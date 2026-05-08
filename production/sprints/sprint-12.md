# Sprint 12 — 2026-05-09 to 2026-05-11 (3-day window)

> **Generated**: 2026-05-08 (post-sprint-11 close commit `e70ecba`; immediately following gate-check `production/gate-checks/pre-prod-to-prod-2026-05-08.md` CONCERNS verdict)
> **Mode**: lean (`production/review-mode.txt` = `lean`)
> **Velocity model** (validated sprint-9 + sprint-10 + sprint-11 retro AI #4): closure ÷3, greenfield ÷5, admin ÷3 — sprint-12 mixed-mode (greenfield demo + closure cleanup) projects ~0.8-1.0 calendar day actual from ~2.8-3.8d nominal

## Sprint Goal

Close the gate-check 2026-05-08 CONCERNS verdict by shipping ≥1 player-facing Pillar 3 OR Pillar 4 demonstration (gate-check path-to-PASS item 3) + execute sprint-11 retro AIs (Save/Load story flesh-out + lint drift bulk cleanup + TODO triage Address actions + USER-OWNED 5th-time threshold codification) + collect S7-11 + S8-15 user attestations to potentially flip `production/stage.txt` Pre-Production → Production at sprint-12 close `/gate-check` re-run.

## Capacity

- Total days: 3
- Buffer (20%): 0.6d reserved
- Available: 2.4d nominal
- Projected actual via mixed-mode multiplier: ~0.8-1.0 calendar day (1 greenfield demo × ÷5 + 4 closure cleanups × ÷3 + 2 admin × ÷3 + 2 USER-OWNED parallel)

## Carryover Backlog (from Previous Sprint)

> **Codified per sprint-9 retro AI #2** (sustained sprint-10 + sprint-11; threshold ≥4 = visibility breach). Sprint-12 entry carryover concentration is **2 USER-OWNED only** — well below threshold; refusal-to-fabricate posture preserved.

| Carryover Task | Original Sprint | Times Carried | Disposition | New Estimate / Target Tier |
|----------------|-----------------|---------------|-------------|---------------------------|
| **S11-12** S7-11 user attestation pass on 4 VS Validation items | sprint-7 (S7-11) → sprint-8 → sprint-9 → sprint-10 (S10-13) → sprint-11 (S11-12) | **5** (project-record; threshold codification candidate per sprint-11 retro AI #7) | KEEP USER-OWNED | S12-10 USER-OWNED Nice-to-Have (0d claude-side; refusal-to-fabricate posture; threshold codification at S12-06) |
| **S11-13** S8-15 user attestation pass on sprint-8 manual smoke check Batches 1+3 | sprint-8 (S8-15) → sprint-10 (S10-14) → sprint-11 (S11-13) | **3** | KEEP USER-OWNED | S12-11 USER-OWNED Nice-to-Have (0d claude-side; same posture) |

**Disposition rationale**: USER-OWNED items cannot be claude-cut; carryover continues until user attests OR until S12-06 codifies a 5th-time threshold rule (e.g., explicit "deferred-to-Production-readiness-review" status, async batching, or producer-escalated workflow redesign per gate-check 2026-05-08 CD recommendation).

## Tasks

### Must Have (Critical Path) — gate-check path-to-PASS items + sprint-11 retro AI #2 follow-on

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S12-01 | **`/create-stories save-load`** — flesh out the 3-story decomposition from `production/epics/save-load/EPIC.md` (S11-07 follow-on per sprint-11 retro AI #2) into ready-for-`/dev-story` story files. Story-001 ScenarioRunner CP-1/2/3 emission contract + Story-002 Cross-chapter continuity Destiny State populator + `save_loaded` GameBus signal addition + Story-003 Failure surfacing tests + 3 enforcement lints + systems-index row 17 flip | claude (or systems-designer) | 0.3 | sprint-11 S11-07 EPIC.md (Complete) | 3 story files at `production/epics/save-load/story-001-*.md` + `story-002-*.md` + `story-003-*.md` per /create-stories convention; each story ready for /story-readiness |
| S12-02 | **NEW Pillar 3 OR Pillar 4 player-facing demonstration** — close gate-check 2026-05-08 path-to-PASS item 3 (CD-refined). Recommended Option A: ship Pillar 4 atmospheric moment (운명 분기 reserved-color treatment + audio cue) for ONE branch resolution in `prototypes/chapter-prototype/` using existing destiny-branch (1/1 Complete) + battle-hud + 1 new audio asset OR synthesized cue. Alternative Option B: Pillar 3 narrative beat triggered by hero death in chapter-1 scenario; requires Story Event #10 stub OR BeatCue schema landing. Decision at story-readiness time | claude (or game-designer + writer + sound-designer) | 1.0 (greenfield ÷5 → ~0.2d actual; option-A recommended for lower variance) | destiny-branch epic (Complete) + battle-hud epic (Complete) + chapter-prototype (Complete) + (Option B only) Story Event #10 GDD | Pillar 3/4 demo shipped to player-facing surface; integration test exercises the demo path; CD verdict at next gate-check upgrades from CONCERNS → READY-on-pillar-demonstration |
| S12-03 | **`/gate-check pre-prod-to-prod` re-run** at sprint-12 close — sprint-11 retro AI #1 follow-through. Runs after S12-02 demo ships AND after user attests S12-10 + S12-11 (if attested). Verdict eligibility: PASS (writes `production/stage.txt` = `Production`) OR CONCERNS (re-evaluate path-to-PASS) | claude | 0.1 (closure ÷3 → ~0.03d actual) | S12-02 demo ship + S12-10 + S12-11 attestations (best case) | New gate-check artifact at `production/gate-checks/pre-prod-to-prod-2026-05-1?.md`; verdict + path-to-PASS documented; `production/stage.txt` written if PASS |

**Must-have subtotal: 1.4d nominal → ~0.4d actual projected** (1 greenfield × ÷5 + 2 closure × ÷3)

### Should Have — sprint-11 retro AI #3 + #4 + #7 follow-throughs

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S12-04 | **`lint_story_status_consistency` 33-drift bulk cleanup** — sprint-11 retro AI #3 (sprint-11 S11-03 surfacing). Single coordinated pass propagating Status flips through 33 surfaced items (21 index.md row Ready + 12 EPIC.md header Ready when all stories Complete). Re-run lint to verify Exit 0 post-cleanup. CI wiring (per S11-03 deferred condition) lands same-patch | claude | 0.5 (closure ÷3 → ~0.17d actual; mostly mechanical edits) | sprint-11 S11-03 lint script | 33 → 0 drift items; lint Exit 0; lint wired to `.github/workflows/tests.yml` per S11-03 deferred condition; sprint-12 retro acknowledges baseline-clean state |
| S12-05 | **TODO triage Address actions** — bundleable into ~30-min commit per sprint-11 S11-11 §Sprint-12 Action Items. TODO-02 (`save_manager.gd:200` doc cleanup) + TODO-04 (`get_battle_state_snapshot()` removal Option A) + TODO-05 (`grid_battle_controller.gd:424` stale TODO line removal) + TODO-03 (reformat with story-anchor) + TODO-01 disposition (keep inline OR migrate to POLISH-006 producer call). Post-cleanup TODO count: 5 → 2 (below AI #6 ≥5-stalled threshold) | claude | 0.2 (closure ÷3 → ~0.07d actual) | sprint-11 S11-11 triage doc | TODO count drops 5 → 2; remaining 2 are documented Defer-with-context items (map_grid Dijkstra heuristic + beat_cue Story Event GDD #10 stub); src/ TODO grep verifies |
| S12-06 | **USER-OWNED 5th-time threshold codification** — sprint-11 retro AI #7 (S11-12 hits 5th-time at sprint-12 entry; producer-recommended workflow review per gate-check 2026-05-08 CD finding). Codify rule: e.g., "after 5 carries, USER-OWNED item must be either user-attested in next session OR formally cancelled via /architecture-decision retro OR re-classified as 'deferred-to-Production-readiness-review' with explicit reactivation trigger." Document at `docs/process/user-owned-carryover-threshold.md` OR extend existing `docs/process/decisions-convention.md` with USER-OWNED-specific clause | claude (consults producer + user for posture decision) | 0.2 (closure ÷3 → ~0.07d actual; process doc) | sprint-11 retro AI #7 + gate-check 2026-05-08 CD recommendation | Process doc shipped at agreed location; rule explicitly handles S7-11 (now 5th-time) + S8-15 (3rd-time); refusal-to-fabricate posture preserved; producer + user concurrence captured |

**Should-have subtotal: 0.9d nominal → ~0.3d actual projected** (3 closure × ÷3)

### Nice to Have — sprint-11 retro AI #5 + #6 + AD-flagged conditional + USER-OWNED carryover

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S12-07 | **Closure-mode sprint planning evaluation** — sprint-11 retro AI #6 (producer call). Sprint-11 first-precedent of explicitly-planned closure-mode sprint over-performed at -77% vs nominal. Decision: should closure-mode sprints be planned more often (e.g., every 3rd sprint as debt-pay sprint), or remain reserved for carryover-absorption stopgap? Document decision at `production/decisions/closure-mode-sprint-pattern-2026-05-1?.md` per S11-05 convention | claude (or producer) | 0.1 | sprint-11 retro AI #6 | Decision recorded per `docs/process/decisions-convention.md` template (10 sections + reactivation triggers + amendment log); 1 of (a) embraced-as-pattern / (b) reserved-as-stopgap / (c) hybrid-policy outcomes documented |
| S12-08 | **POLISH-006 Guan Yu + Zhang Fei character profile stubs** — *conditional* on AD-flagged ADVISORY-candidate from gate-check 2026-05-08 (fires ONLY IF character-art sprint enters sprint-12+ planning). If no character-art sprint scheduled, this is added to `production/polish-backlog.md` as POLISH-006 entry (Guan Yu + Zhang Fei pre-art-commission stubs); if sprint-12 doesn't include character-art, this row is closed by polish-backlog ledger entry only (0d claude-time) | art-director (or claude) | 0.2 conditional / 0d if unscheduled | gate-check 2026-05-08 AD ADVISORY-candidate | Either polish-backlog.md POLISH-006 entry written (0d outcome) OR Guan Yu + Zhang Fei stubs authored at `design/art/characters/guan-yu.md` + `design/art/characters/zhang-fei.md` (0.2d outcome if character-art sprint triggers) |
| S12-09 | **`tools/ci/lint_sprint_carryover_count.sh`** — sprint-11 retro AI #5 *optional*. Lint asserts "sprint N's pre-sprint carryover count − sprint-N-end carryover-out count = absorbed count" matches retro metrics. Only ship if AI #2 threshold continues to be load-bearing watcher metric | claude | 0.2 (optional) | sprint-11 retro AI #2 + #5 | Lint script at `tools/ci/lint_sprint_carryover_count.sh` Exit 0 on current sprint-11 → sprint-12 carryover (2 USER-OWNED, well below threshold); CI wiring per S12-04 pattern |

**Nice-to-have subtotal (claude-owned): 0.5d nominal → ~0.2d actual projected**

### USER-OWNED — refusal-to-fabricate carryover

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S12-10 | **S7-11 user attestation pass** on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` — **5th-time carryover** (project-record; threshold breach per S12-06 codification). User boots `chapter.tscn` (or `vertical-slice/battle.tscn`), executes core loop, records attestation per item: PASS / FAIL with notes | user | 0 (user time ~30 min) | prototypes/chapter-prototype/ + prototypes/vertical-slice/ | 4 attestations recorded in REPORT.md; sprint-12 retro re-evaluates posture |
| S12-11 | **S8-15 user attestation pass** on sprint-8 manual smoke check Batches 1+3 — 3rd-time carryover. User executes documented batches in `production/qa/qa-signoff-sprint-8-2026-05-06.md` Batches 1+3 sections, records PASS / FAIL per item | user | 0 (user time ~15 min) | production/qa/qa-signoff-sprint-8-2026-05-06.md | Batches 1+3 attestations recorded; verdict potentially upgrades from APPROVED WITH CONDITIONS → APPROVED |

## Cuts (per sprint-12 plan + sprint-11 retro AI #5 evaluation)

| Story | Reason for Cut |
|---|---|
| ~~Carryover absorption AI #2 verification automation~~ → **DESCOPED to S12-09 Nice-to-Have (optional)** | Per sprint-11 retro AI #5: "Optional; sprint-13+ if AI #2 still binding." Sprint-12 entry carryover is 2 USER-OWNED — well below threshold; lint adds little marginal value at current state |
| ~~Pause-menu UX spec~~ (AD-C6 open side) | Not in sprint-12 scope per sprint-11 S11-08 disposition (separate sprint task; no immediate forcing function); remains AD ADVISORY for menu-implementation sprint |

## Carryover from Previous Sprint (sprint-11 → sprint-12)

(Already enumerated in §Carryover Backlog above. 2 USER-OWNED only; AI #2 threshold not breached.)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **R1 — Pillar 3/4 demo (S12-02) under-scopes**: 1d greenfield estimate may not capture full integration cost (audio asset sourcing + reserved-color test + chapter-prototype regression) | Medium | Medium | Time-box S12-02 to 1.0d; if Option A (Pillar 4 atmospheric moment) over-scopes, descope to a smaller atmospheric beat (e.g., single visual treatment without audio) that still satisfies CD-refined "≥1 player-facing demo." Sprint-12 retro evaluates if descope was correct |
| **R2 — Save/Load /create-stories (S12-01) story-readiness verdicts may surface gaps** in EPIC.md decomposition | Low-Medium | Low | Sprint-11 S11-07 EPIC.md was authored with 13 TR-IDs explicit + 3-story decomp tested against GDD §Implementation hooks; gaps unlikely. If found, run `/architecture-decision` for amendments same-patch |
| **R3 — `lint_story_status_consistency` 33-drift cleanup (S12-04) reveals deeper drift** in EPIC.md / index.md cross-references not surfaced by S11-03 lint design | Low | Low | S12-04 ships in single coordinated commit; if extra drift surfaces during cleanup, defer-overflow to sprint-13 candidate; document new drift class as sprint-12 retro AI seed |
| **R4 — USER-OWNED 5th-time threshold codification (S12-06)** decision may face user pushback (e.g., "no threshold rule needed; status quo OK") | Low | Medium | Surface 3 candidate options to user before authoring; default to "no rule yet; revisit at 7th-time" if user prefers. Process doc is reversible |
| **R5 — Sprint-12 close gate-check (S12-03) may STILL return CONCERNS** if S12-02 demo lands but S12-10 + S12-11 attestations don't | Medium | Low | This is acceptable; CD-refined verdict will downgrade from "Pillar 3+4 + USER-OWNED" CONCERNS to "USER-OWNED only" CONCERNS — strictly less concerning. Sprint-13 absorbs remaining USER-OWNED gates |
| **R6 — POLISH-006 trigger (S12-08) may fire mid-sprint** if a character-art sprint is unexpectedly added to sprint-12+ planning, requiring Guan Yu + Zhang Fei stubs | Low | Low | Default to polish-backlog ledger entry (0d outcome); upgrade to stub authoring only if explicit forcing function appears in sprint-12 |
| **R7 — Mixed-mode velocity multiplier may miscalibrate** for sprint-12's 1-greenfield-+-many-closure mix vs sprint-11's pure-closure baseline | Low | Low | Sprint-11 retro AI #4 already noted closure-only ÷~4.4 vs ÷3 baseline; sprint-12 mixed mode reverts to ÷3 closure / ÷5 greenfield blend; expected within ±20% projection |

## Dependencies on External Factors

- **User attestation gates S12-10 + S12-11**: refusal-to-fabricate posture means claude cannot proceed on these without explicit user action; S12-06 codification will explicitly handle the 5th-time threshold (S12-10) per CD recommendation
- **S12-02 Option A (Pillar 4 audio cue)**: may need user-provided audio asset OR sound-designer subagent invocation if synthesized cue is insufficient. Defer audio-asset sourcing decision to S12-02 story-readiness time
- **S12-03 gate-check verdict at sprint-12 close**: depends on S12-02 demo + S12-10 + S12-11 user attestations; PASS verdict path requires all three; CONCERNS verdict path is acceptable fallback

## Sprint-12 Retro AI seed (carry from sprint-11 retro)

- **AI #1** (sustained sprint-7→8→9→10→11→12): Codification debt MUST be paid at retro time
- **AI #2** (sustained sprint-9→10→11→12): Carryover concentration threshold ≥4 — sprint-12 entry has only 2 USER-OWNED; validate post-S12 absorption
- **AI #3** (sustained sprint-9→10→11→12; pattern stable at 4 invocations as of sprint-11 S11-02): Story-spec doc-correction at /story-readiness time — sprint-12 may not invoke if no new BACKFILL CLOSE-OUT scenarios surface; validate at retro
- **AI #4** (validated 3rd time sprint-11): Mixed-mode velocity multiplier — sprint-12 reverts from pure-closure to mixed mode; re-validate ±20% projection
- **AI #5 NEW**: Sprint-12 close gate-check evaluation — re-run /gate-check pre-prod-to-prod and verify whether S12-02 demo + S12-10/11 attestations upgrade verdict CONCERNS → PASS (production/stage.txt flip eligible)
- **AI #6 NEW**: Closure-mode sprint pattern decision (S12-07) embraced-as-pattern / reserved-as-stopgap / hybrid — feeds sprint-13 plan authoring
- **AI #7 NEW**: USER-OWNED 5th-time threshold codification (S12-06) live application — does the new rule actually unblock S7-11 / S8-15 OR does it just rename the holding pattern? Validate at sprint-12 retro

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S12-01 + S12-02 + S12-03) completed
- [ ] All tasks pass acceptance criteria (per Tasks table)
- [ ] QA plan exists (`production/qa/qa-plan-sprint-12.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (S12-02 demo will likely be Integration tier; test required)
- [ ] Smoke check passed (`/smoke-check sprint`) — file naming per S11-10 codified convention `production/qa/smoke-sprint-12-[date].md`
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`) — file naming per S11-10 codified convention `production/qa/qa-signoff-sprint-12-[date].md`
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] **Gate-check S12-03 re-run**: verdict documented; `production/stage.txt` written if PASS

---

> **Scope check**: If this sprint includes stories added beyond the original epic scope, run `/scope-check [epic]` to detect scope creep before implementation begins. Sprint-12 S12-02 (Pillar 3/4 demo) is greenfield — verify scope against destiny-branch + battle-hud + chapter-prototype existing acceptance criteria; if a NEW epic is implied, run `/create-epics` instead before story-readiness.

> ⚠️ **No QA Plan**: This sprint plan was authored without a QA plan. Run `/qa-plan sprint-12` before the last story is implemented. The Production → Polish gate (and the sprint-12 close gate-check S12-03) requires a QA sign-off report, which requires a QA plan.
>
> **Recommended order**: (1) commit + push this sprint plan; (2) run `/qa-plan sprint-12` next; (3) run `/story-readiness` on S12-01 candidates → `/dev-story` to begin implementation.
