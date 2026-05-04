# Gate Check: Pre-Production → Production

**Date**: 2026-05-04
**Mode**: Lean (per `production/review-mode.txt`)
**Checked by**: `/gate-check pre-production` (interpreted as Pre-Production → Production transition per active.md handoff context)
**Baseline reference**: `production/gate-checks/pre-prod-to-prod-2026-04-20.md` (verdict: FAIL with 7/17 artifacts)

---

## Verdict: **CONCERNS**

The project is **substantially Production-ready**. Architectural foundation and engineering quality have advanced dramatically since the 2026-04-20 FAIL baseline (7/17 → 13/17 artifacts present; 4 → 18 ADRs; 0 → 6 sprints; 0 → 17 epics; 0 → 2 prototypes including a 4/4-pillar VS). All 4 directors converged on CONCERNS — none returned NOT READY. But the same blocker recurs across multiple director lenses (AI System has no design or architectural anchor) and several artifacts are either stale (sprint-status.yaml, control-manifest.md, art-bible.md) or never landed (chapter-prototype REPORT.md, character profiles, main/pause-menu UX). All are fixable in 1-3 sessions.

**Per skill escalation rule**: 0 NOT READY → not auto-FAIL; 4 CONCERNS → minimum CONCERNS.

**Stage update**: Not writing `production/stage.txt` — verdict CONCERNS, not PASS.

---

## Required Artifacts: 13/17 present (was 7/17 on 2026-04-20)

| # | Artifact | Status | Notes |
|---|----------|--------|-------|
| 1 | Art bible (9 sections) | ✅ | `design/art/art-bible.md` — 64KB; AD-ART-BIBLE-signed pre-2026-04-20; **18 days stale vs ADR-0015/0018 visual contracts** |
| 2 | ≥3 Foundation ADRs | ✅ | **18 ADRs** (was 4) — all Accepted with Engine Compat + ADR Dependencies + GDD Requirements sections (verified via grep) |
| 3 | Master architecture doc | ✅ | `docs/architecture/architecture.md` (94KB) + traceability v0.13 + 13 review reports |
| 4 | Accessibility requirements | ✅ | `design/ux/accessibility-requirements.md` (path accepted by 2026-04-20 baseline) |
| 5 | Interaction pattern library | ✅ | `design/ux/interaction-patterns.md` |
| 6 | Test framework + CI | ✅ | GdUnit4 v6.1.2 (Godot 4.6.x) + workflows; **883/883 PASS** at sprint-6 close (25th consecutive failure-free baseline) |
| 7 | HUD design doc | ✅ | `design/ux/battle-hud.md` (57KB) — accepted as equivalent to gate spec's `hud.md` |
| 8 | MVP GDDs complete | ⚠️ | 13/14 Designed; **AI System #8 MVP-tier Status: Not Started** in `design/gdd/systems-index.md` |
| 9 | Character visual profiles | ❌ | Still missing — only `art-bible.md` in `design/art/`; no `design/art/characters/` |
| 10 | `prototypes/` with README | ✅ | **vertical-slice + chapter-prototype** (was missing) — 4-phase Changban-Bridge loop testing 4/4 pillars per its README |
| 11 | First sprint plan | ✅ | **6 sprints** (sprint-1 through sprint-6) — was missing |
| 12 | Epics in `production/epics/` | ✅ | **17 epic dirs + index.md** spanning Foundation/Core/Feature/Presentation — was missing |
| 13 | Control manifest | ⚠️ | Exists at `docs/architecture/control-manifest.md` (29KB) — **dated 2026-04-20; ADRs 0014..0018 (5 ADRs) Accepted post-manifest, including 3 Pillar-2 forbidden_patterns not yet codified** |
| 14 | Main menu UX spec | ❌ | Still missing |
| 15 | Pause menu UX spec | ❌ | Still missing |
| 16 | Vertical Slice playable | ✅ | `chapter-prototype/chapter.tscn` runnable via `godot --path ... res://prototypes/chapter-prototype/chapter.tscn`; tests 4/4 pillars (was missing) |
| 17 | VS 3+ playtest reports | ❌ | `production/playtests/` does not exist; chapter-prototype's promised `REPORT.md` was never written |

---

## Quality Checks

