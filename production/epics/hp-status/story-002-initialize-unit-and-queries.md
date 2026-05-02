# Story 002: initialize_unit + 3 read-only queries (get_current_hp / get_max_hp / is_alive) + CR-1a init + AC-01/AC-02 invariants

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-005` (partial — initialize_unit + 3 query methods only; remaining 5 methods land in stories 003-006), `TR-hp-status-018` (unit_id: int lock from ADR-0001 line 155 signal contract source-of-truth)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status — HPStatusController battle-scoped Node + per-unit UnitHPState
**ADR Decision Summary**: §5 Public API methods — `initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void` populates `_state_by_unit[unit_id]` with a fresh UnitHPState (max_hp cached via `UnitRole.get_max_hp(hero, unit_class)` per ADR-0009 line 328 one-time-per-battle cadence; current_hp = max_hp per CR-1a; status_effects = empty Array[StatusEffect]). Read-only queries `get_current_hp / get_max_hp / is_alive` return Dictionary lookups — defense-in-depth `push_warning` + return 0 / false on unknown unit_id. CR-1b non-persistence enforced via battle-scoped Node lifecycle (state freed automatically when BattleScene is freed per ADR-0002).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Dictionary.has(key)` + `Dictionary.get(key, default)` (4.0+ stable); `UnitRole.get_max_hp(hero: HeroData, unit_class: UnitRole.UnitClass) -> int` (Foundation-layer stateless-static utility shipped via unit-role epic Complete 2026-04-28). No post-cutoff API surface in this story. Test fixture pattern: per-test fresh `HPStatusController.new()` instance + synthetic HeroData via `_make_hero()` factory + `UnitRole.UnitClass.INFANTRY` enum value.

**Control Manifest Rules (Core layer + Global)**:
- Required: same-layer Core peer call to `UnitRole.get_max_hp` permitted by architecture.md invariant #4b case (a) (Unit Role is stateless rules module); G-15 `BalanceConstants._cache_loaded = false` reset in `before_test()` (ADR-0006 §6 mirror — even though story-002 doesn't call BalanceConstants directly, the test-isolation discipline is established here for stories 003-007)
- Forbidden: HPStatusController must not subscribe to GameBus or emit any signal yet (story-006 adds GameBus.unit_turn_started subscribe; story-003 adds unit_died emit); push_warning is preferred over push_error for unknown-unit defense-in-depth (graceful degradation; ADR-0010 §5 line 211 spec)
- Guardrail: per-method latency `get_current_hp / get_max_hp / is_alive` < 0.05ms (ADR-0010 Validation §8 — but on-device measurement deferred to story-008)

---

## Acceptance Criteria

*From GDD AC-01..AC-02 + ADR-0010 §5 + §6 dead/unknown-unit defense pattern, scoped to this story:*

- [ ] **AC-1** Mirrors GDD AC-01: Given a freshly-initialized unit (`initialize_unit(1, hero, INFANTRY)`), When `get_current_hp(1)` queried, Then return value equals the cached `max_hp` from UnitRole.get_max_hp (CR-1a — every unit starts at full HP; no exception paths)
- [ ] **AC-2** Mirrors GDD AC-02: Given any unit at any moment after initialization, When `get_current_hp(unit_id)` is queried, Then `0 ≤ current_hp ≤ max_hp` invariant holds. (Story-002 only verifies the post-init equality `current_hp == max_hp`; later stories verify the bounded-range invariant after damage/heal/DoT mutations)
- [ ] **AC-3** `initialize_unit(unit_id, hero, unit_class)` populates `_state_by_unit[unit_id]` with a fresh UnitHPState whose 6 fields match exactly: `unit_id` = parameter, `max_hp` = `UnitRole.get_max_hp(hero, unit_class)`, `current_hp` = same as max_hp, `status_effects` = `[]` (empty typed Array), `hero` = parameter, `unit_class` = parameter
- [ ] **AC-4** `get_max_hp(unit_id)` returns the cached `max_hp` from initialize_unit (the one-time UnitRole.get_max_hp value); subsequent UnitRole.get_max_hp calls during battle do NOT re-query (validates one-time-per-battle cadence per ADR-0009 line 328 + ADR-0010 §3)
- [ ] **AC-5** `is_alive(unit_id)` returns `true` for a freshly-initialized unit (current_hp == max_hp > 0); returns `false` ONLY when current_hp == 0 (story-003 verifies the false branch after apply_damage; story-002 only asserts true on init)
- [ ] **AC-6** Unknown unit_id defense-in-depth: `get_current_hp(99)` (no initialize_unit call for unit_id=99) emits `push_warning("apply_damage on dead/unknown unit_id %d" % unit_id)` per ADR-0010 §6 line 239 pattern AND returns 0; `get_max_hp(99)` returns 0; `is_alive(99)` returns false. Test asserts return values; push_warning visibility is via separate test that captures stderr (or via log capture stub if available — otherwise structural existence of `push_warning` call site verified via grep)
- [ ] **AC-7** Multiple-unit registry: `initialize_unit(1, hero_a, INFANTRY)` then `initialize_unit(2, hero_b, CAVALRY)` produces 2 distinct UnitHPState entries; `get_current_hp(1)` and `get_current_hp(2)` return independent values (no shared state across unit_ids)
- [ ] **AC-8** Re-initialization safety: calling `initialize_unit(1, hero_a, INFANTRY)` twice for the same unit_id should overwrite the prior entry (idempotent at the Dictionary level — last-write-wins). Validates Battle Preparation idempotency per ADR-0010 Migration Plan §From `[no current implementation]` (defensive against re-entry of `initialize_battle` Bbeh-prep cycle; mirrors ADR-0011 turn-order initialize_battle BI-2 pattern)
- [ ] **AC-9** Regression baseline maintained: full GdUnit4 suite passes ≥660 cases (story-001 baseline 654 + ≥6 new) / 0 errors / 0 carried failures / 0 orphans

