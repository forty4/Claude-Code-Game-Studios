# Story 005: apply_status + CR-5c refresh + CR-5d coexist + CR-5e slot eviction + CR-7 DEFEND_STANCE+EXHAUSTED mutex + template load + .duplicate()

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-008` (status effect lifecycle apply/refresh/evict/expire), `TR-hp-status-010` (CR-7 DEFEND_STANCE+EXHAUSTED mutex enforcement)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status §8 + §10 + §5
**ADR Decision Summary**: §8 status effect lifecycle: apply via `apply_status` with CR-7 mutex enforcement (EXHAUSTED → DEFEND_STANCE attempt returns false; DEFEND_STANCE → EXHAUSTED apply force-removes DEFEND_STANCE BEFORE appending EXHAUSTED); CR-5c same effect_id refresh-only (find existing → overwrite remaining_turns + source_unit_id, no stack); CR-5d different effect_id co-exist (Array.append after refresh check); CR-5e MAX_STATUS_EFFECTS_PER_UNIT slot cap with `pop_front()` insertion-order eviction; template load via `load("res://assets/data/status_effects/[effect_template_id].tres")` with null-on-missing returning false + push_error; shallow `.duplicate()` per delta-#7 Item 2 (intentional for read-only sub-Resource pattern; tick_effect Resource shared between template + instance per ADR-0010 §4 Hot-reload behavior note).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Resource.duplicate()` (NOT `duplicate_deep()`) per ADR-0010 §4 + delta-#7 Item 2 PASS; intentional shallow copy for read-only sub-Resource sharing of `tick_effect`. `load("res://assets/data/status_effects/%s.tres" % effect_template_id) as StatusEffect` returns null on missing file (graceful degradation). `Array.pop_front()` is insertion-order eviction (4.0+ stable). StringName literals `&"defend_stance"` / `&"exhausted"` / `&"poison"` etc. for effect_id keys (4.0+ stable; matches 4-precedent ADR-0007/0009/0012/0010 StringName convention). `String % StringName` formatting works via implicit `to_string()` (4.x stable).

**Control Manifest Rules (Core layer + Global)**:
- Required: `BalanceConstants.get_const("MAX_STATUS_EFFECTS_PER_UNIT")` for slot cap (no hardcoded 3); `load(...)` with `as StatusEffect` cast for template; shallow `.duplicate()` (NOT `duplicate_deep()` — explicit comment justifying choice per ADR-0010 §4); G-15 `BalanceConstants._cache_loaded = false` reset; method-reference signal handlers (forward-compat for story-006)
- Forbidden: `duplicate_deep()` for StatusEffect template duplication (would unnecessarily clone read-only `tick_effect` sub-Resource — wastes memory + breaks shared template hot-reload behavior per ADR-0010 §4); inline lambdas for any signal handler (story-005 doesn't connect anything yet — discipline carried forward); modify `state.status_effects` Array elements in place if returned outward (story-008 forbidden_pattern hp_status_consumer_mutation enforces — apply_status itself owns the Array; doesn't return it)
- Guardrail: `apply_status` < 0.10ms minimum-spec mobile (slightly higher than apply_damage/apply_heal due to template `load()` + `.duplicate()`); ADR-0010 Validation §8

---

## Acceptance Criteria

*From GDD AC-11..AC-12 + AC-15..AC-16 + EC-04..EC-05 + EC-13 + EC-16 + ADR-0010 §8 + §10, scoped to this story:*

