# Process Audit — `/story-done` Phase 7 Status Update Enforcement

**Date**: 2026-05-08 (sprint-11 S11-03)
**Auditor**: claude
**Trigger**: sprint-10 retro action item #3 (S10-04 root cause analysis); empirically confirmed by sprint-11 S11-02 catching 3rd + 4th activation of retro AI #3 on destiny-branch + ai-system epics
**Subject**: `.claude/skills/story-done/SKILL.md` Phase 7 (Update Story Status)
**Verdict**: **GAP CONFIRMED** — Phase 7 enforces story-file + sprint-status.yaml + active.md updates, but does NOT enforce EPIC.md + index.md updates. Causal of S10-04 + S11-02 backfill drift.

---

## Background

Sprint-10 closed 2026-05-07 with S10-04 BACKFILL CLOSE-OUT — a doc-only graduation flip that caught scenario-progression Core epic stranded with EPIC.md + index.md Status fields stuck at `Ready` since sprint-7 S7-02 close 2026-05-05 (commit `ba02e02`). Sprint-11 S11-02 caught the same pattern on destiny-branch + ai-system Core/Feature epics — both had EPIC.md Status headers correctly Complete since 2026-05-05 but EPIC.md Stories table rows + index.md rows remained stale at `Ready` for 2 days.

**Pattern**: when a story closes via `/story-done`, the story-file Status header flips Ready → Complete, sprint-status.yaml row flips ready-for-dev → done, and active.md gets a session extract. But the parent EPIC.md and the project-wide `production/epics/index.md` are NEVER touched by Phase 7. If this is the epic's last (epic-terminal) story, that means epic-graduation status flips are silently dropped.

Sprint-10 retro AI #3 ("Story-spec doc-correction at /story-readiness time") codified the catch mechanism (S11-01 BACKFILL CLOSE-OUT verdict in `/story-readiness`). This audit closes the loop by addressing the **root cause** — fixing `/story-done` Phase 7 so the drift never opens in the first place.

---

## Phase 7 Current State (read from `.claude/skills/story-done/SKILL.md` lines 322-381)

Phase 7 currently does, on user approval:

| Step | Action | Source canonical for Status |
|---|---|---|
| 1 | Update story file Status field: `Status: Complete` | Story file (1 of 4) |
| 2 | Add Completion Notes section | Story file |
| 3 | Optionally log tech debt entries | (separate doc) |
| 4 | Update `production/sprint-status.yaml` row + top-level `updated:` | sprint-status.yaml (2 of 4) |
| 4b | 200-byte cap discipline + history archiving on overflow | sprint-status-history.md |
| Session State Update | Append to `production/session-state/active.md` | active.md (gitignored) |

**Steps 1 + 4 + Session State Update cover**:
- Story file Status header ✓
- sprint-status.yaml row + top-level ✓
- sprint-status-history.md long-form (when overflow) ✓
- active.md session extract ✓

**Phase 7 currently DOES NOT cover**:
- ❌ Parent `production/epics/[epic-slug]/EPIC.md` Status header (Ready → Complete when last story closes)
- ❌ Parent `production/epics/[epic-slug]/EPIC.md` Stories table row Status
- ❌ Project-wide `production/epics/index.md` row Status cell + Stories cell

**Detection logic absent**: Phase 7 has no concept of "is this story the epic's last story?" — there is no scan of sibling stories or check of remaining-Ready story counts in the parent EPIC.md.

---

## Root Cause of S10-04 + S11-02

### S10-04 (sprint-7 S7-02 ScenarioRunner — caught at sprint-10 plan-time)

- 2026-05-05: `/story-done` closed S7-02 → story file Status: Complete ✓ + sprint-status.yaml: done ✓ + active.md updated ✓
- **Phase 7 silently skipped**: scenario-progression EPIC.md (Status remained "Ready") + scenario-progression EPIC.md Stories table (row remained "Ready") + index.md scenario-progression row (Status remained "Ready")
- Drift duration: 2 days (sprint-7 close 2026-05-05 → S10-04 catch 2026-05-07)
- Cost saved by catch: ~0.6d of would-have-been-wasted /dev-story attempt (S10-04 0.6d nominal estimate would have been spent re-implementing already-shipped work)

### S11-02 (sprint-7 S7-03 destiny-branch + S7-04 ai-system — caught at sprint-11 S11-02)

- 2026-05-05: `/story-done` closed S7-03 + S7-04 individually → both story files Complete ✓ + sprint-status.yaml done (sprint-7 era; archived now) ✓
- **Phase 7 partially executed**: destiny-branch + ai-system EPIC.md Status headers DID get updated to Complete ✓ (suggests sprint-7 era ran an additional manual flip); but EPIC.md Stories table rows + index.md rows DID NOT get updated ✗
- Drift duration: 2 days (sprint-7 close 2026-05-05 → S11-02 catch 2026-05-07)
- Cost saved by catch: ~1.0-1.2d combined across both epics

