# Story 005: Load pipeline — list_slots + load_latest_checkpoint + crash-recovery scan

> **Epic**: save-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: 4-5 hours (3 methods + newest-CP ordering + corrupt-file handling + slot isolation + CACHE_MODE_IGNORE verification)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0003 §Key Interfaces)
**Requirement**: `TR-save-load-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 — §Key Interfaces (load_latest_checkpoint, list_slots, _find_latest_cp_file) + §Cache Bypass
**ADR Decision Summary**: "All loads use `ResourceLoader.load(path, '', CACHE_MODE_IGNORE)`. Newest checkpoint in active slot = highest chapter_number, then highest cp. `list_slots` enumerates all 3 slots with newest-CP metadata for UI consumption. Corrupt files marked `corrupt: true`, never crash."

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `ResourceLoader.CACHE_MODE_IGNORE` is BLOCKING per §Cache Bypass — cached loads return stale post-overwrite objects. `DirAccess.get_files_at(path)` is 4.6-idiomatic (replaces legacy `list_dir_begin()` loop per `docs/engine-reference/godot/deprecated-apis.md`). `PackedStringArray` iteration via `for f in files:` — idiomatic GDScript 4.x.

**Control Manifest Rules (Platform layer)**:
- Required: All save loads use `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` (TR-save-load-004)
- Required: `DirAccess.get_files_at` (4.6 idiom), NOT `list_dir_begin()` legacy loop
- Forbidden: loading without CACHE_MODE_IGNORE (returns stale post-overwrite objects)

## Acceptance Criteria

*Derived from ADR-0003 §Key Interfaces + §Validation Criteria V-2, V-7, V-8, V-9, V-12:*

- [ ] `load_latest_checkpoint() -> SaveContext` implements pipeline exactly per ADR-0003 §Key Interfaces:
  1. `path = _find_latest_cp_file(_active_slot)`
  2. If `path.is_empty()`: return null
  3. `raw = ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`
  4. If `raw == null` or `not raw is SaveContext`: emit `save_load_failed("load", "invalid_resource:%s" % path)`; return null
  5. `ctx = raw as SaveContext`
  6. Return `SaveMigrationRegistry.migrate_to_current(ctx)` — NOTE: migration call may return unmigrated ctx if story-006 not yet landed; acceptable transient state (test with `CURRENT_SCHEMA_VERSION == 1` so no migration needed)
- [ ] `list_slots() -> Array[Dictionary]` implements per ADR-0003 §Key Interfaces:
  - For each slot in 1..SLOT_COUNT: call `_find_latest_cp_file(slot)`
  - Empty slot: `{"slot_id": i, "empty": true}`
  - Valid file: load via CACHE_MODE_IGNORE; if SaveContext: `{"slot_id": i, "empty": false, "chapter_number": ctx.chapter_number, "last_cp": ctx.last_cp, "saved_at_unix": ctx.saved_at_unix}`
  - Invalid file: `{"slot_id": i, "empty": true, "corrupt": true}`
  - Returns array of length `SLOT_COUNT` exactly
- [ ] `_find_latest_cp_file(slot: int) -> String` implements per ADR-0003 §Key Interfaces:
  - `dir = "%s/slot_%d" % [SAVE_ROOT, slot]`
  - `files = DirAccess.get_files_at(dir)` (NOT legacy loop)
  - Parse each filename `ch_{MM}_cp_{N}.res`: `parts = f.trim_suffix(".res").split("_")`
  - Skip if `parts.size() != 4` or `parts[0] != "ch"` or `parts[2] != "cp"`
  - Compute key: `int(parts[1]) * 10 + int(parts[3])`
  - Track `best` + `best_key`; return full path of best match or empty string
- [ ] V-2: Array[EchoMark] survives round-trip — 10 EchoMarks with unique fields, save via story-004 pipeline, load via this story's `load_latest_checkpoint`, assert element-wise equality
- [ ] V-7: CACHE_MODE_IGNORE enforced — overwrite file in same session (via 2nd `save_checkpoint`), call `load_latest_checkpoint`, assert loaded content matches 2nd save (NOT 1st cached version)
- [ ] V-8: slot isolation — save to slot 1; call `list_slots`; slots 2 and 3 report `empty: true`
- [ ] V-9: `list_slots` handles corrupt file — write garbage bytes to `slot_1/ch_01_cp_1.res` via `FileAccess`; call `list_slots`; slot 1 reports `{"empty": true, "corrupt": true}`; never crashes
- [ ] V-12: `load_latest_checkpoint` returns newest CP — save `ch_01_cp_1` then `ch_01_cp_2` (same chapter, later CP); `load_latest_checkpoint` returns `cp_2` content; save additionally `ch_02_cp_1` (later chapter, earlier CP); `load_latest_checkpoint` returns `ch_02_cp_1` (chapter wins over CP)

## Implementation Notes

*From ADR-0003 §Key Interfaces + §Cache Bypass:*

1. **CACHE_MODE_IGNORE is BLOCKING** — without it, the in-memory ResourceLoader cache returns the pre-overwrite object on second load in the same session. This is a silent correctness bug that only surfaces on V-7 test. Must NEVER be omitted.

2. **DirAccess.get_files_at preferred** — 4.6-idiomatic. Returns `PackedStringArray`; iterate directly with `for f in files:`. Do NOT use `list_dir_begin()` + `get_next()` loop (legacy 4.3-and-earlier pattern).

3. **Filename parsing robustness** — 4-part split (`ch`, `MM`, `cp`, `N`) guards against non-save files in the slot dir (e.g., `.tmp` files lingering from failed saves, user-dropped files). Anything non-matching silently ignored, not errored.

4. **Newest-CP key ordering** — `key = int(parts[1]) * 10 + int(parts[3])` gives chapter-major order. Example: `ch_02_cp_1` → key=21, `ch_01_cp_2` → key=12. Chapter 2 CP 1 > Chapter 1 CP 2 (correct — chapter wins).
   - Edge case: chapter ≥ 10 → key overflow into next chapter's range (ch_10_cp_1 → 101 vs ch_01_cp_1 → 11 — still correctly ordered). Safe for MVP scope (expected <20 chapters).

5. **Migration invocation** — this story's `load_latest_checkpoint` calls `SaveMigrationRegistry.migrate_to_current(ctx)` per ADR §Key Interfaces. If story-006 hasn't landed yet, `SaveMigrationRegistry` doesn't exist → test with `CURRENT_SCHEMA_VERSION == 1` so loaded v1 ctx needs no migration. Add a `TODO story-006:` comment on the call line; at story-006 time, this line's contract is already correct.

6. **Corrupt-file test via raw FileAccess** — write byte garbage (`"this is not a resource"`) to `slot_1/ch_01_cp_1.res`. `ResourceLoader.load` returns null → `list_slots` marks `{"empty": true, "corrupt": true}`. Verify NO crash, NO exception escape.

7. **V-8 slot isolation** — saves to slot 2 should never touch slot 1's directory. Verified by: save to slot 2; then read `user://saves/slot_1/` directory contents — must be empty. This is an atomicity-adjacent test (filesystem isolation, not write atomicity).

