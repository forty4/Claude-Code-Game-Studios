# Epic: Chapter Prototype Demo (Pillar 4 Atmospheric Moment)

> **Status**: In Progress (1 story planned)
> **Layer**: Demo (prototype-isolated; not production)
> **Created**: 2026-05-08 (S12-02 sprint task)
> **Sprint**: sprint-12 (Must-Have)
> **Closes**: gate-check 2026-05-08 path-to-PASS item 3

## Overview

Demo epic covering implementation slice that demonstrates Pillar 4 (삼국지의 숨결)
atmospheric moment in `prototypes/chapter-prototype/`. Scoped to REWRITTEN
branch only; production `src/scenario/` integration deferred to when production
scenario runner exists.

## Scope

**In**: `prototypes/chapter-prototype/chapter.gd` + `chapter.tscn` + `REPORT.md`
update + `tests/integration/chapter_prototype/atmospheric_moment_test.gd`.

**Out**: production code, full Beat 7 visual surface (반신 portrait, 묵 dark panel,
ink-wash 번짐 wipe), asset-commissioned audio, color-blind alternative treatment.

## Design Source

`design/quick-specs/chapter-prototype-pillar-4-atmospheric-moment-2026-05-08.md`
(quick-spec; type Addition; no GDD update required — atmospheric behavior fully
spec'd in `design/gdd/scenario-progression.md` §V.3 + AC-SP-7/9 + `design/gdd/destiny-branch.md`
Player Fantasy).

## Governing ADRs

None. Prototype-isolated per `.claude/rules/prototype-code.md`. Production
scenario runner integration will be governed by ADR-0017 when authored.

## Engine Risk

LOW. `AudioStreamGenerator` is a stable Godot API (pre-cutoff); ColorRect +
tween are stable; modulate-α animation is stable. No post-cutoff API usage.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Pillar 4 atmospheric moment dispatch on REWRITTEN | Integration | Ready | None (prototype) |

## Pillar Coverage

- **Pillar 4 (삼국지의 숨결)** — primary; atmospheric moment is the canonical Pillar 4 payoff per `destiny-branch.md` Player Fantasy
- **Pillar 2 (운명은 바꿀 수 있다)** — supporting; REWRITTEN branch is the player-rewriting-history fate
