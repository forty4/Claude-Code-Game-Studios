# `production/decisions/` Convention

> **Status**: BINDING (sprint-11 S11-05; codifies the format that emerged organically in sprint-10 S10-05 `ci-lane-gap-decision-2026-05-07.md`)
> **Codified**: 2026-05-08
> **Author**: claude (sprint-11 S11-05 owner)
> **Reactivation Owner**: producer (at the ≥3-artifact threshold trigger in §7)

---

## 1. Purpose + Scope

The `production/decisions/` directory holds **binding non-architectural process decisions** — scope postponements, deferral rationale docs, and other commitments that bind future sprints but are not technical-architecture choices.

This is a different artifact class from:

| Artifact class | Location | Skill | Used for |
|---|---|---|---|
| **Architecture Decision Record (ADR)** | `docs/architecture/ADR-NNNN-*.md` | `/architecture-decision` | Technical choices that constrain implementation (engine, data format, API shape, system boundary) |
| **Sprint plan** | `production/sprints/sprint-N.md` | `/sprint-plan` | Sprint-scope decisions valid only for the in-flight sprint |
| **Retrospective AI** | `production/retrospectives/retro-sprint-N-*.md` | `/retrospective` | Lessons that bind the *next* sprint via Action Items |
| **Decision artifact (this convention)** | `production/decisions/{topic}-decision-{date}.md` | *(no dedicated skill — manual authoring per this doc; see §7 for the skill-route decision)* | Binding **process** decisions that must persist across sprints with explicit reactivation triggers |

**When to use this convention** — all four conditions must hold:

1. The decision binds work *across multiple sprints* (i.e., it cannot be captured by a single sprint plan).
2. The decision is **not** a technical-architecture choice (use `/architecture-decision` if it is).
3. The decision has **explicit reactivation conditions** — there is a measurable signal that should re-open it, not an open-ended "later."
4. The decision needs to be findable by future sprint plans / gate-checks (i.e., a sprint plan or retro AI explicitly says "decision recorded at `production/decisions/...`").

If any condition fails, prefer the artifact class above that fits.

## 2. Filename Pattern + Directory

```
production/decisions/{topic-slug}-decision-{YYYY-MM-DD}.md
```

- `{topic-slug}` — short kebab-case identifier (e.g., `ci-lane-gap`, `font-glyph-coverage`, `playtest-cohort-size`). 2-4 words, no story IDs.
- `{YYYY-MM-DD}` — the **decision date** (when the binding outcome was committed), not the date of last edit. Amendments append to the existing file (see §6); they do not get a new file.
- File extension: `.md` (Markdown, GFM rendering).

**One file per decision.** If a follow-up decision *modifies* an earlier one, append to the original via the Amendment log (§6). If a follow-up decision *supersedes* an earlier one, the new file gets a new date suffix and the old file's Status header is updated to `SUPERSEDED by {new-filename}`.

## 3. Required Template

Every decision artifact MUST contain the following sections in order. Sections marked **REQUIRED** are blocking — `/story-readiness` checking a sprint task that depends on a decision artifact will fail if any required section is missing.

### Header block (REQUIRED)

```markdown
# Decision: {Topic Title} — {BINDING OUTCOME, e.g., POSTPONE TO POST-MVP / KEEP-AS-IS / ADOPT}

> **Status**: BINDING (sprint-N S{N}-NN; closes {prior AI / retro line / deferral chain})
> **Decision Date**: YYYY-MM-DD
> **Author**: {agent or user name} ({role / sprint context})
> **Reactivation Owner**: {producer / role / specific agent at next gate-check or VS-close}
```

### 3.1. Decision (REQUIRED)

The binding outcome stated in 1-3 sentences. No ambiguity, no "we should consider" — this is the commitment.

### 3.2. Why {decision verb} (REQUIRED)

Numbered list (typically 2-4 items) of **load-bearing reasons** for the decision. Each item should cite a measurable signal (test count, sprint count, line reference to retro), not a feeling. Avoid "it seems X" or "we think Y."

### 3.3. What is NOT being decided (REQUIRED)

Explicit scope guardrails. List what this decision does NOT do — the negative space matters because future sprints may incorrectly read the decision as broader than it is. Bullet list of 3-5 items typical.

### 3.4. Reactivation Triggers (REQUIRED — at least 1 trigger)

Numbered list of conditions that **automatically re-open** this decision. Each trigger has three sub-fields:

