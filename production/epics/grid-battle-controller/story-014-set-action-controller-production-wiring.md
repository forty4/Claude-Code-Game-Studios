# Story 014: POLISH-012 closure — `set_action_controller` production-wiring (BattleScene._ready Callable injection)

> **Epic**: Grid Battle Controller
> **Status**: Complete (2026-05-10 sprint-15 S15-J close — 6/6 ACs verified; +6 integration tests 1314→1320; /code-review APPROVED WITH SUGGESTIONS — 1 P1 wildcard arm test added inline + 7 ADVISORY suggestions deferred per user Route a per S15-C precedent)
> **Layer**: Feature (battle orchestrator + scene-root mount sequence integration)
> **Type**: Integration
> **Estimate**: 1-2h (~0.15d)
> **Manifest Version**: 2026-05-05
> **Sprint**: sprint-15 (S15-J — mid-sprint amendment per sprint-15.md R4 mitigation pattern; POLISH-012 closure)
> **Backlog**: POLISH-012 (CRITICAL release-blocker — production-wiring residual of POLISH-011 absorption arc S15-A/B/C; gates Production stage advancement)

## Context

**GDD**: `design/gdd/turn-order.md` §Contract 5 (Callable controller dispatch contract — what S15-A wired internally must be called from production scope) + `design/gdd/grid-battle.md` CR-1..CR-2 (player input → action dispatch + AI command → action dispatch — both routes converge on the Callable that S15-J injects)

**Requirement**: `TR-grid-battle-controller-011` (`_acted_this_turn` per-turn action consumption tracking + Contract 4 token API — same TR S15-A/B/C target; S15-J completes the absorption by wiring the DI surface S15-A added) + `TR-turn-order-001` (TurnOrderRunner Contract 5 Callable controller dispatch — S15-J is the production call site)

