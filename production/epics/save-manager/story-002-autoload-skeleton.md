# Story 002: SaveManager autoload skeleton + project.godot registration

> **Epic**: save-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: 2-3 hours (skeleton + registration + test file; pipeline bodies deferred to stories 004-006)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0003)
**Requirement**: `TR-save-load-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 — §Key Interfaces (SaveManager autoload) + §Migration Plan Phase 1-2
**ADR Decision Summary**: "Single autoload at `/root/SaveManager`, load order 3 (after GameBus + SceneManager). Signal-driven — subscribes to `save_checkpoint_requested` via `CONNECT_DEFERRED`, emits `save_persisted` / `save_load_failed`."

**Engine**: Godot 4.6 | **Risk**: LOW (this story is skeleton only; pipeline bodies deferred)
**Engine Notes**: Autoload-script `class_name` collision gotcha (G-3) — `extends Node` with NO `class_name SaveManager`. `CONNECT_DEFERRED` mandatory for cross-system subscribes (ADR-0001 §7). `_ensure_save_root()` uses `DirAccess.make_dir_recursive_absolute()` — pre-cutoff stable.

**Control Manifest Rules (Platform layer)**:
- Required: SaveManager autoload at `/root/SaveManager`, load order 3 (after GameBus + SceneManager)
- Required: subscribe to `save_checkpoint_requested` via `CONNECT_DEFERRED` in `_ready`
- Required: `_exit_tree` disconnects guarded by `is_connected`
- Required: `SAVE_ROOT` constant pinned to `user://saves` (TR-save-load-006)
- Forbidden: gameplay state on SaveManager (pure persistence owner)
- Forbidden: per-frame emits (ADR-0001 §7)
- Forbidden: SAF / external-storage paths (atomicity not guaranteed on Android SAF)

## Acceptance Criteria

*Derived from ADR-0003 §Key Interfaces + §Validation Criteria V-1-ready discipline:*

- [ ] `src/core/save_manager.gd` exists: `extends Node` (NO `class_name`), matching autoload discipline
- [ ] Declares constants exactly: `const SAVE_ROOT: String = "user://saves"`, `const SLOT_COUNT: int = 3`, `const CURRENT_SCHEMA_VERSION: int = 1`
- [ ] `var active_slot: int` read-only accessor (getter returns `_active_slot`, setter pushes error); backing `var _active_slot: int = 1`
- [ ] `_ready()` connects `GameBus.save_checkpoint_requested` to `_on_save_checkpoint_requested` via `CONNECT_DEFERRED` + calls `_ensure_save_root()`
- [ ] `_exit_tree()` disconnects guarded by `is_connected`
- [ ] `_ensure_save_root()` creates `user://saves` + `user://saves/slot_{1..3}` via `DirAccess.make_dir_recursive_absolute`
- [ ] `set_active_slot(slot: int)` validates `1 <= slot <= SLOT_COUNT` via assert + assigns `_active_slot`
- [ ] `_path_for(slot, chapter_number, cp)` returns formatted path: `"%s/slot_%d/ch_%02d_cp_%d.res" % [SAVE_ROOT, slot, chapter_number, cp]`
- [ ] Handler stubs exist with `pass` body + TODO comments linking to target stories:
  - `_on_save_checkpoint_requested(source: SaveContext)` → story 004
  - `save_checkpoint(source: SaveContext) -> bool` → story 004
  - `load_latest_checkpoint() -> SaveContext` → story 005
  - `list_slots() -> Array[Dictionary]` → story 005
  - `_find_latest_cp_file(slot: int) -> String` → story 005
- [ ] `project.godot` [autoload] section adds `SaveManager="*res://src/core/save_manager.gd"` as THIRD entry after `GameBus` and `SceneManager`; ORDER-SENSITIVE comment preserved
- [ ] `godot --headless --import` exit 0 (no parse errors, no autoload collision)

## Implementation Notes

*From ADR-0003 §Key Interfaces:*

1. **Autoload identity**: autoload name `SaveManager` IS the global identifier. Script must NOT declare `class_name SaveManager` (G-3). Same discipline as `game_bus.gd` + `scene_manager.gd`.

2. **Read-only `active_slot` accessor** (mirror of SceneManager `state`):
   ```gdscript
   var active_slot: int = 1:
       get: return _active_slot
       set(_v): push_error("SaveManager.active_slot is read-only; call set_active_slot()")

   var _active_slot: int = 1
   ```

3. **`_ensure_save_root()` at `_ready` time** — idempotent directory creation. On fresh install, creates `user://saves/` + 3 slot dirs. On existing install, no-ops.

