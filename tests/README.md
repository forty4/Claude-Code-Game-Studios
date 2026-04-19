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
godot --headless --script tests/gdunit4_runner.gd
```

This wrapper invokes GdUnit4's CLI runner over `tests/unit/` and `tests/integration/`. Prerequisite: GdUnit4 installed via the Godot Asset Library (search "gdUnit4") or as a git submodule at `addons/gdUnit4/`.

### Local (GdUnit4 direct)

```bash
godot --headless --path . -s addons/gdUnit4/bin/GdUnit4CliRunner.gd --add tests/unit --add tests/integration --continue
```

### CI

GitHub Actions runs `.github/workflows/tests.yml` on every push to `main` and every PR. Uses `MikeSchulze/gdUnit4-action@v1` which provisions Godot + GdUnit4 automatically.

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

- [ ] Install GdUnit4 via Godot Asset Library (Editor → AssetLib → search "gdUnit4")
- [ ] Verify `addons/gdUnit4/` exists
- [ ] Run `godot --headless --script tests/gdunit4_runner.gd` — should pass `tests/unit/example_test.gd`
- [ ] Commit `addons/gdUnit4/` (or add as submodule) so CI can install it
- [ ] Push to a branch and confirm `.github/workflows/tests.yml` runs green
