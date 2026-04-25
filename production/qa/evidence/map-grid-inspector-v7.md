# V-7 Map/Grid Inspector Authoring — Manual Verification Evidence

> **Story**: `production/epics/map-grid/story-008-inspector-fixture-manual-qa.md`
> **ADR**: `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 3, §Risks R-5, V-7
> **Story Type**: UI (manual verification + documentation)
> **Status**: PROGRAMMATIC PORTION COMPLETE / MANUAL PORTION PENDING SIGN-OFF
> **Last updated**: 2026-04-25

---

## Summary

This document is the manual verification artifact for V-7 (40×30 `MapResource.tres`
loads in the Godot 4.6 inspector without hang) plus ancillary inspector authoring
documentation. It records the workflow, the load-time observations, R-3 inline-only
constraint check, and screenshots required by story-008 ACs.

The **programmatic portion** (4 of 7 ACs) is complete and CI-asserted:
- AC-SAMPLE-15x15: `data/maps/sample_small.tres` (15×15) loads + validator passes
- AC-STRESS-40x30 runtime portion: `data/maps/stress_40x30.tres` (40×30) loads + validator passes
- AC-R3-INLINE-ASSERT: structural plain-text inspection confirms inline TileData (see §R-3 below)
- Sample fixture committed to `data/maps/`

The **manual portion** (3 of 7 ACs) requires the Godot editor GUI and is filled in
by the human verifier (you) after running through §Manual Steps below.

---

## Programmatic Verification (already CI-asserted)

### AC-SAMPLE-15x15 + AC-STRESS-40x30 (runtime load)

```bash
$ godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
        --ignoreHeadlessMode \
        -a res://tests/integration/core/map_grid_inspector_fixtures_test.gd -c

Overall Summary: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans
Exit code: 0
```

Both fixtures load via `ResourceLoader` and pass the story-003 validator without
errors. Dimensions confirmed (15×15 and 40×30 respectively).

### AC-R3-INLINE-ASSERT (R-3 hard constraint)

The R-3 constraint requires: TileData entries inline inside `MapResource.tres`,
with NO `ExtResource(...)` references to external `.tres` files.

```bash
# sample_small.tres structural analysis
$ grep -c "^\[ext_resource " data/maps/sample_small.tres
2                # only the 2 Script refs (map_resource.gd + map_tile_data.gd)
$ grep -cE '^\[ext_resource type="Resource"' data/maps/sample_small.tres
0                # CONFIRMED: no external Resource refs (R-3 inline-only)
$ grep -c "^\[sub_resource " data/maps/sample_small.tres
225              # all 225 tiles inline as SubResource blocks

# stress_40x30.tres structural analysis
$ grep -c "^\[ext_resource " data/maps/stress_40x30.tres
2                # same: only the 2 Script refs
$ grep -cE '^\[ext_resource type="Resource"' data/maps/stress_40x30.tres
0                # CONFIRMED: R-3 satisfied
$ grep -c "^\[sub_resource " data/maps/stress_40x30.tres
1200             # all 1200 tiles inline
```

**R-3 hard constraint VERIFIED for both fixtures**: zero external Resource references;
all TileData entries are inline `[sub_resource]` blocks within the same `.tres` file.

The 2 `[ext_resource]` lines in each file are Script references for `MapResource`
and `MapTileData` respectively — these are required by Godot's typed-Resource
serialization and do NOT violate R-3 (R-3 forbids external TileData data, not the
TileData script attachment).

### Plain-text fixture inspection (AC-5 evidence)

`sample_small.tres` (first 20 lines):

```
[gd_resource type="Resource" script_class="MapResource" format=3]

[ext_resource type="Script" path="res://src/core/map_resource.gd" id="1_vfib4"]
[ext_resource type="Script" path="res://src/core/map_tile_data.gd" id="2_usyww"]

[sub_resource type="Resource" id="Resource_685qe"]
script = ExtResource("2_usyww")
terrain_type = 7

[sub_resource type="Resource" id="Resource_shco3"]
script = ExtResource("2_usyww")
coord = Vector2i(1, 0)
terrain_type = 7

[sub_resource type="Resource" id="Resource_v5nbq"]
script = ExtResource("2_usyww")
coord = Vector2i(2, 0)
terrain_type = 7
```

The `tiles` array at the bottom of the file is a flat `Array[ExtResource("2_usyww")]`
of 225 `SubResource(...)` references, all pointing into the same file. ZERO external
Resource references → R-3 inline-only constraint SATISFIED.

---

## Manual Verification (PENDING — fill in below)

### How to perform the manual checks

1. Open Godot 4.6 editor: `godot --path .` (drops you into the editor).
2. Wait for project import to complete.
3. In the FileSystem dock, navigate to `res://data/maps/`.
4. Perform each AC below in order, recording your observations in the placeholders.
5. Take screenshots as specified.
6. When all 4 manual ACs are complete, change the document `Status:` line at the
   top of this file to `COMPLETE — SIGNED OFF`.

