# Sprint 7 — 2026-05-31 to 2026-06-06

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md` — refreshed via gate-check item #3)
> **Generated**: 2026-05-04
> **Carries**: sprint-6 implicit retro AI (closed: 4-archetype AI System scope; reserved_color_treatment art-bible §4.7 visual contract; tighter ratchet AI #1 from 4.4d → ~2d nominal Must — sprint-6 absorbed 5× faster than planned at ~1d actual) + sprint-7 retro AI proposed by gate-check 2026-05-04 PR ("all shipped work must close its sprint-status row in the same patch" — the manual reconcile of S6-02/03/04/11 was a one-shot cleanup, not the new normal)
> **Generated to close**: `/gate-check pre-production` 2026-05-04 path-to-PASS item #6 — final blocker before re-running gate-check for upgrade CONCERNS → PASS

## Sprint Goal

**Ship chapter-1 (장판파) end-to-end as the first user-experienceable narrative arc.** ScenarioRunner autoload comes alive (Beat 1 entry → Beat 7 judgment → Beat 8 reveal → Beat 9 outro). DestinyBranchJudge is callable; Beat 7 reserved-color visual reveal fires per art-bible §4.7. AISystem responds to GridBattleController per CR-3 protocol; chapter-1 enemy roster (하후돈/장요/우금/허저) gets archetype assignments via ChapterDefinition data. Story Event #10 + Destiny State #16 GDDs promote PROVISIONAL → Designed (load-bearing for chapter-1 narrative beats per Producer cut-point logic). Save/Load #17 GDD **CUT** per PR pressure-cut decision (Producer flagged at gate-check 2026-05-04). Closes the 3 Pillar 2 architectural locks' implementation surfaces: HUD doesn't subscribe + ScenarioRunner seal is synchronous + Judge takes pure-data parameters.

## Pivot context (carried from sprint-6 + gate-check 2026-05-04)

Sprint-6 was the **integration-and-mount sprint**: 5 battle-scoped Nodes + ADR-0015 BattleHUD wired into the first runnable BattleScene. Sprint-7 is the **chapter-arc sprint**: take the runnable BattleScene + put it inside a 9-beat scenario + wire AI to actually press the player + add the destiny-branch judgment that gives the chapter its narrative shape. This is the first sprint where a player can play a complete narrative arc, not just a mounted battle.

Gate-check 2026-05-04 returned **CONCERNS** on the Pre-Production → Production phase gate. 5 of 6 path-to-PASS items closed via gate-check session work (sprint-status reconcile + chapter-prototype REPORT.md + control-manifest refresh + reserved_color_treatment art-bible §4.7 + AI System GDD/ADR-0019 Proposed). This sprint plan IS path-to-PASS item #6. Re-run `/gate-check pre-production` after sprint-7 kickoff is documented + items 1-6 all land + user attestation captured on the 4 VS Validation items in chapter-prototype REPORT.md → expect upgrade CONCERNS → PASS.

## Capacity (per sprint-6 implicit retro — 4th consecutive ratchet)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work
- Available: **4.25 working days**

> **AI #1 ratchet (4th consecutive)**: sprint-6 was 4.4d nominal / ~1d actual = ~5× off. Sprint-7 plan targets **~2.0d Must-Have nominal** (down from sprint-6's 2.4d). Should-Have absorbs slack if Must lands fast (sprint-6 pattern); Nice-to-Have buffers further. Velocity-multiplier baseline now stable at ~5× nominal across sprint-5/6 — projection for sprint-7 actual: ~0.4-0.5d. If Must+Should ship in <1 calendar day per sprint-6 pattern, sprint-8 plan tightens to 1.5d nominal.

## Context

Project state as of 2026-05-04 (post-gate-check pre-prod-to-prod):

- **18 ADRs Accepted** + **ADR-0019 Proposed** (AI System; awaits S7-01 fresh-session escalation).
- **Core layer 5/5 Complete** per `architecture-traceability.md` v0.13 (Foundation + GameBus + SceneManager + Save/Load + Map/Grid + ScenarioRunner ADR + DestinyBranchJudge ADR).
- **17 epics** in `production/epics/` — Foundation 4/5 + Core 3/4 + Feature 3/13 + Presentation 1/6 + Integration 1/1 (battle-scene Complete 3/3).
- **18 GDDs Designed** (incl. AI System #8 newly Designed 2026-05-04). 3 PROVISIONAL: Story Event #10 + Destiny State #16 + Save/Load #17 — sprint-7 Should-Have promotes #10 + #16; #17 **CUT**.
- **Control manifest refreshed 2026-05-04** absorbing ADRs 0014..0018 + new Pillar 2 Architectural Locks section. ADRs 0005..0013 backfill remains as advisory note (sprint-7+ backfill candidate).
- **art-bible §4.7 reserved_color_treatment addendum landed 2026-05-04** — Beat 8 reveal visual contract bound to DestinyBranchChoice payload field; AD-C1 BLOCKING for destiny-branch impl is closed.
- **chapter-prototype/REPORT.md landed 2026-05-04** — provisional PROCEED verdict on MVP Core Hypothesis; 4 VS Validation items flagged for user attestation (sprint-7 user-owned task).
- **3 Pillar 2 architectural locks codified** (battle_hud_subscribes_to_hidden_fate_signal + scenario_runner_deferred_seal_in_beat_7_entry + destiny_branch_judge_reads_scenario_runner_state). ADR-0019 proposes 4th: ai_system_reads_destiny_branch_state.
- **907 PASS** at sprint-6 close (25th consecutive failure-free baseline per battle-scene EPIC closure). Target sprint-7 close: ~960 PASS (+50 net-new tests across 4 impl tracks).

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S7-01 | `/architecture-review` fresh session — escalate **ADR-0019 AI System** Proposed → Accepted (delta #14) + register ~12-15 net-new TR-ai-system-001..N entries + 1 state_ownership (`ai_system_runtime_state`) + 1 interface (`ai_action_signal_contract` — LOCAL signal pattern, NOT GameBus) + 1 api_decision (`ai_system_module_form` — battle-scoped Node 6th invocation, single-class match-dispatch, 2 typed Resources) + 4 forbidden_patterns (`ai_system_signal_emission_outside_action_ready` + `ai_system_static_var` + `ai_system_reads_destiny_branch_state` Pillar 2 lock 4th precedent + `ai_system_direct_battle_state_read`); same-patch ADR-0016 mount sequence renumber (6 steps → 7 steps with AISystem at step 5.5 OR full 1-7 renumber per /architecture-review delta decision per ADR-0019 Migration Plan §1). | claude | 0.4 | ADR-0019 Proposed (commit `6dfd962`) | ADR-0019 Status flip Proposed → Accepted; tr-registry.yaml v14 → v15; architecture.yaml v12 → v13; architecture-review-2026-05-XX.md report shipped; PASS verdict; 4-precedent same-day-fresh-session escalation pattern continued (after delta #11/#12/#13). |
| S7-02 | ScenarioRunner implementation per **ADR-0017 §Migration Plan §1..§11** single coordinated patch — autoload registration (`/root/ScenarioRunner` post-SaveManager load order) + 13-state machine `_state` enum + match dispatch + 9-beat per-chapter rhythm + ChapterDefinition typed Resource loader + 7-signal contract emission (chapter_started + scenario_complete + scenario_beat_retried + save_checkpoint_requested + destiny_branch_chosen + 2 confirmed) + retry-loop guard + 3-CP save integration + DestinyBranchJudge delegation (F-SP-1/F-SP-2 4-arg call site) + sprint-6 inline mock encoder DELETION per ADR-0016 Migration Plan §1 + lint flip from `battle_scene_sprint6_mock_marker_must_exist` "marker MUST exist" → "marker MUST NOT exist" (phase-flipping lint 1st-precedent semantic switch). | claude | 0.6 | S7-01 (for ADR-0019 lockstep — wait, this is independent; ADR-0017 already Accepted) | ScenarioRunner autoload exists + 13-state machine functional + chapter-1 .tres loads + 7 signals fire per protocol; sprint-6 mock encoder removed + phase-flipping lint passes new semantic; ~25-30 new unit tests; ~935 PASS target (+~28). |
| S7-03 | DestinyBranchJudge implementation per **ADR-0018 §Migration Plan §5** — 3 source files (`src/core/payloads/destiny_branch_choice.gd` 30 LoC + `src/feature/destiny_branch/destiny_branch_judge.gd` 120 LoC + `src/feature/destiny_branch/default_destiny_branch_judge.gd` 10 LoC) + 1 test helper (`tests/helpers/destiny_branch_judge_stub.gd` 30 LoC) + 2 unit test files (200-300 LoC GdUnit4 covering F-DB-1 worked examples E1-E6 + 12 invalid_reason vocabulary + EC-DB-17 thread-safety + AC-DB-24 ResourceSaver/ResourceLoader 5-platform round-trip) + 3 CI lint scripts (`lint_destiny_branch_judge_no_static_var.sh` + `lint_destiny_branch_judge_no_gamebus_emit.sh` + `lint_destiny_branch_judge_no_scenario_runner_read.sh` Pillar 2 lock #3) + 1 integration test (thread-safety on WorkerThreadPool). | claude | 0.5 | S7-02 (DestinyBranchJudge is called BY ScenarioRunner at BEAT_7_JUDGMENT entry per ADR-0017 line 209) | DestinyBranchJudge.resolve(...) callable + DefaultDestinyBranchJudge subclass tested + DestinyBranchChoice 9-field round-trip on 5 platforms (closes OQ-DB-6 BLOCKING-for-VS gate) + @abstract test seam parse-fail verified + 3 lint scripts green; ~12-15 net-new tests; ~950 PASS target. |
| S7-04 | AISystem implementation per **ADR-0019 §Migration Plan §2..§5** — 3 source files (`src/feature/ai/ai_system.gd` ~300 LoC + `src/core/payloads/battle_state_snapshot.gd` ~30 LoC + `src/core/payloads/ai_action_command.gd` ~50 LoC) + 2 test helpers + 5 unit/integration test files (AC-AI-1..14 except AC-AI-12 distribution + AC-AI-14 save-load deferred until ScenarioRunner + Save/Load ship) + 4 CI lint scripts (`ai_system_no_gamebus_emit` + `ai_system_no_static_var` + `ai_system_no_destiny_branch_reference` Pillar 2 lock 4th precedent + `ai_system_no_direct_state_read` CR-AI-6) + GridBattleController extension `_make_battle_state_snapshot()` private method + BattleScene mount sequence step 5.5 insertion + chapter-1 ChapterDefinition.enemy_roster archetype assignments (하후돈=`&"aggressor"` + 장요=`&"skirmisher"` + 우금=`&"holder"` + 허저=`&"coordinator"` boss). | claude | 0.5 | S7-01 + S7-02 (AISystem instantiates after GridBattleController per ADR-0019 step 5.5 — works against shipped GridBattleController; depends on ChapterDefinition archetype field which is added by S7-02 ChapterDefinition work) | AISystem battle-scoped Node 6th invocation mounted + 4 archetypes scoring functions + signal protocol AC-AI-1 + determinism AC-AI-2 + archetype differentiation AC-AI-3 + per-archetype behavior AC-AI-4..8 + 4 lint scripts green + Pillar 2 lock 4th precedent enforced; ~10-12 net-new tests; ~960 PASS target. |

**Must-have subtotal: ~2.0 working days nominal** (~16h). Per 4th-ratchet AI #1, projected actual: ~0.4-0.5 calendar day at sprint-6 5× velocity multiplier.

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S7-05 | Chapter-1 (장판파) ChapterDefinition `.tres` data authoring + 9-beat content + branch_table + canonical_branch_key + chokepoints + enemy roster archetype assignments + invalid_reason vocabulary mapping + Beat 8 reveal text (per art-bible §4.7 reserved_color_treatment trigger) + integration with sprint-6 inline mock unit data (now removed per S7-02) — chapter-1 IS the integration test target for ScenarioRunner + DestinyBranchJudge + AISystem coordination. | claude | 0.3 | S7-02 + S7-03 + S7-04 | `data/chapters/chapter_01_changban_bridge.tres` exists + loads via ChapterDefinition.load() + 9-beat structure validates + 4 archetype assignments correct + chokepoints (3,3)/(3,2)/(3,4) tagged + Beat 8 reveal text per art-bible §1.지지 원칙 2 + reserved_color_treatment trigger validates per art-bible §4.7 truth table; ~5 integration tests; ~965 PASS. |
| S7-06 | `/design-system story-event` — Story Event #10 GDD authoring (PROVISIONAL → Designed) — chapter-1 dialogue + Beat-1/2/8/9 narrative beat content + branch-aware text variants (canonical-WIN / REWRITTEN / PARTIAL / HISTORICAL / DEFEAT) + invalid-path UI carve-out for is_invalid==true paths + integration with art-bible §1.지지 원칙 2 visual narrative + Pillar 4 mechanical-expression spec. | claude | 0.4 | S7-03 (DestinyBranchChoice 9-field shape locked at acceptance) | story-event GDD has all 8 required sections (Overview / Player Fantasy / Detailed Rules / Formulas / Edge Cases / Dependencies / Tuning Knobs / Acceptance Criteria); destiny-branch.md §Bidirectional rev 1.2 D1 invalid-path UI gate satisfied; systems-index.md row 10 PROVISIONAL → Designed; cross-refs to ADR-0017/0018 + game-concept Pillar 4. |
| S7-07 | `/design-system destiny-state` — Destiny State #16 GDD authoring (PROVISIONAL → Designed) — echo-archive maintenance + cross-chapter destiny-state propagation + persistence schema (echo_marks_archive / flags_to_set per ADR-0003 SaveContext) + Beat 8 canonical-history enforcement keys on `is_canonical_history` + `echo_count` + `is_draw_fallback` payload fields per ADR-0018 §F-DB-4 + Pillar 2 mechanical-expression spec. | claude | 0.4 | S7-03 | destiny-state GDD has 8 required sections; destiny-branch.md §Bidirectional rev 1.2 D1 echo-archive gate satisfied; systems-index.md row 16 PROVISIONAL → Designed; cross-refs to ADR-0018 + ADR-0003 SaveContext + game-concept Pillar 2. |

**Should-have subtotal: ~1.1 working days nominal** (~9h).

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S7-08 | control-manifest.md ADRs 0005..0013 backfill — dedicated subsections for Input (ADR-0005) + Balance/Data (ADR-0006) + Hero DB (ADR-0007) + Terrain Effect (ADR-0008) + Unit Role (ADR-0009) + HP-Status (ADR-0010) + Turn Order (ADR-0011) + Damage Calc (ADR-0012) + Camera (ADR-0013); closes the advisory note from gate-check 2026-05-04 path-to-PASS item #3 partial-coverage. | claude | 0.5 | — | manifest 513 → ~700 lines; 9 new subsections; coverage advisory note removed; Manifest Version bump 2026-05-04 → 2026-06-XX; sprint-7 retro AI from gate-check ("all shipped work closes its sprint-status row") satisfied via this row. |
| S7-09 | battle-hud story-004 (carried from sprint-6 nice-to-have S6-12) — UI-GB-01 Initiative Queue + UI-GB-07 Turn/Round Counter + UI-GB-08 Victory Condition Display per battle-hud.md §3. | claude | 0.4 | sprint-6 S6-09 Complete | story Complete; UI-GB-01/07/08 render per battle-hud.md §3; ~975 PASS. |
| S7-10 | battle-hud story-005 (carried from sprint-6 should-have S6-12-adjacent) — UI-GB-02/05/10 + Two-tap ATTACK/DEFEND HUD-owns-timer (TR-005/017); AC-UX-HUD-08/09 contract verification. | claude | 0.5 | S7-09 | story Complete; UI-GB-02/05/10 + two-tap timer per battle-hud.md §AC-UX-HUD-08/09; ~985 PASS. |
| S7-11 | User attestation pass on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` — append `## Playtest Notes` section after 3-5 chapter-prototype runs; converts gate-check unverified items to PASS contributions. **User-owned task**, NOT claude. | user | n/a | chapter-prototype runnable | 3-5 captured run notes appended to REPORT.md with concrete observations on (a) core loop without dev guidance, (b) communicates within 2 min, (c) no fun-blocker bugs, (d) core mechanic feels good; this triggers gate-check re-run with PASS upgrade path. |

