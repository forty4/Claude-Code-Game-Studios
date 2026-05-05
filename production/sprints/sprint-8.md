# Sprint 8 — 2026-06-07 to 2026-06-13

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-05-05 (`docs/architecture/control-manifest.md` — refreshed via S7-08)
> **Generated**: 2026-05-05
> **Carries**: Sprint-7 retro AI seeds (5 carried forward — see §Sprint-8 Retro AI seed) + Producer split-input-handling-epic recommendation (PR-PHASE-GATE 2026-05-05) + TD InputRouter-ADR-before-impl gate + AD AD-C3 + AD-C5 + AD-C6 carryovers
> **Generated to close**: Production-phase first sprint — input-handling unblock + chapter-1 integration vertical-slice + 2 newly-Designed GDD implementations (Story Event #10 + Destiny State #16)

## Sprint Goal

**Unblock input-handling + ship chapter-1 (장판파) end-to-end as a runnable vertical-slice + close 2 newly-Designed GDDs (Story Event #10 + Destiny State #16) into runtime.** This is the first Production-phase sprint. InputRouter graduates from 33-line PLACEHOLDER to functional FSM (stories 1-5 of input-handling epic; remaining 6-10 deferred to sprint-9 per Producer split). S7-10 battle-hud two-tap timer ships as immediate cash-in once InputRouter `_handle_event` lands. Story Event #10 + Destiny State #16 GDD implementations (sprint-7's newly-Designed pair) ratify Pillar 2 architectural lock candidates 5+6, bringing Pillar 2 lock pattern from "4 shipped + 2 candidates" to "6 shipped". Chapter-1 (장판파) integration run validates the ScenarioRunner + DestinyBranchJudge + AISystem + Story Event coordination as the first user-experienceable narrative arc.

## Pivot context (carried from sprint-7 + gate-check 2026-05-05)

Sprint-7 was the **chapter-arc sprint**: 4 must-haves shipped (ScenarioRunner + DestinyBranchJudge + AISystem + chapter-1 data) + 3 should-haves (Story Event #10 GDD + Destiny State #16 GDD + chapter-1 data) + 2 nice-to-haves (control-manifest backfill + battle-hud story-004). Sprint-7 closed at **9/11 stories** (Must+Should 7/7 + Nice 2/4); S7-10 BLOCKED on input-handling epic (InputRouter PLACEHOLDER discovered at story-attempt time); S7-11 USER-OWNED.

Gate-check 2026-05-05 returned **CONCERNS** — significant upgrade from 2026-05-04's 4× CONCERNS to 1× CONCERNS (CD only) + 3× READY (TD + PR + AD). Sole remaining gating blocker: S7-11 user attestation on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md`. Per refusal-to-fabricate posture (`tooling-gotchas.md` TG-2 + damage-calc 2026-04-27 precedent), this is genuinely outside claude control.

Sprint-8 is the **Production-phase entry sprint**. Producer recommended split-input-handling-epic across sprint-8 (stories 1-5) + sprint-9 (stories 6-10) rather than absorbing the full 10-story epic. TD recommended InputRouter ADR authoring before implementation (gate before impl). AD recommended first 2-3 character profile stubs + AD-C3 font glyph check before story-event text rendering tasks land.

## Capacity (per sprint-7 retro — 5th consecutive AI #1 ratchet evaluation)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work (input-handling epic discovery risk per S7-10 lesson)
- Available: **4.25 working days**

> **AI #1 ratchet (5th consecutive)**: sprint-7 was 4.5d nominal / ~1-1.5d actual = ~3-5× off. Sprint-8 plan targets **~3.0d Must-Have nominal** (up from sprint-7's 2.0d to absorb 5-story input-handling block + InputRouter ADR + S7-10 unblock per Producer "1.5× sprint-7 nominal" sizing). Should-Have absorbs slack if Must lands fast (sprint-7 pattern); Nice-to-Have buffers further. Velocity-multiplier baseline now stable at 3-5× nominal across sprint-5/6/7 — projection for sprint-8 actual: ~0.6-1.0d. If Must+Should ship in <1.5 calendar days per sprint-7 pattern, sprint-9 plan tightens further.

## Context

Project state as of 2026-05-05 (post-sprint-7 close + gate-check 2026-05-05):

- **19 ADRs Accepted**. ADR-0019 (AI System) Accepted 2026-05-05 via /architecture-review delta #14 (commit 05c9e6d). ADR-0020 (InputRouter) NEW Proposed → Accepted target via S8-01.
- **Pre-Production → Production verdict**: CONCERNS (gate-check 2026-05-05). 3 directors READY + 1 CONCERNS (CD only — Pillar 3+4 demonstration unproven without playtest evidence).
- **Sole gate-check upgrade blocker**: S7-11 user attestation on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` (USER-OWNED).
- **Pillar 2 architectural lock pattern firmly stable at 4 invocations + 2 candidates** (Destiny State #16 + Story Event #10 GDDs). Sprint-8 implementation flips both candidates to "stable at 6 invocations".
- **Battle-scoped Node pattern at 6 invocations** (HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD + AISystem).
- **Autoload Node pattern at 8 shipped** + 2 candidates (boot pos 7 + 8 from Destiny State + Story Event); ADR-0020 InputRouter would extend lineage further.
- **Control manifest refreshed 2026-05-05 to 634 lines** (ADRs 0005..0013 + 0019 backfilled across Foundation/Core/Feature; coverage advisory CLOSED).
- **978/978 PASSING / 108 suites** (26th+ consecutive failure-free baseline).
- **20 epics in production/epics/**: input-handling Ready (10 stories not yet started) + scenario-progression + destiny-branch + ai-system Ready (story-001 close pending).
- **chapter-prototype/REPORT.md PROVISIONAL PROCEED** verdict on MVP Core Hypothesis (mechanical substrate only; 4 VS Validation items USER-OWNED).
- **Save/Load #17 GDD remains PROVISIONAL** — sprint-8 should-have authoring closes the GDD-authoring gap.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S8-01 | `/architecture-decision` — author **ADR-0020 InputRouter** Proposed → Accepted via combined-session escalation pattern (5th invocation; same-day fresh /architecture-review delta #15 OK). Spec: `_handle_event(event: InputEvent) -> void` dispatch contract per input-handling.md F-1/F-2; touch-mouse separation per technical-preferences.md "no hover-only"; 6+ forbidden_patterns; DI test seam; integration with ADR-0014 GridBattleController + ADR-0015 BattleHUD `input_state_changed` + `input_mode_changed` GameBus emits. | claude | 0.4 | — | ADR-0020 Accepted; tr-registry.yaml v15 → v16 with TR-input-handling-001..N entries; architecture.yaml v13 → v14; gate-before-impl discipline ratified. |
| S8-02 | input-handling story-001 — module skeleton + autoload registration (`/root/InputRouter` load order 4 per ADR-0005; joins GameBus + SceneManager + SaveManager autoload lineage). | claude | 0.3 | S8-01 | InputRouter autoload registered + boots cleanly + smoke test PASS; ~5 net new tests. |
| S8-03 | input-handling story-002 — action vocabulary + bindings.json (default_bindings.json schema + StringName action keys + emulate_mouse_from_touch=false project setting per ADR-0005 same-patch obligation). | claude | 0.3 | S8-02 | bindings.json loads + Input.is_action_pressed(action) functional + ~6 tests. |
| S8-04 | input-handling story-003 — FSM core S0/S1/S2 move flow (state machine + move action dispatch + integration with GridBattleController via ADR-0014 ai_action_requested signal pattern). | claude | 0.5 | S8-03 | FSM transitions S0→S1→S2 + move action dispatched to GridBattleController + ~10 tests. |
| S8-05 | input-handling story-004 — FSM attack S3/S4 + ST2 demotion (attack action dispatch + ST2 demotion gate per CR-IH-3). | claude | 0.4 | S8-04 | FSM transitions S3→S4 + ST2 demotion + ~8 tests. |
| S8-06 | input-handling story-005 — mode determination CR-2 (input_mode_changed GameBus emit + Tap Preview Protocol contract from BattleHUD subscribe at ADR-0015 line 235-236). | claude | 0.3 | S8-05 | input_mode_changed signal fires + BattleHUD subscribes + Tap Preview Protocol Closes ADR-0005 lines 235-236 provisional contract; ~6 tests. |
| S8-07 | **S7-10 unblock + ship** — battle-hud story-005 (UI-GB-02/05/10 + two-tap ATTACK/DEFEND HUD-owns-timer per TR-005/017; AC-UX-HUD-08/09 contract verification). | claude | 0.5 | S8-06 (InputRouter `_handle_event` test seam now exists) | story-005 Complete + UI-GB-02/05/10 render + two-tap timer per battle-hud.md §AC-UX-HUD-08/09; ~10 tests; ~1010 PASS target. |

**Must-have subtotal: ~2.7 working days nominal** (~22h). Per 5th-ratchet AI #1, projected actual: ~0.6-0.9 calendar day at sprint-7 3-5× velocity multiplier.

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S8-08 | `/design-system save-load` — Save/Load #17 GDD authoring (PROVISIONAL → Designed) — schema spec + persistence contract + cross-chapter destiny-state propagation per ADR-0003 SaveContext + ADR-0017 ScenarioRunner 3-CP save integration; carryover from sprint-7 Producer pressure-cut. | claude | 0.4 | — | Save/Load GDD has 8 required sections; systems-index.md row 17 PROVISIONAL → Designed; cross-refs to ADR-0003 + ADR-0017 + game-concept Pillar 2/4. |
| S8-09 | **Story Event #10 implementation** per S7-06 GDD — 3 GameBus signals registration (story_event_resolved + story_event_invalid_path_detected + story_event_revelation_committed per CR-SE-2/3/19) + ADR-0001 minor amendment per Evolution Rule #4 + autoload registration (boot pos 8 — 9th invocation of autoload Node pattern) + 6-variant closed-branch-state vocabulary const + invalid-gate D1 BLOCKING contract enforcement + Pillar 2 architectural lock 6th invocation candidate flips to shipped (`story_event_reads_destiny_state` forbidden_pattern). | claude | 0.5 | S7-06 GDD Designed (✅) | StoryEvent autoload registered; 3 new GameBus signals fire per protocol; 6-variant closed vocabulary; invalid-gate contract enforced; Pillar 2 lock 6th invocation lint PASS; ~10-12 tests. |
| S8-10 | **Destiny State #16 implementation** per S7-07 GDD — Array[EchoMark] + flags_to_set lifecycle owner + 3 GameBus subs (destiny_branch_chosen + scenario_complete + chapter_started) + 2 GameBus emits (echo_mark_committed + flag_set_committed) per CR-DS-2/3 (signals already declared in game_bus.gd lines 54-55 from sprint-6 forward-decl) + autoload registration (boot pos 7 — 8th invocation of autoload Node pattern) + Pillar 2 architectural lock 5th invocation candidate flips to shipped (`destiny_state_reads_scenario_runner_state` forbidden_pattern). | claude | 0.5 | S7-07 GDD Designed (✅) | DestinyState autoload registered; subscriptions wire correctly; emit-pair fires per protocol; Pillar 2 lock 5th invocation lint PASS; ~10-12 tests. |
| S8-11 | **Chapter-1 (장판파) end-to-end integration vertical-slice run** — full 9-beat ScenarioRunner playthrough hitting Beat 7 judgment + Beat 8 reveal + Beat 9 outro; AISystem 4 archetypes apply pressure; DestinyBranchJudge fires; Story Event #10 dispatches branch-aware text; Destiny State #16 archives echo_marks. Validates the sprint-7 architecture chain end-to-end. | claude | 0.4 | S8-09 + S8-10 | Chapter-1 plays end-to-end via integration test; all 9 beats fire; branch_table resolves; ~6-8 integration tests + smoke check evidence at production/qa/evidence/chapter_1_integration_run.md. |

**Should-have subtotal: ~1.8 working days nominal** (~14h).

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S8-12 | First 2-3 character visual profile stubs — `design/art/characters/yu-bei.md` + `zhang-fei.md` + `liu-bei.md` (chapter-1 player roster); closes AD-C5 ADVISORY from gate-check 2026-05-04. | claude (or art-director) | 0.3 | — | 3 profile stubs created with Section 1-3 minimum (silhouette + costume + role-anchor); systems-index reference if applicable. |
| S8-13 | AD-C3 font glyph check (緣 bond glyph rendering verification across chapter-1 text); closes AD-C3 OPEN from gate-check 2026-05-04. Gates story-event text rendering tasks. | claude | 0.2 | S8-09 (Story Event impl exists for text-pipeline test) | Test renders 緣 + verifies glyph fidelity in default font set; result documented at production/qa/evidence/font_glyph_check_緣.md. |
| S8-14 | Main menu UX spec stub at `design/ux/main-menu.md` — minimal section structure (information architecture + key states + accessibility tier compliance); closes AD-C6 ADVISORY. | claude (or ux-designer) | 0.2 | — | UX spec created with 8-section template; references accessibility-requirements.md Intermediate tier. |
| S8-15 | **S7-11 user attestation** on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` — append `## Playtest Notes` section after 3-5 chapter-prototype runs. **USER-OWNED** carryover from sprint-7. | user | n/a | — | 3-5 captured run notes appended; triggers /gate-check pre-production re-run with PASS upgrade path. |
| S8-16 | Pillar 4 chapter-2 scoping + chapter-1-callback ACs (CD recommendation from gate-check 2026-05-05) — defines mechanical-narrative ripple-validation criteria for chapter-2; produces chapter-2 enemy roster + branch_table outline draft. | claude | 0.3 | S8-11 (chapter-1 e2e validates ScenarioRunner chain works) | chapter-2 outline draft at design/scenarios/chapter-2-outline.md (PROVISIONAL); chapter-1-callback ACs codify how ripple-narrative is validated; Pillar 4 demonstration gate criteria for sprint-9+ playtest. |

**Nice-to-have subtotal: ~1.0 working day nominal claude-owned** (~8h) + user-owned attestation (S8-15).

**Sprint-8 total nominal**: ~5.5 working days claude-owned (Must + Should + Nice; OVER 4.25 capacity by 1.25d). **Most likely cut point under pressure** (per Producer recommendation): defer S8-09 OR S8-10 to sprint-9 (Story Event #10 OR Destiny State #16 implementation, NOT both same-sprint as input-handling 1-5 + chapter-1 e2e). Sprint-7 retro pattern: Should-Have absorbs slack at 5× velocity; if multiplier holds, all Must+Should land within ~1.5 calendar days actual.

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| Battle-hud story-005 (UI-GB-02/05/10 + two-tap timer) | sprint-7 S7-10 BLOCKED on input-handling InputRouter PLACEHOLDER discovery; unblocks once S8-02..06 land | 0.5d (S8-07) |
| Save/Load #17 GDD authoring | sprint-7 Producer pressure-cut; design-only filler | 0.4d (S8-08) |
| Chapter-prototype playtest notes (4 VS Validation items) | sprint-7 S7-11 user-attestation gate; sole gate-check upgrade blocker | n/a (S8-15 — user) |
| Hero portraits (8) — user-owner | Sprint-4 S4-05 carryover (3rd carryover); chapter-1 still uses ColorRect placeholders | n/a (user) |
| BGM candidates (2-3) — user-owner | Sprint-4 S4-06 carryover (3rd carryover); not blocking critical path | n/a (user) |

## Cut from Sprint-8 (Producer pressure-cut candidates)

| Task | Reason for cut | Deferred to |
|------|---------------|-------------|
| Input-handling stories 6-10 (per-unit undo + input_blocked + touch protocol TPP magnifier + pan/tap gestures + epic-terminal perf+lints+evidence) | Producer split-input-handling-epic recommendation: don't absorb full 10-story epic; ship 1-5 in sprint-8, 6-10 in sprint-9 | sprint-9 |
| AD-C2 청록 #3A7D6E contrast resolution | Deferrable to formation-bonus implementation story per gate-check 2026-05-04 (deferred 2 sprints) | sprint-9+ formation-bonus implementation |
| Audio Director collaboration on `reserved_color_treatment` sound-companion sync | Flagged non-BLOCKING in art-bible §4.7 addendum (deferred 2 sprints) | sprint-9+ destiny-branch impl polish OR cinematic-system GDD |
| Beat 8 reveal cinematic-layer camera/composition/typography spec | Flagged non-BLOCKING in art-bible §4.7 addendum (deferred 2 sprints) | sprint-9+ |
| Pause menu UX spec | Deferrable to menu implementation sprint per gate-check 2026-05-04 §AD-C6 | sprint-9+ menu sprint |
| Character profile stubs 4-7 (remaining Wei generals 장요/우금/허저 + Riding-Cloud Captain) | First 2-3 stubs are sprint-8 nice-to-have; remaining defer | sprint-9+ |
| ADR Engine Compatibility / Depends-on / Depended-by header backfill across 19 ADRs (TD ADVISORY) | Hardening pass; not gating Production work | sprint-9+ hardening sprint |

## Risks

- **R1 — InputRouter ADR-0020 same-session ban hits 5th time** (S8-01 escalates ADR-0020 — same-session-ban means /architecture-review CANNOT run in same session as /architecture-decision). **Mitigation**: 4-precedent same-day-fresh-session escalation pattern is stable + well-rehearsed (deltas #11/#12/#13/#14). S8-01 budgeted at 0.4d expecting standard combined-session pattern. If S8-01 escalates to delta #15 in fresh session, sprint-8 plan still on track.
- **R2 — Input-handling stories 1-5 single coordinated patch is large** (5 stories × 0.3-0.5d nominal = 5 stories of dependent FSM scaffolding). Risk of partial completion + lint-flip half-applied + InputRouter `_handle_event` shipping without all dispatch surfaces covered. **Mitigation**: S8-02..06 sequenced per dependency chain (story-001 skeleton → story-002 vocabulary → story-003 FSM core → story-004 FSM attack → story-005 mode determination). Partial completion via sub-stories OK if input-handling 5-story scope blows past 3.0d actual.
- **R3 — S7-10 unblock at S8-07 depends on S8-06 mode_determination_CR-2 (which fires `input_mode_changed`)**. If S8-06 lands but BattleHUD subscribes don't fire correctly, S8-07 two-tap timer can't validate AC-UX-HUD-08/09. **Mitigation**: ADR-0015 line 235-236 Tap Preview Protocol is unambiguous; integration test in S8-06 verifies BattleHUD subscription works before S8-07 picks up.
- **R4 — Story Event #10 + Destiny State #16 implementations (S8-09 + S8-10) both require ADR-0001 minor amendments** (Evolution Rule #4 — 3 new GameBus signals from Story Event + 2 new from Destiny State). Risk of ADR-0001 amendment churn / drift. **Mitigation**: bundle both amendments in single /architecture-review delta if budget permits, or single ADR-0001 amendment pass post-S8-09 + S8-10. Per sprint-7 R6 retro: 0 user-adjudication points expected (over-budgeted in sprint-7 by 4×).
- **R5 — Chapter-1 e2e integration test (S8-11) may surface ScenarioRunner / DestinyBranchJudge / AISystem / Story Event coordination drift** that wasn't caught at sprint-7's individual-system tests. **Mitigation**: chapter-1 IS the integration test target (S7-05 design intent); issues surface here are by design. Budget S8-11 generously at 0.4d (already includes integration discovery time per sprint-7 R5 mitigation pattern).
- **R6 — 5× velocity multiplier may fragment with broader-impl scope** (5 input-handling stories + 2 GDD impls + chapter-1 e2e + 4 nice-to-haves = 11 claude-owned stories; sprint-7 was 9 claude-owned). Implementation has more cross-system + cross-file variance than ADR/architecture work. **Mitigation**: per-story commit cadence + immediate sprint-status.yaml row close per sprint-7 retro AI #1 (now at 4-story streak; sprint-8 enforcement targets 6+ for stability declaration). If velocity slows to 2-3×, S8-09 OR S8-10 slips cleanly to sprint-9 per Producer cut-point identification.
- **R7 — Pre-flight check policy enforcement (sprint-7 retro improvement #1)** must apply to every sprint-8 carryover story (S8-07 S7-10 unblock + S8-15 S7-11 attestation + carryover hero portraits + BGM). **Mitigation**: at sprint-plan time, every carryover story must verify underlying infra has all referenced APIs (e.g., S8-07 verifies S8-06 InputRouter `input_mode_changed` exists + BattleHUD subscribes). 5-min grep before story claim.
- **R8 — Sprint-status hygiene close-in-same-patch enforcement still at 4-story streak** (sprint-7 retro AI #1 PARTIAL status). **Mitigation**: every sprint-8 story commit MUST close its sprint-status row in same patch — no manual reconcile cleanup at sprint-9 kickoff. Pattern stability declaration target: 6+ consecutive in-patch closes (currently 4 from sprint-7's S7-05..S7-09).
- **R9 — User attestation S8-15 (S7-11 carryover) requires user time** (~30-60 min for 3-5 chapter-prototype runs). If user is unavailable during sprint-8 window, /gate-check upgrade CONCERNS → PASS slips beyond sprint-8 close. **Mitigation**: S8-15 is user-owned with no claude prerequisite (chapter-prototype runnable since 2026-05-02); attestation can happen any time before next gate-check invocation. Not a sprint-8 blocker.
- **R10 — G-7 silent-skip detection codification candidate** (sprint-7 retro improvement #2). New tooling-gotcha pattern from S7-05→S7-07 surface-and-fix lesson. **Mitigation**: at sprint-8 kickoff + after each Should/Nice ship, run G-7 detection grep on test files: `grep -rn '\.contains(\[' tests/` + `grep -rn 'assert_str.*\.contains' tests/`. If silent-skip surfaced, fix in same patch (not deferred follow-up).

## Dependencies on External Factors

- None at the system level. All 19 ADRs Accepted; ADR-0020 NEW Proposed → Accepted target via S8-01 + same-day delta #15 escalation (combined-session pattern stable at 4 invocations). Engine pinned at Godot 4.6 (3+ months stable runway). GdUnit4 v6.1.2 pinned per `tests/README.md`.
- **User-owner deferred items** (hero portraits + BGM + chapter-prototype attestation S8-15) remain optional for sprint-8 critical path. Critical path uses ColorRect placeholders + text-based scenes per chapter-prototype precedent.
- **CI infrastructure**: Linux Editor + Windows D3D12 lanes active. macOS / iOS / Android lanes manual-fallback per ADR-0018 OQ-DB-6 partial closure. Sprint-9 evaluation per sprint-7 retro AI #5 carryover.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S8-01..S8-07 = 7 stories)
- [ ] All tasks pass acceptance criteria
- [ ] **ADR-0020 InputRouter** authored Proposed → Accepted via combined-session escalation pattern 5th invocation (S8-01)
- [ ] **InputRouter graduated from PLACEHOLDER to functional FSM** — 5 input-handling stories (1-5) shipped via S8-02..06
- [ ] **S7-10 battle-hud story-005 ships** — UI-GB-02/05/10 + two-tap timer (S8-07)
- [ ] Save/Load #17 GDD PROVISIONAL → Designed (S8-08)
- [ ] **Story Event #10 implementation shipped** — autoload registered + Pillar 2 lock 6th invocation (S8-09)
- [ ] **Destiny State #16 implementation shipped** — autoload registered + Pillar 2 lock 5th invocation (S8-10)
- [ ] **Chapter-1 (장판파) end-to-end integration test PASS** — full 9-beat run validates ScenarioRunner + DestinyBranchJudge + AISystem + Story Event coordination (S8-11)
- [ ] Full GdUnit4 regression: ≥1010 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (target 1010-1050 depending on Should + Nice ship; up from sprint-7's 978)
- [ ] `production/epics/index.md` updated: input-handling stories 1-5 Complete + scenario-progression epic Complete (terminal close after chapter-1 e2e) + destiny-branch epic Complete + ai-system epic Complete + story-event NEW Ready + destiny-state NEW Ready + save-manager NEW (Save/Load #17 GDD authored)
- [ ] `production/sprint-status.yaml` updated **per-story-row at completion** (sprint-7 retro AI #1 enforcement target: 6+ consecutive in-patch closes for stability declaration)
- [ ] `tests/regression-suite.md` updated with chapter-1 e2e critical path coverage
- [ ] Sprint-8 retrospective written before sprint-9 kickoff
- [ ] **Re-run `/gate-check pre-production`** if S8-15 user attestation captured during sprint-8 → expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production"
- [ ] **+1 playable-surface delta achieved** (sprint-8 promotes chapter-1 from "data authored + integration target" to "plays full 9-beat narrative arc with input + branch judgment + dialogue")
- [ ] **Pillar 2 architectural lock pattern stabilized at 6 invocations** (Story Event #10 + Destiny State #16 candidates flip to shipped)
- [ ] **Autoload Node pattern stabilized at 10 invocations** (Story Event + Destiny State + InputRouter join lineage; lineage was 8 shipped + 2 candidates pre-sprint-8)

## Sprint-8 Retro AI seed (carried from sprint-7 retrospective)

These will be evaluated at sprint-8 close + carried to sprint-9 plan:

1. **Sprint-status hygiene "close in same patch"** (sprint-7 retro AI #1 PARTIAL). Sprint-8 enforces 6+ consecutive in-patch closes for pattern-stability declaration. Validate at sprint-8 retro: did any rows close late?
2. **Pre-flight check discipline (NEW from sprint-7 retro improvement #1)**. Every carryover story must verify underlying infra has all referenced APIs at sprint-plan time, not story-attempt time. Validate at sprint-8 retro: did any sprint-8 stories surface S7-10-style PLACEHOLDER discoveries?
3. **G-7 silent-skip detection at every test baseline run (NEW from sprint-7 retro improvement #2)**. Run grep at sprint-8 kickoff + post-each-Should/Nice. Validate at sprint-8 retro: was silent-skip caught + fixed in same-session, or did any deferred follow-ups recur?
4. **5× velocity multiplier durability under broader impl scope** (sprint-7 retro AI #2 HELD). Sprint-8 has 11 claude-owned stories vs sprint-7's 9. If multiplier drops to 2-3×, sprint-9 nominal estimates re-baseline.
5. **Pillar 2 lock pattern 6th invocation**. S8-09 + S8-10 flip Story Event + Destiny State candidates to shipped; pattern moves from "4 shipped + 2 candidates" to "6 shipped". Verify enforcement triad (source-grep lint + ADR-annotation + integration test) holds for both flips.
6. **Combined-session escalation pattern 5th invocation** (S8-01 ADR-0020 → fresh-session delta #15). Pattern stable at 4 invocations entering sprint-8; sprint-8 invocation locks at 5.
7. **Autoload Node pattern stabilized at 10 invocations** post-S8-09 + S8-10 + S8-02 (Story Event + Destiny State + InputRouter join lineage). Validate boot order at S8-02 + S8-09 + S8-10: InputRouter at boot pos 4 (per ADR-0005); Destiny State at boot pos 7; Story Event at boot pos 8.
8. **CI lane gap for macOS / iOS / Android** (sprint-7 retro AI #5 DEFERRED). Sprint-8 evaluates whether sprint-9 hardening pass is worth investment vs continued manual-test fallback.

## Cross-References

- **Sprint-7 retrospective**: `production/retrospectives/retro-sprint-7-2026-05-05.md`
- **Gate-check that informed this sprint plan**: `production/gate-checks/pre-prod-to-prod-2026-05-05.md` (CONCERNS verdict; sole remaining blocker S7-11 user attestation USER-OWNED)
- **Architecture-review delta #14 report** (most recent): `docs/architecture/architecture-review-2026-05-05.md`
- **Governing ADRs (Accepted)**: ADR-0001..0019 (19 ADRs); ADR-0019 (AI System) Accepted 2026-05-05 most recent
- **Governing ADRs (Proposed; S8-01 escalates)**: ADR-0020 InputRouter NEW
- **Governing GDDs**: `design/gdd/input-handling.md` rev 1.0 + `design/gdd/story-event.md` rev 1.0 + `design/gdd/destiny-state.md` rev 1.0 + `design/gdd/scenario-progression.md` rev 2.2 + `design/gdd/destiny-branch.md` rev 1.3.2 + `design/gdd/ai-system.md` rev 1.0 + `design/gdd/grid-battle.md` v5.0 + `design/gdd/game-concept.md` (Pillars 1-4 + MVP Core Hypothesis)
- **Governing art-bible sections**: `design/art/art-bible.md` §4.7 reserved_color_treatment + (S8-12 first character profile stubs target §5 Character Design Direction)
- **Control manifest**: `docs/architecture/control-manifest.md` v2026-05-05 + Pillar 2 Architectural Locks section (codifies 4 shipped + 2 candidates; S8-09 + S8-10 flip 5+6 to shipped)
- **Prior sprints**: `production/sprints/sprint-{1,2,3,4,5,6,7}.md`
- **Chapter-prototype**: `prototypes/chapter-prototype/` (chapter.gd + battle_v2.gd + REPORT.md PROVISIONAL PROCEED — S8-15 user-attestation gate target)
- **Input-handling epic**: `production/epics/input-handling/EPIC.md` + 10 stories already authored (story-001..story-010); S8-02..06 ship stories 1-5

> **Scope check**: Sprint-8 stories all derive from sprint-7 retrospective action items + gate-check 2026-05-05 director recommendations + sprint-7 carryover (S7-10 + S7-11 + Save/Load #17 cut). Run `/scope-check sprint-8` after S8-06 if S8-01..S8-06 cumulative scope diverges from Producer "1.5× sprint-7 nominal" budget.

> ⚠️ **No Sprint-Level QA Plan Yet** — see Phase 5 follow-up. Per project pattern (locked sprint-2 Phase 5), QA discipline is per-epic. Sprint-8 implementation stories require:
> - **input-handling epic**: `/qa-plan input-handling` should be authored Should-Have AFTER S8-06 lands (5-story scope with FSM coverage); promote to Must-Have if integration test count target >25 cases lands.
> - **story-event epic**: `/qa-plan story-event` should be authored Should-Have AFTER S8-09 lands.
> - **destiny-state epic**: `/qa-plan destiny-state` should be authored Should-Have AFTER S8-10 lands.
> - **chapter-1 integration**: chapter-1 IS the integration test target — covered by S8-11 acceptance criteria.

> **Reminder**: re-run `/gate-check pre-production` AFTER S8-15 user attestation captured (any time during sprint-8). Expected verdict upgrade: CONCERNS → PASS + `production/stage.txt` written = "Production". This sprint's secondary success criterion IS the gate-check upgrade (primary success criterion is the input-handling unblock + chapter-1 e2e integration ship).

> **Pre-flight check applied (sprint-7 retro improvement #1)**: S8-07 S7-10 unblock verified — InputRouter `_handle_event` will exist post-S8-04 (input-handling story-003 FSM core); BattleHUD `input_mode_changed` subscription verified at design/ux/battle-hud.md §3 + ADR-0015 line 235-236. S8-09 Story Event impl verified — GameBus signals already forward-declared in game_bus.gd (sprint-6 forward-decl precedent). S8-10 Destiny State impl verified — GameBus signals already forward-declared in game_bus.gd lines 54-55 (per sprint-7 S7-07 commit ba8da69 GDD reference).
