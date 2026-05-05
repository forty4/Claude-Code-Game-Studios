# Save/Load System (세이브/로드) — Design GDD #17

| Field | Value |
|-------|-------|
| **Tier** | Vertical Slice |
| **Status** | Designed (rev 1.0 — 2026-05-05) |
| **Layer** | Core / Persistence |
| **Owner** | systems-designer |
| **Governing ADR** | ADR-0003 SaveContext + ADR-0017 ScenarioRunner (CP-1/2/3 emission source) + ADR-0002 SceneManager (CP-2/3 timing boundaries) + ADR-0018 DestinyBranch (branch_key + is_canonical_history persisted fields) |
| **Cross-refs** | game-concept Pillar 4 (지난 장의 선택이 살아 있다); destiny-state.md §3.5 Persistence contract (CR-DS-16..18); scenario-progression.md §F-SP-4 scenario_path_key delimiter; destiny-branch.md §F-DB-1 branch_key emission |
| **Replaces** | systems-index.md row 17 Not Started → Designed (sprint-8 S8-08 close — Producer pressure-cut from sprint-7) |

---

## 1. Overview

The Save/Load System is the **persistence substrate** that captures player progress at three checkpoints per chapter (CP-1 / CP-2 / CP-3 per ADR-0003), persists a typed `SaveContext` Resource via `ResourceSaver.save()` to `user://saves/slot_{1..3}/`, and rehydrates state via `ResourceLoader.load()` with cache bypass on game resume. It owns three responsibilities: (1) **typed snapshot capture** — every save is a deep-duplicated immutable Resource (no live-state torn writes); (2) **atomic disk write** — write-to-tmp + `rename_absolute` so a crash mid-save never produces a partial visible file; (3) **schema migration** — every save carries `schema_version: int`, and `SaveMigrationRegistry` chains pure-function upgrade callables until current version is reached.

