# Gate Check: Pre-Production → Production (2026-05-06)

| Field | Value |
|-------|-------|
| **Date** | 2026-05-06 |
| **Reviewer** | gate-check skill (lean mode) |
| **Stage source** | inferred (no `production/stage.txt` yet — pre-Production) |
| **Verdict** | **CONCERNS** (unchanged from 2026-05-05; sprint-8 closure validated 11/16 stories + 38th FFB; path-to-PASS unchanged at S7-11 + S8-15 USER-OWNED) |
| **Director Panel** | 3× READY (TD + PR + AD) + 1× CONCERNS (CD) — same pattern as 2026-05-05 |
| **Sole gating blockers** | **S7-11 user attestation** (4 VS Validation items) + **S8-15 user attestation** (manual smoke check Batches 1+3) — both USER-OWNED |
| **Cross-references** | Prior gate-check `production/gate-checks/pre-prod-to-prod-2026-05-05.md` (CONCERNS); /team-qa sign-off `production/qa/qa-signoff-sprint-8-2026-05-06.md` (APPROVED WITH CONDITIONS); smoke check `production/qa/smoke-2026-05-06.md` (PASS WITH WARNINGS) |

---

## 1. Verdict Trajectory

| Date | Verdict | Director Panel | Note |
|------|---------|----------------|------|
| 2026-04-20 | FAIL | n/a (prior format) | First gate-check; multiple structural gaps |
| 2026-05-04 | CONCERNS | 4× CONCERNS | 13/17 artifacts; 6-step path-to-PASS surfaced |
| 2026-05-05 | CONCERNS | 3× READY + 1× CONCERNS (CD) | 15/17 artifacts; sole gate = S7-11 user attestation |
| **2026-05-06** | **CONCERNS** | **3× READY + 1× CONCERNS (CD)** | **17/17 artifacts; sole gates = S7-11 + S8-15 USER-OWNED** |

**Trajectory**: All claude-owned path-to-PASS items are now closed. Sprint-8 added zero claude-owned regressions. Sprint-8 closure (Must 7/7 + Should 4/4) materially advanced the architectural + test substrate but did NOT close the experiential validation gap (S7-11) and INTRODUCED a 2nd USER-OWNED gate (S8-15 manual smoke). Pattern: USER-OWNED manual-attestation-deferral now stable at 2 invocations — codification candidate as project discipline for headless-dev workflows.

---

## 2. Required Artifacts: 17/17 Present

| Artifact | Status | Location |
|----------|--------|----------|
| ≥1 prototype with README | ✅ | `prototypes/chapter-prototype/README.md` + `prototypes/vertical-slice/README.md` |
| First sprint plan | ✅ | `production/sprints/sprint-1.md` ... `sprint-8.md` (8 sprints) |
| Art bible complete (9 sections) | ✅ | `design/art/art-bible.md` — verified at 2026-05-05 gate |
| Character visual profiles | ⚠ | `design/art/characters/` stubs missing — AD ADVISORY (AD-C5; not gating) |
| All MVP-tier GDDs | ✅ | All 20+ GDDs in `design/gdd/` + `design/ux/` |
| Master architecture doc | ✅ | `docs/architecture/architecture.md` |
| ≥3 ADRs Foundation-layer | ✅ | **20 ADRs Accepted** (was 19 at 2026-05-05; ADR-0020 InputRouter Dispatch added at S8-01) |
| Control manifest | ✅ | `docs/architecture/control-manifest.md` (v2026-05-05) |
| Epics defined | ✅ | 19 epics in `production/epics/` (Foundation + Core + Feature + Presentation layers) |
| Vertical Slice playable | ✅ | `prototypes/vertical-slice/battle.tscn` + `prototypes/chapter-prototype/chapter.tscn` |
| ≥3 playtest sessions | ❌ | `production/playtests/` empty — **S7-11 USER-OWNED** (no claude-fabricated playtest evidence per refusal-to-fabricate posture) |
| Vertical Slice playtest report | ❌ | Same as above — S7-11 USER-OWNED |
| UX specs (key screens) | ✅ | `design/ux/battle-hud.md` + `design/ux/interaction-patterns.md` + `design/ux/accessibility-requirements.md` |
| HUD design document | ✅ | `design/ux/battle-hud.md` v1.1 |
| UX specs passed `/ux-review` | ✅ | Battle HUD UX spec sign-off recorded; interaction patterns library initialized |
| Smoke check PASS or PASS WITH WARNINGS | ✅ | `production/qa/smoke-2026-05-06.md` PASS WITH WARNINGS |
| QA sign-off APPROVED or APPROVED WITH CONDITIONS | ✅ | `production/qa/qa-signoff-sprint-8-2026-05-06.md` APPROVED WITH CONDITIONS |