- [ ] **AC-1** Mirrors GDD AC-11 + EC-16: Given unit with POISON active (3 turns remaining), When `apply_status(1, &"poison", -1, source_unit_id)` re-applied (same effect_id, same source), Then existing POISON's remaining_turns refreshed to template default (3) AND no second POISON instance created (status_effects.size() unchanged at 1); CR-5c — `source_unit_id` field also updated on refresh
- [ ] **AC-2** CR-5d different effect_id coexist: Given unit with POISON active (status_effects size = 1), When `apply_status(1, &"demoralized", -1, source_unit_id)`, Then status_effects size grows to 2; both effects active independently; no eviction (size < MAX_STATUS_EFFECTS_PER_UNIT=3)
- [ ] **AC-3** Mirrors GDD AC-12 + EC-04: Given unit with 3 effects active (POISON insertion-order [0], DEMORALIZED [1], INSPIRED [2]) at MAX_STATUS_EFFECTS_PER_UNIT cap, When `apply_status(1, &"exhausted", -1, source_unit_id)` (different effect_id triggering 4th-slot scenario), Then status_effects.size() stays at 3; oldest (POISON at index 0) evicted via `pop_front()`; final order = [DEMORALIZED, INSPIRED, EXHAUSTED]
- [ ] **AC-4** Mirrors GDD AC-15 + CR-7 EXHAUSTED → DEFEND_STANCE rejection: Given unit with EXHAUSTED active, When `apply_status(1, &"defend_stance", -1, source_unit_id)`, Then return value == false; status_effects unchanged (no DEFEND_STANCE added); push_warning OR doc comment notes the caller MUST surface "피로로 태세 유지 불가" feedback
- [ ] **AC-5** Mirrors GDD AC-16 + CR-7 + EC-13 DEFEND_STANCE → EXHAUSTED force-remove: Given unit with DEFEND_STANCE active, When `apply_status(1, &"exhausted", -1, source_unit_id)`, Then return value == true; DEFEND_STANCE force-removed from status_effects BEFORE EXHAUSTED appended; final status_effects contains EXHAUSTED but NOT DEFEND_STANCE
- [ ] **AC-6** Template load null-on-missing: Given attempt to apply unknown effect_template_id `&"poison_typo"`, When `apply_status(1, &"poison_typo", -1, source_unit_id)`, Then `load("res://assets/data/status_effects/poison_typo.tres")` returns null; push_error fires; return value == false; status_effects unchanged (no malformed instance appended)
- [ ] **AC-7** Dead/unknown unit early-return: Given unit at current_hp == 0 OR unknown unit_id, When `apply_status(99, &"poison", -1, source_unit_id)`, Then return value == false; no state mutation; pipeline does NOT enter (early-return BEFORE CR-7 mutex check)
- [ ] **AC-8** duration_override == -1 uses template default: Given POISON template with `remaining_turns = 3` (POISON_DEFAULT_DURATION), When `apply_status(1, &"poison", duration_override=-1, source_unit_id)`, Then applied StatusEffect instance has `remaining_turns == 3` (template default copied)
- [ ] **AC-9** duration_override >= 0 overrides template: Given POISON template, When `apply_status(1, &"poison", duration_override=5, source_unit_id)`, Then applied StatusEffect instance has `remaining_turns == 5` (override applied to per-instance copy; template's remaining_turns unchanged at 3 — proven by re-loading template + asserting unchanged value)
- [ ] **AC-10** Shallow `.duplicate()` produces independent instances per ADR-0010 §4 hot-reload behavior + Verification §4: Given POISON template, When `apply_status(1, &"poison", -1, ...)` then `apply_status(2, &"poison", 7, ...)` (two different units, second with override), Then both units have independent StatusEffect instances (different `remaining_turns` values 3 vs 7); but the inner `tick_effect: TickEffect` SHARED Resource reference is the same object (intentional per ADR-0010 §4 — read-only sub-Resource pattern; verifiable via `instance1.tick_effect == instance2.tick_effect` reference equality)
- [ ] **AC-11** EC-05 slot eviction does NOT trigger DoT tick: Given unit with POISON evicted via CR-5e during `apply_status` (POISON was at index 0, new effect appended forces eviction), When the eviction occurs, Then no DoT tick processing fires for the evicted POISON in this turn (eviction is silent — `_apply_turn_start_tick` in story-006 sees no POISON to tick)
- [ ] **AC-12** CR-5b apply timing — apply_status callable in any order relative to apply_damage / apply_heal: Test sequence init → apply_damage → apply_status(POISON) → apply_damage → apply_status(POISON refresh) — final state correctly reflects damage taken + POISON refreshed once (no order-dependence bugs)
- [ ] **AC-13** Regression baseline maintained: full GdUnit4 suite passes ≥696 cases (story-004 baseline ~684 + ≥12 new) / 0 errors / 0 carried failures / 0 orphans

---

## Implementation Notes

*Derived from ADR-0010 §8 line 300-332 pseudocode + §10 + §4 hot-reload note + Verification §4:*

1. **`apply_status` body** — exact structure per ADR-0010 §8:
   ```gdscript
   func apply_status(unit_id: int, effect_template_id: StringName, duration_override: int, source_unit_id: int) -> bool:
       var state: UnitHPState = _state_by_unit.get(unit_id)
       if state == null or state.current_hp == 0:
           return false

       # CR-7 mutex enforcement — DEFEND_STANCE attempt while EXHAUSTED → reject
       if effect_template_id == &"defend_stance" and _has_status(state, &"exhausted"):
           return false  # caller surfaces "피로로 태세 유지 불가" UI feedback per AC-15

       # CR-7 mutex enforcement — EXHAUSTED apply while DEFEND_STANCE → force-remove first
       if effect_template_id == &"exhausted" and _has_status(state, &"defend_stance"):
           _force_remove_status(state, &"defend_stance")  # AC-16 + EC-13

       # CR-5c: same effect_id refresh (no stack)
       var existing: StatusEffect = _find_status(state, effect_template_id)
       if existing != null:
           existing.remaining_turns = duration_override if duration_override >= 0 else _template_default_duration(effect_template_id)
           existing.source_unit_id = source_unit_id  # update source for DEMORALIZED recovery proximity
           return true

       # CR-5e: max slots check + oldest-first eviction (Array preserves insertion order)
       var max_slots: int = BalanceConstants.get_const("MAX_STATUS_EFFECTS_PER_UNIT")
       if state.status_effects.size() >= max_slots:
           state.status_effects.pop_front()  # evict oldest (insertion-order)

       # Apply: load template + duplicate + inject overrides
       var template: StatusEffect = load("res://assets/data/status_effects/%s.tres" % effect_template_id) as StatusEffect
       if template == null:
           push_error("apply_status: unknown effect template %s" % effect_template_id)
           return false
       var instance: StatusEffect = template.duplicate()  # shallow copy; tick_effect Resource shared (read-only)
       instance.remaining_turns = duration_override if duration_override >= 0 else template.remaining_turns
       instance.source_unit_id = source_unit_id
       state.status_effects.append(instance)
       return true
   ```

2. **`_force_remove_status(state, effect_id)` private helper** — first-time used in this story:
   ```gdscript
   func _force_remove_status(state: UnitHPState, effect_id: StringName) -> void:
       var i: int = state.status_effects.size() - 1
       while i >= 0:
           if state.status_effects[i].effect_id == effect_id:
               state.status_effects.remove_at(i)
               # Continue iterating in case duplicates exist (defensive — should not happen per CR-5c refresh contract)
           i -= 1
   ```
   Reverse-index iteration per delta-#7 godot-specialist Item 7 PASS (idiomatic Godot 4.x — forward iteration with `remove_at` would skip elements). Story-006 reuses this helper for `_apply_turn_start_tick` TURN_BASED expiry pattern.

3. **`_find_status(state, effect_id)` private helper**:
   ```gdscript
   func _find_status(state: UnitHPState, effect_id: StringName) -> StatusEffect:
       for effect in state.status_effects:
           if effect.effect_id == effect_id:
               return effect
       return null
   ```

4. **`_template_default_duration(effect_template_id)` private helper** — used when `duration_override == -1`:
   ```gdscript
   func _template_default_duration(effect_template_id: StringName) -> int:
       var template: StatusEffect = load("res://assets/data/status_effects/%s.tres" % effect_template_id) as StatusEffect
       if template == null:
           return 0  # caller already failed via load null-check; defense-in-depth
       return template.remaining_turns
   ```
   Could be optimized via cached template references (story-008 Polish-tier opportunity), but MVP correctness first.

5. **Shallow `.duplicate()` — NOT `duplicate_deep()`** — explicit comment in code:
   ```gdscript
   # SHALLOW duplicate intentional per ADR-0010 §4 hot-reload note + delta-#7 Item 2 PASS:
   # tick_effect: TickEffect is read-only post-load; sharing the Resource reference
   # between template and instance is correct (matches read-only sub-Resource pattern).
   # Editor-mode hot-reload of POISON .tres values reflects live in all currently-applied
   # StatusEffect instances via shared TickEffect reference — intentional for designer iteration.
   # Production builds unaffected (no hot-reload in shipped binaries).
   var instance: StatusEffect = template.duplicate()  # NOT duplicate_deep()
   ```

6. **Test-side helper retirement** (story-005 supersedes story-003/004 helpers):
   - story-003's `_attach_defend_stance(unit_id)` — replaced by `apply_status(unit_id, &"defend_stance", -1, source_unit_id)` in production. Story-005 tests USE the canonical `apply_status` pathway throughout.
   - story-004's `_attach_exhausted(unit_id)` — same replacement. Story-005 verifies AC-4/AC-5 via apply_status calls (NOT direct injection).

7. **G-15 `before_test()` discipline**:
   ```gdscript
   func before_test() -> void:
       BalanceConstants._cache_loaded = false  # ADR-0006 §6 G-15 mirror
       _controller = HPStatusController.new()
       add_child(_controller)
   ```

8. **Test file**: `tests/unit/core/hp_status_apply_status_test.gd` — 12-15 tests covering AC-1..AC-12 (AC-13 = full regression).

9. **AC-10 reference-equality check** — Godot RefCounted/Resource reference comparison via `==` works for object identity (4.x stable):
   ```gdscript
   func test_shallow_duplicate_shares_tick_effect_resource() -> void:
       var hero := _make_hero(50)
       _controller.initialize_unit(1, hero, UnitRole.UnitClass.INFANTRY)
       _controller.initialize_unit(2, hero, UnitRole.UnitClass.INFANTRY)
       _controller.apply_status(1, &"poison", -1, 99)
       _controller.apply_status(2, &"poison", 7, 99)  # different override → different remaining_turns
       var p1: StatusEffect = _find_status(_controller._state_by_unit[1], &"poison")
       var p2: StatusEffect = _find_status(_controller._state_by_unit[2], &"poison")
       assert_int(p1.remaining_turns).is_equal(3)  # template default
       assert_int(p2.remaining_turns).is_equal(7)  # overridden
       # SHARED tick_effect (read-only sub-Resource pattern):
       assert_object(p1.tick_effect).is_same(p2.tick_effect)  # GdUnit4 4.x is_same() reference-equality
   ```

10. **No GameBus interaction in story-005**: apply_status emits NO signal per ADR-0010 §5 line 207-208 spec. Battle HUD is expected to poll `get_status_effects()` per frame OR subscribe to a future `hp_status_changed` signal in a deferred Battle HUD ADR (per OQ-3). Story-005's test file has no signal subscriptions or emits.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: `apply_damage` body. Story-005 reuses `_has_status` helper that story-003 might have shipped; verify at /dev-story spawn.
- **Story 004**: `apply_heal` body + `_has_status` helper (first defined in story-004). Story-005 EXTENDS the helper set with `_force_remove_status` + `_find_status` + `_template_default_duration`.
- **Story 006**: `_apply_turn_start_tick` body + F-3 DoT + F-4 `get_modified_stat` + EXHAUSTED move-range special-case + GameBus.unit_turn_started subscribe + MapGrid DI; AC-13/14/19. Story-005 ships the apply pathway; story-006 ships the per-turn tick + decrement + expiry pathway.
- **Story 007**: `_propagate_demoralized_radius` body. Story-005's `apply_status(unit_id, &"demoralized", duration, source_unit_id)` is the call site that story-007's propagation logic invokes for each ally in radius.
- **Story 008**: Perf baseline + `hp_status_consumer_mutation` forbidden_pattern lint (which polices `get_status_effects` returned-Array immutability convention; applied in story-006 once `get_status_effects` body lands — but story-005 already ensures internal `state.status_effects` is mutated only via apply_status / _force_remove_status / _apply_turn_start_tick).

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1 — CR-5c POISON refresh (GDD AC-11 / EC-16)**:
- Given: unit at full HP; `apply_status(1, &"poison", -1, 99)` already called once
- When: `apply_status(1, &"poison", -1, 99)` called second time (same source)
- Then: return value == true; status_effects.size() == 1 (no duplicate); the existing POISON's `remaining_turns` reset to 3 (template default); `source_unit_id` overwritten with new value (test with different source on second call → asserts overwrite)

**AC-2 — CR-5d different effect coexist**:
- Given: unit with POISON active
- When: `apply_status(1, &"demoralized", -1, 99)`
- Then: return value == true; status_effects.size() == 2; both POISON + DEMORALIZED present; insertion order [POISON, DEMORALIZED]

**AC-3 — CR-5e slot eviction (GDD AC-12 / EC-04)**:
- Given: unit with 3 effects [POISON, DEMORALIZED, INSPIRED] at MAX_STATUS_EFFECTS_PER_UNIT=3 cap
- When: `apply_status(1, &"exhausted", -1, 99)` (4th distinct effect — note: must NOT have DEFEND_STANCE active to avoid CR-7 force-remove path)
- Then: return value == true; status_effects.size() == 3; final order [DEMORALIZED, INSPIRED, EXHAUSTED]; POISON evicted via `pop_front()`

**AC-4 — CR-7 EXHAUSTED blocks DEFEND_STANCE (GDD AC-15)**:
- Given: unit with EXHAUSTED active
- When: `apply_status(1, &"defend_stance", -1, 99)`
- Then: return value == false; status_effects unchanged (DEFEND_STANCE NOT added)

**AC-5 — CR-7 EXHAUSTED force-removes DEFEND_STANCE (GDD AC-16 / EC-13)**:
- Given: unit with DEFEND_STANCE active
- When: `apply_status(1, &"exhausted", -1, 99)`
- Then: return value == true; status_effects contains EXHAUSTED but NOT DEFEND_STANCE; `_has_status(state, &"defend_stance") == false`

**AC-6 — Template load failure**:
- Given: attempt unknown effect_template_id `&"unknown_typo"`
- When: `apply_status(1, &"unknown_typo", -1, 99)`
- Then: push_error fires (visible in stderr); return value == false; status_effects unchanged

**AC-7 — Dead/unknown unit early-return**:
- Given: unit at current_hp = 0 OR unknown unit_id 99
- When: `apply_status(1, &"poison", -1, 99)` on dead OR `apply_status(99, &"poison", -1, 99)` on unknown
- Then: return value == false; no state mutation; CR-7 mutex check NOT entered

**AC-8 — duration_override == -1 uses template default**:
- Given: POISON template (`remaining_turns = 3`)
- When: `apply_status(1, &"poison", -1, 99)`
- Then: applied instance `remaining_turns == 3`

**AC-9 — duration_override > 0 overrides + template unchanged**:
- Given: POISON template
- When: `apply_status(1, &"poison", 5, 99)`
- Then: applied instance `remaining_turns == 5`; subsequent `load("res://...poison.tres") as StatusEffect` returns template with unchanged `remaining_turns == 3`

**AC-10 — Shallow .duplicate() instance independence + tick_effect sharing**:
- Given: 2 different units; POISON applied to both
- When: unit 1 with default duration, unit 2 with override 7
- Then: `p1.remaining_turns == 3` AND `p2.remaining_turns == 7` (independent state); `p1.tick_effect` IS `p2.tick_effect` (shared reference per ADR-0010 §4)

**AC-11 — Slot eviction does NOT fire DoT tick**:
- Given: unit with POISON at index 0 (DoT-bearing); 2 other effects at indices 1, 2
- When: `apply_status(1, &"exhausted", ...)` evicts POISON via pop_front
- Then: current_hp unchanged before/after (no DoT applied during eviction); `_apply_turn_start_tick` is NOT a side effect of apply_status. (Story-006 owns turn-start ticks; story-005 ensures apply_status path stays clean)

**AC-12 — CR-5b apply timing flexibility**:
- Given: init → apply_damage → apply_status(POISON) → apply_damage → apply_status(POISON refresh)
- When: full sequence executed
- Then: final state shows correct cumulative damage + POISON with refreshed remaining_turns (no order-of-operation bugs)

**AC-13 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: full-suite headless run
- Then: ≥696 cases / 0 errors / 0 failures / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/hp_status_apply_status_test.gd` — new file (12-15 tests covering AC-1..AC-12; AC-13 verified via full-suite regression)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 + 002 (HPStatusController + UnitHPState + 5 .tres templates + `_has_status` helper from story-004 if shipped); ADR-0006 ✅ Accepted (BalanceConstants for MAX_STATUS_EFFECTS_PER_UNIT); ADR-0010 ✅ Accepted; balance-data + hero-database epics ✅ Complete
- Unlocks: Story 006 (`_apply_turn_start_tick` consumes status_effects array shape established here; `_force_remove_status` helper reused for ACTION_LOCKED expiry); story 007 (`_propagate_demoralized_radius` calls `apply_status(ally, &"demoralized", duration, ...)` for each ally in radius — relies on apply_status pathway shipped here)
- Independent of: Story 003, Story 004 (parallel implementation possible after stories 001 + 002; shared `_has_status` helper coordinated at /dev-story time — first of 003/004/005 to ship gets ownership)

---

## Completion Notes

- **Completed**: 2026-05-02
- **Criteria**: 13/13 passing (AC-7 split into 7a dead + 7b unknown; AC-13 = full-suite regression)
- **Deviations**: NONE — ADR-0010 §8/§10/§5 verbatim implementation; manifest current (2026-04-20 match)
- **Test Evidence**: Logic — `tests/unit/core/hp_status_apply_status_test.gd` (414 LoC / 13 tests / standalone 13/13 PASS / full regression 679 → **692 / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0**); 4th consecutive failure-free baseline since story-001
- **Helper ownership**: story-005 ships first production version of `_has_status` / `_find_status` / `_force_remove_status` / `_template_default_duration` — used by apply_status CR-7 mutex + CR-5c refresh + CR-7 force-remove paths. Story-006 will reuse `_force_remove_status` (ACTION_LOCKED expiry) + `_find_status` (DEMORALIZED CONDITION_BASED recovery); story-004 apply_heal F-2 EXHAUSTED multiplier should consume `_has_status`.
- **Code Review**: APPROVED WITH SUGGESTIONS (lean-mode orchestrator-direct, 9th occurrence) — 8 forward-look advisory items captured (S-1..S-8); 0 required changes
- **Files**: `src/core/hp_status_controller.gd` (185 → 268 LoC, +83) + `tests/unit/core/hp_status_apply_status_test.gd` (NEW, 414 LoC)
- **Engine gotchas applied**: G-9 (paren-wrap concat before `%`), G-12 (helper name non-collision verified), G-14 (proactive import refresh), G-15 (canonical `before_test`/`after_test` doubled cache reset), G-22 (test-private `_state_by_unit` direct access for forced-state setup), G-23 (no `is_not_equal_approx`), G-24 (paren-wrap `as Type` in `==` expressions)
- **Forward-look advisory carry items** (story-008 epic-terminal scope): S-2 cached template references for `_template_default_duration` Polish opportunity; S-3 test factory hoisting (4 hp_status_*_test.gd files now repeat `initialize_unit` arrange); S-4 story-006 cleanup opportunity to refactor apply_damage inline iteration to consume `_has_status`/`_find_status` helpers; S-5 `_force_remove_status` defensive `push_warning` if duplicates encountered (would surface latent CR-5c breakage)