Save/Load has **no UI surface of its own** at MVP. Its presence is felt indirectly: through Save Slot UI (#18 Alpha — reads `SaveManager.list_slots()` for slot enumeration); through Main Menu (#21 Alpha — "Continue" button presence implies a non-empty active slot); and most critically through cross-chapter Pillar 4 narrative continuity (Destiny State #16 archives EchoMarks + flags that survive between sessions).

Three save slots are supported from MVP. Slots are **independent** — overwriting slot 2 never touches slot 1 or 3. Within a slot, per-chapter checkpoint files accumulate as **run history**: slot 1 may contain `ch_01_cp_1.res`, `ch_01_cp_2.res`, `ch_01_cp_3.res`, `ch_02_cp_1.res`, etc., reflecting the player's full traversal. Older chapter files are retained for forensic recovery (debug-mode "rewind to chapter 1" → load `ch_01_cp_1.res` from slot history) until the slot is explicitly reset.

This is the **substrate layer** that makes Pillar 4 ("지난 장의 선택이 살아 있다 — past choices remain alive") mechanically observable across sessions. Without persistence, "the world remembers what you did" reduces to "the world remembers what you did THIS session" — a Pillar-breaking compromise.

---

## 2. Player Fantasy

> "내가 쌓아온 시간이 사라지지 않는다. 다음에 다시 켜도, 내 선택은 살아 있다."

Two fantasy pillars converge here:

- **Session safety** — long sessions on mobile (9-beat ceremony × N chapters) are routinely interrupted: a phone call lands, the OS swaps the app under memory pressure, the battery dies. The player should never feel they have to "race" to a save point or risk losing 30 minutes of careful tactical play. Save/Load makes interruption invisible: at every critical narrative beat (chapter start, post-resolution, next-chapter entry), the game checkpoints automatically. When the player returns, the most recent checkpoint loads transparently — no "save your game?" prompt, no anxious checking that the save took.

- **Run permanence (Pillar 4)** — "the world remembers your choices" requires the world to remember. When the player chooses a non-canonical branch in Chapter 2, that choice MUST persist so Chapter 3 can recognize the divergence in dialogue, faction stance, and ending eligibility. Save/Load is the medium of memory: every Destiny State flag, every EchoMark accumulated from retries, every `scenario_path_key` permutation lives on disk between sessions. The player's run is a **specific history**, not a default trajectory.

The 3-slot policy serves a third, lighter fantasy: **parallel exploration**. Three save slots = three parallel runs. A player can dedicate slot 1 to a "canonical history" playthrough, slot 2 to a "Pillar 2 echo-routing experiment" run, slot 3 to a "Pillar 4 deepest-divergence" exploration. Slots don't bleed into each other.

Save/Load is invisible when working correctly and **catastrophic when it isn't**. A failed save that loses 2 hours of play undermines every other system in the game — Pillar 1 tactical care, Pillar 2 retry investment, Pillar 4 cross-chapter narrative continuity all collapse if the player can't trust the save.

*Anchor moment*: The player closes the app mid-chapter, comes back the next day, taps "Continue" on the main menu, and lands at exactly Beat 3 of Chapter 2 with the units they had positioned, the EchoMarks they had earned, and the Chapter 1 branch they had chosen — fully restored, no questions asked, no "did the save work?" anxiety.

---

## 3. Detailed Rules

### 3.1 Schema (CR-SL-1..4)

- **CR-SL-1**: `SaveContext` Resource is the **single typed payload** persisted per checkpoint. Authoritative schema lives in `src/core/save_context.gd` per ADR-0003 §Key Interfaces. MVP fields: `schema_version: int` + `slot_id: int` + `chapter_id: StringName` + `chapter_number: int` + `last_cp: int (1|2|3)` + `outcome: int (BattleOutcome.Result)` + `branch_key: StringName` + `echo_count: int` + `echo_marks_archive: Array[EchoMark]` + `flags_to_set: PackedStringArray` + `saved_at_unix: int` + `play_time_seconds: int`. Total: **12 @export fields**.
- **CR-SL-2**: Every persisted field on `SaveContext` AND every nested `Resource` (e.g. `EchoMark`) MUST be annotated `@export`. Non-exported fields are silently dropped by `ResourceSaver` per Godot 4.6 serialization contract (verified `docs/engine-reference/godot/modules/core.md`). Adding a field without `@export` is a **silent data-loss bug** — discoverable only at next-load. Per ADR-0003 §Schema Stability §EchoMark Resource Contract (BLOCKING).
- **CR-SL-3**: Schema versioning is MANDATORY. Every `SaveContext` carries `schema_version: int = CURRENT_SCHEMA_VERSION` (currently `1` per ADR-0003 §Key Interfaces). Bump on every additive OR breaking change. Loader applies migrations in linear chain via `SaveMigrationRegistry.migrate_to_current(ctx)` until `ctx.schema_version == CURRENT_SCHEMA_VERSION`.
- **CR-SL-4**: `BattleOutcome.Result` enum integer ordering is FROZEN (per ADR-0003 §Schema Stability). Append-only. Reordering or inserting a new value silently corrupts every loaded save — requires `schema_version` bump + migration callable that rewrites `outcome` integers. Future schema versions MAY switch to string form (`"WIN"|"DRAW"|"LOSS"`) for format-independence; until then, integer ordering is a persistence contract.

### 3.2 Three-Checkpoint Policy (CR-SL-5..8)

- **CR-SL-5**: ScenarioRunner emits `save_checkpoint_requested(ctx: SaveContext)` on the GameBus relay at exactly **three moments per chapter** per ADR-0003 §Decision §3-CP policy:
  - **CP-1 — Chapter entry (Beat 1)**: fires when ScenarioRunner enters `BEAT_1_INTRO`. Captures the chapter's **starting state** (chapter_id, chapter_number, last_cp=1, fresh `branch_key=&""`, current echo + flag carryover from prior chapter).
  - **CP-2 — Post-resolution (SceneManager RETURNING_FROM_BATTLE → IDLE boundary)**: fires when SceneManager transitions from RETURNING_FROM_BATTLE back to IDLE post-Beat 7 seal. Captures the chapter's **resolved outcome** (chapter_id, last_cp=2, outcome int, branch_key per F-DB-1, updated echo_count). This is the single most important checkpoint — losing CP-2 forces a chapter replay.
  - **CP-3 — Next-chapter Beat 1 entry**: fires at the entering chapter's Beat 1 same as CP-1, but with `last_cp=3` semantically marking "previous chapter completed + transitioned". Distinguishes "fresh chapter start" from "first save after a successful transition" for Save Slot UI.
- **CR-SL-6**: Per-chapter checkpoint files **accumulate within a slot**. Slot 1 may hold `ch_01_cp_1.res` + `ch_01_cp_2.res` + `ch_01_cp_3.res` + `ch_02_cp_1.res` simultaneously. Older chapters' files are NOT pruned at next-chapter advance — they remain as **run history** until explicit slot reset. This enables future debug-mode rewind features ("load chapter 1 cp 2 from slot 1") without requiring separate save infrastructure.
- **CR-SL-7**: Newest-checkpoint resolution (per F-SL-2) applies a deterministic ordering: **highest chapter_number, then highest cp**. `ch_02_cp_1.res` is newer than `ch_01_cp_3.res` (Chapter 2 entry beats Chapter 1 transition). `ch_02_cp_2.res` is newer than `ch_02_cp_1.res`. The path-resolution helper `_find_latest_cp_file(slot)` parses filenames as `key = chapter_number * 10 + cp` per ADR-0003 §Key Interfaces.
- **CR-SL-8**: ScenarioRunner is the **sole emitter** of `save_checkpoint_requested`. Other systems (Destiny State, Battle, etc.) populate `SaveContext` fields via subscription pattern — they receive the event, write their owned fields, and return. SaveManager fires AFTER all populators have returned (CONNECT_DEFERRED ordering guarantees deferred-frame serialization). Per ADR-0001 sole-emitter discipline.

### 3.3 Atomic Write Protocol (CR-SL-9..11)

- **CR-SL-9**: Every save MUST follow the atomic write protocol per ADR-0003 §Decision §Atomic Write:
  1. Deep-duplicate the source `SaveContext` via `source.duplicate_deep(Resource.DUPLICATE_DEEP_ALL_BUT_SCRIPTS)`. The snapshot is the unique reference for serialization; the source may be mutated freely after `save_checkpoint(source)` returns.
  2. Write to `final_path + ".tmp"` via `ResourceSaver.save(snapshot, tmp_path)`.
  3. `DirAccess.rename_absolute(tmp_path, final_path)` — atomic on `user://` per Platform-Scoped Atomic Rename table (POSIX `rename(2)` on iOS/macOS/Linux/Android internal storage; `MoveFileEx` on Windows; **NOT guaranteed on Android SAF external storage** — save root MUST remain `user://`).
  4. Emit `save_persisted(chapter_number, cp)` on success; `save_load_failed(op, reason)` on any error.
- **CR-SL-10**: Save root MUST remain `user://saves/`. No code path may write to external/scoped storage paths (Android SAF, iOS shared containers, etc.) — these break atomic-rename semantics and can produce corrupted saves. This is enforced by the constant `SaveManager.SAVE_ROOT = "user://saves"` (CR-SL-9 lint candidate: `grep -E 'SAVE_ROOT.*=.*"(?!user://)'` MUST return 0 matches).
- **CR-SL-11**: All loads MUST use `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`. Cached loads return stale post-overwrite objects — a save written at CP-2 then re-loaded immediately would return the pre-CP-2 cached snapshot per Godot 4.6 ResourceLoader cache semantics. The CACHE_MODE_IGNORE flag is mandatory at every load site (lint candidate: `grep -E 'ResourceLoader\.load' src/core/save_manager.gd` MUST contain `CACHE_MODE_IGNORE` on every match).

### 3.4 Live-State Safety + Migration Purity (CR-SL-12..14)

- **CR-SL-12**: SaveManager MUST capture a deep-duplicated snapshot before serialization (per CR-SL-9 step 1). The source `SaveContext` may share references to mutable Resources (`echo_marks_archive: Array[EchoMark]`); without deep duplication, mutations to the source between `save_checkpoint(source)` invocation and the deferred `ResourceSaver.save()` produce **torn writes** (some EchoMarks reflect pre-mutation, others reflect post). The `DUPLICATE_DEEP_ALL_BUT_SCRIPTS` flag is correct per ADR-0003 (scripts shared by reference because they are immutable program code; data Resources deep-copied because they are mutable state).
- **CR-SL-13**: Migration callables in `SaveMigrationRegistry._migrations` MUST be **pure functions** operating ONLY on the `SaveContext` argument. Capturing a node, singleton, or object reference from the enclosing scope is FORBIDDEN per ADR-0003 §Schema Stability §Migration Callable Purity (BLOCKING) — captured references outlive the migration's invocation and leak for process lifetime, eventually producing dangling references into freed scenes. Lint candidate: source-grep `_migrations` Dictionary entries for non-static-context references.
- **CR-SL-14**: Every `from_version` in the migration chain MUST reach `CURRENT_SCHEMA_VERSION`. Gaps (e.g. version 1 → version 3 without a v2 step) are FORBIDDEN. Loader iterates `while ctx.schema_version < current` calling `_migrations.get(ctx.schema_version, Callable())`; if the Callable is invalid (gap), `save_load_failed.emit("load", "no_migration_from_v%d")` fires and the partial-migrated context is returned (player surface: "Save file is from a newer version" error toast).

### 3.5 Cross-Chapter Continuity (CR-SL-15..17)

- **CR-SL-15**: Cross-chapter destiny state propagation is **populator-driven**: at `save_checkpoint_requested(ctx)`, Destiny State (autoload subscriber per CR-DS-7 + CR-DS-16) populates `ctx.echo_count` + `ctx.echo_marks_archive` + `ctx.flags_to_set`. SaveManager does NOT directly query Destiny State — it serves as the disk I/O layer only. This indirection preserves Pillar 2 architectural lock pattern (Destiny State owns its archive lifecycle; SaveManager owns disk persistence).
- **CR-SL-16**: `scenario_path_key: String` field is `"::"`-delimited composite of `branch_path_id` values per scenario-progression.md §F-SP-4 (cross-doc downstream obligation). Format: `"WIN_ch1_default::DRAW_ch2_fallback::DRAW_ch3_echo"` (per F-SP-4 example). `branch_path_id` values match regex `^[A-Za-z0-9_]+$` (alphanumerics + underscore only); the `"::"` separator is collision-free. **Migration note**: pre-rev-2.1 saves used `"-"` delimiter; if any pre-rev-2.1 save data exists in the wild, a `from_version` migration callable rewrites the `scenario_path_key` field by replacing `"-"` with `"::"`. MVP scope: no pre-rev-2.1 saves exist (project is pre-launch); migration is documented for future reference but not yet shipped.
- **CR-SL-17**: `branch_key: StringName` field carries the resolved DestinyBranchChoice's branch_key per F-DB-1. Single-chapter granularity. To reconstruct the full multi-chapter narrative trajectory, `scenario_path_key` (CR-SL-16 composite) is the authoritative read; `branch_key` reflects only the most-recently-resolved chapter.

### 3.6 Hydration Contract (CR-SL-18..20)

- **CR-SL-18**: SaveManager exposes `load_latest_checkpoint() -> SaveContext` (per ADR-0003 §Key Interfaces). Caller is Main Menu's "Continue" button handler OR ScenarioRunner's resume-from-save flow. Returns `null` if active slot is empty (fresh install or wiped slot). Migration is applied transparently per CR-SL-14.
- **CR-SL-19**: Future signal `save_loaded(ctx: SaveContext)` is **declared in this GDD** as a contract surface (NOT yet shipped in `game_bus.gd` lines 73-75 — only `save_checkpoint_requested` + `save_persisted` + `save_load_failed` are declared post-ADR-0003). Per CR-DS-17, Destiny State subscribes to `save_loaded` for hydration. Sprint-8+ implementation ships `save_loaded` as a 4th Persistence-domain GameBus signal via ADR-0001 minor amendment per Evolution Rule #4. Until shipped, hydration is method-call driven (`SaveManager.load_latest_checkpoint()` returns ctx + caller manually distributes to Destiny State + ScenarioRunner via setter methods).
- **CR-SL-20**: Hydration is **idempotent**: calling `load_latest_checkpoint()` twice with no intervening saves produces field-identical `SaveContext` instances (modulo deep-duplicate identity). This is structurally guaranteed because (a) ResourceLoader.load with CACHE_MODE_IGNORE always re-reads from disk, (b) no migration callable mutates source ctx (each callable returns a new ctx instance per CR-SL-13 purity contract).

### 3.7 Failure Surfacing (CR-SL-21..22)

- **CR-SL-21**: Every save/load failure path MUST emit `save_load_failed(op: String, reason: String)` on GameBus per ADR-0003 §Key Interfaces. `op ∈ {"save", "load"}`; `reason` is a structured snake_case identifier (e.g., `"resource_saver_error:5"`, `"atomic_rename_failed:7"`, `"invalid_resource:user://saves/slot_1/ch_01_cp_2.res"`, `"no_migration_from_v3"`). UI subscribers (Main Menu error toast, in-game save indicator) translate the structured reason into player-facing localized strings.
- **CR-SL-22**: SaveManager MUST NEVER crash on save/load failure. Every error path returns gracefully: save errors return `false` from `save_checkpoint(source)`; load errors return `null` from `load_latest_checkpoint()`. Player-facing surfacing is the consumer's responsibility (toast, dialog, "fresh start" fallback). Per ADR-0003 §Constraints "Failures never crash; emit save_load_failed and surface to player".

---

## 4. Formulas

### F-SL-1 — Path resolution

```text
_path_for(slot: int, chapter_number: int, cp: int) -> String:
  return "user://saves/slot_%d/ch_%02d_cp_%d.res" % [slot, chapter_number, cp]
```

| Variable | Symbol | Type | Range | Source |
|----------|--------|------|-------|--------|
| Slot identifier | slot | int | 1..3 | SLOT_COUNT constant |
| Chapter number | chapter_number | int | 1..30 (MVP: 1..3) | ChapterDefinition |
| Checkpoint marker | cp | int | 1..3 | CP-1/2/3 emission per CR-SL-5 |
| Output path | (return) | String | `user://saves/slot_N/ch_MM_cp_K.res` | derived |

Filename format `ch_MM_cp_N` uses two-digit zero-padded chapter number for natural lexical ordering at any directory listing tool. CP suffix is single-digit (1/2/3 only).

---

### F-SL-2 — Newest-checkpoint resolution

```text
_find_latest_cp_file(slot: int) -> String:
  files := DirAccess.get_files_at("user://saves/slot_%d" % slot)
  best_path := ""
  best_key := -1
  for f in files:
    if not f.ends_with(".res"): continue
    parts := f.trim_suffix(".res").split("_")
    if parts.size() != 4 or parts[0] != "ch" or parts[2] != "cp": continue
    key := int(parts[1]) * 10 + int(parts[3])  # e.g. ch_02_cp_1 → 21
    if key > best_key:
      best_key = key
      best_path = "user://saves/slot_%d/%s" % [slot, f]
  return best_path
```

Sort key: `chapter_number * 10 + cp`. `ch_01_cp_3.res` → key 13; `ch_02_cp_1.res` → key 21; the latter wins. Per ADR-0003 §Key Interfaces. Returns empty string if slot is empty (caller treats as "no save in this slot").

---

### F-SL-3 — Schema migration chain

```text
migrate_to_current(ctx: SaveContext) -> SaveContext:
  current := SaveManager.CURRENT_SCHEMA_VERSION
  while ctx.schema_version < current:
    step := _migrations.get(ctx.schema_version, Callable())
    if not step.is_valid():
      GameBus.save_load_failed.emit("load", "no_migration_from_v%d" % ctx.schema_version)
      return ctx  # partial-migrated; consumer surfaces error
    ctx = step.call(ctx) as SaveContext
  return ctx
```

| Variable | Type | Notes |
|----------|------|-------|
| ctx | SaveContext | Input + output (migration callables return mutated ctx) |
| current | int | Current schema version per `SaveManager.CURRENT_SCHEMA_VERSION` |
| step | Callable | Migration function: `Callable(SaveContext) -> SaveContext` |

Migration callables are stored in `SaveMigrationRegistry._migrations: Dictionary[int, Callable]`. Each callable maps `from_version → next_version` (typically `+1` increment; gaps forbidden per CR-SL-14). Pure functions per CR-SL-13.

---

### F-SL-4 — Atomic write protocol

```text
save_checkpoint(source: SaveContext) -> bool:
  # Step 1: deep-duplicate snapshot (CR-SL-12)
  snapshot := source.duplicate_deep(Resource.DUPLICATE_DEEP_ALL_BUT_SCRIPTS) as SaveContext
  snapshot.schema_version = CURRENT_SCHEMA_VERSION
  snapshot.saved_at_unix = int(Time.get_unix_time_from_system())

  # Step 2: write to tmp
  final_path := _path_for(_active_slot, snapshot.chapter_number, snapshot.last_cp)
  tmp_path := final_path + ".tmp"
  if ResourceSaver.save(snapshot, tmp_path) != OK:
    GameBus.save_load_failed.emit("save", "resource_saver_error:%d" % err)
    return false

  # Step 3: atomic rename (CR-SL-9 step 3, user:// only per CR-SL-10)
  da := DirAccess.open(SAVE_ROOT)
  if da == null:
    GameBus.save_load_failed.emit("save", "dir_access_open_failed")
    return false
  if da.rename_absolute(tmp_path, final_path) != OK:
    GameBus.save_load_failed.emit("save", "atomic_rename_failed:%d" % err)
    return false

  # Step 4: success signal
  GameBus.save_persisted.emit(snapshot.chapter_number, snapshot.last_cp)
  return true
```

Atomicity invariant: if step 3 fails, the `.tmp` file may be left on disk but the `final_path` is unchanged — the loader's `_find_latest_cp_file` filters by `.res` extension, so `.tmp` files are invisible to the load path. Cleanup of stale `.tmp` files is a Polish-deferred housekeeping task (not load-blocking).

---

### F-SL-5 — `scenario_path_key` composition (cross-doc bridge from F-SP-4)

```text
scenario_path_key(chapter_outcomes: Array[Dictionary]) -> String:
  parts := chapter_outcomes.map(func(c): return c["branch_path_id"])
  return "::".join(parts)
```

| Variable | Type | Notes |
|----------|------|-------|
| chapter_outcomes | Array[{chapter_id, branch_path_id, echo_count_at_completion}] | per-chapter resolved outcomes |
| branch_path_id | String | per-chapter authored ID; regex `^[A-Za-z0-9_]+$` |
| (return) | String | `"::"`-joined composite key |

Example: `["WIN_ch1_default", "DRAW_ch2_fallback", "DRAW_ch3_echo"]` → `"WIN_ch1_default::DRAW_ch2_fallback::DRAW_ch3_echo"`. Used by ScenarioRunner SCENARIO_END epilogue selection per scenario-progression.md §CR-16. Persisted in `SaveContext.scenario_path_key` (FUTURE schema_version 2 field — not shipped MVP per CR-SL-1 12-field count; deferred to post-MVP epilogue authoring epic). Migration note: pre-rev-2.1 saves used `"-"` delimiter; if encountered, replace `"-"` with `"::"` in a future migration callable. Per scenario-progression.md F-SP-4 cross-doc downstream obligation.

---

## 5. Edge Cases

- **EC-SL-1** — Mid-write crash. Process killed between `ResourceSaver.save(snapshot, tmp_path)` step 2 and `rename_absolute` step 3. **Result**: no partial write visible to loader; `final_path` unchanged from prior version (or absent if first save); `.tmp` file may remain on disk but is filtered out by `_find_latest_cp_file` extension check. Player resume: previous successful checkpoint loads. Cleanup of stale `.tmp` Polish-deferred.

- **EC-SL-2** — Corrupted save file. `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` returns `null` OR returns a Resource that is not a `SaveContext` instance. **Result**: `load_latest_checkpoint()` returns `null` AND emits `save_load_failed.emit("load", "invalid_resource:%s" % path)`. Caller (Main Menu / ScenarioRunner) surfaces "Save file is corrupted" error toast; offers fresh-start fallback. Future: Save Slot UI flags slot as `corrupt: true` per ADR-0003 §Key Interfaces `list_slots()` return shape.

- **EC-SL-3** — Schema migration gap. SaveContext on disk has `schema_version=3` but `_migrations` lacks a v3-handler (v3 was a future version that never shipped, OR v3 saves came from a newer build). **Result**: `migrate_to_current(ctx)` early-returns at the gap; emits `save_load_failed.emit("load", "no_migration_from_v3")`. Player surface: "Save file is from a newer version" error. Cannot auto-repair; requires either (a) downgrade build OR (b) manual save-file deletion.

- **EC-SL-4** — Slot deletion mid-session. Player wipes slot 1 from a Save Slot UI; SaveManager's `_active_slot == 1`. **Result**: in-memory state is unchanged (SaveManager doesn't cache slot contents); next `save_checkpoint_requested` re-creates `ch_NN_cp_K.res` files in the wiped slot directory. Player effectively "starts over" within the same play session. Considered correct behavior for MVP (no warning dialog). Future: consider "Are you sure?" prompt at slot-wipe UI if it's reachable mid-session.

