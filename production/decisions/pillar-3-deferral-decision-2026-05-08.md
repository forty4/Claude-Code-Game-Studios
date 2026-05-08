# Decision: Pillar 3 (영웅의 차이가 만드는 흐름) Dedicated Player-Facing Demonstration — DEFER TO ORGANIC EMERGENCE

> **Status**: BINDING (sprint-12 S12-03 close-rerun; closes gate-check 2026-05-08-rerun path-to-PASS item 3b)
> **Decision Date**: 2026-05-08
> **Author**: claude (sprint-12 S12-03 close-rerun owner; per gate-check 2026-05-08-rerun §6 Item 3b Route B mandate)
> **Reactivation Owner**: producer (at next gate-check pass; concurrent with Polish-stage approach + VS playtest reports)

---

## Decision

**Pillar 3 (영웅의 차이가 만드는 흐름 — "the flow that hero differences create") is deferred from a dedicated player-facing demonstration story to organic emergence across MVP play.**

Pillar 3's experiential validation is satisfied by the cumulative-distinguishability of multi-system substrate already shipped (unit-role 10/10 Complete + hero-database 5/5 Complete + damage-calc Designed + formation-bonus Designed + AI-system 1/1 Complete) rather than by a single dedicated demonstration story. The Pre-Production → Production gate-check accepts this deferral as the closure path for path-to-PASS item 3b (CD-refined from the AM gate-check's broader item 3 split into 3a + 3b at the 2026-05-08 PM rerun).

This is a **deferral with explicit reactivation triggers** — Pillar 3 demonstration is NOT cancelled; if the substrate fails to emerge as player-distinguishable across VS playtest data or Polish-stage observation, this decision re-opens with a binding sprint task.

## Why defer-to-organic-emergence (and not author dedicated demo now)

Four load-bearing reasons:

1. **Pillar 3 is fundamentally a cumulative-distinguishability pillar, not a moment pillar.** Per `design/gdd/game-concept.md` Pillar 3 wording, the experiential target is "the player feels how 조운's role-asymmetry creates a different battle flow than 장비's" — this is observed across **multiple encounters** as the player's mental model accumulates, not at a single ceremonial beat. Compare to Pillar 4 (삼국지의 숨결 — 운명 분기 ceremonial witness) which IS a moment pillar. Authoring a single dedicated demonstration story for Pillar 3 would risk reducing the design intent to a single moment when the substrate's load-bearing effect is its **multi-encounter accumulation**. The single-story demonstration fails the design honesty test.

2. **Pillar 3 substrate is mechanically present and playable.** unit-role 10/10 Complete (cost matrix + direction multiplier + 6 derived-stat methods + passive tags) + hero-database 5/5 Complete (459 LoC + 9-record MVP roster heroes.json + Peach Garden Oath bond + 3-pass validation) + damage-calc Designed (rev 2.9.3 APPROVED; 12 apex cells <180 with Pillar-1+3 hierarchy preserved) + formation-bonus Designed (v1.1 APPROVED; LORD_VASSAL relationship + 4 patterns × 4 relationships) + AI-system 1/1 Complete (4 archetypes per CR-AI-3) — together these systems provide **distinguishable hero behavior** across encounters: 조운 (CAVALRY archetype + 5pts dominant ATK + Charge passive) plays measurably differently from 장비 (RUSHER archetype + 6pts dominant ATK + REAR position) which plays measurably differently from 관우 (COMMANDER archetype + 90 dominant command). The flow difference IS in the code; what's missing is dedicated player-facing **framing** of the difference, not the difference itself.

