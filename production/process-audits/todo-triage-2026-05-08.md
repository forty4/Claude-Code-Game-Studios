# TODO Triage Pass — 2026-05-08

> **Sprint**: sprint-11 S11-11 (closes sprint-10 retro AI #6 — TODO count stalled at 5 for 2 consecutive sprints)
> **Author**: claude
> **Scope**: All TODO/FIXME markers in `src/` (per `grep -rn "TODO\|FIXME" src/`)
> **TODO count**: 5 TODO + 0 FIXME (matches CLAUDE.md session-start health snapshot 2026-05-08)

---

## Triage Disposition Summary

| Disposition | Count | IDs |
|---|---|---|
| **Address** (sprint-12 candidate work; surface remains) | 2 | TODO-04, TODO-05 |
| **Defer-with-context** (forcing function present; keep marker) | 2 | TODO-01, TODO-03 |
| **Remove** (stale doc reference; trivial cleanup) | 1 | TODO-02 |

**Net sprint-12 actions**: 2 Address (small surface; ~0.1d each); 1 Remove (trivial; can be batched into any sprint-12 close-out commit). Defer-with-context items remain in src/ until their forcing function fires.

**Carryover risk**: After sprint-12 cleanup, the count drops 5 → 2 (the 2 Defer items remain). Below the AI #6 visibility threshold (≥5 stalled across 2 sprints).

---

## TODO-01 — `src/core/map_grid.gd:915` — Plain Dijkstra (no admissible heuristic)

**Disposition**: **Defer-with-context** — Polish-tier perf hardening with explicit forcing function

**Source line**:
```gdscript
# TODO (story-007 / AC-PERF-2): plain Dijkstra — no admissible heuristic
# lower-bound applied. ADR-0004 §Decision 7 recommends a Manhattan-distance
# heuristic for `get_movement_path`. Correctness is unaffected; performance
# delta only matters at the 40×30 m=10 benchmark scale (TR-map-grid-006).
```

**Why defer**:
1. **Correctness unaffected** — the comment explicitly says so. The existing plain-Dijkstra implementation produces correct paths; only the perf differs from the ADR-recommended A*-with-Manhattan-heuristic shape.
2. **Forcing function is a benchmark threshold, not a deadline** — TR-map-grid-006 + AC-PERF-2 specify a 40×30 grid + m=10 movement reach as the perf benchmark. MVP gameplay does NOT exercise that scale (chapter-1 MVP scenarios use ≤20×15 grids per `design/gdd/scenario-progression.md` chapter sizing).
3. **No spec-drift risk** — the TODO references a specific ADR-0004 §Decision 7 source and a specific AC-PERF-2 owner; those references are stable. When the perf benchmark is invoked at Polish phase, the work has clear scope.

**Why not address now**: budget — A* refactor with Manhattan heuristic is ~0.5-1d; not worth pulling forward when current implementation passes all existing AC and no consumer hits the perf cliff.

**Forcing function**: `tests/integration/core/map_grid_perf_test.gd` (or equivalent) FAILS on the 40×30 m=10 benchmark, OR Polish-phase perf-profile pass identifies `get_movement_path` as a bottleneck.

**Action when fired**: implement A*-with-Manhattan-heuristic per ADR-0004 §Decision 7; remove this TODO; add the perf-test gate to CI.

**Cross-references**:
- ADR-0004 §Decision 7 (path-finding heuristic recommendation)
- TR-map-grid-006 + AC-PERF-2 in map-grid epic story-007
- Polish-tier candidate (consider moving to `production/polish-backlog.md` as POLISH-006 if Polish-tier tracking is preferred over inline TODO; sprint-12 producer call)

---

## TODO-02 — `src/core/save_manager.gd:200` — Stale "see TODO below" doc reference

**Disposition**: **Remove** — trivial doc cleanup

**Source line** (in docstring describing `load_latest_checkpoint()` flow):
```gdscript
##   6. Return ctx (migration shim — see TODO below)
```

**Why remove**:
1. **No corresponding TODO exists in the function body**. The docstring promises a "TODO below" that the reader cannot find. The function (lines 201-210) is complete — `return SaveMigrationRegistry.migrate_to_current(ctx)` IS the migration step the doc was forward-referencing.
2. **The migration shim is implemented**, not pending. `SaveMigrationRegistry.migrate_to_current(ctx)` was shipped in save-manager epic story-006 (Complete 2026-04-24). The "shim" descriptor is also stale — the registry is a fully-formed pure-function migration chain per CR-SL-13.
3. **The TODO marker is a false signal** — it inflates the project's TODO count without representing actual deferred work.

**Action**: edit the line to remove the "see TODO below" parenthetical. Replace with a direct description of what the step does:

```gdscript
##   6. Return migrated ctx (migration applied via SaveMigrationRegistry per CR-SL-13)
```

**Estimated effort**: <2 minutes; trivial doc edit.

**Cross-references**:
- save-manager epic story-006 (migration registry shipped)
- ADR-0003 §Schema Stability §Migration Callable Purity (CR-SL-13)
- save-load.md GDD §3.4 CR-SL-13 (consumer contract)

---

## TODO-03 — `src/core/payloads/beat_cue.gd:6` — Story Event GDD #10 stub schema

**Disposition**: **Defer-with-context** — explicit upstream-epic forcing function

**Source line**:
```gdscript
## TODO: shape locked by Story Event GDD #10 — replace stub with authoritative schema when epic lands.
```

**Why defer**:
1. **Forcing function is precise** — Story Event System #10 epic acceptance triggers replacement.
2. **Stub purpose is structural** — the BeatCue Resource exists ONLY so `game_bus.gd` declarations parse for the `beat_visual_cue_fired` + `beat_audio_cue_fired` signals. Removing the stub now would break game_bus.gd parse; replacing it speculatively risks ADR-0001 amendment churn.
3. **No spec-drift risk** — pegged to GDD #10 authoritative schema. When the GDD lands, this stub is replaced atomically with the GDD's schema definition.

**Why not address now**: Story Event System #10 GDD is currently **Designed** at `design/gdd/story-event.md` (per `design/gdd/systems-index.md`) but no implementation epic exists yet. Replacing the stub schema requires the implementation epic to define field names + types — premature without that epic.

**Recommendation**: reformat the TODO line to standardize the format with TODO-04/05 (story-anchor in parens):

```gdscript
## TODO(story-event-epic): replace stub Resource with authoritative BeatCue schema from Story Event System #10 GDD when implementation epic lands.
```

**Forcing function**: `/create-epics story-event` (or equivalent) is run; first BeatCue-shape-touching story enters /story-readiness.

**Action when fired**: replace the stub with the GDD-locked field set. Update game_bus.gd signal type binding if signature changes. Run /architecture-decision if it touches ADR-0001 contract.

**Cross-references**:
- `design/gdd/story-event.md` (GDD #10; Designed status)
- `design/gdd/systems-index.md` row 10 (Story Event System tier + status)
- `src/core/game_bus.gd` (consumer of BeatCue type via `beat_visual_cue_fired` + `beat_audio_cue_fired` signals)

---

## TODO-04 — `src/feature/grid_battle/grid_battle_controller.gd:342` — `get_battle_state_snapshot()` empty stub

**Disposition**: **Address** (sprint-12 candidate)

**Source line** (in stub method `get_battle_state_snapshot()`):
```gdscript
## Returns an opaque snapshot of battle state for AI consumer (Battle AI ADR).
## Shape is intentionally unspecified at MVP; callers must not rely on field names.
func get_battle_state_snapshot() -> Dictionary:
    # TODO(story-003+): populate FSM state, unit positions, acted flags
    return {}
```

**Why address**:
1. **The TODO's premise is obsolete** — the method was scaffolded in sprint-5 grid-battle-controller story-003 era as a provisional AI consumer hook. AI System epic (Complete 2026-05-07; ADR-0019 Accepted 2026-05-05) shipped with its OWN typed snapshot mechanism: `BattleStateSnapshot` Resource + `_make_battle_state_snapshot()` helper at `grid_battle_controller.gd` (different from this `get_battle_state_snapshot()` Dictionary stub).
2. **The stub is unused by AISystem** — AISystem reads via the typed `BattleStateSnapshot` flow, not via this Dictionary-returning method. `grep -n "get_battle_state_snapshot" src/` confirms no production caller exists.
3. **Risk of leak** — the method exists in the public API surface and may attract speculative use by future code that doesn't realize AISystem uses a different mechanism. Removing or clarifying it is the safe call.

**Recommended fix** (sprint-12 candidate, ~0.1d):

Option A — **remove the method entirely** (preferred). It's unused and confuses future readers about the AI snapshot pathway. AISystem story-001 verification summary should already note `BattleStateSnapshot` is the authoritative type.

Option B — **clarify + leave the stub** if a future debug-tool consumer is anticipated. Replace the docstring + remove the TODO:

```gdscript
## Debug-only Dictionary snapshot of battle state. Intended for future debug-tooling consumers.
## NOT used by AISystem — AISystem reads via typed BattleStateSnapshot per ADR-0019.
## Field names are unstable; do not depend on them.
func get_battle_state_snapshot() -> Dictionary:
    return _build_debug_snapshot()
```

**Recommendation**: Option A (remove). The stub has zero callers and zero forcing function for keeping it.

**Cross-references**:
- ADR-0019 (AISystem ADR; defines typed BattleStateSnapshot pathway)
- AISystem epic story-001 verification summary
- ADR-0014 §8 (GridBattleController LOCAL signals; `ai_action_requested(unit_id, snapshot: BattleStateSnapshot)` — the typed alternative)

---

## TODO-05 — `src/feature/grid_battle/grid_battle_controller.gd:424` — Stale "reset per-turn acted flag" TODO

**Disposition**: **Address** (sprint-12 candidate; trivial removal)

**Source line** (in `_on_unit_turn_started`):
```gdscript
func _on_unit_turn_started(unit_id: int) -> void:
    # TODO(story-006): reset per-turn acted flag for this unit
    # Per ADR-0019 + grid-battle.md CR-3: AI-turn detection + ai_action_requested emission.
    # When the active turn unit is non-player-controlled, emit ai_action_requested
    # so that AISystem (battle-scoped Node 6th invocation) can produce an action.
    if _battle_over:
        return
```

**Why address**:
1. **The TODO is stale by design-evolution** — the comment claims "reset per-turn acted flag for this unit" was needed inside `_on_unit_turn_started`. The actual implementation (verified via `grep -n "_acted_this_turn"`) uses **round-end bulk clear** at line 357 (`_acted_this_turn.clear()`) inside the round-end handler, NOT per-turn-start per-unit reset. The bulk-clear semantic is correct + sufficient + already shipped.
2. **The TODO header line conflicts with the body comment immediately below it** — the body comment correctly describes the AI emission behavior (per ADR-0019 + grid-battle.md CR-3), which IS what the function does in its post-guard body. The TODO is a leftover from a sprint-5/6 design pass that didn't land.
3. **Removing it is a 1-line edit** — drop the TODO line; the surrounding comment + `_battle_over` guard remain unchanged.

**Recommended fix** (sprint-12 candidate, <5 minutes):

Delete just line 424:

```gdscript
func _on_unit_turn_started(unit_id: int) -> void:
    # Per ADR-0019 + grid-battle.md CR-3: AI-turn detection + ai_action_requested emission.
    # When the active turn unit is non-player-controlled, emit ai_action_requested
    # so that AISystem (battle-scoped Node 6th invocation) can produce an action.
    if _battle_over:
        return
```

**Verification after removal**: full test suite green (no behavioral change; the TODO was a comment, not a production code path).

**Cross-references**:
- `_acted_this_turn.clear()` at line 357 (the actual implementation of round-end bulk reset)
- AISystem epic story-001 (`ai_action_requested` emission landing)
- ADR-0019 + grid-battle.md CR-3 (the AI-turn-detection contract; correctly described in lines 425-427)

---

## Sprint-12 Action Items (derived from this triage)

| # | Action | Story candidate | Effort |
|---|---|---|---|
| 1 | TODO-02 stale doc reference removal — edit `save_manager.gd:200` line | Bundleable into any sprint-12 commit (admin) | <5 min |
| 2 | TODO-04 `get_battle_state_snapshot()` removal (Option A) — verify zero callers + delete method | Standalone story OR bundleable | ~10-15 min |
| 3 | TODO-05 stale TODO line removal — `grid_battle_controller.gd:424` | Bundleable with TODO-04 (same file) | <5 min |
| 4 | TODO-03 reformat — standardize TODO format in `beat_cue.gd:6` (optional; cosmetic) | Bundleable | <2 min |
| 5 | TODO-01 disposition — keep as-is OR move to `production/polish-backlog.md` as POLISH-006 (producer call) | Decision-only | <5 min |

**Bundling recommendation**: actions 1 + 2 + 3 + 4 can ship as a single "TODO triage close-out" commit in sprint-12 (~30 min total). Action 5 is a disposition decision (≤5 min including doc update).

**Post-cleanup TODO count**: 5 → 2 (TODO-01 + TODO-03 remain as legitimate Defer-with-context markers). Below AI #6 visibility threshold of ≥5 stalled across 2 sprints.

---

## Cross-references

- Sprint-10 retro AI #6: `production/retrospectives/retro-sprint-10-2026-05-07.md` (TODO count stalled — triage required)
- Sprint-9 retro: `production/retrospectives/retro-sprint-9-2026-05-07.md` (TODO count first noted as stalled)
- Sprint-11 plan task: `production/sprints/sprint-11.md` line 48 (S11-11 acceptance: classify each as Address / Defer-with-context / Remove)
- CLAUDE.md session-start hook: `Code health: 5 TODOs, 0 FIXMEs in src/` (matches this triage's count)
- Polish-backlog convention: `production/polish-backlog.md` (TODO-01 candidate for POLISH-006 entry if producer prefers Polish-tier tracking over inline TODO marker)

---

## Amendment log

*Append future amendments below — do not rewrite the body above.*

- 2026-05-08 — Initial triage pass (sprint-11 S11-11 close-out; 5 TODOs classified; 2 Address + 2 Defer-with-context + 1 Remove).