### Manual AC-1: sample_small.tres opens cleanly

| Step | Action | Expected |
|------|--------|----------|
| 1 | Double-click `data/maps/sample_small.tres` | Inspector panel opens on the right |
| 2 | Confirm fields visible | `map_id="sample_small"`, `map_rows=15`, `map_cols=15`, `terrain_version=1`, `tiles (Array)` collapsed |
| 3 | Click the `tiles` array fold-out | Array expands; 225 elements scrollable |
| 4 | Confirm no error dialog appeared | (no error popup) |

**Result**: [ ] PASS / [ ] FAIL

**Notes**: _(fill in any observations here — e.g., "fields displayed in <500ms; tiles array expand was instant")_

### Manual AC-2 (V-7 core): stress_40x30.tres opens without hang

| Step | Action | Expected |
|------|--------|----------|
| 1 | Have a stopwatch ready (phone timer is fine) | — |
| 2 | **Double-click** `data/maps/stress_40x30.tres` in FileSystem dock | Inspector starts loading |
| 3 | Start stopwatch when you double-click | — |
| 4 | Stop stopwatch when the `tiles` array becomes scrollable (not greyed out) | Recorded time ≤ 30s |
| 5 | Confirm no editor crash | (editor still responsive) |
| 6 | Scroll through the tiles array; confirm scroll proceeds (lag acceptable) | Scroll works |

**Result**: [ ] PASS / [ ] FAIL

**Measured load time**: `___` seconds
- Pass condition: ≤ 30 seconds (story-008 AC-INSPECTOR-LOAD-TIME)
- If > 30 seconds: ESCALATE to ADR-0004 R-1 fallback discussion (reduce max map size from 40×30 to 32×24); DO NOT mark story Complete.

**Notes**: _(observations on scroll lag, editor responsiveness, etc.)_

### Manual AC-3: TileData field edit round-trip

| Step | Action | Expected |
|------|--------|----------|
| 1 | With `sample_small.tres` open in inspector, expand `tiles[0]` | TileData fields visible |
| 2 | Note initial `destruction_hp` value | _(record initial: ____)_ |
| 3 | Click the `destruction_hp` field; type `777` | Value field accepts edit |
| 4 | Press Enter | Value commits |
| 5 | Press Ctrl+S (Cmd+S on macOS) | Save dialog or silent save |
| 6 | In FileSystem dock, click any other file to deselect, then re-click `sample_small.tres` to reload the inspector view | Inspector reloads from disk |
| 7 | Confirm `tiles[0].destruction_hp == 777` in the reloaded inspector | Sentinel value visible (persisted to disk) |
| 8 | (optional) Open `data/maps/sample_small.tres` in a plain text editor | `destruction_hp = 777` visible in the corresponding `[sub_resource]` block |
| 9 | Restore original value (revert to initial) and Ctrl+S | Original value reinstated |
| 10 | **Re-run the integration smoke to confirm the fixture is still valid before committing**: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/integration/core/map_grid_inspector_fixtures_test.gd -c` | 2/2 PASS, exit 0 |

**Result**: [ ] PASS / [ ] FAIL

**Notes**: _(observations on the save flow — e.g., "value persisted on first re-open")_

### Manual AC-INSPECTOR-LOAD-TIME (final sign-off)

Recorded `stress_40x30.tres` load time: `___` seconds (from AC-2 above).

| Threshold | Outcome |
|-----------|---------|
| ≤ 5 seconds | PASS — well within budget |
| 5 to 30 seconds | PASS — acceptable per story-008 |
| > 30 seconds | FAIL — trigger R-1 fallback discussion |

**Result**: [ ] PASS / [ ] FAIL

---

## Screenshots

Place screenshots in `production/qa/evidence/map-grid-inspector-v7/` and
reference them below.

### Screenshot 1: Inspector panel open showing MapResource fields
- Path: `production/qa/evidence/map-grid-inspector-v7/01-inspector-mapresource.png`
- What to capture: full Godot editor with inspector dock visible, showing
  `sample_small.tres` selected, fields displayed (`map_id`, `map_rows`, `map_cols`,
  `tiles (Array)` collapsed).
- Status: [ ] Captured / [ ] Pending

### Screenshot 2: Tiles array expanded
- Path: `production/qa/evidence/map-grid-inspector-v7/02-inspector-tiles-array.png`
- What to capture: same fixture, `tiles` array expanded showing several `[Resource]`
  / `MapTileData` sub-entries with their fields visible. This evidences the inline
  SubResource pattern visually.
- Status: [ ] Captured / [ ] Pending

### Optional Screenshot 3: stress_40x30 inspector load
- Path: `production/qa/evidence/map-grid-inspector-v7/03-stress-40x30-loaded.png`
- What to capture: inspector showing `stress_40x30.tres` post-load, with `tiles
  (Array)` field visible and the fold-out scrollable.
- Status: [ ] Captured / [ ] Pending (optional)

---

## Authoring Workflow Reference

For future content authors editing maps in the Godot inspector.

### Open a `.tres` map for editing
1. In Godot editor, FileSystem dock → navigate to `res://data/maps/`
2. Double-click the `.tres` file → inspector loads on the right
3. The inspector shows the `MapResource` fields and the `tiles` array

