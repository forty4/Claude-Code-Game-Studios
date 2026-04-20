# Tests — 천명역전 (Defying Destiny)

This directory holds all automated test suites. Per `.claude/docs/technical-preferences.md` the framework is **GdUnit4** (GDScript testing framework). Per `.claude/docs/coding-standards.md` balance formulas require 100% coverage and gameplay systems require 80%.

## Directory layout

| Path | Purpose | Gate level |
|---|---|---|
| `tests/unit/` | Per-system unit tests — formulas, state machines, pure logic. Fast, deterministic, no scene tree. | BLOCKING |
| `tests/integration/` | Multi-system integration tests — signal contracts, save/load round-trips, pathfinding × terrain. | BLOCKING |
| `tests/performance/` | Performance benchmarks — e.g. Map/Grid `get_movement_range` <16 ms on 40×30 mobile target (ADR-0004 V-1). | ADVISORY |
| `tests/fixtures/` | Shared test data — canonical MapResource fixtures, HeroRecord fixtures, reference expected outputs. No inline magic numbers in test files. |  |

## Running tests

### Local (one-shot)

```bash
# One-time prerequisite — builds .godot/ class cache so gdUnit4 class_name globals resolve in headless mode.
# Re-run only after pulling changes that add new class_name declarations or addons.
godot --headless --import

# Test run
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
```

Prerequisite: gdUnit4 vendored at `addons/gdUnit4/` — see `addons/gdUnit4/VERSION.txt` for pinned version. To upgrade, follow the instructions in that file.

The `--ignoreHeadlessMode` flag is required because gdUnit4 v6.x refuses headless mode by default (it warns that UI-interaction tests won't work in headless). Our test suite is pure logic/integration — no UI InputEvent simulation — so ignoring the warning is safe.

### CI

GitHub Actions runs `.github/workflows/tests.yml` on every push to `main` and every PR. Uses `MikeSchulze/gdUnit4-action@v1` which provisions Godot + gdUnit4 automatically — the vendored `addons/gdUnit4/` copy is for local dev, not CI.

## Conventions

Per `.claude/docs/coding-standards.md`:
- **File naming**: `[system]_[feature]_test.gd` (e.g. `map_grid_pathfinding_test.gd`)
- **Function naming**: `test_[scenario]_[expected]` (e.g. `test_dijkstra_with_obstacle_routes_around`)
- **Determinism**: no `randf()` without seeded RNG; no time-dependent assertions.
- **Isolation**: each test sets up + tears down its own state; no cross-test order dependency.
- **No hardcoded data**: use `tests/fixtures/` (exception: boundary value tests where the exact number IS the point).
- **No external I/O** in unit tests — use dependency injection.

## What NOT to automate

Per coding standards:
- Visual fidelity (shader output, VFX appearance, animation curves) — screenshot sign-off in `production/qa/evidence/`
- "Feel" qualities (input responsiveness, perceived weight, timing) — playtesting
- Platform-specific rendering — test on target hardware
- Full gameplay sessions — covered by playtesting

## First-run checklist

- [ ] Install Godot 4.6 (macOS: `brew install --cask godot`)
- [ ] Verify `addons/gdUnit4/` exists (vendored at project-root; see `VERSION.txt`)
- [ ] Run `godot --headless --import` — populates `.godot/` class cache
- [ ] Run the test command shown in "Running tests → Local" — should pass `tests/unit/example_test.gd` (3 test cases)
- [ ] Push to a branch and confirm `.github/workflows/tests.yml` runs green
