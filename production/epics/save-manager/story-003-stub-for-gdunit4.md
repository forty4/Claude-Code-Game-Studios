# Story 003: SaveManagerStub for GdUnit4 test isolation

> **Epic**: save-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: 3-4 hours (stub helper + self-test + temp-dir cleanup discipline; mirrors GameBusStub + SceneManagerStub patterns)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (test infrastructure; enables V-4/V-5/V-7/V-8/V-9 test coverage in stories 004-006)
**Requirement**: No direct TR — test-infra prerequisite for TR-save-load-003/004 validation
*(Mirrors `GameBusStub` from gamebus story-006 and `SceneManagerStub` from scene-manager story-002)*

**ADR Governing Implementation**: ADR-0003 — §Constraints (testing: "SaveManager stub must be injectable for tests, swap `user://` root to a temp path in `before_test`, cleanup in `after_test`")
**ADR Decision Summary**: "Tests must not pollute real `user://saves/`. Swap SaveManager's effective save root to a temp directory for the duration of each test. `after_test` cleanup MUST remove the temp dir recursively."

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (temp-dir cleanup discipline; autoload-identifier binding gotcha G-10)
**Engine Notes**: G-10 (autoload identifier binds at engine init) applies — tests that require SaveManager's actual handler to fire MUST emit on the REAL `/root/SaveManager`, not on a swapped-in stub. Use this stub for fresh-state isolation only (the `user://` root override), NOT for signal-handler-firing tests. G-6 (orphan detection between test body exit and after_test) — explicit `swap_out()` at the end of every test body that calls `swap_in()`.

**Control Manifest Rules (Platform layer)**:
- Required: SaveManager stub injectable via `before_test` / `after_test` in GdUnit4 (control-manifest §Foundation Layer)
- Required: tests must not touch real `user://saves/` — every test uses isolated temp root
- Required: explicit `swap_out()` at end of test body (G-6)

## Acceptance Criteria

*Derived from ADR-0003 §Constraints + G-6/G-10 guardrails:*

- [ ] `tests/unit/core/save_manager_stub.gd` exists: `class_name SaveManagerStub extends RefCounted` (NOT an autoload; `class_name` is safe)
- [ ] Static `swap_in(temp_root: String = "") -> Node` helper:
  - If `temp_root` empty, generates unique temp dir under `user://test_saves/[uuid]/`
  - Creates temp dir structure (root + 3 slot dirs) via `DirAccess.make_dir_recursive_absolute`
  - Detaches production `SaveManager` from `/root`, caches as static `_cached_production`
  - Mounts fresh `SaveManager` instance at `/root/SaveManager` with `SAVE_ROOT` overridden to `temp_root`
  - Returns the stub instance
- [ ] Static `swap_out() -> void` helper:
  - Restores cached production SaveManager to `/root`
  - Frees stub via `free()` (NOT `queue_free()` — G-6)
  - Recursively removes temp dir via `DirAccess.remove_absolute` (cleanup discipline)
  - `is_instance_valid()` guard on `_cached_production` (G-11)
- [ ] `SAVE_ROOT` override mechanism: stub sets a test-only `_save_root_override: String` on its SaveManager instance; production SaveManager's `_save_root` reads from override if set, else falls back to const `SAVE_ROOT`
  - Alternative: stub subclasses SaveManager and overrides `_get_save_root() -> String`
  - Story-004 implementation resolves which mechanism (document in code-review)
- [ ] `tests/unit/core/save_manager_stub_self_test.gd` — 7 self-tests (AC-1..AC-7) passing
- [ ] `tests/unit/core/README.md` — `## SaveManagerStub` section appended with usage pattern + known limitations
- [ ] Full unit suite passes, 0 orphans, GODOT EXIT 0
- [ ] No residual temp dirs in `user://test_saves/` after test run (cleanup discipline verified)

## Implementation Notes

*From ADR-0003 §Constraints + G-6/G-10/G-11 session gotchas:*

1. **G-10 applies — autoload-identifier binding** — any test that checks "SaveManager's handler fired after GameBus emit" MUST emit on REAL `/root/SaveManager`, NOT on the stub instance returned by `swap_in`. The autoload identifier `SaveManager` was bound at engine init; downstream code in SaveManager's `_ready` subscribed using that identifier. Stub is useful for:
   - Testing `_ensure_save_root`, `_path_for`, `set_active_slot` logic (no GameBus roundtrip)
   - Pre-creating test files on disk before exercising SaveManager API
   - Tests that exercise `save_checkpoint` / `load_latest_checkpoint` directly (no GameBus emit required)

