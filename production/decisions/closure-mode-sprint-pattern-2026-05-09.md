# Decision: Closure-Mode Sprint Planning Pattern — ADOPT HYBRID (≥3-of-5 SIGNAL TRIGGER)

> **Status**: BINDING (sprint-12 S12-07; closes sprint-11 retro AI #6)
> **Decision Date**: 2026-05-09
> **Author**: claude (sprint-12 S12-07 owner; per producer-call mandate)
> **Reactivation Owner**: producer (at every sprint-(N+1) /sprint-plan invocation; signal evaluation gate)

---

## Decision

**Closure-mode sprints are adopted as a HYBRID planning pattern, triggered when ≥3 of the 5 signals defined in §3.4 Trigger 1 evaluate true at sprint-(N+1) `/sprint-plan` time. Otherwise, mixed-mode is the default.**

A "closure-mode sprint" is a sprint where ≥80% of stories are closure / admin / codification work (carryover absorption, lint cleanup, doc-only graduation flips, retro-AI codification, process-audit follow-through, hygiene sweeps). The remaining ≤20% may be greenfield feature work.

Mixed-mode (the default) is any sprint where greenfield feature work and closure work each constitute >20% of story slots.

The producer evaluates the 5 signals at each `/sprint-plan` invocation; signal evaluation outcome is recorded in the sprint plan's `## Sprint Mode` section (NEW required section in `.claude/skills/sprint-plan/SKILL.md` Phase 2 template — companion edit to be made when this decision's Trigger 4 fires for the first time at sprint-13 plan).

## Why HYBRID (and not EMBRACE-as-cadence or RESERVE-as-stopgap)

Four load-bearing reasons:

1. **Empirical velocity data favours signal-triggered over cadence-based.** Sprint-11 (the project's first explicitly-planned 100% closure-mode sprint) over-performed at ~0.5d actual vs ~2.2d nominal — multiplier ÷~4.4 vs the ÷3 mixed-mode baseline (per `production/retrospectives/retro-sprint-11-2026-05-08.md` §"Aggregate"). Sprint-9 + sprint-10 (closure-heavy by carryover absorption rather than by plan) over-performed less dramatically (≤÷3.5 multiplier per sprint-10 retro AI #4 re-validation). The delta between "planned closure-mode" and "incidentally closure-heavy" is ~÷1 multiplier point — meaning closure-mode IS distinctively faster when planned, but only when the right signals justify it. EMBRACE-as-cadence (e.g., "every 3rd sprint is closure-mode") would force closure-mode planning even when no signals support it — leaving the over-performance multiplier theoretical rather than load-bearing. RESERVE-as-stopgap would only fire on carryover threshold breach, missing 4 of the 5 signals that justified sprint-11's planned closure-mode (only carryover threshold was NOT one of sprint-11's triggers — sprint-11 entered with 9 carryover items, not ≥4 from a single category, but the OTHER signals were dominant).

2. **Sprint-11 itself proves all 5 signals must be measurable, not vibes-based.** The sprint-11 plan-time decision to go closure-mode was made on 5 distinct converging conditions — each retroactively isolatable from the sprint-10 retro + sprint-status.yaml at sprint-11 entry. Codifying these as signals (rather than a producer's gut call) makes the trigger reproducible: any future producer (or claude) running `/sprint-plan` for sprint-13+ can mechanically evaluate each signal against the current artifacts. This converts "we noticed sprint-11 was a good closure sprint" into a binding rule that can be re-applied without re-deriving the logic each time.

3. **≥3-of-5 threshold protects against both over-allocation and under-allocation.** ≥4-of-5 would gate-keep too aggressively (sprint-11 itself fired exactly 4 of 5 signals, so the threshold would be at sprint-11's empirical floor — fragile if any one signal weakens). ≥2-of-5 would be too permissive (3 of the 5 signals fire frequently enough that ≥2 would trigger closure-mode in ~40% of sprints per a back-of-envelope sprint-7→11 retroactive count). ≥3-of-5 places the threshold at the empirical signal-density that distinguished sprint-11 from sprint-7/8/9/10 (each of which had ≤2 signals firing despite being closure-heavy). The threshold is calibrated to the data, not chosen aesthetically.

4. **HYBRID respects producer agency at sprint-(N+1) plan time.** Even when ≥3 signals fire, the producer retains override authority — the rule is "closure-mode is the default RECOMMENDATION when the trigger fires," not "closure-mode is mandatory." The override is recorded in the sprint plan's NEW `## Sprint Mode` section as a justification line. This preserves the meta-pattern from sprint-9 retro AI #2 / sprint-10 retro AI #1 / sprint-11 retro AI #1 (codification debt MUST be paid at retro time): rules are codified to capture lessons learned, not to remove agency.

## What is NOT being decided here

This decision does NOT:

- Mandate closure-mode at any specific cadence (no "every Nth sprint" rule). Closure-mode firing is data-driven via the 5 signals, not calendar-driven.
- Cap or floor the closure-mode allocation within a sprint when the trigger fires. The ≥80% closure / ≤20% greenfield split is the closure-mode definition, but a closure-mode sprint may also be 100% closure (sprint-11 precedent) or 95% / 5% — the exact mix is producer-determined within the closure-mode designation.
- Change the mixed-mode default planning workflow. `/sprint-plan` continues to operate as it does today; this decision adds a single signal-evaluation step before the mode designation locks in.
- Affect the velocity multiplier model (sprint-10 retro AI #4 still owns the ÷3 mixed / ÷4 closure / ÷5 greenfield calibration). Multiplier choice follows the mode designation; mode designation follows the signal evaluation.
- Override carryover-absorption obligations. Carryover items must still be addressed each sprint per sprint-9 retro AI #2; closure-mode designation is orthogonal to whether carryover is in-scope.
- Create a new skill or sub-skill. Per `docs/process/decisions-convention.md` §7, no new skill is authored for a single binding decision; the decision is captured in this artifact + a companion `## Sprint Mode` section addition to `.claude/skills/sprint-plan/SKILL.md` at the next sprint plan invocation.
- Apply retroactively to sprint-12. Sprint-12 was planned mixed-mode at 2026-05-08 plan-time and remains so; this decision binds sprint-13+ planning.

## Reactivation Triggers

This decision **automatically re-opens** when any one of the following becomes true:

### Trigger 1 — Sprint-(N+1) `/sprint-plan` signal evaluation (RECURRING)

This is the standing per-sprint trigger that operationalizes the decision. At every `/sprint-plan` invocation (sprint-13 onward), the producer evaluates all 5 signals against the current state. The signal definitions:

**Signal A — Carryover concentration**: pre-sprint-(N+1) carryover backlog (per sprint-9 retro AI #2 carryover-backlog section in sprint-N status) contains ≥4 items, OR contains any item with ≥4-time-carryover count (per S12-06 USER-OWNED 5th-time threshold codification candidate).

**Signal B — Unpaid codification debt**: sprint-N retrospective contains ≥1 codification AI marked as DEFERRED / NOT-CLOSED / CARRY-FORWARD (i.e., codification debt was NOT paid at sprint-N retro time per the sprint-7→11 sustained discipline).

**Signal C — Recent epic-cluster close**: ≥3 epics flipped to Status=Complete in `production/epics/index.md` within the last 2 sprints (sprint-(N-1) + sprint-N). Mechanical check: count `Complete (YYYY-MM-DD)` cells where the date falls in the sprint-(N-1) start to sprint-N end window.

**Signal D — Hygiene drift accumulation**: at least one of (i) 5 TODOs in `src/` (current S11-11 audit threshold), (ii) ≥10 lint-drift items surfaced by `lint_story_status_consistency.sh`, OR (iii) ≥1 lint with vacuous-pass condition where forward-looking enforcement coverage is needed (e.g., S12-S03 migration-purity lint as of 2026-05-09).

**Signal E — No fresh must-have feature ready**: at sprint-(N+1) plan time, the GDD backlog has zero items where `/quick-design` OR `/create-stories` has produced ready-for-/dev-story files for a Pillar 1-4 feature (i.e., next-up greenfield features need design-spec authoring before /dev-story is feasible).

**Signal**: at `/sprint-plan` invocation, count how many of A/B/C/D/E evaluate TRUE.

**Required action when fired**:

- If count ≥3: producer designates the sprint as closure-mode in the `## Sprint Mode` section of the sprint plan, with the firing signals listed. Velocity multiplier defaults to ÷4 (per sprint-10 retro AI #4 closure baseline). Producer may override designation with documented justification.
- If count = 2: producer evaluates whether borderline-trigger applies; mixed-mode is the default but closure-leaning mixed-mode (e.g., 60% closure / 40% greenfield) is permitted with documented signal rationale.
- If count ≤1: mixed-mode is the binding designation; greenfield-leaning mix is appropriate.

Records the count + signal labels in `## Sprint Mode` regardless of outcome — the negative case (≤1 firing) is itself audit data for sprint-(N+2) signal calibration.

### Trigger 2 — Sprint-mode designation outcome diverges from the rule

Across any 3 consecutive sprint plans, if the producer overrides the rule's designation (e.g., signal count ≥3 but planned mixed-mode, or signal count ≤1 but planned closure-mode) ≥2 times, the rule itself is re-opened. The override pattern indicates the signals are mis-calibrated.

**Signal**: producer overrides the signal-triggered designation in ≥2 of any 3 consecutive sprint plans (sprint-(N) + sprint-(N+1) + sprint-(N+2) window — rolling).

**Required action when fired**: producer adds a sprint task "Re-calibrate closure-mode signal definitions per `production/decisions/closure-mode-sprint-pattern-2026-05-09.md` Trigger 2" to the next retrospective Action Items list. Re-calibration may amend Signal A-E definitions, adjust the ≥3-of-5 threshold, or supersede this decision if the pattern is fundamentally wrong.

### Trigger 3 — Velocity multiplier model amendment

If sprint-10 retro AI #4's velocity multiplier model (÷3 mixed / ÷4 closure / ÷5 greenfield) is amended by a future retro, this decision must be re-validated because the cost-benefit calculus depends on the multiplier delta between mixed and closure modes.

**Signal**: any retrospective contains amendment text for the velocity multiplier model (grep: `production/retrospectives/retro-sprint-*.md` for `÷4 closure` OR `÷3 mixed` with edit/amendment context).

**Required action when fired**: claude amends this decision's §3.6 Cost-Benefit Summary with a recalculated row reflecting the new multiplier delta + records the amendment per §3.9.

### Trigger 4 — `.claude/skills/sprint-plan/SKILL.md` `## Sprint Mode` section addition

The decision specifies (in §"Decision" + Trigger 1) that `/sprint-plan` Phase 2 template gains a new required `## Sprint Mode` section. The companion edit is NOT included in this S12-07 ship — it is deferred to the first sprint plan that fires Trigger 1 (likely sprint-13 plan at sprint-12 close).

**Signal**: `/sprint-plan` is invoked for sprint-13 (or any sprint after this decision's date) for the first time AND `.claude/skills/sprint-plan/SKILL.md` Phase 2 template does NOT yet contain a `## Sprint Mode` section.

**Required action when fired**: claude (or producer) adds the `## Sprint Mode` template section to `.claude/skills/sprint-plan/SKILL.md` BEFORE authoring sprint-13's plan. The new section's required sub-fields: (a) Mode designation (mixed / closure / borderline-mixed), (b) Signal evaluation table (5 rows × Signal/TRUE-FALSE columns), (c) Override justification (CONDITIONAL — required if designation diverges from rule), (d) Velocity multiplier choice (÷3 / ÷4 / ÷5 / custom + rationale).

## Dependency on User Actions

None. This decision is fully claude-side and does NOT require user attestation, user-paid prerequisites, or user-only credentials. The producer (claude in this project's collaboration model) evaluates signals and applies designation at each `/sprint-plan` invocation; user override is always available via the existing `Question -> Options -> Decision -> Draft -> Approval` collaboration protocol (per CLAUDE.md).

The user is the override authority at sprint plan time — if the signal evaluation suggests closure-mode but the user prefers mixed-mode (or vice versa), the user's preference binds. The `## Sprint Mode` section captures the override justification regardless of source (claude or user).

## Cost-Benefit Summary

| Factor | EMBRACE (cadence-based) | RESERVE (stopgap-only) | HYBRID (≥3-of-5 signals — decided outcome) |
|---|---|---|---|
| Sprint budget impact | Closure-mode every Nth sprint regardless of signals; ~33% of sprints if N=3 (over-allocation when no signals fire) | Closure-mode only when carryover threshold breaches; ~10-15% of sprints (under-allocation when codification debt accumulates) | Closure-mode when ≥3 signals converge; estimated ~20-25% of sprints based on retroactive sprint-7→11 count (1 of 5 sprints fired 4 signals; sprints 9-10 fired 2-3) |
| Verification value pre-VS | Low: forced cadence ignores codification debt timing | Low: misses non-carryover-driven closure opportunities (recent epic-cluster, hygiene drift) | High: signal-driven means closure-mode fires precisely when codification debt + hygiene drift + epic-cluster timing converge |
| Verification value post-VS | Same as pre-VS (cadence is mode-orthogonal to VS) | Same as pre-VS | Same as pre-VS |
| Risk to current baseline | Low: closure-mode is doc-only/admin-heavy; baseline preserved per sprint-11 precedent (51st FFB through 11/11 stories) | Low: same as EMBRACE | Low: same as both alternatives |
| User-action prerequisite | None | None | None — signal evaluation is mechanical (greppable) |
| Pattern alignment | Mis-aligned: cadence-based contradicts the data-driven discipline established by sprint-9 retro AI #2 + sprint-10 retro AI #4 + sprint-11 retro AI #1 | Mis-aligned: stopgap framing under-weights the project's empirical preference for proactive codification (Process Improvement #1 from sprint-8: pay codification debt at retro time) | Aligned: signal-driven matches the project's broader discipline of measurable triggers (per `docs/process/decisions-convention.md` §4 "every trigger must be machine-or-grep-checkable") |

The combination of (1) signal-driven over cadence-driven + (2) ≥3-of-5 calibrated to empirical sprint-11 floor + (3) producer override authority preserved + (4) recurring per-sprint evaluation as Trigger 1 makes the binding outcome **HYBRID with ≥3-of-5 signal trigger**, not EMBRACE-as-cadence and not RESERVE-as-stopgap.

## Why this satisfies the prior AI / retro mandate

The originating mandate is sprint-11 retro AI #6, captured verbatim in `production/sprint-status.yaml` line 31:

> **AI #6 NEW: Closure-mode sprint pattern decision (S12-07) — embraced / reserved / hybrid; feeds sprint-13 plan.**

The retro's "What Went Well" item 1 + "Velocity Analysis" §"Aggregate" provided the supporting data:

> **Doc-only sprint as a viable single-session execution pattern** — 11 stories shipped in ~0.5 calendar day with full /story-done + commit + push pipeline per story. Demonstrates that closure/admin sprints can be planned with confidence; they are not just "carryover absorption stopgaps" but a legitimate sprint mode.

> **Aggregate**: ~2.2d nominal → ~0.5d actual (-77% over-performance). Mixed-mode multiplier ÷3 was conservative for 100% closure/admin sprint; observed multiplier was ~÷4.4. Within the ±20% tolerance band of the projected ÷3 multiplier when accounting for 100%-closure-mode bias.

This decision satisfies AI #6 by:

- Selecting the third option from the AI's enumerated trinary (embraced / reserved / **hybrid**)
- Codifying the trigger criteria such that "feeds sprint-13 plan" becomes mechanical rather than judgment-based
- Establishing the recurring per-sprint evaluation (Trigger 1) so the decision continues to feed sprint-(N+1)+ plans automatically
- Preserving producer agency via the override path (per Trigger 2), respecting the data-driven discipline that produced the AI in the first place

The AI's "feeds sprint-13 plan" clause is operationalized by Trigger 4 — the `## Sprint Mode` section addition fires at the first post-decision `/sprint-plan` invocation, ensuring the decision shapes sprint-13 planning concretely rather than abstractly.

## Cross-references

- **Sprint-11 retrospective (originating)**: `production/retrospectives/retro-sprint-11-2026-05-08.md` §"What Went Well" item 1 + §"Velocity Analysis" §"Aggregate" + §"Sprint-12 Action Items" #6
- **Sprint-12 sprint plan**: `production/sprints/sprint-12.md` (S12-07 row) + `production/sprint-status.yaml` lines 30-31 (AI #6 NEW seed)
- **Sprint-10 retro AI #4 (velocity multiplier model)**: `production/retrospectives/retro-sprint-10-*.md` (÷3 mixed / ÷4 closure / ÷5 greenfield)
- **Sprint-9 retro AI #2 (carryover concentration threshold)**: `production/retrospectives/retro-sprint-9-*.md` (≥4 carryover threshold)
- **Process-decision convention**: `docs/process/decisions-convention.md` §3 template + §4 trigger discipline + §7 skill-route meta-decision
- **Companion future edit (Trigger 4)**: `.claude/skills/sprint-plan/SKILL.md` Phase 2 template — `## Sprint Mode` section addition
- **Velocity baseline data**: `production/sprint-status-history.md` Sprint 11 section (sprint-11 ÷4.4 actual) + Sprint 9 + Sprint 10 sections (closure-heavy ÷3.5 actual baseline)
- **Reactivation Trigger 1 monitoring**: producer at every `/sprint-plan` invocation; signal evaluation is the gate
- **Reactivation Trigger 2 monitoring**: producer at retro time; rolling 3-sprint override-divergence window
- **Reactivation Trigger 3 monitoring**: any retrospective amendment to velocity multiplier model
- **Reactivation Trigger 4 monitoring**: `.claude/skills/sprint-plan/SKILL.md` Phase 2 template — first post-decision invocation
- **Companion sprint-12 decisions**: `production/decisions/pillar-3-deferral-decision-2026-05-08.md` + `production/decisions/prototype-as-gate-sufficient-decision-2026-05-08.md` (gate-check path-to-PASS items 3a + 3b)
- **Convention §7 skill-promotion trigger**: `docs/process/decisions-convention.md` §7 (≥3 artifacts AND ≥2 distinct sprints — NOTE: this decision is the 4th artifact in `production/decisions/` and the 2nd distinct sprint origin (sprint-10 + sprint-12); §7 trigger has FIRED — separate retro AI candidate at sprint-12 retro for skill-promotion evaluation, NOT closed by this decision)

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-09 — Initial binding decision recorded (sprint-12 S12-07 close-out; closes sprint-11 retro AI #6).