---

## Implementation Notes

*Derived from ADR-0010 §3 + §5 + §6 (defense-in-depth pattern) + Migration Plan §27 BalanceConstants + §From provisional ADR-0011 Turn Order signal:*

1. **`initialize_unit` body** — exact 6-field population:
   ```gdscript
   func initialize_unit(unit_id: int, hero: HeroData, unit_class: int) -> void:
       var state := UnitHPState.new()
       state.unit_id = unit_id
       state.max_hp = UnitRole.get_max_hp(hero, unit_class)
       state.current_hp = state.max_hp  # CR-1a: every unit starts at max_hp
       state.status_effects = []  # Array[StatusEffect] — typed empty array
       state.hero = hero
       state.unit_class = unit_class
       _state_by_unit[unit_id] = state
   ```
   No `push_warning` for re-initialize per AC-8 (silent overwrite is the contract; Battle Preparation owns the lifecycle).

2. **`get_current_hp` body** — defense-in-depth:
   ```gdscript
   func get_current_hp(unit_id: int) -> int:
       if not _state_by_unit.has(unit_id):
           push_warning("get_current_hp: unknown unit_id %d" % unit_id)
           return 0
       return _state_by_unit[unit_id].current_hp
   ```

3. **`get_max_hp` body**:
   ```gdscript
   func get_max_hp(unit_id: int) -> int:
       if not _state_by_unit.has(unit_id):
           push_warning("get_max_hp: unknown unit_id %d" % unit_id)
           return 0
       return _state_by_unit[unit_id].max_hp
   ```

4. **`is_alive` body**:
   ```gdscript
   func is_alive(unit_id: int) -> bool:
       if not _state_by_unit.has(unit_id):
           return false  # NO push_warning — is_alive is the canonical guard query; warning would log on every safe-call check
       return _state_by_unit[unit_id].current_hp > 0
   ```
   Note: `is_alive` deliberately does NOT push_warning on unknown unit_id — it's the canonical "do I exist?" query that callers (Damage Calc, AI threat eval) call defensively; warning would be noisy. ADR-0010 §5 line 217 spec says "false for unknown unit_id" (no warning specified).

5. **Test factory `_make_hero(base_hp_seed: int) -> HeroData`** per ADR-0010 §13 line 503 pattern. HeroData was shipped via hero-database epic Complete 2026-05-01; instantiation pattern for test:
   ```gdscript
   func _make_hero(base_hp_seed: int = 50) -> HeroData:
       var hero := HeroData.new()
       hero.hero_id = &"test_hero_%d" % base_hp_seed
       hero.base_hp_seed = base_hp_seed
       # ... fill other 24 required HeroData fields with sane test defaults ...
       return hero
   ```
   Reuse hero-database test factory if `tests/helpers/hero_data_factory.gd` exists (check during /dev-story); otherwise inline.

6. **G-15 `before_test()` reset list** (forward-compat for stories 003-007):
   ```gdscript
   func before_test() -> void:
       BalanceConstants._cache_loaded = false  # ADR-0006 §6 G-15 mirror — story-002 doesn't call BalanceConstants but discipline established here
       _controller = HPStatusController.new()
       add_child(_controller)
       # _map_grid injection deferred to story-006/007 when DEMORALIZED needs it
   ```