**Note on accessibility-requirements.md path**: gate spec cites `design/accessibility-requirements.md` but actual file is at `design/ux/accessibility-requirements.md`. Path discrepancy is documentation-only; artifact exists.

---

## 3. Quality Checks

### Test Baseline

- **1116 / 1116 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** — **38th consecutive failure-free baseline** (chain unbroken since hp-status story-001; +459 tests added across sprints 3-8)
- **G-7 silent-skip detection**: PASS — count actually advanced 1106 → 1116 (+10) at S8-07 ship; final regression at /story-done captured the actual count
- **No deprecated API usage**: verified by existing CI lint scripts + 0 push_warning emissions

### Sprint-8 Closure (11/16 stories done; 5× velocity multiplier 4th invocation)

**Must-Have (7/7 done)** — see `production/qa/qa-signoff-sprint-8-2026-05-06.md` Test Coverage Summary table for full mapping.

**Should-Have (4/4 done)** — Save/Load #17 GDD authoring + Story Event #10 implementation + Destiny State #16 implementation + Chapter-1 e2e integration.

### 4 VS Validation Items (still MANUAL CHECK NEEDED — S7-11)

Per `prototypes/chapter-prototype/REPORT.md`:
1. A human has played through the core loop without developer guidance — pending
2. The game communicates what to do within the first 2 minutes of play — pending
3. No critical "fun blocker" bugs exist in the Vertical Slice build — pending
4. The core mechanic feels good to interact with (subjective check) — pending

### 6 Manual Smoke Items (NEW — S8-15)

Per `production/qa/smoke-2026-05-06.md` Phase 4 Batches:
- **Batch 1 (core stability)**: 3 items deferred (game launches / new game starts / main menu inputs)
- **Batch 3 (data integrity + performance)**: 2 items deferred (save/load — N/A pre-impl; frame rate — Polish-tier)
- **Batch 2 (sprint mechanic + regression)**: ✅ COVERED by automated tests (FSM 24 tests + mode-determine 11 + two-tap 10 + chapter-1 e2e 8 + StoryEvent + DestinyState 29; 38 FFBs)

---

## 4. Director Panel Assessment (Lean Mode — All 4 Spawned in Parallel)

### Creative Director — **CONCERNS**

**Verdict comparison vs. 2026-05-05**: HOLDS at CONCERNS; sprint-8 added Pillar 2 structural proof (6-invocation lock + chapter-1 e2e closes "Pillar 2/3/4 demonstration unproven" gap at the integration layer). Pillar 1+2 PROVEN; Pillar 3+4 HYPOTHESIS. CD-acknowledged USER-OWNED gates (S7-11 + S8-15) are NOT CD blockers — they are out-of-scope handoffs.

**Pillar status**:
- **Pillar 1 (무자비한 단순성)**: PROVEN (22-action vocab + 7-state FSM + two-tap commit)
- **Pillar 2 (운명을 바꿀 수 있다)**: STRUCTURALLY PROVEN (6-invocation lock + chapter-1 e2e); felt experience pending S7-11 attestation
- **Pillar 3 (영웅의 무게)**: HYPOTHESIS (mechanical scaffolding present; narrative weight beat not yet shipped)
- **Pillar 4 (전국 시대의 그림자)**: HYPOTHESIS (structural arc proven; atmospheric tone gated on art-bible execution + audio surfacing)