```markdown
### Trigger N — {short title}

{1-2 paragraph context}

**Signal**: {measurable, machine-detectable-or-grep-detectable condition — e.g., "production/stage.txt content changes from Pre-Production to Production" or "any story file in production/epics/ contains the literal string 'OQ-DB-6' in an Acceptance Criterion"}

**Required action when fired**: {specific procedure — who does what, in which sprint, with which artifact updated}
```

A trigger without a measurable Signal field is malformed. "When we feel ready" / "after some time" are NOT valid signals — replace them with a count, a date, a file-content-grep, or a stage marker.

### 3.5. Dependency on User Actions (CONDITIONAL — required if any trigger or implementation step requires user action)

If the decision (or any reactivation outcome) cannot proceed without user-paid prerequisites, user-only credentials, or user attestation, list each dependency with:

- What the user must do
- Whether claude has any partial-progress workaround (often "no")
- Whether the dependency is hard-blocking vs partial (e.g., Android free path vs macOS-paid path)

### 3.6. Cost-Benefit Summary (REQUIRED for postponement / deferral decisions; OPTIONAL for adopt-now decisions)

Table comparing the decided outcome against the rejected alternative. Recommended columns:

```markdown
| Factor | {alternative — e.g., "Author lanes now"} | {decided outcome — e.g., "Postpone to post-MVP"} |
|---|---|---|
| Sprint budget impact | ... | ... |
| Verification value pre-VS | ... | ... |
| Verification value post-VS | ... | ... |
| Risk to current baseline | ... | ... |
| User-action prerequisite | ... | ... |
| Pattern alignment | ... | ... |
```

The table is the audit trail — future-you reading this 3 sprints later needs to know *why this was the right call at the time* without re-deriving the logic.

### 3.7. Why this satisfies the prior AI / retro mandate (CONDITIONAL — required if the decision was a sprint-N retro AI carrying into sprint-(N+1))

Quote the verbatim AI text from the retro, then explain how this decision satisfies its AND/OR structure (e.g., "AI mandated 'author lane OR write rationale' — this doc satisfies the OR branch because [...]"). This section closes the loop on the AI so the next retro doesn't carry it forward as still-open.

### 3.8. Cross-references (REQUIRED)

Bullet list of file:line references to:

- The originating retro AI (sprint-N retro, line NNN)
- The originating sprint plan task (sprint-N S{N}-NN)
- Any ADRs the decision depends on or affects
- The current-state file the reactivation triggers monitor (e.g., `production/stage.txt`)
- The CI workflow / lint script the decision affects (if any)

### 3.9. Amendment log (REQUIRED — initially empty except for the initial-record line)

```markdown
## Amendment log

*Append future amendments below — do not rewrite the body above.*

- YYYY-MM-DD — Initial binding decision recorded ({sprint-N S{N}-NN close-out}).
```

Amendments are append-only. Never edit the body sections after the initial record date. If the decision needs to change, either (a) amend with a dated entry that explicitly notes which body sections it modifies, or (b) supersede with a new file (see §2).

## 4. Reactivation Trigger Discipline

Triggers are the load-bearing element of this convention — without them, a "decision" is just a sprint-status note that decays.

**Every trigger must be machine-or-grep-checkable.** Examples that pass:

- "`production/stage.txt` content equals `Production`"
- "Any file in `production/epics/` contains the literal string `OQ-DB-6` in an Acceptance Criterion section"
- "GitHub Actions secret named `MACOS_CERT_*` exists in repo settings"
- "`/launch-checklist` produces FAIL verdict citing missing Android CI"

Examples that fail discipline (do not use):

- "When we have time"
- "After we feel ready"
- "If it becomes a problem"
- "Once the team agrees"

The producer (or reactivation owner) is responsible for monitoring triggers at every gate-check pass. Failure to monitor is itself a sprint-N retro AI candidate.

## 5. Cost-Benefit Table Format

The cost-benefit table is the most-cited section of any decision artifact. Discipline rules:

- Always include a "Sprint budget impact" row — quantify in days or fractions thereof.
- Always include a "Risk to current baseline" row — name the specific test count or build status (e.g., "no change to current 1236/1236 PASSING baseline").
- Use the columns to compare *the decided outcome against the rejected alternative* — not against a hypothetical "ideal" outcome.
- Order rows by load-bearing weight: budget first, value/risk middle, pattern-alignment last.

## 6. Amendment Log Discipline

