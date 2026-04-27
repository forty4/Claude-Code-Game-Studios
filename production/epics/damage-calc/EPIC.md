# Epic: Damage Calc

> **Layer**: Feature
> **GDD**: `design/gdd/damage-calc.md` (rev 2.9.3, APPROVED post-ninth-pass + narrow re-review close-out 2026-04-20, 2335 LoC, 53 ACs)
> **Architecture Module**: Damage Calc (#11) — `src/feature/damage_calc/`
> **Status**: Ready
> **Stories**: 11/11 created (2026-04-26 — original 10; +1 via /story-readiness story-006 split) — **10/11 complete** (story-001 ✓ PR #52, story-002 ✓ PR #54, story-003 ✓ PR #56, story-004 ✓ PR #59, story-005 ✓ PR #61, story-006 ✓ PR #64 — TD-037 logged for ADR-0012 R-9 revision, story-006b ✓ PR #65 — BalanceConstants wrapper + entities.json migration, story-007 ✓ PR #67 — F-GB-PROV retirement + Grid Battle integration = vertical-slice 7/7 first-playable damage roll demo achieved, story-008 ✓ PR #68 — engine-pin + RNG replay + AC-DC-41 lint + ENGINE-CONTRACT-FINDING with TD-038/TD-039 logged, story-010 ✓ PR #70 — AC-DC-40(a) headless CI throughput + AC-DC-40(b) Polish-deferred = 5th invocation of stable 4-precedent pattern); next: `/story-readiness production/epics/damage-calc/story-009-accessibility-ui-tests.md` then `/dev-story` (Visual/Feel story; 5-6h; only remaining damage-calc story — closes the epic)
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Created**: 2026-04-26 (Sprint 1 S1-05)

## Stories

| # | Story | Type | Status | Governing ADR | Depends on |
|---|-------|------|--------|---------------|------------|
| 001 | [CI infrastructure prerequisite](story-001-ci-infrastructure-prerequisite.md) | Config/Data | **Complete (2026-04-26)** | ADR-0012 §10 | None (gates 002-010) |
| 002 | [RefCounted wrapper classes](story-002-refcounted-wrapper-classes.md) | Logic | **Complete (2026-04-26)** | ADR-0012 §2 | 001 |
| 003 | [Stage 0 — invariant guards + evasion roll](story-003-stage-0-invariant-guards-evasion.md) | Logic | **Complete (2026-04-26)** | ADR-0012 §1, §5, §12 | 002 |
| 004 | [Stage 1 — base damage + BASE_CEILING](story-004-stage-1-base-damage-base-ceiling.md) | Logic | **Complete (2026-04-26)** | ADR-0012 §7 | 003 |
| 005 | [Stage 2 — direction × passive multiplier + P_MULT_COMBINED_CAP](story-005-stage-2-direction-passive-multiplier.md) | Logic | **Complete (2026-04-26)** | ADR-0012 §7, §8 | 004 |
| 006 | [Stage 3-4 — raw + counter + result + N-1 enum-cast fix + AC-DC-51 bypass-seam](story-006-stage-3-4-raw-counter-result-construction.md) | Logic | **Complete (2026-04-27)** | ADR-0012 §1, §3, §4, §12 | 005 |
| 006b | [BalanceConstants wrapper + entities.json + migrate hardcoded constants + AC-DC-48 grep gate](story-006b-balance-constants-migration.md) | Logic | **Complete (2026-04-27)** | ADR-0012 §6 + ADR-0008 (TerrainConfig precedent) | 006 |
| 007 | [F-GB-PROV retirement + entities.yaml + Grid Battle integration](story-007-fgbprov-retirement-entities-yaml-grid-battle-integration.md) | Integration | **Complete (2026-04-27)** | ADR-0012 §9 | 006b |
| 008 | [Determinism + engine-pin + cross-platform matrix + AC-DC-41 lint](story-008-determinism-engine-pin-cross-platform.md) | Integration | **Complete (2026-04-27)** | ADR-0012 §10, §11 | 006, 001 |
| 009 | [Accessibility UI tests — TalkBack + Reduce Motion + monochrome](story-009-accessibility-ui-tests.md) | Visual/Feel | Ready | ADR-0012 §10 | 006, 001 |
| 010 | [Performance baseline — headless throughput + mobile p99](story-010-perf-baseline.md) | Logic | **Complete (2026-04-27)** | ADR-0012 Performance Implications + R-2 | 006b, 001 |

**Stories total**: 11 — 1 Config/Data, 7 Logic (incl. 006b), 2 Integration, 1 Visual/Feel. (Was 10; +1 via /story-readiness story-006 split 2026-04-26 — extracted BalanceConstants migration + AC-DC-48 grep gate from story-006 into 006b for cleaner review surface.)

**Implementation order** (vertical-slice replan 2026-04-26 + post-006-split): **Core path 001 → 002 → 003 → 004 → 005 → 006 → 006b → 007 = first-playable damage roll demo** (target: ~5/24 end of Sprint 2). **Polish stories 008 (cross-platform determinism) + 009 (a11y UI tests) + 010 (perf baseline) deferred** to a post-vertical-slice phase — story-001 already scaffolded the CI matrix that runs them weekly + on rc/* tags, so divergence still surfaces as WARN annotations during deferral. Rationale: prioritize a working damage-roll loop (story-007 Grid Battle integration end-to-end) over completing all 11 stories in sequence. Story-006 (Stage 3-4 + N-1 fix + AC-DC-51) ships first to unblock vertical-slice 6/8 demo planning; 006b (BalanceConstants migration) follows on its own PR to discharge the deferred-constants tech debt without bundling into a single oversized PR.

**AC coverage**: All 53 GDD ACs assigned across 10 stories. AC-DC-51(b) bypass-seam test class extends `GdUnitTestSuite` (Node base) per ADR-0012 §10 #4.

## Overview

Damage Calc is the synchronous, deterministic service that resolves a single attack into an integer `resolved_damage` for HP/Status to consume. It owns four stages of the attack pipeline — evasion roll, effective-stat read, terrain reduction, and direction × class × passive multiplication — and stops short of HP subtraction, Shield Wall flat reduction, and status-effect modifiers (those belong to HP/Status intake per `hp-status.md` §F-1).

Per ADR-0001 §Damage Calc (line 375), Damage Calc is on the **non-emitter list**: it owns ZERO signals, subscribes to ZERO signals, and pulls all per-attack context through direct calls. Per ADR-0012 §1, the architectural form is a stateless `class_name DamageCalc extends RefCounted` with a single `static func resolve()` method — no instance, no Node lifecycle, no autoload registration.

This epic implements the 12 architectural commitments locked by ADR-0012 plus the test infrastructure prerequisites (headless+headed CI matrix, cross-platform Metal/D3D12/Vulkan, GdUnitTestSuite-extends-Node base for AC-DC-51(b) bypass-seam, gdUnit4 addon pinning at the Godot 4.6 LTS line). It also discharges the F-GB-PROV retirement same-patch obligation (`grid-battle.md` §CR-5 Step 7 + `entities.yaml` `damage_resolve` registration + AC-DC-44 CI grep gate).

This is the **first Feature-layer epic** in the project. It exercises the provisional-dependency strategy at its 2nd invocation (precedent: ADR-0008 → ADR-0006, 2026-04-25); 4 upstream ADRs (ADR-0006/0009/0010/0011) are NOT YET WRITTEN, so stories use API-stable workarounds documented below.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0012: Damage Calc** (Accepted 2026-04-26) | Stateless `class_name DamageCalc extends RefCounted` + 4 typed RefCounted wrappers; direct-call interface from Grid Battle; per-call seeded RNG injection; 3-tier cap layering (BASE_CEILING=83 / P_MULT_COMBINED_CAP=1.31 / DAMAGE_CEILING=180); 11 tuning constants in `entities.yaml`; F-GB-PROV retirement; test infrastructure prerequisites; AC-DC-49/50 engine-pin tests; `source_flags` always-new-Array semantics. | **LOW** (no post-cutoff APIs; `RefCounted`, `class_name`, `Array[StringName]`, `randi_range`, `snappedf`, `RandomNumberGenerator` all pre-Godot-4.4 stable) |
| ADR-0001: GameBus (Accepted 2026-04-18) | Damage Calc on non-emitter list (line 375); zero signals, zero subscriptions. | LOW |
| ADR-0008: Terrain Effect (Accepted 2026-04-25) | `terrain.get_combat_modifiers(atk, def) -> CombatModifiers` returning already-clamped `terrain_def ∈ [-30, +30]` and `terrain_evasion ∈ [0, 30]`; `MAX_DEFENSE_REDUCTION = MAX_EVASION = 30` cap constants owned by Terrain Effect. | LOW |

## Provisional (soft) Dependencies — Workaround Pattern

ADR-0012 §8 commits to interface signatures verbatim from APPROVED GDD sections; upstream ADRs will *ratify* (not negotiate) when authored. Stories use these workarounds until each upstream ADR is Accepted.

| Upstream | Future ADR | Workaround pattern | Migration trigger |
|---|---|---|---|
| **Balance/Data** (`DataRegistry.get_const(key)`) | ADR-0006 (Sprint 1 S1-09 Nice-to-Have) | Direct `FileAccess.get_file_as_string` + `JSON.parse_string` read of `assets/data/balance/entities.yaml` via thin `BalanceConstants` wrapper (mirrors ADR-0008's `terrain_config.json` pattern) | ADR-0006 Accepted → swap wrapper internals to call `DataRegistry.get_const()`; call sites unchanged |
| **Unit Role** (`UnitRole.BASE_DIRECTION_MULT[3]`, `UnitRole.CLASS_DIRECTION_MULT[4][3]`) | ADR-0009 (Sprint 1 S1-06 Should-Have) | Define const tables locally in `damage_calc.gd` using `unit-role.md` §EC-7 locked values verbatim (Cavalry/Scout/Infantry/Archer × FRONT/FLANK/REAR; rev 2.8 D_mult values) | ADR-0009 Accepted → `UnitRole.gd` exports the tables; `damage_calc.gd` imports them and removes locals |
| **HP/Status** (`hp_status.get_modified_stat(unit_id, stat_name)`) | ADR-0010 (post-Sprint-1) | Define stub interface contract in test fixtures only; production call sites use the contract per `hp-status.md:508` signature | ADR-0010 Accepted → real `HPStatus.gd` implementation provides the method |
| **Turn Order** (`turn_order.get_acted_this_turn(unit_id)`) | ADR-0011 (post-Sprint-1) | Stub interface contract in test fixtures only; production call sites use the contract per `turn-order.md:397` | ADR-0011 Accepted → real `TurnOrder.gd` implementation provides the method |

ADR-0008 Terrain Effect is **already Accepted** so `terrain.get_combat_modifiers()` is a hard contract, not provisional.

## GDD Requirements (TR Coverage)

13 architectural TRs registered in `docs/architecture/tr-registry.yaml` v5; 100% covered by ADR-0012.

| TR-ID | Requirement (abbrev) | ADR Coverage |
|-------|---------------------|--------------|
| TR-damage-calc-001 | CR-1 Module type — stateless `class_name DamageCalc extends RefCounted` + static `resolve()` sole entry point | ADR-0012 §1 ✅ |
| TR-damage-calc-002 | CR-1 + CONTRACT rev 2.2 — Type boundary: 4 typed RefCounted wrappers (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`); `Array[StringName]` runtime enforcement; StringName literal release-build defense | ADR-0012 §2 ✅ |
| TR-damage-calc-003 | CR-11 + AC-DC-33-36 — Direct-call interface Grid Battle → DamageCalc.resolve(); apply_damage invoked by Grid Battle, never DamageCalc | ADR-0012 §3 ✅ |
| TR-damage-calc-004 | CR-1 + AC-DC-34/35 — Stateless / signal-free invariant per ADR-0001 non-emitter list line 375 | ADR-0012 §4 ✅ |
| TR-damage-calc-005 | CR-2 + EC-DC-14 + AC-DC-39 — Per-call seeded RNG injection via `ResolveModifiers.rng`; call-count contract 1/0/0 per non-counter/counter/skill-stub | ADR-0012 §5 ✅ |
| TR-damage-calc-006 | CR-12 + AC-DC-48 + TUNING — 11 tuning constants in `entities.yaml` via `DataRegistry.get_const()`; hardcoding banned (forbidden_pattern) | ADR-0012 §6 ✅ |
| TR-damage-calc-007 | CR-6/8/9 + F-DC-3/5/6 — 3-tier cap layering BASE_CEILING=83 / P_MULT_COMBINED_CAP=1.31 / DAMAGE_CEILING=180 in non-negotiable order | ADR-0012 §7 ✅ |
| TR-damage-calc-008 | CR-3 + Section F — 5 cross-system READ-ONLY upstream interfaces (HP/Status, Terrain Effect, Unit Role, Turn Order, Balance/Data); provisional-dependency strategy on ADR-0006/0009/0010/0011 | ADR-0012 §8 ✅ |
| TR-damage-calc-009 | AC-DC-44 + Migration Plan — F-GB-PROV retirement same-patch obligation with `entities.yaml` `damage_resolve` registration; CI grep gate | ADR-0012 §9 ✅ |
| TR-damage-calc-010 | AC-DC-37/46/47/50/51(b) — Test infrastructure prerequisites: headless+headed CI matrix, cross-platform Metal/D3D12/Vulkan, GdUnitTestSuite-extends-Node base, gdUnit4 addon pinning | ADR-0012 §10 ✅ |
| TR-damage-calc-011 | AC-DC-49 + AC-DC-50 — Engine-pin tests (`randi_range` inclusive both ends + `snappedf` round-half-away-from-zero) mandatory CI | ADR-0012 §11 ✅ |
| TR-damage-calc-012 | CR-11 + AC-DC-36 — `source_flags` always-new-Array semantics; never mutate caller; error-flag vocabulary via `.has(&"invariant_violation:reason")` | ADR-0012 §12 ✅ |
| TR-damage-calc-013 | AC-DC-40(a)/(b) + AC-DC-41 — Performance: 50µs avg headless / <1ms p99 mobile / zero Dictionary alloc inside `resolve()` body except `build_vfx_tags` | ADR-0012 Performance Implications + §1/§2 ✅ |

**Untraced requirements**: None. The 53 GDD ACs are at finer granularity than the TR layer; per-AC coverage is ratified via ADR-0012 §GDD Requirements Addressed table (FORMULA 12 + EDGE_CASE BLOCKER 15 + EDGE_CASE IMPORTANT 7 + CONTRACT 4 + DETERMINISM 3 + PERFORMANCE 2 + INTEGRATION 3 + ACCESSIBILITY 3 + TUNING 1 + VERIFY-ENGINE 2 + CONTRACT-rev-2.2 1).

## Implementation Surface

Per ADR-0012 §Implementation Guidelines #1, the epic produces the following files:

### Source files (5 GDScript files in `src/feature/damage_calc/`)

| File | Class | Role |
|------|-------|------|
| `damage_calc.gd` | `DamageCalc` (extends RefCounted) | 12-stage pipeline: invariant guards → evasion roll (F-DC-2) → base damage (F-DC-3) → direction multiplier (F-DC-4) → passive multiplier (F-DC-5) → raw damage (F-DC-6) → counter halve (F-DC-7) |
| `attacker_context.gd` | `AttackerContext` (extends RefCounted) | unit_id / unit_class / charge_active / defend_stance_active / passives — typed RefCounted wrapper, with static `make()` factory |
| `defender_context.gd` | `DefenderContext` (extends RefCounted) | unit_id / terrain_def / terrain_evasion — typed RefCounted wrapper, with static `make()` factory |
| `resolve_modifiers.gd` | `ResolveModifiers` (extends RefCounted) | attack_type / source_flags / direction_rel / is_counter / skill_id / rng / round_number / rally_bonus / formation_atk_bonus / formation_def_bonus — 10-field typed RefCounted wrapper with `make()` factory |
| `resolve_result.gd` | `ResolveResult` (extends RefCounted) | kind (HIT/MISS) / resolved_damage / attack_type / source_flags / vfx_tags — typed RefCounted wrapper with static `hit()` and `miss()` factories |

### Test files (3 test files in `tests/`)

| File | ACs covered | Runner |
|------|-------------|--------|
| `tests/unit/damage_calc/damage_calc_test.gd` | FORMULA (12) + EDGE_CASE BLOCKER (15) + EDGE_CASE IMPORTANT (7) + CONTRACT (4) + DETERMINISM (3) + PERFORMANCE (2) + TUNING (1) + VERIFY-ENGINE (2) + CONTRACT rev 2.2 (1) = 47 ACs | headless |
| `tests/integration/damage_calc/damage_calc_integration_test.gd` | INTEGRATION non-UI (3) — AC-DC-42/43/44 | headless |
| `tests/integration/damage_calc/damage_calc_ui_test.gd` | ACCESSIBILITY UI (3) — AC-DC-45/46/47 | headed (xvfb-run) |

**Total**: 53 ACs across 3 test files.

### Cross-doc same-patch obligations (per ADR-0012 §9 + Migration Plan)

These ship in the same patch as the `damage_calc.gd` source code (gated by AC-DC-44 CI grep):

1. `grid-battle.md` §CR-5 Step 7 — remove F-GB-PROV provisional formula; cite `damage-calc.md` §F-DC-1; call `DamageCalc.resolve()` directly.
2. `assets/data/balance/entities.yaml` — register `damage_resolve` formula + 11 constants (9 consumed `referenced_by: [damage-calc.md]` + 2 owned new TK-DC-1 CHARGE_BONUS + TK-DC-2 AMBUSH_BONUS + 1 owned cap P_MULT_COMBINED_CAP).
3. `docs/registry/architecture.yaml` — add `interfaces: damage_resolution` (direct_call) + 4 new `forbidden_patterns` (`damage_calc_signal_emission`, `damage_calc_state_mutation`, `damage_calc_dictionary_payload`, `hardcoded_damage_constants`). _(Already added during /architecture-decision 2026-04-26 S1-03; verify this epic does not need additional registry mutations.)_

### CI infrastructure prerequisites (per ADR-0012 §10)

These are project-wide CI changes, NOT damage-calc-specific. They unblock damage-calc story-001 and benefit all subsequent epics:

1. Headless CI matrix per push (Linux runner, GdUnit4 + headless Godot — already in place; verify ADR-0012 path coverage)
2. Headed CI via `xvfb-run` (Linux runner with virtual display) — weekly + every `rc/*` tag — **NEW**
3. Cross-platform determinism matrix: macOS Metal per-push baseline + Windows D3D12 + Linux Vulkan weekly + every `rc/*` tag — **NEW**
4. GdUnitTestSuite extends Node base for AC-DC-51(b) bypass-seam (per-test-class choice; only AC-DC-51(b) requires Node base)
5. gdUnit4 addon pinned version recorded in `tests/README.md` AND `CLAUDE.md` Engine Specialists section — **NEW**

Without items 1-3, AC-DC-25/37/46/47/50 are un-enforceable at the Beta gate (hard blocker per ADR-0012 §10 + damage-calc.md lines 2248-2264). **Story-001 must include CI workflow delta as a Config/Data sub-story; `/story-readiness` will block story-001 if prerequisite is unmet.**

## Definition of Done

This epic is **Complete** when all of the following hold:

### Source code
- [ ] All 5 GDScript files implemented in `src/feature/damage_calc/`, each with `class_name` declarations and static `make()` factories where applicable
- [ ] `DamageCalc.resolve()` implements the 12-stage pipeline per CR-1..CR-12 with the 3-tier cap layering in non-negotiable order
- [ ] Zero `signal` declarations and zero `connect(` calls in `damage_calc.gd` (static lint enforced — ADR-0012 §4)
- [ ] Zero hardcoded balance constants — all 11 read via `DataRegistry.get_const(key)` or the provisional `BalanceConstants` wrapper (ADR-0012 §6, forbidden_pattern `hardcoded_damage_constants`)
- [ ] Zero `Dictionary(` and zero standalone `{` matches inside reachable `resolve()` body except `build_vfx_tags` helper (static lint AC-DC-41)
- [ ] `source_flags` always constructed as a NEW `Array[StringName]` per ADR-0012 §12; never mutates caller's array

### Tests
- [ ] All stories implemented, reviewed, and closed via `/story-done`
- [ ] `tests/unit/damage_calc/damage_calc_test.gd` covers 47 ACs (FORMULA+EDGE_CASE+CONTRACT+DETERMINISM+PERFORMANCE+TUNING+VERIFY-ENGINE+CONTRACT-rev-2.2) — all PASS on headless CI
- [ ] `tests/integration/damage_calc/damage_calc_integration_test.gd` covers AC-DC-42/43/44 (INTEGRATION non-UI) — all PASS on headless CI
- [ ] `tests/integration/damage_calc/damage_calc_ui_test.gd` covers AC-DC-45/46/47 (ACCESSIBILITY UI) — all PASS on headed `xvfb-run` CI
- [ ] AC-DC-49 (`randi_range` inclusive both ends) + AC-DC-50 (`snappedf` round-half-away-from-zero) PASS on macOS Metal, Windows D3D12, Linux Vulkan
- [ ] AC-DC-37 cross-platform determinism: WARN tier (softened contract per ADR-0012 R-7); divergences logged but not ship-blocking
- [ ] AC-DC-40(a) <500ms for 10,000 calls in headless CI (Vertical Slice blocker)
- [ ] AC-DC-40(b) <1ms p99 on minimum-spec mobile device (Beta blocker, KEEP-through-implementation)
- [ ] AC-DC-51(b) bypass-seam test PASSES — explicit `Array[String]` field assignment + downstream `P_mult == 1.00` assertion (per ADR-0012 R-9 mitigation)

### Cross-doc obligations
- [ ] `grid-battle.md` §CR-5 Step 7 removed F-GB-PROV; cites `damage-calc.md` §F-DC-1
- [ ] `entities.yaml` registers `damage_resolve` formula + 11 constants with proper `referenced_by` audit trail
- [ ] CI grep AC-DC-44 returns 0 matches for `F-GB-PROV` in `design/`
- [ ] CI grep AC-DC-44 confirms `entities.yaml` `damage_resolve` exists

### CI infrastructure
- [ ] Headed `xvfb-run` job added to `.github/workflows/tests.yml`
- [ ] Cross-platform matrix (macOS Metal + Windows D3D12 + Linux Vulkan) added to `.github/workflows/tests.yml`
- [ ] gdUnit4 addon pinned version recorded in `tests/README.md` and `CLAUDE.md`

### Manifest staleness
- [ ] All story files embed Manifest Version `2026-04-20`; `/story-done` staleness-check passes per project convention

## Story Decomposition Strategy (preview)

`/create-stories damage-calc` will decompose this epic into ~8-10 implementable stories, expected breakdown:

1. **CI infrastructure prerequisite** (Config/Data) — headed `xvfb-run` + cross-platform matrix + gdUnit4 addon pin (gates all subsequent stories per ADR-0012 §10)
2. **Typed RefCounted wrapper classes** (Logic) — 4 wrapper classes with `class_name` + static `make()` factories
3. **CR-1..CR-3 invariant guards + Stage-0 evasion roll (F-DC-2)** (Logic) — first 3 stages of the pipeline
4. **CR-4..CR-6 base damage (F-DC-3) + BASE_CEILING cap** (Logic) — Stage-1
5. **CR-7..CR-8 direction × passive multiplier (F-DC-4 + F-DC-5)** + P_MULT_COMBINED_CAP (Logic) — Stage-2/2.5
6. **CR-9..CR-12 raw damage + counter halve + final cap + result construction (F-DC-6 + F-DC-7 + source_flags)** (Logic) — Stage-3/4 + final
7. **F-GB-PROV retirement + entities.yaml registration** (Integration + Config/Data) — same-patch obligation
8. **Engine-pin tests + cross-platform determinism** (Integration) — AC-DC-49 / AC-DC-50 / AC-DC-37
9. **Accessibility UI tests** (Visual/Feel + UI) — AC-DC-45/46/47 headed-CI tests
10. **Performance baseline + apex arithmetic verification** (Logic) — AC-DC-40(a) headless baseline; AC-DC-40(b) mobile p99 deferred to Polish per ADR-0008/scene-manager precedent if minimum-spec device unavailable at story time

Final count and sequencing locked by `/create-stories damage-calc`.

## Risks (carried from ADR-0012 + /architecture-review advisories)

| Risk | Source | Mitigation |
|------|--------|------------|
| **R-1**: ADR-0006/0009/0010/0011 propose narrower contracts than ADR-0012-locked interfaces | ADR-0012 R-1 | `/architecture-review` cross-conflict detection runs on each upstream ADR; reciprocal ADR-0012 amendment if needed (interface surface bounded — 5 method signatures across 5 systems) |
| **R-2**: Mobile p99 perf budget (<1ms) misses on minimum-spec device | ADR-0012 R-2 | AC-DC-40(b) is KEEP-through-implementation; story-N includes Polish-deferral pattern (4 invocations precedent — save-manager / map-grid / scene-manager / terrain-effect) if device unavailable |
| **R-3**: CI infrastructure prerequisite not in place at story-001 | ADR-0012 R-3 | Story-001 is the CI infrastructure sub-story; `/story-readiness` blocks story-002+ until R-3 mitigated |
| **R-4**: gdUnit4 addon version pinning drift | ADR-0012 R-4 | Pinned version recorded in `tests/README.md` + `CLAUDE.md`; CI workflow asserts pinned version |
| **R-5**: F-GB-PROV removal patch ships without `entities.yaml` registration (or vice versa) | ADR-0012 R-5 | AC-DC-44 CI grep gate — fails merge if either side missing |
| **R-7**: AC-DC-37 cross-platform divergence escalates from WARN to hard-fail | ADR-0012 R-7 | Softened contract is reversible; integer-only-math superseding ADR is the path forward if needed |
| **R-8**: Floating-point accumulation upstream of `snappedf` shifts apex arithmetic by 1 ULP across platforms | ADR-0012 R-8 + /architecture-review ADV-4 | Add full apex-path D_mult composition CI test (`D_mult = snappedf(BASE_DIRECTION_MULT[REAR] * CLASS_DIRECTION_MULT[CAVALRY][REAR], 0.01)` end-to-end) in story-N; track as TD entry |
| **R-9**: AC-DC-51(b) bypass-seam test relies on call-site type rejection that may not hard-error | ADR-0012 R-9 | Bypass-seam test must explicitly assign `Array[String]` at field level (`var ctx = AttackerContext.new(); ctx.passives = ["passive_charge_string"]`) and assert downstream `P_mult == 1.00` — NOT rely on `make()` rejecting typed-array argument |
| **ADV-1**: int↔StringName direction encoding translation responsibility unlocked | /architecture-review 2026-04-26 ADV-1 | Implicit Grid Battle responsibility; defer to future Grid Battle ADR (post-Sprint-1). Story implementation may need a temporary helper if Grid Battle not yet implementing the bridge |
| **ADV-2**: `&"foo" in Array[StringName]` is O(n) linear scan | /architecture-review 2026-04-26 ADV-2 + godot-specialist Item 11 | Adequate at MVP scale (2-5 passives/unit); code-review watchpoint if passive sets grow >10 |
| **ADV-3**: `DataRegistry.get_const(key) -> Variant` cast safety | /architecture-review 2026-04-26 ADV-3 + godot-specialist AF-2 | Recommend ADR-0006 (when authored) tighten return type or add typed variants (`get_const_int`, `get_const_float`) |

## Next Step

Run `/create-stories damage-calc` to break this epic into implementable stories.