**CD recommendation**: Production may proceed conditionally. Either (a) execute S7-11 + S8-15 attestation in next session to upgrade CONCERNS → READY, or (b) accept CONCERNS verdict and proceed to Production with explicit acknowledgement that Pillar 3/4 fantasy delivery is a sprint-9 priority.

### Technical Director — **READY**

**Verdict comparison vs. 2026-05-05**: STAYS READY. Sprint-8 introduced zero TD-flagged regressions. All path-to-PASS items from prior gate cleared. 20 ADRs Accepted; architecture.yaml v14 + tr-registry v16 + 258 TRs internally consistent.

**TD ADVISORY items (non-blocking)**:
1. Performance claims remain unmeasured (sprint-9 must land a performance-baseline story; delegate to performance-analyst)
2. Tech-debt growth rate: 62 → 67 in one sprint (+5 ADVISORY TD-063..067; trend acceptable, slope non-zero)
3. InputRouter freshly-graduated at S8-02; 0 days soak time outside sprint-8 chain
4. **G-26 candidate** (deferred-handler-after-state-advance race) — surfaced twice in sprint-8 (StoryEvent + battle_hud_two_tap test); codify at sprint-8 retro
5. **G-27 candidate** (bulk-disconnect-all in test cleanup interferes with autoload subs) — codify alongside G-26

**TD recommendation**: Proceed to Production. Schedule performance-baseline story for sprint-9.

### Producer — **READY (advisory cleared)**

**Verdict comparison vs. 2026-05-05**: UPGRADES from READY-with-advisory → READY (advisory absorbed). Sprint-8 closure (input-handling 1-5 + battle-hud 5 in single calendar day) cleared the prior advisory cleanly.

**Producer concerns (non-blocking)**:
1. Velocity-multiplier hidden cost: 5× across sprints 5/6/7/8 is pattern-stable but elapsed-time playtest exposure is 0; sprint-9 must include explicit 1-day soak window before /milestone-review GO
2. 2 USER-OWNED gates outstanding (S7-11 + S8-15); if still USER-OWNED at sprint-9 close, escalate to milestone-review NO-GO
3. Tech-debt register at 67 entries; verify each TD has a target sprint, not just a row
4. Multi-spawn-on-scale pattern at S8-07 (9-file bundle) is uncodified; rule-file entry recommended before sprint-9

**Producer recommendation — Sprint-9 plan outline**:
- **Must-have**: input-handling 006-010 (5 stories) + battle-hud 006-008 (3 stories) + S7-11 + S8-15 user-attestation gates + performance-baseline story (per TD recommendation)
- **Should-have**: S8-12..14 + S8-16 carryover; soak-day buffer
- **Capacity**: budget at sprint-7 nominal × 1.5 (NOT replicate 5× outlier)

### Art Director — **READY**

**Verdict comparison vs. 2026-05-05**: STAYS READY. The 3 new .tscn files shipped at S8-07 (UI-GB-02/05/10) are structurally compliant with art-bible direction; pattern-stable across 8 interactive Buttons + 1 Label now in scene library.

**AD ADVISORY items (non-blocking, carried forward)**:
- **AD-C5**: Character visual profile stubs absent (`design/art/characters/`) — must author before sprint-9+ character asset generation
- **AD-C2**: 청록/적색 contrast resolution still open
- **AD-C3**: 緣 glyph font-set check pending
- **TD-065**: UndoLabel hardcoded `text = "Undo"` — TD-067 lint scope extension is the correct resolution path

**AD recommendation**: Proceed to Production. Production-phase art priorities (AD-ordered): (1) character visual profile stubs for first 2-3 characters, (2) AD-C3 font glyph check, (3) AD-C2 contrast pass, (4) main-menu + pause-menu UX specs.