**Nice-to-have subtotal: ~1.4 working days nominal claude-owned** (~11h) + user-owned attestation (S7-11).

**Sprint-7 total nominal**: ~4.5 working days claude-owned (Must + Should + Nice; within 4.25 capacity if Should slips OR Nice slips). **Cut decision (Producer pressure-cut from gate-check 2026-05-04)**: Save/Load #17 GDD authoring — DEFERRED to sprint-8 or later. Save/Load is Vertical-Slice tier per systems-index, not load-bearing for chapter-1 narrative beats.

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| Battle-hud story-004 (UI-GB-01 + UI-GB-07 + UI-GB-08) | sprint-6 nice-to-have S6-12 not shipped (sprint-6 absorbed must + should + nice for ADR-0017/0018 architecture instead of HUD impl) | 0.4d (S7-09) |
| Battle-hud story-005 (UI-GB-02/05/10 + two-tap timer) | sprint-6 nice-to-have-adjacent; carried for HUD impl track continuity | 0.5d (S7-10) |
| Hero portraits (8) — user-owner | Sprint-4 S4-05 carryover; chapter-1 still uses ColorRect placeholders | n/a (user) |
| BGM candidates (2-3) — user-owner | Sprint-4 S4-06 carryover; not blocking sprint-7 critical path | n/a (user) |
| Chapter-prototype playtest notes (4 VS Validation items) | gate-check 2026-05-04 user attestation gate; converts CONCERNS → PASS upgrade path | n/a (user — S7-11) |