- **EC-SL-5** — SAF / external storage attempt. Per CR-SL-10, save root MUST remain `user://`. If a future code path attempts to write to external storage (SAF, NSCachesDirectory, etc.), atomic rename guarantees break and saves can corrupt under crash conditions. **Mitigation**: lint `lint_save_root_user_only.sh` (CR-SL-10 candidate) greps for `ResourceSaver.save` calls outside the `_path_for(slot, ch, cp)` resolved path; fails CI on any non-`user://` save path.

- **EC-SL-6** — Concurrent save_checkpoint_requested events (e.g., ScenarioRunner emits CP-2 then immediately CP-3 in the same deferred frame). **Result**: events are serialized via Godot's deferred-signal queue (CONNECT_DEFERRED guarantees per-frame ordering). SaveManager processes them sequentially: `_on_save_checkpoint_requested(ctx_cp2)` returns before `_on_save_checkpoint_requested(ctx_cp3)` fires. Both files are written; `_find_latest_cp_file` resolves cp_3 as newer per F-SL-2 ordering. No race condition possible.

- **EC-SL-7** — Disk full. `ResourceSaver.save(snapshot, tmp_path)` returns `Error.ERR_FILE_NO_PERMISSION` or similar. **Result**: `save_checkpoint(source)` returns `false`; `save_load_failed.emit("save", "resource_saver_error:N")` fires. Player-facing: "Cannot save — storage full" error toast. CP-2 (the critical post-resolution save) failure is escalated by ScenarioRunner per future error-handling design (NOT shipped MVP — failure is silent except for the toast).

