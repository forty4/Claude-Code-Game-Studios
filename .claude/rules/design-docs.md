---
paths:
  - "design/gdd/**"
  - "design/quick-specs/**"
---

# Design Document Rules

- Every design document MUST contain these 8 sections: Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria
- Formulas must include variable definitions, expected value ranges, and example calculations
- Edge cases must explicitly state what happens, not just "handle gracefully"
- Dependencies must be bidirectional — if system A depends on B, B's doc must mention A
- Tuning knobs must specify safe ranges and what gameplay aspect they affect
- Acceptance criteria must be testable — a QA tester must be able to verify pass/fail
- No hand-waving: "the system should feel good" is not a valid specification
- Balance values must link to their source formula or rationale
- Design documents MUST be written incrementally: create skeleton first, then fill
  each section one at a time with user approval between sections. Write each
  approved section to the file immediately to persist decisions and manage context

## Pre-Flight Checklist (run BEFORE drafting any new spec)

Codified S85 from 3 stable instances of spec-authoring traps caught LATE
(ch05 §8 OQ-9 Pillar 2 lock violation found at S81 visualization time, not
S79 spec time; ch08 §3.3 substrate field name `turn_count` vs actual
`win_within_turns` found at S82 impl time, not S82 spec time; ch10 §3.1
substrate add — inverse case where field needed to be created). All three
would have been silent bugs (or 3-doc revision forces) if not caught by
chance before impl.

These 3 checks MUST run before the first `## 1. Change Summary` keystroke:

1. **Pillar lock + critical lint inventory**:
   ```bash
   grep -l 'Pillar\|CRITICAL\|KEEP forever' \
       docs/architecture/ADR-*.md tools/ci/lint_*.sh
   ```
   Open each result. If the spec touches the domain that lint guards (e.g.
   BattleHUD + Pillar 2 fate visualization), enumerate the forbidden patterns
   in the spec's §3 or §4 and design around them — NOT through them. A spec
   that proposes anything a CRITICAL lint forbids will fail at impl time with
   "3-doc revision required" — the cheapest fix is to redesign the spec.

2. **fate_data emit substrate verification** (when spec touches DestinyBranch
   ★ trigger or any `hidden_condition.field`):
   ```bash
   # Does the field name you're about to write into hidden_condition actually
   # exist as an emitted fate_data field?
   grep -n '"<expected_field_name>":' \
       src/feature/grid_battle/grid_battle_controller.gd
   ```
   - If found: substrate is wired, spec can lock the field name as-is.
   - If absent: pick from the EXISTING `fate_data` emit list (preferred —
     no production code change), OR add the field via spec §3 "Substrate
     add" subsection (ch10 model, S84 reference). Never write a spec that
     names a field which doesn't exist + doesn't have an §3 add subsection.

3. **Recommended path framing for design questions**: when authoring decisions
   require user input, present a SINGLE recommended path with concise rationale
   + 3-option confirm (yes / partial-change / clarify). Avoid AskUserQuestion
   stacks that present multiple option grids — the cognitive load makes choices
   feel undifferentiated. S82 mid-session feedback codified this — see active.md
   S82 §"AskUserQuestion fatigue mitigation".

Failure to run these 3 checks before spec authoring has cost ~30-90 min per
instance across 3 chapters (ch05 / ch08 / ch10). Running them costs ~2-5 min.
The ROI heavily favors the pre-flight discipline.