## Cut from Sprint-7 (Producer pressure-cut)

| Task | Reason for cut | Deferred to |
|------|---------------|-------------|
| Save/Load #17 GDD authoring | PR's likely cut point per gate-check 2026-05-04 §Producer §Most likely cut point under pressure. Save/Load is Vertical-Slice tier per systems-index #17, not load-bearing for chapter-1 narrative beats (Beat 7 judgment + Beat 8 reveal can ship without persistent saves; in-memory CP-1/2/3 satisfies sprint-7 demo). | sprint-8 (or later) |
| Audio Director collaboration on `reserved_color_treatment` sound-companion sync | Flagged non-BLOCKING in art-bible §4.7 addendum; not gate-check path-to-PASS scope | sprint-8 or destiny-branch impl story polish |
| Beat 8 reveal cinematic-layer camera/composition/typography spec | Flagged non-BLOCKING in art-bible §4.7 addendum; deferred to destiny-branch impl story OR future cinematic-system GDD | sprint-8+ |
| Character visual profiles (`design/art/characters/`) | gate-check 2026-05-04 §AD-C5 deferrable to early Production (not pillar-blocking) | sprint-8+ |
| Main menu / Pause menu UX specs | gate-check 2026-05-04 §AD-C6 deferrable | sprint-8+ |
| 청록 #3A7D6E contrast resolution | gate-check 2026-05-04 §AD-C2 deferrable to formation-bonus implementation story | sprint-8+ |
| 緣 bond glyph font-set check | gate-check 2026-05-04 §AD-C3 deferrable to formation-bonus implementation story | sprint-8+ |

