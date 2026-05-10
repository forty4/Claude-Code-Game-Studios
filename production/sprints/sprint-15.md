# Sprint 15 — 2026-05-12 to 2026-05-15 (3-day window; MIXED HYBRID closure-leaning with Logic-tier carry-condition closure)

## Sprint Goal

Close **POLISH-011 turn-loop architectural integration gap** (3-story arc S15-A/B/C spanning ADR-0011/0014/0019 amendments) so production main_scene executes battle loop end-to-end through natural input + AI dispatch paths. Pass `/gate-check pre-prod-to-prod` **rerun-4 PASS verdict** + flip `production/stage.txt` Pre-Production → Production. Secondary: resolve S14-05 producer §7 promotion call (2nd-time carry; 3rd-time eligible if not resolved this sprint per Route c default per R7).

## Capacity

- **Total days**: 3.0d (3-day window 2026-05-12 entry → 2026-05-15 close target)
- **Buffer (20%)**: 0.6d reserved for unplanned (e.g., S15-A T5 await mechanism design surfacing additional ADR-0011 amendment scope per R1; S15-D integration test infrastructure first-time scope expansion per R2)
- **Available**: 2.4d nominal claude-side + ~30 min user-time (S15-G S8-15 §1.3 third re-attestation ~15min + S14-05 user concurrence ~10min + final stage.txt flip authorization ~5min if PASS)
- **Projected actual** (Logic-tier work; sprint-15 NOT closure-mode despite being closure-leaning — POLISH-011 absorption is implementation work, not doc edits): **~1.5-2.0d actual claude-side** (vs 0.7-1.0d closure-mode sprints sprint-12/13/14)

## Carryover Backlog (from Sprint-14)

> **§11 HARD GATE binding rebind expected**: per sprint-13 retro AI #2 + closure-mode signal evaluation, carryover concentration ≥5 → rebind to closure-leaning. Sprint-15 has **6 effective carryover items** (POLISH-011 absorption arc counts as 3 stories per gate-check rerun-3 §6 path-to-PASS Item 10 §3 + S14-05 + S14-09 + optional smoke harness). **Rebind triggered**; sprint-15 mode designated MIXED HYBRID closure-leaning at entry per §11.4 Trigger 4 evaluation below. **2nd consecutive closure-leaning sprint** (sprint-14 was 1st); per sprint-13 retro AI #9 / sprint-14 retro AI #11, this is a watchpoint for closure-mode pattern stability.
>
> **Codified per sprint-9 retro AI #2** (paid via sprint-11 S11-01): Carryover items listed in dedicated section AHEAD of new scope so cumulative carryover-concentration threshold is visible at sprint-plan time.

| Carryover Task | Original Sprint | Times Carried | Disposition | New Estimate / Target Tier |
|---|---|---|---|---|
| **POLISH-011** turn-loop architectural integration gap (CRITICAL release-blocker; gates Production advancement; 3 unwired integration boundaries: T5 stub + AISystem.ai_action_ready subscriber + declare_action plumbing) | sprint-14 | 1 | KEEP → Must Have S15-A + S15-B + S15-C (3-story split) | ~0.5d nominal each (~1.5d aggregate; 10-15h claude-side) |
| **S13-06 producer §7 promotion call** (USER-OWNED; Route a vs Route c retention decision) | sprint-12 | **3 (→13 → 14 → 15)** | KEEP → Should Have S15-F | ~0.05d claude paper + ~10min user; **3rd-time carry** — Route c default per R7 if user unavailable at sprint-15 close |
| **S14-09 mid-sprint mode redesignation tracking** (Tracking-only; no trigger fired sprint-14) | sprint-14 | 1 | KEEP → Nice to Have S15-H (tracking-only) | 0d (no-op carry; pattern stability monitor) |
| **Optional visual-smoke harness for `chapter_visuals.gd`** (G-30 mitigation; paired with TD-071/073 verification-gap test infrastructure) | sprint-14 | 1 | KEEP → Nice to Have S15-I | ~0.15d (1-2hr if paired with S15-D natural-loop test infrastructure) |
| **POLISH-007** GameBus soft cap exceeded headless (ADVISORY tier; deferred since sprint-13) | sprint-13 | 2 | DESCOPE → backlog (no forcing function; defer to Polish-stage entry OR real-play F5 surfacing) | 0d (descoped to backlog this sprint per 2-carryover-visibility-threshold rule) |
| **POLISH-008** ObjectDB instances leaked at exit (ADVISORY tier; deferred since sprint-13) | sprint-13 | 2 | DESCOPE → backlog (no memory-pressure forcing function) | 0d (descoped to backlog per 2-carryover-visibility-threshold rule) |

