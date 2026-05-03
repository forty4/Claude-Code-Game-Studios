# Sprint 6 — 2026-05-24 to 2026-05-30

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Generated**: 2026-05-03
> **Carries**: sprint-5 retrospective AI #1 (tighten estimation 3rd ratchet) + AI #2 (architecture-review structural backfill) + AI #3 (Battle Scene wiring primary work) + AI #4 (battle-hud /create-stories early) + AI #5 (G-class gotcha procedural fix)

## Sprint Goal

**Ship the first runnable Battle Scene that mounts BattleCamera + GridBattleController + BattleHUD + HPStatusController + TurnOrderRunner together — the +1 playable-surface delta that finally puts a user in front of a working battle.** Battle HUD lands first 2 implementation stories (skeleton + 11 GameBus subscriptions) so the BattleScene has a real Control to wire under CanvasLayer. Architecture-review structural backfill (~45 TRs + 15 file edits) closes the deferred debt from sprint-5 delta #10 in the same fresh `/architecture-review` session that escalates the Battle Scene Wiring ADR.

## Pivot context (carried from sprint-5)

Sprint-5 was the integration-infrastructure sprint: grid-battle-controller (4th battle-scoped Node) + battle-hud ADR-0015 (5th battle-scoped Node, first Presentation-layer ADR) shipped 13/13 with +84 tests. Sprint-6 is the **integration-and-mount sprint**: take all 5 shipped battle-scoped Nodes + ADR-0015 BattleHUD, and wire them into a single `BattleScene` that loads under `--main-scene`. This is the **first user-facing playable surface** since the prototype iterations of sprint-3 — and unlike those throwaway prototypes, this is production code.

Sprint-7 = first chapter (장판파) playable + Scenario Progression + Destiny Branch impl (consumers of the Pillar 2 hidden-fate channel locked sprint-5).

## Capacity (per sprint-5 retro AI #1 — continued tightening, 3rd consecutive ratchet)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work
- Available: **4.25 working days**

> **AI #1 ratchet**: sprint-5 was 4.2d nominal / ~2d actual = ~2× off. Sprint-6 plan targets **2.4d Must-Have nominal**, down from sprint-5's 3.55d. Should-Have buffers if Must lands fast (~1 day actual at current velocity); Nice-to-Have absorbs remaining slack. If Must+Should ship in 1 calendar day per pattern, sprint-7 plan tightens further to 1.5d nominal.

## Context

Project state as of 2026-05-03 (post-sprint-5 close):