8. **Performance** — `DirAccess.get_files_at` is O(N) in directory size; with ≤3 CPs × N chapters × 1 slot, worst-case N ≈ 60 files — trivial. `ResourceLoader.load` on SaveContext expected 5-15 ms per load (ADR-0003 §Performance Implications); `list_slots` calls load 3× → ≤45 ms. Acceptable for menu-screen use.

9. **G-10 applies** — tests that use GameBus emit triggers must emit on REAL `/root/GameBus`, test handler on REAL `/root/SaveManager`. Use SaveManagerStub for temp-root isolation only.

## Out of Scope

- SaveContext / EchoMark classes — story 001
- Autoload skeleton — story 002
- Test stub — story 003
- Save pipeline — story 004 (prerequisite)
- Migration registry — story 006 (`migrate_to_current` call is a TODO shim here)
- Perf validation — story 007
- CI lint — story 008

## QA Test Cases

*Test file*: `tests/unit/core/save_manager_test.gd` (additive — extends story-002 skeleton + story-004 save tests)

- **AC-V2** (Array[EchoMark] round-trip):
  - Given: stub with temp root; 10 EchoMarks with unique `beat_index` + `outcome` + `tag` values in a SaveContext
  - When: save via story-004 pipeline + `load_latest_checkpoint`
  - Then: loaded ctx `echo_marks_archive` has 10 elements, each matching source EchoMark field-by-field