- **EC-SL-8** — EchoMark schema drift. Loaded archive contains EchoMarks with fields that don't match current EchoMark schema (e.g., new `chapter_id` field added in v2 that v1 saves lack). **Result**: ResourceLoader populates the missing field with the @export default. Destiny State's CR-DS-18 silent-drop guard catches malformed marks (e.g., `beat_index <= 0` defaults). Schema migration callable per F-SL-3 SHOULD upgrade EchoMarks at load — MVP scope (single schema_version=1) does not yet need this; sprint-8+ may add chapter_id field per OQ-DS-1.

- **EC-SL-9** — `slot_id` field on disk doesn't match directory path. SaveContext was written to slot 2 directory but `ctx.slot_id == 1`. **Result**: `slot_id` is informational per ADR-0003 §Key Interfaces ("authoritative slot identity is the directory path on disk"); load proceeds normally. The mismatch is logged at debug level. Possible cause: manual file copy by a player. Tolerated.

- **EC-SL-10** — Hot reload during save (developer workflow only). Game restarts via Godot editor F5 mid-save. **Result**: process termination can occur between any of CR-SL-9 step 1-3. Atomic rename invariant still holds per EC-SL-1. Developer-side cleanup (delete stale `.tmp`) is manual; QA-side test fixtures use `before_test()` to wipe a temp save root entirely.

