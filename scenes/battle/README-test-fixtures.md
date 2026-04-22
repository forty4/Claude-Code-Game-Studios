# scenes/battle — Test Fixture Notice

## Production scenes

Production BattleScene files live here and follow the naming convention
`<map_id>.tscn` as required by `SceneManager._resolve_battle_scene_path`.

## Test-only fixtures

The following files are **test fixtures only** and must be excluded from
release builds:

| File | Story | Purpose |
|------|-------|---------|
| `test_ac4_map.tscn` | Story 004 | Minimal Node2D scene for async-load integration test (AC-1) |

### Excluding test fixtures from exports

In **Project → Export → Resources**, add a filter to exclude test fixtures:

```
scenes/battle/test_*.tscn
```

This ensures no test-only content ships in production exports. When adding
new test fixtures, prefix the filename with `test_` so the export filter
catches them automatically.