- ✅ All 18 ADRs have Engine Compatibility + ADR Dependencies + GDD Requirements sections
- ✅ Architecture has no unresolved open questions in Foundation or Core layers (Core 5/5 Complete per traceability v0.13; Pillar 2 + Pillar 4 architectural narrative-pillar substrate complete)
- ✅ Sprint plans reference real story file paths (verified by sampling `production/sprint-status.yaml`)
- ⚠️ **Sprint-status.yaml stale** — S6-02/S6-03/S6-04/S6-11 marked backlog despite shipped work:
  - S6-02 (architecture-review escalation + structural backfill) shipped via commit `6c4bd08` 2026-05-03 (delta #11)
  - S6-03 (/create-epics battle-scene) shipped via commit `f056fbe` 2026-05-04
  - S6-04 (/create-stories battle-hud — 8 stories) shipped via commit `29a7ca1` 2026-05-03
  - S6-11 (ADR-0018 Destiny Branch authoring) shipped via commits `9228660` Proposed + `41efeab` Accepted 2026-05-04 (delta #13)
- ❓ **MANUAL CHECK NEEDED — Vertical Slice Validation 4 items**:
  1. A human played through core loop without dev guidance — **unverified** (no captured playtest)
  2. Game communicates what to do within first 2 minutes — **unverified**
  3. No critical fun-blocker bugs in VS — **unverified**
  4. Core mechanic feels good — **unverified** (subjective; needs user attestation)

---

## Director Panel Assessment (lean mode — all 4 spawned in parallel)

### Creative Director: **CONCERNS**

> Pillars 1+2 well-supported by design state; **Pillars 3+4 lack provable substrate**. Chapter-prototype claims 4/4 pillars tested but no captured evidence. MVP Core Hypothesis at `game-concept.md:296` is staged, not validated.

**Specific items**:
- **BLOCKER**: Capture playtest evidence — write `prototypes/chapter-prototype/REPORT.md` with concrete findings against all 4 pillars + MVP Core Hypothesis verdict.
- **BLOCKER**: Author AI System GDD (#8) — Pillar 3 ("Every class has a role") cannot be proven without enemy AI that pressures roles asymmetrically. Inline prototype AI ≠ Production-ready design.
- **CONCERN**: Promote 3 PROVISIONAL VS-tier GDDs to Designed — Story Event #10 + Save/Load #17 (Pillar 4 substrate); Destiny State #16 (Pillar 2 substrate).
- **ADVISORY**: Character visual profiles deferred — acceptable for phase entry; not pillar-blocking.

### Technical Director: **CONCERNS**

> Architectural substrate genuinely strong. Manifest refresh + AI ADR are sprint-7 entry conditions, not phase blockers. ADR-0017/0018 implementation IS Production work — not Pre-Production scope.

**Specific items**:
- **BLOCKER for sprint-7 kickoff (not phase gate)**: Refresh `control-manifest.md` to cover ADRs 0014..0018. The manifest is the programmer-actionable surface; 5 ADRs and 3 Pillar-2 forbidden_patterns missing means specialist agents won't enforce them.
- **CONCERN**: AI System needs ADR-0019 before first AI implementation story — TD-FEASIBILITY → ADR draft sub-task. Don't let AI implementation begin without it (unbounded architectural debt).
- **ACCEPTABLE**: 2 PROVISIONAL signals on GameBus (down from 5). Trajectory correct.
- **CONCERN, deferrable**: No accessibility ADR despite committed tier — add to sprint-7 or sprint-8 backlog as ADR-0020.

### Producer: **CONCERNS**

> Technical foundation strong. Three production-tracking artifacts are stale or missing in ways that compound the moment Production execution starts.

**Specific items (BLOCKER-adjacent — fix before Production day 1)**:
- Reconcile `production/sprint-status.yaml` — flip S6-02/03/04/11 backlog → done with commit refs. Stale truth-source propagates wrong velocity into sprint-7 estimation.
- Author sprint-7 plan covering ADR-0017 Migration §1..§11 (ScenarioRunner) + ADR-0018 Migration §5 (DestinyBranchJudge) + at minimum Story Event #10 GDD track.
- Create AI System epic (or explicit defer-with-rationale ADR) — 장판파 chapter-1 cannot ship without enemy AI.

**CONCERNS (track, don't block)**:
- Sprint hygiene gap (3 must-haves absorbed across deltas without ceremony) → set sprint-7 retro AI: "all shipped work must close its sprint-status row in the same patch."
- Refresh `control-manifest.md` (14 days stale).
- Capture 2-3 internal playtest notes retroactively in `production/playtests/`.

**Most likely cut point under pressure**: Cut Save/Load #17 GDD from sprint-7 — keep Story Event #10 + Destiny State #16 (load-bearing for chapter-1 narrative beats).

### Art Director: **CONCERNS**

> Art bible structurally solid. Four concrete visual contracts created after the bible's last update remain unresolved; three systemic gaps were already flagged at 2026-04-20 baseline without resolution.

**Specific items**:
- **C1 — `reserved_color_treatment` visual spec missing (BLOCKING for destiny-branch impl)**: ADR-0018 line 84 defines the boolean invariant; no art-bible spec for the visual treatment it triggers. Latest responsible moment: before destiny-branch implementation story opens (sprint-7+). Fix as art-bible §4.x addendum this sprint.
- **C2 — 청록 #3A7D6E contrast unresolved** (formation-bonus.md OQ-FB-01). Latest responsible moment: before formation-bonus implementation story.
- **C3 — 緣 bond glyph font-set availability unchecked**. Latest responsible moment: before formation-bonus implementation story.
- **C4 — Art bible not updated for ADR-0015 or ADR-0018** (18 days stale). Standing end-of-sprint sync ritual recommended.
- **C5 — No character visual profiles** (known since 2026-04-20). Latest responsible moment: before first character asset is commissioned/generated.
- **C6 — No main/pause menu UX spec** (known since 2026-04-20). Latest responsible moment: before main/pause-menu implementation stories.

---

## Cross-Director Convergent Blockers (flagged by 2+ directors)

1. **AI System (#8 MVP)** — no GDD, no ADR, no epic. Flagged by CD (Pillar 3), TD (no ADR), PR (no epic). Required before chapter-1 (장판파) implementation.
2. **`reserved_color_treatment` visual spec** — flagged by AD as BLOCKING for destiny-branch implementation; downstream of ADR-0018 acceptance today.
3. **Stale artifacts** — control-manifest (TD + PR), sprint-status.yaml (PR), art-bible.md (AD).

---

## Chain-of-Verification

5 questions checked against artifacts — verdict unchanged.

1. *Could any CONCERN be elevated to a blocker?* — Yes for several individually (REPORT.md, AI System, manifest staleness), but each is reconcilable in <1 session and none triggers an automatic-FAIL gate criterion.
2. *Are CONCERNS resolvable in next phase?* — Yes for all; estimates 4-6 hours total across 1-3 sessions.
3. *Did I soften any FAIL into CONCERN?* — VS Validation block has 4 unverified items. Skill auto-FAIL triggers only on explicit NO answers, not unverified items. Chapter-prototype demonstrably runs (per its README + battle.gd 470 LoC + chapter.gd 19KB). User attestation needed to convert unverified → PASS contributions.
4. *Are there artifacts I didn't check that could reveal additional blockers?* — `docs/consistency-failures.md` does not exist (gate spec says read if exists; it doesn't, so no extra blockers from that source).
5. *Do all CONCERNS together create a blocking problem?* — Cumulatively, ~80-90% Production-ready. Individual items are 1-2 session fixes. Not blocking in aggregate, but not PASS either.

---

## Minimal Path to PASS (ordered, ~4-6 hours / 1-3 sessions)

| # | Action | Estimate | Director(s) flagged |
|---|--------|----------|---------------------|
| 1 | Reconcile `production/sprint-status.yaml` — flip S6-02/03/04/11 backlog → done with commit refs (`6c4bd08` / `f056fbe` / `29a7ca1` / `41efeab`). **Note**: file convention says "use /story-done to update status" — choose: retrospective `/story-done` × 4, OR manual edit + clear annotation, OR document-only via this gate report. | 15-30 min | PR |
| 2 | Author `prototypes/chapter-prototype/REPORT.md` — capture findings against 4 pillars + MVP Core Hypothesis verdict (PROCEED / PIVOT). Honest write-up acceptable; subjective UX claims require user attestation. | 30-60 min | CD |
| 3 | Refresh `control-manifest.md` to absorb ADRs 0014..0018 (3 new Pillar-2 forbidden_patterns + 5 ADR layer). Sprint-7 entry condition. | 1-2 hours | TD + PR |
| 4 | Author AI System GDD (#8) + minimal AI ADR-0019 — sufficient to unblock chapter-1 enemy behavior. Solo dev MVP scope: 2-4 enemy archetypes with role-aware heuristics. | ~1 session | CD + TD + PR |
| 5 | Address `reserved_color_treatment` visual spec in art-bible §4.x addendum (1 paragraph + color + state diagram). | 30 min | AD |
| 6 | Author sprint-7 plan absorbing ScenarioRunner + DestinyBranchJudge + Story Event #10 + Destiny State #16 GDDs (PR cut point: drop Save/Load #17). | ~1 hour | PR |

**Optional, deferrable to early Production**: Character visual profiles (AD-C5); main/pause-menu UX specs (AD-C6); 청록 contrast resolution (AD-C2); 緣 glyph font-set check (AD-C3).

After items 1-6 land, re-run `/gate-check pre-production` for upgrade to PASS (with user attestation on the 4 VS Validation items).

---

## Recommendations (non-blocking)

- Set sprint-7 retro AI: "all shipped work must close its sprint-status row in the same patch" (PR observation on 3 must-haves absorbed across deltas).
- Capture 2-3 internal playtest notes retroactively in `production/playtests/` from VS prototype runs.
- Art bible end-of-sprint sync ritual whenever an ADR touching visual contracts is Accepted.
- Damage Calc triad process insights ("recursive fabrication trap" / "compute, don't read" / "change the cell, forget the citer") — already noted in 2026-04-20 baseline; ensure they ride into Production via control-manifest refresh.
