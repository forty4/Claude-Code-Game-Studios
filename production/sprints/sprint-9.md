# Sprint 9 — 2026-06-14 to 2026-06-20

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-05-05 (`docs/architecture/control-manifest.md` — refreshed via S7-08; sprint-9 doesn't refresh)
> **Generated**: 2026-05-06
> **Carries**: Sprint-8 retro AI seeds (10 carried forward — see §Sprint-9 Retro AI seed) + sprint-8 Producer split-input-handling-epic recommendation closure (stories 6-10) + 4 sprint-8 Nice-to-Have deferrals (S8-12..S8-14, S8-16) + 2 USER-OWNED gates (S7-11 + S8-15)
> **Generated to close**: input-handling epic 10/10 (closing Producer split decision from sprint-7) + sprint-8 Nice-to-Have backlog absorption + sprint-9 codification follow-throughs + Save/Load #17 Core epic creation post-S8-08 GDD authoring

## Sprint Goal

**Close the input-handling epic 10/10** (stories 6-10 complete the Producer split decision from sprint-7) **+ absorb sprint-8 Nice-to-Have backlog** (3 character profile stubs + AD-C3 font glyph check + main menu UX spec) **+ create Save/Load #17 Core epic post-GDD authoring**. Sprint-9 is a **closure sprint** — completes long-pending Producer-pressure-cut items rather than opening new feature scope. Sprint-7 retro AI #5 (CI lane gap) gets formal acceptance/postpone decision. Sprint-8 retro Process Improvement #1 (codification debt at retro time) is now project discipline; sprint-9 retro evaluates whether further G-* candidates surface from input-handling 6-10 work.

## Pivot context (carried from sprint-8 retro 2026-05-06)

Sprint-8 was the **strongest sprint by every claude-owned metric**: Must+Should 11/11 closed in ~1 calendar day at sustained 5× velocity multiplier (4-sprint trend stable), 38th consecutive failure-free baseline (+12 streak ratchet), Pillar 2 architectural lock pattern STABILIZED at 6 invocations (codification threshold reached), combined-session escalation pattern STABLE at 5 invocations + first cross-calendar-day variant, sprint-status hygiene close-in-same-patch STABILIZED at 15-streak. Sprint-8's two failure modes: (1) codification debt accumulated rather than paid down — addressed via new Process Improvement #1 ("codification debt MUST be paid at retro time"); (2) S8-15 added 2nd USER-OWNED attestation gate on top of S7-11.

Gate-check 2026-05-06 returned **CONCERNS** (unchanged from 2026-05-05). Sole gating blockers: S7-11 + S8-15 USER-OWNED attestation (refusal-to-fabricate posture commitment cost). Sprint-9 critical path does NOT include claude-owned gate-check work — claude side is fully discharged.

Sprint-9 is the **input-handling closure + sprint-8 Nice absorption sprint**. Producer split-input-handling-epic recommendation from sprint-7 closes here (stories 6-10 ship). Sprint-8 deferred 4 Nice-to-Haves (S8-12..S8-14, S8-16); sprint-9 absorbs them as Should-Have to honor Producer pressure-cut acceptance discipline.

## Capacity (per sprint-8 retro AI #4 — 5× velocity multiplier stable across 4 sprints)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work (input-handling epic-terminal scope discovery risk)
- Available: **4.25 working days**

> **AI #4 ratchet (5th consecutive)**: sprint-8 was 5.5d nominal / ~1d actual = ~5×. Sprint-9 plan targets **~2.5d Must-Have nominal** (input-handling 5-story closure) + ~1.0d Should-Have + ~0.5d Nice — **~4.0d total** (down from sprint-8's 5.5d to absorb closure-mode discipline). Velocity-multiplier baseline now stable at 5× across sprint-5/6/7/8 (4 consecutive sprints) — projection for sprint-9 actual: **~0.8d**. If multiplier holds, sprint-9 ships in ~1 calendar day actual.

## Context

Project state as of 2026-05-06 (post-sprint-8 close + retro + 3 G-* codifications):

- **20 ADRs Accepted**. ADR-0020 (InputRouter Dispatch) Accepted 2026-05-06 via /architecture-review delta #15 (1st cross-calendar-day fresh-session escalation). No new ADRs pending for sprint-9 — input-handling 6-10 all governed by ADR-0005 + ADR-0020.
- **Pre-Production → Production verdict**: CONCERNS (gate-check 2026-05-06 unchanged). 3 directors READY + 1 CONCERNS (CD only — Pillar 3+4 demonstration unproven without playtest evidence).
- **Sole gate-check upgrade blockers**: S7-11 + S8-15 USER-OWNED attestation (both blocked on user time). Path-to-PASS unchanged.
- **Pillar 2 architectural lock pattern STABILIZED at 6 invocations** (codification threshold reached; no new candidates expected from sprint-9 work).
- **Combined-session escalation pattern STABLE at 5 invocations** (4 same-day + 1 cross-calendar-day; pattern stability declared).
- **In-patch sprint-status hygiene close STABILIZED at 15-streak** (target was 6+; comfort margin 9).
- **Autoload Node pattern at 9 production autoloads** (was 8 entering sprint-8; +1 InputRouter at boot pos 9). Sprint-9 may add +1 Save/Load Core epic autoload candidate if Save/Load #17 creates a new autoload.
- **Battle-scoped Node pattern at 6 invocations** (unchanged sprint-8).
- **G-26 + G-27 + G-28 codified** in `.claude/rules/godot-4x-gotchas.md` (sprint-8 retro 2026-05-06; codification debt paid at retro time per new Process Improvement #1).
- **Story-spec doc-correction sweep complete** for input-handling stories 002-004 (`ctx.unit_id` → `ctx.target_unit_id` + `ctx.coord` → `ctx.target_coord` per actual InputContext schema).
- **1116/1116 PASSING** (38th consecutive failure-free baseline).
- **Tech debt register at 67 entries** (TD-063..TD-067 added sprint-8 from S8-07 /code-review; deferred to sprint-9 input-handling 6 OR grid-battle epic ownership).
- **Sprint-8 Nice-to-Have deferrals** (4 items): S8-12 character profile stubs (3) + S8-13 AD-C3 glyph check + S8-14 main menu UX spec stub + S8-16 chapter-2 scoping. All re-included in sprint-9 Should/Nice tiers.
- **Save/Load #17 GDD landed Designed** (S8-08); systems-index row 17 PROVISIONAL → Designed; **save-manager Platform epic already 8/8 Complete** since 2026-04-24 — Save/Load #17 may be schema-spec ratification only (verify at sprint-9 epic-creation time before opening implementation stories).

## Tasks

### Must Have (Critical Path) — input-handling epic 6-10 closure

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S9-01 | input-handling story-006 — per-unit undo window (CR-5) + window OPEN/CLOSE on confirm/attack/end-turn + EC-5 occupied-tile rejection + GridBattleStub extension | claude | 0.4 | sprint-8 input-handling 1-5 done | story-006 file: `production/epics/input-handling/story-006-per-unit-undo-window.md` AC-1..AC-11 satisfied; `_undo_windows: Dictionary[int, UndoEntry]` lifecycle + `_apply_undo` helper + GridBattleStub `restore_unit_to_pre_move` + `is_tile_occupied`; ≥10 tests; closes TD-064 _grid_controller.is_undo_available API placeholder via real production method |
| S9-02 | input-handling story-007 — input_blocked + menu_open S5/S6 states + 3-arm input_blocked_reason vocabulary + open_game_menu S6 transition | claude | 0.4 | S9-01 | story-007 file: `production/epics/input-handling/story-007-input-blocked-and-menu-open.md` AC-1..AC-N satisfied; S5 (INPUT_BLOCKED) + S6 (MENU_OPEN) states wired + return-from-menu via `_pre_menu_state` already-shipped scaffolding (story-004); ≥8 tests |
| S9-03 | input-handling story-008 — touch protocol Tap Preview Protocol magnifier F1 + i18n .tscn lint scope extension (closes TD-067) + TD-065 + TD-066 absorption | claude | 0.5 | S9-02 | story-008 file AC satisfied; TPP magnifier F1 implementation per ADR-0020 §Phase 1 mode-determine + ADR-0015 §OQ-4 HUD-owns-timer; lint scope extension to `.tscn` files for `battle_hud_hardcoded_localized_strings` forbidden_pattern; TD-065 + TD-066 + TD-067 closed in same patch; ≥8 tests |
| S9-04 | input-handling story-009 — touch protocol pan/tap gestures + InfoPanel scrolling per ADR-0005 §1 + CR-1c per-touch-mode interaction discipline | claude | 0.4 | S9-03 | story-009 file AC satisfied; pan + tap gesture distinction at touch boundary; InfoPanel scrolling on touch via `screen_drag` event subscription; ≥6 tests |
| S9-05 | input-handling story-010 — epic-terminal perf+lints+evidence pass + close all 8 forbidden_patterns from ADR-0020 + lint scripts in `tools/ci/` | claude | 0.4 | S9-04 | story-010 file AC satisfied; all 8 input-handling forbidden_patterns lint scripts shipped in `tools/ci/`; per-frame state polling check via grep + structural source-scan of caller allow-list; total InputRouter regression suite ≥1180 tests target (1116 baseline + ~50-65 net new from stories 006-010) / 0 errors / 0 failures / 0 orphans / Exit 0; **input-handling epic 10/10 Complete** flip in `production/epics/index.md` |

**Must-have subtotal: ~2.1 working days nominal** (~17h). Per 4-sprint-stable 5× velocity multiplier, projected actual: ~0.4-0.5 calendar day.

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S9-06 | **Save/Load #17 Core epic creation OR design-only ratification** — verify against existing save-manager Platform epic (8/8 Complete since 2026-04-24); if Save/Load #17 GDD adds NEW schema/contract not yet implemented, run `/create-epics save-load` + author 1-3 first stories; if GDD purely ratifies existing impl, flip systems-index row 17 Designed → Implemented (no-op) | claude | 0.3 | sprint-8 S8-08 GDD landed | Either: NEW save-load Core epic created at `production/epics/save-load/EPIC.md` with 1-3 stories ready for sprint-10; OR systems-index row 17 confirmed ratified-by-existing-impl with no impl gap |
| S9-07 | **First 3 character visual profile stubs** (유비/장비/리유비 — chapter-1 player roster) — closes AD-C5 ADVISORY from sprint-7+8 carryover | claude (or art-director) | 0.3 | — | 3 profile files at `design/art/characters/{liu-bei,zhang-fei,guan-yu}.md` (or 유비/장비 etc) with Section 1-3 minimum (silhouette + costume + role-anchor); AD-C5 ADVISORY closed in next gate-check |
| S9-08 | **AD-C3 font glyph check (緣 bond glyph rendering verification)** across chapter-1 text — gates Story Event #10 text rendering tasks (currently unblocked since S8-09 shipped) | claude | 0.2 | — | Test renders 緣 + verifies glyph fidelity in default font set (Pretendard or pinned chapter-1 font); result documented at `production/qa/evidence/font_glyph_check_緣.md`; AD-C3 OPEN closed in next gate-check |
| S9-09 | **Main menu UX spec stub** at `design/ux/main-menu.md` — minimal section structure (information architecture + key states + accessibility tier compliance per `accessibility-requirements.md` Intermediate tier); closes AD-C6 ADVISORY | claude (or ux-designer) | 0.2 | — | UX spec created with 8-section template; references `accessibility-requirements.md` Intermediate tier; AD-C6 ADVISORY closed in next gate-check |

**Should-have subtotal: ~1.0 working day nominal** (~8h).

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S9-10 | **Pillar 4 chapter-2 scoping + chapter-1-callback ACs** (CD recommendation; carryover from S8-16) — defines mechanical-narrative ripple-validation criteria for chapter-2; produces chapter-2 enemy roster + branch_table outline draft | claude | 0.3 | sprint-8 S8-11 chapter-1 e2e validated ScenarioRunner chain | chapter-2 outline draft at `design/scenarios/chapter-2-outline.md` (PROVISIONAL); chapter-1-callback ACs codify how ripple-narrative is validated; Pillar 4 demonstration gate criteria for sprint-10+ playtest |
| S9-11 | **CI lane gap formal decision** (sprint-7 AI #5 + sprint-8 AI #8 — 2-sprint deferred) — either ship macOS / iOS / Android automated CI lanes OR formally postpone to post-MVP with rationale | claude | 0.2 | — | Decision recorded at `production/decisions/ci-lane-gap-decision-2026-05-XX.md` (file path TBD); either CI workflow file added in `.github/workflows/` for at least one new lane OR rationale doc explaining post-MVP postponement |
| S9-12 | **Sprint-plan template refinement** — separate user-owned carryovers from claude-owned in `production/sprints/` template per sprint-8 retro carryover-tracking refinement note | claude | 0.1 | — | Future sprint plans use distinct sections for user-owned (hero portraits + BGM + attestations) vs. claude-owned carryovers; velocity metrics not distorted by perpetual non-claude carryovers |
| S9-13 | **S7-11 user attestation pass** on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` — **USER-OWNED** carryover (3rd time; 2-sprint streak from S7-11 → S8-15 → now) | user | n/a | — | 3-5 captured run notes appended; triggers /gate-check pre-production re-run with PASS upgrade path |
| S9-14 | **S8-15 user attestation pass** on sprint-8 manual smoke check Batches 1+3 — **USER-OWNED** carryover (1st time post-introduction; sprint-8 added this gate) | user | n/a | — | Manual smoke check Batches 1+3 walked through + signed off in `production/qa/qa-signoff-sprint-8-2026-05-06.md` USER ATTESTATION section; triggers /gate-check pre-production re-run |

**Nice-to-have subtotal: ~0.6 working day nominal claude-owned** (~5h) + user-owned attestations (S9-13 + S9-14).

**Sprint-9 total nominal**: ~3.7 working days claude-owned (Must + Should + Nice; UNDER 4.25 capacity by 0.55d). **Most likely cut point under pressure** (per Producer pressure-cut discipline): defer S9-10 (chapter-2 scoping) to sprint-10 if input-handling 6-10 closure consumes more than nominal, OR drop S9-12 sprint-plan template refinement to sprint-10 (low-impact tooling cleanup).

## Carryover from Previous Sprint

> **NEW carryover-tracking format per S9-12 retro AI** — separate user-owned from claude-owned to avoid velocity-metric distortion:

### Claude-owned carryovers (active sprint scope)

| Task | Reason | New Estimate |
|------|--------|-------------|
| Input-handling stories 6-10 (per-unit undo + input_blocked + TPP magnifier + pan/tap gestures + epic-terminal perf+lints) | Producer split-input-handling-epic decision from sprint-7 — sprint-8 shipped 1-5; sprint-9 closes 6-10 | ~2.1d (S9-01..S9-05) |
| First 3 character visual profile stubs (S8-12 deferred) | Sprint-8 nice-to-have absorbed via Producer pressure-cut acceptance | 0.3d (S9-07) |
| AD-C3 font glyph check (S8-13 deferred) | Sprint-8 nice-to-have; blocker S8-09 cleared | 0.2d (S9-08) |
| Main menu UX spec stub (S8-14 deferred) | Sprint-8 nice-to-have | 0.2d (S9-09) |
| Pillar 4 chapter-2 scoping (S8-16 deferred) | Sprint-8 nice-to-have; blocker S8-11 cleared | 0.3d (S9-10) |
| Save/Load #17 Core epic creation OR ratification (S8-08 GDD landed) | Sprint-8 should-have; impl deferred per Producer split | 0.3d (S9-06) |
| CI lane gap (sprint-7 AI #5 → sprint-8 AI #8) | 2-sprint deferred; sprint-9 forces decision | 0.2d (S9-11) |
| Sprint-plan template refinement (sprint-8 retro action item #10) | Carryover-tracking refinement | 0.1d (S9-12) |

### User-owned carryovers (track separately; do not count against velocity)

| Task | Times Carried | Reason | Status |
|------|---------------|--------|--------|
| S7-11 user attestation (4 VS Validation items) | 3rd time (S7-11 → S8-15 → S9-13) | User-owned by design; refusal-to-fabricate posture | Pending user time; ~30-60min |
| S8-15 user attestation (sprint-8 manual smoke Batches 1+3) | 1st time post-introduction | User-owned by design; sprint-8 added | Pending user time; ~30-60min |
| Hero portraits (8) | 5th time (Sprint-4 → 7 → 8 → 9; +1 carryover bump) | User-owner | Non-blocking for critical path; ColorRect placeholders functional |
| BGM candidates (2-3) | 5th time (Sprint-4 → 7 → 8 → 9; +1 carryover bump) | User-owner | Non-blocking for critical path |

## Cut from Sprint-9 (Producer pressure-cut candidates if velocity drops below 5×)

| Task | Reason for cut | Deferred to |
|------|---------------|-------------|
| S9-10 Pillar 4 chapter-2 scoping | Defer if input-handling 6-10 consumes >2.5d actual | sprint-10 |
| S9-12 sprint-plan template refinement | Low-impact tooling cleanup; can absorb at sprint-10 plan-time directly | sprint-10 |
| Save/Load #17 implementation stories (if S9-06 surfaces a real gap) | Producer split-strategy: don't bundle Save/Load impl with input-handling closure; ship Save/Load impl in sprint-10 | sprint-10 |
| Character profile stubs 4-7 (remaining Wei generals) | First 3 are sprint-9 should-have; remaining defer | sprint-10+ |
| Pause menu UX spec | Deferrable to menu implementation sprint per gate-check 2026-05-04 §AD-C6 | sprint-10+ menu sprint |
| ADR Engine Compatibility / Depends-on / Depended-by header backfill across 20 ADRs (TD ADVISORY) | Hardening pass; not gating Production work | sprint-10+ hardening sprint |

## Risks

- **R1 — Input-handling story-006 undo window logic surfaces InputContext sentinel ambiguity** (TD-candidate-E from sprint-8 retro: `Vector2i.ZERO` is both (0,0) playfield grid origin AND "no coord" sentinel). **Mitigation**: story-008 + story-009 owned redesign per sprint-8 retro Process Improvement #3; story-006 may surface the issue earlier. If surfaced, redesign InputContext defaults to `Vector2i(-1, -1)` matching `target_unit_id = -1` pattern in same patch (3rd-precedent for sentinel-discipline alignment).
- **R2 — Story-007 input_blocked S5 + menu_open S6 may surface end-phase interaction bugs** (sprint-8 S8-04 added `_pending_end_phase` 2-beat safety gate; story-007 introduces `input_blocked_reasons` PackedStringArray which interacts with end-phase logic). **Mitigation**: story-007's full ACs MUST cover end-phase × input_blocked × menu_open 9-cell interaction matrix; if not, hold story until matrix added.
- **R3 — Story-008 i18n .tscn lint scope extension (TD-067) requires lint script authoring vs grep-only** (current `.gd`-only forbidden_pattern lint at `tools/ci/lint_battle_hud_no_hardcoded_localized_strings.sh` greps `.gd` files; `.tscn` extension requires multi-line awk parsing of node properties). **Mitigation**: story-008 budget includes lint extension; if lint authoring exceeds 1h, defer extension to story-010 epic-terminal lint pass and unblock story-008 ship.
- **R4 — Story-010 epic-terminal lint pass forced to ship 8 forbidden_pattern lint scripts** (per ADR-0020 §architecture.yaml v14 forbidden_patterns); some lints may require structural source-scan vs grep due to G-22 precedent. **Mitigation**: story-010 budget assumes mix of grep + awk patterns; if any single lint exceeds 30min, document as deferred follow-up per story-010 Acceptance Criteria.
- **R5 — Save/Load #17 Core epic verification (S9-06) may surface a real implementation gap** that wasn't visible at S8-08 GDD authoring time. If gap is significant (>0.3d additional impl work), sprint-9 cuts S9-06 to "epic creation only" + defers actual stories to sprint-10. **Mitigation**: budget S9-06 generously at 0.3d for verification + epic-creation; defer impl-stories cleanly per Producer cut-point identification.
- **R6 — 5× velocity multiplier may fragment under closure-mode discipline** (sprint-9 is closure-heavy; less greenfield architecture work; may not sustain 5× as cleanly as sprint-7+8 mixed-scope). **Mitigation**: Sprint-9 nominal already cut to ~3.7d (down from sprint-8's 5.5d); even at 3× velocity, sprint-9 ships in ~1.2d actual. Don't worry about mode-shift artifacts unless multiplier drops below 2×.
- **R7 — User-owned carryovers stack to 4 items** (S7-11 + S8-15 + portraits + BGM) — gate-check trajectory CONCERNS chain remains regardless of claude-owned work. **Mitigation**: communicate the user-owned backlog explicitly at sprint-9 retro; do NOT confuse refusal-to-fabricate posture with sprint failure. Sprint-9 retro should call out cumulative user-owned debt as project-state fact, not sprint blocker.
- **R8 — Codification debt may recur if input-handling 6-10 surfaces new G-* candidates** (sprint-8 had 3 candidates surface; per Process Improvement #1, sprint-9 retro MUST codify all surfaced candidates at retro time, not defer). **Mitigation**: at each story `/code-review` pass, capture any G-* candidate surfaced; sprint-9 retro pre-allocates ~30min for codification work.
- **R9 — TD-063 + TD-064 GridBattleController API placeholders are still outstanding** (`is_action_available` + `is_undo_available`). Story-006 closes TD-064 via real production `is_undo_available(unit_id)` impl. TD-063 (`is_action_available`) needs grid-battle epic owner; not closed by sprint-9 input-handling work. **Mitigation**: TD-063 explicitly carried to grid-battle epic Polish-tier ownership; document handoff in story-006 Completion Notes + TD-063 register entry.
- **R10 — User attestation S9-13 + S9-14 require user time** (~60-120min total for both). If user is unavailable during sprint-9 window, /gate-check upgrade CONCERNS → PASS continues to slip. **Mitigation**: Both gates are user-owned with no claude prerequisite (chapter-prototype runnable since 2026-05-02; sprint-8 smoke check artifacts complete); attestation can happen any time before next gate-check invocation. Not a sprint-9 blocker.

## Dependencies on External Factors

- None at the system level. All 20 ADRs Accepted; sprint-9 input-handling 6-10 all governed by ADR-0005 + ADR-0020 (Accepted). Engine pinned at Godot 4.6 (3+ months stable runway). GdUnit4 v6.1.2 pinned per `tests/README.md`.
- **User-owner deferred items** (hero portraits + BGM + 2 attestation gates) remain optional for sprint-9 critical path. Critical path uses ColorRect placeholders + text-based scenes per chapter-prototype precedent.
- **CI infrastructure**: Linux Editor + Windows D3D12 lanes active. macOS / iOS / Android lanes manual-fallback per ADR-0018 OQ-DB-6 partial closure. **S9-11 forces formal decision** (ship lanes OR postpone to post-MVP with rationale).

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S9-01..S9-05 = 5 stories closing input-handling epic 10/10)
- [ ] All tasks pass acceptance criteria
- [ ] **input-handling epic 10/10 Complete** — flips in `production/epics/index.md` post-S9-05
- [ ] **InputRouter regression suite ≥1180 tests** (1116 baseline + ~50-65 net new from stories 006-010)
- [ ] **All 8 ADR-0020 forbidden_patterns enforced via lint scripts** in `tools/ci/`
- [ ] **TD-064 closed** (story-006 ships real `is_undo_available(unit_id)` production impl); **TD-065 + TD-066 + TD-067 closed** (story-008 absorbs them)
- [ ] Save/Load #17 Core epic decision recorded (S9-06 — either NEW epic created OR ratification noted in systems-index)
- [ ] First 3 character visual profile stubs at `design/art/characters/` (S9-07 — closes AD-C5)
- [ ] AD-C3 font glyph check evidence at `production/qa/evidence/font_glyph_check_緣.md` (S9-08 — closes AD-C3)
- [ ] Main menu UX spec stub at `design/ux/main-menu.md` (S9-09 — closes AD-C6)
- [ ] CI lane gap formal decision recorded (S9-11)
- [ ] Sprint-plan template refined to separate user-owned carryovers from claude-owned (S9-12)
- [ ] Full GdUnit4 regression: ≥1180 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (target 1180-1200 depending on Should + Nice ship; up from sprint-8's 1116)
- [ ] `production/epics/index.md` updated: input-handling 10/10 Complete + (Save/Load Core epic NEW row if S9-06 creates epic)
- [ ] `production/sprint-status.yaml` updated **per-story-row at completion** (15-streak in-patch close discipline; sprint-9 enforcement target: maintain streak)
- [ ] `tests/regression-suite.md` updated with input-handling epic-terminal critical path coverage
- [ ] Sprint-9 retrospective written before sprint-10 kickoff
- [ ] **Re-run `/gate-check pre-production`** if S9-13 + S9-14 user attestation captured during sprint-9 → expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production"
- [ ] **Codification debt at retro time discipline maintained** — if any G-* candidate surfaces in sprint-9, codify in `.claude/rules/godot-4x-gotchas.md` at retro time per Process Improvement #1

## Sprint-9 Retro AI seed (carried from sprint-8 retrospective)

These will be evaluated at sprint-9 close + carried to sprint-10 plan:

1. **Codification debt MUST be paid at retro time** (NEW from sprint-8 retro Process Improvement #1). Any G-* / TD-* / pattern candidate surfaced during sprint-9 must be codified at sprint-9 retro time, not deferred. Pre-allocate ~30min in retro for codification work.
2. **Lint scope must include `.tscn` content for forbidden patterns about visible content** (NEW from sprint-8 retro Process Improvement #2). Story-008 ships TD-067 lint scope extension; sprint-9 retro evaluates whether the extension caught additional cases.
3. **InputContext sentinel-discipline alignment** (NEW from sprint-8 retro Process Improvement #3). Stories 008-009 own `Vector2i(-1, -1)` "absent" sentinel migration mirroring `target_unit_id = -1`. Validate at sprint-9 retro: did the migration land cleanly + retroactively in input_context.gd?
4. **3-skill arc `/dev-story` → `/code-review` → `/story-done` is now project workflow standard** (NEW from sprint-8 retro Process Improvement #4). Document in `.claude/skills/dev-story/SKILL.md` if not already; validate at sprint-9 retro that all 5 stories used the pattern.
5. **5× velocity multiplier durability under closure-mode scope** (sprint-8 AI #4 carried). Sprint-9 has 12 claude-owned items vs sprint-8's 11; if multiplier drops to 2-3× under closure-mode discipline, sprint-10 nominal estimates re-baseline.
6. **Sprint-status hygiene 15-streak** sustained from sprint-8. Sprint-9 enforcement: maintain streak (target: 20+ for further pattern-stability ratchet declaration).
7. **Carryover-tracking refinement adoption** (sprint-9 S9-12). Validate at retro that the new template separation (user-owned vs claude-owned) is in place.
8. **Pillar 2 architectural lock pattern STABILIZED at 6 invocations** (sprint-8 AI #5 closure). No new candidates expected from sprint-9 work; validate at retro that no Pillar 2 lock surfaced in unexpected place.
9. **Autoload Node pattern at 9 production autoloads** (sprint-8 AI #7 PARTIAL — was target 10). Sprint-9 may add +1 if Save/Load #17 creates a new autoload via S9-06; OR pattern stays at 9 if S9-06 is design-only ratification. Validate at retro.
10. **CI lane gap formal decision** (sprint-7 AI #5 + sprint-8 AI #8). Sprint-9 S9-11 forces decision. Validate at retro that decision shipped + dependency on user is or isn't created.
11. **Codification debt recurrence test**: sprint-9 sustained at 0 deferred G-* candidates if Process Improvement #1 holds. If any candidate surfaces but is NOT codified at retro, that's a process failure.
12. **User-owned attestation backlog growth**: 2 gates entering sprint-9 (S7-11 + S8-15); sprint-9 may add 0 (closure sprint with no new attestation surfaces). Validate at retro that stack count holds at 2 or shrinks.

## Cross-References

- **Sprint-8 retrospective**: `production/retrospectives/retro-sprint-8-2026-05-06.md`
- **Gate-check that informed this sprint plan**: `production/gate-checks/pre-prod-to-prod-2026-05-06.md` (CONCERNS verdict; sole gates = S7-11 + S8-15 USER-OWNED)
- **Architecture-review delta #15 report** (most recent): `docs/architecture/architecture-review-2026-05-06.md` (PASS — 0 BLOCKING + 0 ADVISORY; ADR-0020 Accepted)
- **Governing ADRs (Accepted)**: ADR-0001..0020 (20 ADRs); ADR-0020 (InputRouter Dispatch) Accepted 2026-05-06 most recent
- **Governing GDDs**: `design/gdd/input-handling.md` rev 1.0 + `design/gdd/save-load.md` (NEW rev 1.0 from S8-08) + `design/gdd/scenario-progression.md` rev 2.2 + `design/gdd/destiny-branch.md` rev 1.3.2 + `design/gdd/grid-battle.md` v5.0 + `design/gdd/game-concept.md` (Pillars 1-4 + MVP Core Hypothesis)
- **Governing art-bible sections**: `design/art/art-bible.md` §4.7 reserved_color_treatment + §5 Character Design Direction (S9-07 first 3 character profile stubs target)
- **Control manifest**: `docs/architecture/control-manifest.md` v2026-05-05 + Pillar 2 Architectural Locks section (codifies 6 invocations stable)
- **Tech debt register active items**: `docs/tech-debt-register.md` TD-063..TD-067 (sprint-8 surfaced; sprint-9 stories 006/008 close TD-064/065/066/067; TD-063 carries to grid-battle epic)
- **Engine gotchas codified**: `.claude/rules/godot-4x-gotchas.md` G-1..G-28 (G-26/27/28 codified at sprint-8 retro 2026-05-06)
- **Prior sprints**: `production/sprints/sprint-{1,2,3,4,5,6,7,8}.md`
- **Chapter-prototype**: `prototypes/chapter-prototype/` (chapter.gd + battle_v2.gd + REPORT.md PROVISIONAL PROCEED — S9-13 user-attestation gate target)
- **Input-handling epic**: `production/epics/input-handling/EPIC.md` + 10 stories authored (story-001..story-010); sprint-9 ships stories 6-10 closing 10/10
- **Save-manager Platform epic** (already 8/8 Complete): `production/epics/save-manager/EPIC.md` (sprint-9 S9-06 verifies whether Save/Load #17 GDD requires NEW Core epic OR ratifies existing)

> **Scope check**: Sprint-9 stories all derive from sprint-8 retrospective action items + Producer split-input-handling-epic recommendation closure + sprint-8 Nice-to-Have backlog absorption + carryover from sprint-7+8. Run `/scope-check input-handling` after S9-03 if cumulative input-handling 6-10 scope diverges from sprint-8 ratchet ~2.5d budget.

> ⚠️ **No Sprint-Level QA Plan Yet** — see Phase 5 follow-up. Per project pattern (locked sprint-2 Phase 5), QA discipline is per-epic. Sprint-9 implementation stories require:
> - **input-handling epic** (CLOSURE): existing `/qa-plan input-handling` if any (sprint-8 had inline `## QA Test Cases` per lean-mode discipline) absorbs sprint-9 stories 6-10. Promote to sprint-level QA plan if integration test count target >40 cases lands at S9-05 epic-terminal.
> - **save-load Core epic** (NEW if S9-06 creates): `/qa-plan save-load` should be authored Should-Have AFTER S9-06 if epic creation lands.

> **Reminder**: re-run `/gate-check pre-production` AFTER S9-13 + S9-14 user attestation captured (any time during sprint-9). Expected verdict upgrade: CONCERNS → PASS + `production/stage.txt` written = "Production". This sprint's secondary success criterion IS the gate-check upgrade (primary success criterion is the input-handling epic 10/10 closure).

> **Pre-flight check applied (sprint-7 retro improvement #1, now 3-sprint-stable discipline)**: S9-01..S9-05 verified — all input-handling stories 006-010 are Status: Ready in their respective story files; ADR-0005 + ADR-0020 both Accepted; `_undo_windows: Dictionary[int, UndoEntry]` field already declared at S8-02 (story-001) per ADR-0020 §6 Migration Plan §2; `UndoEntry` RefCounted already shipped at S8-02; `GridBattleStub` already declared `restore_unit_to_pre_move` + `is_tile_occupied` forward-coverage methods at S8-04 (story-003) per the GridBattleStub forward-coverage helper pattern. S9-06 Save/Load #17 verified — S8-08 GDD landed Designed; save-manager Platform epic 8/8 Complete since 2026-04-24; verification step is what determines whether S9-06 creates a new Core epic or ratifies existing impl.