- **AC-V7** (CACHE_MODE_IGNORE enforced):
  - Given: stub; save ctx_v1 with chapter_number=1, last_cp=1, echo_count=5; then save ctx_v2 to the SAME (slot, chapter, cp) triple with `echo_count=99`
  - When: `load_latest_checkpoint`
  - Then: loaded ctx has `echo_count == 99` (NOT 5); loaded BEFORE _v2 save call should've returned v1, AFTER returns v2 (cache-bypass contract)

- **AC-V8** (slot isolation):
  - Given: stub; `set_active_slot(1)`; save a ctx
  - When: `list_slots()`
  - Then: slot 1 reports `empty: false` with correct metadata; slots 2 and 3 report `{empty: true}`
  - Edge: `set_active_slot(2)` + save different ctx → `list_slots` reports both slot 1 and slot 2 with distinct metadata; slot 3 still `empty: true`

- **AC-V9** (corrupt file handling):
  - Given: stub; write byte-garbage to `slot_1/ch_01_cp_1.res` via FileAccess (not via save_checkpoint)
  - When: `list_slots()` (with `set_active_slot(1)`)
  - Then: slot 1 reports `{empty: true, corrupt: true}`; no push_error cascade; no crash
  - Edge case: `load_latest_checkpoint()` on corrupt file returns null; `save_load_failed` emitted with `reason` starting `"invalid_resource:"`

- **AC-V12a** (newest-CP within chapter):
  - Given: stub; save ch_01_cp_1 then ch_01_cp_2 to active slot
  - When: `load_latest_checkpoint()`
  - Then: returns ch_01_cp_2 content (higher cp wins within same chapter)

- **AC-V12b** (newest-CP chapter wins over CP):
  - Given: stub; save ch_01_cp_2 (key=12) then ch_02_cp_1 (key=21)
  - When: `load_latest_checkpoint()`
  - Then: returns ch_02_cp_1 content (later chapter wins)

- **AC-V12c** (skips non-matching filenames):
  - Given: stub; save ch_01_cp_1; manually create a rogue file `slot_1/unknown.res` via FileAccess
  - When: `load_latest_checkpoint()`
  - Then: returns ch_01_cp_1 (rogue file ignored; 4-part filename parser rejected it); no crash

- **AC-EMPTY-SLOT** (empty slot behavior):
  - Given: stub; freshly-created slot dirs (no save files)
  - When: `load_latest_checkpoint()`
  - Then: returns null; no error emission (empty is not a failure)
  - Edge: `list_slots()` returns 3 dicts, all `{empty: true}`

- **AC-list_slots-ordering** (deterministic slot order):
  - Given: stub; save to slots 2 and 3 (not 1)
  - When: `list_slots()`
  - Then: returns array length 3; `out[0].slot_id == 1` (empty), `out[1].slot_id == 2`, `out[2].slot_id == 3` (ascending slot_id order)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/save_manager_test.gd` — V-2/V-7/V-8/V-9/V-12 + 3 AC tests pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: story-004 (save pipeline must work to produce files to load)
- **Unlocks**: story-006 (migration chain integrates with load_latest_checkpoint), story-007 (perf validates load side too), story-008 (CI lint covers load path)