Amendments are how a decision evolves without losing its audit trail. Rules:

1. **Append-only.** Never modify body sections (§3.1 through §3.8) after the initial decision date. If you need to change a body section, either supersede the file or append an amendment that says verbatim "Amends §3.X — replace text with [new text]."
2. **Dated.** Every amendment line starts with `YYYY-MM-DD — `.
3. **Author-attributed.** State who made the amendment (`claude (sprint-N S{N}-NN)` or `user (manual)`).
4. **Reactivation-or-supersede note.** If the amendment fires a reactivation trigger, link to the trigger by number. If the amendment is a supersede, link to the new file.

## 7. Skill-Route Decision (this convention's own meta-decision)

The S11-05 sprint plan offered three routes for codifying this convention:

- **(a)** Sibling skill `/decision-record`
- **(b)** Extend `/architecture-decision` for non-architectural binding decisions
- **(c)** Standalone process doc

**Decision: Route (c) — standalone process doc.** This file is the canonical convention. No new skill is authored.

**Why Route (c):**

1. **Premature-abstraction risk for Route (a).** As of 2026-05-08, exactly **one** decision artifact exists in `production/decisions/` (`ci-lane-gap-decision-2026-05-07.md`). Authoring a full skill scaffold for a 1-instance pattern violates the YAGNI guidance in CLAUDE.md ("Don't add features, refactor, or introduce abstractions beyond what the task requires").
2. **Semantic-pollution risk for Route (b).** ADRs are a well-defined artifact class with `/architecture-review` traceability + ADR-NNNN numbering + technical-architecture scope. Folding process decisions into the ADR skill would muddle that semantic identity (e.g., "ADR-0019: Postpone CI lanes" reads wrong; ADR slots are for *architecture*, not *process*).
3. **Route (c) is the lightest-weight viable codification.** This doc captures the format (extracted from the ci-lane-gap precedent) without taking sprint-12 budget for skill scaffolding.

**Reactivation trigger for skill promotion (Route (a) at a later date):**

**Signal**: `production/decisions/` contains **≥3 decision artifacts** AND the `production/decisions/` directory has accumulated artifacts across **≥2 distinct sprints** (i.e., not all artifacts originated in the same sprint cluster).

**Required action when fired**: producer adds a sprint task "Promote `production/decisions/` convention to a `/decision-record` skill" to the next sprint as a Should-Have item. The skill scaffolds the Header block, the 9 required sections, and the trigger format from this doc; this doc becomes the skill's `SKILL.md` reference.

Until the trigger fires, manual authoring per this doc is the canonical workflow.

## 8. Cross-Reference Contract

Every decision artifact must be linked from:

1. **The sprint plan that closes it.** The sprint plan task row references the artifact path in its Acceptance Criteria column.
2. **The sprint-status.yaml story changelog line.** The `# YYYY-MM-DD — SHIPPED` comment lists the artifact path.
3. **The retro that absorbs it.** The retro entry that closes the AI links to the artifact.
4. **Any future sprint plan or gate-check that depends on it.** Forward references must use the artifact path verbatim so grep finds them.

The artifact itself must back-reference (in §3.8 Cross-references):

- The originating retro AI line
- The sprint task that produced it
- All ADRs and current-state files its triggers monitor

A decision artifact without back-references is malformed and `/story-readiness` should flag it.

## 9. Canonical Example

`production/decisions/ci-lane-gap-decision-2026-05-07.md` — sprint-10 S10-05; closes sprint-7→8→9 deferral chain. Use this as the reference when authoring new artifacts; it demonstrates all 9 required sections + 4 reactivation triggers + a 6-row cost-benefit table.

## 10. Future Evolution

This convention is expected to evolve as more decision artifacts accumulate. Anticipated changes:

- **At ≥3 artifacts**: Route (a) skill promotion fires per §7 trigger.
- **At ≥5 artifacts** OR **≥2 superseded artifacts**: an `index.md` may be added to `production/decisions/` summarizing live vs superseded artifacts (mirroring `production/epics/index.md`).
- **At any artifact whose triggers fire repeatedly without action**: a `producer` retro AI candidate to either tighten the trigger Signal or delete the trigger as not-actually-binding.

Until then: this doc is the convention. Author new decision artifacts manually following §3, link them per §8, and let the precedent grow before automating.

---

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-08 — Initial codification recorded (sprint-11 S11-05 close-out; Route (c) skill-route decision binding).