4. **Handler stub discipline** — pipeline bodies land in:
   - `save_checkpoint` body → story 004 (duplicate_deep → ResourceSaver.save → rename_absolute)
   - `load_latest_checkpoint` + `list_slots` + `_find_latest_cp_file` bodies → story 005
   - Migration invocation inside `load_latest_checkpoint` → story 006 integration

   Each stub has a `# TODO story-NNN:` comment linking to its implementing story.

5. **project.godot order-sensitive comment** — preserve existing comment block; add SaveManager as the third entry:
   ```ini
   [autoload]

   ; ORDER-SENSITIVE: GameBus must be first — all other autoloads may reference it in _ready
   GameBus="*res://src/core/game_bus.gd"
   SceneManager="*res://src/core/scene_manager.gd"
   SaveManager="*res://src/core/save_manager.gd"
   GameBusDiagnostics="*res://src/core/game_bus_diagnostics.gd"
   ```
   *(SaveManager comes before GameBusDiagnostics; diagnostics depends on GameBus only, SaveManager depends on GameBus — they may register in either order after SceneManager, but alphabetical convention prefers SaveManager first.)*

6. **Signal existence check** — `save_checkpoint_requested`, `save_persisted`, `save_load_failed` on GameBus are all pre-declared as PROVISIONAL stubs from gamebus story-002 inventory; ratified by ADR-0003 amendment. Verify via `grep "save_checkpoint_requested\|save_persisted\|save_load_failed" src/core/game_bus.gd` — no ADR-0001 amendment needed in this PR.

7. **Performance**: skeleton story — no per-frame loops, no I/O beyond one-time `_ensure_save_root` (dir creation). No performance impact expected. Full ADR-0003 budgets (<50 ms full save cycle) apply to story-004 pipeline.

## Out of Scope

- SaveContext / EchoMark Resource classes — story 001 (prerequisite)
- Test stub (temp `user://` swap) — story 003
- Save pipeline implementation — story 004
- Load + crash-recovery — story 005
- Migration registry — story 006
- Perf validation — story 007
- CI lint — story 008

## QA Test Cases

*Test file*: `tests/unit/core/save_manager_test.gd` (skeleton-level; pipeline tests added in stories 004-006)

- **AC-1** (autoload loads cleanly):
  - Given: SaveManager registered as 3rd autoload in project.godot
  - When: `godot --headless --import`
  - Then: exit 0, no parse errors, no "Class hides autoload singleton" error

- **AC-2** (initial active_slot):
  - Given: autoload mounted
  - When: read `SaveManager.active_slot` immediately after `_ready`
  - Then: returns `1`

- **AC-3** (read-only active_slot):
  - Given: autoload mounted
  - When: attempt `SaveManager.active_slot = 2`
  - Then: `_active_slot` unchanged + `push_error` fires with "read-only; call set_active_slot()" message

- **AC-4** (set_active_slot valid range):
  - Given: autoload mounted
  - When: `set_active_slot(2)`
  - Then: `active_slot == 2`
  - Edge case: `set_active_slot(0)` or `set_active_slot(4)` triggers assert failure

- **AC-5** (GameBus subscription):
  - Given: autoload mounted
  - When: `GameBus.save_checkpoint_requested.is_connected(sm._on_save_checkpoint_requested)`
  - Then: returns true

- **AC-6** (disconnect on exit):
  - Given: autoload mounted + subscribed
  - When: manually call `_exit_tree()`
  - Then: signal has no connection to SaveManager (verified via `get_connections()` per G-8)

- **AC-7** (SAVE_ROOT constant):
  - Given: script loaded
  - When: read `SaveManager.SAVE_ROOT`
  - Then: equals `"user://saves"` exactly (TR-save-load-006 V-10 prerequisite)

- **AC-8** (directory creation):
  - Given: fresh `user://` (test uses SaveManagerStub from story-003 with temp root — this test is SKIPPED/stubbed until story-003 lands; kept here as the contract)
  - When: autoload `_ready` runs
  - Then: `DirAccess.dir_exists_absolute` returns true for `user://saves` + 3 slot dirs
  - *Note*: Depends on story-003 test infra; this AC is advisory until stub lands. Alternative: exercise `_ensure_save_root` directly from test with a temp path override.

- **AC-9** (_path_for formatting):
  - Given: autoload mounted
  - When: `_path_for(2, 3, 1)` (or via test hook if private)
  - Then: returns `"user://saves/slot_2/ch_03_cp_1.res"` (zero-padded chapter)

- **AC-10** (project.godot autoload order):
  - Given: project.godot parsed
  - When: inspect [autoload] section
  - Then: `GameBus` first, `SceneManager` second, `SaveManager` third; ORDER-SENSITIVE comment present

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/save_manager_test.gd` — skeleton tests must exist and pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: story-001 (SaveContext + EchoMark types referenced in handler stubs)
- **Unlocks**: Stories 003-008
