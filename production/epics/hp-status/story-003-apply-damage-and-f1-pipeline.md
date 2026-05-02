# Story 003: F-1 apply_damage 4-step pipeline + unit_died emit AFTER mutation + R-1 re-entrancy mitigation

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-005` (apply_damage public API), `TR-hp-status-006` (F-1 4-step pipeline + EC-03 bind-order + dual-enforcement + CR-8c death branch), `TR-hp-status-014` (R-1 re-entrant unit_died emission mitigation)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status §6 + §5 + R-1 mitigation
**ADR Decision Summary**: §6 4-step damage intake pipeline: Step 1 passive flat reduction (PHYSICAL + passive_shield_wall via UnitRole.PASSIVE_TAG_BY_CLASS); Step 2 status modifier (DEFEND_STANCE first per EC-03 bind-order rule, explicit `int(floor(post_passive * (1 - DEFEND_STANCE_REDUCTION / 100.0)))` per delta-#7 Item 9 cast); Step 3 MIN_DAMAGE floor (`max(MIN_DAMAGE, post_passive)`) — dual-enforcement with Damage Calc per ADR-0012 line 92; Step 4 HP reduction (`current_hp = max(0, current_hp - final_damage)`) + `GameBus.unit_died(unit_id)` emit AFTER mutation per Verification §5. Dead/unknown unit early-return with push_warning. CR-8c Commander class auto-trigger DEMORALIZED radius propagation in Step 4 death branch is **STUBBED** in this story (full body lands in story-007 per R-6 dual-invocation requirement).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript 4.x `floor()` returns float — explicit `int(...)` cast eliminates editor SAFE-mode implicit-coercion warning at the assignment site `post_passive: int = ...`; `100.0` literal forces float division (Variant `100` could yield integer division). `GameBus.unit_died.emit(unit_id)` typed-signal emission form (NOT deprecated `GameBus.emit_signal("unit_died", unit_id)` per `deprecated-apis.md`). `UnitRole.PASSIVE_TAG_BY_CLASS` is a const Dictionary[UnitRole.UnitClass, Array[StringName]] shipped via unit-role epic Complete 2026-04-28 (verify field exists at /dev-story spawn time).

**Control Manifest Rules (Core layer + Global)**:
- Required: typed-signal emission `GameBus.unit_died.emit(unit_id)` (NOT string-based); `BalanceConstants.get_const(key)` for MIN_DAMAGE / SHIELD_WALL_FLAT / DEFEND_STANCE_REDUCTION reads (no hardcoded numbers); G-15 `BalanceConstants._cache_loaded = false` reset in `before_test()`; G-15 ensure no static state on HPStatusController (forbidden_pattern hp_status_static_var_state_addition lands in story-008)
- Forbidden: emit `unit_died` BEFORE `current_hp = 0` mutation (Verification §5 ordering — subscribers reading `get_current_hp(unit_id)` in the handler MUST see 0); use string-based signal connect; reference shared StatusEffect Array elements without copying (story-005 owns the consumer-mutation forbidden_pattern; story-003 just iterates `state.status_effects` for DEFEND_STANCE check, doesn't return any reference outward)
- Guardrail: `apply_damage` < 0.05ms minimum-spec mobile (ADR-0010 Validation §8); on-device measurement deferred to story-008 Polish-tier per damage-calc story-010 Polish-deferral pattern (stable at 6+ invocations)

---

## Acceptance Criteria

*From GDD AC-03..AC-06 + AC-17 (emit-only) + EC-01..EC-03 + ADR-0010 §6 + Validation §3, §5, §7, §10, scoped to this story:*

- [ ] **AC-1** Mirrors GDD AC-03: Given Infantry unit (PASSIVE_TAG_BY_CLASS includes `&"passive_shield_wall"`) with current_hp=120, When `apply_damage(unit_id=1, resolved_damage=40, attack_type=PHYSICAL=0, source_flags=[])`, Then `post_passive = 40 - 5 = 35`; `final_damage = 35`; `current_hp` decrements 120 → 85
- [ ] **AC-2** Mirrors GDD AC-04: Given Infantry unit with current_hp=120, When `apply_damage(unit_id=1, resolved_damage=40, attack_type=MAGICAL=1, source_flags=[])`, Then Shield Wall NOT applied (MAGICAL bypasses Step 1 passive); `final_damage = 40`; `current_hp` decrements 120 → 80
- [ ] **AC-3** Mirrors GDD AC-05 + EC-01: Given Infantry unit with current_hp=120, When `apply_damage(unit_id=1, resolved_damage=3, attack_type=PHYSICAL, source_flags=[])`, Then Step 1 `3 - 5 = -2`; Step 3 `max(1, -2) = 1`; `final_damage = 1`; `current_hp` decrements 120 → 119 (MIN_DAMAGE floor — Shield Wall cannot reduce below MIN_DAMAGE)
- [ ] **AC-4** Mirrors GDD AC-06 + EC-02: Given any unit with DEFEND_STANCE active (modifier added via story-005 apply_status, OR injected directly into state.status_effects in test fixture) with current_hp=80, When `apply_damage(unit_id=1, resolved_damage=20, attack_type=PHYSICAL, source_flags=[])`, Then Step 2 `int(floor(20 * (1 - 50/100.0))) = int(floor(10.0)) = 10`; `final_damage = 10`; `current_hp` decrements 80 → 70 (DEFEND_STANCE_REDUCTION = 50% per ADR-0010 §12 + grid-battle.md v5.0 CR-13)
- [ ] **AC-5** EC-02 MIN_DAMAGE floor preserved under DEFEND_STANCE: Given DEFEND_STANCE-active unit, When `apply_damage(unit_id=1, resolved_damage=1, attack_type=PHYSICAL, source_flags=[])`, Then Step 2 `int(floor(1 * 0.5)) = 0`; Step 3 `max(1, 0) = 1`; `final_damage = 1`; `current_hp -= 1` (DEFEND_STANCE cannot reduce below MIN_DAMAGE — last-line-of-defense)
- [ ] **AC-6** Mirrors GDD AC-17 (emit-only branch): Given a unit at current_hp=10 (any class), When `apply_damage(unit_id=1, resolved_damage=10, attack_type=PHYSICAL, source_flags=[])` (or any input bringing HP to 0), Then `current_hp = max(0, 10 - 10) = 0`; `GameBus.unit_died.emit(unit_id)` fires AFTER the assignment (verifiable via signal spy reading `get_current_hp(unit_id)` from the handler — handler MUST see 0, NOT the pre-mutation value 10)
- [ ] **AC-7** ADR-0010 Validation §5 `unit_died` emission ordering: Test subscriber connects `GameBus.unit_died` to a handler that reads `get_current_hp(unit_id)`; on emit, the handler captures the read value; assertion: captured value is 0 (post-mutation), NOT >0 (pre-mutation value would prove Verification §5 violation)
- [ ] **AC-8** Dead/unknown unit early-return: `apply_damage(unit_id=99, resolved_damage=10, ...)` (no initialize_unit for unit_id=99) emits `push_warning("apply_damage on dead/unknown unit_id %d" % unit_id)` AND returns silently (no signal, no state mutation); same for `apply_damage(unit_id=1, ...)` when unit 1's current_hp == 0 already (idempotent dead path)
- [ ] **AC-9** Step 1 only applies to PHYSICAL + passive_shield_wall combination: Given a non-Infantry unit (e.g., CAVALRY whose PASSIVE_TAG_BY_CLASS does NOT include passive_shield_wall) with current_hp=80, When `apply_damage(unit_id=1, resolved_damage=20, attack_type=PHYSICAL, ...)`, Then Step 1 SKIPS subtraction; `post_passive = 20`; `final_damage = 20`; `current_hp -= 20`
- [ ] **AC-10** EC-03 DEFEND_STANCE-first bind-order (single-effect verification this story; multi-effect interaction tests in story-006): Story-003 verifies that DEFEND_STANCE is applied at Step 2 BEFORE the MIN_DAMAGE floor (Step 3 sequence), proven by AC-5 (DEFEND_STANCE intermediate value 0 promoted to 1 by floor)
- [ ] **AC-11** R-1 re-entrancy mitigation test: A subscriber connected with `Object.CONNECT_DEFERRED` does NOT cause synchronous re-entry into `apply_damage` from within the `unit_died` handler. Test fixture: subscriber's handler attempts `_controller.apply_damage(some_other_unit, ...)`; under CONNECT_DEFERRED, the call is queued for next idle frame and does NOT recurse into the active stack. Assertion: re-entrant `apply_damage` call observed in deferred queue, NOT in synchronous call stack (verifiable via `await get_tree().process_frame` cycle drain pattern from turn-order story-005)
- [ ] **AC-12** Commander class death branch STUB: When a Commander-class unit dies via apply_damage Step 4, `_propagate_demoralized_radius(state)` is called (story-007 implements full body); story-003 stubs it as a private method `pass`. Test asserts the stub method exists in the source via FileAccess scan; full radius-propagation behavior tested in story-007. Non-Commander-class deaths do NOT call the stub (verified via grep on call site condition `if state.unit_class == UnitRole.UnitClass.COMMANDER`)
- [ ] **AC-13** Regression baseline maintained: full GdUnit4 suite passes ≥672 cases (story-002 baseline ~660 + ≥12 new) / 0 errors / 0 carried failures / 0 orphans

---

## Implementation Notes

*Derived from ADR-0010 §6 + R-1 mitigation + Validation §3/§5/§7/§10:*

1. **`apply_damage` body** — exact 4-step structure per ADR-0010 §6 line 235-271 pseudocode, verbatim:
   ```gdscript
   func apply_damage(unit_id: int, resolved_damage: int, attack_type: int, source_flags: Array) -> void:
       var state: UnitHPState = _state_by_unit.get(unit_id)
       if state == null or state.current_hp == 0:
           push_warning("apply_damage on dead/unknown unit_id %d" % unit_id)
           return

       # F-1 Step 1: Passive flat reduction (PHYSICAL + Shield Wall only)
       const PHYSICAL := 0  # local const matches ADR-0012 §C CR-1 attack_type enum
       var post_passive: int
       if attack_type == PHYSICAL and &"passive_shield_wall" in UnitRole.PASSIVE_TAG_BY_CLASS[state.unit_class]:
           post_passive = resolved_damage - BalanceConstants.get_const("SHIELD_WALL_FLAT")
       else:
           post_passive = resolved_damage

       # F-1 Step 2: Status modifier (DEFEND_STANCE first per EC-03 bind-order rule)
       for effect in state.status_effects:
           if effect.effect_id == &"defend_stance":
               post_passive = int(floor(post_passive * (1 - BalanceConstants.get_const("DEFEND_STANCE_REDUCTION") / 100.0)))
       # NOTE: VULNERABLE post-MVP — story-003 does NOT implement; ADR-0010 §6 line 256-258 documents the future hook

       # F-1 Step 3: MIN_DAMAGE floor (dual-enforced; Damage Calc enforces same value upstream)
       var final_damage: int = max(BalanceConstants.get_const("MIN_DAMAGE"), post_passive)

       # F-1 Step 4: HP reduction + death emission
       state.current_hp = max(0, state.current_hp - final_damage)
       if state.current_hp == 0:
           GameBus.unit_died.emit(unit_id)  # AFTER mutation per Verification §5
           if state.unit_class == UnitRole.UnitClass.COMMANDER:
               _propagate_demoralized_radius(state)  # STUB body — story-007 implements
   ```

2. **`_propagate_demoralized_radius` STUB** in this story:
   ```gdscript
   # STUB — story-007 implements full body per ADR-0010 §11 + R-6 dual-invocation
   func _propagate_demoralized_radius(commander_state: UnitHPState) -> void:
       pass
   ```
   Story-003 ships this stub so that Commander-death-via-apply_damage compiles + runs without errors; story-007 fills the body AND wires the same call from `_apply_turn_start_tick` DoT-kill branch (R-6 mitigation).

3. **Verification §5 `unit_died` emission ordering test** (AC-7):
   ```gdscript
   var _captured_hp_at_emit: int = -1
   func _on_unit_died_handler(uid: int) -> void:
       _captured_hp_at_emit = _controller.get_current_hp(uid)

   func test_unit_died_emit_sees_post_mutation_zero() -> void:
       _controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
       _controller._state_by_unit[1].current_hp = 10  # synthetic low-HP setup
       GameBus.unit_died.connect(_on_unit_died_handler)
       _controller.apply_damage(1, 100, 0, [])  # 100 damage on 10 HP → final_damage clamped + HP→0 + emit
       assert_int(_captured_hp_at_emit).is_equal(0)
       GameBus.unit_died.disconnect(_on_unit_died_handler)
   ```

4. **R-1 re-entrancy test** (AC-11) using `Object.CONNECT_DEFERRED`:
   ```gdscript
   func test_unit_died_subscriber_with_deferred_does_not_synchronously_recurse() -> void:
       _controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
       _controller.initialize_unit(2, _make_hero(50), UnitRole.UnitClass.INFANTRY)
       _controller._state_by_unit[1].current_hp = 10
       _controller._state_by_unit[2].current_hp = 10
       var call_stack_depth_at_handler: int = -1
       var handler := func(_uid: int) -> void:
           call_stack_depth_at_handler = 1  # entered handler frame
           # NOTE: do NOT actually call apply_damage(2, ...) here — that would prove same-stack invocation
           # The CONNECT_DEFERRED contract is that the handler itself runs in a deferred frame
       GameBus.unit_died.connect(handler, Object.CONNECT_DEFERRED)
       _controller.apply_damage(1, 100, 0, [])
       # Synchronously: handler has NOT yet run
       assert_int(call_stack_depth_at_handler).is_equal(-1)
       # Drain deferred queue
       await get_tree().process_frame
       assert_int(call_stack_depth_at_handler).is_equal(1)
       GameBus.unit_died.disconnect(handler)
   ```

5. **DEFEND_STANCE setup in tests** (story-005 has full apply_status; story-003 needs DEFEND_STANCE active for AC-4/AC-5 — bypass via direct StatusEffect injection):
   ```gdscript
   func _attach_defend_stance(unit_id: int) -> void:
       var ds_template := load("res://assets/data/status_effects/defend_stance.tres") as StatusEffect
       var instance: StatusEffect = ds_template.duplicate()
       _controller._state_by_unit[unit_id].status_effects.append(instance)
   ```
   Production path uses `apply_status(unit_id, &"defend_stance", -1, source_unit_id)` shipped in story-005; story-003 takes the test-side shortcut to focus on F-1 pipeline correctness.

6. **G-15 `before_test()` discipline**:
   ```gdscript
   func before_test() -> void:
       BalanceConstants._cache_loaded = false  # ADR-0006 §6 G-15 mirror
       _controller = HPStatusController.new()
       add_child(_controller)
       _captured_hp_at_emit = -1  # reset signal-capture sentinel per test
   ```

7. **G-15 `after_test()` discipline** — disconnect any signal handlers connected during the test (matching connect/disconnect symmetry per turn-order story-003 method-reference handler precedent):
   ```gdscript
   func after_test() -> void:
       if GameBus.unit_died.is_connected(_on_unit_died_handler):
           GameBus.unit_died.disconnect(_on_unit_died_handler)
   ```

8. **Test file**: `tests/unit/core/hp_status_apply_damage_test.gd` — 12-15 tests covering AC-1..AC-12 (AC-13 = full regression). Use real `GameBus` autoload subscription per turn-order story-003 G-10 precedent (NO GameBusStub here).

9. **Method-reference signal handler pattern** (per turn-order story-003 lessons): use named `_on_unit_died_handler(uid: int) -> void` method, NOT inline lambdas. Sidesteps G-4 lambda primitive-capture + simplifies G-15 connect/disconnect symmetry.

10. **No `_ready()` body added in story-003**: GameBus.unit_turn_started subscription is a story-006 concern. Story-003 emits unit_died but does not subscribe to anything yet.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 004**: `apply_heal` body + F-2 4-step + AC-07..10
- **Story 005**: `apply_status` body + CR-5/CR-7 mutex + slot eviction + template load + .duplicate() + AC-11/12/15/16. **Note**: story-003 uses a test-side helper `_attach_defend_stance()` to inject DEFEND_STANCE for AC-4/AC-5; story-005 ships the canonical apply_status pathway.
- **Story 006**: `_apply_turn_start_tick` body + F-3 DoT + F-4 `get_modified_stat` + GameBus.unit_turn_started subscribe + MapGrid DI; AC-13/14/19. EC-03 multi-effect bind-order (DEFEND_STANCE + VULNERABLE) is post-MVP per ADR-0010 §6 line 256-258 — story-006 stubs the future hook.
- **Story 007**: `_propagate_demoralized_radius` full body + R-6 dual-invocation. Story-003 ships the call site at apply_damage Step 4 + the stub method body.
- **Story 008**: Perf baseline + lint scripts (including hp_status_re_entrant_emit_without_deferred forbidden_pattern that polices story-003's R-1 mitigation).

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1 — PHYSICAL + Shield Wall basic case (GDD AC-03)**:
- Given: Infantry unit (initialize_unit + class with passive_shield_wall in PASSIVE_TAG_BY_CLASS) with current_hp = 120 (force via direct `_state_by_unit[1].current_hp = 120` setup)
- When: `_controller.apply_damage(1, 40, 0, [])` (PHYSICAL=0)
- Then: `_controller.get_current_hp(1) == 85` (40 - 5 = 35 damage)
- Edge case: Verify SHIELD_WALL_FLAT value matches BalanceConstants.get_const("SHIELD_WALL_FLAT") return (5 per ADR-0010 §12 default; not hardcoded in test)

**AC-2 — MAGICAL bypasses Shield Wall (GDD AC-04)**:
- Given: Same Infantry setup, current_hp = 120
- When: `apply_damage(1, 40, 1, [])` (MAGICAL=1)
- Then: `get_current_hp(1) == 80` (full 40 damage; Shield Wall not applied)

**AC-3 — MIN_DAMAGE floor under Shield Wall (GDD AC-05 / EC-01)**:
- Given: Infantry, current_hp = 120
- When: `apply_damage(1, 3, 0, [])` (PHYSICAL=0, low damage)
- Then: `get_current_hp(1) == 119` (3 - 5 = -2 → max(1, -2) = 1; HP -= 1)

**AC-4 — DEFEND_STANCE -50% reduction (GDD AC-06)**:
- Given: any unit with `_attach_defend_stance(1)` test helper applied, current_hp = 80
- When: `apply_damage(1, 20, 0, [])`
- Then: `get_current_hp(1) == 70` (`int(floor(20 * 0.5)) = 10` damage)

**AC-5 — DEFEND_STANCE + MIN_DAMAGE floor combined (EC-02)**:
- Given: DEFEND_STANCE-active unit, current_hp = 80
- When: `apply_damage(1, 1, 0, [])` (smallest legal damage input)
- Then: `get_current_hp(1) == 79` (`int(floor(1 * 0.5)) = 0` → `max(1, 0) = 1`; HP -= 1)

**AC-6 — current_hp reaches 0 + unit_died emit (GDD AC-17 emit-only)**:
- Given: any unit, current_hp = 10
- When: `apply_damage(1, 10, 0, [])` (no Shield Wall, no DEFEND_STANCE)
- Then: `get_current_hp(1) == 0`; `GameBus.unit_died` was emitted with payload uid == 1 (verified via signal spy)

**AC-7 — Verification §5 emit ordering**:
- Given: connected handler `func _on(uid): _captured = _controller.get_current_hp(uid)`
- When: apply_damage brings HP to 0 + emit fires
- Then: `_captured == 0` (NOT pre-mutation value); proves emit ordering AFTER `current_hp = 0` assignment

**AC-8 — Dead / unknown unit early-return**:
- Given: empty controller (no init for unit 99) OR unit 1 with current_hp = 0
- When: `apply_damage(99, 10, 0, [])` and `apply_damage(1, 10, 0, [])` (already-dead branch)
- Then: push_warning observed (capture or grep verify); no signal emitted; no state mutation; method returns silently

**AC-9 — Non-Shield-Wall class skips Step 1**:
- Given: CAVALRY unit (no passive_shield_wall in PASSIVE_TAG_BY_CLASS), current_hp = 80
- When: `apply_damage(1, 20, 0, [])` (PHYSICAL=0)
- Then: `get_current_hp(1) == 60` (full 20 damage; Step 1 skipped)

**AC-10 — DEFEND_STANCE bind-order verification**:
- Given: DEFEND_STANCE-active unit with current_hp = 80
- When: `apply_damage(1, 1, 0, [])` (verifies AC-5 path)
- Then: AC-5 result confirms Step 2 BEFORE Step 3 (otherwise DEFEND_STANCE would zero out before MIN_DAMAGE floor protection)

**AC-11 — R-1 CONNECT_DEFERRED non-recursion**:
- Given: subscriber connected with `Object.CONNECT_DEFERRED`
- When: apply_damage emits unit_died
- Then: handler runs in deferred frame (verified via process_frame await pattern); no synchronous recursion observed (call_stack_depth_at_handler -1 → 1 only after process_frame)

**AC-12 — Commander stub call site**:
- Given: Commander-class unit at low HP
- When: apply_damage brings HP to 0
- Then: `_propagate_demoralized_radius` method is called (verifiable via FileAccess scan for the call site); body is `pass` (story-007 implements). Non-Commander deaths do NOT enter this branch.

**AC-13 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: full-suite headless run
- Then: ≥672 cases / 0 errors / 0 failures / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/hp_status_apply_damage_test.gd` — new file (12-15 tests covering AC-1..AC-12; AC-13 verified via full-suite regression)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 + 002 (HPStatusController + UnitHPState + initialize_unit + queries); ADR-0001 ✅ Accepted (`unit_died` signal contract); ADR-0006 ✅ Accepted (BalanceConstants); ADR-0009 ✅ Accepted (UnitRole.PASSIVE_TAG_BY_CLASS); ADR-0010 ✅ Accepted; balance-data + unit-role + hero-database + map-grid + gamebus epics ✅ Complete
- Unlocks: Story 007 (full `_propagate_demoralized_radius` body — apply_damage Step 4 already wires the call site); story-008 (re_entrant_emit_without_deferred forbidden_pattern lint registration)

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 13/13 passing (100% — 12 auto-verified via test functions in `tests/unit/core/hp_status_apply_damage_test.gd` + AC-10 structurally covered via AC-5 path + AC-13 full-suite regression)
**Test Evidence**: Logic BLOCKING gate satisfied — `tests/unit/core/hp_status_apply_damage_test.gd` (407 LoC / 14 tests) at canonical path; standalone 14/14 PASS (97ms); full regression **665 → 679 cases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** ✅ (3rd consecutive failure-free baseline; story-001 + story-002 + story-003 clean chain)
**Manifest staleness check**: PASS (story 2026-04-20 = current 2026-04-20)

