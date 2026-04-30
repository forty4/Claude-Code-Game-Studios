# ADR-0010: HP/Status — HPStatusController Battle-Scoped Node + Per-Unit RefCounted State (MVP scope)

## Status

Accepted (2026-04-30 via `/architecture-review` delta #7 — `docs/architecture/architecture-review-2026-04-30c.md`; design-time godot-specialist validation completed during `/architecture-decision hp-status` lean-mode authoring; review-time independent godot-specialist validation completed this delta — APPROVED WITH SUGGESTIONS, 3 same-patch corrections applied (Items 1/2/9) + 2 advisories carried (Items 5/8); 1 cross-doc unit_id type advisory queued for next ADR-0012 amendment)

## Date

2026-04-30

## Last Verified

2026-04-30 (Accepted via /architecture-review delta #7 — first Core-layer ADR; closes ADR-0012's `get_modified_stat` + `apply_damage` upstream Core soft-dep)

## Decision Makers

- User (Sprint scheduling authorization, 2026-04-30 — `/architecture-decision hp-status` invocation immediately following ADR-0005 Acceptance via /architecture-review delta #6)
- Technical Director (architecture owner — Core layer first ADR; closes ADR-0012 Damage Calc's outstanding upstream soft-dep on `get_modified_stat` interface)

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core — gameplay state + logic (not Physics/Rendering/UI/Audio/Navigation/Input — pure gameplay rules layer over typed Resources, Dictionaries, and signals) |
| **Knowledge Risk** | **LOW** — Core/Scripting domain. Post-cutoff features used: typed `Dictionary[K, V]` (Godot 4.4+) for the per-unit state map; `Resource` `@export` typed fields (stable since 4.0); `class_name` PascalCase + signal connect via Callable (stable since 4.0); StringName literals `&"effect_id"` (stable since 4.0). NO HIGH-risk surface (no UI dual-focus, no shaders, no SDL3, no Android-specific APIs). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pinned 2026-04-16); `docs/engine-reference/godot/breaking-changes.md` (no HP/Status-relevant 4.4/4.5/4.6 changes); `docs/engine-reference/godot/deprecated-apis.md` (none used); `docs/engine-reference/godot/current-best-practices.md`; `design/gdd/hp-status.md` (Designed 2026-04-16, 5 Core Rules CR-1..CR-9, 4 formulas F-1..F-4, 17 Edge Cases EC-01..EC-17, 27 Tuning Knobs, 20 Acceptance Criteria AC-01..AC-20, 6 Open Questions); `docs/architecture/ADR-0001-gamebus-autoload.md` (line 155 `signal unit_died(unit_id: int)`; line 303-307 HP/Status emitter declaration; line 252 batching rule; lines 365-376 non-emitter list — HP/Status is on the emitter side for `unit_died` only, no other emit obligations); `docs/architecture/ADR-0004-map-grid-data-model.md` (`get_tile(coord: Vector2i) -> TileData` + `TileData.occupant_id` for DEMORALIZED radius scan per registry line 293); `docs/architecture/ADR-0006-balance-data.md` (`BalanceConstants.get_const(key: String) -> Variant` for all 27 tuning knobs); `docs/architecture/ADR-0007-hero-database.md` (HeroData 26-field schema; `is_morale_anchor` field NOT present — DEFERRED post-MVP per §Open Questions OQ-2); `docs/architecture/ADR-0009-unit-role.md` (line 166 `static func get_max_hp(hero: HeroData, unit_class: UnitRole.UnitClass) -> int`; PASSIVE_TAG_BY_CLASS Dictionary for `passive_shield_wall` lookup); `docs/architecture/ADR-0012-damage-calc.md` (lines 89-93, 260, 297-299, 340-352 — interface signatures + cap ownership labels + sole-caller contract); `docs/registry/architecture.yaml` v3 (line 293 hp-status reads MapGrid get_tile; line 356 hp-status reads UnitRole get_max_hp; line 388 hp-status reads HeroData base_hp_seed via UnitRole; line 641 Unit Role rejection of stateful cache cites HP/Status's get_modified_stat ownership); `.claude/docs/technical-preferences.md` (60fps target / 16.6ms frame budget / 512MB mobile / GdUnit4 v6.1.2 pinned). |
| **Post-Cutoff APIs Used** | (a) **Godot 4.4 typed `Dictionary[int, UnitHPState]`** for the per-unit state map — provides parse-time element-type checking; falls back to untyped `Dictionary` if compatibility issues arise (no behavior change). (b) **Godot 4.5 `@abstract` decorator** is **NOT used** here — `HPStatusController extends Node` is a concrete instance node, not an abstract base. (c) **Godot 4.5 `duplicate_deep()`** is **NOT used** here — battle-scoped state is non-persistent per CR-1b; no save/load round-trip ever occurs through HP/Status (SaveManager only persists scenario-level state per ADR-0003, NOT in-battle HP). (d) StringName literals `&"poison"` / `&"defend_stance"` etc. for `effect_id` keys (stable since 4.0; matches ADR-0007/0009/0012 4-precedent StringName convention). |
| **Verification Required** | (1) **Cross-platform determinism**: Same `apply_damage` / `apply_heal` / `apply_status` / DoT-tick call sequence produces identical `current_hp` + `status_effects[]` final state on macOS Metal + Linux Vulkan + Windows D3D12 — F-1/F-2/F-3/F-4 use only integer arithmetic + `floor()` + `clamp()` (no float-point math in HP intake; F-2 uses `ceil(max_hp × HEAL_HP_RATIO)` but `HEAL_HP_RATIO` is loaded as float from JSON and the `ceil()` result is integer). Headless CI deterministic-fixture test mandatory before Polish. (2) **`Dictionary[int, UnitHPState]` typed-map parse**: GDScript 4.4+ typed Dictionary syntax must parse without warning in 4.6 stable; verify on first story implementation. Fallback path: untyped `Dictionary` with explicit `assert(state is UnitHPState)` guards at access sites. (3) **GdUnit4 v6.1.2 RefCounted + Resource lifecycle in `before_test()` reset**: per-test fresh `HPStatusController.new()` instance with empty `_state_by_unit` Dictionary; verify no state leakage across test cases (G-15-style obligation; codified as forbidden_pattern `hp_status_static_var_state_addition`). (4) **`StatusEffect` Resource serialization** in tests: typed Resource `.new()` + `@export` field assignment must round-trip identically when used as test fixture (no save/load needed for production but tests use `.tres` resources for regression fixtures). (5) **`unit_died` signal emission ordering** with respect to `current_hp = 0` mutation: signal MUST emit AFTER `current_hp` is set to 0 (so subscribers reading `current_hp` in the handler see 0, not pre-mutation value). Verify via re-entrancy unit test fixture. |

> **Knowledge Risk Note**: Domain is **LOW** risk for this Core-layer state-machine ADR. No engine-version-specific gotchas in scope. The 5-precedent stateless-static pattern (ADR-0008→0006→0012→0009→0007) is **NOT applicable** here per ADR-0005 §Alternative 4 pattern boundary: HP/Status is **STATEFUL** (per-unit `current_hp` + `status_effects[]` + cached `max_hp`) AND **LISTENS** to Turn Order signals for DoT tick + duration decrement. Battle-scoped Node form (matching ADR-0004 Map/Grid lifecycle) is the engine-correct fit per the pattern boundary established in ADR-0005.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 GameBus** (Accepted 2026-04-18) — HPStatusController is the registered emitter of `unit_died(unit_id: int)` per ADR-0001 §7 Signal Contract Schema (line 155) and per the HP/Status Domain emitter declaration (line 303-307). HP/Status is on the **non-emitter list by behavior** for all OTHER 21 GameBus signals across 8 domains (Combat / Scenario / Persistence / Environment / Grid Battle / Turn Order / Input / UI-Flow). **ADR-0004 Map/Grid** (Accepted 2026-04-20) — HPStatusController calls `MapGrid.get_tile(coord: Vector2i) -> TileData` for DEMORALIZED radius scan (CR-6 SE-2 condition (a)); per registry line 293 consumer entry; battle-scoped lifecycle alignment (both freed with BattleScene per ADR-0002). **ADR-0006 Balance/Data** (Accepted 2026-04-30 via /architecture-review delta #9) — `BalanceConstants.get_const(key: String) -> Variant` for all 27 tuning knob values per CR-1..CR-9 (MIN_DAMAGE / SHIELD_WALL_FLAT / HEAL_BASE / HEAL_HP_RATIO / HEAL_PER_USE_CAP / EXHAUSTED_HEAL_MULT / DOT_HP_RATIO / DOT_FLAT / DOT_MIN / DOT_MAX_PER_TURN / DEMORALIZED_ATK_REDUCTION / DEMORALIZED_RADIUS / DEMORALIZED_TURN_CAP / DEMORALIZED_RECOVERY_RADIUS / DEFEND_STANCE_REDUCTION / DEFEND_STANCE_ATK_PENALTY / INSPIRED_ATK_BONUS / INSPIRED_DURATION / EXHAUSTED_MOVE_REDUCTION / MODIFIER_FLOOR / MODIFIER_CEILING / MAX_STATUS_EFFECTS_PER_UNIT / ATK_CAP / DEF_CAP / POISON_DEFAULT_DURATION / DEMORALIZED_DEFAULT_DURATION / EXHAUSTED_DEFAULT_DURATION); G-15 `_cache_loaded` reset obligation in every HPStatusController test suite. **ADR-0007 Hero Database** (Accepted 2026-04-30) — `HeroDatabase.get_hero(hero_id: StringName) -> HeroData` provides `base_hp_seed` (transitively consumed via UnitRole.get_max_hp). **ADR-0009 Unit Role** (Accepted 2026-04-28) — `UnitRole.get_max_hp(hero: HeroData, unit_class: UnitRole.UnitClass) -> int` cached at battle-init for each unit's `UnitHPState.max_hp` field (one call per unit per battle per ADR-0009 line 328); `UnitRole.PASSIVE_TAG_BY_CLASS[unit_class]` for `passive_shield_wall` lookup in F-1 Step 1 (ATK_TYPE = PHYSICAL passive flat reduction). **ADR-0012 Damage Calc** (Accepted 2026-04-26) — soft-coupled: ADR-0012 §Dependencies line 42 commits to consuming `hp_status.get_modified_stat(unit_id, stat_name)` + ADR-0012 line 260 commits Grid Battle (NOT Damage Calc) as sole caller of `hp_status.apply_damage(unit_id, resolved_damage, attack_type, source_flags)`. ADR-0010 ratifies (does not negotiate) both signatures. |
| **Soft / Provisional** | (1) **ADR-0011 Turn Order (Accepted 2026-04-30 via /architecture-review delta #8 — RATIFIED parameter-stable; no code change to ADR-0010 required)**: HPStatusController subscribes to `unit_turn_started(unit_id: int)` GameBus signal (Turn Order Domain per ADR-0001 §7) for (a) DoT tick processing per F-3 (POISON deals damage at unit's turn start); (b) status effect duration decrement (TURN_BASED effects); (c) DEFEND_STANCE 1-turn ACTION_LOCKED expiry per CR-6 SE-3; (d) DEMORALIZED CONDITION_BASED recovery check per CR-6 SE-2 (ally hero ≤ 2 manhattan distance triggers expiry). HPStatusController commits to this consumer contract verbatim per ADR-0001 line 159 Turn Order signal declaration; ADR-0011 ratified (did not negotiate) the signal payload `(unit_id: int)` — confirmed parameter-stable upon delta #8 Acceptance. Mirrors 5-precedent provisional-dep pattern (ADR-0008→0006 / ADR-0012→0009/0010/0011 / ADR-0009→0007 / ADR-0007→Formation Bonus / ADR-0005→5 downstream). (2) **Hero DB `is_morale_anchor: bool` field (NOT YET in ADR-0007 ratified schema — DEFERRED post-MVP)**: GDD CR-6 SE-2 condition (b) ("`is_morale_anchor=true`인 아군 명명 영웅 사망 시 동일 적용") references a `is_morale_anchor` field that does NOT exist in HeroData's 26-field schema (verified 2026-04-30 via grep of ADR-0007 + design/gdd/hero-database.md — zero matches). MVP DEMORALIZED triggers ONLY via condition (a) Commander class auto-trigger (`unit_class == UnitClass.COMMANDER`) and condition (c) direct skill application. Condition (b) is-morale-anchor heroes deferred to post-MVP via either (i) ADR-0007 amendment to add the field; or (ii) HPStatusController-side `_morale_anchor_unit_ids: Dictionary[int, bool]` populated from a future scenario-side authored list. Decision deferred to Open Question OQ-2 below; tracked as soft-dep for next ADR-0007 amendment OR ADR-0014 Scenario Progression depending on which lands first. (3) **Battle Preparation ADR (NOT YET WRITTEN — soft / provisional downstream)**: invokes `HPStatusController.initialize_battle(unit_roster: Array[BattleUnit])` to populate per-unit `UnitHPState` entries at battle-init (one-time `UnitRole.get_max_hp` call per unit per battle per ADR-0009 line 328 per-unit cadence). Battle Preparation ADR ratifies the BattleUnit contract; ADR-0010 commits to the signature shape verbatim from prose-level `Battle Preparation → HP/Status` description. |
| **Enables** | (1) **Ratifies** ADR-0012's `hp_status.apply_damage(unit_id, resolved_damage, attack_type, source_flags)` interface (line 260) + `hp_status.get_modified_stat(unit_id, stat_name)` interface (lines 89-93, 340-352) + MIN_DAMAGE=1 dual-enforcement contract (line 92) + DEFEND_STANCE -50% intake-pipeline reduction ownership (line 93). Closes ADR-0012's only outstanding upstream Core-layer soft-dep among ADR-0010/0011 (ADR-0011 ratified 2026-04-30 via delta #8). (2) **Unblocks `hp-status` Core epic** — `/create-epics hp-status` after ADR-0010 Acceptance via /architecture-review delta. (3) **Unblocks ADR-0011 Turn Order ratification path** — Turn Order will ratify (not negotiate) the `unit_turn_started(unit_id: int)` consumer contract this ADR commits to. (4) **Unblocks Battle HUD ADR / Presentation-layer epic** — HUD reads `get_current_hp / get_max_hp / get_status_effects` query API for HP bar + status icon rendering; ratifies the read-only query contract. (5) **Unblocks AI System ADR / Feature-layer epic** — AI reads `get_current_hp(unit_id) / get_max_hp(unit_id)` ratio for threat evaluation + `get_status_effects(unit_id)` for buff/debuff awareness in target prioritization heuristic. (6) **Unblocks Grid Battle Vertical Slice readiness** — Grid Battle's HIT path orchestration depends on `hp_status.apply_damage` (per ADR-0012 line 260); no VS without HP/Status shipped. (7) **Resolves ADR-0012 §Dependencies line 42 ADR-0010 provisional clause** — provisional → ratified upon Acceptance. |
| **Blocks** | hp-status Core epic implementation (cannot start any story until this ADR is Accepted); `assets/data/balance/balance_entities.json` 27-key BalanceConstants entries authoring + lint validation (story-level same-patch obligation per ADR-0006 §6 pattern); ADR-0011 Turn Order finalization (Turn Order's `unit_turn_started` payload ratification depends on this ADR's consumer contract); Grid Battle Vertical Slice (no VS without HP/Status); Battle HUD ADR ratification (HUD depends on `get_current_hp / get_max_hp / get_status_effects` query API surface). |
| **Ordering Note** | First **Core layer** ADR (ADR-0008 Terrain Effect was tagged Core in some prose but architectural lineage groups Terrain Effect with Foundation calculator pattern). Pattern divergence from prior 6 ADRs (5 stateless-static + 1 stateful Autoload Node ADR-0005): HPStatusController is **STATEFUL** (per-unit `current_hp` + `status_effects[]` + cached `max_hp`) AND **BATTLE-SCOPED** (resets between battles per CR-1b). Pattern boundary established by ADR-0005 §Alternative 4 (stateless-static for systems CALLED; Node-based for systems that LISTEN) is honored: HP/Status listens to Turn Order signals AND mutates per-unit state, satisfying both ADR-0005 criteria for Node-based form. Battle-scoped Node form (matching ADR-0004 Map/Grid lifecycle) — vs. autoload Node (ADR-0005 InputRouter pattern) — is the engine-correct fit because HP state is non-persistent per CR-1b (no cross-battle survival required). Lifecycle alignment with BattleScene teardown is the cleanest non-persistence enforcement (state freed automatically when BattleScene is freed per ADR-0002 SceneManager pattern; no manual reset between battles needed). |

---

## Context

### Problem Statement

`design/gdd/hp-status.md` (Designed 2026-04-16, 5 Core Rules CR-1..CR-9 + 4 sub-rules per CR-5; 4 formulas F-1..F-4; 17 Edge Cases EC-01..EC-17; 27 Tuning Knobs; 20 Acceptance Criteria AC-01..AC-20; 6 Open Questions OQ-1..OQ-6) defines the Core-layer HP/Status System. The architecture cannot proceed without locking 11 questions:

1. **Module form** — Battle-scoped Node? Autoload Node? Stateless-static utility? Stateful RefCounted singleton? Per-unit `Component` Node attached to BattleUnit nodes?
2. **Class naming reconciliation** — ADR-0001 line 303 prose names "HPStatusController" as the emitter; registry uses slug `hp-status`. Cross-doc canonical name must lock.
3. **Per-unit state schema** — `UnitHPState` as RefCounted vs Resource vs typed Dictionary entries? Field set: `current_hp`, cached `max_hp`, `status_effects` Array, plus per-effect remaining-turns tracking?
4. **`StatusEffect` schema** — typed Resource vs untyped Dictionary vs `RefCounted` wrapper class? CR-5a defines 6 fields (effect_id / effect_type / duration_type / remaining_turns / modifier_targets / tick_effect); how to type each?
5. **Public API surface** — what's the minimal set of public methods Grid Battle + Damage Calc + Battle HUD + AI need? (5 methods? 8? 12?)
6. **Signal contract** — `unit_died` already declared in ADR-0001. Does HP/Status need additional signals (`hp_changed` / `status_effect_applied` / `status_effect_expired`) for Battle HUD ergonomics, or is direct query (HUD polls per frame) sufficient?
7. **DoT tick timing** — F-3 POISON DoT processes at unit turn start. How does HP/Status get notified? GameBus subscription to `unit_turn_started` (Turn Order ADR-0011 NOT YET WRITTEN — provisional)?
8. **Constants source** — 27 tuning knobs from GDD §Tuning Knobs. Route through BalanceConstants per ADR-0006 4-precedent JSON pattern, or HP/Status holds its own `hp_status_config.json` like terrain-effect's `terrain_config.json`?
9. **`is_morale_anchor` Hero DB gap** — GDD CR-6 SE-2 condition (b) references a `is_morale_anchor: bool` HeroData field that does NOT exist in ADR-0007's ratified 26-field schema. How to handle the gap (defer / amend / external source)?
10. **Test infrastructure** — how to test HPStatusController without real Turn Order signal subscription (DI seam pattern matching ADR-0005 `_handle_event` + ADR-0012 RNG injection)?
11. **Modifier calc contract with Damage Calc** — F-4 `total_modifier = clamp(sum(modifier_i), MODIFIER_FLOOR, MODIFIER_CEILING)` + `modified_stat = max(1, floor(base_stat × (1 + total_modifier / 100)))`. Damage Calc consumes `hp_status.get_modified_stat(unit_id, stat_name)` per ADR-0012 lines 89-93. Does HP/Status need to expose the raw modifier sum, or only the final modified stat? Does HP/Status own the DEFEND_STANCE_ATK_PENALTY application (-40%), or does Damage Calc apply it after `get_modified_stat`?

### Constraints

**From `design/gdd/hp-status.md` (locked by GDD):**
- **CR-1**: HP lifecycle — initialize `current_hp = max_hp` at battle start (after Formation/pre-battle buffs); non-persistent (CR-1b); reset only at new battle or explicit scenario heal event (CR-1c).
- **CR-2**: HP range invariant `0 ≤ current_hp ≤ max_hp` always; external systems MUST NOT directly write `current_hp` — all changes flow through CR-3 damage intake or CR-4 healing pipeline.
- **CR-3**: Damage intake pipeline — F-1 Step 1 (passive flat reduction: SHIELD_WALL_FLAT for PHYSICAL+passive_shield_wall) → Step 2 (status modifier: DEFEND_STANCE -50% / VULNERABLE +%; bind-order DEFEND_STANCE first per EC-03) → Step 3 (MIN_DAMAGE floor) → Step 4 (HP reduction + unit_died emit if 0).
- **CR-4**: Healing pipeline — F-2 raw_heal computed from source → EXHAUSTED multiplier (max(1, floor)) → overheal prevention `min(raw_heal, max_hp - current_hp)` → HP increase. CR-4a: no overheal. CR-4b: dead units cannot be healed.
- **CR-5**: Status Effect architecture — 6-field schema (CR-5a); apply via `apply_status` (CR-5b); same effect_id refresh-only (CR-5c); different effect_id co-exist (CR-5d); max 3 slots per unit, evict oldest (CR-5e); modifier sum + clamp [MODIFIER_FLOOR=-50, MODIFIER_CEILING=+50] (CR-5f).
- **CR-6**: 5 MVP status effects (POISON / DEMORALIZED / DEFEND_STANCE / INSPIRED / EXHAUSTED) with explicit duration types + tick effects + apply/release conditions.
- **CR-7**: DEFEND_STANCE + EXHAUSTED mutual exclusion — EXHAUSTED applied to DEFEND_STANCE unit force-releases DEFEND_STANCE; DEFEND_STANCE attempt while EXHAUSTED fails with "피로로 태세 유지 불가" feedback.
- **CR-8**: Death — `current_hp == 0` emits `unit_died` immediately; no down-state / no resurrection MVP; Commander or `is_morale_anchor` death triggers DEMORALIZED radius propagation.
- **CR-9**: MIN_DAMAGE=1 floor on all damage events; overkill discarded; no instakill mechanic MVP.

**From `docs/architecture/ADR-0001-gamebus-autoload.md`:**
- Line 155: `signal unit_died(unit_id: int)` — HP/Status sole emitter; payload locked to `int`.
- Line 252: "NOT from `_input(event)` for high-frequency input — use dedicated input batching in InputRouter" — applies to InputRouter; HP/Status signals are bursty (per-attack), not high-frequency, so ADR-0001 batching rule does not constrain.
- Line 303-307: HP/Status Domain emitter table — `unit_died` is the only HP/Status-domain signal.
- Lines 365-376 non-emitter list: HP/Status is NOT on the list (consistent with `unit_died` emitter status); HP/Status is non-emitter by behavior for all OTHER 21 signals.

**From `docs/architecture/ADR-0012-damage-calc.md`:**
- Line 89-93: `get_modified_stat(unit_id: StringName, stat_name: String) -> int` returns effective stat with all buffs/debuffs and DEFEND_STANCE penalty pre-folded; MIN_DAMAGE=1 owned by HP/Status; DEFEND_STANCE -50% damage reduction owned by HP/Status intake pipeline.
- Line 260: `hp_status.apply_damage(defender.unit_id, result.resolved_damage, ...)` — called by **Grid Battle** (NOT Damage Calc) on HIT only.
- Line 297-299: `MIN_DAMAGE / ATK_CAP / DEF_CAP / DEFEND_STANCE_ATK_PENALTY` labelled "HP/Status owner" — these constants belong here, not in Damage Calc.
- Line 340: `hp_status.get_modified_stat(unit_id: StringName, stat_name: String) -> int` interface signature locked there; ADR-0010 ratifies.

**Note on `unit_id` parameter type**: ADR-0001 line 155 declares `unit_died(unit_id: int)` — payload is `int`. ADR-0012 lines 89/260 use `unit_id: StringName` for `get_modified_stat` and `apply_damage`. **Inconsistency**: This ADR locks `unit_id: int` to match ADR-0001's signal contract (which is the established cross-system source-of-truth per the GameBus signal Domain). ADR-0012's `StringName` parameter type is a precision-gap advisory — to be batched into ADR-0012's next amendment alongside the ADR-0007 line 372 + ADR-0005 line 168 cross-doc advisories. Migration is parameter-stable: `int` and `StringName` are not auto-coercible, so call sites in ADR-0012's prose pseudocode (line 352-353) need explicit `int` typing in the actual implementation. Documented as design-time delta-#7 godot-specialist Item to be raised.

**From `docs/registry/architecture.yaml` v3:**
- Line 293: hp-status reads `MapGrid.get_tile.occupant_id` for positional effects (DEMORALIZED radius scan).
- Line 356: hp-status reads `UnitRole.get_max_hp` (one-time per unit per battle).
- Line 388: hp-status consumes `HeroData.base_hp_seed` transitively via UnitRole.
- Line 641: Unit Role rejection of stateful cache cites HP/Status's `get_modified_stat` accessor — confirms HP/Status is the OWNER of derived-stat-with-modifiers logic.

**From `.claude/docs/technical-preferences.md`:**
- 60 fps target / 16.6 ms frame budget / 512 MB mobile.
- Naming: `class_name` PascalCase; signals snake_case past tense; constants UPPER_SNAKE_CASE.
- GdUnit4 v6.1.2 pinned for Godot 4.6.

---

## Decision

**Lock HPStatusController as a Battle-scoped Node child of BattleScene** (created on battle-init via Battle Preparation, freed automatically with BattleScene per ADR-0002). It owns a `Dictionary[int, UnitHPState]` keyed by `unit_id` (matching ADR-0001 `unit_died` payload type), exposes 8 read+write public methods, emits exactly 1 GameBus signal (`unit_died` per ADR-0001), consumes 1 Turn Order signal (`unit_turn_started` per ADR-0011 provisional), and routes ALL 27 tuning knob reads through `BalanceConstants.get_const(key)` per ADR-0006.

### §1. Module Form — Battle-Scoped Node, NOT stateless-static, NOT Autoload

```gdscript
# src/core/hp_status_controller.gd  (Node child of BattleScene; created at battle-init, freed with BattleScene)
extends Node
class_name HPStatusController

# Battle-scoped per-unit state map (Godot 4.4+ typed Dictionary; production-stable in 4.6)
var _state_by_unit: Dictionary[int, UnitHPState] = {}  # Typed Dictionary form declared directly per /architecture-review delta-#7 godot-specialist Item 1 PASS (consistency with §Architecture Diagram line 520). Tech-debt fallback path documented in Verification §2 if a 4.6 parse warning emerges at first story (unexpected per delta-#7 review).

# Test seam — direct unit_turn_started dispatch without GameBus subscription
func _apply_turn_start_tick(unit_id: int) -> void:
    """DoT tick + duration decrement + DEFEND_STANCE/DEMORALIZED expiry checks. Production: called via GameBus.unit_turn_started subscription. Tests: called directly to bypass signal infrastructure."""
    pass  # implementation in §8 + §11
```

**Justification**: HPStatusController holds 1 Dictionary of mutable per-unit state (current_hp + status_effects) that is non-persistent (CR-1b) and lifecycle-scoped to a single battle. Stateless-static utility (5-precedent ADR-0008→0007) is **architecturally incompatible** because HP/Status (a) holds mutable state — `static var` would create test-isolation hazards mirroring ADR-0005 §Alt 4 reasoning, AND (b) needs to subscribe to GameBus signals via Callable identity (Object instance required for stable connect/disconnect identity per ADR-0005 §Alt 4 finding). Autoload Node form (ADR-0005 InputRouter pattern) fails because cross-battle state survival is NOT required (CR-1b) — battle-scoped form provides cleaner non-persistence enforcement (state freed automatically when BattleScene is freed). ADR-0004 Map/Grid is the closest precedent (battle-scoped Node, freed with BattleScene, holds per-tile state). Godot-specialist Step 4.5 to confirm.

### §2. Class Naming Reconciliation

ADR-0001 line 303 prose-name `HPStatusController` is adopted as `class_name`. The GDD's "HP/Status System" prose is preserved as the human-readable system name. Registry slug `hp-status` continues to be the directory + file slug.

| Surface | Name | Rationale |
|---|---|---|
| GDScript class | `class_name HPStatusController` | Matches ADR-0001 line 303 emitter declaration; PascalCase per technical-preferences |
| Node path (in scene tree) | `BattleScene/HPStatusController` | Battle-scoped child node; freed with BattleScene |
| File path | `src/core/hp_status_controller.gd` | Core layer per architecture.md |
| System slug | `hp-status` | Matches GDD filename + epic directory (will be created on /create-epics hp-status) |
| Cross-doc system display name | "HP/Status System" / "HP/상태 시스템" | Preserved in GDDs + UI strings |

### §3. Per-Unit State Schema — `UnitHPState` RefCounted

```gdscript
# src/core/payloads/unit_hp_state.gd
class_name UnitHPState extends RefCounted

var unit_id: int                       # Matches ADR-0001 unit_died(int) signal payload type
var max_hp: int                        # Cached at battle-init via UnitRole.get_max_hp(hero, unit_class); per ADR-0009 line 328 one-time-per-battle
var current_hp: int                    # 0 ≤ current_hp ≤ max_hp invariant per CR-2; mutable via apply_damage / apply_heal / DoT tick only
var status_effects: Array              # Array[StatusEffect] — preserves insertion order for CR-5e oldest-first eviction
var hero: HeroData                     # Read-only reference to ADR-0007 HeroData (for unit_class lookup + future is_morale_anchor)
var unit_class: int                    # UnitRole.UnitClass enum value (CAVALRY=0..SCOUT=5) — cached at battle-init for PASSIVE_TAG_BY_CLASS lookup
```

**RefCounted (NOT Resource)** because: (a) battle-scoped, never serialized to disk per CR-1b non-persistence; (b) no `@export` inspector visibility required (state is internal to HPStatusController); (c) RefCounted is lighter-weight than Resource (no `resource_path`, no ResourceLoader cache participation per ADR-0007 Item 8 acknowledgement); (d) matches ADR-0012 4-RefCounted-wrapper precedent (AttackerContext / DefenderContext / ResolveModifiers / ResolveResult — all RefCounted, all per-call, all non-persistent).

### §4. `StatusEffect` Schema — Typed Resource (5 MVP types as `.tres` data assets)

```gdscript
# src/core/payloads/status_effect.gd
class_name StatusEffect extends Resource

@export var effect_id: StringName             # &"poison" / &"demoralized" / &"defend_stance" / &"inspired" / &"exhausted"
@export var effect_type: int                  # 0=BUFF, 1=DEBUFF (typed enum at @export site)
@export var duration_type: int                # 0=TURN_BASED, 1=CONDITION_BASED, 2=ACTION_LOCKED
@export var remaining_turns: int              # Mutable per turn-tick decrement; for CONDITION_BASED, this is the turn-cap (DEMORALIZED 4-turn cap per CR-6 SE-2)
@export var modifier_targets: Dictionary      # Dictionary[StringName, int] — stat_name → percent (signed, e.g., {&"atk": -25} for DEMORALIZED)
@export var tick_effect: TickEffect           # null if no tick (BUFF / non-DoT DEBUFF); non-null for POISON
@export var source_unit_id: int               # -1 if unsourced (e.g., scenario event); else attacker unit_id for attribution + DEMORALIZED recovery proximity check

# Authored as 5 .tres files in assets/data/status_effects/{poison,demoralized,defend_stance,inspired,exhausted}.tres
# HPStatusController duplicates the .tres template via .duplicate() into per-unit instances on apply_status (so remaining_turns mutation per instance does not affect template)
```

```gdscript
# src/core/payloads/tick_effect.gd
class_name TickEffect extends Resource

@export var damage_type: int                  # 0=TRUE_DAMAGE (bypass F-1 intake pipeline; direct current_hp -= dot_damage per F-3 line 366-368)
@export var dot_hp_ratio: float               # F-3 max_hp coefficient (POISON: 0.04)
@export var dot_flat: int                     # F-3 fixed addend (POISON: 3)
@export var dot_min: int                      # F-3 floor (POISON: 1)
@export var dot_max_per_turn: int             # F-3 ceiling (POISON: 20)
```

**Resource (NOT RefCounted)** because: (a) `.tres` files are the authored content surface — designers tune POISON/DEFEND_STANCE values via editor inspector + git diff; (b) `@export` typed-field inspector visibility is the Godot-idiomatic content-authoring path (matches ADR-0004 TileData + ADR-0007 HeroData precedents); (c) `.duplicate()` on apply produces per-unit instances (mutable `remaining_turns` per instance does not affect the `.tres` template; matches Godot 4.5+ `duplicate_deep` discipline if nested resources added later — currently no nested mutable fields so shallow `.duplicate()` suffices). **Note per design-time godot-specialist 2026-04-30 Item 4 advisory + /architecture-review delta-#7 review-time CONCERN Item 2 (corrected same-patch)**: shallow `duplicate()` is **intentional** (NOT `duplicate_deep()`) because `tick_effect: TickEffect` is read-only post-load — sharing the TickEffect Resource reference between template and instance is correct and matches the read-only sub-Resource pattern. Do NOT "fix" this to `duplicate_deep()` unnecessarily; the `deprecated-apis.md` entry refers to the GENERAL pattern of nested-Resource per-instance mutable copies (since 4.5), NOT to the read-only sub-Resource sharing case which is the correct pattern here. **Hot-reload behavior note (delta-#7 Item 2 added)**: in editor-mode hot-reload, edits to a `.tres` template via the Godot inspector are reflected live in all currently-applied StatusEffect instances via the shared TickEffect reference — intentional for designer iteration on POISON DoT values during playtesting. Production builds are unaffected (no hot-reload in shipped binaries). If a future status effect requires per-instance mutable sub-Resource state (e.g., a stack-counter on a buff), that effect's apply path MUST switch to `duplicate_deep()` for the affected sub-Resource — this would be a per-effect schema decision documented in the StatusEffect template's `.tres` schema, not a global pattern change.

**TickEffect as separate Resource** (not inlined into StatusEffect): allows POISON-distinct DoT formula reuse for future BURN / BLEED variants without StatusEffect schema bloat per OQ-6 (DoT type extension).

### §5. Public API — 8 Methods + 1 Signal

```gdscript
# Battle Preparation calls this once at battle-init for each participating unit
func initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void:
    """Caches max_hp via UnitRole.get_max_hp(hero, unit_class); creates UnitHPState entry. CR-1a initialization."""

# Sole damage entry — called by Grid Battle on HIT (NEVER by Damage Calc per ADR-0012 line 260)
func apply_damage(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array) -> void:
    """F-1 intake pipeline. resolved_damage clamped to [1, DAMAGE_CEILING=180] by Damage Calc upstream (ADR-0012 §F-DC-6); HP/Status enforces MIN_DAMAGE=1 again at Step 3 (dual-enforcement intentional per ADR-0012 line 92-93). attack_type ∈ {PHYSICAL=0, MAGICAL=1} per ADR-0012 §C CR-1; illegal values trigger push_error + early return (defense-in-depth per ADR-0012 line 280-281). Emits unit_died if current_hp reaches 0."""

# Healing entry — called by skills/items/scenario-events
func apply_heal(unit_id: int, raw_heal: int, source_unit_id: int) -> int:
    """F-2 healing pipeline. EXHAUSTED multiplier + overheal prevention. Returns actual heal_amount applied (0 if dead per CR-4b; actual amount up to max_hp - current_hp). Caller can inspect return for UI feedback (skip 'healed for 0' display when return is 0 per EC-09)."""

# Status effect application — called by skills/items/scenario-events/CR-7 mutex enforcement
func apply_status(unit_id: int, effect_template_id: StringName, duration_override: int, source_unit_id: int) -> bool:
    """Loads StatusEffect template from assets/data/status_effects/[effect_template_id].tres, .duplicate()s it, applies CR-5b/c/d/e rules (refresh / co-exist / slot-evict). duration_override == -1 uses template default; else overrides remaining_turns. Returns true if applied (false on rejection: CR-7 mutex violation, dead unit, unknown template). Emits no signal — Battle HUD polls get_status_effects() per frame OR subscribes to a future hp_status_changed signal in Battle HUD ADR (deferred OQ-3)."""

# Read-only queries (consumed by Damage Calc / Battle HUD / AI / Grid Battle)
func get_current_hp(unit_id: int) -> int:
    """Returns current_hp (0 if unit_id unknown — caller's responsibility to call is_alive first; defense-in-depth is push_warning + return 0)."""

func get_max_hp(unit_id: int) -> int:
    """Returns cached max_hp (the one-time UnitRole.get_max_hp value from initialize_unit). Returns 0 if unknown."""

func is_alive(unit_id: int) -> bool:
    """Returns current_hp > 0 (false for unknown unit_id)."""

func get_modified_stat(unit_id: int, stat_name: StringName) -> int:
    """F-4 modifier application. Sums modifier_targets[stat_name] across active status_effects, clamps to [MODIFIER_FLOOR, MODIFIER_CEILING], applies max(1, floor(base × (1 + total_modifier / 100))). base_stat is fetched from UnitRole accessors (get_atk / get_phys_def / get_mag_def / get_initiative / get_effective_move_range) per stat_name dispatch. **DEFEND_STANCE_ATK_PENALTY is folded in via the DEFEND_STANCE StatusEffect's modifier_targets entry {&"atk": -40} per CR-6 SE-3 — Damage Calc consumes the already-folded value and does NOT separately apply the penalty.** ADR-0012's call site (lines 352-353) reads this for AttackerContext.raw_atk + DefenderContext.raw_def per attack resolution."""

func get_status_effects(unit_id: int) -> Array:
    """Returns shallow copy of status_effects Array[StatusEffect] for the unit. Consumer mutation forbidden (codified as forbidden_pattern hp_status_consumer_mutation — mirrors ADR-0007 hero_data_consumer_mutation precedent). Battle HUD reads for icon rendering + remaining-turn display."""
```

**1 emitted signal** (already in ADR-0001 contract):
- `GameBus.unit_died(unit_id: int)` — emitted in `apply_damage` Step 4 + DoT tick Step 4 when `current_hp` reaches 0 (CR-8a). Emission ordering: AFTER `current_hp = 0` mutation, so subscribers reading `get_current_hp(unit_id)` see 0 (verification §5).

**1 consumed signal**:
- `GameBus.unit_turn_started(unit_id: int)` — Turn Order Domain per ADR-0001 line 159 (provisional ADR-0011). Triggers `_apply_turn_start_tick(unit_id)` which: (a) processes POISON DoT (F-3), (b) decrements TURN_BASED `remaining_turns`, (c) checks DEFEND_STANCE 1-turn ACTION_LOCKED expiry (CR-6 SE-3), (d) checks DEMORALIZED CONDITION_BASED recovery (ally hero ≤ 2 manhattan distance — uses MapGrid.get_tile + CR-6 SE-2 condition).

### §6. Damage Intake Pipeline (F-1) — Implementation Order

```
apply_damage(unit_id, resolved_damage, attack_type, source_flags):
    state = _state_by_unit.get(unit_id)
    if state == null or state.current_hp == 0:
        push_warning("apply_damage on dead/unknown unit_id %d" % unit_id)
        return  # silent no-op for dead; defense-in-depth for unknown

    # F-1 Step 1: Passive flat reduction (PHYSICAL + Shield Wall only)
    if attack_type == PHYSICAL and &"passive_shield_wall" in UnitRole.PASSIVE_TAG_BY_CLASS[state.unit_class]:
        post_passive = resolved_damage - BalanceConstants.get_const("SHIELD_WALL_FLAT")
    else:
        post_passive = resolved_damage

    # F-1 Step 2: Status modifier (DEFEND_STANCE first per EC-03 bind-order rule)
    # NOTE per /architecture-review delta-#7 godot-specialist Item 9 (corrected same-patch):
    # `floor()` returns float in GDScript 4.x — explicit `int(...)` cast eliminates editor SAFE-mode
    # implicit-coercion warning at the assignment site `post_passive: int = ...` and documents
    # return-type honesty. The `100.0` literal forces float division (Variant `100` could
    # otherwise yield integer division in GDScript). Same convention applied at §9 F-4 final.
    for effect in state.status_effects:
        if effect.effect_id == &"defend_stance":
            post_passive = int(floor(post_passive * (1 - BalanceConstants.get_const("DEFEND_STANCE_REDUCTION") / 100.0)))
    for effect in state.status_effects:
        if effect.effect_id == &"vulnerable":  # post-MVP
            post_passive = int(floor(post_passive * BalanceConstants.get_const("VULNERABLE_MULT")))

    # F-1 Step 3: MIN_DAMAGE floor (dual-enforced; Damage Calc enforces same value upstream)
    final_damage = max(BalanceConstants.get_const("MIN_DAMAGE"), post_passive)

    # F-1 Step 4: HP reduction + death emission
    state.current_hp = max(0, state.current_hp - final_damage)
    if state.current_hp == 0:
        GameBus.unit_died.emit(unit_id)  # AFTER mutation per Verification §5
        # CR-8c: Commander or is_morale_anchor death triggers DEMORALIZED radius
        if state.unit_class == UnitRole.UnitClass.COMMANDER:
            _propagate_demoralized_radius(state)
        # is_morale_anchor branch: DEFERRED per OQ-2 (HeroData field NOT in ADR-0007 schema)
```

**Note on `post_passive` integer**: Step 2 uses `floor()` to coerce float-multiplier intermediate to int. F-1 Step 1 result is already int. F-1 Step 3 `max()` preserves int. Cross-platform determinism follows from integer arithmetic + deterministic `floor()` semantics (Verification §1).

### §7. Healing Pipeline (F-2) — Implementation Order

```
apply_heal(unit_id, raw_heal, source_unit_id) -> int:
    state = _state_by_unit.get(unit_id)
    if state == null or state.current_hp == 0:
        return 0  # CR-4b: dead units cannot be healed

    # F-2 Step 1: raw_heal is already computed by caller (skill / item formula)
    # F-2 Step 2: EXHAUSTED multiplier (CR-4 Step 2)
    if _has_status(state, &"exhausted"):
        raw_heal = max(1, floor(raw_heal * BalanceConstants.get_const("EXHAUSTED_HEAL_MULT")))

    # F-2 Step 3: Overheal prevention
    heal_amount = min(raw_heal, state.max_hp - state.current_hp)

    # F-2 Step 4: HP increase
    state.current_hp += heal_amount

    return heal_amount  # caller inspects for UI feedback
```

### §8. Status Effect Lifecycle — Apply / Refresh / Evict / Expire

```
apply_status(unit_id, effect_template_id, duration_override, source_unit_id) -> bool:
    state = _state_by_unit.get(unit_id)
    if state == null or state.current_hp == 0:
        return false

    # CR-7 mutex enforcement
    if effect_template_id == &"defend_stance" and _has_status(state, &"exhausted"):
        return false  # "피로로 태세 유지 불가" — caller surfaces UI feedback
    if effect_template_id == &"exhausted" and _has_status(state, &"defend_stance"):
        _force_remove_status(state, &"defend_stance")  # CR-7 force-release

    # CR-5c: same effect_id refresh (no stack)
    existing = _find_status(state, effect_template_id)
    if existing != null:
        existing.remaining_turns = duration_override if duration_override >= 0 else _template_default_duration(effect_template_id)
        existing.source_unit_id = source_unit_id  # update source for DEMORALIZED recovery proximity
        return true

    # CR-5e: max slots check + oldest-first eviction (Array preserves insertion order)
    var max_slots = BalanceConstants.get_const("MAX_STATUS_EFFECTS_PER_UNIT")
    if state.status_effects.size() >= max_slots:
        state.status_effects.pop_front()  # evict oldest (insertion-order)

    # Apply: load template + duplicate + inject overrides
    var template = load("res://assets/data/status_effects/%s.tres" % effect_template_id) as StatusEffect
    if template == null:
        push_error("apply_status: unknown effect template %s" % effect_template_id)
        return false
    var instance: StatusEffect = template.duplicate()  # shallow copy; tick_effect Resource shared (read-only)
    instance.remaining_turns = duration_override if duration_override >= 0 else template.remaining_turns
    instance.source_unit_id = source_unit_id
    state.status_effects.append(instance)
    return true

_apply_turn_start_tick(unit_id):
    state = _state_by_unit.get(unit_id)
    if state == null or state.current_hp == 0:
        return

    # F-3 DoT tick (BEFORE duration decrement so DoT gets one final tick at expiry-turn)
    for effect in state.status_effects:
        if effect.tick_effect != null and effect.tick_effect.damage_type == TickEffect.TRUE_DAMAGE:
            var dot = clamp(floor(state.max_hp * effect.tick_effect.dot_hp_ratio) + effect.tick_effect.dot_flat,
                            effect.tick_effect.dot_min, effect.tick_effect.dot_max_per_turn)
            state.current_hp = max(0, state.current_hp - dot)  # bypasses F-1 intake (true damage)
            if state.current_hp == 0:
                GameBus.unit_died.emit(unit_id)  # POISON-killed unit per EC-06
                return  # don't process further effects on dead unit

    # CR-5: TURN_BASED duration decrement + expiry
    var i = state.status_effects.size() - 1
    while i >= 0:
        var effect = state.status_effects[i]
        if effect.duration_type == StatusEffect.TURN_BASED:
            effect.remaining_turns -= 1
            if effect.remaining_turns <= 0:
                state.status_effects.remove_at(i)  # expire
        elif effect.duration_type == StatusEffect.ACTION_LOCKED and effect.effect_id == &"defend_stance":
            # SE-3: 1-turn DEFEND_STANCE expiry at next unit_turn_started per CR-13 grid-battle.md ratification
            state.status_effects.remove_at(i)
        i -= 1

    # CR-6 SE-2: DEMORALIZED CONDITION_BASED recovery check (ally hero ≤ 2 manhattan)
    var demoralized = _find_status(state, &"demoralized")
    if demoralized != null and _has_ally_hero_within_radius(state, BalanceConstants.get_const("DEMORALIZED_RECOVERY_RADIUS")):
        _force_remove_status(state, &"demoralized")
```

**Note on DoT-then-decrement order**: GDD §States and Transitions line 243-245 specifies "DoT tick → 사망 체크 → duration 만료 체크/제거". This order means a POISON applied with `remaining_turns=3` ticks 3 times (turns 1, 2, 3) before expiring at end-of-turn-3 — total DoT damage = 3 ticks (correct per F-3 example: "12/turn × 3turns = 36 total"). The `_apply_turn_start_tick` order above implements this correctly.

### §9. Modifier Calculation (F-4) — `get_modified_stat`

```
get_modified_stat(unit_id, stat_name) -> int:
    state = _state_by_unit.get(unit_id)
    if state == null:
        return 0

    # Get base stat from UnitRole accessors per stat_name dispatch
    var base_stat: int
    match stat_name:
        &"atk": base_stat = UnitRole.get_atk(state.hero, state.unit_class)
        &"phys_def": base_stat = UnitRole.get_phys_def(state.hero, state.unit_class)
        &"mag_def": base_stat = UnitRole.get_mag_def(state.hero, state.unit_class)
        &"initiative": base_stat = UnitRole.get_initiative(state.hero, state.unit_class)
        &"effective_move_range": base_stat = UnitRole.get_effective_move_range(state.hero, state.unit_class)
        _:
            push_error("get_modified_stat: unknown stat_name %s" % stat_name)
            return 0

    # F-4: Sum modifier_targets[stat_name] across active effects
    var total_modifier = 0
    for effect in state.status_effects:
        if stat_name in effect.modifier_targets:
            total_modifier += effect.modifier_targets[stat_name]

    # Clamp to [MODIFIER_FLOOR, MODIFIER_CEILING] per CR-5f
    total_modifier = clamp(total_modifier,
                           BalanceConstants.get_const("MODIFIER_FLOOR"),
                           BalanceConstants.get_const("MODIFIER_CEILING"))

    # Apply: max(1, int(floor(base × (1 + total_modifier / 100.0))))
    # NOTE per /architecture-review delta-#7 godot-specialist Item 9 (corrected same-patch):
    # explicit `int(floor(...))` cast satisfies `-> int` return type without implicit
    # float→int coercion warning in editor SAFE-mode; `100.0` forces float division.
    return max(1, int(floor(base_stat * (1 + total_modifier / 100.0))))
```

**Note on EXHAUSTED move-range special case**: CR-6 SE-5 specifies `effective_move_range -1 (최소 1)` — this is NOT a percent modifier but a flat -1. ADR-0010 represents EXHAUSTED's modifier_targets as `{&"effective_move_range": -100}` would be wrong (would multiply by 0). Instead, EXHAUSTED's `modifier_targets` is empty for move_range, and `get_modified_stat(&"effective_move_range")` checks `_has_status(state, &"exhausted")` and applies `result -= BalanceConstants.get_const("EXHAUSTED_MOVE_REDUCTION")` after the F-4 calculation, then `max(1, ...)`. This is a special-case branch documented in §9 — alternative would be a typed `flat_modifier_targets` field on StatusEffect, which adds schema complexity for one edge case. Going with the special-case branch.

**Note on DEFEND_STANCE_ATK_PENALTY -40%**: DEFEND_STANCE's modifier_targets in `defend_stance.tres` includes `{&"atk": -40}`. F-4 sums + clamps + applies. Damage Calc consumes via `get_modified_stat(unit_id, &"atk")` and gets the already-folded value. This satisfies ADR-0012 line 89-93 "DEFEND_STANCE penalty pre-folded" contract. CR-13 grid-battle.md rule 4 separately enforces "DEFEND_STANCE units do NOT counter-attack" which is Grid Battle's responsibility, NOT HP/Status's.

### §10. DEFEND_STANCE + EXHAUSTED Mutex (CR-7) — Implementation

Already woven into §8 `apply_status` flow:
- EXHAUSTED → DEFEND_STANCE attempt: `apply_status(unit_id, &"defend_stance", -1, source)` returns `false`. Caller (Grid Battle action menu) surfaces "피로로 태세 유지 불가" feedback per AC-15.
- DEFEND_STANCE → EXHAUSTED apply: `apply_status(unit_id, &"exhausted", duration, source)` calls `_force_remove_status(state, &"defend_stance")` BEFORE appending EXHAUSTED. AC-16.

### §11. Death + DEMORALIZED Propagation (CR-8) — Implementation

```
_propagate_demoralized_radius(commander_state):
    var radius = BalanceConstants.get_const("DEMORALIZED_RADIUS")  # default 4
    var commander_coord = _get_unit_coord(commander_state.unit_id)  # via Grid Battle? or cached?
    var duration = BalanceConstants.get_const("DEMORALIZED_DEFAULT_DURATION")  # 4 turns

    for unit_id in _state_by_unit.keys():
        var state = _state_by_unit[unit_id]
        if state.current_hp == 0:
            continue
        if not _is_ally(commander_state, state):  # CR-8c: aligned-faction allies only
            continue
        var coord = _get_unit_coord(unit_id)
        if _manhattan_distance(commander_coord, coord) <= radius:
            apply_status(unit_id, &"demoralized", duration, commander_state.unit_id)
            # CR-5c refresh handles already-DEMORALIZED units per EC-17 (no double penalty)
```

**Cross-system call**: `_get_unit_coord(unit_id)` requires Grid Battle's spatial query. Two options: (a) HPStatusController takes a reference to MapGrid + queries `get_tile.occupant_id` to find unit position (registry line 293 already documents this consumer pattern); OR (b) Grid Battle pushes `unit_id → coord` mapping into HPStatusController on each unit move. Going with **(a) MapGrid query** for the cleaner separation — HPStatusController takes a constructor-injected MapGrid reference (Battle Preparation passes both HPStatusController and MapGrid as siblings in the BattleScene; HPStatusController accesses via `get_parent().get_node("MapGrid")` OR via explicit `_map_grid: MapGrid` field set by Battle Preparation). The latter (explicit field) is preferred for testability.

```gdscript
# HPStatusController initialization snippet (called by Battle Preparation)
var _map_grid: MapGrid  # explicit reference set by Battle Preparation; testable via test fixture inject

func _ready():
    GameBus.unit_turn_started.connect(_on_unit_turn_started)  # ADR-0011 provisional consumer

func _on_unit_turn_started(unit_id: int):
    _apply_turn_start_tick(unit_id)  # delegates to test seam method
```

### §12. 27 BalanceConstants Entries — Story-Level Same-Patch Obligation

All 27 tuning knobs from GDD §Tuning Knobs are read via `BalanceConstants.get_const(key)` per ADR-0006 5-precedent JSON pattern. The `assets/data/balance/balance_entities.json` append (27 keys + provenance comments) is a **story-level same-patch obligation** for the first hp-status implementation story (mirrors ADR-0007 §Migration Plan §4 + ADR-0009 §Migration Plan §From provisional precedent). NOT this ADR's responsibility to ship the JSON content.

| Constant | Default | Range | Owner | Notes |
|---|---|---|---|---|
| `MIN_DAMAGE` | 1 | [1, 3] | HP/Status | Dual-enforcement at Damage Calc CR-9 + HP/Status F-1 Step 3 |
| `SHIELD_WALL_FLAT` | 5 | [3, 8] | HP/Status | F-1 Step 1; PHYSICAL + passive_shield_wall only |
| `HEAL_BASE` | 15 | [5, 30] | HP/Status | F-2 fixed addend |
| `HEAL_HP_RATIO` | 0.10 | [0.05, 0.20] | HP/Status | F-2 max_hp coefficient |
| `HEAL_PER_USE_CAP` | 50 | [30, 80] | HP/Status | F-2 ceiling |
| `EXHAUSTED_HEAL_MULT` | 0.5 | [0.3, 0.7] | HP/Status | F-2 Step 2 EXHAUSTED multiplier |
| `DOT_HP_RATIO` (POISON) | 0.04 | [0.02, 0.08] | HP/Status | F-3 max_hp coefficient |
| `DOT_FLAT` (POISON) | 3 | [0, 10] | HP/Status | F-3 fixed addend |
| `DOT_MIN` (POISON) | 1 | [1, 3] | HP/Status | F-3 floor |
| `DOT_MAX_PER_TURN` (POISON) | 20 | [15, 30] | HP/Status | F-3 ceiling |
| `DEMORALIZED_ATK_REDUCTION` | -25 | [-40, -15] | HP/Status | StatusEffect modifier_targets in demoralized.tres (signed; -25 = 25% reduction) |
| `DEMORALIZED_RADIUS` | 4 | [2, 6] | HP/Status | CR-8c radius scan |
| `DEMORALIZED_TURN_CAP` | 4 | [2, 6] | HP/Status | DEMORALIZED CONDITION_BASED max duration |
| `DEMORALIZED_RECOVERY_RADIUS` | 2 | [1, 3] | HP/Status | CR-6 SE-2 ally hero proximity recovery |
| `DEMORALIZED_DEFAULT_DURATION` | 4 | [2, 6] | HP/Status | apply_status default duration_override |
| `DEFEND_STANCE_REDUCTION` | 50 | [30, 70] | HP/Status (rev 2026-04-19) | F-1 Step 2 damage reduction (signed; 50 = 50% reduction) |
| `DEFEND_STANCE_ATK_PENALTY` | -40 | [-50, -25] | HP/Status (provisional INERT per grid-battle v5.0 CR-13 rule 4) | StatusEffect modifier_targets in defend_stance.tres |
| `INSPIRED_ATK_BONUS` | 20 | [10, 30] | HP/Status | StatusEffect modifier_targets in inspired.tres |
| `INSPIRED_DURATION` | 2 | [1, 3] | HP/Status | TURN_BASED default |
| `EXHAUSTED_MOVE_REDUCTION` | 1 | [1, 2] | HP/Status | F-4 special-case branch (flat, not percent) |
| `EXHAUSTED_DEFAULT_DURATION` | 2 | [1, 3] | HP/Status | TURN_BASED default |
| `MODIFIER_FLOOR` | -50 | [-60, -20] | HP/Status | F-4 clamp |
| `MODIFIER_CEILING` | 50 | [20, 60] | HP/Status | F-4 clamp |
| `MAX_STATUS_EFFECTS_PER_UNIT` | 3 | [2, 4] | HP/Status | CR-5e slot cap |
| `ATK_CAP` | 200 | locked-not-tunable | HP/Status (consumed by Damage Calc per ADR-0012 line 297) | F-4 result is clamped by Damage Calc upstream consumer |
| `DEF_CAP` | 105 | rev 2.9.2 [1,100]→[1,105] | HP/Status (consumed by Damage Calc per ADR-0012 line 298) | Same |
| `POISON_DEFAULT_DURATION` | 3 | [2, 4] | HP/Status | TURN_BASED default per CR-6 SE-1 |

### §13. Test Seam — `_apply_turn_start_tick(unit_id)` Direct Call + DI for `_map_grid`

Mirrors ADR-0005 `_handle_event` + ADR-0012 ResolveModifiers.rng injection pattern. Test fixtures:

```gdscript
# tests/unit/core/hp_status_controller_test.gd
class_name HPStatusControllerTest extends GdUnitTestSuite

var _controller: HPStatusController
var _map_grid_stub: MapGridStub  # test stub with controlled get_tile.occupant_id values

func before_test():
    BalanceConstants._cache_loaded = false  # G-15 mirror per ADR-0006 §6
    _controller = HPStatusController.new()
    _map_grid_stub = MapGridStub.new()
    _controller._map_grid = _map_grid_stub  # DI injection
    add_child(_controller)
    # NO GameBus.unit_turn_started subscription in tests — call _apply_turn_start_tick directly

func test_poison_dot_per_turn_basic():
    # Initialize a unit
    var hero = _make_hero(base_hp_seed=50)
    _controller.initialize_unit(unit_id=1, hero, UnitRole.UnitClass.INFANTRY)
    # Apply POISON
    _controller.apply_status(1, &"poison", duration_override=3, source_unit_id=99)
    # Trigger turn-start tick directly (bypass GameBus)
    _controller._apply_turn_start_tick(1)
    # Assert HP reduction per F-3
    var max_hp = _controller.get_max_hp(1)
    var expected_dot = clamp(floor(max_hp * 0.04) + 3, 1, 20)
    assert_int(_controller.get_current_hp(1)).is_equal(max_hp - expected_dot)
```

**No DI seam needed for RNG**: HP/Status is fully deterministic given inputs. F-1/F-2/F-3/F-4 use no randomization — DamageCalc owns all RNG (per ADR-0012 line 489). Test seam is needed only for (a) bypassing GameBus signal subscription to keep tests isolated, and (b) injecting MapGrid stub for DEMORALIZED radius scan tests.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│  BattleScene (created by SceneManager per ADR-0002)                     │
│                                                                         │
│  ├─ MapGrid                  (ADR-0004; battle-scoped Node)             │
│  ├─ HPStatusController       (ADR-0010; battle-scoped Node)             │
│  │     ├─ _state_by_unit: Dictionary[int, UnitHPState]                  │
│  │     │     ├─ unit_id: int                                            │
│  │     │     ├─ max_hp: int (cached from UnitRole.get_max_hp)           │
│  │     │     ├─ current_hp: int (mutable; 0 ≤ current_hp ≤ max_hp)      │
│  │     │     ├─ status_effects: Array[StatusEffect]                     │
│  │     │     ├─ hero: HeroData (read-only ref per ADR-0007 §6)          │
│  │     │     └─ unit_class: int (cached UnitClass enum)                 │
│  │     ├─ _map_grid: MapGrid (DI for DEMORALIZED radius)                │
│  │     └─ Subscribes: GameBus.unit_turn_started (ADR-0011 provisional)  │
│  └─ GridBattleController     (ADR ⏳; battle-scoped Node — orchestrator)│
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
                                  │
       READS                      │      EMITS (1 signal on /root/GameBus)
        │                         │       │
        │  • UnitRole.get_max_hp  │       │  • unit_died(unit_id: int)
        │  • UnitRole.get_atk     │       │       (ADR-0001 Domain: HP/Status)
        │  • PASSIVE_TAG_BY_CLASS │       │
        │  • HeroDatabase         │       │
        │  • BalanceConstants     │       │  CONSUMES (1 signal)
        │  • MapGrid.get_tile     │       │  • unit_turn_started (ADR-0011)
        ▼                         │       │
                                  │
         ┌────────────────────────┴───────┐
         │ Grid Battle (orchestrator):     │
         │  hp_status.apply_damage(...)    │ (per ADR-0012 line 260)
         │  hp_status.apply_heal(...)      │
         │  hp_status.apply_status(...)    │
         └─────────────────────────────────┘
                                  │
                                  │
         ┌────────────────────────┴───────┐
         │ Damage Calc (read-only):        │
         │  hp_status.get_modified_stat(   │ (per ADR-0012 line 89-93, 340)
         │    unit_id, stat_name)          │
         │   → AttackerContext.raw_atk     │
         │   → DefenderContext.raw_def     │
         └─────────────────────────────────┘
                                  │
         ┌────────────────────────┴───────┐
         │ Battle HUD (read-only, polls):  │
         │  get_current_hp / get_max_hp /  │
         │  get_status_effects             │
         └─────────────────────────────────┘
                                  │
         ┌────────────────────────┴───────┐
         │ AI System (read-only):          │
         │  is_alive / get_current_hp /    │
         │  get_status_effects             │
         └─────────────────────────────────┘
```

### Key Interfaces

```gdscript
# Public API (consumed by Grid Battle / Damage Calc / Battle HUD / AI)
HPStatusController.initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void
HPStatusController.apply_damage(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array) -> void
HPStatusController.apply_heal(unit_id: int, raw_heal: int, source_unit_id: int) -> int
HPStatusController.apply_status(unit_id: int, effect_template_id: StringName, duration_override: int, source_unit_id: int) -> bool
HPStatusController.get_current_hp(unit_id: int) -> int
HPStatusController.get_max_hp(unit_id: int) -> int
HPStatusController.is_alive(unit_id: int) -> bool
HPStatusController.get_modified_stat(unit_id: int, stat_name: StringName) -> int
HPStatusController.get_status_effects(unit_id: int) -> Array  # shallow copy; consumer mutation forbidden

# Test seam (convention: _-prefixed; production callers forbidden)
HPStatusController._apply_turn_start_tick(unit_id: int) -> void

# Emitted signal (declared on GameBus per ADR-0001 line 155)
GameBus.unit_died(unit_id: int)

# Consumed signal (Turn Order per ADR-0011 provisional)
GameBus.unit_turn_started(unit_id: int)

# Typed payloads (in src/core/payloads/)
class_name UnitHPState extends RefCounted    # Per-unit battle-scoped state (§3)
class_name StatusEffect extends Resource     # 6 @export fields (§4); 5 .tres templates in assets/data/status_effects/
class_name TickEffect extends Resource       # 5 @export fields for DoT formula (§4); 1 .tres for poison (currently)
```

---

## Alternatives Considered

### Alternative 1: Autoload Node `/root/HPStatusManager`

- **Description**: HPStatusController as `/root/HPStatusManager` autoload, persistent across scene swaps (ADR-0005 InputRouter pattern).
- **Pros**: Cross-scene survival means HP state could span multiple battles in a chain (e.g., scenario continuity).
- **Cons**: GDD CR-1b mandates HP non-persistence between battles. Autoload form requires explicit reset between battles — extra mutation, easy to forget, error-prone. Battle-scoped Node form provides cleaner non-persistence enforcement (state freed automatically when BattleScene is freed).
- **Rejection reason**: CR-1b architectural requirement. Battle-scoped form is strictly better for non-persistent state — matches ADR-0004 Map/Grid lifecycle (also battle-scoped, also non-persistent between battles).

### Alternative 2: Per-Unit `Component` Node Attached to BattleUnit Nodes

- **Description**: Each BattleUnit Node has an HPStatusComponent child Node holding `current_hp` + `status_effects`. No central HPStatusController.
- **Pros**: Highly OO. Each unit "owns" its own state. Matches Unity-style ECS-lite patterns.
- **Cons**: (a) Cross-unit queries (DEMORALIZED radius scan, AI threat eval over multiple units) become N-way Node traversals — `get_node()` chains or `get_tree().get_nodes_in_group()` scans per query. (b) BattleUnit is not yet ADR'd (Battle Preparation provisional); coupling HP/Status's lifecycle to BattleUnit Node creates a tighter dependency than necessary. (c) Test isolation is harder — each test must build a BattleScene-shaped Node hierarchy. (d) `unit_died` signal emission per-unit via per-unit signals + bus relay would violate ADR-0001 sole-emitter contract (the bus relay would need to connect ALL per-unit signals to GameBus — N×1 fan-in, vs. centralized HPStatusController single emit).
- **Rejection reason**: Centralized HPStatusController gives cleaner cross-unit queries (Dictionary lookup vs. Node traversal), simpler test fixtures, and ADR-0001 contract compliance. The OO encapsulation gain doesn't justify the test + traversal overhead at MVP scope (≤16-24 units per battle).

### Alternative 3: Stateless-Static Utility Class (5-precedent ADR-0008→0007 pattern)

- **Description**: `class_name HPStatusController extends RefCounted` + `@abstract` + all-static methods. State held in `static var _state_by_unit: Dictionary` (process-global).
- **Pros**: Consistency with 5-precedent stateless-static pattern.
- **Cons**: **Architecturally incompatible** per ADR-0005 §Alternative 4 pattern boundary: HP/Status (a) holds mutable state — static var creates test-isolation hazards (G-15 reset becomes critical instead of automatic via fresh `.new()` per test); (b) needs to subscribe to GameBus signals via Callable identity — static-method Callable disconnect identity is undefined in GDScript 4.x for non-Object class references (same engine-level claim that rejected this form for InputRouter in ADR-0005). The 5-precedent pattern applies to stateless calculators (Damage Calc / Unit Role / Hero DB / Balance/Data / Terrain Effect — all CALLED, never LISTENING); HP/Status is BOTH stateful AND listening (Turn Order signals).
- **Rejection reason**: Engine-level structural incompatibility with signal subscription, mirroring ADR-0005 §Alt 4 finding. Pattern boundary explicitly says: stateless-static for systems CALLED; Node-based form for systems that LISTEN AND/OR hold mutable state. HP/Status is both, falling squarely into the Node-based half.

### Alternative 4: ECS-style Data + System Separation (DOTS-style)

- **Description**: HPState is a pure data Resource on each unit; HPStatusSystem is a Node iterating over all units each frame applying pipelines. No Dictionary, no per-unit state map — just an Array of HPState resources owned externally.
- **Pros**: Pure functional pipeline; composable; cache-friendly iteration.
- **Cons**: Not idiomatic to Godot 4.x — DOTS/ECS is Unity-specific. Godot's OO Node + Resource model fits this project's pattern. Frame-by-frame iteration would violate ADR-0001 batching rule (line 252) — HP intake happens on attack events, not per-frame. The Dictionary-per-unit map already provides O(1) lookup needed for individual `apply_damage` calls.
- **Rejection reason**: Not project pattern; not Godot-idiomatic. Adds framework overhead for no gain at MVP scope (<24 units per battle).

---

## Consequences

### Positive

- **Foundation 5/5 + Core 1/2 → 2/2** anticipated upon Acceptance + ADR-0011 Turn Order — closes the Core layer.
- **ADR-0012 Damage Calc's outstanding upstream soft-dep closed** — `get_modified_stat` + `apply_damage` interface signatures ratified verbatim from ADR-0012 line 89-93/260; no negotiation.
- **Pattern boundary precedent extended** — ADR-0005 established Node-based form for stateful event-listening systems; ADR-0010 extends to STATEFUL battle-scoped Node form (vs. ADR-0005's autoload Node). Reusable for future Grid Battle ADR (likely battle-scoped Node) and AI System ADR (likely battle-scoped Node).
- **Test isolation pattern proven** — DI seam mirrors ADR-0005 + ADR-0012 4-precedent; first stateful battle-scoped Node test infrastructure becomes reusable for Grid Battle + AI.
- **3 Open Questions partially resolved** — OQ-1 (resurrection mechanic deferred to VS+); OQ-2 (`is_morale_anchor` deferred post-MVP per HeroData schema gap); OQ-6 (DoT type extension scaffolded via TickEffect Resource for future BURN/BLEED).

### Negative

- **Provisional contracts to ADR-0011 + post-MVP ADR-0007 amendment** — interface drift risk if either negotiates rather than ratifies. Mitigation: 5-precedent track record (ADR-0008→0006 / ADR-0012→0009/0010/0011 / ADR-0009→0007 / ADR-0007→Formation Bonus / ADR-0005→5 downstream) shows downstream ADRs consistently ratify; risk bounded.
- **Cross-doc unit_id type inconsistency** — ADR-0001 uses `int`, ADR-0012 uses `StringName`. ADR-0010 locks `int` to match ADR-0001 (signal contract source-of-truth). Carried advisory for next ADR-0012 amendment (queues with ADR-0001 line 168 + line 372 advisories from ADR-0005 + ADR-0007 deltas).
- **27 BalanceConstants entries pending JSON authoring** — story-level same-patch obligation (mirrors ADR-0007 §Migration §4 + ADR-0009 §Migration §From provisional precedents). Implementation story 1 must ship the `balance_entities.json` append + lint validation.
- **DEFEND_STANCE_ATK_PENALTY=-40 is provisional INERT** per grid-battle v5.0 CR-13 rule 4 (DEFEND_STANCE units do not counter, so -40% ATK never applies). Documented in §12 BalanceConstants table with clear INERT label. Future mid-turn DEFEND skill design re-evaluates the value.
- **Special-case branch for EXHAUSTED move-range** in `get_modified_stat` (§9 note) — EXHAUSTED's flat -1 vs. percent modifiers schema asymmetry. Alternative was a typed `flat_modifier_targets` Dictionary on StatusEffect (more general). Special-case branch chosen for MVP simplicity; revisit if more flat-modifier effects emerge post-MVP.

### Risks

- **R-1 — Re-entrant `unit_died` emission during DEMORALIZED propagation** (CR-8c): when Commander dies, `_propagate_demoralized_radius` is called from inside `apply_damage`'s Step 4 (after `unit_died.emit`). If a DEMORALIZED-recipient subscriber synchronously calls back into `apply_damage` (e.g., a same-scene AI test fixture), recursion into a Dictionary in active-mutation is risky. **Mitigation**: ADR-0001 §5 mandate `CONNECT_DEFERRED` for cross-scene subscribers eliminates the synchronous re-entrancy. Same-scene subscribers (test fixtures, future Tutorial overlay) MUST use `CONNECT_DEFERRED` or document explicit non-re-entrant behavior. Unit test fixture for re-entrant check (subscriber that re-emits / re-applies status from within `unit_died` handler) — re-entrancy MUST be test-asserted as either safe (deferred-only) or explicitly forbidden.
- **R-2 — Status effect template `.tres` corruption / missing file**: `apply_status` `load("res://assets/data/status_effects/%s.tres")` returns `null` on missing file → `push_error` + return false (graceful). But corrupted `.tres` (malformed @export field) could load with default values silently. **Mitigation**: per-template fixture validation in `tests/unit/core/status_effect_template_test.gd` — load each of 5 templates + assert all fields are non-default (effect_id matches filename, modifier_targets non-empty for buff/debuff effects, etc.). CI lint asserts presence of all 5 expected templates.
- **R-3 — DEMORALIZED radius cross-call to MapGrid** could fail if `_map_grid` reference is null (Battle Preparation forgot DI injection). **Mitigation**: `assert(_map_grid != null, "HPStatusController._map_grid must be injected by Battle Preparation before _propagate_demoralized_radius")` in `_propagate_demoralized_radius` first line. Unit test asserts NULL injection causes assert failure (test for the safety net).
- **R-4 — Test isolation: per-test `HPStatusController.new()` instance + `_state_by_unit` reset** via `before_test()`. Without per-test fresh instance, state leaks across tests. **Mitigation**: forbidden_pattern `hp_status_static_var_state_addition` — no `static var` on HPStatusController; `_state_by_unit` is INSTANCE state (typed Dictionary on the Node). Test fixture creates fresh `HPStatusController.new()` per test (matches Damage Calc + Map/Grid test patterns). Static-lint check: `grep -c '^static var' src/core/hp_status_controller.gd` returns 0.
- **R-5 — Consumer mutation of returned `Array[StatusEffect]`** from `get_status_effects`: shallow copy returned, but the StatusEffect Resources inside are SHARED references. A consumer mutating `effect.remaining_turns` would corrupt HPStatusController's authoritative state. **Mitigation**: forbidden_pattern `hp_status_consumer_mutation` (mirrors ADR-0007 hero_data_consumer_mutation precedent); R-5 documented test asserts mutation IS visible cross-call (proving convention is sole defense). Source comment on `get_status_effects` reinforces "DO NOT MUTATE".
- **R-6 — `unit_died` emission order with respect to DoT damage stacking**: if a unit takes POISON DoT that brings HP to 0 AND has DEMORALIZED-trigger (Commander) → DEMORALIZED propagation must occur. Step §11 `_apply_turn_start_tick` returns early after first `unit_died` emission, but DEMORALIZED propagation is invoked from `apply_damage` Step 4, NOT from DoT tick. **Mitigation**: refactor to call `_propagate_demoralized_radius(state)` from BOTH `apply_damage` Step 4 AND `_apply_turn_start_tick` DoT-kill branch (when state.unit_class == COMMANDER). Documented in §6 + §11 implementation order; Validation Criterion §11 verifies DoT-killed Commander triggers radius propagation.
- **R-7 — `effect_template_id` typo silent miss**: `apply_status(unit_id, &"poson", ...)` (typo) returns `false` after `load("res://...poson.tres")` returns null. **Mitigation**: `apply_status` push_errors on unknown template (visible in editor / test logs); CI lint validates all `apply_status` call sites use one of the 5 known StringNames OR a constant-defined StringName (avoid inline literals for new effects without same-patch JSON addition).

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| hp-status.md | CR-1 HP lifecycle (init/non-persistence/reset) | §1 Battle-scoped Node; §5 `initialize_unit` at battle-init; lifecycle tied to BattleScene teardown enforces CR-1b |
| hp-status.md | CR-2 HP range invariant `0 ≤ current_hp ≤ max_hp` | §3 UnitHPState mutable only via §5 apply_damage / apply_heal / DoT; §6 / §7 / §8 enforce via `max(0, ...)` and `min(max_hp, ...)` |
| hp-status.md | CR-3 Damage intake pipeline (F-1 4 steps) | §6 implementation order with EC-03 bind-order DEFEND_STANCE-first |
| hp-status.md | CR-4 Healing pipeline (F-2 4 steps) | §7 implementation order with CR-4b dead-unit reject + CR-4a overheal prevention |
| hp-status.md | CR-5a StatusEffect 6-field schema | §4 typed Resource with @export fields; 5 .tres templates as authored content |
| hp-status.md | CR-5c same effect_id refresh | §8 `_find_status` + `remaining_turns` overwrite (no stack) |
| hp-status.md | CR-5d different effect_id co-exist | §8 Array.append after refresh check |
| hp-status.md | CR-5e MAX 3 slots, evict oldest | §8 `pop_front()` insertion-order eviction |
| hp-status.md | CR-5f modifier sum + clamp | §9 F-4 `total_modifier` sum + clamp + max(1, floor()) |
| hp-status.md | CR-6 SE-1 POISON DoT | §4 TickEffect Resource for POISON; §8 `_apply_turn_start_tick` F-3 implementation; bypasses F-1 intake (true damage) |
| hp-status.md | CR-6 SE-2 DEMORALIZED radius + recovery | §11 `_propagate_demoralized_radius` MapGrid query; §8 turn-start CONDITION_BASED recovery check via `_has_ally_hero_within_radius` |
| hp-status.md | CR-6 SE-3 DEFEND_STANCE -50% + ACTION_LOCKED | §6 F-1 Step 2 bind-order; §8 turn-start ACTION_LOCKED expiry; modifier_targets on defend_stance.tres includes -50 (damage) + -40 (atk INERT) |
| hp-status.md | CR-6 SE-4 INSPIRED ATK +20% | StatusEffect modifier_targets in inspired.tres `{&"atk": +20}` |
| hp-status.md | CR-6 SE-5 EXHAUSTED move -1 + heal -50% | §9 F-4 special-case branch for move_range flat-1; §7 F-2 Step 2 EXHAUSTED multiplier |
| hp-status.md | CR-7 DEFEND_STANCE+EXHAUSTED mutex | §10 `apply_status` early-reject + force-remove; AC-15 + AC-16 |
| hp-status.md | CR-8 Death + DEMORALIZED propagation | §6 + §11 — `unit_died` emit AFTER mutation; Commander class auto-trigger radius scan; is_morale_anchor branch DEFERRED per OQ-2 |
| hp-status.md | CR-9 MIN_DAMAGE=1 floor + overkill discard | §6 F-1 Step 3 + §12 dual-enforcement contract with Damage Calc |
| hp-status.md | F-1 damage intake formula | §6 implementation pseudocode |
| hp-status.md | F-2 healing formula | §7 implementation pseudocode |
| hp-status.md | F-3 DoT damage per turn | §8 `_apply_turn_start_tick` formula application + bypass F-1 intake |
| hp-status.md | F-4 status modifier application | §9 implementation with EXHAUSTED move-range special-case branch documented |
| hp-status.md | EC-01..EC-17 (17 edge cases) | All 17 mapped to one or more §1-§13 sections; full coverage table in `tr-registry.yaml` upon /architecture-review acceptance |
| hp-status.md | AC-01..AC-20 (20 acceptance criteria) | All 20 testable via §13 DI seam test fixtures + GdUnit4 deterministic input/output assertions |
| hp-status.md | OQ-1 Resurrection mechanic | DEFERRED to VS+ scope per GDD; ADR-0010 explicitly excludes DEAD → ALIVE transition |
| hp-status.md | OQ-2 HP carry-over (campaign) | DEFERRED to scenario continuity ADR; CR-1b non-persistence locked at MVP |
| hp-status.md | OQ-3 Additional status effects (VULNERABLE/BURN/STUN/REGENERATION) | DEFERRED to post-MVP; StatusEffect + TickEffect schema scaffolded for extension |
| hp-status.md | OQ-4 `is_morale_anchor` criteria | **DEFERRED post-MVP per ADR-0010 §ADR Dependencies Soft / Provisional (2)** — HeroData 26-field schema gap; tracked for next ADR-0007 amendment OR ADR-0014 Scenario Progression |
| hp-status.md | OQ-5 DEMORALIZED nested propagation | DEFERRED to Alpha; CR-5c refresh-only handles MVP per EC-17 |
| hp-status.md | OQ-6 DoT type extension | TickEffect Resource scaffolds the schema; MVP ships POISON only; BURN/BLEED extension is Resource addition + JSON authoring (no ADR change needed) |

---

## Performance Implications

- **CPU**: per-`apply_damage` < 0.05 ms on minimum-spec mobile (Adreno 610 / Mali-G57 class). Operations: 1 Dictionary lookup (O(1)) + 1 PASSIVE_TAG_BY_CLASS const Dictionary read + max 3 status_effects iteration (CR-5e cap) + integer arithmetic. `get_modified_stat` < 0.05 ms — 1 Dictionary lookup + 1 UnitRole accessor call + max 3 status_effects iteration + 1 clamp + 1 floor. `apply_status` < 0.10 ms (slightly higher due to template `load()` + `.duplicate()`). Headless CI throughput baseline; on-device measurement deferred per damage-calc story-010 Polish-deferral pattern (now stable at 6+ invocations).
- **Memory**: `_state_by_unit` Dictionary bounded by max units per battle (~16-24) × per-UnitHPState ~120 bytes (5 ints + 1 Array + 1 HeroData ref) = ~3 KB. Each StatusEffect instance ~80 bytes × max 3 per unit × 24 units = ~6 KB max. TOTAL HPStatusController heap footprint: < 10 KB << 512 MB mobile ceiling. Status effect template `.tres` files: 5 × ~500 bytes = ~2.5 KB shared (loaded once, .duplicate()'d per apply).
- **Load Time**: No per-battle async load — `initialize_unit` is synchronous Dictionary insertion + UnitRole.get_max_hp call (already cached in UnitRole's lazy-init JSON load per ADR-0009). Status effect templates loaded lazily on first `apply_status` for each effect_id — `load("res://...")` cost ~1 ms per template, amortized over battle.
- **Network**: N/A — HP/Status is single-player.

---

## Migration Plan

### From `[no current implementation]`
No `src/core/hp_status_controller.gd` exists; clean greenfield. First story creates the file + UnitHPState payload + StatusEffect/TickEffect Resources + 5 status effect `.tres` templates + HPStatusController skeleton with `initialize_unit` + `is_alive` + `get_current_hp` minimum API.

### From provisional ADR-0011 Turn Order signal
HPStatusController commits to `unit_turn_started(unit_id: int)` consumer contract verbatim. When ADR-0011 lands, ratification is parameter-stable; HPStatusController's `_on_unit_turn_started` handler signature matches without code change. If ADR-0011 negotiates a different payload (e.g., adds a `phase: int` parameter), this ADR-0010 must be amended (caught by `/architecture-review` cross-conflict scan).

### From `is_morale_anchor` Hero DB gap
**Current state (MVP)**: DEMORALIZED CR-6 SE-2 condition (b) is_morale_anchor heroes are DEFERRED. Only condition (a) Commander class auto-trigger and condition (c) direct skill apply work in MVP.
**Post-MVP migration path**: When `is_morale_anchor` field is added to HeroData (via ADR-0007 amendment OR scenario-side authored list), this ADR-0010's `_propagate_demoralized_radius` adds branch:
```gdscript
if state.unit_class == UnitRole.UnitClass.COMMANDER or state.hero.is_morale_anchor:
    _propagate_demoralized_radius(state)
```
Single-line addition; no schema change to UnitHPState.

### Cross-system contract migration paths
- When ADR-0011 Turn Order lands: `unit_turn_started(unit_id: int)` consumer contract ratified; no code change.
- When Battle HUD ADR lands: `get_current_hp / get_max_hp / get_status_effects` query API ratified; no code change. HUD may request additional signals (`hp_changed` / `status_effect_applied` / `status_effect_expired`) — additive ADR-0001 amendment if signal-based HUD ergonomics are preferred over polling.
- When AI System ADR lands: `is_alive / get_current_hp / get_max_hp / get_status_effects` query API ratified; no code change.
- When Grid Battle ADR lands: `apply_damage / apply_heal / apply_status` mutator call sites ratified; sole-caller contract per ADR-0012 line 260.

### Implementation-time verification follow-ups
- First HPStatusController story MUST verify cross-platform determinism (Verification §1) — same synthetic call sequence produces identical state on macOS Metal + Linux Vulkan + Windows D3D12.
- First HPStatusController story MUST verify `Dictionary[int, UnitHPState]` typed-map syntax parses without warning in Godot 4.6 stable (Verification §2) — fallback to untyped Dictionary if needed.
- First HPStatusController story MUST verify `StatusEffect.duplicate()` produces independent instances (mutation of one does not affect template or other instances) — Verification §4.
- First HPStatusController story MUST verify `unit_died` emission ordering: subscribers reading `get_current_hp(unit_id)` in the handler see 0, NOT pre-mutation value — Verification §5.

### 27 BalanceConstants entries (story-level same-patch)
First HPStatusController story appends 27 keys to `assets/data/balance/balance_entities.json` with provenance comments (`// MIN_DAMAGE owned by HP/Status; dual-enforced at Damage Calc per ADR-0012 line 92`). CI lint script (`tools/ci/lint_balance_entities_hp_status.sh`) validates all 27 keys exist + are within GDD safe ranges.

---

## Validation Criteria

1. **Battle-scoped Node lifecycle**: BattleScene `_ready()` includes `var hp_status := preload("res://src/core/hp_status_controller.gd").new(); add_child(hp_status)`; SceneManager `_free_battle_scene()` automatic teardown frees HPStatusController + all UnitHPState entries (no manual cleanup needed). Boot test verifies HPStatusController is reachable from Grid Battle's `_ready()`.
2. **22-effect-template + 5-MVP-types coverage parity**: 5 status effect `.tres` files exist at `assets/data/status_effects/{poison,demoralized,defend_stance,inspired,exhausted}.tres`; `apply_status` accepts each and produces non-null UnitHPState `status_effects` entry. CI lint validates fresh-cloned project state.
3. **Single GameBus signal emission contract**: per ADR-0001 line 155 — HPStatusController emits exactly `unit_died(unit_id: int)`; static lint `grep -c 'GameBus\.unit_died\.emit(' src/core/hp_status_controller.gd` returns ≥2 emit call sites (in `apply_damage` Step 4 AND `_apply_turn_start_tick` DoT-kill branch). Pattern restricted to `.emit(` suffix per design-time godot-specialist 2026-04-30 Item 11 to enforce non-deprecated typed-signal emission form (rejects `GameBus.emit_signal("unit_died", ...)` deprecated string-based form per `deprecated-apis.md` Patterns table) and eliminate false positives from `is_connected` / `connect` call sites.
4. **Non-emitter invariant for all non-HP/Status GameBus signals**: per ADR-0001 line 365-376 — `grep -c 'GameBus\\.' src/core/hp_status_controller.gd | grep -v '^GameBus\\.unit_died'` returns 0 emit call sites (ADR-0001 + this ADR confirm HP/Status emits ONLY unit_died; no other domain signals).
5. **DI seam test isolation**: every `tests/unit/core/hp_status_controller_test.gd` test suite calls `_apply_turn_start_tick(synthetic_unit_id)` directly (not via Godot's GameBus dispatch); `before_test()` creates fresh `HPStatusController.new()` + injects `_map_grid = MapGridStub.new()`; `BalanceConstants._cache_loaded = false` reset (G-15 mirror per ADR-0006 §6).
6. **27 BalanceConstants entries lint gate**: `tools/ci/lint_balance_entities_hp_status.sh` validates all 27 keys exist in `balance_entities.json` AND values are within GDD §Tuning Knobs safe ranges; fails CI if any key missing or out of range.
7. **Dual-enforcement of MIN_DAMAGE**: per ADR-0012 line 92 — Damage Calc enforces at every `floor()` boundary (F-DC-3 / F-DC-6 / F-DC-7); HP/Status enforces again at `apply_damage` Step 3 (intentional defense-in-depth). Test fixture: `apply_damage(unit_id=1, resolved_damage=1, attack_type=PHYSICAL, source_flags=[])` on a Shield Wall unit → `1 - 5 = -4` → `max(1, -4) = 1` → HP -= 1. AC-05.
8. **Per-method latency baseline** (headless CI): `apply_damage` < 0.05 ms; `get_modified_stat` < 0.05 ms; `apply_status` < 0.10 ms; `_apply_turn_start_tick` < 0.20 ms (max 3 status_effects × DoT/decrement). On-device measurement deferred to Polish per Polish-deferral pattern (stable at 6+ invocations as of ADR-0007).
9. **Cross-platform determinism**: same synthetic `apply_damage` / `apply_heal` / `apply_status` / `_apply_turn_start_tick` sequence produces same `current_hp` + `status_effects` final state on macOS Metal + Linux Vulkan + Windows D3D12 (no float-point math except F-2 `ceil(max_hp × HEAL_HP_RATIO)` and F-3 `floor(max_hp × DOT_HP_RATIO)`; all results are integer; deterministic by construction).
10. **`unit_died` emission ordering** (per Verification §5): `apply_damage` test where subscriber's handler reads `get_current_hp(unit_id)` MUST see 0 (not pre-mutation value). Test asserts both: subscriber receives signal AND `current_hp == 0` at handler entry.
11. **DoT-killed Commander triggers DEMORALIZED radius** (R-6 mitigation): `apply_status(commander_id, &"poison", duration=1, ...)` → `_apply_turn_start_tick(commander_id)` → POISON brings HP to 0 → `unit_died` emit → DEMORALIZED radius scan invoked. Test verifies allies in radius receive DEMORALIZED.
12. **Consumer mutation forbidden_pattern** (R-5 mitigation): `tests/unit/core/hp_status_consumer_mutation_test.gd` documents that mutating returned `Array[StatusEffect]` IS visible cross-call (proving convention is sole defense). Test serves as documented fail-state, not a passing protective test.
13. **CR-7 mutex enforcement**: `apply_status(unit_id, &"defend_stance", ...)` on EXHAUSTED unit → returns false. `apply_status(unit_id, &"exhausted", ...)` on DEFEND_STANCE unit → DEFEND_STANCE force-removed BEFORE EXHAUSTED applied. AC-15 + AC-16.

---

## Related Decisions

- **ADR-0001 GameBus** (Accepted 2026-04-18) — `signal unit_died(unit_id: int)` emitter contract ratified by ADR-0010 §5; HP/Status Domain emitter declaration line 303-307 ratified by §1 module form choice. Carried advisory for next ADR-0001 amendment: line 168 `action: String` → `action: StringName` (queues with ADR-0007 line 372 + ADR-0010-introduced ADR-0012 unit_id type advisories).
- **ADR-0004 Map/Grid** (Accepted 2026-04-20) — battle-scoped Node lifecycle precedent for ADR-0010 module form choice; `get_tile(coord) -> TileData.occupant_id` consumer contract ratified by §11 DEMORALIZED radius scan (registry line 293).
- **ADR-0006 Balance/Data** (Accepted 2026-04-30 via /architecture-review delta #9) — `BalanceConstants.get_const(key) -> Variant` consumer contract for all 27 tuning knob reads per §12; G-15 `_cache_loaded` reset obligation for HP/Status test suites per Validation §5.
- **ADR-0007 Hero Database** (Accepted 2026-04-30) — `HeroDatabase.get_hero(hero_id)` provides HeroData read; `is_morale_anchor` field gap deferred per OQ-2 (next ADR-0007 amendment OR ADR-0014 Scenario Progression).
- **ADR-0009 Unit Role** (Accepted 2026-04-28) — `UnitRole.get_max_hp` cached at battle-init per §3; PASSIVE_TAG_BY_CLASS Dictionary read in F-1 Step 1 for Shield Wall passive lookup.
- **ADR-0012 Damage Calc** (Accepted 2026-04-26) — `hp_status.apply_damage` (line 260) sole-caller-Grid-Battle contract ratified; `hp_status.get_modified_stat` (lines 89-93, 340-352) interface ratified; MIN_DAMAGE / ATK_CAP / DEF_CAP / DEFEND_STANCE_ATK_PENALTY ownership transferred to ADR-0010 §12. Carried advisory for next ADR-0012 amendment: parameter type `unit_id: StringName` (ADR-0012 lines 89/260) → `unit_id: int` to match ADR-0001 + ADR-0010 (queues with ADR-0001 line 168 + line 372 + ADR-0010-introduced cross-doc advisories).
- **Future ADR-0011 Turn Order** — will ratify `unit_turn_started(unit_id: int)` consumer contract this ADR commits to.
- **Future Battle Preparation ADR** — will ratify `initialize_unit(unit_id, hero, unit_class)` lifecycle hook + `_map_grid` DI injection contract.
- **Future Battle HUD ADR** — will ratify `get_current_hp / get_max_hp / get_status_effects` query API; may add `hp_changed / status_effect_applied / status_effect_expired` signals via additive ADR-0001 amendment.
- **Future AI System ADR** — will ratify `is_alive / get_current_hp / get_max_hp / get_status_effects` query API for threat eval + buff/debuff awareness.
- **Future Grid Battle ADR** — will ratify `apply_damage / apply_heal / apply_status` mutator sole-caller contract per ADR-0012 line 260.