## Risks

- **R1 — `/architecture-review` same-session ban hits 4th time** (S7-01 ADR-0019 escalation requires fresh session — same constraint as sprint-6 S6-02 + S6-10 + S6-11). **Mitigation**: 4th-precedent same-day-fresh-session escalation pattern is now stable + well-rehearsed (delta #11/#12/#13 all combined-session). S7-01 budgeted at 0.4d expecting standard combined-session pattern.
- **R2 — ScenarioRunner Migration Plan §1..§11 single coordinated patch is large** (~25-30 new tests + autoload registration + 13-state machine + 7-signal emission + sprint-6 mock encoder deletion). Risk of partial completion + lint-flip half-applied. **Mitigation**: ADR-0017 Migration Plan §1..§11 is sequenced; partial completion via sub-stories only if S7-02 estimate blows past 1.5d actual. The phase-flipping lint (`battle_scene_sprint6_mock_marker_must_exist`) MUST flip in same patch as the mock encoder deletion to avoid intermediate state where lint expects markers that no longer exist.
- **R3 — DestinyBranchJudge 5-platform ResourceSaver/Loader round-trip (S7-03 OQ-DB-6 closure) requires CI lanes for Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan + Linux Editor**. CI infrastructure not yet verified for all 5 lanes. **Mitigation**: Linux Editor + Windows D3D12 lanes are CI-active per existing GdUnit4 setup; macOS / iOS / Android lanes are manual-test fallback for sprint-7 (document as ADR-0018 OQ-DB-6 partial closure with CI lane gap noted). Full 5-platform CI deferred to release-prep sprint.
- **R4 — AISystem mounted at step 5.5 (or step 6 in renumbered scheme) breaks ADR-0016's `lint_battle_scene_pre_instanced_children.sh`** if implementation accidentally adds AISystem as pre-instanced .tscn child instead of code-instantiated. **Mitigation**: ADR-0019 §R-5 documents this; S7-04 acceptance criteria includes lint pass; code-driven mount per ADR-0016 R-2 setup-before-add_child mandate.
- **R5 — chapter-1 (장판파) ChapterDefinition .tres authoring may surface ScenarioRunner data-format issues** that weren't caught at ADR-0017 acceptance. **Mitigation**: S7-05 dependencies S7-02+03+04 all land first; chapter-1 IS the first integration test for ScenarioRunner — issues surface here are by design. Budget S7-05 generously at 0.3d (already includes integration discovery time).
- **R6 — Story Event #10 + Destiny State #16 GDD authoring (S7-06 + S7-07) may surface design questions requiring user adjudication** that block close-out. /design-system pattern across 17 prior GDDs has surfaced ~2-4 user adjudication points per GDD. **Mitigation**: AskUserQuestion at each adjudication; if more than 4 per GDD, defer that GDD to sprint-8. Story Event #10 has higher adjudication risk (narrative + branching content) than Destiny State #16 (mechanical archive maintenance) — schedule #16 first if budget tight.
- **R7 — User attestation gate (S7-11) requires 3-5 chapter-prototype runs** (~30-60 min user time). If user is unavailable during sprint-7 window, gate-check upgrade CONCERNS → PASS slips beyond sprint-7 close. **Mitigation**: S7-11 is user-owned with no claude prerequisite (chapter-prototype is already runnable since 2026-05-02); attestation can happen any time before next gate-check invocation. Not a sprint-7 blocker.
- **R8 — 5× velocity multiplier (sprint-5/6 baseline) may not continue** as scope shifts to broad implementation work (4 impl stories S7-02/03/04 spanning Core + Feature). Implementation has more cross-system + cross-file variance than ADR/architecture work. **Mitigation**: per-story commit cadence + immediate sprint-status.yaml row close per sprint-7 retro AI from gate-check; if velocity slows 2.5×, Should + Nice slip cleanly per AI #1 ratchet discipline.

## Dependencies on External Factors

- None at the system level. All 18 ADRs Accepted; ADR-0019 Proposed (S7-01 escalates). Engine pinned at Godot 4.6 (3+ months stable runway). GdUnit4 v6.1.2 pinned per `tests/README.md`.
- **User-owner deferred items** (hero portraits + BGM + chapter-prototype attestation) remain optional for sprint-7 critical path. Critical path uses ColorRect placeholders + text-based scenes per chapter-prototype precedent.
- **CI infrastructure**: Linux Editor + Windows D3D12 lanes active. macOS / iOS / Android lanes manual-fallback per R-3 mitigation.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S7-01..S7-04 = 4 stories)
- [ ] All tasks pass acceptance criteria
- [ ] **ADR-0019 AI System** escalated Proposed → Accepted via /architecture-review delta #14 (S7-01)
- [ ] **ScenarioRunner autoload functional** + 13-state machine + 7-signal contract (S7-02)
- [ ] **Sprint-6 inline mock encoder deleted** + phase-flipping lint flipped (S7-02 same-patch per ADR-0016 Migration Plan §1)
- [ ] **DestinyBranchJudge.resolve(...) callable** + DefaultDestinyBranchJudge subclass + DestinyBranchChoice 9-field round-trip on ≥2 platforms (S7-03; full 5-platform deferred per R-3)
- [ ] **AISystem battle-scoped Node 6th invocation mounted** + 4 archetypes + 4 lint scripts green + Pillar 2 lock 4th precedent enforced (S7-04)
- [ ] **Chapter-1 (장판파) ChapterDefinition .tres exists** + loads + 9-beat structure validates + 4 archetypes assigned (S7-05)
- [ ] Story Event #10 + Destiny State #16 GDDs PROVISIONAL → Designed (S7-06 + S7-07)
- [ ] Full GdUnit4 regression: ≥960 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (target 960-985 depending on Should + Nice ship)
- [ ] `production/epics/index.md` updated: AI System #8 epic created Ready + Story Event #10 epic Ready + Destiny State #16 epic Ready + Save/Load #17 deferred-to-sprint-8 row
- [ ] `production/sprint-status.yaml` updated **per-story-row at completion** (sprint-7 retro AI from gate-check 2026-05-04 — reverses sprint-6 manual-reconcile-debt pattern)
- [ ] `tests/regression-suite.md` updated with chapter-1 critical path coverage
- [ ] Sprint-7 retrospective written before sprint-8 kickoff
- [ ] **Re-run `/gate-check pre-production`** after S7-01..S7-07 close + S7-11 user attestation captured → expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production"
- [ ] **+1 playable-surface delta achieved** (sprint-7 promotes BattleScene from "mounts 5 systems without crash" to "plays full 9-beat chapter with AI + destiny-branch judgment")