### Files Modified (1) + Created (1)

- **EDIT** `src/core/hp_status_controller.gd` (140 → **185 LoC**, +45) — `apply_damage(unit_id, resolved_damage, attack_type, source_flags)` body fills the F-1 4-step pipeline per ADR-0010 §6 lines 232-271 verbatim:
  - **Step 1** (passive flat reduction): PHYSICAL + `passive_shield_wall` lookup via `UnitRole.PASSIVE_TAG_BY_CLASS[state.unit_class] == &"passive_shield_wall"` → `SHIELD_WALL_FLAT` subtract
  - **Step 2** (status modifier): DEFEND_STANCE first per EC-03 bind-order rule; explicit `int(floor(post_passive * (1.0 - DEFEND_STANCE_REDUCTION/100.0)))` cast per delta-#7 godot-specialist Item 9
  - **Step 3** (MIN_DAMAGE floor): `maxi(BalanceConstants.get_const("MIN_DAMAGE") as int, post_passive)` typed int max
  - **Step 4** (HP reduction + emit): `state.current_hp = maxi(0, state.current_hp - final_damage)` mutation FIRST + `GameBus.unit_died.emit(unit_id)` AFTER per Verification §5 + Commander class auto-trigger `_propagate_demoralized_radius(state)` per CR-8c
  - Dead/unknown unit early-return with push_warning (defense-in-depth)
  - Underscore prefix dropped from apply_damage parameters per S-1 forward-look pattern from story-002
  - NEW private `_propagate_demoralized_radius(_commander_state)` STUB method (`pass` body; story-007 implements full body per ADR-0010 §11 + R-6 dual-invocation)