### Edit a TileData field
1. Expand the `tiles (Array)` field
2. Find the tile by index (linear `row * map_cols + col` from coordinates)
3. Expand the `[Resource]` entry for that tile
4. Edit any `@export` field: `terrain_type`, `elevation`, `is_passable_base`,
   `tile_state`, `occupant_id`, `occupant_faction`, `is_destructible`,
   `destruction_hp`, `coord`
5. Press Enter to commit, Ctrl+S to save

### R-3 Hard Constraint Reminder

**TileData MUST stay inline inside the `MapResource.tres` file.** Do NOT replace
inline `SubResource` entries with `ExtResource("res://path/to/tile.tres")` references
to external files — this would break the `Resource.duplicate_deep` round-trip
that pathfinding depends on (see ADR-0004 §R-3).

If you find yourself wanting to share TileData across multiple maps (e.g., a
"PLAINS_default" preset), do NOT externalize. Instead: copy/paste the inline
sub-resource block, or write a generator script that procedurally builds the
fixtures (see `tests/fixtures/generate_sample_small.gd` and
`tests/fixtures/generate_stress_40x30.gd` for the established pattern).

### Adding a new map
1. Author programmatically via a one-shot generator (see existing `generate_*.gd`
   scripts in `tests/fixtures/`); inspector authoring is for ITERATION, not
   greenfield map creation.
2. Save to `res://data/maps/[map_id].tres` with `map_id` matching the filename.
3. Verify validator acceptance: add the path to
   `tests/integration/core/map_grid_inspector_fixtures_test.gd` (or create a new
   smoke test) and run the integration suite:
   ```
   godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
       --ignoreHeadlessMode -a res://tests/integration -c
   ```
   Author should see exit 0 + new test included in Overall Summary count BEFORE
   committing the new map. Catches field-constraint violations (e.g., elevation
   out of CR-3 range) at authoring time rather than at runtime/playtest.
4. The `.tres` is the source of truth for git; shipped builds get binary `.res`
   via export-import pipeline (release-manager concern).

---

## Sign-off

| Role | Name | Status | Date |
|------|------|--------|------|
| UI track verifier | _(your name)_ | [ ] Approved / [ ] Approved with notes / [ ] Rejected | _(YYYY-MM-DD)_ |

**Sign-off conditions**:
- All 4 manual ACs (AC-1, AC-2, AC-3, AC-INSPECTOR-LOAD-TIME) marked PASS
- Both required screenshots captured
- Stress fixture load time ≤ 30 seconds
- No editor crash, no error dialogs, no R-3 violations observed

When sign-off is complete:
1. Change the document `Status:` line at the top to `COMPLETE — SIGNED OFF`
2. Run `/story-done production/epics/map-grid/story-008-inspector-fixture-manual-qa.md`
   to close the story.

---

## Linked artifacts

- Programmatic test: `tests/integration/core/map_grid_inspector_fixtures_test.gd`
- Sample fixture: `data/maps/sample_small.tres` (15×15)
- Stress fixture: `data/maps/stress_40x30.tres` (40×30, copied from `tests/fixtures/maps/`)
- Sample fixture generator: `tests/fixtures/generate_sample_small.gd`
- Stress fixture generator: `tests/fixtures/generate_stress_40x30.gd`
- ADR: `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 3, §Risks R-5, V-7
- Story spec: `production/epics/map-grid/story-008-inspector-fixture-manual-qa.md`
- Performance baseline (V-1, runtime perf): `production/qa/evidence/`-adjacent or
  `tests/integration/core/map_grid_perf_test.gd` (story-007)
