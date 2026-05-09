# Story 012: POLISH-011 absorption — Player declare_action plumbing in grid-click handlers

> **Epic**: Grid Battle Controller
> **Status**: Complete (2026-05-10 sprint-15 S15-C close — 9/9 ACs verified; +7 integration tests 1307→1314; /code-review APPROVED with 1 BLOCKING ADR cross-ref fixed inline + 5 ADVISORY suggestions deferred per user Route a)
> **Layer**: Feature (battle orchestrator)
> **Type**: Integration
> **Estimate**: 3-5h (~0.4d)
> **Manifest Version**: 2026-05-05
> **Sprint**: sprint-15 (S15-C) — POLISH-011 absorption #3 of 3
> **Backlog**: POLISH-011 (CRITICAL release-blocker; gates Production advancement)

## Context

**GDD**: `design/gdd/grid-battle.md` (CR-1 + CR-2 player input → action dispatch + grid-click action vocabulary `move_target_select` / `move_confirm` / `attack_target_select` / `attack_confirm` / `end_unit_turn`)

**Requirement**: `TR-grid-battle-controller-011` (single-token MVP simplification of grid-battle.md Contract 4 — `_acted_this_turn` per-turn action consumption tracking + `_consume_unit_action` calls `_turn_runner.declare_action(unit_id, ATTACK, null)` regardless of underlying action). The shipped single-token shortcut at `_consume_unit_action` (line 884-892) hardcodes `declare_action(ATTACK)` — this is functionally correct in TEST-SEAM mode (T5 = no-op pass per S15-A; ActionType doesn't gate turn completion) but BROKEN under NATURAL-LOOP mode where `_maybe_defer_turn_completion` predicate uses `state.action_token_spent` (set by ATTACK/SKILL/DEFEND/WAIT) vs `state.move_token_spent` (set by MOVE alone). After S15-A wires NATURAL-LOOP mode, a player MOVE that should LEAVE the turn open (allowing follow-up ATTACK same turn) instead immediately completes turn via the hardcoded ATTACK declaration. POLISH-011 root cause #3 of 3.

**ADR Governing Implementation**: ADR-0014 §8 Amendment 2026-05-10 (extends to player path; this story is amendment #2 to the same Amendment) + ADR-0011 §Amendment 2026-05-09 (S15-A T5 await mechanism + `_maybe_defer_turn_completion` predicate; controller follows up correctly-typed declare_action) + ADR-0014 §6 (single-token MVP simplification — to be amended for NATURAL-LOOP correctness)

**ADR Decision Summary**: Per ADR-0011 §Amendment 2026-05-09 + ADR-0014 §8 Amendment 2026-05-10 (S15-B precedent), the AI path uses `_do_move` / `_resolve_attack` directly + manual `_acted_this_turn[unit_id] = true` + correctly-typed `declare_action(MOVE/ATTACK/DEFEND/WAIT)` to satisfy `_maybe_defer_turn_completion` predicate without double-dispatch. S15-C closes the **player-path mirror gap**: `_handle_grid_click_unit_selected` action arms currently dispatch via `_handle_move` / `_handle_attack` wrappers, which call `_consume_unit_action` → `declare_action(ATTACK, null)` (hardcoded — wrong type for MOVE; missing for `end_unit_turn`). Under NATURAL-LOOP mode this triggers premature turn completion on MOVE + missing turn completion on `end_unit_turn` (player explicitly ends turn → no `declare_action` fires → T5 await never releases → battle stalls). POLISH-011 root cause #3 of 3.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (existing player tests in stories-004/005/006 depend on `_handle_move`/`_handle_attack`/`_consume_unit_action` behavior — must NOT regress; S15-C must add NEW helpers without modifying the existing wrappers)
**Engine Notes**: No post-cutoff API surface. `Object.CONNECT_DEFERRED` already established at battle init for the AI path (S15-B); player path runs synchronously inside `_on_input_action_fired` deferred callback, no additional reentrance concern. ActionTarget construction reuses S15-B's `_make_move_target` / `_make_attack_target` factories.

**Control Manifest Rules (Feature layer — ADR-0014 §8 + §6)**:
- Required: 6 LOCAL signals stay LOCAL (no GameBus emission); player path declare_action calls correctly-typed (MOVE for moves / ATTACK for attacks / WAIT for end_unit_turn); `_acted_this_turn` flag set BEFORE `declare_action` (mirrors S15-B AI-path order-of-operations)
- Forbidden: `grid_battle_controller_signal_emission_outside_battle_domain` (no GameBus.*.emit); `grid_battle_controller_static_state` (no static var); `grid_battle_controller_external_combat_math` (no formation/angle math added)
- Guardrail: existing story-004/005/006 tests must continue to PASS without regression — `_handle_move` / `_handle_attack` / `_consume_unit_action` signatures + behaviors preserved

---

## Acceptance Criteria

*From sprint-15.md S15-C acceptance criteria + ADR-0014 §8 Amendment 2026-05-10 + S15-B precedent + ADR-0011 §Amendment 2026-05-09:*

- [ ] **AC-1** `_handle_player_move(unit: BattleUnit, dest: Vector2i) -> void` private helper added to `grid_battle_controller.gd`. Mirrors S15-B AI-path pattern: validates `is_tile_in_move_range` + calls `_do_move(unit, dest)` directly (NOT `_handle_move` wrapper) + sets `_acted_this_turn[unit.unit_id] = true` + calls `_turn_runner.declare_action(unit.unit_id, TurnOrderRunner.ActionType.MOVE, _make_move_target(dest))`. Re-entrancy guard via `_acted_this_turn.get(unit.unit_id, false)` early-return.
- [ ] **AC-2** `_handle_player_attack(attacker_id: int, defender_id: int) -> void` private helper added. Mirrors S15-B AI-path pattern: validates `is_tile_in_attack_range` + `_units.has(defender_id)` + calls `_resolve_attack(attacker, defender)` directly (NOT `_handle_attack` wrapper) + sets `_acted_this_turn[attacker_id] = true` + calls `_turn_runner.declare_action(attacker_id, TurnOrderRunner.ActionType.ATTACK, _make_attack_target(defender_id))`. Re-entrancy guard via `_acted_this_turn.get(attacker_id, false)` early-return.
- [ ] **AC-3** `_handle_grid_click_unit_selected` action arms rewired:
  - `move_target_select` / `move_confirm` → call `_handle_player_move(_units[_selected_unit_id], coord)` (instead of `_handle_move`)
  - `attack_target_select` / `attack_confirm` → call `_handle_player_attack(_selected_unit_id, unit_id)` (instead of `_handle_attack`)
  - `end_unit_turn` → call `_handle_player_end_turn()` (NEW — instead of bare `end_player_turn()`)
- [ ] **AC-4** `_handle_player_end_turn() -> void` private helper added. Iterates `_units` for player-side alive units that have NOT `_acted_this_turn`; for each, sets `_acted_this_turn[unit_id] = true` + calls `_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)`. Then calls existing `end_player_turn()` (preserves auto-handoff + deselect side effects).
- [ ] **AC-5** `_handle_move` / `_handle_attack` / `_consume_unit_action` signatures + behaviors UNCHANGED. Story-004/005/006 tests continue to PASS without regression. Test-seam paths that drive `_handle_move(unit, dest)` directly retain existing `_consume_unit_action` → `declare_action(ATTACK)` behavior (acceptable in TEST-SEAM mode where T5 = no-op pass).
- [ ] **AC-6** ADR-0014 §Amendment 2026-05-10 extended (Amendment #2 same date): document the player-path bypass mirror — `_handle_player_move` / `_handle_player_attack` / `_handle_player_end_turn` helpers; rationale (NATURAL-LOOP mode requires correctly-typed declare_action; wrappers' single-token shortcut declares ATTACK regardless and would prematurely complete MOVE turns); design symmetry with S15-B AI path; backward compat preserved for story-004/005/006 tests.
- [ ] **AC-7** Integration test `tests/integration/feature/grid_battle/grid_battle_controller_player_declare_action_test.gd` (NEW) covers AC-1..AC-5 dispatch surface:
  - Test 1: `move_target_select` → `_handle_player_move` → declare_action(MOVE, target) recorded; `_handle_move` NOT called (sole-call discipline)
  - Test 2: `attack_target_select` → `_handle_player_attack` → declare_action(ATTACK, target) recorded
  - Test 3: `move_confirm` aliases `move_target_select` (same handler dispatch)
  - Test 4: `attack_confirm` aliases `attack_target_select` (same handler dispatch)
  - Test 5: `end_unit_turn` → `_handle_player_end_turn` → for each unacted player unit declares WAIT + then end_player_turn auto-handoff
  - Test 6: re-entrancy guard — calling `move_target_select` twice in same turn (after first MOVE) → only first dispatches; second is silent no-op
  - Test 7: backward compat regression — direct `_handle_move(unit, dest)` test seam still works (calls `_consume_unit_action` → `declare_action(ATTACK)` per existing story-004 contract)
- [ ] **AC-8** Test count delta: 1307 baseline + ~7 new tests = ~1314; 0 NEW failures introduced; existing story-004/005/006 player tests continue to PASS.
- [ ] **AC-9** Backward compat: existing 6 LOCAL signals + 4 GameBus subscriptions preserved; existing grid-battle-controller story-001..011 tests continue to PASS without regression.

---

## Implementation Notes

*Derived from ADR-0014 §8 Amendment 2026-05-10 (S15-B AI-path precedent) + ADR-0011 §Amendment 2026-05-09 + story-006 §6 + S15-A T5 await mechanism (commit `ab924aa`):*

1. **Player MOVE helper** — add to `grid_battle_controller.gd` near `_handle_move` (~line 810):
   ```gdscript
   ## Per ADR-0014 §8 Amendment 2026-05-10 (Amendment #2 — player-path mirror).
   ## Mirrors AI-path bypass: calls _do_move directly (not _handle_move wrapper)
   ## to avoid _consume_unit_action's hardcoded declare_action(ATTACK). Player MOVE
   ## must declare correctly-typed MOVE action so _maybe_defer_turn_completion
   ## predicate (S15-A) keeps the turn open for follow-up ATTACK same turn.
   func _handle_player_move(unit: BattleUnit, dest: Vector2i) -> void:
       if _acted_this_turn.get(unit.unit_id, false):
           return  # re-entrancy guard
       if not is_tile_in_move_range(dest, unit.unit_id):
           return  # invalid target — silent
       _do_move(unit, dest)
       _acted_this_turn[unit.unit_id] = true
       _turn_runner.declare_action(unit.unit_id, TurnOrderRunner.ActionType.MOVE,
           _make_move_target(dest))
   ```

2. **Player ATTACK helper** — add near `_handle_attack` (~line 825):
   ```gdscript
   ## Per ADR-0014 §8 Amendment 2026-05-10 (Amendment #2 — player-path mirror).
   ## Mirrors AI-path bypass for the attack action.
   func _handle_player_attack(attacker_id: int, defender_id: int) -> void:
       if _acted_this_turn.get(attacker_id, false):
           return  # re-entrancy guard
       if not _units.has(attacker_id) or not _units.has(defender_id):
           return  # defensive — shouldn't happen if dispatch is correct
       var attacker: BattleUnit = _units[attacker_id]
       var defender: BattleUnit = _units[defender_id]
       if not is_tile_in_attack_range(defender.position, attacker_id):
           return  # invalid target — silent
       _resolve_attack(attacker, defender)
       _acted_this_turn[attacker_id] = true
       _turn_runner.declare_action(attacker_id, TurnOrderRunner.ActionType.ATTACK,
           _make_attack_target(defender_id))
   ```

3. **Player end_unit_turn helper** — add near `end_player_turn` body (~line 358):
   ```gdscript
   ## Per ADR-0014 §8 Amendment 2026-05-10 (Amendment #2 — player-path mirror).
   ## Player explicitly ends turn (`end_unit_turn` action). For each player-side
   ## alive unit that has NOT acted, declare WAIT to release the T5 await per
   ## S15-A `_maybe_defer_turn_completion` predicate (action_token_spent == true).
   ## Preserves existing end_player_turn() side effects (deselect + auto-handoff).
   func _handle_player_end_turn() -> void:
       for unit: BattleUnit in _units.values():
           if unit.side != 0:
               continue  # player-side only
           if not _hp_controller.is_alive(unit.unit_id):
               continue  # dead units don't WAIT
           if _acted_this_turn.get(unit.unit_id, false):
               continue  # already declared an action this turn
           _acted_this_turn[unit.unit_id] = true
           _turn_runner.declare_action(unit.unit_id,
               TurnOrderRunner.ActionType.WAIT, null)
       end_player_turn()
   ```

4. **Action arm rewiring** in `_handle_grid_click_unit_selected` (~line 758):
   ```gdscript
   "move_target_select", "move_confirm":
       if is_tile_in_move_range(coord, _selected_unit_id):
           _handle_player_move(_units[_selected_unit_id], coord)  # was _handle_move
   "attack_target_select", "attack_confirm":
       if is_tile_in_attack_range(coord, _selected_unit_id):
           _handle_player_attack(_selected_unit_id, unit_id)  # was _handle_attack
   "end_unit_turn":
       _handle_player_end_turn()  # was end_player_turn
   ```

5. **Backward compat preservation** — `_handle_move`, `_handle_attack`, `_consume_unit_action` all UNCHANGED. Story-004/005/006 tests use `_handle_move(unit, dest)` direct calls + assert `_consume_unit_action` side effects — these paths still work because the wrappers + their token shortcut behavior are preserved. The S15-C change is purely additive: new helpers + dispatch arm rewires, no modifications to existing methods.

6. **Integration test pattern** — mirrors `tests/integration/feature/grid_battle/grid_battle_controller_ai_action_ready_test.gd` (S15-B precedent). Use the same inner-class pattern (`GBCTurnRunnerDouble` records `declare_action` calls; `GBCHPControllerStub` for `_resolve_attack` integration; concrete subclass stubs `GBCUnitRoleStub` / `GBCHeroDatabaseStub` per G-22). Drive via direct `_handle_grid_click_unit_selected(action, coord, unit_id)` calls + assert recorded `_turn_double.calls` shape + side effects (unit_moved signal capture per G-4 Array-of-Dict + HP delta via stub recording).

7. **Performance budget** — no perf impact expected. New helpers are O(1) match-dispatch + O(units) for `_handle_player_end_turn` iteration (typically ≤5 player units; bounded). No hot-path allocations beyond existing `_do_move` / `_resolve_attack` paths (already perf-tested in story-004/005).

---

## Dependencies

- **Depends On**: S15-A (story-008; T5 await + `set_action_controller` + `_maybe_defer_turn_completion`) — ✅ Complete (2026-05-10 commit `ab924aa`); S15-B (story-011; AI-path bypass precedent + `_make_move_target` / `_make_attack_target` factories) — ✅ Complete (2026-05-10 sprint-15 S15-B close)
- **Blocks**: S15-D (natural-loop integration test for player + AI mixed battles), S15-E (gate-check rerun-4 PASS), S15-G (S8-15 §1.3 third re-attestation)

## Test Evidence

- **Type**: Integration (cross-system: GridBattleController dispatch ↔ TurnOrderRunner declare_action contract)
- **Location**: `tests/integration/feature/grid_battle/grid_battle_controller_player_declare_action_test.gd` (NEW)
- **Gate Level**: BLOCKING per coding-standards.md Test Evidence Matrix

## Out of Scope

- AI declare_action plumbing (S15-B scope — ✅ Complete)
- T5 await mechanism (S15-A scope — ✅ Complete)
- Full natural-loop battle-end-to-end integration test player+AI to non-DRAW (S15-D scope; this story's test is single-action-arm verification)
- Move-token + action-token split (post-MVP per ADR-0014 §6 — current single-token MVP simplification preserved at `_consume_unit_action`; new helpers introduce typed declare_action without splitting tokens)
- DEFEND action via `defend_confirm` action arm (deferred to Skill ADR per ADR-0014 §0; player path currently has no DEFEND grid-click action — only AI path emits DEFEND via AIActionCommand)
- USE_SKILL action (deferred per ADR-0014 §0 MVP scope)
- 500ms AI timeout / `ai_soft_lock_counter` (CR-3b/CR-3 future stories)
- ADR-0011 / ADR-0019 amendments (only ADR-0014 amendment in this story)
- Removal or refactor of `_handle_move` / `_handle_attack` / `_consume_unit_action` (preserved for backward compat; future Token ADR convergence is separate scope)

## Risks

- **R1**: New helpers introduce code duplication with `_handle_move` / `_handle_attack` (re-entrancy guard + range check + DI'd backend calls all repeated). Mitigation: helpers are intentionally additive per AC-5 backward compat constraint; documented in ADR-0014 §Amendment 2026-05-10 §2 as "convergence pending future Token ADR". Acceptable tech debt, not blocking.
- **R2**: `_handle_player_end_turn` must handle the edge case where ALL player units already acted (early-return short-circuit; no WAIT declared; existing `end_player_turn` auto-handoff still fires). Verified by integration test 5 with pre-acted unit fixture.
- **R3**: Test isolation — story-004/005/006 tests assert `_consume_unit_action` side effects (deselect + auto-handoff). New helpers do NOT call `_consume_unit_action`, so they bypass auto-handoff. Mitigation: only `_handle_player_end_turn` keeps the auto-handoff path (calls `end_player_turn()` after declaring WAIT for unacted units). Per-action arms (move/attack) leave selection state untouched per natural-loop dispatch flow — controller turn handoff happens via T6+T7 deferred chain triggered by `_maybe_defer_turn_completion` predicate, NOT inline auto-handoff. This is the intended NATURAL-LOOP behavior; documented in ADR amendment.
- **R4**: Action arm rewiring in `_handle_grid_click_unit_selected` may surface gaps if the existing dispatch had implicit assumptions about `_handle_move` / `_handle_attack` side effects (e.g., MapGrid occupancy bookkeeping is in `_do_move` not `_handle_move` so safe; HP mutations are in `_resolve_attack` not `_handle_attack` so safe). Mitigation: read each wrapper carefully BEFORE rewiring; verify that the underlying primitive (`_do_move` / `_resolve_attack`) covers all the wrapper's side effects.

## Completion Notes
**Completed**: 2026-05-10 (sprint-15 S15-C — POLISH-011 absorption #3 of 3, final root cause closure)
**Criteria**: 9/9 passing — all ACs verified via 7 new integration tests + suite-wide regression check (1307→1314)
**Implementation**:
- `src/feature/grid_battle/grid_battle_controller.gd` (+69/-7) — 3 new helpers (`_handle_player_end_turn` L524, `_handle_player_move` L831, `_handle_player_attack` L844) + 5 dispatch arms rewired in `_handle_grid_click_unit_selected` (L792 move_target_select+move_confirm, L796 attack_target_select+attack_confirm, L800 end_unit_turn) mirroring S15-B's AI-path bypass at L309-410
- `tests/integration/feature/grid_battle/grid_battle_controller_player_declare_action_test.gd` (NEW 489 LoC, 7 tests) — covers AC-7-mandated dispatch arms via inner-class doubles `GBCPTurnRunnerDouble` / `GBCPHPControllerStub` / `GBCPUnitRoleStub` / `GBCPHeroDatabaseStub` (G-26 prefix isolation from S15-B's `GBC*`)
- `docs/architecture/ADR-0014-grid-battle-controller.md` (+78 LoC) — Amendment 2026-05-10 (#2) at L713-787 documenting player-path mirror helpers, order-of-operations, backward-compat preservation, out-of-scope (Token ADR convergence + DEFEND/USE_SKILL deferrals), cross-references
**Test Results**: 1307 → 1314 PASS (+7); 0 NEW failures; pre-existing `hp_status_perf` flap absent this run; both grid-battle-controller-specific lints PASS (GameBus emit count=0; static var grep=empty)
**Test Evidence**: Integration — `tests/integration/feature/grid_battle/grid_battle_controller_player_declare_action_test.gd` (BLOCKING gate satisfied per coding-standards.md Test Evidence Matrix)
**Code Review**: Complete — orchestrator-led /code-review verdict APPROVED (lean mode; LP-CODE-REVIEW + QL-TEST-COVERAGE PHASE-GATE skipped per `production/review-mode.txt`); godot-gdscript-specialist + qa-tester both reported APPROVED WITH SUGGESTIONS; 1 BLOCKING resolved inline (ADR-0014 L784 cross-reference filename suffix `-plumbing` added to match actual on-disk path)
**Deviations**: NONE blocking. 5 ADVISORY suggestions deferred per user Route a:
- (1) Test 8 R2 all-acted short-circuit + (2) Test 9 ATTACK re-entrancy mirror + (3) Test 10 dead-unit `is_alive` filter — all 3 absorbed into S15-D natural-loop integration test drafting (R2 mitigation claim in story Risks was technically inaccurate vs Test 5 actual coverage; S15-D will close)
- (4) `_handle_player_attack` doc-comment expand from 2 → 5 lines + (5) `push_warning` mirror in player helpers' invalid-input paths (vs AI-path discipline) — both logged to retro debt for sprint-15 retrospective
**POLISH-011 absorption arc status**: 3/3 root causes WIRED (S15-A T5 await ✅ + S15-B AI consumer ✅ + S15-C player path ✅) — final root cause closed. S15-D natural-loop integration test, S15-E /gate-check rerun-4, S15-G S8-15 §1.3 third re-attestation now all UNBLOCKED. Production-stage flip path-to-PASS continues.
**Pattern observation**: 2nd extension of S15-A's `set_action_controller` Callable-setter DI surface pattern to a 3rd subscriber (player path); helper-bypass pattern symmetrically applied across player + AI paths (single-token MVP simplification preserved per ADR-0014 §6 backward compat for story-004/005/006 wrappers; future Token ADR will retire `_consume_unit_action` and reunify both paths)