- **NEW** `tests/unit/core/hp_status_apply_damage_test.gd` (407 LoC, **14 test functions** covering AC-1..AC-12 + bonus regression for non-Commander branch):
  - Method-reference signal handlers (`_on_unit_died_handler` sync + `_deferred_unit_died_handler` deferred) — sidesteps G-4 lambda primitive-capture trap
  - `_attach_defend_stance(unit_id)` test-side helper (bypasses apply_status — story-005 ships canonical pathway)
  - `before_test()` doubled cache reset (BalanceConstants + UnitRole) + GameBus.unit_died.connect; `after_test()` matching disconnect symmetry
  - AC-11 R-1 mitigation test: connects SECOND subscriber with `Object.CONNECT_DEFERRED` alongside standard sync handler; verifies deferred fires only after `process_frame` drain
  - AC-7 Verification §5 ordering: subscriber captures `get_current_hp(uid)` from handler; assertion proves AFTER-mutation emit
  - AC-12 dual coverage: functional (a) Commander death stub-trigger doesn't crash + structural (b) FileAccess source-content scan asserts call site + COMMANDER guard present

### Deviations

- **MINOR DEVIATION (verified benign + documented inline)**: PASSIVE_TAG_BY_CLASS access pattern uses `==` (single StringName equality) instead of ADR-0010 §6 pseudocode `&"passive_shield_wall" in UnitRole.PASSIVE_TAG_BY_CLASS[state.unit_class]` (Array containment). Verified at `src/foundation/unit_role.gd:35-42` that data structure ships single-StringName values per UnitClass (CAVALRY=&"passive_charge", INFANTRY=&"passive_shield_wall", etc.) — NOT Array. ADR pseudocode was prose-level approximation; agent's inline NOTE (lines 72-74) explains the choice. Functional behavior identical for current data shape; fragility surfaces only if any future class acquires multiple passives (regression-detectable via existing AC-1/AC-9 tests).