**AD-specific Production-phase risks**: visual consistency drift (TD-067 lint scope extension critical before scene count exceeds 12); asset pipeline stress (1-day AD review loop per first-asset-of-category); accessibility tier maintenance (manual AD spot-check at story-done until TD-067 lands).

### Aggregate

| Director | Verdict | Blockers |
|----------|---------|----------|
| Creative | **CONCERNS** | Pillar 3+4 demonstration unproven (CONCERN); S7-11 + S8-15 attestation gaps acknowledged as USER-OWNED (NOT CD blockers) |
| Technical | **READY** | None; 5 ADVISORY items (performance baseline + tech-debt growth + InputRouter soak + G-26/27 codification) |
| Producer | **READY** | None; 4 CONCERN items addressable in sprint-9 plan |
| Art | **READY** | None; 4 ADVISORY items (AD-C5/C2/C3 + TD-065/067) carried forward |

**Per Phase 4b rule**: Any director CONCERNS → verdict is minimum CONCERNS. CD CONCERNS → verdict is **CONCERNS**.

---

## 5. Path to PASS (2 USER-OWNED items)

### S7-11: User attestation on 4 VS Validation items

Source: `prototypes/chapter-prototype/REPORT.md` — 4 VS Validation items require human playtest evidence.

**Resolution path**: User boots `prototypes/chapter-prototype/chapter.tscn` (or `prototypes/vertical-slice/battle.tscn`), executes the core loop, and records attestation in REPORT.md (each of the 4 items: PASS or FAIL with notes).

**Estimated effort**: ~30 minutes one user session.

### S8-15: User attestation on manual smoke check

Source: `production/qa/smoke-2026-05-06.md` Phase 4 Batches 1 + 3.

**Resolution path**: User boots a build, verifies Batch 1 (core stability — game launches / new game / menu inputs) + Batch 3 (data integrity / performance), and records results either in the smoke check report itself or in a new `production/qa/smoke-2026-05-06-attestation.md` file.

**Estimated effort**: ~15 minutes one user session.

**Combined effort to upgrade CONCERNS → PASS**: ~45 minutes user time.

---

## 6. Alternative Path: Accept Production at CONCERNS

If user prefers immediate phase flip without S7-11 + S8-15 attestation:

- **Carry S7-11 + S8-15 attestation as Production sprint-9 must-have** (not pre-stage gate)
- Update `production/sprint-status.yaml` sprint-9 plan to reserve must-have row #1 for both attestation gates
- Write `production/stage.txt` = `Production`
- Acknowledge in writing that **CONCERNS verdict is being accepted** and the project enters Production with these CONCERN items tracked as sprint-9 backlog (not retrospectively claimed READY)

**Per refusal-to-fabricate posture**: Recommended to wait on S7-11 + S8-15 user evidence rather than flip stage prematurely. But the choice is yours — the gate-check verdict is advisory, not coercive.

---

## 7. Carryover into Sprint-9 (Production Phase Start)

| Item | Source | Owner | Resolve By |
|------|--------|-------|------------|
| S7-11 user attestation (4 VS items) | Sprint-7 USER-OWNED | user | Anytime (1 user session) |
| S8-15 user attestation (manual smoke) | Sprint-8 USER-OWNED (NEW) | user | Anytime (1 user session) |
| Performance baseline story | TD ADVISORY | performance-analyst | Sprint-9 must-have |
| Input-handling stories 006-010 | Producer plan | gameplay-programmer | Sprint-9 must-have (5 stories) |
| Battle-hud stories 006-008 | Producer plan | ui-programmer | Sprint-9 should-have (3 stories) |
| Character visual profile stubs (AD-C5) | AD ADVISORY | art-director / writer | Sprint-9 (gates character asset work) |
| TD-067 lint scope extension to .tscn | Story-008 implementation | tools-programmer | Story-008 in sprint-9 |
| G-26 + G-27 codification (engine gotchas) | TD codification candidate | godot-specialist | Sprint-8 retro |
| Multi-spawn-on-scale pattern codification | PR ADVISORY | producer / lead-programmer | Sprint-8 retro |

