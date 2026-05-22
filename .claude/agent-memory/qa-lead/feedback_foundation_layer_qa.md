---
name: Foundation-layer epic QA pattern
description: For Foundation-layer epics with no playable runtime, collapse 7-phase team-qa to single sign-off pass; manual batches are no-ops; headless coverage is sufficient
type: feedback
---

For Foundation-layer epics (autoload nodes, data systems, pure logic with no playable UI), the standard 7-phase /team-qa cycle collapses to a single sign-off pass.

**Why:** Manual QA execution phases are no-ops when there is no runtime visualization. The orchestrator confirmed this pattern explicitly at sprint-9 sign-off. It mirrors 5 prior closures: damage-calc, hp-status, turn-order, grid-battle, battle-hud.

**How to apply:** When producing a QA sign-off report for a Foundation-layer epic:
1. Read the smoke check, QA plan, story files, and verification evidence — do not re-execute
2. Classify stories and verify evidence exists; skip manual batch walkthroughs
3. Polish-deferred items require physical hardware — document as APPROVED WITH CONDITIONS, not blockers
4. Write the report directly (autonomous mode for this project)