### Code Review Suggestions Captured (forward-looking; non-blocking)

- **S-1 (DOCUMENTED, verified benign)**: PASSIVE_TAG_BY_CLASS == vs ADR pseudocode in — single-StringName structure verified; inline NOTE accurate. Watch for unit-role schema changes that could break this assumption.
- **S-2 (cosmetic)**: Doc comments still say "Implemented by story-N." even after stories Complete. Forward-look: at story-008 epic-terminal, sweep these annotations or replace with `✅ Implemented` markers.
- **S-3 (test pattern reuse opportunity)**: 3rd HP/Status test file inlining `_make_hero` + 1st using `_attach_defend_stance`. If 4+ test files duplicate, hoist to `tests/helpers/hp_status_test_factories.gd` at story-008.
- **S-4 (forward-look story-006)**: `await get_tree().process_frame` deferred-queue drain pattern stable now at 3 occurrences (turn-order story-003 + story-005 + hp-status story-003). Codify as project test pattern.
- **S-5 (test fragility note)**: AC-12(b) FileAccess source-content scan asserts `_propagate_demoralized_radius(state)` literal exists. Robust to story-007 body fill; fragile to story-007 wrapping the call. Acceptable trade-off.
- **S-6 (cosmetic)**: VULNERABLE forward-hook comment at line 88 documents post-MVP behavior; if VULNERABLE becomes a separate ADR/story, this comment should migrate accordingly.
- **S-7 (forward-look story-008)**: `lint_balance_constants_overwrite_grep_audit.sh` (carry-forward from story-001) is now relevant — story-003 reads 3 BalanceConstants keys (SHIELD_WALL_FLAT / DEFEND_STANCE_REDUCTION / MIN_DAMAGE). The proposed lint would catch future ADR-amendment value changes that could break apply_damage.
- **S-8 (Step 2 design-look)**: status_effects loop iterates ≤3 times (MAX_STATUS_EFFECTS_PER_UNIT cap); acceptable per ADR-0010 §Performance. Future story-005 may consider `_has_defend_stance: bool` cached field if perf becomes a concern; not warranted yet.