7. **No production GameBus subscribe yet**: story-002 does NOT add `_ready()` body. The `_ready()` GameBus.unit_turn_started subscription lands in story-006 alongside `_apply_turn_start_tick` body.

8. **Test file**: `tests/unit/core/hp_status_initialize_unit_test.gd` — 6-8 tests covering AC-1..AC-8 (AC-9 = full regression). Test pattern mirrors turn-order story-002 `tests/unit/core/turn_order_initialize_battle_test.gd` lifecycle hook discipline.

9. **G-14 obligation**: after writing the new test file, run `godot --headless --import --path .` BEFORE first test run if any new `.gd` file is created. Story-002 only creates 1 new `.gd` (test file) — but if the orchestrator decides to add a `_make_hero` helper file (`tests/helpers/hero_data_factory.gd`), G-14 import refresh is mandatory.

10. **No method bodies for stories 003-007 in this story**: `apply_damage`, `apply_heal`, `apply_status`, `get_modified_stat`, `get_status_effects`, `_apply_turn_start_tick` remain stubbed per story-001. This story implements ONLY `initialize_unit + get_current_hp + get_max_hp + is_alive` (4 of 9 method bodies; remaining 5 land in stories 003-006).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: `apply_damage` body + F-1 4-step pipeline + `unit_died` emit + R-1 mitigation; AC-03..06 + AC-17 (emit-only)
- **Story 004**: `apply_heal` body + F-2 4-step pipeline + EXHAUSTED multiplier + overheal prevention; AC-07..10
- **Story 005**: `apply_status` body + CR-5/CR-7 mutex + slot eviction + template load + .duplicate(); AC-11/12/15/16
- **Story 006**: `_apply_turn_start_tick` body + F-3 DoT + F-4 `get_modified_stat` + EXHAUSTED move-range special-case + GameBus.unit_turn_started subscribe + MapGrid DI; AC-13/14/19
- **Story 007**: `_propagate_demoralized_radius` body + CR-8c + R-6 dual-invocation; AC-17 (full integration) + AC-18
- **Story 008**: Perf baseline + lint scripts + CI wiring; AC-20

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1 — Initial HP equals max_hp**:
- Given: `_controller.initialize_unit(1, _make_hero(base_hp_seed=50), UnitRole.UnitClass.INFANTRY)`
- When: `_controller.get_current_hp(1)` queried
- Then: return value equals `UnitRole.get_max_hp(hero, UnitRole.UnitClass.INFANTRY)` (full HP per CR-1a)
- Edge case: hero with min base_hp_seed=10 + INFANTRY class → max_hp computed via UnitRole F-3 (story checks the actual `get_max_hp` return, not a hardcoded number, to remain robust against future UnitRole tuning)

**AC-2 — HP range invariant post-init**:
- Given: `_controller.initialize_unit(1, hero, INFANTRY)` followed by repeated `get_current_hp(1)` calls
- When: 100 successive queries (no mutations between)
- Then: every return value equals max_hp; `0 ≤ value ≤ max_hp` always (trivially holds when value == max_hp); no drift
- Edge case: confirms no internal mutation in query methods (read-only contract)

**AC-3 — initialize_unit 6-field population**:
- Given: fresh HPStatusController + `var hero = _make_hero(base_hp_seed=50)`
- When: `_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)`
- Then: directly inspect `_controller._state_by_unit[1]` (test-private access via convention `_`-prefix); state.unit_id == 1, state.max_hp == UnitRole.get_max_hp(hero, CAVALRY), state.current_hp == state.max_hp, state.status_effects == [], state.hero == hero (same reference per ADR-0010 §3 read-only ref), state.unit_class == UnitRole.UnitClass.CAVALRY
- Edge case: status_effects is empty Array (size 0), NOT null

**AC-4 — get_max_hp returns cached value**:
- Given: `initialize_unit(1, hero, INFANTRY)`
- When: `get_max_hp(1)` called immediately, then 1000 times
- Then: all 1001 calls return the same value; UnitRole.get_max_hp is NOT re-invoked (verifiable via test-side spy on UnitRole — or simply by asserting return value stability since UnitRole is deterministic stateless)
- Edge case: per ADR-0009 line 328 one-time-per-battle cadence — even if hero's underlying base_hp_seed could change (it can't post-init in MVP), `get_max_hp` returns the cached value frozen at initialize_unit time

