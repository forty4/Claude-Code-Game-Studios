# Damage / Combat Calculation — Design Brief

> **Status**: Pre-authoring brief (not a GDD).
> **Purpose**: Pre-load context for a fresh `/design-system damage-calc` session
> so the systems-designer agent starts with the full upstream surface already mapped.
> **Scope**: What Damage Calc must consume, what it must produce, and what it must NOT re-derive.
> **Does not define**: final formulas, tuning values, or acceptance criteria — those are
> the job of the `/design-system` skill in its own session.

---

## 1. Position in the System Graph

- **System ID**: `#11` (design-order `#10`), MVP tier, Feature layer.
- **Depends on**: Unit Roles (#7), HP/Status (#13), Terrain (#5), Balance/Data (#18).
- **Consumed by**: Grid Battle (#1), HP/Status intake pipeline, AI System (#8 — projected-damage heuristics), Battle Effects/VFX (#23).
- **Called by**: Grid Battle CR-5 Step 7 — `DamageCalc.resolve(attacker, defender, modifiers) -> int`.
- **Returns to**: HP/Status via Grid Battle (CR-5 Step 8) — the returned integer is `resolved_damage`, the input contract documented in `hp-status.md` §CR-3 / §F-1.
- **Does NOT emit signals**. Per ADR-0001 (line 375): *"Formation Bonus (#3), Damage Calculation (#11) — subscribers only; consume `round_started` and per-attack context; do not emit."* Damage Calc is a synchronous calculation service. Any side-effects (number popups, sound) are downstream presentation reacting to Grid Battle's step-sequence, not to a signal Damage Calc emits.

---

## 2. Upstream References — what every citing GDD expects Damage Calc to own

Six MVP GDDs reference Damage Calc. Each expectation is cited below with a locator.

### 2.1 `hp-status.md` — intake contract (authoritative)

- `hp-status.md:98` — *"Damage Calc은 회피 체크 완료 후 `resolved_damage ≥ 1`을 전달한다. 회피(MISS)인 경우 HP/Status는 호출되지 않는다."*
- `hp-status.md:271–273` — **Contract 1 Damage Calc → HP/Status**: Input `resolved_damage`(int ≥ 1), `attack_type`(enum {PHYSICAL, MAGICAL}), `source_flags`(set).
- `hp-status.md:508` — HP/Status exposes `get_modified_stat(unit, stat_name)` for Damage Calc to read ATK/DEF adjusted for status effects.
- **Implication for Damage Calc**: owns ATK/DEF, terrain, direction, and evasion roll; HP/Status owns Shield Wall flat reduction, DEFEND_STANCE %, status modifiers, min-damage floor, and HP subtraction. **Do not duplicate HP/Status pipeline stages.**

### 2.2 `unit-role.md` — stat & passive inputs

- `unit-role.md:99` — Cavalry Charge: first attack of turn, moved ≥4 budget before attacking → **+20% bonus damage**. Requires unit initiated combat (not counter).
- `unit-role.md:100` — Infantry Shield Wall: PHYSICAL only, **flat −5** after percentage reductions. (Owned by HP/Status intake, but Damage Calc must propagate `attack_type`.)
- `unit-role.md:104` — Scout Ambush: attacking a unit with `acted_this_turn == false` → **+15% bonus damage** AND target cannot counter-attack. Gated on `current_round_number ≥ 2`.
- `unit-role.md:180–193` — Direction multipliers:
  - Base: FRONT ×1.0 / FLANK ×1.2 / REAR ×1.5
  - Class overrides: CAVALRY 1.0/1.1/1.2, SCOUT 1.0/1.0/1.1 (all others ×1.0 flat).
  - Multiplied together: `base_D × class_D`.
- `unit-role.md:505–507` — **Order rule (EC-7)**: `base_atk × base_REAR(1.5) × class_REAR(1.2) × Charge(1.2) = 2.16×`. Charge is **multiplicative, not additive**. Damage Calc must preserve this ordering.
- `unit-role.md:623` — **Contract 2 Unit Role → Damage Calc (per-attack)**: Damage Calc pulls `atk`, `phys_def`, `mag_def`, `attack_type`, passive tags, direction multipliers from Unit Role.
- `unit-role.md:941` — Ranges: `atk ∈ [1,200]`, `phys_def / mag_def ∈ [1,100]`.

### 2.3 `terrain-effect.md` — modifier provider, not the formula owner

- `terrain-effect.md:260–262` — *"Terrain → Damage Calc: Defense reduction is a percentage passed to the damage formula. Damage Calc applies it as `base_damage × (1 - total_def / 100)`."*
- `terrain-effect.md:266–270` — Caps live in `terrain-effect.md`: `MAX_DEFENSE_REDUCTION = 30%`, `MAX_EVASION = 30%`. **Damage Calc enforces the clamp**, using the constants registered in `entities.yaml`.
- `terrain-effect.md:156–158` — CR-3d **minimum damage rule**: `max(1, effective_damage)`. Damage Calc owns the `max(1, …)` application.
- `terrain-effect.md:485–495` — EC-11 **rounding**: fractional damage **truncated toward floor** (`floori`). Deterministic, platform-independent, reinforces "terrain fights for you" fantasy.
- `terrain-effect.md:90–93, 325` — Evasion: rolled **once per attack, before damage calculation**. On success: 0 damage, no status effects, short-circuit. `MAX_EVASION = 30%` clamp applied by Damage Calc.
- `terrain-effect.md:178` — **Method 2** call: `get_combat_modifiers(atk, def)` returns terrain/elevation components ready for formula consumption.

### 2.4 `grid-battle.md` — call site + **provisional formula (to be replaced)**

- `grid-battle.md:185–196` — CR-5 sequence. Steps Damage Calc owns (step 7): `raw_damage` computation from ATK/DEF/modifiers/direction. Steps Damage Calc does **not** own: evasion check (step 6 — Grid Battle currently calls Damage Calc via F-GB-PROV; in final form, evasion roll moves into Damage Calc service since `terrain-effect.md:442` assigns it there), intake routing (step 8).
- `grid-battle.md:220–225` — **CR-6 counter-attack**:
  - `COUNTER_ATTACK_MODIFIER = 0.5` (constant registered in `entities.yaml`).
  - Applied **as final multiplier** before HP/Status intake: `counter_raw = max(1, floori(raw_damage × 0.5))`.
  - DEFEND_STANCE reduces both the primary attack (damage taken) AND the DEFEND_STANCE unit's counter ATK by −40%.
- `grid-battle.md:581–615` — **F-GB-PROV (provisional formula)** to be replaced:
  ```gdscript
  # Stage 1 — Base damage (pre-direction cap)
  var defense_mul: float = snappedf(1.0 - (T_def / 100.0), 0.01)  # terrain def clamp
  var base_damage: int = max(MIN_DAMAGE, floori(ATK - DEF * defense_mul))
  base_damage = mini(BASE_CEILING, base_damage)                   # 100 pre-direction cap
  
  # Stage 2 — Directional final damage (post-direction cap)
  var D_mult: float = snappedf(base_D * class_D, 0.01)             # pre-quantize to kill IEEE-754 drift
  var raw_damage: int = mini(DAMAGE_CEILING, floori(base_damage * D_mult))  # 150 post-direction cap
  ```
  - `BASE_CEILING = 100`, `DAMAGE_CEILING = 150`, `MIN_DAMAGE = 1` (all in registry).
  - **Two-stage cap** intentional: preserves linear REAR>FLANK>FRONT scaling at all ATK levels while hard-clamping single-hit damage at 50% of `HP_CAP = 300`.
  - Note: **F-GB-PROV currently ignores ATK/DEF multiplicative ratios AND class_atk_mult** — the brief calls this out explicitly because the replacement formula will likely change the ATK/DEF relationship from `ATK - DEF*m` subtraction to something with more dynamic range.
  - **Precision invariant (AC-GB-07)**: `snappedf(base × class, 0.01)` must happen **before** multiplying into `base_damage` to prevent IEEE-754 residue between platforms.
- `grid-battle.md:814–816` — Final interface target: `DamageCalc.resolve(attacker: Dictionary, defender: Dictionary, modifiers: Dictionary) -> int`.
- `grid-battle.md:895–901` — Registered balance ceilings Damage Calc must respect: `BASE_CEILING=100` (tuning range 60–150), `DAMAGE_CEILING=150` (100–300).

### 2.5 `scenario-progression.md` — no direct dependency

- `scenario-progression.md`: zero `damage` references. Scenario Progression depends on the **outcome** of battles, not individual damage resolutions. Damage Calc has no upstream contract with Scenario Progression. **Brief implication**: Damage Calc does **not** need to surface telemetry or events for Scenario Progression consumption.

### 2.6 `turn-order.md` — query contract

- `turn-order.md:196–197` — ATTACK action "Initiates Damage Calc pipeline"; USE_SKILL "Passes to Damage Calc/status pipeline".
- `turn-order.md:397, 405–410` — **Contract 1 Turn Order → Damage Calc** (read-only, queried per-attack): `get_acted_this_turn(unit_id) -> bool`, `get_current_round_number() -> int`. Used to evaluate Scout Ambush gate (CR-2 / unit-role EC-8).
- `turn-order.md:625, 895, 898` — Ambush gate: `current_round_number >= 2 AND target.acted_this_turn == false`. Damage Calc calls the two turn-order getters at attack resolution time.

---

## 3. Registered Entities — constants & formulas Damage Calc must consume (not re-derive)

All values below already live in `design/registry/entities.yaml` at the line ranges noted. Damage Calc **must read these from the registry config chain** (`balance_constants.json` / `battle_constants.json` / `terrain_config.json` / `hp_status_config.json`) rather than hard-coding.

### Constants

| Name | Value | Unit | Owner GDD | Damage Calc usage |
|---|---|---|---|---|
| `atk_cap` | 200 | stat_points | unit-role.md:440 | Clamp ceiling on attacker ATK input |
| `def_cap` | 100 | stat_points | unit-role.md:451 | Clamp per-type defense input |
| `hp_cap` | 300 | hit_points | unit-role.md:462 | Informs `DAMAGE_CEILING` scaling rationale |
| `min_damage` | 1 | hit_points | hp-status.md:522 | Damage floor `max(1, …)` (CR-3d / F-GB-PROV line 594, 602) |
| `base_ceiling` | 100 | damage | grid-battle.md:667 | F-GB-PROV Stage 1 cap — **revisit on formula replacement** |
| `damage_ceiling` | 150 | damage | grid-battle.md:678 | F-GB-PROV Stage 2 cap — **revisit on formula replacement** |
| `counter_attack_modifier` | 0.5 | multiplier | grid-battle.md:689 | Final multiplier on counter damage |
| `shield_wall_flat` | 5 | hit_points | hp-status.md:533 | Propagated via `attack_type` — applied by HP/Status, NOT by Damage Calc |
| `defend_stance_reduction` | 30 | percent | hp-status.md:577 | Applied by HP/Status intake — Damage Calc must propagate flag but not apply |
| `defend_stance_atk_penalty` | 40 | percent | hp-status.md:588 | Applied by Damage Calc on the DEFEND_STANCE unit's counter-attack ATK |
| `terrain_def_cap` | 30 | percent | terrain-effect.md:556 | Clamp on `total_defense_reduction` before `(1 - def/100)` multiply |
| `max_evasion` | 30 | percent | terrain-effect.md:420 | Clamp on evasion roll |
| `charge_threshold` | 40 | move_cost_points | turn-order.md:655 | Evaluated by Unit Role; Damage Calc reads the resolved `charge_active` flag |

### Formulas (registered, **do not redefine**)

| Name | Owner | Damage Calc relation |
|---|---|---|
| `damage_intake_pipeline` | hp-status.md:110 (F-1) | **Downstream of Damage Calc output.** Consumes `resolved_damage`. Damage Calc must produce an int ≥ 1 that feeds this formula. |
| (no registered formula yet) | grid-battle.md F-GB-PROV | **Provisional — to be replaced by the new Damage Calc formula.** F-GB-PROV will be retired from `grid-battle.md` and the replacement registered as `damage_resolve` (name TBD by /design-system). |

---

## 4. ADR-0001 Signal Surface — confirmation

Per `docs/architecture/ADR-0001-gamebus-autoload.md:375`, Damage Calc is a **consumer-only** system.

**Signals Damage Calc may subscribe to (read-only)**:
- `round_started(round_number: int)` — optional, for per-round caches.
- Per-attack context is **pulled via direct call**, not signal: Unit Role `get_passive_tags()`, Terrain `get_combat_modifiers()`, Turn Order `get_acted_this_turn()` / `get_current_round_number()`, HP/Status `get_modified_stat()`.

**Signals Damage Calc MUST NOT emit**: any. A new `damage_resolved` signal would contradict ADR-0001 and duplicate Grid Battle's step-sequence orchestration.

**Implication for the GDD**: the Dependencies section lists **direct synchronous contracts only**. No signal declarations belong in Damage Calc's GDD.

---

## 5. Open Questions Inherited from Upstream GDDs

The /design-system session must resolve (or explicitly defer with justification) the following carried-over questions. Sources cited for traceability.

| # | Question | Source | Why it blocks Damage Calc |
|---|---|---|---|
| **OQ-DC-1** | Does Damage Calc own the **evasion roll**, or does it receive a pre-rolled MISS flag from Terrain? | terrain-effect.md:442 delegates evasion to Damage Calc; grid-battle.md:188 shows Grid Battle calling evasion at Step 6 | Call-graph surface. Affects `resolve()` signature and determinism. |
| **OQ-DC-2** | ATK/DEF relationship — retain F-GB-PROV's `ATK − DEF×m` subtraction, or migrate to ratio/curve (e.g., `ATK² / (ATK + DEF)`)? | grid-battle.md:1085 "F-GB-PROV is provisional"; unit-role.md:976 "Resolve at Damage Calc GDD" | Central formula choice. Determines dynamic range, one-shot risk, counter-attack balance. |
| **OQ-DC-3** | Counter-attack as first-class Damage Calc output, or as a second `resolve()` call from Grid Battle? | grid-battle.md:626 shows counter computed as `raw_damage × 0.5` — implicit reliance on primary result | API shape: returns `{primary: int, counter: int}` vs. single int with Grid Battle calling twice. |
| **OQ-DC-4** | Does Damage Calc define **skill damage** (USE_SKILL action), or defer to a future Skill System GDD? | grid-battle.md:962 "deferred to Skill System"; unit-role.md:966 "Hero DB OQ-2 raised the same question" | Scope boundary. MVP answer likely: defer, return placeholder for skill effect types. |
| **OQ-DC-5** | **Critical hits** — in scope for MVP or deferred? | No MVP GDD references crits explicitly | Scope. 삼국지연의 tonally compatible with "decisive blow" moments, but adds RNG surface. |
| **OQ-DC-6** | **Elevation attack bonus** — percentage, tile-count, or elevation-delta? | terrain-effect.md:666 shows "+8% 공격" UI; AC-3 test uses +15% | Inconsistency in terrain GDD; must be pinned before Damage Calc formula. |
| **OQ-DC-7** | Stacking order: `(base_atk × class_atk_mult × direction × passive) − defense_term × terrain_def_mul` vs. `(base_atk − def_term) × direction × passive × terrain_def_mul`. | unit-role.md:505 EC-7 fixes multiplicative order for direction and Charge **only** | Final formula skeleton choice. unit-role.md EC-7 is non-negotiable; all other factors are open. |
| **OQ-DC-8** | True damage (DoT, status) — does Damage Calc expose a `resolve_true_damage(amount) -> int` branch, or does HP/Status invoke its own `dot_damage` path entirely outside Damage Calc? | hp-status.md:356 DoT explicitly bypasses intake pipeline; does it bypass Damage Calc too? | API surface. Current evidence says **yes, bypass** — confirm in GDD. |

---

## 6. Anticipated Formula Skeleton (straw-man for /design-system to refine)

Not a commitment — this is a starting point the fresh session can accept, reject, or mutate. Each block flags the open question it addresses.

```gdscript
# DamageCalc.resolve(attacker: Dictionary, defender: Dictionary, modifiers: Dictionary) -> ResolveResult
# 
# attacker: { unit_id, class, atk, class_atk_mult, passives[], direction_facing, charge_active }
# defender: { unit_id, class, phys_def, mag_def, defend_stance_active, terrain_def, terrain_evasion }
# modifiers: { attack_type, source_flags, elevation_delta, skill_id?, is_counter }

# 1. Evasion roll (OQ-DC-1 — if owned here)
if not is_counter:
    var evasion_pct: int = clampi(defender.terrain_evasion, 0, MAX_EVASION)
    if rng.randi_range(1, 100) <= evasion_pct:
        return ResolveResult.MISS

# 2. Effective stats (from HP/Status via get_modified_stat)
var eff_atk: int = clampi(hp_status.get_modified_stat(attacker.unit_id, "atk"), 1, ATK_CAP)
var eff_def: int = clampi(hp_status.get_modified_stat(defender.unit_id, "phys_def" if PHYSICAL else "mag_def"), 1, DEF_CAP)

# 3. Defense reduction from terrain (OQ-DC-6 resolution required for elevation)
var terrain_def_pct: int = clampi(defender.terrain_def + elevation_def_bonus, -30, TERRAIN_DEF_CAP)  # signed — negative amplifies
var defense_mul: float = snappedf(1.0 - (terrain_def_pct / 100.0), 0.01)

# 4. Direction + class direction (unit-role EC-7 rule — MULTIPLICATIVE, preserved)
var D_mult: float = snappedf(base_direction_mult[direction_rel] * class_direction_mult[attacker.class][direction_rel], 0.01)

# 5. Passive bonus (Charge / Ambush — from unit-role passives[])
var P_mult: float = 1.0
if "passive_charge" in attacker.passives and attacker.charge_active:
    P_mult *= 1.20
if "passive_ambush" in attacker.passives and ambush_conditions_met(attacker, defender, turn_order):
    P_mult *= 1.15

# 6. DEFEND_STANCE penalty on counter-attack ATK (hp-status.md:588)
if is_counter and attacker.defend_stance_active:
    eff_atk = floori(eff_atk * 0.60)  # -40%

# 7. Core formula — straw-man: subtraction (OQ-DC-2 to decide)
var base_damage: int = max(MIN_DAMAGE, floori(eff_atk - eff_def * defense_mul))
base_damage = mini(BASE_CEILING, base_damage)

# 8. Direction + passive multiply
var raw_damage: int = mini(DAMAGE_CEILING, floori(base_damage * D_mult * P_mult))

# 9. Counter multiplier (OQ-DC-3 — if counter is computed here rather than by a second call)
if is_counter:
    raw_damage = max(MIN_DAMAGE, floori(raw_damage * COUNTER_ATTACK_MODIFIER))

return ResolveResult.hit(raw_damage, attack_type, source_flags)
```

### Non-negotiable invariants the final formula must preserve

1. **EC-7 ordering**: `base × base_REAR × class_REAR × Charge` stays multiplicative (`unit-role.md:505`).
2. **MIN_DAMAGE floor**: every branch returns ≥ 1 on hit (or MISS marker). Registered as `min_damage = 1`.
3. **DAMAGE_CEILING = 150** on single-hit output (or replacement if OQ-DC-2 restructures).
4. **Deterministic float handling**: `snappedf(…, 0.01)` applied to every compound float **before** casting back to int (AC-GB-07).
5. **Evasion short-circuit**: on MISS, HP/Status not called (`hp-status.md:98`).
6. **Intake boundary**: Shield Wall, status modifiers, DEFEND_STANCE damage %, and HP subtraction are HP/Status's job. Damage Calc stops at `resolved_damage`.

---

## 7. Testing Commitments

Per `.claude/docs/coding-standards.md`: **Balance formulas 100% unit-test coverage**.

### Required test surface (minimum bar for Acceptance Criteria)

| Test class | Examples |
|---|---|
| **Ordering & multiplicative correctness** | EC-7 Cavalry REAR + Charge = 2.16× (`unit-role.md:506`); Scout REAR + Ambush = 1.897× (`unit-role.md:917`) |
| **Floor & ceiling enforcement** | MIN_DAMAGE applied below 1; BASE_CEILING caps pre-direction; DAMAGE_CEILING caps post-direction |
| **Terrain clamp** | total_def at 31% clamped to 30%; negative defense `-15%` amplifies to `× 1.15` (`terrain-effect.md:697`) |
| **Evasion** | MAX_EVASION clamp at 30%; MISS short-circuits (no HP/Status call); evasion RNG seeding deterministic |
| **Counter-attack** | `counter_raw = max(1, floor(raw × 0.5))`; DEFEND_STANCE −40% ATK penalty applied; primary reduction AND counter penalty both active |
| **Direction edge cases** | All 4 classes × 3 directions = 12 combinations; verify class override vs. base (`unit-role.md:186–193`) |
| **Precision** | IEEE-754 determinism — identical output on Android/Windows for quantized D_mult (`AC-GB-07`) |
| **Passive gating** | Scout Ambush blocked on round 1 (EC-8); Charge blocked on counter-attack (EC-7); Shield Wall flat-5 is MAGICAL-immune (AC-7 in unit-role) |
| **Attack type propagation** | PHYSICAL/MAGICAL flag reaches HP/Status intake unchanged (Shield Wall only fires on PHYSICAL) |

### Test fixtures location

- Unit tests: `tests/unit/damage_calc/damage_calc_formula_test.gd` (naming per `.claude/rules/test-standards.md`).
- Integration: `tests/integration/combat/grid_battle_damage_intake_test.gd` — round-trip through Grid Battle + HP/Status.
- Framework: GdUnit4. CI: `.github/workflows/tests.yml` (already configured).

---

## 8. Authoring Checklist for `/design-system damage-calc` Session

When the fresh session starts, the systems-designer agent should confirm before drafting:

- [ ] Resolved OQ-DC-1 (evasion ownership) — pick one owner, update `terrain-effect.md` or `grid-battle.md` cross-reference to match.
- [ ] Resolved OQ-DC-2 (ATK/DEF formula shape) — OR explicitly ratified F-GB-PROV's subtraction as the final form.
- [ ] Resolved OQ-DC-3 (counter-attack API shape).
- [ ] Scoped OQ-DC-4, OQ-DC-5 (skills, crits) — in or out of MVP.
- [ ] Resolved OQ-DC-6 (elevation percentage inconsistency — reconcile terrain-effect.md AC-3 vs. UI text).
- [ ] All 13 registered constants from §3 referenced, not redefined.
- [ ] EC-7 multiplicative order preserved in Formulas section.
- [ ] MIN_DAMAGE floor, DAMAGE_CEILING, deterministic float handling each have an AC.
- [ ] No signals emitted — confirm Damage Calc stays a consumer-only service per ADR-0001.
- [ ] Retire F-GB-PROV in `grid-battle.md` with a producer-coordinated update (ADR-0001 §Coordinated Updates style).
- [ ] Register new formula `damage_resolve` (or final name) in `design/registry/entities.yaml`.
- [ ] Systems-index row 11: `Not Started` → `Designed`, and the `design-order #10` row mirrors.

---

## 9. Cross-References

- `docs/architecture/architecture.md` v0.3 — Core layer Module Ownership, Invariant #4 / #4b.
- `docs/architecture/ADR-0001-gamebus-autoload.md:375` — Damage Calc consumer-only role.
- `design/gdd/hp-status.md` §CR-3, §F-1 — intake contract.
- `design/gdd/unit-role.md` §CR-2, §CR-6, §F-1, §EC-7 — passives, direction multipliers, ordering rule.
- `design/gdd/terrain-effect.md` §CR-3, §F-1, §F-2, §EC-11 — defense reduction, evasion, rounding.
- `design/gdd/grid-battle.md` §CR-5, §CR-6, §F-GB-PROV, §AC-GB-07, §AC-GB-10 — call site, counter, provisional formula, precision invariant.
- `design/gdd/turn-order.md` §Contract 1 — query API for Ambush gate.
- `design/registry/entities.yaml` — 13 constants + `damage_intake_pipeline` formula.
- `.claude/docs/coding-standards.md` — testing commitments.
- `.claude/docs/technical-preferences.md` — Godot 4.6 / GDScript / GdUnit4 stack.

---

## Document metadata

- Author: pre-authoring brief, written during the 2026-04-18 gate-closing session.
- Consumed by: `/design-system damage-calc` in a fresh session.
- Lifecycle: **delete after** the Damage Calc GDD reaches `Designed` status and this brief's open questions are all answered in the GDD. Until then, treat as a read-only input.