- **Sprint-5 closed 13/13** (Must 11/11 + Should 2/2 + Nice 0/0). 19th consecutive failure-free baseline (841 PASS).
- **All 15 ADRs Accepted** (ADR-0015 Battle HUD escalated 2026-05-03 via delta #10).
- **13 epics Complete + 2 Ready** — Platform 3/3 + Foundation 4/5 (input-handling Ready) + Core 3/4 + Feature 3/13 + **Presentation 1/6 Ready** (battle-hud).
- **First Presentation-layer epic** (battle-hud) authored Ready; 5-8 stories anticipated.
- **First Pillar 2 hidden-semantic lock** shipped (`battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern; CRITICAL — KEEP forever).
- **Architecture-review structural backfill** (~45 TRs + ~15 file edits across ADR-0013/0014/0015 era) DEFERRED from sprint-5 delta #10 — bundled into sprint-6 S6-02.
- **`src/ui/` still empty** — battle-hud impl stories (S6-05/S6-06) crack it; Battle Scene wiring (S6-07) mounts it.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S6-01 | `/architecture-decision battle-scene-wiring` — ADR-0016 governing the BattleScene root Node + 9-param BattleHUD `setup()` invocation + 8-param GridBattleController `setup()` + child-order CanvasLayer mount + scene tree topology + load-order vs init-order separation. Closes the implicit "battle scene composition" contract referenced from ADR-0014 + ADR-0015 without their owning the answer. | claude | 0.4 | — | ADR-0016-battle-scene-wiring.md authored Proposed; godot-specialist 3-pass review per sprint-4 retro AI #3 lean-mode pattern (now standardized at 3 invocations); cross-references all 5 mounted systems (BattleCamera + GridBattleController + BattleHUD + HPStatusController + TurnOrderRunner) + GameBus + InputRouter; architecture.yaml registry entry drafted. |
| S6-02 | `/architecture-review` fresh session — escalates ADR-0016 Proposed → Accepted **AND** performs structural backfill (~45 TRs + ~15 file edits across ADR-0013 + ADR-0014 + ADR-0015 era — sprint-5 delta #10 deferred debt per retro AI #2). Single combined session per workflow-tax mitigation. | claude | 0.5 | S6-01 | ADR-0016 status flip Proposed → Accepted; tr-registry.yaml amended with battle-hud + grid-battle-controller + camera TR-IDs (~45 entries); architecture.yaml v8 → v9; architecture-review-2026-05-XX.md report shipped; PASS verdict; sprint-5 retro AI #2 marked CLOSED. |
| S6-03 | `/create-epics battle-scene` + EPIC.md scaffold — first user-visible-surface integration epic; preview ~3-5 stories (BattleScene root + mock encounter loader + main scene wiring as Godot project entry point). | claude | 0.3 | S6-02 | production/epics/battle-scene/EPIC.md authored Ready; epics-index.md updated with battle-scene row; cross-links ADR-0016 + 5 supporting ADRs; preview story decomposition with TR-IDs + ACs. |
| S6-04 | `/create-stories battle-hud` (sprint-5 deferred per retro AI #4) — break battle-hud EPIC.md preview into 5-8 implementable stories. Each story embeds GDD UI-GB-* refs + ADR-0015 §refs + 7-verification-gate ownership table from EPIC.md. | claude | 0.2 | S6-02 (ADR-0015 already Accepted via delta #10) | 5-8 story files in production/epics/battle-hud/; each embeds GDD UI-GB-* refs + ADR-0015 §refs + ACs; story-008 epic-terminal sequenced with 7-verification-gate closure. |
| S6-05 | battle-hud story-001 — BattleHUD class skeleton + 9-param `setup()` DI + `_ready()` 9-backend assertion + `_exit_tree()` 11-disconnect cleanup + scene mount under CanvasLayer + `class_name BattleHUD extends Control`. | claude | 0.3 | S6-04 | story Complete + DI assertion test + class_name verified; full regression PASS (target ~845 cases — +4 lifecycle tests); 20th consecutive failure-free baseline. |
| S6-06 | battle-hud story-002 — 11 GameBus signal subscriptions all CONNECT_DEFERRED + per-handler stub bodies + DI test seam `_handle_signal(name, args)`. Closes verification gate #5 (recursive MOUSE_FILTER_IGNORE) + #6 (CONNECT_DEFERRED discipline lint). | claude | 0.3 | S6-05 | story Complete + 11 signals subscribed test + CONNECT_DEFERRED lint test + recursive MOUSE_FILTER_IGNORE smoke test; ~852 PASS target. |
| S6-07 | battle-scene story-001 — BattleScene root + `scenes/battle/battle_scene.tscn` + mounts BattleCamera + GridBattleController + BattleHUD + HPStatusController + TurnOrderRunner + hardcoded 4-unit mock encounter loader; first run = `godot --path . --main-scene scenes/battle/battle_scene.tscn` produces non-crashing battle screen — **the +1 playable-surface delta**. | claude | 0.4 | S6-06 | scenes/battle/battle_scene.tscn exists + main scene config updated in project.godot OR documented gating; smoke playthrough doc at production/qa/evidence/battle_scene_smoke_2026-05-XX.md; 0 errors / 0 orphans; **playable-surface delta target +1 achieved**. |

**Must-have subtotal: ~2.4 working days nominal** (~19h).

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S6-08 | `/qa-plan battle-hud` — per-epic QA plan (sprint-2 Phase 5 discipline; mandatory before story-003 onward per established locked discipline). | claude | 0.2 | S6-04 | production/qa/qa-plan-battle-hud-2026-05-XX.md exists; 5-8 stories classified Logic/UI/Integration; test count target locked; verification-gate ownership table per battle-hud EPIC.md §Engine Compatibility Verification Items. |
| S6-09 | battle-hud story-003 — UI-GB-03 Unit Info Panel (full populate via `_on_unit_selected_changed` + `_hp_controller.get_*` + `_hero_db.get_hero` + `_unit_role.get_max_hp`) + UI-GB-11 DEFEND Stance Badge. Closes verification gate #2 (AccessKit screen reader announcement on Unit Info Panel — macOS VoiceOver). | claude | 0.4 | S6-06, S6-08 | story Complete; UI-GB-03 + UI-GB-11 render per battle-hud.md §3; AccessKit verification on macOS VoiceOver documented in evidence; ~860 PASS target. |
| S6-10 | `/architecture-decision scenario-progression` — ADR-0017 governing Beat 1 → Beat N data structure + chapter file format + scenario state autoload OR battle-scoped Node form decision. Cross-references battle-scene wiring + future Destiny Branch ADR (S6-11 nice-to-have). | claude | 0.5 | S6-02 | ADR-0017 authored Proposed; cross-references battle-scene wiring + future Destiny Branch ADR; godot-specialist 3-pass review per AI #3 standard. |

**Should-have subtotal: ~1.1 working days nominal** (~9h).

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S6-11 | `/architecture-decision destiny-branch` — ADR-0018 governing the SOLE consumer of `hidden_fate_condition_progressed` channel + `battle_outcome_resolved.fate_data` snapshot interpretation + Beat 7 reserved-color reveal mechanics per game-concept.md Pillar 2 + destiny-branch.md Section B. | claude | 0.5 | S6-10 | ADR-0018 authored Proposed; ratifies Pillar 2 lock from ADR-0015 (Destiny Branch IS the lone consumer); cross-references game-concept.md Pillar 2 + destiny-branch.md Section B; godot-specialist 3-pass review. |
| S6-12 | battle-hud story-004 — UI-GB-01 Initiative Queue + UI-GB-07 Turn/Round Counter + UI-GB-08 Victory Condition Display. | claude | 0.4 | S6-06 | story Complete; UI-GB-01/07/08 render per battle-hud.md §3; ~865 PASS target. |

**Nice-to-have subtotal: ~0.9 working days nominal** (~7h).

**Sprint-6 total nominal**: ~4.4 working days (Must + Should = ~3.5d within 4.25 capacity; Nice slips first if budget tight).

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| Architecture-review structural backfill (~15 files + ~45 TRs) | Sprint-5 delta #10 explicitly DEFERRED to "future explicit run" — bundled into S6-02 fresh session per retro AI #2 | 0.5d (combined with ADR-0016 escalation) |
| Hero portraits (8) — user-owner | Sprint-4 S4-05 → user-owner; not blocking sprint-6 critical path (BattleScene mock uses ColorRect placeholders per sprint-3 prototype precedent) | n/a (user) |
| BGM candidates (2-3) — user-owner | Sprint-4 S4-06 → user-owner; not blocking sprint-6 critical path | n/a (user) |

## Risks

- **R1 — `/architecture-decision` + `/architecture-review` same-session ban hits twice this sprint** (S6-01 → S6-02 for ADR-0016 Battle Scene Wiring; S6-10 ADR-0017 Scenario Progression + S6-11 ADR-0018 Destiny Branch each need future fresh-session escalation). **Mitigation**: bundle backfill + ADR-0016 escalation into single S6-02 fresh session (already designed); ADR-0017/0018 escalations drop to sprint-7 if not budget-feasible. The two-session ship pattern is now well-rehearsed (sprint-5 delta #10 validated at 10 invocations of /architecture-review).
- **R2 — Battle Scene "first runnable" definition is fuzzy**. Risk that S6-07 ships a scene that mounts but doesn't actually play (no input wired, no win condition firing, etc.). **Mitigation**: AC explicitly requires "non-crashing battle screen" + smoke evidence doc; full playable Beat 1 is sprint-7 work, not sprint-6. The bar is "scene loads + 5 systems mount + can be smoke-tested" — not "complete first chapter".
- **R3 — InputRouter still Foundation/Ready, not Complete** — battle-hud story-002 + battle-scene story-001 both touch InputRouter integration. **Mitigation**: per battle-hud EPIC.md R-3, use stub `tests/helpers/input_router_stub.gd`; full InputRouter impl stays separate epic. BattleScene S6-07 mock encounter does NOT require live input routing — it just needs to mount. Live input ships sprint-7+ when input-handling impl lands.
- **R4 — Architecture-review structural backfill scope unknown** — "~45 TRs + ~15 file edits" is the sprint-5 delta-#10 estimate; actual count emerges during the run. **Mitigation**: budget S6-02 at 0.5d (generous); if backfill blows past 1.5h actual, escalate by deferring ~10-15 TRs to sprint-7 partial backfill. Worth-it-debt-payoff because debt grows the longer it sits.
- **R5 — godot-specialist 3-pass review on UI-domain ADR-0016 may surface dual-focus / AccessKit / scene-tree-init-order issues** like ADR-0015 did (HIGH engine risk for Presentation domain). **Mitigation**: ADR-0016 is wiring/topology not Control-element design, so engine-risk should be MEDIUM not HIGH; the godot-specialist review is mandatory regardless (sprint-4 retro AI #3 standard at 3 invocations).
- **R6 — Sprint-5 5×-faster-than-planned velocity may not continue** as scope shifts to UI-rendering work. UI work has more cross-platform variance + visual verification overhead vs. pure Logic. **Mitigation**: per-story commit cadence + screenshot evidence for each UI element; if velocity slows 1.5×, Should + Nice slip cleanly per sprint-5 retro AI #1 discipline.
- **R7 — G-class gotcha re-hits during UI work** (sprint-5 had 2 hits — G-4 + G-7 in `.claude/rules/godot-4x-gotchas.md`). UI domain may surface NEW gotchas at first invocation (recursive MOUSE_FILTER_IGNORE, AccessKit Control inheritance, dual-focus state machine). **Mitigation**: per sprint-5 retro AI #5, skim-reference `.claude/rules/godot-4x-gotchas.md` + `.claude/rules/tooling-gotchas.md` at start of each /dev-story; document NEW UI-domain gotchas as discovered (G-16+).

## Dependencies on External Factors

- None at the system level. All 9 backends consumed by BattleHUD + Battle Scene Wiring are Complete (8 of 9) or Ready-with-stub-strategy (InputRouter — 1 of 9). No external library updates pending. Godot 4.6 stable since Jan 2026 (3+ months runway).
- **User-owner deferred items** (hero portraits + BGM) remain optional for sprint-6 — BattleScene mock uses ColorRect placeholders per sprint-3 prototype precedent. User can drop assets in `assets/art/heroes/portraits/` + `assets/audio/bgm/candidates/` at any spare 1-2h window before sprint-7 first chapter implementation.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S6-01..S6-07 = 7 stories)
- [ ] All tasks pass acceptance criteria
- [ ] **ADR-0016 Battle Scene Wiring** authored AND escalated Proposed → Accepted (S6-01 + S6-02)
- [ ] **Architecture-review structural backfill complete** (~45 TRs + ~15 files; sprint-5 retro AI #2 closed)
- [ ] battle-hud epic broken into 5-8 stories (S6-04)
- [ ] battle-hud first 2 implementation stories Complete (S6-05 skeleton + S6-06 signals)
- [ ] **First runnable BattleScene** at scenes/battle/battle_scene.tscn — mounts 5 systems without crash (S6-07)
- [ ] battle-scene epic Complete OR Ready with stories scaffolded (S6-03)
- [ ] Smoke evidence doc at production/qa/evidence/battle_scene_smoke_2026-05-XX.md
- [ ] Full GdUnit4 regression: ≥845 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (target 845-865 depending on Should-Have ship)
- [ ] `production/epics/index.md` updated: Presentation 1/6 Ready → 1/6 with first impl stories shipped + battle-scene row added
- [ ] `production/sprint-status.yaml` updated per the 200-byte cap discipline (S3-05 active)
- [ ] Sprint-6 retrospective written before sprint-7 kickoff
- [ ] **+1 playable-surface delta achieved** (sprint-4 was first +1 with BattleCamera; sprint-5 was infrastructure with no +; sprint-6 returns the +1 with BattleScene)

## Cross-References

- **Sprint-5 retro**: `production/retrospectives/retro-sprint-5-2026-05-03.md` (AI #1-5 driving sprint-6 plan)
- **Architecture-review delta #10 report**: `docs/architecture/architecture-review-2026-05-03.md` (deferred backfill spec)
- **Governing ADRs**: ADR-0015 Battle HUD (Accepted 2026-05-03 via delta #10) + ADR-0016 Battle Scene Wiring (S6-01) + ADR-0017 Scenario Progression (S6-10 should-have) + ADR-0018 Destiny Branch (S6-11 nice-to-have)
- **Battle HUD epic**: `production/epics/battle-hud/EPIC.md` (Ready; 5-8 stories anticipated)
- **GDD sources**: `design/ux/battle-hud.md` v1.1 (744 lines) + `design/gdd/grid-battle.md` (1259 lines, MVP subset only) + `design/gdd/game-concept.md` Pillar 2 + `design/gdd/destiny-branch.md` Section B
- **Prior sprints**: `production/sprints/sprint-{1,2,3,4,5}.md`

> **Scope check**: Sprint-6 stories all derive from sprint-5 retro AI items + active.md Top-ADR-gaps Next-Session Candidates. Run `/scope-check battle-hud` after S6-04 if story decomposition diverges from EPIC.md preview.

> ⚠️ **No Sprint-Level QA Plan**: Per project pattern, QA discipline is per-epic (locked sprint-2 Phase 5). The sprint-6 implementation stories require:
> - **battle-hud epic**: `/qa-plan battle-hud` is S6-08 should-have — should land BEFORE S6-09 story-003 onward. If Must-Have ship races ahead, /qa-plan battle-hud may need to elevate to Must-Have mid-sprint.
> - **battle-scene epic**: `/qa-plan battle-scene` not yet scheduled; defer to sprint-7 with battle-scene story-002+ implementation stories. Sprint-6 ships only battle-scene story-001 (mount smoke) which is Integration story type with documented playthrough evidence per project standards.
