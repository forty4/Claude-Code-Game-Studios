# Story 004: F-2 apply_heal 4-step pipeline + EXHAUSTED multiplier + overheal prevention + dead-unit zero-return

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-007` (F-2 4-step healing pipeline + CR-4a/4b)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status §7 + §5
**ADR Decision Summary**: §7 4-step healing pipeline: Step 1 raw_heal computed by caller (skill/item formula); Step 2 EXHAUSTED multiplier (`raw_heal = int(max(1, floor(raw_heal * EXHAUSTED_HEAL_MULT)))` per CR-4 Step 2; explicit int cast applied per delta-#7 Item 9 convention); Step 3 overheal prevention (`heal_amount = min(raw_heal, max_hp - current_hp)` per CR-4a no-overheal); Step 4 HP increase (`current_hp += heal_amount`). Returns actual `heal_amount` applied (0 if dead per CR-4b dead-units-cannot-be-healed; actual amount up to max_hp - current_hp). Caller can inspect return for UI feedback (skip 'healed for 0' display when return is 0 per EC-09 풀-HP target).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript 4.x `floor()` returns float; explicit `int(...)` cast for return-type honesty under typed `-> int`. `EXHAUSTED_HEAL_MULT` is a float (default 0.5; safe range [0.3, 0.7]) per ADR-0010 §12 + GDD §Tuning Knobs; `BalanceConstants.get_const(key) -> Variant` typed-coerces to float at the call site. `min(int, int)` and `max(int, int)` return int (Godot 4.x stable). No post-cutoff API surface.

**Control Manifest Rules (Core layer + Global)**:
- Required: `BalanceConstants.get_const("EXHAUSTED_HEAL_MULT")` for Step 2 multiplier (no hardcoded 0.5); explicit `int(floor(...))` cast at Step 2 per delta-#7 Item 9; G-15 `BalanceConstants._cache_loaded = false` reset in `before_test()`
- Forbidden: emit any signal from apply_heal (`hp_status_signal_emission_outside_domain` lint at story-008 enforces — apply_heal emits NO signal per ADR-0010 §5 line 207-208 spec); mutate any state when current_hp == 0 (CR-4b — return 0 silently)
- Guardrail: `apply_heal` < 0.05ms minimum-spec mobile (ADR-0010 Validation §8); on-device measurement deferred to story-008 Polish-tier

---

## Acceptance Criteria

*From GDD AC-07..AC-10 + EC-08..EC-10 + ADR-0010 §7, scoped to this story:*

- [ ] **AC-1** Mirrors GDD AC-07: Given Strategist unit (max_hp = 106 per UnitRole F-3 with appropriate hero seed) at current_hp = 50, When `apply_heal(unit_id=1, raw_heal=26, source_unit_id=99)`, Then return value == 26 (no EXHAUSTED, no overheal); current_hp 50 → 76. **Note**: AC-07's stated `floor(15 + ceil(106×0.10)) = 26` is the raw_heal CALCULATION owned by the caller (skill/item formula), NOT by HP/Status. Story-004 verifies HP/Status correctly applies raw_heal=26 INPUT; the F-2 §1-§4 pipeline does not implement the heal_amount derivation formula (CR-4 Step 1 says "raw_heal computed by caller").
- [ ] **AC-2** Mirrors GDD AC-08 + EC-09: Given any unit at current_hp == max_hp, When `apply_heal(unit_id=1, raw_heal=26, source_unit_id=99)`, Then `min(26, max_hp - max_hp) = min(26, 0) = 0`; return value == 0; current_hp unchanged
- [ ] **AC-3** Mirrors GDD AC-09: Given EXHAUSTED-active unit at current_hp = 50 (max_hp = 232), When `apply_heal(unit_id=1, raw_heal=39, source_unit_id=99)`, Then Step 2 `int(max(1, floor(39 * 0.5))) = int(max(1, 19.0)) = 19`; Step 3 `min(19, 232 - 50) = min(19, 182) = 19`; return value == 19; current_hp 50 → 69
- [ ] **AC-4** Mirrors GDD AC-10 + EC-10 + CR-4b: Given unit with current_hp == 0 (or unknown unit_id), When `apply_heal(unit_id=1, raw_heal=26, source_unit_id=99)`, Then return value == 0; no state mutation; pipeline does NOT enter (early-return BEFORE Step 1)
- [ ] **AC-5** EC-08 EXHAUSTED preserves minimum heal: Given EXHAUSTED-active unit at current_hp = 50 (max_hp = 232), When `apply_heal(unit_id=1, raw_heal=1, source_unit_id=99)`, Then Step 2 `int(max(1, floor(1 * 0.5))) = int(max(1, 0)) = 1`; return value == 1; current_hp 50 → 51 (EXHAUSTED cannot reduce heal below 1)
- [ ] **AC-6** Overheal prevention guarantees current_hp ≤ max_hp at all times: Given unit at current_hp = max_hp - 5 (e.g., 95/100), When `apply_heal(unit_id=1, raw_heal=100, source_unit_id=99)`, Then Step 3 `min(100, 5) = 5`; return value == 5; current_hp 95 → 100 (exactly max_hp; no spillover)
- [ ] **AC-7** Return value is the ACTUAL heal applied (for UI feedback): Given current_hp = 90, max_hp = 100, raw_heal = 50, no EXHAUSTED. When `apply_heal(unit_id=1, raw_heal=50, source_unit_id=99)`, Then return value == 10 (NOT 50 — overhealed amount discarded); current_hp 90 → 100
- [ ] **AC-8** Source_unit_id parameter is NOT consumed by apply_heal logic in MVP (no source-attribution in healing pipeline — only used for status_effects). Test asserts behavior is identical for source_unit_id = -1 / 99 / unit_id (reflexive heal). The parameter is preserved in the signature for forward-compat with future skill-source attribution logic
- [ ] **AC-9** No GameBus signal emission: source-file scan asserts `apply_heal` body contains zero `GameBus.*\.emit(` patterns; `is_alive`, `get_current_hp`, `get_max_hp` non-emitter contract per ADR-0010 §5 line 207-208 + Validation §4 grep gate (full lint enforcement at story-008)
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥684 cases (story-003 baseline ~672 + ≥12 new) / 0 errors / 0 carried failures / 0 orphans

---

## Implementation Notes

*Derived from ADR-0010 §7 line 277-295 pseudocode + delta-#7 Item 9 cast convention:*

1. **`apply_heal` body** — exact 4-step structure per ADR-0010 §7:
   ```gdscript
   func apply_heal(unit_id: int, raw_heal: int, source_unit_id: int) -> int:
       var state: UnitHPState = _state_by_unit.get(unit_id)
       if state == null or state.current_hp == 0:
           return 0  # CR-4b: dead/unknown units cannot be healed

       # F-2 Step 1: raw_heal already computed by caller (skill/item formula)
       # F-2 Step 2: EXHAUSTED multiplier (CR-4 Step 2)
       if _has_status(state, &"exhausted"):
           raw_heal = int(max(1, floor(raw_heal * BalanceConstants.get_const("EXHAUSTED_HEAL_MULT"))))

       # F-2 Step 3: Overheal prevention (CR-4a)
       var heal_amount: int = min(raw_heal, state.max_hp - state.current_hp)

       # F-2 Step 4: HP increase
       state.current_hp += heal_amount

       return heal_amount  # caller inspects for UI feedback (skip 'healed for 0' on full-HP per EC-09)
   ```

2. **`_has_status(state, effect_id)` private helper** — first time used in this story (story-005 reuses + extends):
   ```gdscript
   func _has_status(state: UnitHPState, effect_id: StringName) -> bool:
       for effect in state.status_effects:
           if effect.effect_id == effect_id:
               return true
       return false
   ```
   Story-004 ships this helper; story-005 reuses it for CR-7 mutex check + CR-5c refresh check + DEFEND_STANCE/INSPIRED queries.

3. **EXHAUSTED test setup**: same test-side helper pattern as story-003's `_attach_defend_stance` — story-004 adds `_attach_exhausted(unit_id)`:
   ```gdscript
   func _attach_exhausted(unit_id: int) -> void:
       var ex_template := load("res://assets/data/status_effects/exhausted.tres") as StatusEffect
       var instance: StatusEffect = ex_template.duplicate()
       _controller._state_by_unit[unit_id].status_effects.append(instance)
   ```
   Production path uses `apply_status(unit_id, &"exhausted", -1, source_unit_id)` shipped in story-005.

4. **Source_unit_id pass-through** (AC-8): the parameter is preserved in the signature but not consumed by the F-2 pipeline. It exists for forward-compat with future skill-source attribution (e.g., a "healing received from this source" stat for a skill cooldown). Story-004 documents this with a doc comment:
   ```gdscript
   ## raw_heal: integer pre-multiplier heal value computed by caller (skill/item formula).
   ## source_unit_id: attacker/skill-source unit_id; preserved for forward-compat (future healing-received attribution).
   ##                  NOT consumed by F-2 pipeline in MVP.
   ## Returns: actual heal_amount applied (0 if dead/unknown; ≥1 if alive and not full-HP; 0 if full-HP).
   func apply_heal(unit_id: int, raw_heal: int, source_unit_id: int) -> int:
   ```

5. **`min` / `max` operate on int** when both arguments are int — verified Godot 4.x stable. `BalanceConstants.get_const("EXHAUSTED_HEAL_MULT")` returns Variant typed at runtime as float; the multiplication `raw_heal * float = float`, then `floor()` returns float, then `max(1, float)` promotes to float (Godot's max takes Variant), then `int(...)` cast back to int. The explicit `int(max(1, floor(...)))` ordering matches ADR-0010 §7 line 286 verbatim.

6. **G-15 `before_test()` discipline** (extends story-003 pattern):
   ```gdscript
   func before_test() -> void:
       BalanceConstants._cache_loaded = false  # ADR-0006 §6 G-15 mirror
       _controller = HPStatusController.new()
       add_child(_controller)
   ```
   No GameBus subscriptions in story-004 (apply_heal emits nothing).

7. **Test file**: `tests/unit/core/hp_status_apply_heal_test.gd` — 8-12 tests covering AC-1..AC-9 (AC-10 = full regression).

8. **AC-1 max_hp value handling**: AC-07 cites `max_hp = 106` for Strategist. Story-004 test should use `_make_hero(base_hp_seed=...)` with appropriate seed + `UnitRole.UnitClass.STRATEGIST` to derive max_hp via UnitRole F-3. Compute the actual max_hp via `_controller.get_max_hp(1)` and assert relative behavior (e.g., `current_hp = max_hp - 56` for a heal that should land 26 → expected current_hp = max_hp - 30). Avoid hardcoding 106 unless that's the verified UnitRole.get_max_hp output for the chosen seed/class combination — keeps test robust against UnitRole tuning.

9. **No `_ready()` body, no GameBus subscription** in story-004. apply_heal is a pure mutator that does not interact with GameBus.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: `apply_damage` body + F-1 4-step pipeline + unit_died emit + R-1 mitigation. Story-003 prerequisite for story-004 EXHAUSTED test setup (test uses _attach_exhausted helper, NOT apply_status pathway).
- **Story 005**: `apply_status` body + CR-5/CR-7 mutex + slot eviction + template load + .duplicate(). Story-005 ships the canonical EXHAUSTED apply pathway (replaces story-004's test-side `_attach_exhausted` helper in production).
- **Story 006**: `_apply_turn_start_tick` + F-3 DoT + F-4 `get_modified_stat` + EXHAUSTED move-range special-case. EXHAUSTED is a multi-effect status; story-004 only handles the Step 2 heal-multiplier; the move-range -1 special-case ships in story-006.
- **Story 007**: `_propagate_demoralized_radius` + R-6 dual-invocation. Healing has no DEMORALIZED interaction in MVP.
- **Story 008**: Perf baseline + signal-emission-outside-domain forbidden_pattern lint (which polices apply_heal's no-emit invariant).

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1 — Basic heal application (GDD AC-07 input verification)**:
- Given: Strategist-class unit (init via initialize_unit with appropriate hero) at current_hp = max_hp - 56 (forces a heal target with sufficient room)
- When: `_controller.apply_heal(1, 26, 99)`
- Then: return value == 26; `get_current_hp(1) == max_hp - 30`
- Edge case: source_unit_id == -1 vs 99 vs same unit_id — all produce identical return + state (AC-8)

**AC-2 — Full-HP heal returns 0 (GDD AC-08 / EC-09)**:
- Given: any unit at current_hp == max_hp (initialize_unit puts it there per CR-1a)
- When: `apply_heal(1, 26, 99)`
- Then: return value == 0; current_hp unchanged
- Edge case: heal_amount = max_hp - current_hp = 0 → min(26, 0) = 0 (Step 3 short-circuits)

**AC-3 — EXHAUSTED multiplier (GDD AC-09)**:
- Given: unit with `_attach_exhausted(1)` test helper, max_hp ~232 (Infantry-equivalent), current_hp = 50
- When: `apply_heal(1, 39, 99)`
- Then: return value == 19; `get_current_hp(1) == 69`
- Edge case: int(max(1, floor(39 * 0.5))) = int(max(1, 19.0)) = 19 — explicit cast verified

**AC-4 — Dead-unit zero-return (GDD AC-10 / CR-4b / EC-10)**:
- Given: unit at current_hp = 0 (force via direct `_state_by_unit[1].current_hp = 0`) OR unknown unit_id
- When: `apply_heal(1, 26, 99)` (or `apply_heal(99, 26, 99)` for unknown)
- Then: return value == 0; no state mutation (current_hp stays 0)

**AC-5 — EXHAUSTED preserves minimum heal of 1 (EC-08)**:
- Given: EXHAUSTED-active unit at current_hp = 50
- When: `apply_heal(1, 1, 99)`
- Then: return value == 1; current_hp 50 → 51
- Edge case: max(1, floor(1 * 0.5)) = max(1, 0) = 1 — proves the floor protection

**AC-6 — Overheal prevention guarantees current_hp ≤ max_hp**:
- Given: unit at current_hp = max_hp - 5 (e.g., 95 with max_hp 100)
- When: `apply_heal(1, 100, 99)`
- Then: return value == 5; `get_current_hp(1) == 100` (exact max_hp; no overflow)

**AC-7 — Return value matches actual applied heal**:
- Given: current_hp = 90, max_hp = 100
- When: `apply_heal(1, 50, 99)`
- Then: return value == 10 (capped); current_hp 90 → 100
- Edge case: caller can compare returned value to raw_heal input — if return < raw_heal, caller knows overheal was clamped (UI logic for "healed for 10" vs "healed for 50 — 40 wasted")

**AC-8 — source_unit_id reflexivity**:
- Given: 3 test runs with source_unit_id = -1 / 99 / 1 (same unit) on identical unit/HP state
- When: apply_heal each time with same raw_heal
- Then: return value identical across all 3 runs; state identical (modulo independent initial state); proves source_unit_id NOT consumed in MVP

**AC-9 — No-emit invariant**:
- Given: apply_heal body source code
- When: FileAccess.get_file_as_string + grep for `GameBus.*\.emit(`
- Then: zero matches inside the apply_heal body lines (story-008 lint enforces this globally; story-004 asserts the structural invariant)

**AC-10 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: full-suite headless run
- Then: ≥684 cases / 0 errors / 0 failures / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/hp_status_apply_heal_test.gd` — new file (8-12 tests covering AC-1..AC-9; AC-10 verified via full-suite regression)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 + 002 (HPStatusController + initialize_unit + queries); ADR-0006 ✅ Accepted (BalanceConstants for EXHAUSTED_HEAL_MULT); ADR-0010 ✅ Accepted; balance-data + unit-role + hero-database epics ✅ Complete
- Unlocks: Story 005 (apply_status pathway replaces test-side `_attach_exhausted` helper for production EXHAUSTED application); story 006 (`_apply_turn_start_tick` reuses `_has_status` helper shipped in story-004)
- Independent of: Story 003 (parallel implementation possible — no apply_damage call sites in story-004)

---

## Completion Notes

- **Completed**: 2026-05-02
- **Criteria**: 10/10 passing (AC-4 split into 4a dead + 4b unknown — AC split discipline now stable at 2 occurrences with story-005's AC-7 split; AC-10 = full-suite regression)
- **Deviations**: NONE — ADR-0010 §7 verbatim implementation with 3 convention alignments matching story-003/005 precedents (`int(...)` cast at Step 2 per delta-#7 Item 9; `as float` cast for BalanceConstants Variant; `mini()` typed-int min); manifest current (2026-04-20 match)
- **Test Evidence**: Logic — `tests/unit/core/hp_status_apply_heal_test.gd` (~290 LoC / 10 tests / standalone 10/10 PASS in 65ms / full regression 692 → **702 / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / 68/68 suites / Exit 0**); 5th consecutive failure-free baseline since story-001 — entire hp-status implementation chain (1, 2, 3, 4, 5) ALL green
- **Pre-resolved coordination decisions both validated**:
  - `_has_status` REUSED from story-005's helper at `src/core/hp_status_controller.gd:231-235` — NOT re-shipped (orchestrator pre-resolved)
  - EXHAUSTED test setup uses **production `apply_status(unit, &"exhausted", -1, source)` pathway** (NOT test-side `_attach_exhausted` helper) — validates story-005 → story-004 helper-ownership chain end-to-end (orchestrator pre-resolved per /story-readiness coordination note)
- **Code Review**: APPROVED WITH SUGGESTIONS (lean-mode orchestrator-direct, **10th occurrence**) — 4 forward-look advisory items captured (S-1..S-4); 0 required changes
- **Files**: `src/core/hp_status_controller.gd` (268 → 296 LoC, +28) + `tests/unit/core/hp_status_apply_heal_test.gd` (NEW, ~290 LoC)
- **Engine gotchas applied**: G-9 (paren-wrap concat before `%`), G-14 (proactive import refresh), G-15 (canonical `before_test`/`after_test` doubled cache reset), G-22 (FileAccess source-file scan for AC-9 no-emit invariant), G-23 (no `is_not_equal_approx`), G-24 (paren-wrap `as Type` in `==` expressions). NONE encountered new — all proactive applications from established patterns.
- **Forward-look advisory carry items** (story-008 epic-terminal scope or earlier opportunity):
  - S-1 (escalating priority): test factory hoisting — now 5 hp_status_*_test.gd files repeat `_make_hero` factory (~25 LoC duplication). Codify shared helper at `tests/unit/core/hp_status_test_helpers.gd` or extend existing `tests/unit/core/test_helpers.gd::TestHelpers` per G-1 precedent.
  - S-2 (carry from story-005): `_template_default_duration` redundant `load()` — Polish-tier optimization for story-008.
  - S-3 (G-22 AC-9 refinement): `apply_heal_body.contains("GameBus.")` is a coarse substring scan; refine to regex `\bGameBus\.\w+\.emit\(` if false positives surface from comments mentioning GameBus.
  - S-4 (carry from story-005, now reinforced): story-006 cleanup opportunity to refactor story-003's apply_damage inline `for effect: StatusEffect in state.status_effects` iteration to consume `_has_status`/`_find_status` helpers — story-003 is now the only place where inline iteration remains; minor consistency gain.