**AC-5 — is_alive returns true on init**:
- Given: `initialize_unit(1, hero, INFANTRY)` (current_hp == max_hp > 0 trivially)
- When: `is_alive(1)` queried
- Then: returns `true`
- Edge case: zero-max_hp hero (impossible per UnitRole F-3 guarantees max_hp ≥ 1) — defensive test: a hypothetical max_hp=0 would correctly return false (current_hp 0 == 0 NOT > 0); but UnitRole F-3 guarantees ≥1 so this branch is unreachable in production

**AC-6 — Unknown unit_id defense**:
- Given: empty HPStatusController (no initialize_unit calls)
- When: `get_current_hp(99)`, `get_max_hp(99)`, `is_alive(99)` queried
- Then: get_current_hp returns 0 (with push_warning emitted to stderr — capture via `var captures: Array = []; push_warning_capture_helper(captures); _controller.get_current_hp(99); assert(captures.size() == 1)` if log capture available; else verify push_warning literal exists in source via FileAccess scan); get_max_hp returns 0 (same push_warning); is_alive returns false (NO push_warning per Implementation Note 4 spec)
- Edge case: confirms is_alive is the canonical guard query (silent on unknown) while get_*_hp are diagnostic queries (warn on unknown)

**AC-7 — Multiple-unit isolation**:
- Given: `initialize_unit(1, hero_a_seed_50, INFANTRY)` + `initialize_unit(2, hero_b_seed_80, CAVALRY)`
- When: `get_current_hp(1)`, `get_current_hp(2)`, `get_max_hp(1)`, `get_max_hp(2)`
- Then: unit 1's max_hp != unit 2's max_hp (different base_hp_seed AND different unit_class → distinct UnitRole.get_max_hp results); current_hp values match max_hp respectively; no cross-contamination
- Edge case: 16-24 simultaneous units (MVP scale) — extend test with 16 units for stress check; assert all 16 distinct

**AC-8 — Re-initialization overwrites**:
- Given: `initialize_unit(1, hero_a, INFANTRY)` + capture max_hp_v1 = `get_max_hp(1)`
- When: `initialize_unit(1, hero_b_with_higher_seed, CAVALRY)` (same unit_id=1, different hero + class)
- Then: `get_max_hp(1)` returns max_hp_v2 = UnitRole.get_max_hp(hero_b, CAVALRY) which differs from max_hp_v1; current_hp == max_hp_v2 (CR-1a applied to the NEW state; old state discarded); state.unit_class == CAVALRY (overwrote INFANTRY)
- Edge case: silent overwrite — no exception, no warning (Battle Preparation idempotency contract)

**AC-9 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`
- Then: Overall Summary ≥660 cases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/hp_status_initialize_unit_test.gd` — new file (6-8 tests covering AC-1..AC-8; AC-9 verified via full-suite regression)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story-001 (HPStatusController + UnitHPState type system); ADR-0009 ✅ Accepted (UnitRole.get_max_hp); ADR-0007 ✅ Accepted (HeroData class); unit-role epic ✅ Complete; hero-database epic ✅ Complete
- Unlocks: Stories 003, 004, 005 (all consume initialize_unit + get_current_hp + get_max_hp + is_alive query API)

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 9/9 passing (100% — 8 auto-verified via test functions + AC-9 full-suite regression)
**Test Evidence**: Logic BLOCKING gate satisfied — `tests/unit/core/hp_status_initialize_unit_test.gd` (288 LoC / 8 tests) at canonical path; 8/8 PASS standalone; full regression **657 → 665 cases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** ✅ (2nd consecutive failure-free baseline; story-001 + story-002 clean chain maintained)
**Manifest staleness check**: PASS (story 2026-04-20 = current 2026-04-20)

### Files Modified (1) + Created (1)

- **EDIT** `src/core/hp_status_controller.gd` (125 → **140 LoC**, +15) — 4 method-body stubs replaced with implementations:
  - `initialize_unit(unit_id, hero, unit_class)` — exact 6-field UnitHPState population per ADR-0010 §3 + CR-1a (current_hp = max_hp at init); UnitRole.get_max_hp call cached per ADR-0009 line 328 one-time-per-battle cadence
  - `get_current_hp(unit_id)` — Dictionary lookup + push_warning on unknown + return 0 (ADR-0010 §5 line 211 spec)
  - `get_max_hp(unit_id)` — same defense-in-depth pattern
  - `is_alive(unit_id)` — Dictionary lookup + silent on unknown (rationale comment cited inline: "is_alive is the canonical guard query; warning would log on every safe-call check") per ADR-0010 §5 line 217
  - Underscore prefix dropped from 4 implemented method parameters (S-1 forward-look from story-001 review applied)
  - 5 OTHER stubs (`apply_damage`, `apply_heal`, `apply_status`, `get_modified_stat`, `get_status_effects`, `_apply_turn_start_tick`) retain underscored params for stories 003-006
