# Story 013: Natural-loop integration test (G-30 mitigation infrastructure)

> **Epic**: Grid Battle Controller
> **Status**: Ready (BLOCKED on S15-J close per mid-sprint amendment 2026-05-10 PM late-late — POLISH-012 production-wiring residual discovered at /dev-story Phase 4; story-014 must close before story-013 implementation can MEANINGFULLY demonstrate POLISH-011 closure end-to-end)
> **Layer**: Feature (integration-tier test infrastructure)
> **Type**: Integration
> **Estimate**: 2-3h (~0.3d)
> **Manifest Version**: 2026-05-05
> **Sprint**: sprint-15 (S15-D) — POLISH-011 closure verification + G-30 verification gap pattern #5 closure
> **Backlog**: G-30 codification (`.claude/rules/godot-4x-gotchas.md` G-30) verification-gap pattern #5 (full battle-loop end-to-end)

## Context

**GDD**: `design/gdd/turn-order.md` §Contract 4 token API + `design/gdd/grid-battle.md` CR-1..CR-7 natural battle dispatch (player + AI mixed flow) + `design/gdd/scenario-progression.md` §Battle Outcomes (victory_condition_detected emit contract — non-DRAW eligible)

**Requirement**: `TR-grid-battle-controller-011` (single-token MVP simplification of grid-battle.md Contract 4 — `_acted_this_turn` per-turn action consumption tracking + `declare_action` + ActionType discrimination per ADR-0011 §Decision Contract 5 + ADR-0014 §6). S15-A (T5 await) + S15-B (AI consumer) + S15-C (player consumer) WIRED the 3 root-cause integration boundaries; S15-D **VERIFIES** the wiring via natural deferred-chain progression — the FIRST end-to-end natural-loop integration test in the codebase. Closes G-30 verification gap pattern #5: existing 1314-test suite passes via direct test seams (`_advance_turn(unit_id)`, `declare_action(...)`, `_seed_unit_state_for_test(...)`) and never exercises `initialize_battle()` → `_begin_round.call_deferred()` → outcome emit through the natural deferred chain. Without S15-D, headless suite green ≠ production main_scene battle loop functional (the precise gap that surfaced POLISH-011 originally per G-30 invocation #4).