**Carryover concentration**: 6 effective items at entry (3-story POLISH-011 + S14-05 + S14-09 tracking + optional smoke harness). 2 ADVISORY items DESCOPED per visibility rule (POLISH-007 + POLISH-008). §11 HARD GATE rebind succeeds at plan-time.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S15-A | **POLISH-011 absorption — ADR-0011 §Decision Contract 5 Callable controller wiring + T5 await** — replace `_execute_action_budget(_unit_id)` stub at `turn_order_runner.gd:561-562` with the controller dispatch obligated by story-005 (unfulfilled). T5 must AWAIT until external action declared before proceeding to T6. | godot-gdscript-specialist + lead-programmer | 0.4d (~3-5h) | None (entry blocker) | (1) `_execute_action_budget` body implements Callable controller dispatch per ADR-0011 §Decision Contract 5; (2) T5 holds until `declare_action()` is called for the active unit; (3) ADR-0011 amendment ratifies the implementation decision; (4) integration test drives single-turn flow to verify hold-and-release; (5) 1288 baseline preserved + new tests added |
| S15-B | **POLISH-011 absorption — AISystem.ai_action_ready subscriber + declare_action plumbing for AI commands** — connect `AISystem.ai_action_ready` to a handler that routes the emitted `AIActionCommand` into `_turn_runner.declare_action()` + executes the command (move unit / apply damage / etc.). | godot-gdscript-specialist + lead-programmer | 0.3d (~2-4h) | S15-A (T5 must await before AI subscriber can fire declare_action) | (1) `_on_ai_action_ready` handler exists in `grid_battle_controller.gd` (or appropriate owner); (2) Handler maps `AIActionCommand.action_type` → `TurnOrderRunner.ActionType` correctly for all 5 actions (MOVE/ATTACK/USE_SKILL/DEFEND/WAIT); (3) Handler executes the actual game action (calls `_handle_move` / `_handle_attack` / etc.); (4) Handler calls `_turn_runner.declare_action()` to release T5 and advance turn; (5) ADR-0014 amendment documents the subscriber contract; (6) Integration test drives AI-only battle to non-DRAW resolution |
| S15-C | **POLISH-011 absorption — Player declare_action plumbing in grid-click handlers** — extend `grid_battle_controller.gd:_handle_grid_click_unit_selected` action arms (move_target_select / move_confirm / attack_target_select / attack_confirm / end_unit_turn) so natural grid-click MOVE/ATTACK/USE_SKILL/DEFEND flows call `declare_action()`. Currently only `end_player_turn()` does. | godot-gdscript-specialist + lead-programmer | 0.4d (~3-5h) | S15-A (T5 must await before player input can fire declare_action) | (1) Each grid-click action arm in `_handle_grid_click_unit_selected` calls `_turn_runner.declare_action()` with appropriate ActionType after handling; (2) ADR-0019 amendment documents the player input → declare_action contract; (3) Integration test drives mixed player+AI battle through natural input dispatch to non-DRAW resolution; (4) Edge cases: action_token_spent guard / move_token_spent guard; (5) 1288 baseline preserved + new tests added |
| S15-D | **Natural-loop integration test (G-30 mitigation infrastructure)** — author `tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd` that drives full battle via `initialize_battle` → `_begin_round.call_deferred()` → outcome emit (NOT direct test-seam calls). Closes G-30 verification gap pattern for the turn loop itself. **DEFERRED to sprint-16 per POLISH-013 (mid-sprint 3-spawn-cycle attempt surfaced deferred-chain progression gap exceeding 2-3h estimate; test environment vs production unresolved without S15-G windowed re-attestation; META-pattern: test designed to close G-30 surfaced NEW G-30 instance — verification gap pattern #6)**. | godot-gdscript-specialist + qa-tester | 0.3d → ~3h actual + DEFERRED | S15-A + S15-B + S15-C + S15-J | DEFERRED — POLISH-013 entry documents 3-fixture-iteration attempt + sprint-16 reframed-scope paths (debug instrumentation / input simulation / delayed-victory-eval / reduced ACs). Story-013 file at `production/epics/grid-battle-controller/story-013-natural-loop-integration-test.md` REMAINS Ready for sprint-16 reauthoring. |
| **S15-J** | **POLISH-012 closure — `set_action_controller` production-wiring (BattleScene._ready Callable injection)** — *MID-SPRINT AMENDMENT 2026-05-10 PM late-late*: POLISH-011 absorption-arc residual discovered at S15-D /dev-story Phase 4 godot-gdscript-specialist mid-implementation investigation. `set_action_controller` DI surface (S15-A) has 0 production callers; production main_scene falls through TEST-SEAM no-op pass for T5 → ROUND_CAP_DRAW in 2-3s. Single ~3-line addition in `battle_scene.gd` STEP 5 + NEW handler `_on_turn_runner_action_request` on `grid_battle_controller.gd` + ADR-0014 §Amendment 2026-05-10 (#3) + ~5 integration tests. Sprint-15 R4 risk REALIZED via investigation-time catch (faster + cheaper than the anticipated test-first-run-failure path). | godot-gdscript-specialist | 0.15d (~1-2h) | S15-A + S15-B + S15-C | (1) `_on_turn_runner_action_request(unit_id: int, snapshot: UnitTurnState) -> void` handler added to `grid_battle_controller.gd` with side-routing (player → return; enemy → AISystem.decide); (2) `BattleScene._ready` STEP 5 extends with `_turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)` BEFORE `add_child`; (3) ADR-0014 §Amendment 2026-05-10 (#3) extends prior amendments to specify the BattleScene mount-sequence integration site; (4) Integration test `tests/integration/feature/battle_scene/battle_scene_set_action_controller_wiring_test.gd` covers Callable registration + enemy-side dispatch + player-side defer + backward compat + defensive unknown-unit_id; (5) 1314 baseline + ~5 new tests = ~1319; 0 NEW failures; existing `turn_order_t5_await_test.gd` 7 sites continue to PASS unchanged |

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S15-E | **/gate-check pre-prod-to-prod rerun-4** — re-evaluate after S15-A/B/C/D land; PASS verdict (production/stage.txt flip) OR CONCERNS verdict if any director downgrades; sprint-11 retro AI #1 follow-through closure | claude (lean-mode 4-director panel) | 0.05d (~30min) | S15-A + S15-B + S15-C + S15-D + S15-G | (1) 4-director panel parallel review (lean mode); (2) Verdict artifact at `production/gate-checks/pre-prod-to-prod-2026-05-1?-rerun-4.md`; (3) Substrate ratchet assessment vs rerun-3 (POLISH-011 closure + Item 7 §1.3 third-attestation); (4) AD's READY expected to hold; CD/TD/PR verdict pivots on natural-loop integration test demonstration |
| S15-F | **S14-05 S13-06 producer §7 promotion call** (3rd-time carry; Route c default per R7 if user unavailable) — author producer paper at `production/decisions/decisions-convention-promotion-evaluation-2026-05-1?.md` + user concurrence | producer + user | 0.05d claude paper + ~10min user | None | (1) Producer paper exists at specified path; (2) Route a (promote) vs Route c (stay) decision recorded; (3) User concurrence captured in artifact; (4) If 3rd-time carry without user concurrence by sprint-15 close, Route c default applies (closure-mode pattern per R7); (5) decisions-convention.md §7 amended if Route a chosen |
| S15-G | **S8-15 §1.3 third re-attestation post-POLISH-011-fix** — refusal-to-fabricate posture preserved (3rd invocation; pattern stability ESCALATES 2→3 if invoked); user re-runs Batch 1.3 input-responsive test against post-S15-A/B/C build | user (after Items #3 land) | 0d claude-side (~15min user time) | S15-A + S15-B + S15-C | (1) User re-runs Batch 1.3 input-responsive test (windowed boot of `scenes/battle/battle_scene.tscn` + grid-click on player unit + verify input dispatched); (2) `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S15-G Re-Attestation section added; (3) Refusal-to-fabricate posture preserved (honest verdict regardless of outcome — PASS/FAIL/MIXED both honored); (4) S8-15 carry chain TERMINATES at S15-G (sprint-8 → 15 = 7-sprint carry chain — exceeds prior project-record 6-sprint S7-11 chain) |

### Nice to Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|--------------|---------------------|
| S15-H | **Mid-sprint mode redesignation precedent tracking** (carry from S14-09; sprint-13 retro AI #9; pattern stable at 1 invocation; track for ≥2-invocation codification trigger) | producer | 0d | None | Tracking-only; no-op default; if mid-sprint trigger fires (e.g., sprint-15 absorbs new Logic-tier work mid-sprint), pattern reaches 2 invocations → codification trigger |
| S15-I | **Optional visual-smoke harness for `chapter_visuals.gd`** — G-30 mitigation; paired with TD-071/073 verification-gap test infrastructure (same `tests/integration/feature/battle_scene/` directory as S15-D) | godot-gdscript-specialist | 0.15d (~1-2h) | S15-D (paired infrastructure) | (1) `tests/integration/feature/battle_scene/battle_scene_visual_smoke_test.gd` authored; (2) Verifies non-blank pixel sentinel OR `_draw()` invocation count > 0 on chapter_visuals.gd at scene mount; (3) Verifies no `push_error` / `push_warning` at scene boot; (4) 1288 baseline + S15-D tests + S15-I tests preserved together |

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| **R1**: S15-A T5 await mechanism design surfaces additional ADR-0011 amendment scope (e.g., re-entrant declare_action handling, deferred-vs-synchronous tradeoffs) | MEDIUM | HIGH (could push S15-A from 3-5h to 6-8h) | Buffer 0.6d allocated; if R1 triggers, ADR-0011 amendment can be split into 2 amendments (initial wire-up at S15-A; refinement at sprint-16 if needed) |
| **R2**: S15-D natural-loop integration test infrastructure first-time authoring (no existing similar tests in codebase) — could hit unforeseen test-framework gotchas (G-N pattern triggers) | MEDIUM | MEDIUM | Lean on existing G-1..G-30 patterns; if new gotcha discovered, sprint-15 retro AI codifies as G-31; allow 0.1-0.2d additional buffer for first-time integration test authoring |
| **R3**: User unavailable at sprint-15 close window for S15-G third re-attestation | LOW | MEDIUM (delays rerun-4 verdict) | S8-15 §1.3 re-attestation carries to sprint-16 if user unavailable; sprint-15 still closes APPROVED WITH CONDITIONS regardless |
| **R4** *(REALIZED 2026-05-10 PM late-late)*: POLISH-011 fix surfaces ADDITIONAL integration gaps beyond the 3 identified (e.g., target_pos vs target_unit_id confusion in AIActionCommand routing; 5-action ActionType mapping ambiguity). **Realized form**: `set_action_controller` production-wiring residual (POLISH-012) discovered at S15-D /dev-story Phase 4 godot-gdscript-specialist mid-implementation investigation BEFORE first test run; `set_action_controller` DI surface (S15-A) has 0 production callers; production main_scene falls through TEST-SEAM no-op pass for T5. **Mid-amendment vehicle**: S15-J Must Have promotion (mirrors sprint-13 S13-11/12 mid-amendment precedent — anticipated path was Should Have promotion + first-run failure path; actual path is Must Have promotion + investigation-time catch which is FASTER + CHEAPER). | MEDIUM | MEDIUM | S15-D natural-loop integration test catches these by failing on first run; mid-sprint amendment absorbs via Should Have promotion (mirrors sprint-13 S13-11/12 mid-amendment precedent) |
| **R5**: Sprint-15 carryover concentration at sprint-16 entry (POLISH-011 if not closed + S14-05 if not closed + S14-09 if no trigger fires + new POLISH-N from S15-D test discoveries) — could trigger 3rd consecutive closure-leaning rebind | MEDIUM | MEDIUM (3 consecutive closure-leaning sprints would signal substrate non-stabilizing) | Sprint-15 retro AI #11 watches for this; if sprint-16 also closure-leaning, escalate process-significance signal to /retrospective for structural review |

## Dependencies on External Factors

- **User availability**: S15-G third re-attestation requires user windowed-boot test (~15min); S15-F producer §7 user concurrence (~10min); final stage.txt flip authorization (~5min if PASS)
- **Godot 4.6.2 Engine**: no engine version changes expected this sprint
- **External libraries**: none

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S15-A + S15-B + S15-C + S15-J done 4/5; **S15-D DEFERRED to sprint-16 per POLISH-013 mid-sprint 2026-05-10 PM very-late — 3-spawn-cycle attempt surfaced deferred-chain progression gap; test environment vs production unresolved without S15-G windowed re-attestation**)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists at `production/qa/qa-plan-sprint-15-2026-05-1?.md` (entry-time)
- [ ] All Logic/Integration stories have passing unit/integration tests (S15-A/B/C unit + S15-D integration)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations (ADR-0011 + ADR-0014 + ADR-0019 amendments per S15-A/B/C)
- [ ] Code reviewed and merged
- [ ] **§11 HARD GATE binding fulfillment** (per sprint-13 retro AI #2): if §11 HARD GATE was bound at sprint-15 entry per closure-leaning rebind, disposition documented at close (USER-ATTESTED disposition (a) or (b) per closure-mode pattern §11.4)
- [ ] **POLISH-011 closure verification** (sprint goal): production main_scene executes battle loop end-to-end through natural input + AI dispatch paths without ROUND_CAP DRAW; rerun-4 verdict eligible PASS

## Sprint Mode

**MIXED HYBRID closure-leaning** — §11 HARD GATE rebind triggered at sprint-15 plan-time per concentration ≥5 audit (6 effective carryover items: POLISH-011 3-story arc + S14-05 + S14-09 + optional smoke harness; 2 ADVISORY items POLISH-007/008 DESCOPED per visibility rule).

**Closure-leaning rationale**: sprint-15 sprint-goal IS closure of POLISH-011 carry-condition (the largest in chain history). Despite the work being Logic-tier (not doc-edit closure-mode like sprint-13/14), the GOAL framing is closure-mode. Mode designation: **MIXED HYBRID closure-leaning** — closure-leaning by goal, HYBRID by work-type.

**Distinction from sprint-14 entry**: sprint-14 was MIXED HYBRID closure-leaning with content-authoring (S14-02 Visual/UI). Sprint-15 is MIXED HYBRID closure-leaning with Logic-tier (S15-A/B/C). Both share the closure-mode goal framing; both require §11 HARD GATE binding rebind.

**2nd consecutive closure-leaning sprint** — sprint-14 retro AI #11 watchpoint TRIGGERED. If sprint-16 is ALSO closure-leaning (3rd consecutive), escalate process-significance signal to /retrospective for structural review (R5 mitigation).

---

## §11 HARD GATE Binding Trigger

Per `docs/process/decisions-convention.md` §11.4 Trigger 4: "Sprint carryover concentration ≥5 items".

Sprint-15 entry concentration: **6 effective items** (POLISH-011 absorption arc 3 stories + S14-05 + S14-09 + optional smoke harness). Threshold breached. **§11 HARD GATE binding ACTIVATED at sprint-15 entry**.

Binding obligation: §11 HARD GATE disposition (a) or (b) MUST be recorded at sprint-15 close. Sprint-14 disposition was USER-ATTESTED (a) closure-success at S14-04 (despite verdict FAIL — the BINDING was on path-to-PASS items 5/6/8/9 which were CLOSED, not on the rerun verdict). Sprint-15 binding will be on POLISH-011 closure.

Disposition expectation: USER-ATTESTED disposition (a) at sprint-15 close — POLISH-011 turn-loop integration gap CLOSED via S15-A/B/C; rerun-4 verdict PASS or CONCERNS.

---

## Carry-conditions to Sprint-16 (anticipated)

If sprint-15 closes APPROVED WITH CONDITIONS (matching sprint-12/13/14 precedents):

1. POLISH-011 user re-attestation (S8-15 §1.3 third invocation) — only if S15-G slips to sprint-16
2. S14-05 S13-06 producer §7 promotion call — 4th-time carry if not resolved (Route c default fires per R7)
3. Sprint-15 retro AI carryforwards (active count expected ~10-13 depending on which AIs close in-sprint)
4. POLISH-007 + POLISH-008 (ADVISORY tier) — DESCOPED but tracked
5. New POLISH-N entries if S15-D natural-loop integration test surfaces additional gaps (R4 mitigation)

Anticipated sprint-16 carryover concentration: 3-5 items (depends on S15-G outcome + sprint-15 retro AI count). If ≥5, 3rd consecutive closure-leaning rebind triggers (R5 escalation).

---

## Mid-Sprint Amendments

- **2026-05-10 PM very-late — S15-D DEFERRED to sprint-16 (POLISH-013 closure deferral)**: 3-spawn-cycle godot-gdscript-specialist attempt at authoring `tests/integration/feature/battle_scene/battle_scene_natural_loop_test.gd` surfaced reproducible deferred-chain progression gap across 3 fixture iterations (chapter-1 / hybrid 1-stub-player+4-enemies / TRUE 0-player-units+4-enemies — same outcome: 2 emits captured / 4000 frames consumed / no victory_condition_detected). Root-cause hypothesis UNRESOLVED: AISystem CONNECT_DEFERRED subscriber may not fire in test scope (Hypothesis A — test-env-only gap; production fine) OR POLISH-011 absorption arc didn't actually close natural-loop progression end-to-end (Hypothesis B — real production defect). **S15-G windowed re-attestation by user is the gate that determines this.** S15-J wiring test #2 verifies enemy-side dispatch chain at UNIT scope (component contracts correct); cross-system progression unverified. Test scaffolding (~600 LoC) deleted at sprint-15 close-out per "never disable failing tests" project discipline; recoverable via git history; sprint-16 reauthoring per POLISH-013 §sprint-16 paths (debug instrumentation / input simulation / delayed-victory-eval / reduced ACs). Sprint-15 closes 4/5 Must Have done (S15-A/B/C/J); S15-D status: deferred. **6th invocation of headless-vs-windowed verification gap pattern (G-30) — META-pattern: even the test designed to close G-30 verification gap pattern #5 ITSELF surfaces a G-30 instance.** Sprint-15 retro AI strongly seeded for G-30 §Discovered list update + structural review of G-30 mitigation strategy.

- **2026-05-10 PM late-late — S15-J Must Have promotion (POLISH-012 closure)**: discovered during S15-D /dev-story Phase 4 godot-gdscript-specialist mid-implementation investigation BEFORE first test run. `set_action_controller` DI surface (S15-A `ab924aa`) has 0 production callers (`grep -rn "set_action_controller" src/ tests/` → 7 test sites + 0 src callers); production main_scene falls through TEST-SEAM no-op pass for T5; battle resolves to ROUND_CAP_DRAW identically with-or-without S15-A/B/C wiring. R4 risk REALIZED via investigation-time catch (faster + cheaper than the anticipated test-first-run-failure path). Amendment vehicle: **S15-J Must Have promotion** (NOT Should Have as R4 mitigation anticipated — the production-wiring residual is a release-blocker per POLISH-012 CRITICAL tier; gates Production stage advancement; cannot defer past sprint-15 close). Story: `production/epics/grid-battle-controller/story-014-set-action-controller-production-wiring.md`. Estimate: ~1-2h. Dependencies: S15-A/B/C all Complete. Blocks: S15-D (story-013 natural-loop test cannot meaningfully demonstrate POLISH-011 closure end-to-end without the wiring); S15-E (gate-check rerun-4); S15-G (S8-15 §1.3 third re-attestation post-POLISH-011-fix). Pattern: 5th invocation of headless-vs-windowed verification gap (G-30) — codification candidate for sprint-15 retro to update G-30 §Discovered + add wiring-verification-AC discipline to absorption-arc story templates. Mirrors sprint-13 S13-11/12 mid-amendment precedent (anticipated Should Have promotion path; actual Must Have promotion path).

## Cross-References

- Sprint-14 retro: `production/retrospectives/retro-sprint-14-2026-05-09.md` (commit `1b59f40`)
- Sprint-14 sign-off: `production/qa/qa-signoff-sprint-14-2026-05-09.md`
- Gate-check rerun-3 (path-to-PASS source): `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-3.md` Item 10 §3
- POLISH-011 entry + TRIAGE FINDING: `production/polish-backlog.md` (search "POLISH-011")
- ADR-0011 (TurnOrderRunner; §Decision Contract 5): `docs/architecture/ADR-0011-*.md`
- ADR-0014 (GridBattleController): `docs/architecture/ADR-0014-*.md`
- ADR-0019 (AISystem): `docs/architecture/ADR-0019-*.md`
- G-30 verification gap pattern: `.claude/rules/godot-4x-gotchas.md` G-30
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3 + §11.4
- TD-071/072/073 (sibling verification-gap entries): `docs/tech-debt-register.md`