- **NEW** `tests/unit/core/hp_status_initialize_unit_test.gd` (288 LoC, 8 test functions covering AC-1..AC-8) — `_make_hero(p_base_hp_seed)` factory inline (mirrors `tests/unit/foundation/unit_role_stat_derivation_test.gd::_make_hero` precedent); `before_test()` + `after_test()` G-15 doubled cache reset (BalanceConstants `_cache_loaded` + `_cache` AND UnitRole `_coefficients_loaded` + `_coefficients` — discipline established for stories 003-007 since `initialize_unit` transitively calls UnitRole.get_max_hp → BalanceConstants.get_const)

### Deviations

NONE.

### Code Review Suggestions Captured (forward-looking; non-blocking)

- **S-1 (cosmetic)**: `_bc_script` / `_ur_script` GDScript references loaded at suite-instance level (lines 22-23). Acceptable; `static var` alternative would load once per class. Current form fine.
- **S-2 (idiom)**: `assert_bool(state.hero == hero).is_true()` — GdUnit4 v6.1.2 `assert_object(state.hero).is_same(hero)` is more idiomatic for reference-equality. Working code; idiom-only (recurring forward-look from turn-order story-001).
- **S-3 (pattern reuse opportunity)**: `_make_hero` factory now inlined in 2 test files (unit_role_stat_derivation_test.gd + hp_status_initialize_unit_test.gd); stories 003-007 will need similar fixtures. Consider hoisting to `tests/helpers/hero_data_factory.gd` at story-008 epic-terminal time IF 3+ test files duplicate the pattern.
- **S-4 (forward-look story-003+)**: AC-2 / AC-4's "100 successive queries return identical value" pattern is correct read-only contract guard under static state. After story-003 lands `apply_damage`, a stronger AC-2 variant should test "100 queries between mutations return monotonically decreasing values".
- **S-5 (cosmetic file consistency)**: 4 implemented methods drop underscore prefix; 5 stub methods retain underscored params. Visual inconsistency resolves naturally as stories 003-006 implement remaining bodies.
- **S-6 (story-002 hero null-validation deferral)**: `_make_hero` factory has only `base_hp_seed` set; UnitRole.get_max_hp only consumes that field so this works. Future stories that consume more HeroData fields (story-006 F-4 stat dispatch) may need richer factory.
- **S-7 (test bypass-seam pattern stability)**: `_state_by_unit[1]` direct private access established for AC-3 + AC-8; future stories can reuse without re-litigating. Per ADR-0010 §13 DI seam pattern.

### Engineering Discipline Applied

- **G-15** `before_test()` canonical hook + doubled `before_test()` + `after_test()` cache reset (defensive: BalanceConstants AND UnitRole both reset; discipline established for downstream stories per ADR-0010 §13 R-4)
- **G-7** verified Overall Summary count grew (657 → 665, +8 new tests; 0 silent skips)
- **G-9** paren-wrap `%` format strings throughout test file
- **G-22** test-private `_state_by_unit` direct access for AC-3 inspection per ADR-0010 §13 DI seam pattern (`_`-prefix marks test bypass-seam allowed; production callers forbidden)
- **No hardcoded HP numbers** — every test derives expected via `UnitRole.get_max_hp(hero, class)` direct invocation; robust against future UnitRole/BalanceConstants tuning

### Out-of-Scope Deviations

NONE. No GameBus subscribe/emit; no method bodies for stories 003-006; no `_propagate_demoralized_radius`; no `_apply_turn_start_tick` body; no other src/ or tests/ files modified.

### Sprint Impact

hp-status epic 2/8 stories Complete (skeleton + initialize_unit + queries). Sprint-3 day ~0-1 of 7. Baseline 657 → 665. Must-have load: S3-02 progress 2/8.

**Single-agent flow**: 1 agent invocation (74k tokens / 28 tool uses / 215s) terminated after standalone PASS, before full-regression — orchestrator-direct ran the full regression. Multi-spawn pattern NOT needed at this scale: small Logic story (~2-3h) fits cleanly in a single agent context window. Pattern stable: <3h Logic stories can use single-agent flow.