2. **G-6 orphan-detection discipline** — explicit `SaveManagerStub.swap_out()` at the end of every test body. `after_test` is a safety net only. Use `free()` not `queue_free()` (deferred deletion triggers orphan detection).

3. **G-11 is_instance_valid before cast** — `_cached_production` may be freed between swap cycles. Guard all casts with `is_instance_valid()`.

4. **Temp-dir cleanup is non-trivial** — `DirAccess.remove_absolute` only removes empty dirs. Must recursively walk + remove files first. Helper:
   ```gdscript
   static func _remove_dir_recursive(path: String) -> void:
       var da := DirAccess.open(path)
       if da == null: return
       for f in da.get_files(): da.remove(f)
       for d in da.get_directories(): _remove_dir_recursive("%s/%s" % [path, d])
       DirAccess.remove_absolute(path)
   ```

5. **Unique temp dir per test** — use `OS.get_unique_id() + "_" + str(Time.get_ticks_msec())` as the temp-dir suffix to avoid collisions on serial test runs (GdUnit4 is serial-only per gamebus story-006 limitation).

6. **SAVE_ROOT override mechanism decision** — defer to story-004 implementation. Two candidates:
   - **Option A**: SaveManager exposes package-private `_save_root_override: String` var; stub sets it after swap_in. Production SaveManager reads override if non-empty, else falls back to const `SAVE_ROOT`.
   - **Option B**: Stub subclasses SaveManager (`extends SaveManager`) and overrides `_get_save_root()`.
   - Option A preferred for simplicity; code-review at story-004 confirms.

7. **Precedent parity** — follows GameBusStub + SceneManagerStub patterns exactly: static `swap_in`/`swap_out`, `_cached_production` static var, explicit cleanup, `free()` for detached nodes. Reuse those test-helper patterns from `test_helpers.gd`.

## Out of Scope

- SaveContext / EchoMark classes — story 001
- SaveManager autoload skeleton — story 002
- Save pipeline — story 004
- Load + crash-recovery — story 005
- Migration registry — story 006
- Perf validation — story 007
- CI lint — story 008

## QA Test Cases

*Test file*: `tests/unit/core/save_manager_stub_self_test.gd`

- **AC-1** (swap_in creates fresh SaveManager at /root/SaveManager):
  - Given: production SaveManager mounted at `/root/SaveManager`
  - When: `var stub = SaveManagerStub.swap_in()`
  - Then: `/root/SaveManager` is now the stub instance (not production); `_cached_production` is non-null; `is_instance_valid(_cached_production) == true`
  - Cleanup: `SaveManagerStub.swap_out()` at test body end

- **AC-2** (swap_out restores production):
  - Given: stub swapped in
  - When: `SaveManagerStub.swap_out()`
  - Then: `/root/SaveManager` is back to production instance; stub is freed (`is_instance_valid(stub) == false`)

- **AC-3** (temp dir created with override):
  - Given: no preconditions
  - When: `var stub = SaveManagerStub.swap_in("user://test_saves/custom_test/")`
  - Then: `user://test_saves/custom_test/slot_1/` through `slot_3/` all exist on disk
  - Cleanup: swap_out removes the entire `custom_test/` subtree

- **AC-4** (SAVE_ROOT override takes effect):
  - Given: stub swapped in with temp root
  - When: `stub._path_for(1, 5, 2)` (or `stub.get_effective_save_root()` helper)
  - Then: returns path under the temp root, NOT under `user://saves/`

- **AC-5** (temp dir cleanup after swap_out):
  - Given: stub swapped in with temp root `user://test_saves/cleanup_test/`; fake file written to `user://test_saves/cleanup_test/slot_1/dummy.res`
  - When: `swap_out()`
  - Then: `DirAccess.dir_exists_absolute("user://test_saves/cleanup_test")` returns false (recursive removal succeeded)

- **AC-6** (double swap_in warns gracefully):
  - Given: stub already swapped in
  - When: second `swap_in()` call
  - Then: `push_warning` fires with "SaveManagerStub already swapped in" message; first stub is swapped out before new one mounted (no orphan leak)

- **AC-7** (swap_out on unswapped state is no-op):
  - Given: no prior swap_in
  - When: `swap_out()`
  - Then: no-op (no push_error); `/root/SaveManager` unchanged

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/save_manager_stub_self_test.gd` — 7 tests pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: story-002 (SaveManager autoload must exist to be swapped)
- **Unlocks**: Stories 004, 005, 006 (all rely on stub for filesystem isolation)