- **EC-SL-11** — `save_loaded` signal not yet shipped (CR-SL-19 future signal slot). MVP hydration uses method-call dispatch: `var ctx := SaveManager.load_latest_checkpoint(); DestinyState.rehydrate(ctx); ScenarioRunner.rehydrate(ctx)`. Ordering matters: ScenarioRunner's chapter advance must NOT fire before Destiny State has rehydrated archive + flags (race would produce empty echo_count at first DestinyBranchChoice resolution). Sprint-8+ implementation ratifies the manual-dispatch ordering OR ships `save_loaded` signal via ADR-0001 amendment.

---

## 6. Dependencies

| System | Direction | Coupling | Notes |
|--------|-----------|----------|-------|
| **Scenario Progression** (#6, MVP) | In | Hard (CP-1/2/3 emission source) | ScenarioRunner sole emitter of `save_checkpoint_requested(ctx)` per CR-SL-5 + CR-SL-8. Populates ctx.chapter_id + chapter_number + last_cp + outcome + branch_key fields per ADR-0017 §F-SP-3 (echo lifecycle + outcome capture). |
| **Scene Manager** (#3, MVP) | In | Hard (CP-2/3 timing source) | SceneManager RETURNING_FROM_BATTLE → IDLE transition is the CP-2 timing boundary per ADR-0002 + ADR-0003 §Decision §3-CP policy. CP-3 timing is next-chapter IDLE entry. ScenarioRunner subscribes to `scene_state_changed` to detect both boundaries. |
| **Destiny State** (#16, VS) | In | Hard (echo + flag populator) | Destiny State subscribes to `save_checkpoint_requested(ctx)` per CR-DS-7 + CR-DS-16; populates ctx.echo_count + echo_marks_archive + flags_to_set; releases to SaveManager. Reverse direction (CR-SL-19 future): subscribes to `save_loaded(ctx)` for rehydration per CR-DS-17. |
| **Destiny Branch** (#4, MVP) | In | Soft (branch_key emission source) | DestinyBranchChoice.branch_key per F-DB-1 lands in `ctx.branch_key` via ScenarioRunner's BEAT_7 capture per ADR-0017 + ADR-0018. SaveManager never queries DestinyBranchJudge directly. |
| **Battle (Grid Battle)** (#7, MVP) | In | Soft (BattleOutcome.Result emitter) | BattleOutcome.Result enum integer value lands in `ctx.outcome` via ScenarioRunner's BEAT_7 capture per ADR-0014. Enum ordering FROZEN per CR-SL-4 — append-only. |
| **Hero Database** (#?) | — | NONE | Hero data is not save-state — heroes live in `assets/data/heroes/heroes.json` and are loaded fresh per session. Saves do NOT serialize hero stat arrays. |
| **Balance/Data** (#5, MVP) | — | NONE | Balance constants live in `assets/data/balance/*.json` and are loaded fresh per session. Saves do NOT serialize tunable constants. |
| **GameBus** (#1, MVP) | In/Out | Hard (signal transport) | 1 subscription in (`save_checkpoint_requested`) + 2 emissions out (`save_persisted` + `save_load_failed`) per ADR-0001 §Persistence domain. CR-SL-19 future addition: `save_loaded(ctx)` 4th Persistence-domain signal via ADR-0001 minor amendment. |
| **Save Slot UI** (#18, Alpha) | Out | Hard (slot enumeration consumer) | Reads `SaveManager.list_slots() -> Array[Dictionary]` for slot screen rendering. Each entry: `{slot_id, empty, chapter_number, last_cp, saved_at_unix}` OR `{slot_id, empty: true}` OR `{slot_id, empty: true, corrupt: true}` per ADR-0003 §Key Interfaces. |
| **Main Menu** (#21, Alpha) | Out | Soft (Continue button presence) | "Continue" button presence/availability gated on `SaveManager.list_slots()` containing at least one non-empty slot. |

---

## 7. Tuning Knobs

| Constant | Default | Where | Rationale |
|----------|---------|-------|-----------|
| `SLOT_COUNT` | `3` | `SaveManager.SLOT_COUNT` constant in `src/core/save_manager.gd` | Mobile-friendly slot count: enough for parallel runs (canonical / experimental / wildcard) without overwhelming the Save Slot UI. Increasing requires UI layout revision. |
| `CURRENT_SCHEMA_VERSION` | `1` | `SaveManager.CURRENT_SCHEMA_VERSION` constant | Bump on any additive OR breaking change to `SaveContext` schema. Migration callable required for non-additive bumps. |
| `SAVE_ROOT` | `"user://saves"` | `SaveManager.SAVE_ROOT` constant | MUST stay `user://` per CR-SL-10 (atomic rename guarantee). Subdirectory `saves` keeps save artifacts separate from other `user://` content (settings, telemetry). |
| `SAVE_PAYLOAD_BUDGET_KB` | `50` | (informational) | Per ADR-0003 §Constraints. Typical expected payload 5–15 KB; FLAG_COMPRESS optional if budget exceeded. Above 50 KB triggers performance review (CP-2 serialization budget 50 ms on mid-tier Android). |
| `SAVE_SERIALIZE_BUDGET_MS` | `50` | (informational) | Per ADR-0003 §Constraints performance budget. CP-2 fires on a UI-responsive frame; any serialization above 50 ms is perceived as a hitch. Benchmark on minimum-spec mobile during sprint-8+ implementation. |
| `RESOURCE_SAVER_FLAG_COMPRESS_THRESHOLD_KB` | `50` | (informational) | Per ADR-0003 §Verification Required item 3. Apply `ResourceSaver.FLAG_COMPRESS` only if measured payload exceeds 50 KB; below threshold, compression overhead exceeds bandwidth savings. Re-evaluate at first save-payload benchmark. |

**Tuning guidance**:
- `SLOT_COUNT` is a hard contract surface for Save Slot UI. Increasing requires the UI to scroll or paginate; not recommended pre-launch.
- `SAVE_PAYLOAD_BUDGET_KB` is informational — actual payload size depends on EchoMarks accumulated. Pathological retry-heavy sessions can exceed if echo cap (`ECHO_ARCHIVE_HARD_CAP = 200` per Destiny State CR-DS-12) × EchoMark size grows. ECHO_ARCHIVE_HARD_CAP × 200 bytes/mark = ~40 KB worst-case. Still under budget.
- `CURRENT_SCHEMA_VERSION` bumps are a one-way ratchet. Down-version migration is NOT supported (saves from a newer build cannot be loaded on an older build per EC-SL-3).

---

## 8. Acceptance Criteria

### 8.1 Three-Checkpoint Emission (AC-SL-1..4)

- **AC-SL-1**: Given a fresh chapter (chapter_id = `&"ch01_changbanpo"`) starting at BEAT_1_INTRO, when ScenarioRunner enters BEAT_1, then `save_checkpoint_requested(ctx)` is emitted exactly once with `ctx.chapter_id == &"ch01_changbanpo"` AND `ctx.last_cp == 1` AND `ctx.chapter_number == 1`.
  - **Evidence**: GdUnit4 integration test `test_cp1_emission_at_beat_1_entry`.
- **AC-SL-2**: Given a chapter resolved at Beat 7 with outcome WIN + branch_key `&"WIN_changbanpo_default"`, when SceneManager transitions RETURNING_FROM_BATTLE → IDLE, then `save_checkpoint_requested(ctx)` is emitted exactly once with `ctx.last_cp == 2` AND `ctx.outcome == BattleOutcome.WIN_AS_INT` AND `ctx.branch_key == &"WIN_changbanpo_default"`.
- **AC-SL-3**: Given Chapter 1 just resolved + Chapter 2 enters at BEAT_1_INTRO, when ScenarioRunner enters BEAT_1 of Chapter 2, then `save_checkpoint_requested(ctx)` is emitted with `ctx.last_cp == 3` AND `ctx.chapter_number == 2`. (CP-3 marks "previous chapter completed + transitioned" per CR-SL-5.)
- **AC-SL-4**: Given a chapter complete cycle (CP-1 → battle → CP-2 → next chapter CP-1 (= prior chapter's CP-3)), when all three CPs fire, then 3 distinct files exist in `user://saves/slot_X/`: `ch_01_cp_1.res` + `ch_01_cp_2.res` + `ch_02_cp_1.res`. (Note: ch_01's CP-3 == ch_02's CP-1 by ScenarioRunner emission sequence.)

### 8.2 Atomic Write + Schema (AC-SL-5..8)

- **AC-SL-5**: Given `save_checkpoint(source)` invoked, when serialization completes, then `final_path` exists on disk AND `final_path + ".tmp"` does NOT exist (atomic rename succeeded). Source `SaveContext` may be freely mutated post-call without affecting the saved file (deep-duplicate per CR-SL-12).
- **AC-SL-6**: Given a SaveContext with `schema_version == 0` (impossible value — older than v1), when `migrate_to_current(ctx)` is invoked, then `save_load_failed.emit("load", "no_migration_from_v0")` fires AND ctx is returned with `schema_version == 0` (partial-migrate per CR-SL-14). Lint: `_migrations.has(0) == false` is the test fixture.
- **AC-SL-7**: Given a `SaveContext` with all 12 @export fields populated (CR-SL-1) + 5 EchoMarks in archive + 3 flags, when `ResourceSaver.save()` writes + `ResourceLoader.load()` re-reads with CACHE_MODE_IGNORE, then loaded ctx has field-identical content (deep-equal) to the original AND distinct Object identity (proves disk round-trip per CR-SL-11).
- **AC-SL-8**: Given a save root path attempt outside `user://` (e.g. test fixture mocks SAVE_ROOT to `res://saves`), when SaveManager initializes, then `_ensure_save_root` MUST fail per ADR-0003 atomicity invariant. (Test fixture verifies the lint contract at runtime; CI lint enforces source-side.)

### 8.3 Multi-Slot Independence (AC-SL-9..11)

- **AC-SL-9**: Given slot 1 contains `ch_01_cp_2.res` AND slot 2 is empty, when SaveManager.set_active_slot(2) + save_checkpoint(source), then `user://saves/slot_2/ch_01_cp_2.res` is created AND `user://saves/slot_1/ch_01_cp_2.res` is unchanged (slot 1 file size + mtime preserved). Slots are **independent**.
- **AC-SL-10**: Given slot 1 contains 4 files (ch_01_cp_1, ch_01_cp_2, ch_01_cp_3, ch_02_cp_1) AND slot 3 is empty, when `SaveManager.list_slots()` is invoked, then return value is `[{slot_id:1, empty:false, chapter_number:2, last_cp:1, saved_at_unix:T}, {slot_id:2, empty:true}, {slot_id:3, empty:true}]`. Newest-CP resolution per F-SL-2.
- **AC-SL-11**: Given a corrupted file in slot 1 (`ch_01_cp_2.res` is not a SaveContext), when `list_slots()` is invoked, then slot 1's entry includes `corrupt: true` per ADR-0003 §Key Interfaces. Save Slot UI flags slot as corrupt; "Continue" flow refuses to load.

### 8.4 Cross-Chapter Continuity (AC-SL-12..14)

- **AC-SL-12**: Given a complete chapter cycle with 3 EchoMarks accumulated + 1 divergence flag set in Chapter 1, when `save_checkpoint_requested(ctx)` fires at CP-2, then Destiny State populates `ctx.echo_count == 3` AND `ctx.echo_marks_archive.size() == 3` AND `ctx.flags_to_set.size() == 1` (per CR-SL-15 + CR-DS-16 contract).
- **AC-SL-13**: Given a SaveContext with full Destiny State populated, when round-tripped through ResourceSaver → ResourceLoader, then loaded ctx has bitwise-equivalent echo_marks_archive + flags_to_set + echo_count to pre-save state (per AC-DS-20 mirror).
- **AC-SL-14**: Given a SaveContext from a multi-chapter run with `scenario_path_key == "WIN_ch1_default::DRAW_ch2_fallback"`, when persisted + loaded, then loaded ctx.scenario_path_key field-equals the source string (delimiter `"::"` preserved per CR-SL-16). (Future schema_version 2 — MVP scope skips this AC for v1; ScenarioRunner persists `scenario_path_key` only at SCENARIO_END epilogue selection per scenario-progression.md F-SP-4.)

### 8.5 Failure Surfacing (AC-SL-15..17)

- **AC-SL-15**: Given disk full simulated via test fixture (forced ResourceSaver error code), when `save_checkpoint(source)` is invoked, then return is `false` AND `save_load_failed.emit("save", "resource_saver_error:%d")` fires AND no partial file is left in `final_path` (`.tmp` may persist but extension filter hides it).
- **AC-SL-16**: Given a malformed SaveContext file in slot 1 (truncated mid-Resource), when `load_latest_checkpoint()` is invoked, then return is `null` AND `save_load_failed.emit("load", "invalid_resource:...")` fires. Caller surfaces error toast.
- **AC-SL-17**: Given a process kill simulated mid-write (test fixture: `os._exit()` between ResourceSaver.save and rename_absolute), when game restarts + `load_latest_checkpoint()` invokes, then loader skips the orphan `.tmp` AND returns the prior successful checkpoint OR `null` if no prior. Atomic invariant per EC-SL-1.

### 8.6 Determinism + Round-Trip (AC-SL-18..20)

- **AC-SL-18**: Given two SaveManager instances with identical seeded state (test fixture: same SaveContext in-memory), when both invoke `save_checkpoint(source)` then immediately `load_latest_checkpoint()`, then both return field-identical SaveContext instances. No `Time.*` / `rand*` non-determinism in the save/load path beyond the explicit `saved_at_unix` field (which is captured at save-time once per save).
- **AC-SL-19**: Given a `SaveContext` round-tripped through ResourceSaver/Loader, when verified across ≥2 platforms (Linux Editor + macOS Apple Silicon dev-machine sufficient for MVP per AC-DB-24 5-platform deferral pattern), then loaded ctx is bitwise-equivalent across platforms. Full 5-platform verification (Windows D3D12 + iOS Metal + Android Vulkan) deferred to release-prep epic.
- **AC-SL-20**: Given an idempotent hydration pattern (load → distribute → no further mutation → load again), when `load_latest_checkpoint()` is called twice in succession, then both calls return field-identical ctx (per CR-SL-20 idempotency contract).

---

## Open Questions (OQ-SL-1..5)

- **OQ-SL-1**: Should mid-battle autosave be supported (e.g. between Beat 5 turns) for additional crash-recovery granularity? Currently MVP scope limits saves to the 3 narrative checkpoints; mid-battle autosave would require capturing Grid Battle controller state (units, hp_status, turn order, etc.) — significantly larger payload and higher serialization frequency. Decision deferred to post-MVP per Producer scoping.

- **OQ-SL-2**: Should cloud-sync be supported (iCloud / Google Play Saves) for cross-device save continuity? MVP is local-only per `user://` root constraint. Cloud sync requires platform SDK integration (CloudKit, Play Games Services) + conflict-resolution UX (which save wins on conflict?). Decision deferred to post-launch live-ops scope.

- **OQ-SL-3**: Should `save_loaded(ctx: SaveContext)` GameBus signal slot be added in sprint-8+ implementation OR hydration remain method-call dispatched? Pro-signal: cleaner subscriber pattern (Destiny State + ScenarioRunner both subscribe per CR-DS-17). Pro-method: explicit ordering control (load → Destiny State first → ScenarioRunner second; signal-driven would require CONNECT_DEFERRED ordering discipline). Recommend signal-driven per CR-SL-19 + ADR-0001 minor amendment Evolution Rule #4. **Resolution candidate**: ship `save_loaded` at S8-08 implementation OR sprint-9 hydration epic.

- **OQ-SL-4**: What metadata does Save Slot UI need beyond `{chapter_number, last_cp, saved_at_unix}`? Candidate additions: `play_time_seconds` (already on SaveContext per ADR-0003), `chapter_id` (StringName → localized chapter title via Balance/Data lookup), `outcome` of last resolution (WIN/DRAW/LOSS as icon), `echo_count` (gameplay tag for retry-heavy runs), `branch_key` (narrative tag for canonical/divergent runs). Decision deferred to Save Slot UI authoring (Alpha tier per systems-index #18).

- **OQ-SL-5**: Should slot deletion be reversible (soft-delete with undo) OR hard-delete? MVP scope: hard-delete (Save Slot UI's "Wipe Slot" button immediately removes all `ch_NN_cp_K.res` files in the slot directory). Soft-delete adds a "trash" subdirectory with N-day retention — more code, more complexity, more disk usage. Decision: hard-delete with confirmation dialog ("Are you sure? This cannot be undone.") is sufficient for MVP. Re-evaluate if player feedback indicates accidental wipes.

---

## Implementation hooks (sprint-8+ — design-only this delta)

The following are **NOT** shipped this design-only GDD delta; documented for the implementation epic (sprint-8+ candidate per VS tier scope; ADR-0003 architecture is already Accepted but no implementation has shipped):

1. `src/core/save_manager.gd` (~150 LoC autoload Node 4th invocation per ADR-0003 §Decision boot order) — `class_name SaveManager` (or omit per G-3 verification at implementation time, mirrors GameBus + SceneManager precedent).
2. `src/core/save_context.gd` (~50 LoC Resource with 12 @export fields per CR-SL-1).
3. `src/core/save_migration_registry.gd` (~30 LoC RefCounted with `_migrations: Dictionary[int, Callable]` static var; v1 currently empty per ADR-0003 §Key Interfaces).
4. `src/core/payloads/echo_mark.gd` (existing per ADR-0003 EchoMark Resource Contract; verify @export discipline on every field).
5. `tools/ci/lint_save_root_user_only.sh` — CR-SL-10 enforcement (no save path outside `user://`).
6. `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh` — CR-SL-11 enforcement (every ResourceLoader.load in save_manager.gd uses CACHE_MODE_IGNORE).
7. `tools/ci/lint_save_migration_callable_purity.sh` — CR-SL-13 enforcement (no captured-reference patterns in `_migrations` Dictionary entries).
8. `tools/ci/lint_save_context_export_discipline.sh` — CR-SL-2 enforcement (every field on SaveContext + EchoMark MUST have `@export` annotation).
9. `tests/unit/core/save_manager_atomic_write_test.gd` (AC-SL-5..8) — atomic rename + schema migration + ResourceSaver/Loader round-trip.
10. `tests/unit/core/save_manager_multi_slot_test.gd` (AC-SL-9..11) — slot independence + list_slots metadata + corruption flagging.
11. `tests/integration/scenario_runner/save_checkpoint_emission_test.gd` (AC-SL-1..4) — 3-CP emission contract from ScenarioRunner; verifies CP-1/2/3 firings.
12. `tests/integration/save_load/cross_chapter_continuity_test.gd` (AC-SL-12..14) — Destiny State populator pattern + cross-chapter flag persistence.
13. `tests/integration/save_load/failure_surfacing_test.gd` (AC-SL-15..17) — disk full simulation + corrupted file + mid-write crash recovery.
14. `project.godot` autoload registration: `SaveManager="*res://src/core/save_manager.gd"` at boot order position 3 (after GameBus position 1 + SceneManager position 2; before any Feature-layer autoload). Per ADR-0003 + ADR-0017 mount order.
15. ADR-0001 minor amendment per Evolution Rule #4: add `save_loaded(ctx: SaveContext)` 4th Persistence-domain signal (CR-SL-19 future signal slot). Pending OQ-SL-3 resolution.
16. systems-index.md row 17 status: Not Started → Designed (this delta closes it; sprint-8+ implementation flips to Implemented).

---

## Cross-references

- **Governing**: ADR-0003 SaveContext + SaveManager + SaveMigrationRegistry; ADR-0017 ScenarioRunner §F-SP-3 (echo lifecycle + CP-1/2/3 emission); ADR-0002 SceneManager (CP-2/3 timing boundaries via RETURNING_FROM_BATTLE → IDLE transition); ADR-0018 DestinyBranch §F-DB-1 (branch_key emission for ctx.branch_key field).
- **Pillar substrate**: game-concept.md §Pillar 4 (지난 장의 선택이 살아 있다 — save persistence enables cross-chapter recognition); §Session safety (mobile interruption tolerance).
- **Upstream populators**: scenario-progression.md §F-SP-3 (ScenarioRunner ctx.chapter_id + chapter_number + last_cp + outcome + branch_key + scenario_path_key); destiny-state.md §F-DS-5 (Destiny State ctx.echo_count + echo_marks_archive + flags_to_set per CR-DS-16).
- **Downstream consumers**: Save Slot UI #18 Alpha (`SaveManager.list_slots()` slot enumeration); Main Menu #21 Alpha ("Continue" button gating); Settings/Options #28 Alpha (slot management UI — wipe slot, switch active slot); Crash-recovery QA #25 (CP-1/2/3 recovery validation).
- **Cross-doc obligations**:
  - scenario-progression.md F-SP-4 line 383 cross-doc downstream obligation: `scenario_path_key` `"::"`-delimited String + `"-"` migration note (CR-SL-16 satisfies this).
  - destiny-state.md CR-DS-17 future signal slot: `save_loaded(ctx)` for hydration (CR-SL-19 + OQ-SL-3 satisfy this — pending sprint-8+ implementation).
- **Engine constraints**: tooling-gotchas.md G-3 (autoload no class_name — verify at implementation time); G-7 (silent-skip detection); G-22 (structural source-file assertion if needed for migration callable purity test).
- **Cross-platform contract**: ADR-0003 §Atomicity Guarantees Platform-Scoped Atomic Rename table (iOS/Android internal/macOS/Linux/Windows verified; Android SAF FORBIDDEN); §Verification Required item 1+2 (rename atomicity confirmation per platform).