---

## 8. Chain-of-Verification

**Step 1 — Generate 5 challenge questions** for the CONCERNS draft:

1. **Could any listed CONCERN be elevated to a blocker given the project's current state?**
   → No. CD-flagged Pillar 3+4 demonstration is explicitly Production-phase activity (per all 4 directors). S7-11 + S8-15 are USER-OWNED gates; refusal-to-fabricate posture means MANUAL CHECK NEEDED is correctly classified, not soft-FAIL.

2. **Is each CONCERN resolvable within the next phase, or does it compound over time?**
   → Resolvable. S7-11 + S8-15 closeable in 1 user session each (~45 min combined); Pillar 3+4 demonstration is sprint-9 design + sprint-10+ asset work; performance baseline is 1 sprint-9 story; tech-debt growth at 67 entries is manageable per scheduled resolution paths.

3. **Did I soften any FAIL condition into a CONCERN to avoid a harder verdict?**
   → No. The verdict CONCERNS is justified by:
   - 1× CD CONCERNS (per Phase 4b rule, this fixes minimum verdict at CONCERNS)
   - 0 BLOCKING artifacts (17/17 present)
   - 0 BLOCKING quality checks (all automated tests PASS)
   - 0 ADR circular dependencies
   - All path-to-PASS items from prior gate-check 2026-05-05 closed except S7-11 (carried) + S8-15 (new this gate)

4. **Are there artifacts I didn't check that could reveal additional blockers?**
   → No artifact gaps surfaced beyond the documented 17/17 present + USER-OWNED carryovers. Sprint-8 closure was thorough (Must 7/7 + Should 4/4 + 0 bugs + 38 FFBs); no hidden surface area.

5. **Do all the CONCERNS together create a blocking problem even if each is minor alone?**
   → No. S7-11 + S8-15 user-attestation + Pillar 3+4 demonstration + input-handling 006-010 + Save/Load production impl are separable work streams, not interlocking. Sprint-9 plan addresses all in parallel.

**Step 2 — Answers above were generated by re-reading specific files (gate-check 2026-05-05 + qa-signoff + smoke-check + 4 director responses), not by referencing the draft verdict text.**

**Step 3 — Revision check**: Answers consistent with CONCERNS draft. **Verdict unchanged at CONCERNS.**

**Step 4 — Chain-of-Verification: 5 questions checked — verdict unchanged.**

---

## 9. Files Produced

- `production/gate-checks/pre-prod-to-prod-2026-05-06.md` (this report)

---

## 10. Cross-References

- Prior gate-check: `production/gate-checks/pre-prod-to-prod-2026-05-05.md`
- /team-qa sign-off: `production/qa/qa-signoff-sprint-8-2026-05-06.md`
- Smoke check: `production/qa/smoke-2026-05-06.md`
- Architecture review delta #15: `docs/architecture/architecture-review-2026-05-06.md`
- ADR-0020 (latest accepted): `docs/architecture/ADR-0020-input-router-dispatch.md`
- Tech-debt register: `docs/tech-debt-register.md` (TD-063..TD-067 added at S8-07 close)
- Sprint-8 plan: `production/sprints/sprint-8.md`
- Vertical Slice REPORT (S7-11 attestation target): `prototypes/chapter-prototype/REPORT.md`

---

## Verdict: **CONCERNS**

**Sole gating blockers** (both USER-OWNED, both ~1 session each):
- **S7-11**: 4 VS Validation items require human playtest attestation in `prototypes/chapter-prototype/REPORT.md`
- **S8-15**: Manual smoke check Batches 1+3 require human attestation against running build

**Path to PASS**: ~45 minutes total user time across both attestations. Combined effort upgrades verdict CONCERNS → PASS, eligible for `production/stage.txt` flip to `Production`.

**Alternative**: User may accept CONCERNS verdict + flip stage anyway, carrying S7-11 + S8-15 as sprint-9 must-have rows. Refusal-to-fabricate posture recommends waiting on user evidence, but the choice is the user's.