3. **Dedicated demonstration story risks scope creep with low marginal verification value.** A "Pillar 3 demonstration story" would require either (a) a chapter-1 narrative beat tied to specific hero choices (~1d nominal authoring + Story Event GDD #10 substrate which is currently a stub), OR (b) a forced "lab encounter" where two heroes face the same mock-enemy and the player observes the flow difference (~0.5d nominal but contrived). Both options fail the design intent test (Pillar 3 is cumulative, not isolated). The verification value is **lower than letting VS playtest data surface the dynamics organically** — and VS playtest is already required by the gate as a separate path-to-PASS item (S7-11/S12-10 USER-OWNED 4 VS Validation items). Doubling up — authoring a dedicated demo AND requiring VS attestation — burns sprint budget without raising the verification bar.

4. **4-pattern-stable CONCERNS resolution requires unblocking the gate without inverting the design model.** The Pre-Prod → Production gate-check has held at CONCERNS across 4 consecutive invocations with the same 3× READY + 1× CONCERNS-CD shape. Forcing a Pillar 3 dedicated demonstration story would (a) commit sprint-12 day-2+ scope to a low-value story, (b) precommit sprint-13 by adding Story Event GDD #10 authoring as a prerequisite, and (c) misrepresent Pillar 3's design intent as moment-anchored. Accepting deferral-to-organic-emergence unblocks Production stage flip eligibility while preserving design integrity. The CD-side concern ("Pillar 3 received no movement this cycle") is acknowledged: but "no movement this cycle" is the correct state for a cumulative-distinguishability pillar that already has MVP substrate — additional substrate work without VS playtest signal is premature optimization.

## What is NOT being decided here

This decision does NOT:

- Cancel Pillar 3 verification permanently. VS playtest data is the canonical verification mechanism — captured via S7-11 USER attestation (4 VS Validation items) + future `/playtest-report` runs. The decision binds **dedicated story authoring**, not gate-elgibility-to-Polish or verification monitoring.
- Reduce the substrate completeness bar. unit-role + hero-database + damage-calc + formation-bonus + AI-system ALL must remain mechanically distinguishing (per their respective Acceptance Criteria + post-cutoff API regression suite). Any sprint that touches these systems without preserving Pillar 3 substrate behavior re-opens this decision.
- Override the gate-check's experiential validation requirement. The decision narrows the path-to-PASS item 3b closure to "deferral documented" rather than "story shipped"; the broader VS playtest gate (items 1+2) is unaffected.
- Affect Pillar 4 (삼국지의 숨결) demonstration. Pillar 4 is moment-anchored (운명 분기 ceremonial witness) and is governed separately by `prototype-as-gate-sufficient-decision-2026-05-08.md` — a different decision artifact with different reactivation triggers.
- Affect the gate-check verdict at THIS rerun. The 2026-05-08-rerun verdict remains CONCERNS — this decision closes ONE of 4 path-to-PASS items (3b). Items 1 + 2 + 3a are governed elsewhere.

## Reactivation Triggers

This decision **automatically re-opens** when any one of the following becomes true:

### Trigger 1 — Polish-stage gate-check approaches AND VS playtest data shows Pillar 3 dynamics fail to emerge

The Polish-stage gate-check requires playtest validation of all 4 pillars per the existing gate definition (`.claude/skills/gate-check/SKILL.md` §"Production → Polish"). If VS playtest data — captured via `/playtest-report` or recorded in `production/playtests/` — shows that players cannot distinguish the flow created by hero differences, this decision is overturned and a dedicated demonstration story becomes Must-Have for the smallest containing sprint.

**Signal**: any file under `production/playtests/` contains playtest feedback whose paragraph includes both (a) the literal substring `Pillar 3` OR `hero difference` OR `flow difference`, AND (b) negative framing (e.g., "didn't notice," "felt the same," "couldn't tell," "all heroes feel similar," "differences didn't matter"). The `/playtest-report` skill should explicitly check for Pillar 3 emergence per playtester observations.

**Required action when fired**: producer immediately escalates to creative-director for re-rating; this decision is amended with the playtest reference + may be superseded by a new file `pillar-3-dedicated-demo-decision-{date}.md` whose binding outcome is "AUTHOR DEDICATED STORY"; the next sprint's plan adds a Pillar 3 demonstration story as Must-Have.

### Trigger 2 — A unit-role + hero-database + damage-calc regression touches the substrate

Pillar 3's substrate is the cross-system interaction of unit-role + hero-database + damage-calc + formation-bonus + AI-system. If a future sprint task modifies any of these systems in a way that reduces hero-distinguishability (e.g., flattening role multipliers, removing dominant-stat differentiation, reducing archetype coverage), this decision is re-opened to verify the substrate still satisfies the deferral's load-bearing reason 2.

**Signal**: any commit message in the project-root git log contains the literal substring `Pillar 3 substrate change` OR a sprint plan adds a story whose acceptance criteria explicitly modifies the unit-role × damage-calc multiplier matrix, formation-bonus per-unit cap, hero-database dominant-stat schema, or AI-archetype dispatch.

**Required action when fired**: sprint task auto-flags as Pillar 3 substrate-affecting; the next gate-check pass re-evaluates whether the modified substrate still preserves cumulative-distinguishability (specifically: does the system still allow the apex 12-cell hero-class-direction matrix to maintain meaningful differentiation under all modifier combinations?).

### Trigger 3 — Story Event GDD #10 (chapter-1 narrative beat substrate) is authored

When `design/gdd/story-event.md` (currently a stub per active.md task TODO-04 reference + sprint-12 S12-05 TODO triage) advances to Designed status with chapter-1 narrative beat content, the cost-side calculus for option (a) of "force dedicated demonstration story" changes — the prerequisite substrate now exists. This decision is re-opened to verify whether to ship a Pillar 3 narrative beat as a follow-on story to Story Event GDD #10 authoring.

**Signal**: `design/gdd/story-event.md` Status header changes from "Not Started" / "Draft" to "Designed" OR a `/design-review` verdict for `story-event.md` lands as APPROVED.

**Required action when fired**: producer adds Pillar 3 narrative beat as a Should-Have story in the sprint immediately following Story Event GDD #10 close-out; this decision is amended noting the substrate prerequisite is met + the deferral has reduced cost.

### Trigger 4 — Pre-Prod → Production stage flip happens AND no Pillar 3 demonstration has been added

When `production/stage.txt` flips to `Production` (per gate-check Phase 6 protocol), the next sprint plan must explicitly acknowledge whether Pillar 3 demonstration is being further deferred, and the deferral decision must be re-confirmed.

**Signal**: `production/stage.txt` content changes from `Pre-Production` to `Production`.

**Required action when fired**: producer confirms continued deferral in the next sprint plan + amends this decision noting the stage flip + continued deferral rationale; OR producer adds a Pillar 3 demonstration story as Must-Have for the first Production-stage sprint and this decision is superseded.

## Dependency on User Actions

None at decision-closure time. This decision is fully claude-side and does NOT require user attestation, user-paid prerequisites, or user-only credentials for closure.

The reactivation triggers above include user-action conditions (e.g., a playtest report authored by user observation) but those are reactivation-time obligations, not closure-time prerequisites.

## Cost-Benefit Summary

| Factor | Author dedicated Pillar 3 demo story now | Defer-to-organic-emergence (decided outcome) |
|---|---|---|
| Sprint budget impact | 0.5-1.5d (option (a) chapter-1 narrative beat: 1d + Story Event GDD #10 authoring prerequisite ~0.5d; option (b) lab encounter: 0.5d standalone) | 0d additional (decision is doc-only at ~0.05d this sprint) |
| Verification value pre-VS | Low: a single dedicated demonstration cannot validate cumulative-distinguishability that emerges across multiple encounters; option (b) lab encounter is contrived; option (a) requires Story Event GDD #10 substrate which is a stub | Identical or higher: VS playtest data captures cumulative-distinguishability across natural play sequences; this is the canonical Pillar 3 verification mechanism |
| Verification value post-VS | Same as deferral: the dedicated demo's value is bounded by VS playtest interpretation regardless of whether the demo exists | High: VS playtest data IS the verification; deferral preserves the canonical mechanism |
| Risk to current baseline | Medium: scenario-progression epic is Complete (1/1) but adding chapter-1 narrative beat to chapter-prototype OR creating new lab-encounter scene risks regression to 1273/1273 PASS baseline + may inadvertently bind sprint-13 scope | Zero: 1273/1273 PASS baseline preserved; this decision adds doc only |
| User-action prerequisite | Possibly: option (a) requires user playtest validation of the narrative beat post-authoring | None at closure; reactivation triggers may require user playtest input later |
| Pattern alignment | Forces moment-anchored treatment of a cumulative-distinguishability pillar — inverts design model | Aligned: cumulative-distinguishability pillars are organically validated across MVP play; gate accepts substrate completeness as evidence that the pillar will emerge |
| Design integrity | At risk: dedicated story risks reducing Pillar 3 to a single moment | Preserved: deferral honors the multi-encounter accumulation design intent |

The combination of (1) zero current-sprint cost + (2) preservation of design intent + (3) verification value bound by VS playtest regardless + (4) reactivation-trigger-anchored re-evaluation if substrate fails to emerge makes the binding outcome **defer-to-organic-emergence**, not author-dedicated-demo-now.

## Why this satisfies the prior AI / retro mandate

The originating mandate is gate-check 2026-05-08-rerun §6 Item 3b:

> **Item 3b NEW**: ≥1 Pillar 3 player-facing beat OR documented deferral with rationale. Pillar 3 received no movement this cycle.

This decision satisfies the OR branch of Item 3b's binary: "documented deferral with rationale." The rationale is articulated in §"Why defer-to-organic-emergence" with 4 load-bearing reasons + the §"Cost-Benefit Summary" table comparing both branches.

The CD-side concern raised at gate-check rerun ("Pillar 3 received no movement this cycle") is acknowledged in §"Why defer-to-organic-emergence" reason 4 + addressed via Trigger 1 (Polish-stage gate-check FAIL if VS playtest data shows Pillar 3 dynamics fail to emerge). The decision does not dismiss CD's concern; it reframes the verification mechanism (VS playtest data is canonical, dedicated demo is not) + bounds the deferral by an explicit re-evaluation trigger.

Per `docs/process/decisions-convention.md` §1, this decision is **not** an architectural choice — it is a SCOPE decision about what counts as Pillar 3 verification mechanism + which sprints are obligated to ship Pillar 3 demonstration story. The convention directs SCOPE decisions to `production/decisions/` rather than `docs/architecture/ADR-NNNN-*.md`.

## Cross-references

- **Gate-check rerun (originating)**: `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` §6 Item 3b + §10 Action Summary
- **Pillar 3 substrate (load-bearing reason 2)**:
  - `production/epics/unit-role/EPIC.md` (10/10 Complete 2026-04-28)
  - `production/epics/hero-database/EPIC.md` (5/5 Complete 2026-05-01)
  - `design/gdd/damage-calc.md` (rev 2.9.3 APPROVED 2026-04-28)
  - `design/gdd/formation-bonus.md` (v1.1 APPROVED 2026-04-20)
  - `production/epics/ai-system/EPIC.md` (1/1 Complete 2026-05-07)
  - `assets/data/heroes/heroes.json` (9-record MVP roster)
- **Pillar 3 design intent**: `design/gdd/game-concept.md` Pillar 3 wording + `design/gdd/systems-index.md` Pillar 3 substrate row mappings
- **VS verification mechanism**: `prototypes/vertical-slice/REPORT.md` (S7-11 4 VS Validation items USER-OWNED carryover)
- **S7-11 USER-OWNED carryover**: tracked as S12-10 in `production/sprint-status.yaml`; 5th-time carry as of sprint-12 entry (project-record carryover)
- **Story Event GDD #10 (Trigger 3 prerequisite)**: `design/gdd/story-event.md` (currently stub; authored substrate prerequisite for option (a) dedicated narrative beat story)
- **Decisions convention**: `docs/process/decisions-convention.md` (ratifies Route c for SCOPE decisions)
- **Reactivation Trigger 1 monitoring**: `production/playtests/` directory + future `/playtest-report` invocations
- **Reactivation Trigger 4 monitoring**: `production/stage.txt` (when content flips to `Production`)
- **Sprint plan**: `production/sprints/sprint-12.md` S12-03 row
- **Companion decision (Item 3a)**: `production/decisions/prototype-as-gate-sufficient-decision-2026-05-08.md`

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-08 — Initial binding decision recorded (sprint-12 S12-03 close-rerun close-out; closes gate-check 2026-05-08-rerun path-to-PASS item 3b).