### Pattern recurrence stability

Pattern stable at **4 BACKFILL CLOSE-OUT invocations** (all 4 caught on same calendar day after S11-01 codification 2026-05-07):

1. battle-hud 004 (sprint-10 plan-time sweep; orig S7-09 commit `c5237c8`)
2. battle-hud 005 (sprint-10 plan-time sweep; orig S8-07 commit `ad3c378`)
3. scenario-progression story-001 (S10-04; orig S7-02 commit `ba02e02`)
4. destiny-branch story-001 (S11-02; orig S7-03 sprint-7 close)
5. ai-system story-001 (S11-02; orig S7-04 sprint-7 close)

(5 total catches; 4 distinct patterns since #1+#2 are the same drift instance.)

All 5 share the same root cause: `/story-done` Phase 7 does not enforce EPIC.md + index.md propagation.

---

## Recommended Fix (3-part defense-in-depth)

### Part 1 — Codify Phase 7 step 5 (EPIC.md + Stories table)

Insert new step after Phase 7 step 4 in `.claude/skills/story-done/SKILL.md`:

```markdown
5. **Update parent EPIC.md** (if this story is the epic's last story):
   - Detect epic-terminal: read `production/epics/[epic-slug]/EPIC.md` Stories table; count remaining rows whose Status is Ready / In Progress / Blocked / Draft (not Complete). If this story's row was the last non-Complete row → this is an epic-terminal close.
   - If epic-terminal:
     a. Update `production/epics/[epic-slug]/EPIC.md` Status header (typically line 6): `Ready` / `In Progress` → `Complete (M/M stories shipped — [completion-trace])`
     b. Update this story's row in the Stories table: `Ready` / `In Progress` → `Complete (S{sprint}-{NN} {sprint-id} close {date}; {test-pass-counts}; ...)`
   - If NOT epic-terminal: still update this story's Stories table row in EPIC.md (Status flip Ready → Complete), but leave the EPIC.md header Status alone (epic remains In Progress until last story closes).
```

### Part 2 — Codify Phase 7 step 6 (index.md)

Insert another step after step 5:

```markdown
6. **Update `production/epics/index.md`** if this is an epic-terminal close OR if this story affects the epic's reported state:
   - Find the row referencing the parent epic (grep `production/epics/index.md` for `[epic-slug](epic-slug/EPIC.md)`)
   - Update the Stories cell: from `Not yet created` / `N/M Complete` to canonical `M/M Complete via {commit-sha} {date}` (for epic-terminal) OR `(N+1)/M Complete` (for non-terminal)
   - If epic-terminal: update the Status cell from `Ready` / `In Progress` to `**Complete** ({date}) 🎉 — {graduation-trace}`
   - **DO NOT update** the index.md Layer coverage summary line (line 6) automatically — that line is multi-epic + free-form prose; manual review at sprint-retro time is preferable to over-aggressive auto-update
```

### Part 3 — Add post-close consistency lint (defense-in-depth)

Add new lint script at `tools/ci/lint_story_status_consistency.sh` that runs in CI on every push:

For each story file in `production/epics/**/story-*.md`:
1. Extract the story file Status header value (line 4-6, parse `> **Status**: X`)
2. Find the matching sprint-status.yaml row by file path; extract `status:` value
3. Read the parent EPIC.md (path: same dir + EPIC.md); extract Status header + Stories table row Status for this story
4. Find the index.md row referencing this epic; extract Status cell + Stories cell content
5. **Compare**:
   - Story file Status = Complete should imply sprint-status.yaml row = done OR archived in sprint-status-history.md (sprint-archive)
   - Story file Status = Complete + this is the epic's last story should imply EPIC.md Status = Complete
   - Story file Status = Complete should imply EPIC.md Stories table row = Complete
   - Story file Status = Complete should imply index.md row Status = Complete (if epic-terminal) OR appropriate progress marker
6. If mismatch found: emit `STATUS_CONSISTENCY_FAIL: [story-id] story=[Status]; sprint-status.yaml=[status]; EPIC=[Status]; index=[Status]` + exit non-zero

Wire into `.github/workflows/tests.yml` as a new lint step.

---

## Effort Estimate

| Part | Effort | Sprint-11 Disposition |
|---|---|---|
| Part 1 — Phase 7 step 5 (EPIC.md) | ~0.05d | Apply this commit (S11-03 scope) |
| Part 2 — Phase 7 step 6 (index.md) | ~0.05d | Apply this commit (S11-03 scope) |
| Part 3 — consistency lint | ~0.15d | Apply this commit (S11-03 scope) |
| Total | ~0.25d | Within S11-03 0.3d nominal |

---

## Risk

- **R1**: Phase 7 epic-terminal detection logic depends on EPIC.md Stories table format; if a project had non-standard EPIC.md formats, the detection might miss. Mitigation: detection is best-effort + lint is the safety net.
- **R2**: index.md auto-update could interact poorly with the Layer coverage summary line. Mitigation: explicit "DO NOT update Layer coverage summary line" guidance in step 6.
- **R3**: Consistency lint could be noisy on sprint-archive stories (where sprint-status.yaml row no longer exists because rotated to history). Mitigation: lint includes archive-aware logic — if no current sprint-status.yaml row exists, fall back to sprint-status-history.md presence check.

---

## Validation

This audit will be validated as effective when:

- (a) `/story-done` Phase 7 step 5 + 6 are codified in skill (Part 1 + Part 2 applied) ✓ **DONE this commit**
- (b) Consistency lint exists at `tools/ci/lint_story_status_consistency.sh` (Part 3 applied) ✓ **DONE this commit** (NOT yet CI-wired — see Lint findings below)
- (c) The next epic-terminal story close fires the new steps + the EPIC.md + index.md flips happen automatically without backfill needed
- (d) No 5th retro-AI-3 activation surfaces in sprint-12 or beyond (the codification + lint should prevent the drift from opening at all)

---

## Lint Findings (first run 2026-05-08)

Running `tools/ci/lint_story_status_consistency.sh` against the current repo surfaces **33 pre-existing drift items** distributed across many epics. The lint correctly detects two failure categories:

| Failure Category | Count | Description |
|---|---|---|
| `index.md row status=Ready (story is Complete)` | 21 | index.md row for the story's epic shows Ready but the story file Status header is Complete + the EPIC.md Stories table row is also Complete. Drift in index.md row Status cell only. |
| `EPIC.md Status header=Ready but all stories in epic are Complete (epic-terminal closure not propagated)` | 12 | The epic's EPIC.md Status header is Ready but every story in the epic has Status=Complete. The epic graduated but the header was never flipped. |
| **Total** | **33** | |

These 33 drift items predate the S11-01 codification + S11-03 audit — they accumulated from sprint-7 close-out era (likely earlier) when `/story-done` Phase 7 had no EPIC.md / index.md update step. Now that the codification exists, **sprint-12 (or a dedicated drift-cleanup story in sprint-11 if the user wants to extend scope)** can apply the bulk fix using the lint output as the authoritative finding list.

**S11-03 scope deliberately STOPS at codification + lint authoring** — applying 33 retroactive drift fixes is broader than the 0.3d S11-03 nominal budget. The backfill cleanup is a sprint-12 candidate or could be folded into S11-04 (Carryover absorption sweep close) if the user opts to widen S11-04 scope.

### Why CI wiring is deferred

If the lint were wired to `.github/workflows/tests.yml` immediately, CI would FAIL on every push starting now (33 pre-existing failures). That would break the repo's green-CI baseline — counter-productive to the goal of maintaining 1236/1236 PASS.

**Sprint-12 plan candidate**: (a) bulk-fix the 33 pre-existing drift items via systematic per-epic graduation flips (~0.3-0.5d depending on per-epic Stories table complexity), (b) verify lint exits 0 cleanly, (c) wire to `.github/workflows/tests.yml` after baseline is clean.

Until then, the lint is available as a **local pre-flight tool** for /story-done Phase 7 step 7 enforcement. Future story closures will not add new drift (codification ensures this); the lint catches any future regressions immediately at CI-runtime once wired.

---

## Drift inventory (33 items — sprint-12 cleanup target)

Run `bash tools/ci/lint_story_status_consistency.sh` to regenerate this list at sprint-12 plan time. The list is expected to remain at 33 (or similar count, +/- any new closures since 2026-05-08) until the bulk cleanup ships. The lint output gives the exact story-id + per-source Status mismatch detail per item.

---

## Cross-references

- Sprint-10 retro AI #3: `production/retrospectives/retro-sprint-10-2026-05-07.md` — "Sprint-11 retro AI #3 closure pass" / Action Item #3
- S11-01 codification: commit `1a69b9f` — `.claude/skills/story-readiness/SKILL.md` Phase 2.5 + verdict + output + redirect
- S11-02 empirical validation: commit `07dda3c` — destiny-branch + ai-system 3rd + 4th retro-AI-3 activation
- S10-04 BACKFILL precedent: commit `22b6039` — scenario-progression 1st BACKFILL CLOSE-OUT
- /story-done skill: `.claude/skills/story-done/SKILL.md` Phase 7 (lines 322-381) — target of audit findings
- /story-readiness skill: `.claude/skills/story-readiness/SKILL.md` Phase 2.5 — pre-check that catches drift opened by Phase 7 gap