### Engineering Discipline Applied

- **G-4** sidestepped via method-reference handlers (instance var writes propagate; lambda primitive-capture trap avoided)
- **G-7** verified Overall Summary count grew (665 → 679, +14 new tests; 0 silent skips)
- **G-9** paren-wrap `%` format strings throughout test file
- **G-10** real `/root/GameBus` autoload subscription (NOT GameBusStub) per ADR-0001 single-emitter rule
- **G-15** `before_test()` connect + `after_test()` disconnect symmetry; doubled cache reset (BalanceConstants + UnitRole)
- **G-22** test-private `_state_by_unit` direct access for forced-state setup (e.g., `_controller._state_by_unit[1].current_hp = 10`); FileAccess source-content scan for AC-12(b)
- **`maxi()` typed int max** instead of generic `max()` — exceeds ADR's prose pseudocode for Variant-coercion safety; matches turn-order + damage-calc precedent

### Out-of-Scope Deviations

NONE. No apply_heal/apply_status/get_modified_stat/get_status_effects/_apply_turn_start_tick bodies; `_propagate_demoralized_radius` STUB only (body is story-007); no `_ready()` GameBus.unit_turn_started subscribe; no other src/ or tests/ files modified.

### Pattern Discoveries

- **CAVALRY substitution discipline** (codified): for unit_died emit tests that force low HP + apply low damage, use CAVALRY/SCOUT/ARCHER (no passive_shield_wall) to avoid Step 1 absorption. Agent caught the AC-6 setup bug mid-task (INFANTRY at HP=10 + 10-damage → INFANTRY's SHIELD_WALL_FLAT=5 absorbs → final=5 → HP=5, NOT 0; switched to CAVALRY for clean kill). Apply to: future stories 006/007 unit_died emit tests, EC-06 POISON-kill scenarios.
- **R-1 CONNECT_DEFERRED test pattern stable at 3 occurrences** (turn-order story-003 + story-005 + hp-status story-003). Codify as: connect SECOND subscriber with CONNECT_DEFERRED alongside standard sync subscriber; verify sync fires immediately + deferred fires only after `process_frame` drain.
- **Single-agent flow stable** for ≤4h Logic stories: story-002 (215s) + story-003 (223s) both completed in 1 agent invocation each; orchestrator-direct only for final regression run. Multi-spawn pattern reserved for >5 file deliverables AND/OR cross-doc data mutation (story-001 had both).

### Sprint Impact

hp-status epic 3/8 stories Complete (skeleton + initialize_unit + apply_damage). Sprint-3 day ~0-1 of 7. Baseline 665 → 679. Must-have load: S3-02 progress 3/8 (in-progress); S3-01 done. **3rd consecutive failure-free baseline** (story-001 + story-002 + story-003).