## Sprint-7 Retro AI seed (carried from gate-check 2026-05-04)

These will be evaluated at sprint-7 close + carried to sprint-8 plan:

1. **Sprint-status hygiene** — proposed by Producer at gate-check: "all shipped work must close its sprint-status row in the same patch". S7-01..S7-10 each MUST close their sprint-status row in the implementing patch (no manual-reconcile cleanup at sprint-8 kickoff). Validate at sprint-7 retro: did any rows close late?
2. **5× velocity multiplier durability** — sprint-5/6 baseline; sprint-7 has broader implementation scope (4 impl stories vs sprint-6's 2 impl stories). If sprint-7 velocity drops to 2-3×, sprint-8 nominal estimates re-baseline.
3. **Pillar 2 lock pattern** — 4th invocation in S7-01 (`ai_system_reads_destiny_branch_state`). Pattern stable. Future Pillar-anchored locks should follow the same source-grep + ADR-annotation + integration-test triad documented in control-manifest.md §Pillar 2 Architectural Locks.
4. **Combined-session escalation pattern** — 4th invocation in S7-01 (delta #14 escalation + structural append in single fresh session). Pattern stable; should be the default for future /architecture-review deltas.
5. **CI lane gap for non-Linux/Windows** — flagged at S7-03 R-3; sprint-8 should evaluate whether macOS / iOS / Android CI lanes are worth investment vs continued manual-test fallback.

## Cross-References

- **Gate-check that requested this sprint plan**: `production/gate-checks/pre-prod-to-prod-2026-05-04.md` (path-to-PASS item #6)
- **Sprint-6 implicit retro**: tracked in `production/sprint-status.yaml` line 22-26 (manual-reconcile annotation)
- **Architecture-review delta #13 report** (most recent): `docs/architecture/architecture-review-2026-05-04b.md`
- **Governing ADRs (Accepted)**: ADR-0017 ScenarioRunner (delta #12) + ADR-0018 DestinyBranch (delta #13) + ADR-0001 GameBus (5-field PROVISIONAL → 9-field RATIFIED via delta #13)
- **Governing ADRs (Proposed; S7-01 escalates)**: ADR-0019 AI System (commit `6dfd962`)
- **Governing GDDs**: `design/gdd/scenario-progression.md` rev 2.2 + `design/gdd/destiny-branch.md` rev 1.3.1 + `design/gdd/ai-system.md` 1.0 + `design/gdd/grid-battle.md` v5.0 (CR-3/3a AI signal protocol) + `design/gdd/game-concept.md` (Pillars 1-4 + MVP Core Hypothesis line 296)
- **Governing art-bible sections**: `design/art/art-bible.md` §1.지지 원칙 2 (Destiny Bleeds Once) + §4.6 색채 상태 전환 + §4.7 reserved_color_treatment addendum (added 2026-05-04 path-to-PASS item #5)
- **Control manifest**: `docs/architecture/control-manifest.md` v2026-05-04 + Pillar 2 Architectural Locks section (codifies 3 locks; ADR-0019 §S7-01 adds 4th)
- **Prior sprints**: `production/sprints/sprint-{1,2,3,4,5,6}.md`
- **Chapter-prototype**: `prototypes/chapter-prototype/` (chapter.gd + battle_v2.gd + REPORT.md added 2026-05-04 path-to-PASS item #2)

> **Scope check**: Sprint-7 stories all derive from gate-check 2026-05-04 path-to-PASS item #6 + sprint-6 carryover + ADR-0017/0018/0019 Migration Plans. Run `/scope-check sprint-7` after S7-04 if S7-01..S7-04 cumulative scope diverges from gate-check budget (~4-6 hours nominal across items 4 + 6 of path-to-PASS).

> ⚠️ **No Sprint-Level QA Plan**: Per project pattern (locked sprint-2 Phase 5), QA discipline is per-epic. Sprint-7 implementation stories require:
> - **scenario-progression epic**: `/qa-plan scenario-progression` should be authored Should-Have AFTER S7-02 lands; not Must-Have because ScenarioRunner is autoload + Logic-type stories with high automated coverage. Promote to Must-Have if integration test count target >25 cases lands.
> - **destiny-branch epic**: `/qa-plan destiny-branch` should be authored Should-Have AFTER S7-03 lands.
> - **ai-system epic**: `/qa-plan ai-system` should be authored Should-Have AFTER S7-04 lands.
> - **chapter-1 integration**: chapter-1 IS the integration test target — covered by S7-05 acceptance criteria + ScenarioRunner / DestinyBranchJudge / AISystem integration tests.

> **Reminder**: re-run `/gate-check pre-production` AFTER S7-01..S7-07 close AND S7-11 user attestation captured. Expected verdict upgrade: CONCERNS → PASS + `production/stage.txt` written = "Production". This sprint's success criterion IS the gate-check upgrade.
