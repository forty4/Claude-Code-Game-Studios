# Vertical-Slice Prototype — Battle

> **PROTOTYPE — NOT FOR PRODUCTION.**
> Author: 2026-05-02 (sprint-3 close-out, post-S3-06).
> Question: Does the existing backend feel like an actual battle game when wired together with placeholder visuals?

## How to run

1. Open Godot 4.6 editor on this project
2. In the FileSystem dock, navigate to `prototypes/vertical-slice/`
3. Double-click `battle.tscn` to open it
4. Press **F6** (Run Current Scene) — NOT F5 (Run Project)
   - F5 would try to launch `project.godot`'s `main_scene` (which is unset; sprint-3 work is unaffected)

## What you'll see

- **8×6 colored grid** — green (plains), dark green (forest), brown (hills), blue (river — impassable)
- **4 units** — 2 blue (player: 유비, 관우) + 2 red (enemy: 여포, 동탁); each shows a Korean name label + HP bar
- **HUD** below the grid — turn counter, selected unit stats, action log

## How to play

| Action | How |
|---|---|
| Select your unit | Click a blue unit (only on player turn) |
| Move | After selecting, click a brightened tile (within move range, non-river, unoccupied) |
| Attack | After selecting, click a red-highlighted enemy (must be 1-tile adjacent — melee only in prototype) |
| Deselect | Click your selected unit again |
| End your turn | (No explicit end-turn button — every move OR attack consumes the player turn; AI then runs all its units) |

## What's intentionally missing (per prototype scope)

- Real sprites — placeholder ColorRect + Label only
- Sound — none
- Animations beyond simple position/color tween
- Pathfinding — Manhattan distance only
- Real input handling (no InputRouter — uses raw `_input(event)`)
- Real damage formula (uses simplified `max(1, ATK - DEF - terrain_bonus)`, not ADR-0012's 4-stage pipeline)
- Real turn order (uses simple side-toggle, not TurnOrderRunner's initiative cascade)
- Real save/load
- Real character data loading (units hardcoded inline, no HeroDatabase JSON parse)
- Multiple scenarios (single hardcoded map)
- Camera controls (fixed)
- Magnifier panel / TPP / undo / etc. from input-handling GDD
- Status effects from hp-status epic

## Why the prototype skips production wiring

Per `.claude/skills/prototype/SKILL.md`:
- Prototype code must NEVER `preload`/`load` from `src/`
- Production code must NEVER `preload`/`load` from `prototypes/`
- If recommendation is PROCEED, the production implementation will be written from scratch — this prototype is throwaway

The 8 backend systems already shipped in `src/` (TurnOrderRunner, HPStatusController, DamageCalc, HeroDatabase, MapGrid, TerrainEffect, UnitRole, BalanceConstants) prove the math/state is sound. This prototype answers the **separate** question: is wiring them up to a visible scene the missing piece, or do we need to redesign the loop?

## Next steps

After running, see `REPORT.md` for findings + PROCEED/PIVOT/KILL recommendation.