**ADR Governing Implementation**: ADR-0011 §Amendment 2026-05-09 (S15-A T5 await mechanism + `_action_controller: Callable` DI surface + `_maybe_defer_turn_completion` predicate — defines the Callable contract that S15-J must satisfy at production scope) + ADR-0014 §Amendment 2026-05-10 (#1 S15-B AI subscriber path + #2 S15-C player path mirror — both paths converge on the controller-side handler that S15-J registers as the Callable target) + ADR-0014 §Amendment 2026-05-10 (#3 — NEW; S15-J extends the prior amendments to specify the BattleScene mount-sequence integration point) + ADR-0016 §3 (BattleScene scene-root-as-orchestrator mount sequence — STEP 5 GridBattleController.setup is the integration site)

**ADR Decision Summary**: S15-A wired the `set_action_controller(controller: Callable)` DI surface on `TurnOrderRunner` (per ADR-0011 §Amendment 2026-05-09 lines 513-561). The setter assigns `_action_controller`; T5 `_execute_action_budget` body branches on `_action_controller.is_null()` → if injected, calls `_action_controller.call(unit_id, snapshot)` (NATURAL-LOOP mode); if NOT injected, falls through TEST-SEAM mode (no-op pass). **Production code has 0 callers of `set_action_controller`.** S15-J adds the production call site in `BattleScene._ready()` STEP 5 (`battle_scene.gd:182-194`) immediately AFTER `_grid_controller.setup(...)` but BEFORE `add_child(_grid_controller)` so the Callable is registered before T5 first fires (deferred chain triggers from `_begin_round.call_deferred()` post-`add_child`). The injected Callable points at a NEW handler method on GridBattleController (`_on_turn_runner_action_request(unit_id: int, snapshot: UnitTurnState) -> void`) that bridges T5 await → AI dispatch (S15-B `_on_ai_action_ready` already wired) OR player dispatch (S15-C `_handle_player_*` helpers already wired). The handler routes by `BattleUnit.side` (0 = player → wait for grid-click input event; 1 = enemy → trigger AI decide() + emit `ai_action_ready` deferred-chain).

**Engine**: Godot 4.6 | **Risk**: LOW (small focused production-code change — single call site in `battle_scene.gd` mount sequence + single new handler method on `grid_battle_controller.gd` + corresponding integration test using existing S15-A T5 await test scaffolding).
**Engine Notes**: Callable.bind() vs method-reference form per ADR-0011 §Amendment 2026-05-09 advisory. Use method-reference form `_grid_controller._on_turn_runner_action_request` (the preferred 4.x idiom). No post-cutoff API surface. The handler's player-side branch is asynchronous (waits for natural input via existing GameBus.input_action_fired subscription per S15-C) — handler can return immediately; T5 await stays paused until the player-side declare_action eventually fires from S15-C `_handle_player_move` / `_handle_player_attack` / `_handle_player_end_turn` per ADR-0014 §Amendment 2026-05-10 (#2). The handler's enemy-side branch synchronously triggers AI decide() which emits `ai_action_ready` → S15-B `_on_ai_action_ready` handler → declare_action (release T5 await).

**Control Manifest Rules (Feature layer — ADR-0014 §3 + ADR-0016 §3)**:
- Required: NEW handler method `_on_turn_runner_action_request` follows S15-B/C `_`-prefix discipline (private helper); handler body LOCAL signal scope (no GameBus.*.emit added); handler routes by `BattleUnit.side` per ADR-0014 §3 unit registry contract; `set_action_controller` call in `BattleScene._ready` STEP 5 happens BEFORE `add_child(_grid_controller)` (Callable registered before T5 first fires).
- Forbidden: `grid_battle_controller_signal_emission_outside_battle_domain` (no GameBus.*.emit added in handler body); `grid_battle_controller_static_state` (no static var); `battle_scene_setup_called_after_add_child` (the existing project pattern — `_grid_controller.setup(...)` is sole-call before `add_child`; same-pattern sole-call for `_turn_runner.set_action_controller(...)`).
- Guardrail: existing 1314-test baseline preserved without regression — turn_order_runner.gd / grid_battle_controller.gd / battle_scene.gd test suites continue to PASS; `turn_order_t5_await_test.gd` 7 sites continue to PASS unchanged (S15-J does NOT modify the T5 await body or the DI surface — only adds a production caller).

---

## Acceptance Criteria

*From POLISH-012 closure scope + S15-A/B/C ACs that S15-J completes:*

- [ ] **AC-1** `_on_turn_runner_action_request(unit_id: int, snapshot: UnitTurnState) -> void` private handler added to `grid_battle_controller.gd` (near `_on_ai_action_ready` — typically end-of-file ~L900). Handler body:
  - Lookup `unit: BattleUnit = _units.get(unit_id, null)`. If null, `push_warning` + return (defensive — should never happen if S15-A T5 await is correctly gated on alive units).
  - Branch by `unit.side`: if 0 (player) → return immediately (T5 stays paused; player declare_action will fire from S15-C `_handle_player_*` paths in response to natural grid-click input); if 1 (enemy) → call `_ai_system.decide(unit_id)` (or equivalent — verify exact AISystem entry point) which triggers `ai_action_ready` → S15-B `_on_ai_action_ready` → declare_action (releases T5 await).
  - Idempotent: handler is `_action_controller.call`-driven so it fires once per unit turn per S15-A T5 await semantics; no internal de-dup needed beyond the existing `_acted_this_turn` flag set by S15-B/C downstream paths.
- [ ] **AC-2** `BattleScene._ready()` STEP 5 (`battle_scene.gd:182-194`) extended: AFTER `_grid_controller.setup(...)` + AFTER `_grid_controller.set_chokepoints(chapter.chokepoints)` but BEFORE `add_child(_grid_controller)`, add:
  ```gdscript
  # S15-J: wire NATURAL-LOOP mode per ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1+#2+#3).
  # Without this call, T5 _execute_action_budget falls through TEST-SEAM no-op pass; production
  # battle loop runs to ROUND_CAP_DRAW in ~2-3 seconds without natural input/AI dispatch.
  _turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)
  ```
  Call site placement BEFORE `add_child` is load-bearing — `_begin_round.call_deferred()` runs at first idle frame after `_ready()` completes; T5 fires first within ~1-2 deferred slots.
- [ ] **AC-3** ADR-0014 §Amendment 2026-05-10 (#3) added at end-of-file documenting: BattleScene mount-sequence integration site for `set_action_controller`; the new `_on_turn_runner_action_request` handler signature + side-routing logic; cross-reference to ADR-0011 §Amendment 2026-05-09 §Decision Contract 5 (the contract S15-J satisfies at production scope); rationale for handler placement BEFORE `add_child` (Callable registration order vs T5 first-fire ordering); cross-reference to S15-A/B/C amendments (#0/#1/#2) showing S15-J completes the absorption arc as #4 of 4 root causes.
- [ ] **AC-4** Integration test `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd` (NEW) covers AC-1 + AC-2 wiring:
  - Test 1: BattleScene mount via `add_child` → assert `_turn_runner._action_controller.is_null() == false` (Callable registered)
  - Test 2: T5 fires for an enemy unit → `_on_turn_runner_action_request` called → `_ai_system.decide` called → `ai_action_ready` emit captured → declare_action recorded (verifies enemy-side end-to-end natural-loop step)
  - Test 3: T5 fires for a player unit → `_on_turn_runner_action_request` called → returns immediately → T5 stays paused → no spurious declare_action recorded (player path correctly defers to natural input)
  - Test 4: Backward compat — existing `turn_order_t5_await_test.gd` 7 sites continue to PASS unchanged (regression check; assert via full-suite invocation)
  - Test 5: Defensive — `_on_turn_runner_action_request(99999, snapshot)` with unknown unit_id → `push_warning` fires + handler returns without calling AI dispatch (no crash)
- [ ] **AC-5** Test count delta: 1314 baseline + ~5 new tests = ~1319; 0 NEW failures introduced; existing tests preserved unchanged.
- [ ] **AC-6** Backward compat: `set_action_controller` DI surface contract (S15-A) UNCHANGED — only a NEW caller added; existing 7 test sites in `turn_order_t5_await_test.gd` still PASS without modification. `BattleScene._ready` mount-sequence STEP 1-4 + STEP 5.5 + STEP 6 UNCHANGED — only STEP 5 receives a single ~3-line addition between `setup` + `set_chokepoints` + `add_child`.

---

## Implementation Notes

*Derived from POLISH-012 entry + ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1+#2) + ADR-0016 §3 + S15-A T5 await test pattern (commit `ab924aa`):*

1. **Handler method placement** — add to `grid_battle_controller.gd` at end-of-file (after `_on_ai_action_ready` from S15-B; before `_handle_player_end_turn` from S15-C if alphabetic; or end-of-file if grouped). Keep `_`-prefix discipline per S15-B/C precedent.

2. **Handler body skeleton** (concrete signature + branch logic):
   ```gdscript
   ## Per ADR-0014 §Amendment 2026-05-10 (#3 — production-wiring residual closure).
   ## Bridges T5 await per ADR-0011 §Amendment 2026-05-09 to the appropriate
   ## consumer subscriber: enemy-side via AISystem.decide → ai_action_ready chain
   ## (S15-B); player-side defers to natural grid-click input → _handle_player_*
   ## helpers (S15-C). Returns immediately for player units (T5 stays paused
   ## until player declare_action fires); triggers AI synchronously for enemies.
   func _on_turn_runner_action_request(unit_id: int, snapshot: UnitTurnState) -> void:
       var unit: BattleUnit = _units.get(unit_id, null)
       if unit == null:
           push_warning("S15-J: _on_turn_runner_action_request received unknown unit_id=%d" % unit_id)
           return
       match unit.side:
           0:  # player — natural input path (S15-C); T5 stays paused
               return
           1:  # enemy — synchronous AI dispatch (S15-B chain)
               _ai_system.decide(unit_id)
           _:
               push_warning("S15-J: unknown unit.side=%d for unit_id=%d" % [unit.side, unit_id])
   ```

3. **AISystem entry point verification** — confirm `_ai_system.decide(unit_id)` is the correct method name + signature. Inspect `src/feature/ai_system/ai_system.gd` for the decide method (commonly `decide(unit_id)` per ADR-0019; verify before authoring). If method name differs, adjust handler body. If method requires additional context (e.g., snapshot, full unit ref), pass it.

4. **BattleScene mount-sequence call site** — exact insertion point:
   ```gdscript
   # === STEP 5: GridBattleController (ADR-0014) ===
   _grid_controller = GridBattleController.new()
   _grid_controller.name = "GridBattleController"
   _grid_controller.setup(roster, _map_grid, _battle_camera, _hero_db,
       _turn_runner, _hp_controller, _terrain_effect, _unit_role)
   _grid_controller.set_chokepoints(chapter.chokepoints)
   # ── NEW (S15-J insertion point) ──────────────────────────────────────
   _turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)
   # ── END S15-J insertion ──────────────────────────────────────────────
   add_child(_grid_controller)
   ```
   Call BEFORE `add_child` ensures Callable is registered before `_begin_round.call_deferred()` chain triggers T5.

5. **Test file scaffolding** — copy `tests/integration/core/turn_order_t5_await_test.gd` lifecycle hooks + `_recording_controller` Callable factory pattern as scaffolding source. Adapt for full BattleScene mount via `_instantiate_battle_scene()` per `battle_scene_smoke_test.gd:79-82`. Use Array-of-Dict signal capture per G-4 for `ai_action_ready` + `declare_action` recording.

6. **AISystem.decide() side effect verification (Test 2)** — assert that calling `_on_turn_runner_action_request(enemy_unit_id, snapshot)` synchronously triggers AISystem.decide → `ai_action_ready` emit → S15-B `_on_ai_action_ready` → `declare_action` per the existing chain. Capture the full emit sequence to verify the natural deferred-chain progression.

7. **Performance budget** — no perf impact expected. Single Callable registration is O(1); handler body is O(1) match-dispatch + 1 AI call (already perf-tested in S15-B). No hot-path allocations.

8. **G-30 codification update candidate** — at sprint-15 retro, update G-30 §Discovered to add invocation #5 (this CLOSED-LOOP variant: even after the 3 root-cause stories absorb the verification-target component, the production WIRING that activates them remains unverified). Sprint-15 retro AI candidate: "wiring-verification AC must be added to absorption-arc story templates" (process improvement to prevent re-occurrence).

---

## Dependencies

- **Depends On**: S15-A (story-008; T5 await + `set_action_controller` DI surface) — ✅ Complete (commit `ab924aa`); S15-B (story-011; `_on_ai_action_ready` handler + AI dispatch chain) — ✅ Complete (commits `d5845de` + `a659b21`); S15-C (story-012; player path helpers) — ✅ Complete (commit `971c2ae`)
- **Blocks**: S15-D (story-013; natural-loop integration test — must wait for S15-J close so AC-4 both-paths can MEANINGFULLY demonstrate POLISH-011 closure end-to-end); S15-E (gate-check rerun-4 — natural-loop demonstration is the CD/TD/PR pivot per sprint-15.md S15-E AC-4); S15-G (S8-15 §1.3 third re-attestation post-POLISH-011-fix — user-time test must POST-DATE the production-wiring fix to demonstrate POLISH-011 actually closed in windowed mode)

## Test Evidence

- **Type**: Integration (cross-system: BattleScene mount ↔ TurnOrderRunner DI ↔ GridBattleController handler ↔ AISystem dispatch chain)
- **Location**: `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd` (NEW)
- **Gate Level**: BLOCKING per `.claude/docs/coding-standards.md` Test Evidence Matrix

## Out of Scope

- Natural-loop end-to-end battle test (S15-D scope — story-013; THIS story closes the wiring gap; S15-D verifies the wiring functions across full battle progression)
- Refactor or extension of S15-A T5 await body (DI surface preserved unchanged)
- Refactor or extension of S15-B `_on_ai_action_ready` handler (consumer chain preserved unchanged)
- Refactor or extension of S15-C `_handle_player_*` helpers (player path preserved unchanged)
- USE_SKILL action ActionType wiring (deferred per ADR-0014 §0 MVP scope)
- 500ms AI timeout / `ai_soft_lock_counter` (CR-3b/CR-3 future stories)
- ADR-0011 / ADR-0019 amendments (only ADR-0014 amendment in this story)
- Removal or refactor of `_handle_move` / `_handle_attack` / `_consume_unit_action` legacy wrappers (preserved for backward compat per S15-C R1)
- BattleScene mount-sequence STEP 1-4 / STEP 5.5 / STEP 6 modifications (only STEP 5 receives the ~3-line wire-up addition)

## Risks

- **R1**: AISystem.decide() entry-point signature drift — if `decide(unit_id)` is not the exact method name, handler body needs adjustment. Mitigation: verify at implementation time via direct `src/feature/ai_system/ai_system.gd` read; ~1-line code adjustment if signature differs.
- **R2**: Player-side handler return-immediately may surface a deadlock if player input never arrives (e.g., test runs without GameBus input simulation). Mitigation: AC-2 player-side test (Test 3) explicitly verifies T5 stays paused without spurious declare_action; live windowed mode reaches this state only when player has not yet clicked, which is correct natural behavior. Frame-budget cap in any test that exercises player-side path (e.g., S15-D natural-loop test post-S15-J) prevents infinite-loop.
- **R3**: Callable lifetime under scene teardown — `_action_controller` Callable holds a reference to `_grid_controller._on_turn_runner_action_request`. If `_grid_controller` is freed before `_turn_runner` (or vice-versa), Callable becomes invalid. Mitigation: `_exit_tree()` ordering per ADR-0014 §10 + ADR-0011 §_exit_tree audit (story-009) — both Nodes own their own cleanup; Godot 4.x SOURCE-outlives-TARGET pattern handles this via auto-disconnect. If observed crash on scene transition, add explicit `_turn_runner._action_controller = Callable()` clear in GridBattleController._exit_tree.
- **R4**: Test 4 backward-compat assertion may fail if S15-J introduces an unintended side effect on the existing `turn_order_t5_await_test.gd` 7 sites (e.g., test isolation breaking due to NEW BattleScene mount in S15-J test bleeding into other test state). Mitigation: G-15 before_test/after_test discipline preserved; HeroDatabase reset per `battle_scene_smoke_test.gd:59-62` precedent; test isolation verified via `--filter battle_scene_set_action_controller_wiring_test` standalone run + full-suite run regression check.

## Cross-References

- POLISH-012 entry: `production/polish-backlog.md` (search "POLISH-012")
- Surfacing source: sprint-15 S15-D /dev-story Phase 4 godot-gdscript-specialist mid-implementation investigation 2026-05-10 PM late-late (orchestrator independently verified via `grep -rn "set_action_controller" src/ tests/` returning 7 test sites + 0 production callers)
- Sprint-15 plan S15-J row: `production/sprints/sprint-15.md` (mid-sprint amendment 2026-05-10 PM late-late)
- ADR-0011 §Amendment 2026-05-09 (S15-A T5 await + `set_action_controller` DI surface): `docs/architecture/ADR-0011-turn-order.md` lines 513-561
- ADR-0014 §Amendment 2026-05-10 #1 (S15-B AI subscriber): `docs/architecture/ADR-0014-grid-battle-controller.md` (end of file)
- ADR-0014 §Amendment 2026-05-10 #2 (S15-C player path mirror): `docs/architecture/ADR-0014-grid-battle-controller.md` lines 713-787
- ADR-0014 §Amendment 2026-05-10 #3 (S15-J production-wiring — to be added at story-014 close): `docs/architecture/ADR-0014-grid-battle-controller.md` (end of file post-this-amendment)
- ADR-0016 (BattleSceneWiring scene-root-as-orchestrator mount sequence): `docs/architecture/ADR-0016-battle-scene-wiring.md`
- S15-A T5 await test scaffolding: `tests/integration/core/turn_order_t5_await_test.gd`
- BattleScene mount-sequence reference: `src/feature/battle_scene/battle_scene.gd:115-200` STEP 1-6
- POLISH-011 absorption arc precedents: S15-A `ab924aa` + S15-B `d5845de`+`a659b21` + S15-C `971c2ae`
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3 + §11.4

## Completion Notes
**Completed**: 2026-05-10 (sprint-15 S15-J — POLISH-012 closure; POLISH-011 absorption arc 4/4 root causes WIRED; final root cause closed)
**Criteria**: 6/6 passing — all ACs verified via 6 integration tests + suite-wide regression check (1314→1320)
**Implementation**:
- `src/feature/grid_battle/grid_battle_controller.gd:1250-1262` (+~30 LoC) — new `_on_turn_runner_action_request(unit_id: int, snapshot: TurnOrderSnapshot) -> void` handler with side-routing (player → return immediately; enemy → emit `ai_action_requested.emit(unit_id, _make_battle_state_snapshot())` reusing S15-B chain; defensive null-check + wildcard match arm)
- `src/feature/battle_scene/battle_scene.gd:194-197` (+4 LoC) — STEP 5 wire-up `_turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)` placed AFTER `set_chokepoints` + BEFORE `add_child(_grid_controller)` per load-bearing Callable-registration-order vs T5-first-fire rationale
- `docs/architecture/ADR-0014-grid-battle-controller.md:791-864` (+~75 LoC) — §Amendment 2026-05-10 (#3) documenting integration site, handler signature + side-routing logic, 2 design corrections vs spec, backward-compat preservation, cross-references
- `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd` (NEW ~390 LoC, 6 tests) — covers AC-1 (3 arms) + AC-2 + AC-6 with proper isolation per G-4/G-6/G-10/G-15/G-27/G-28 disciplines; +1 wildcard-arm test added inline post-/code-review per qa-tester P1
**Test Results**: 1314 → 1320 PASS (+6); 0 NEW failures; 71st consecutive failure-free baseline; pre-existing POLISH-008 ObjectDB leak warning observed (out of scope)
**Test Evidence**: Integration — `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd` (BLOCKING gate satisfied per coding-standards.md Test Evidence Matrix)
**Code Review**: Complete — orchestrator-led /code-review verdict APPROVED WITH SUGGESTIONS (lean mode; LP-CODE-REVIEW + QL-TEST-COVERAGE PHASE-GATE skipped per `production/review-mode.txt`); godot-gdscript-specialist APPROVED (8/8 focus areas CLEAN); qa-tester GAPS verdict (1 P1 + 3 P2 + minor suggestions). 1 P1 (wildcard `_:` arm coverage) RESOLVED INLINE with `test_unknown_unit_side_pushes_warning_and_returns_without_dispatch`; 7 ADVISORY suggestions DEFERRED per user Route a (mirrors S15-C close-out precedent) → logged to sprint-15 retro debt
**Deviations** (all ADVISORY documented in ADR Amendment #3 §Key clarifications):
- (1) snapshot type: `TurnOrderSnapshot` (NOT `UnitTurnState` as story-014 spec assumed) — verified at `turn_order_runner.gd:614`
- (2) enemy-side dispatch: emit existing `ai_action_requested` signal (NOT direct `_ai_system.decide()` call) — reuses S15-B chain end-to-end; mirrors `_on_unit_turn_started:630-631` precedent
- (3) AC-4 actual = 6 tests (vs spec target 5; +1 wildcard arm coverage from P1 inline fix; positive scope deviation)
- (4) AC-5 actual = 1320 baseline (vs spec target 1319; +1 from AC-4 deviation; positive scope deviation)
**7 ADVISORY suggestions deferred to sprint-15 retro debt** (per user Route a; mirrors S15-C precedent):
- qa-tester P2: Test for Callable lifetime after `_grid_controller` free
- qa-tester P2: Test for re-entrant call (same unit T5 fires twice)
- qa-tester P2: Test for `_make_battle_state_snapshot()` independent fixture
- qa-tester improvement: Test 1 add `Callable.get_object()` assertion vs grid_ctrl
- qa-tester improvement: Test 6 round-trip null → non-null → null
- godot specialist: `battle_scene.gd:197` inline comment conciseness if line-length CI enforced
- godot specialist: Test 2 G-4 vs G-10 comment block readability split
- qa-tester: Test 3 secondary assertion confirming grid_ctrl matches scene's GridBattleController
- qa-tester (deferred to S15-D drafting): extract `_instantiate_and_mount_battle_scene` + `_seed_hero_database` into shared helper at `tests/integration/feature/battle_scene/battle_scene_test_helpers.gd`
**POLISH-011 absorption arc status**: 4/4 root causes WIRED (S15-A T5 await ✅ + S15-B AI consumer ✅ + S15-C player path ✅ + S15-J production-wiring ✅) — final root cause closed. S15-D natural-loop integration test (story-013) UNBLOCKED for resume; S15-E /gate-check rerun-4 + S15-G S8-15 §1.3 third re-attestation now pivot on S15-D close.
**Pattern observation**: 5th invocation of headless-vs-windowed verification gap (G-30) — CLOSED-LOOP variant where absorption-arc components ship correctly but production wiring remains unverified; codification candidate for sprint-15 retro per ADR amendment process gap analysis (S15-A/B/C amendments documented component contracts but not the integration test that proves end-to-end wiring at production scope; S15-J ADR Amendment #3 closes this gap by explicitly documenting the BattleScene mount-sequence integration site). Investigation-time catch (orchestrator + 3 specialist agent rounds verified before any code authoring) FASTER + CHEAPER than the sprint-15.md R4 mitigation anticipated path (test-first-run-failure → mid-amendment); saved ~2-3h of would-have-been-wasted test authoring + first-run failure + diagnostic + amendment cycle.
