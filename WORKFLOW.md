# Workflow Mode

> **Current mode**: Build, not Ratify
> **Activated**: 2026-05-10
> **Replaces**: Sprint-driven multi-agent process (the default this project was originally configured with)

This document is the **active** development workflow specification.
Where it conflicts with `.claude/docs/coordination-rules.md`, the
`production/` sprint artifacts, or any agent/skill orchestration
guidance, **this document wins**.

## What "Build, not Ratify" Means

Default to direct game-feature work. Read 1-2 files, implement, test,
summarize. Do NOT invoke sprint/gate/retro/story-state machinery.

### Active Tools (call freely as needed)

| Tool | When |
|---|---|
| `gameplay-programmer` | Game system implementation |
| `godot-gdscript-specialist` | Code quality review (post-implementation) |
| `game-designer` | New mechanism design questions |
| `qa-tester` | Test cases for completed features |
| `/quick-design` | ≤30-min design changes |
| `/code-review` | Optional, after ~50+ LOC |
| `/architecture-decision` | Genuinely irreversible technical choices |

### Dormant by Default (do NOT invoke unless user asks by name)

- `/sprint-plan`, `/sprint-status`, `/retrospective`
- `/qa-plan`, `/qa-signoff`, `/smoke-check`, `/gate-check`
- `/story-readiness`, `/story-done`
- All `team-*` orchestrators
- Codifying gotchas as separate AIs (inline `# G-NN: …` comment is enough)
- Tracking POLISH-NNN / carryover concentration / §11 HARD GATE / retro AIs

### Commit Messages

Plain feature descriptions. Do NOT prefix with sprint IDs (e.g.
`feat(sprint-15): S15-J POLISH-012 closure`). Use short, intention-led
messages: `feat: chapter 2 + branch override`.

## Why the Switch (2026-05-10 diagnosis)

The project had accumulated:

- 49 agents / 72 skills / 280 production docs / 198 .claude docs
- 15 sprints in 6 weeks, 12 retrospectives, 9 gate-checks
- Sprint goal "flip `production/stage.txt` Pre-Production → Production"
  (a *meta*-goal, not a player-facing goal)
- POLISH-011 "absorbed" across 3 stories with 4 production-wiring
  residuals still unfixed (clicks did not work in the actual game)
- Meta-rules tracking meta-rule violations (carryover concentration
  thresholds, refusal-to-fabricate posture invocation counts, etc.)

The user could no longer tell whether a game was being built or whether
process was building itself. Mode switched to focus on player-facing
features.

In the ~2-hour session that activated this mode, the team shipped:
- Chapter 2 (장판교) added to the scenario
- `branch_overrides` system (chapter 1 outcome shapes chapter 2 deployment)
- 4 production-wiring fixes that finally closed POLISH-011 (game now
  responds to clicks end-to-end)
- Selection visual highlight on the grid

See commit `61197c2` and the prior chapter-2 + branch commits for the
concrete changeset.

## What Was Preserved (NOT deleted)

These directories are intact and can be reactivated:

- `production/` — sprints, retros, gate-checks, ADRs, qa-plans
- `.claude/agents/` — 49 specialist agent definitions
- `.claude/skills/` — 72 skill definitions
- `.claude/rules/` — godot-4x-gotchas, tooling-gotchas, test-standards, etc.

Reactivation = update this file's "Current mode" line and start invoking
the dormant tools. No restoration step needed.

## Per-Session Memory

Claude Code keeps a separate per-project memory file (outside this repo)
that auto-loads in every future session and enforces the current mode in
agent behavior. **This `WORKFLOW.md` is the human-readable mirror** of
that memory. Keep the two in sync if either is edited; if they ever
disagree, this file is canonical and the memory should be updated to
match.
