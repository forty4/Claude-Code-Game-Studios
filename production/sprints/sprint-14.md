# Sprint 14 — 2026-05-09 to 2026-05-12 (3-day window; closure-leaning HYBRID with content-authoring path-to-PASS)

## Sprint Goal

Resolve 7 sprint-13 carry-conditions to enable `/gate-check pre-prod-to-prod` rerun-3 PASS verdict + `production/stage.txt` Pre-Production → Production flip. Headline items: (1) **ADR-0021 "Production world-space rendering responsibility"** ratification, (2) **POLISH-010 disposition** (Option A author proper visuals OR Option C deferral ADR) — HIGH-tier release-blocker since architectural content gap unfilled since sprint-3 surfaced via S13-10 windowed attestation, (3) **S8-15 re-attestation** post-POLISH-010-fix to convert MIXED → clean PASS, (4) sprint-13 retro AI codifications (verification-gap G-30 + AD gate criterion + S13-06 producer §7 promotion call + /code-review ADVISORY classification batch).

## Capacity

- **Total days**: 3.0d (3-day window 2026-05-09 PM late entry → 2026-05-12 close target)
- **Buffer (20%)**: 0.6d reserved for unplanned (e.g., POLISH-010 Option A scope creep mitigation per R1; mid-sprint scope expansion per AI #9)
- **Available**: 2.4d nominal claude-side + ~25 min user-time (S14-03 re-attestation ~10min + S13-06 user concurrence ~5min + final stage.txt flip authorization ~5min if PASS)
- **Projected actual** (closure-tier ÷~3 multiplier per sprint-10..13 trend; carryover-mode):  ~0.7-1.0d actual claude-side

## Carryover Backlog (from Sprint-13)

> **§11 HARD GATE binding rebind triggered**: per sprint-13 retro AI #2 + closure-mode signal evaluation, carryover concentration ≥5 → rebind to closure-leaning. Sprint-14 has 7 effective carryover items, well above threshold. Rebind landed; sprint-14 mode designated CLOSURE-LEANING HYBRID at entry per §11.4 Trigger 4 evaluation below.
>
> **Codified per sprint-9 retro AI #2** (paid via sprint-11 S11-01): Carryover items listed in dedicated section AHEAD of new scope so cumulative carryover-concentration threshold is visible at sprint-plan time. Each item: KEEP / DESCOPE / BUNDLE / CUT disposition.

| Carryover Task | Original Sprint | Times Carried | Disposition | New Estimate / Target Tier |
|---|---|---|---|---|
| **POLISH-010** production main_scene visual rendering blank in windowed mode (HIGH-tier release-blocker; gates Production advancement) | sprint-13 | 1 | KEEP → Must Have S14-02 | ~0.3d nominal (Option A author proper visuals ~1.5-2hr OR Option C deferral ADR ~1hr) |
| **POLISH-009** missing `scenes/battle/mvp_chapter_01.tscn` (likely contributing cause of POLISH-010) | sprint-13 | 1 | BUNDLE → S14-02 | Bundled with POLISH-010 fix (single .tres + .tscn pair likely resolves both) |
| **ADR-0021** "Production world-space rendering responsibility" ratification (HIGH-tier gate blocker per gate-check rerun-2 Item 6) | sprint-13 | 1 | KEEP → Must Have S14-01 | ~0.2d nominal (1-2hr scoped ADR doc) |
| **S8-15 re-attestation** §1.2/1.3/3.2 post-POLISH-010-fix (MEDIUM; converts MIXED → clean PASS; gate-check rerun-2 Item 7) | sprint-13 (S13-10 MIXED) | 1 | KEEP → Must Have S14-03 | 0d claude-side (user time ~10 min) |
| **S13-06** producer §7 promotion call — Route a vs Route c retention (sprint-12 retro AI #4) | sprint-12 → sprint-13 → sprint-14 | **2** | KEEP (user override rationale: blocked by user concurrence not by claude work; small ~10min once unblocked) | ~0.1d nominal (claude paper) + ~5 min user concurrence |
| **Verification gap pattern codification** at `.claude/rules/godot-4x-gotchas.md` G-30 candidate (sprint-13 retro AI #6; pattern stable at 2 invocations POLISH-008 + POLISH-010) | sprint-13 | 1 | KEEP → Should Have S14-06 | ~0.1d nominal (~30 min) |
| **AD gate criterion addition** — "world-space visual presence" as future pre-prod-to-prod / prod-to-polish gate criterion (sprint-13 retro AI #7) | sprint-13 | 1 | KEEP → Should Have S14-07 | ~0.05d nominal (~15 min documentation) |

**2-carryover-visibility-threshold rule note**: S13-06 has Times Carried = 2. Per sprint-9 retro AI #2 rule, items at ≥2 require non-KEEP disposition unless explicit override. **User override rationale**: S13-06 is blocked by user concurrence on Route a vs Route c, not by claude work; the 2-carry pattern reflects user-gated pacing rather than scope creep. Scope is small (~10 min claude paper + user decision) and unblocks the §7 promotion question once user is available. KEEP disposition stands.

**Note on S13-01 (sprint-13 §11 HARD GATE pre-flight)**: not a sprint-14 carryover — was DONE in-sprint at sprint-13 entry per `cca3eda`. Listed here for traceability only.

## Tasks

### Must Have (Critical Path — gate-check rerun-3 PASS verdict prerequisites)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|--------------------|
| S14-01 | **ADR-0021 "Production world-space rendering responsibility" ratification** — defines contract between battle_scene container, MapGrid, authored chapter scenes, and any sprite/TileMap layers. Status: Accepted. Per gate-check rerun-2 Item 6 (TD-led). | claude (technical-director) | 0.2 (1-2hr scoped doc) | None — sprint-14 entry obligation; references existing ADR-0014/0016 | (1) `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md` exists with status Accepted; (2) Decision section defines responsible Node + visual-asset path + fallback-when-no-authored-scene contract; (3) Engine Compatibility + GDD Requirements Addressed sections present; (4) Cross-references ADR-0014 §3 BattleUnit field-extension precedent + ADR-0016 §3 mount sequence |
| S14-02 | **POLISH-010 disposition: Option A author proper visuals** (PREFERRED per CD + AD) OR fallback to Option C deferral ADR — author `assets/data/maps/mvp_chapter_01.tres` (canonical MapResource path per ADR-0016 §4) + `scenes/battle/mvp_chapter_01.tscn` with sprite/TileMap layer applying art-bible ink-wash palette + tile color language + unit silhouette specs. Eliminates POLISH-009 ERROR + POLISH-010 release-blocker simultaneously (single fix path). | claude (godot-gdscript-specialist + technical-artist) | 0.3 (1.5-2hr Option A; 1hr Option C fallback) | S14-01 (ADR-0021 defines contract this implements) | (1) Option A path: `mvp_chapter_01.tres` + `mvp_chapter_01.tscn` exist with art-bible-aligned visuals; battle_scene loads them without ERROR at headless boot; windowed boot renders non-blank world-space (verified via screenshot evidence at `production/qa/evidence/sprint-14-polish-010-evidence.md`); existing 1288/1288 PASS preserved. (2) Option C fallback path (if Option A blocks at >0.5d): document deferral rationale with hard checkpoint date; ADR amendment to ADR-0021 acknowledging Production stage advances under documented risk. (3) ERROR `Cannot open file 'res://scenes/battle/mvp_chapter_01.tscn'` 0 occurrences in headless boot stderr |
| S14-03 | **S8-15 §1.2/1.3/3.2 re-attestation** post-POLISH-010-fix — user re-runs Batches 1+3 against post-S14-02 build; converts MIXED outcome → clean PASS at `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 USER-OWNED Attestation. Per gate-check rerun-2 Item 7 (CD-led). | user | 0 (user time ~10 min) | S14-02 (POLISH-010 fix shipped) | (1) Batch 1.2 (initial scene loads / battle visuals render) verdict updated PASS (was FAIL); (2) Batch 1.3 (input responsive) verdict updated PASS (was BLOCKED-BY-1.2); (3) Batch 3.2 (no frame drops) verdict updated PASS (was BLOCKED-BY-1.2); (4) qa-signoff-sprint-8 §S8-15 §Verdict line updated MIXED → clean PASS |
| S14-04 | **/gate-check pre-prod-to-prod rerun-3** — re-evaluate after S14-01/02/03 land. Verdict eligibility: PASS (writes `production/stage.txt` = `Production`) OR CONCERNS (re-evaluate path-to-PASS). Sprint-11 retro AI #1 follow-through closure (continued from S13-03). | claude | 0.1 (closure ÷3 → ~0.03d actual; 4-director panel parallel) | S14-01 + S14-02 + S14-03 land | (1) New gate-check artifact at `production/gate-checks/pre-prod-to-prod-2026-05-1?-rerun-3.md`; (2) verdict + path-to-PASS documented; (3) `production/stage.txt` written `Production` if PASS; (4) sprint-13 retro AI #5 (S8-15 re-attest) recorded as resolved if S14-03 PASS |

**Must-have subtotal: 0.6d nominal → ~0.2d actual projected** (closure-tier ÷~3) + ~10 min user time

### Should Have

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|--------------------|
| S14-05 | **S13-06 producer §7 promotion call** — sprint-12 retro AI #4 carry; threshold ≥3 artifacts AND ≥2 distinct sprints HAS FIRED (4 artifacts across sprint-10 + sprint-12). Producer call: keep as Route c standalone OR promote to Route a sibling skill `/process-decision`. Document outcome at `production/decisions/decisions-convention-promotion-evaluation-2026-05-1?.md`. | producer (consults user) | 0.1 nominal (~10min claude paper) + user concurrence ~5min | sprint-12 retro AI #4 + `docs/process/decisions-convention.md` §7 trigger | (1) Decision recorded; (2) if Route a chosen, `/process-decision` skill scaffolded (deferred to next sprint per scope discipline); (3) if Route c retained, decision rationale documented; (4) sprint-12 retro AI #4 closes |
| S14-06 | **Verification gap pattern codification** — sprint-13 retro AI #6. Add G-30 entry to `.claude/rules/godot-4x-gotchas.md`: "Headless tests gate logic + HUD chrome but not world-space visual presence" — pattern stable at 2 invocations (POLISH-008 + POLISH-010). Closes structural verification-gap detection. | claude | 0.1 nominal (~30 min; closure-tier doc edit) | sprint-13 retro AI #6 + existing G-1..G-29 entries | (1) G-30 entry follows Context → Broken → Correct → Discovered structure; (2) cross-references POLISH-008 + POLISH-010 surfacings; (3) discovery story trace links sprint-13 close ceremony |
| S14-07 | **AD gate criterion addition** — sprint-13 retro AI #7. Codify "world-space visual presence" as a future pre-prod-to-prod / prod-to-polish gate criterion: AD attests production main_scene renders non-blank world-space in windowed mode, confirmed by screenshot evidence at `production/qa/evidence/`. Add to `.claude/skills/gate-check/SKILL.md` §3 Director Panel Assessment — AD gate items. | claude (or art-director consult) | 0.05 nominal (~15 min; doc edit) | sprint-13 retro AI #7 | (1) `.claude/skills/gate-check/SKILL.md` updated with AD gate criterion line; (2) sprint-14+ /gate-check invocations include this check by default; (3) AD assessment template gains "world-space visual presence" line item |
| S14-08 | **/code-review ADVISORY items batch classification** — sprint-13 retro AI #10. 10 ADVISORY items from S13-11 + S13-12 reviews need split: tech-debt-register vs documentation polish. Items: S13-11 W#6 + W#8 + W#10 + I#1 + I#7; S13-12 W-3 + I-1 + I-4 + AC-1 sentinel + 5 edge cases. | claude (lead-programmer or qa-tester) | 0.1 nominal (~30 min; classification + register update if any) | sprint-13 retro AI #10 + S13-11 /code-review report + S13-12 /code-review report | (1) Each of 10 ADVISORY items classified: tech-debt-register entry OR documentation-polish OR no-action; (2) `docs/tech-debt-register.md` updated with NEW entries (likely AC-1 sentinel candidate from qa-tester finding); (3) sprint-15+ retro AI to track resolution at next /code-review trigger |

**Should-have subtotal: 0.35d nominal → ~0.12d actual projected** + ~5 min user concurrence

### Nice to Have / Tracking-only

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|--------------------|
| S14-09 | **Mid-sprint mode redesignation precedent tracking** — sprint-13 retro AI #9. Pattern stable at 1 invocation; track at sprint-14+ retro for ≥2-invocation codification trigger. | producer | 0d (tracking-only this sprint unless mid-sprint trigger fires) | sprint-13 retro AI #9 | No new artifact; row exists to track for sprint-14+ if mid-sprint mode redesignation event fires |

**Nice-to-have subtotal: 0d nominal** (tracking-only)

## Cuts (per sprint-14 plan + sprint-13 retro AI evaluation)

| Story | Reason for Cut |
|---|---|
| ~~POLISH-007 (GameBus soft cap exceeded headless)~~ | Pre-existing ADVISORY tier (sprint-13 mid-amendment defer); no forcing function fired this sprint; remains in `production/polish-backlog.md` POLISH-007 entry; closure-trigger is Polish-stage entry OR real-play F5 surfacing |
| ~~POLISH-008 (ObjectDB instances leaked at exit)~~ | Pre-existing ADVISORY tier (sprint-13 mid-amendment defer); no memory-pressure forcing function; remains in `production/polish-backlog.md` POLISH-008 entry |
| ~~Greenfield scope (e.g., new epic flesh-out)~~ | Sprint-14 carryover-concentration ≥5 triggered §11 HARD GATE binding rebind to closure-leaning per AI #2; greenfield scope DEFERRED to sprint-15+ until carryover backlog stabilizes |
| ~~Polish-tier sprint-14 trigger~~ | Sprint-14 is not yet at Polish phase entry (gate-check rerun-3 PASS verdict required first); POLISH-001..006 + POLISH-007/008 carry-forwards remain in polish-backlog |

## Sprint Mode (S14 second live application of closure-mode HYBRID signal evaluation)

> **Companion edit deferred at S12-07 / S13-07** — sprint-14 SHOULD attempt the deferred companion edit to `.claude/skills/sprint-plan/SKILL.md` Phase 2 template per S12-07 deferred. Tracking via S13-09 mid-sprint mode redesignation precedent (no-op this sprint unless trigger fires).

**Sprint-14 closure-mode signal count**:

| Signal | Description | Sprint-14 satisfies? | Evidence |
|---|---|---|---|
| **A** Primary mode = closure-absorption | Plan dominated by carryover absorption + retro AI execution | ⚠️ **MIXED** (7 carryover + 1 nominal-greenfield-mode redesignation tracking; closure dominates but POLISH-010 fix is content-authoring tier) | 0 greenfield rows; 4 Must Have all carry from sprint-13; 4 Should Have all carry from sprint-13 |
| **B** Carryover concentration ≥4 | At sprint entry | ✅ YES — **7 items at threshold** (well above ≥4 visibility breach + above ≥5 §11 HARD GATE binding rebind trigger) | Carryover Backlog table ≥7 entries |
| **C** Zero new architectural risk | No new ADR required this sprint | ⚠️ **MIXED** — S14-01 IS new ADR-0021 ratification; small architectural risk (1-2hr scoped doc; references existing ADR-0014/0016) | S14-01 ratifies one new ADR; minor amendment per Evolution Rule scope |
| **D** Test count delta dominated by closure follow-on | ≥80% of expected test additions from closure work | ⚠️ **MIXED** — S14-02 Option A POLISH-010 fix may need visual-smoke CI test (NEW test infrastructure work; ~1-2 tests); S14-06 verification gap codification = 0 test additions | Test additions limited; visual-smoke harness scope potentially crosses closure boundary |
| **E** Single-session execution feasibility | Claude-side projected ≤1 calendar day | ✅ YES — projected ~0.7-1.0d actual claude-side (well within 3.0d window) | Closure-tier ÷~3 multiplier baseline; sprint-10..13 trend |

**Signal count: 2 of 5 (B/E) fully YES; 3 of 5 (A/C/D) MIXED — at floor of HYBRID threshold per §11.4 Trigger 4. Sprint-14 mode = MIXED HYBRID.**

This is the **2nd consecutive sprint at MIXED HYBRID** (sprint-13 close was MIXED HYBRID after mid-sprint redesignation). Pattern indicating repeat of mode classification — may suggest §11.4 signal evaluation needs refinement at sprint-15+ retro if pattern stabilizes (sprint-13 retro AI #9 tracks frequency).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **R1** — S14-02 Option A scope creep (authored .tscn requires iterative tweaking; sprite/TileMap setup unfamiliar territory) | Medium | Medium | Time-box S14-02 to 0.5d max; if approaching limit fall back to Option C deferral ADR (1hr scoped doc; documented risk acceptance). Both paths satisfy gate-check rerun-3 Item 5; Option C is acceptable per CD verdict ("Option C deferral ADR tolerated") |
| **R2** — S14-01 ADR-0021 surfaces design conflicts with ADR-0014 / ADR-0016 (rendering responsibility unassigned across them; ratification may require existing ADR amendments) | Low-Medium | Low | Read existing ADRs first to ensure consistency; spawn godot-specialist for cross-ADR conflict review if surfaced; treat amendments as SCOPE-CREEP requiring user concurrence |
| **R3** — /gate-check rerun-3 verdict CONCERNS persisting (one or more directors NOT READY despite POLISH-010 close) | Low | Medium | Track 4-director feedback at S14-04; if any NOT READY, plan sprint-15 path-to-PASS; sprint-13 retro AI #2 protocol applies (carryover concentration audit at sprint-15 plan-time) |
| **R4** — Mid-sprint mode redesignation event fires (sprint-13 precedent) — unexpected forcing function | Low | Low | Producer call mid-sprint; redesignate mode if signals shift; track AI #9 frequency at sprint-14 retro |
| **R5** — S8-15 re-attestation FAILs again (POLISH-010 fix incomplete) | Low | Medium | Test windowed boot before requesting user re-attest; visual evidence screenshot at `production/qa/evidence/sprint-14-polish-010-evidence.md`; if FAIL, S14-02 reopens for round 2 |
| **R6** — POLISH-010 Option A introduces test regressions (new visual layer breaks existing 1288 tests) | Low | Medium | Pre-flight grep for tests touching battle_scene visual hierarchy; ensure additions don't break BattleScene scene-tree assumptions; full-suite run after S14-02 ship |
| **R7** — User concurrence on S13-06 Route a vs Route c slips (3rd-time carry to sprint-15) | Medium | Low | If slip detected by Day 2, escalate explicitly; below §11 HARD GATE threshold (S13-06 is small admin item not USER-OWNED CRITICAL); accept Route c-stay as default if user unavailable through sprint-14 close |

## Dependencies on External Factors

- **User attestation gate S14-03**: blocks S14-04 gate-check rerun-3 verdict-PASS path; user time ~10 min required mid-sprint
- **User concurrence on S13-06**: blocks S14-05 close; user time ~5 min
- **User authorization for stage.txt flip** (if S14-04 returns PASS): user concurrence required before claude writes `production/stage.txt = Production`

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S14-01/02/03/04) completed
- [ ] All tasks pass acceptance criteria (per Tasks table)
- [ ] **Gate-check rerun-3 verdict PASS** — `production/stage.txt` Pre-Production → Production flip executed (or clean rationale if CONCERNS persists)
- [ ] QA plan exists (`production/qa/qa-plan-sprint-14-[date].md`) — see Phase 5 gate of /sprint-plan
- [ ] All Logic stories (S14-02 if it generates tests) have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`) — file naming per S11-10 codified convention `production/qa/smoke-sprint-14-[date].md`
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint-14`) — file naming convention `production/qa/qa-signoff-sprint-14-[date].md`
- [ ] No S1 or S2 bugs in delivered features
- [ ] Sprint-13 retro AI carryover items resolved or carry-forward documented (AI #2/3/4/5/6/7/8/10 each have explicit resolution status)
- [ ] §11 HARD GATE binding rebind to closure-leaning honored throughout sprint (no greenfield scope additions without explicit user concurrence)

## Sprint-14 retro AI seeds (10 active; carry from sprint-13)

| AI # | Description | Status |
|---|---|---|
| #1 | Codification debt MUST be paid at retro time (sustained sprint-7→8→9→10→11→12→13→14) | Active — sustained pattern |
| #2 | Carryover concentration ≥5 → §11 HARD GATE binding rebind triggered THIS sprint; validate post-S14 carryover concentration drops below threshold | Active — recurring metric |
| #3 | POLISH-010 disposition outcome (Option A author or Option C deferral ADR) — first project release-blocker resolved via sprint-14 dedicated work | Active — first instance |
| #4 | ADR-0021 ratification outcome — first project ADR ratified at sprint entry as gate-check carry-condition | Active — first instance |
| #5 | S8-15 re-attestation outcome (MIXED → PASS path) — first project re-attestation cycle | Active — first instance |
| #6 | Verification gap pattern codification (G-30) outcome — pattern stable at 2 invocations enables codification per AI #1 sustained pattern | Active |
| #7 | AD gate criterion addition outcome — `.claude/skills/gate-check/SKILL.md` modification | Active |
| #8 | S13-06 producer §7 promotion outcome (Route a vs Route c retention decision) — 2nd-time carry; user concurrence pending | Active |
| #9 | Mid-sprint mode redesignation precedent — frequency tracking; codification trigger at ≥2 invocations | Active — tracking |
| #10 | /code-review ADVISORY items batch classification outcome (10 items split tech-debt-register vs polish) — sprint-13 batch | Active |

## Working tree state at sprint-14 entry

- **Origin/main**: `ef025a6` (sprint-13 close batch pushed)
- **Local working tree**: clean (only gitignored `.claude/agent-memory/qa-lead/` + `.claude/scheduled_tasks.lock` untracked)
- **Tests**: 1288/1288 PASS; 132/132 suites; **66th consecutive failure-free baseline** (preserved through sprint-13 close ceremony)
- **CI lints**: 73+ in `tools/ci/` (sprint-14 may add 1 if visual-smoke harness or G-30-companion lint emerges)
- **Sprint-13 close artifacts on origin**: 5 (smoke + qa-plan-closure + qa-signoff + retro + sprint-status-history.md archive)
- **Sprint-status.yaml**: ready for sprint-14 update
- **Polish-backlog**: 10 Open entries (POLISH-001..010); sprint-14 closes POLISH-009 + POLISH-010 if Option A succeeds
- **Production decisions/**: 4 artifacts across sprint-10 + sprint-12; sprint-14 may add 1 (S13-06 outcome OR S14-02 Option C deferral)
- **Decisions-convention.md**: 315+ LoC (§11 USER-OWNED 5th-carry HARD GATE rule active; first live binding closed at S13-02 SUCCESS; second invocation pattern: §11 binding rebind at sprint-14 entry per AI #2)

## Sprint-14 close ceremony preview (sprint-14 close target ~2026-05-12)

When S14-01..S14-04 reach Done state:

1. `/smoke-check sprint` → `production/qa/smoke-sprint-14-[date].md`
2. `/qa-plan sprint-14-closure` → closure addendum (similar to sprint-13 pattern)
3. `/team-qa sprint-14 attestation-mode` → `production/qa/qa-signoff-sprint-14-[date].md` — verdict APPROVED or APPROVED WITH CONDITIONS
4. `/retrospective sprint-14` → `production/retrospectives/retro-sprint-14-[date].md` (must address 10 sprint-14 retro AIs)
5. **If gate-check rerun-3 PASS**: `production/stage.txt` Pre-Production → Production flip — first stage advancement since 2026-04-20 entry
6. Sprint-14 close commit + push
7. `production/sprint-status-history.md` Sprint 14 section archive