**ADR Governing Implementation**: ADR-0011 §Amendment 2026-05-09 (S15-A T5 await mechanism + `_maybe_defer_turn_completion` predicate) + ADR-0014 §Amendment 2026-05-10 (#1 S15-B AI subscriber + 6-way handler dispatch) + ADR-0014 §Amendment 2026-05-10 (#2 S15-C player path mirror) + ADR-0016 §1-§7 (BattleScene scene-root-as-orchestrator mount sequence — natural-loop test mounts via this contract not via direct controller construction)

**ADR Decision Summary**: Per ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1 + #2), the 3-subscriber architecture (T5 await → AI handler → player handler) all converge on `_turn_runner.declare_action(unit_id, ActionType.{MOVE|ATTACK|DEFEND|WAIT}, target)`; `_maybe_defer_turn_completion` predicate gates T6 advance until `state.action_token_spent` is set. S15-D drives a deterministic chapter-1 fixture (장판파; 2 player + 4 enemy heroes) through `initialize_battle()` → `_begin_round.call_deferred()` deferred chain + `await get_tree().process_frame` loop until `victory_condition_detected` emit fires; asserts the natural sequence `round_started(1)` → `unit_turn_started(<first_unit_in_initiative_order>)` → ... → non-DRAW outcome (player_victory or enemy_victory; ROUND_CAP DRAW also acceptable as deterministic terminal if fixture configured as such per AC-3 below). Test does NOT call `_advance_turn` / `declare_action` / `_seed_unit_state_for_test` / any `_`-prefixed test seam — drives via the **same surface a windowed `scenes/battle/battle_scene.tscn` boot would**.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (first-time natural-loop test infrastructure; sprint-15 R2 risk — could surface unforeseen test-framework gotchas → G-31 codification candidate per sprint-plan R2; ADR-0011 §Decision Contract 5 deferred-chain timing under `await get_tree().process_frame` loop has no precedent test in this codebase).
**Engine Notes**: No post-cutoff API surface beyond what S15-A/B/C already use (`Object.CONNECT_DEFERRED = 1`, `Callable.call_deferred()`, typed `Dictionary[int, K]` 4.4+). Test exercises `await get_tree().process_frame` per Godot 4.x deferred-call drain pattern — must bound iteration count to prevent infinite-loop on stalled chain (~600 frames cap = 10 seconds @ 60fps; failure mode = explicit `assert_bool(...).is_true()` with diagnostic message naming which signal slot never fired).

**Control Manifest Rules (Test layer per `.claude/rules/test-standards.md` + ADR-0014 §8 + G-30 §Correct steps)**:
- Required: `before_test` lifecycle hook (G-15) + explicit `free()` at end of each test body (G-6) + Overall Summary count verification (G-7) + Array-of-Dict signal capture (G-4) + real-autoload signal emit (G-10) + concrete subclass stubs for abstract types (G-22). HeroDatabase pre-seed per ADR-0016 IN-12 + IN-14 (mirrors `battle_scene_smoke_test.gd:51-76`).
- Forbidden: any direct `_advance_turn(unit_id)` or `declare_action(...)` or `_seed_unit_state_for_test(...)` test-seam call from S15-D test (defeats the G-30 mitigation purpose); any `await Engine.get_main_loop().process_frame` (use `get_tree()` per Godot 4.x idiom); any `push_error` / `push_warning` at boot (assert absence per G-30 step 2).
- Guardrail: existing 1314-test baseline preserved without regression — battle_scene_smoke_test.gd unchanged; new test file is purely additive.

---

## Acceptance Criteria

*From sprint-15.md S15-D acceptance criteria (5 baseline) + G-30 mitigation invariants (additional 4 per G-30 §Correct steps):*

- [ ] **AC-1** Test file exists at `tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd`. Mirrors `battle_scene_smoke_test.gd` scaffolding pattern (HeroDatabase pre-seed in `before_test` per ADR-0016 IN-12; chapter-1 장판파 roster — 2 player + 4 enemy; `extends GdUnitTestSuite`). Naming follows `test_[system]_[scenario]_[expected_result]` pattern per `.claude/rules/test-standards.md`.
- [ ] **AC-2** Test drives full battle from `BattleScene._ready()` → `controller.initialize_battle(roster)` → `_begin_round.call_deferred()` to `victory_condition_detected` emit using **natural deferred-chain progression**. NO direct `_advance_turn` / `declare_action` / `_seed_unit_state_for_test` calls. Iteration uses `await get_tree().process_frame` loop bounded to ~600 frames (10s @ 60fps) with explicit timeout-failure diagnostic if loop exits without victory_condition_detected emit.
- [ ] **AC-3** Test asserts the natural-sequence emit chain: `round_started(1)` fires → `unit_turn_started(<first_unit_in_initiative_order>)` fires (per ADR-0011 §Decision Contract 4 initiative-sort) → eventually `victory_condition_detected(<outcome>)` fires with outcome ∈ {player_victory, enemy_victory, ROUND_CAP_DRAW}. **Non-DRAW preferred** but ROUND_CAP_DRAW acceptable as deterministic terminal if chapter-1 fixture configured to reach round 5 without resolution (S15-D AC-5 of sprint-plan). Use Array-of-Dict capture per G-4 for emit recording (NOT direct GameBus instance access — capture via shared subscriber registered in `before_test`).
- [ ] **AC-4** Test exercises **both player + AI turn paths** within the same battle: at least 1 player-side `unit_turn_started` followed by player declare_action emit (via S15-C path) + at least 1 enemy-side `unit_turn_started` followed by AI declare_action emit (via S15-B path). Verifies S15-A T5 await releases on BOTH consumer types; verifies player + AI dispatch tables converge on the same TurnOrderRunner declare_action surface.
- [ ] **AC-5** Test added to CI baseline. Test count delta: 1314 baseline + ~1-3 new test functions (single end-to-end test acceptable; may split into 3 sub-tests for player-path / AI-path / non-DRAW resolution if test body grows >100 LoC). 0 NEW failures introduced; existing battle_scene_smoke_test.gd PASSES without regression.
- [ ] **AC-6** *(G-30 §Correct step 2 invariant)* No `push_error` / `push_warning` lines emitted to stderr during the natural-loop run. Capture stderr via test-runner output OR assert via `Engine.get_singleton("OS").stderr_capture` test-helper if available. If neither path practical in GdUnit4 v6.1.2, document the limitation in a code comment + assert presence of `Overall Summary` line per G-7 silent-skip protection.
- [ ] **AC-7** *(G-30 §Correct step 5 invariant)* Object lifetime under teardown: snapshot `Performance.get_monitor(Performance.OBJECT_COUNT)` before `BattleScene` mount + after `BattleScene.free()`; assert delta ≤ +5 (allows minor allocation drift but flags significant leak; G-6 + G-11 hygiene). Documents object-leak budget for future POLISH-008 closure baseline.
- [ ] **AC-8** Test deterministic across runs: 5 consecutive `godot --headless --import --path . tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd` invocations all PASS with identical outcome. No randomness in chapter-1 fixture (no `randi()` / `randf()` / time-dependent state). If non-determinism surfaces, document as G-31 codification candidate (sprint-plan R2 trigger) + amend test to seed with constant or document deterministic-mode requirement.
- [ ] **AC-9** Test isolation: `before_test` HeroDatabase pre-seed + `after_test` HeroDatabase reset (mirrors `battle_scene_smoke_test.gd:51-62`). Test does NOT depend on execution order vs other tests in `tests/integration/feature/battle_scene/` directory; runs cleanly both standalone (`--filter battle_scene_natural_loop_test`) AND as part of full-suite invocation.

---

## Implementation Notes

*Derived from G-30 §Correct steps 1-6 + battle_scene_smoke_test.gd scaffolding precedent + ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1 + #2) + grid_battle_controller_ai_action_ready_test.gd (S15-B precedent) + grid_battle_controller_player_declare_action_test.gd (S15-C precedent):*

1. **Scaffolding source** — copy `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd:1-83` verbatim for HeroDatabase pre-seed + `_instantiate_battle_scene()` + `before_test` / `after_test` hooks. Same chapter-1 roster (2 player + 4 enemy heroes; MOCK_HERO_IDS const). G-15 lifecycle hook (NOT `before_each`).

2. **Natural-loop driver** — single primary test function:
   ```gdscript
   func test_battle_scene_natural_loop_player_and_ai_paths_resolve_to_terminal_outcome() -> void:
       # Arrange: mount BattleScene + initialize_battle with chapter-1 roster.
       var scene: BattleScene = _instantiate_battle_scene()
       add_child(scene)
       await get_tree().process_frame  # let _ready() fire + deferred mounts complete
       var controller: GridBattleController = scene.get_grid_battle_controller()
       var roster: Array[BattleUnit] = _build_chapter_1_roster()
       var emit_log: Array[Dictionary] = []  # G-4 Array-of-Dict capture
       _wire_emit_capture(emit_log)
       # Act: initialize_battle + drain deferred chain until victory_condition_detected.
       controller.initialize_battle(roster)
       var victory_detected: bool = false
       var frame_budget: int = 600
       while frame_budget > 0 and not victory_detected:
           await get_tree().process_frame
           victory_detected = _has_victory_condition_in_log(emit_log)
           frame_budget -= 1
       # Assert: AC-3 emit-chain shape + AC-4 both-paths + AC-6 no warnings.
       assert_bool(victory_detected).override_failure_message(
           "AC-2/3: victory_condition_detected never emitted within 600-frame budget; "
           + "captured emits: %s" % str(emit_log)
       ).is_true()
       _assert_emit_chain_shape(emit_log)  # AC-3
       _assert_both_paths_exercised(emit_log)  # AC-4
       # Teardown.
       scene.free()
   ```

3. **Emit capture pattern** — `_wire_emit_capture(emit_log)` connects to GameBus signals (round_started, unit_turn_started, victory_condition_detected, AISystem.ai_action_ready) via `Object.CONNECT_DEFERRED = 1`; each handler appends `{"signal": "X", "args": [...]}` Dict to emit_log per G-4. Use real GameBus autoload (NOT a double per G-10).

4. **Chapter-1 roster builder** — `_build_chapter_1_roster()` constructs `Array[BattleUnit]` from MOCK_HERO_IDS (chapter-1 장판파 fixture). Reuse battle_scene_smoke_test.gd's HeroData seed pattern. If roster construction surface differs from existing scaffolding (e.g., requires UnitRole / HeroDatabase chained lookups), use concrete subclass stubs per G-22 — DO NOT abstract-test G-22 pitfall.

5. **Emit-chain shape assertions** (`_assert_emit_chain_shape`) — verifies emit log contains AT LEAST: 1 `round_started(1)` emit (first round) + 1 `unit_turn_started(*)` emit (any unit) + 1 `victory_condition_detected(*)` emit (terminal). Initiative-order assertion deferred to AC-3 baseline if exact ordering proves brittle (document as test simplification + log G-31 candidate if ordering fluctuates between runs).

6. **Both-paths assertion** (`_assert_both_paths_exercised`) — verifies emit log contains AT LEAST 1 player-side action emit (player unit declare_action via S15-C path → `unit_turn_started(player_unit_id)` followed by next-unit transition without `_handle_player_end_turn` short-circuit) + 1 AI-side action emit (enemy unit declare_action via S15-B path → AI ai_action_ready emit followed by next-unit transition). Discriminate player vs AI by `BattleUnit.side` field (0 = player, 1 = enemy per ADR-0014 §3 unit registry contract).

7. **Frame budget rationale** — 600 frames @ 60fps = 10s wall-clock budget. ROUND_CAP=5 (per TR-grid-battle-controller-010 / BalanceConstants MAX_TURNS_PER_BATTLE) × 6 units × ~5 deferred slots per turn ≈ 150 frames worst case; 4× safety multiplier = 600. If test consistently uses <100 frames, lower budget to 200 in follow-up to tighten timeout signal.

8. **Performance budget (AC-7)** — `Performance.get_monitor(Performance.OBJECT_COUNT)` snapshot pattern matches `battle_scene_smoke_test.gd:240` precedent. Delta budget ≤ +5 (smoke test currently uses ≤ +0 strict; natural-loop allows +5 to absorb deferred-chain transient allocations). If observed delta exceeds budget, document as POLISH-008 baseline candidate (object-leak existing tech debt; not S15-D scope to fix).

9. **G-31 codification trigger** — if first-run hits a gotcha not covered by G-1..G-30 (e.g., `await get_tree().process_frame` interaction with GdUnit4 v6.1.2 yield mechanics; emit-capture race condition with CONNECT_DEFERRED; Object.OBJECT_COUNT snapshot non-determinism), codify as G-31 inline in the test source comment + escalate to sprint-15 retrospective AI for `.claude/rules/godot-4x-gotchas.md` permanent codification (sprint-plan R2 mitigation path).

---

## Dependencies

- **Depends On**: S15-A (story-008; T5 await + `_maybe_defer_turn_completion`) — ✅ Complete (commit `ab924aa`); S15-B (story-011; AI handler + `_make_move_target` / `_make_attack_target` factories + 6-way dispatch) — ✅ Complete (commits `d5845de` + `a659b21`); S15-C (story-012; player path helpers + dispatch arm rewires) — ✅ Complete (commit `971c2ae`); **S15-J (story-014; `set_action_controller` production-wiring) — ⏳ in flight (mid-sprint amendment 2026-05-10 PM late-late; POLISH-012 closure)** — without S15-J close, the natural-loop test would technically pass AC-3 (terminal emit fires; ROUND_CAP_DRAW acceptable) but fail to demonstrate POLISH-011 closure end-to-end because production code never injects the controller Callable that activates S15-A/B/C wiring; T5 falls through TEST-SEAM no-op pass; AC-4 both-paths cannot show natural input/AI dispatch
- **Blocks**: S15-E (`/gate-check pre-prod-to-prod` rerun-4 — natural-loop integration test demonstration is the CD/TD/PR pivot per sprint-15.md S15-E AC-4); S15-G (S8-15 §1.3 third re-attestation post-POLISH-011-fix — natural-loop test PROVES the fix at automated-suite level before user re-attestation)

## Test Evidence

- **Type**: Integration (cross-system end-to-end: BattleScene mount ↔ GridBattleController dispatch ↔ TurnOrderRunner declare_action ↔ AISystem ai_action_ready ↔ HPStatusController apply_damage ↔ GameBus signal emit chain)
- **Location**: `tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd` (NEW)
- **Gate Level**: BLOCKING per `.claude/docs/coding-standards.md` Test Evidence Matrix

## Out of Scope

- Visual rendering verification (S15-I scope — paired-infrastructure optional visual-smoke harness for `chapter_visuals.gd`; G-30 verification gap pattern #2)
- Input pipeline verification (G-30 verification gap pattern #3 — `_unhandled_input` → InputRouter → GameBus.input_action_fired emit chain; deferred to dedicated InputRouter integration test if ever needed)
- POLISH-008 ObjectDB leak fix (AC-7 only documents baseline delta, does NOT fix existing leaks)
- POLISH-007 GameBus soft-cap subscriber growth (existing tech debt; orthogonal to natural-loop verification)
- Any modification to `_advance_turn` / `declare_action` / `_seed_unit_state_for_test` test seams (preserved unchanged for existing 1314 tests — S15-D adds NEW natural-loop test alongside, does NOT replace)
- Refactor or expansion of `battle_scene_smoke_test.gd` (smoke test stays focused on mount-sequence verification; natural-loop is a new scope orthogonal to mount-sequence smoke)
- Multi-chapter natural-loop coverage (chapter-1 장판파 only; subsequent chapters validated via dedicated tests if/when chapter-2+ ships)
- Determinism failure remediation (AC-8 documents detection; remediation deferred to G-31 codification + follow-up story if non-deterministic)

## Risks

- **R1**: First-time natural-loop test infrastructure surfaces G-31 codification candidate (sprint-plan R2 trigger). Most likely surface: `await get_tree().process_frame` loop interaction with GdUnit4 v6.1.2 yield mechanics; CONNECT_DEFERRED emit-capture race condition; or non-deterministic outcome from chapter-1 fixture initiative tie-break. Mitigation: codify inline in test source comment + escalate to sprint-15 retro AI for permanent G-31 entry; allow 0.1-0.2d additional buffer per sprint-plan R2.
- **R2**: Chapter-1 fixture (장판파) does not produce deterministic non-DRAW outcome under natural-loop progression. Mitigation: AC-3 explicitly accepts ROUND_CAP_DRAW as terminal; if outcome varies between runs (R1 surface), force determinism via fixture mutation (e.g., reduce enemy HP to ensure player_victory in ≤5 rounds) OR accept ROUND_CAP_DRAW + document fixture limitation. Either path satisfies AC-2 (deferred-chain progression to terminal emit) without requiring specific outcome shape.
- **R3**: Frame-budget timeout (AC-2 600-frame cap) fires due to legitimate slow battle resolution rather than stalled deferred chain. Mitigation: timeout failure message includes captured emit log per AC-2 diagnostic; if false-positive observed, raise budget to 1200 frames (20s) + re-run; if still timing out, investigate as POLISH-N candidate (deferred-chain stall = bug in S15-A T5 await OR S15-B/C dispatch contract).
- **R4**: AC-4 both-paths assertion may fail if chapter-1 fixture initiative-order resolves all player units before any enemy turn fires (e.g., player_victory before any AI ai_action_ready emit). Mitigation: chapter-1 fixture has 4 enemies vs 2 players (asymmetric in enemy favor by unit count); enemy unit gets initiative slot in round 1 most plausibly. If observed asymmetry persists, soften AC-4 to "AT LEAST 1 unit_turn_started for each side" (verifies T5 await releases for both side codes; less strict than declare_action emit assertion) + document as known limitation.
- **R5**: AC-7 `Performance.get_monitor(Performance.OBJECT_COUNT)` delta exceeds +5 budget due to existing POLISH-008 unfixed leak. Mitigation: AC-7 documents observed delta as POLISH-008 baseline; does NOT fail S15-D if delta within reasonable bound (≤ +20 acceptable as documented baseline; >+50 escalates to POLISH-N investigation). S15-D scope is verification, not leak remediation.
- **R6** *(REALIZED 2026-05-10 PM late-late at /dev-story Phase 4)*: Production-wiring residual — `set_action_controller` DI surface (S15-A `ab924aa`) has 0 production callers; production main_scene falls through TEST-SEAM no-op pass for T5; battle resolves to ROUND_CAP_DRAW identically with-or-without S15-A/B/C wiring; AC-4 both-paths cannot meaningfully demonstrate POLISH-011 closure end-to-end without the wiring fix. **Mitigation**: NEW story S15-J (story-014; POLISH-012 closure) added as mid-sprint amendment per sprint-15.md R4 mitigation pattern; S15-D /dev-story BLOCKED until S15-J close; after S15-J ships, S15-D resumes with the wiring activated and AC-4 will MEANINGFULLY demonstrate POLISH-011 closure. **Pattern**: 5th invocation of headless-vs-windowed verification gap (G-30); CLOSED-LOOP variant where the absorption-arc components ship correctly but the production wiring that activates them remains unverified — codification candidate for sprint-15 retro per ADR amendment process gap analysis (S15-A/B/C amendments documented component contracts but not the integration test that proves end-to-end wiring at production scope).

## Cross-References

- Sprint-15 plan S15-D row: `production/sprints/sprint-15.md:40` (acceptance criteria source)
- Sprint-15 plan R2 risk (first-time test infra → G-31 candidate): `production/sprints/sprint-15.md:62`
- Sprint-15 plan R4 risk (POLISH-N from S15-D discoveries): `production/sprints/sprint-15.md:64`
- Sprint-15 plan S15-I (paired visual-smoke harness — Nice to Have, depends on S15-D): `production/sprints/sprint-15.md:55`
- G-30 verification gap pattern (full body): `.claude/rules/godot-4x-gotchas.md:1144-1178`
- ADR-0011 §Amendment 2026-05-09 (S15-A T5 await + `_maybe_defer_turn_completion`): `docs/architecture/ADR-0011-turn-order.md` lines 513-561
- ADR-0014 §Amendment 2026-05-10 #1 (S15-B AI subscriber + 6-way dispatch): `docs/architecture/ADR-0014-grid-battle-controller.md` (end of file)
- ADR-0014 §Amendment 2026-05-10 #2 (S15-C player path mirror): `docs/architecture/ADR-0014-grid-battle-controller.md` lines 713-787
- ADR-0016 (BattleSceneWiring scene-root-as-orchestrator mount sequence): `docs/architecture/ADR-0016-battle-scene-wiring.md`
- Scaffolding template: `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd`
- S15-B test pattern (inner-class doubles + emit capture): `tests/integration/feature/grid_battle/grid_battle_controller_ai_action_ready_test.gd`
- S15-C test pattern (player dispatch arms + re-entrancy guard): `tests/integration/feature/grid_battle/grid_battle_controller_player_declare_action_test.gd`
- POLISH-011 backlog entry: `production/polish-backlog.md`
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3 + §11.4
