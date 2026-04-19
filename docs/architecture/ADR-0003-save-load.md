# ADR-0003: Save/Load — Checkpoint Persistence via Typed Resource + ResourceSaver

## Status

Accepted (2026-04-18)

## Date

2026-04-18

## Last Verified

2026-04-18

## Decision Makers

- Technical Director (architecture owner)
- User (final approval, 2026-04-18)
- godot-specialist (engine validation, 2026-04-18)
- Referenced by Scenario Progression GDD v2.0 (SaveContext schema, 3-CP policy)
  as the pattern to ratify

## Summary

천명역전 runs long sessions (9-beat ceremony × N chapters) during which the
player accrues irreplaceable narrative state: chapter outcomes (WIN/DRAW/LOSS),
branch_key selections, EchoMarks accumulated across retries, and narrative
flags. Losing this state to a crash, force-quit, or app swap on mobile would
destroy the player's run. This ADR ratifies a `SaveManager` autoload at
`/root/SaveManager` that captures a typed `SaveContext` Resource at three
per-chapter checkpoints (CP-1 entry / CP-2 post-resolution / CP-3 next-chapter
entry), serializes via `ResourceSaver.save()` under `user://saves/slot_X/`,
loads via `ResourceLoader.load()` with `CACHE_MODE_IGNORE`, and supports schema
migration through a versioned migration registry. Three save slots are
supported from MVP. All writes are atomic via write-to-tmp + `rename_absolute`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Persistence |
| **Knowledge Risk** | MEDIUM — `ResourceSaver` / `ResourceLoader` API stable since 4.0; `Resource.duplicate_deep()` is a 4.5+ feature confirmed against `docs/engine-reference/godot/modules/core.md`; `DirAccess.rename_absolute()` atomicity guarantees are platform-scoped and require explicit documentation |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/core.md` (ResourceSaver, ResourceLoader, DirAccess), `docs/engine-reference/godot/breaking-changes.md` (Resource.duplicate_deep 4.5+), `docs/engine-reference/godot/deprecated-apis.md` (DirAccess.list_dir_begin legacy pattern), ADR-0001 (signal relay), ADR-0002 (scene-boundary timing for CP-2) |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` — 4.5+. `DirAccess.get_files_at(path)` — preferred over legacy `list_dir_begin()` loop in 4.6. `ResourceSaver.FLAG_COMPRESS` bitflag — stable since 4.0. |
| **Verification Required** | (1) Confirm `DirAccess.rename_absolute()` atomicity guarantee on Android `/data/data/<package>/files/` (POSIX rename(2) holds; SAF external paths do NOT guarantee — save root MUST remain `user://`). (2) Confirm iOS behavior on `user://` (NSApplicationSupportDirectory) — POSIX rename atomic across app containers. (3) Benchmark `ResourceSaver.save()` with FLAG_COMPRESS on a full SaveContext payload (expected <20 KB uncompressed, <8 KB compressed); omit FLAG_COMPRESS if measured payload stays under 50 KB. (4) Confirm `Resource.duplicate_deep` property path on Godot 4.6 matches 4.5 semantics (scripts-excluded mode available). |

> **Note**: Knowledge Risk is MEDIUM. Re-validate if upgrading past Godot 4.6.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted 2026-04-18) — SaveManager subscribes to `save_checkpoint_requested` and emits `save_persisted` / `save_load_failed` on the GameBus relay. Ratifies ADR-0001's provisional `save_checkpoint_requested` signal and adds 2 new persistence signals. ADR-0002 (Accepted 2026-04-18) — CP-2 timing boundary is SceneManager's RETURNING_FROM_BATTLE → IDLE transition (ScenarioRunner observes via `battle_outcome_resolved` handler and emits the checkpoint request); CP-3 timing is SceneManager's next-chapter IDLE entry. |
| **Enables** | Scenario Progression implementation (#6 MVP — 3-CP recovery contract ratified); Save Slot UI (#18 Alpha — slot enumeration + metadata contract); Crash-recovery QA test suite (#25 QA — recovery from CP-1/CP-2/CP-3 validated). |
| **Blocks** | Scenario Progression v2.1 revision SaveContext lock; Save Slot UI implementation (requires SaveManager's slot enumeration API before any screen can list slots). |
| **Ordering Note** | Must be Accepted before any SaveContext-consuming code is written. Minor amendment to ADR-0001 (ratifies `save_checkpoint_requested` payload shape, adds `save_persisted` and `save_load_failed` signals) must land alongside this ADR. |

## Context

### Problem Statement

Scenario Progression GDD v2.0 §Detailed Rules declares three checkpoints per
chapter (CP-1 at Beat 1 entry, CP-2 post-Beat 7, CP-3 at next-chapter Beat 1
entry) and a SaveContext schema containing `chapter_id`, `outcome`, `branch_key`,
`echo_count`, `echo_marks_archive: Array[EchoMark]`, and `flags_to_set:
PackedStringArray`. Without a ratified persistence pattern, four failure modes
are imminent:

1. **Data-loss on crash** — long mobile sessions are routinely interrupted
   (phone calls, app swaps, OS memory pressure). A run with no save = lost run.

2. **Schema drift across versions** — patch releases that add fields to
   SaveContext (e.g., new narrative flags) will silently drop unknown fields
   on old saves, or worse, crash on missing fields in new code. A migration
   strategy must be baked in from day one.

3. **Half-written files** — mobile OS may kill the process mid-write. A
   non-atomic write leaves the save file corrupted and unrecoverable. The
   write-to-tmp + rename pattern is mandatory.

4. **Live-state serialization hazards** — `ResourceSaver.save()` on a live
   SaveContext that is still being mutated elsewhere produces torn writes.
   Capture must take a deep-duplicated snapshot before serialization.

The cost of not deciding: Scenario Progression cannot complete its v2.1
revision (SaveContext schema is blocking), Save Slot UI cannot start, and
crash-recovery QA cannot be authored.

### Current State

No SaveManager exists. No SaveContext Resource class exists. `user://saves/`
directory is unused. ADR-0001 has placeholder expectations for persistence
signals that this ADR fulfills.

### Constraints

- **Engine**: Godot 4.6, GDScript only (no GDExtension).
- **Platform**: iOS, Android, PC. `user://` root is the only guaranteed
  atomic-rename path (Android SAF external storage does NOT guarantee).
- **Memory**: 512 MB ceiling. SaveContext must stay under 50 KB serialized
  (typical expected size: 5–15 KB).
- **Signal contract**: Must use GameBus per ADR-0001. `CONNECT_DEFERRED`
  mandatory. No per-frame emits.
- **Testing**: GdUnit4. SaveManager stub must be injectable for tests
  (swap `user://` root to a temp path in `before_test`, cleanup in
  `after_test`).
- **Performance**: CP-2 save happens immediately after battle outcome, on a
  UI-responsive frame. Serialization must complete under 50 ms on mid-range
  Android (benchmark required).

### Requirements

1. **3-CP policy** — capture CP-1 at Beat 1 entry, CP-2 on SceneManager
   RETURNING_FROM_BATTLE → IDLE (post-Beat 7 resolution persisted), CP-3 at
   next-chapter Beat 1 entry. Per-chapter history kept as separate files.
   (Note: GDD v2.0 §Detailed Rules locates CP-2 "post-Beat 7"; this ADR
   binds that moment to SceneManager's transition boundary for a single
   testable trigger point.)
2. **Multi-slot** — three save slots from MVP. Slots are independent;
   overwriting slot 2 never touches slot 1 or 3.
3. **Atomic write** — write to `user://saves/slot_X/ch_MM_cp_N.res.tmp`,
   fsync, then `rename_absolute` to final filename. No partial writes
   visible to the loader.
4. **Schema migration** — every save file carries a `schema_version: int`.
   `SaveMigrationRegistry` holds a `Dictionary[int, Callable]` mapping
   `from_version → migration_fn(ctx: SaveContext) → SaveContext`. Loader
   applies migrations in sequence until current version reached.
5. **Live-state safety** — capture calls `source.duplicate_deep()` before
   ResourceSaver. No mutable reference shared between gameplay and save
   payload.
6. **Cache bypass** — all loads use `ResourceLoader.load(path, "",
   CACHE_MODE_IGNORE)`. Cached loads return stale post-overwrite objects.
7. **Crash recovery** — loader scans `user://saves/slot_X/` for newest
   `ch_MM_cp_N.res`, resolves which checkpoint is most recent.
8. **Failure signaling** — load/save failures emit `save_load_failed` on
   GameBus; ScenarioRunner surfaces player-facing error. Never crash.

## Decision

We adopt a single Godot autoload singleton at `/root/SaveManager` as the sole
owner of save persistence. SaveManager is signal-driven (subscribes to
`save_checkpoint_requested`, emits `save_persisted` / `save_load_failed`),
uses `ResourceSaver.save()` with optional `FLAG_COMPRESS`, loads with
`CACHE_MODE_IGNORE`, takes deep-duplicated snapshots before serialization,
and writes atomically via tmp + `rename_absolute`. Schema migration is
handled by a static `SaveMigrationRegistry`.

### Architecture

```
                    /root (SceneTree root)
                      │
    ┌─────────────────┼─────────────────┐──────────────────┐
    │                 │                 │                  │
┌───▼────┐     ┌──────▼──────┐   ┌──────▼──────┐    ┌──────▼──────┐
│GameBus │     │SceneManager │   │ SaveManager │    │ Scenario    │
│(auto-  │     │  (auto-     │   │  (auto-     │    │  Runner     │
│ load 1)│     │   load 2)   │   │   load 3)   │    │ (emits      │
│ signals│◀───▶│  (triggers  │   │  (persists  │◀──▶│  checkpoint │
│  relay │     │   CP-2      │   │   via       │    │  _requested)│
└────────┘     │   boundary) │   │   ResSaver) │    └─────────────┘
               └─────────────┘   └──────┬──────┘
                                        │
                                        ▼
                            user://saves/
                              ├── slot_1/
                              │    ├── ch_01_cp_1.res
                              │    ├── ch_01_cp_2.res
                              │    ├── ch_01_cp_3.res
                              │    └── ch_02_cp_1.res
                              ├── slot_2/
                              └── slot_3/
```

### File Layout

`user://saves/slot_{1,2,3}/ch_{MM}_cp_{N}.res` where `MM` is two-digit chapter
number and `N ∈ {1, 2, 3}`. Each chapter produces up to 3 checkpoint files;
older chapters' files are retained as run history until the slot is reset.

### Key Interfaces

**SaveContext Resource** (`src/core/save_context.gd`):

```gdscript
## SaveContext — the single typed payload persisted per checkpoint.
##
## Ratified by ADR-0003. Schema versioning is MANDATORY. Every persisted
## field MUST be annotated @export. Non-exported fields are SILENTLY DROPPED
## on serialization by ResourceSaver.
##
## See ADR-0003 §Schema Stability and §Migration for the versioning contract.
class_name SaveContext
extends Resource

## Schema version. Bump on every additive or breaking change.
## Loader consults SaveMigrationRegistry to upgrade old versions.
@export var schema_version: int = 1

## Slot this save belongs to (1–3). Informational; authoritative slot
## identity is the directory path on disk.
@export var slot_id: int = 1

@export var chapter_id: StringName = &""
@export var chapter_number: int = 1
@export var last_cp: int = 1              # 1, 2, or 3

## BattleOutcome.Result enum value. Enum ORDERING IS FROZEN — any reorder
## requires a migration function. Future schema version MAY switch to
## string ("WIN"|"DRAW"|"LOSS") for format-independence; until then, integer
## ordering is a persistence contract.
@export var outcome: int = 0

@export var branch_key: StringName = &""
@export var echo_count: int = 0

## EchoMark MUST extend Resource, declare class_name EchoMark, and annotate
## every persisted field with @export. See Schema Stability section below.
@export var echo_marks_archive: Array[EchoMark] = []

@export var flags_to_set: PackedStringArray = PackedStringArray()

@export var saved_at_unix: int = 0
@export var play_time_seconds: int = 0
```

**SaveManager autoload** (`src/core/save_manager.gd`):

```gdscript
## SaveManager — the single owner of save persistence.
##
## Ratified by ADR-0003. Consumes GameBus signals per ADR-0001.
##
## RULES:
##  - All saves are deep-duplicated before serialization (no live-state refs).
##  - All writes are atomic (tmp + rename_absolute on user:// only).
##  - All loads bypass cache (CACHE_MODE_IGNORE).
##  - Failures never crash; emit save_load_failed and surface to player.
##
## See ADR-0003 §Decision for topology.
class_name SaveManager
extends Node

const SAVE_ROOT: String = "user://saves"
const SLOT_COUNT: int = 3
const CURRENT_SCHEMA_VERSION: int = 1

## Read-only state.
var active_slot: int = 1:
    get: return _active_slot
    set(_v): push_error("SaveManager.active_slot is read-only; call set_active_slot()")

var _active_slot: int = 1

func _ready() -> void:
    GameBus.save_checkpoint_requested.connect(
        _on_save_checkpoint_requested, CONNECT_DEFERRED
    )
    _ensure_save_root()

func _exit_tree() -> void:
    if GameBus.save_checkpoint_requested.is_connected(_on_save_checkpoint_requested):
        GameBus.save_checkpoint_requested.disconnect(_on_save_checkpoint_requested)

## Persist a checkpoint. Deep-duplicates source; caller may mutate source
## freely after this returns.
func save_checkpoint(source: SaveContext) -> bool:
    var snapshot: SaveContext = source.duplicate_deep(
        Resource.DUPLICATE_DEEP_ALL_BUT_SCRIPTS
    ) as SaveContext
    snapshot.schema_version = CURRENT_SCHEMA_VERSION
    snapshot.saved_at_unix = int(Time.get_unix_time_from_system())

    var final_path: String = _path_for(
        _active_slot, snapshot.chapter_number, snapshot.last_cp
    )
    var tmp_path: String = final_path + ".tmp"

    # ResourceSaver flags: FLAG_COMPRESS only if payload >50 KB (benchmark gated).
    var err: Error = ResourceSaver.save(snapshot, tmp_path)
    if err != OK:
        GameBus.save_load_failed.emit("save", "resource_saver_error:%d" % err)
        return false

    var da: DirAccess = DirAccess.open(SAVE_ROOT)
    if da == null:
        GameBus.save_load_failed.emit("save", "dir_access_open_failed")
        return false
    err = da.rename_absolute(tmp_path, final_path)
    if err != OK:
        GameBus.save_load_failed.emit("save", "atomic_rename_failed:%d" % err)
        return false

    GameBus.save_persisted.emit(snapshot.chapter_number, snapshot.last_cp)
    return true

## Load the newest checkpoint in the active slot. Returns null if slot empty.
func load_latest_checkpoint() -> SaveContext:
    var path: String = _find_latest_cp_file(_active_slot)
    if path.is_empty():
        return null
    var raw: Resource = ResourceLoader.load(
        path, "", ResourceLoader.CACHE_MODE_IGNORE
    )
    if raw == null or not raw is SaveContext:
        GameBus.save_load_failed.emit("load", "invalid_resource:%s" % path)
        return null
    var ctx: SaveContext = raw as SaveContext
    return SaveMigrationRegistry.migrate_to_current(ctx)

## Enumerate slots with their newest-CP metadata for the Save Slot UI.
## Returns Array of { slot_id, chapter_number, last_cp, saved_at_unix } dicts,
## length SLOT_COUNT. Empty slots yield { slot_id, empty: true }.
func list_slots() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for i in range(1, SLOT_COUNT + 1):
        var path: String = _find_latest_cp_file(i)
        if path.is_empty():
            out.append({ "slot_id": i, "empty": true })
            continue
        var raw: Resource = ResourceLoader.load(
            path, "", ResourceLoader.CACHE_MODE_IGNORE
        )
        if raw is SaveContext:
            var ctx: SaveContext = raw as SaveContext
            out.append({
                "slot_id": i,
                "empty": false,
                "chapter_number": ctx.chapter_number,
                "last_cp": ctx.last_cp,
                "saved_at_unix": ctx.saved_at_unix,
            })
        else:
            out.append({ "slot_id": i, "empty": true, "corrupt": true })
    return out

func set_active_slot(slot: int) -> void:
    assert(slot >= 1 and slot <= SLOT_COUNT, "slot must be 1..%d" % SLOT_COUNT)
    _active_slot = slot

func _path_for(slot: int, chapter_number: int, cp: int) -> String:
    return "%s/slot_%d/ch_%02d_cp_%d.res" % [SAVE_ROOT, slot, chapter_number, cp]

func _ensure_save_root() -> void:
    DirAccess.make_dir_recursive_absolute(SAVE_ROOT)
    for i in range(1, SLOT_COUNT + 1):
        DirAccess.make_dir_recursive_absolute("%s/slot_%d" % [SAVE_ROOT, i])

## Newest file = highest chapter_number, then highest cp. Uses 4.6-idiomatic
## DirAccess.get_files_at (not legacy list_dir_begin loop).
func _find_latest_cp_file(slot: int) -> String:
    var dir: String = "%s/slot_%d" % [SAVE_ROOT, slot]
    var files: PackedStringArray = DirAccess.get_files_at(dir)
    var best: String = ""
    var best_key: int = -1
    for f in files:
        if not f.ends_with(".res"):
            continue
        # ch_{MM}_cp_{N}.res → key = MM*10 + N
        var parts: PackedStringArray = f.trim_suffix(".res").split("_")
        if parts.size() != 4 or parts[0] != "ch" or parts[2] != "cp":
            continue
        var key: int = int(parts[1]) * 10 + int(parts[3])
        if key > best_key:
            best_key = key
            best = "%s/%s" % [dir, f]
    return best

func _on_save_checkpoint_requested(source: SaveContext) -> void:
    save_checkpoint(source)
```

**SaveMigrationRegistry** (`src/core/save_migration_registry.gd`):

```gdscript
## SaveMigrationRegistry — version chain for SaveContext upgrades.
##
## RULES:
##  - Migrations are PURE FUNCTIONS. They MUST operate only on the
##    SaveContext argument. Captured node or object state is FORBIDDEN
##    (captured refs outlive the migration and leak for process lifetime).
##  - Every from_version must reach CURRENT_SCHEMA_VERSION through the chain.
##  - Gaps (e.g. skipping version 2) are disallowed — chain must be complete.
class_name SaveMigrationRegistry
extends RefCounted

## Dictionary[int, Callable(SaveContext) -> SaveContext]
static var _migrations: Dictionary = {
    # Example for future versions:
    # 1: func(ctx: SaveContext) -> SaveContext:
    #     ctx.schema_version = 2
    #     ctx.new_field = default_value
    #     return ctx,
}

static func migrate_to_current(ctx: SaveContext) -> SaveContext:
    var current: int = SaveManager.CURRENT_SCHEMA_VERSION
    while ctx.schema_version < current:
        var step: Callable = _migrations.get(ctx.schema_version, Callable())
        if not step.is_valid():
            GameBus.save_load_failed.emit(
                "load", "no_migration_from_v%d" % ctx.schema_version
            )
            return ctx
        ctx = step.call(ctx) as SaveContext
    return ctx
```

### GameBus Signal Amendments (ADR-0001 addendum)

ADR-0001 gains a new Persistence domain with three signals. One ratifies
the provisional slot `save_checkpoint_requested`; two are new.

| Signal | Payload | Emitter | Subscribers | Status |
|--------|---------|---------|-------------|--------|
| `save_checkpoint_requested` | `(source: SaveContext)` | ScenarioRunner | SaveManager | ratifies provisional slot — shape now locked |
| `save_persisted` | `(chapter_number: int, cp: int)` | SaveManager | UI (Save Slot screen, toast) | new |
| `save_load_failed` | `(op: String, reason: String)` | SaveManager | UI (error toast), ScenarioRunner | new |

Note: `source: SaveContext` is a Resource type. Per ADR-0001 TR-gamebus-001
(payloads with ≥2 fields must be typed Resource classes), this is the
canonical form — SaveContext has 6 @export fields and is an immutable typed
snapshot, guaranteed by `duplicate_deep` inside SaveManager before
subscriber access.

## Schema Stability

### EchoMark Resource Contract (BLOCKING)

`EchoMark` MUST:
- `extends Resource`
- Declare `class_name EchoMark`
- Annotate EVERY persisted field with `@export`

Non-exported fields are silently dropped by ResourceSaver. Any field added to
EchoMark without `@export` will fail to serialize and produce silent data loss
on the next load. This is a non-negotiable schema invariant.

### BattleOutcome Enum Stability (BLOCKING)

`BattleOutcome.Result` enum integer ordering is FROZEN as a persistence
contract. Example current ordering (illustrative, to be locked by Grid Battle
GDD): `WIN = 0, DRAW = 1, LOSS = 2`.

Reordering or inserting a new value changes the integer value of all
subsequent members, which silently corrupts loaded saves. Options when
reordering is required:

1. **Preferred**: Add new enum values ONLY at the end (append-only).
2. **If mid-reorder unavoidable**: Bump schema_version and register a
   migration that rewrites `outcome` integers.
3. **Future schema version**: Store outcome as String name
   (`"WIN"|"DRAW"|"LOSS"`) for format-independence. Documented as a
   deferred improvement.

### Migration Callable Purity (BLOCKING)

Migration Callables in `SaveMigrationRegistry._migrations` MUST be pure
functions that operate ONLY on the `SaveContext` argument. They MUST NOT
capture any node, singleton, or object reference from the enclosing scope.
Captured references are held for the registry's lifetime (= process
lifetime), producing memory leaks and dangling references into freed scenes.

## Atomicity Guarantees

### Platform-Scoped Atomic Rename

`DirAccess.rename_absolute()` atomicity is guaranteed ONLY on the following
paths:

| Platform | Path | Atomicity |
|----------|------|-----------|
| iOS | `user://` → NSApplicationSupportDirectory | ✅ POSIX `rename(2)` |
| Android | `user://` → `/data/data/<package>/files/` | ✅ POSIX `rename(2)` |
| Android SAF | external / scoped storage paths | ❌ NOT guaranteed |
| PC | `user://` → OS per-user app data | ✅ POSIX on macOS/Linux, MoveFileEx on Windows |

**Save root MUST remain `user://`**. No code path may attempt to save to an
SAF-backed external path. If external export (e.g., "copy save to downloads"
user-facing feature) is added later, it MUST be a separate COPY operation
AFTER the atomic save — never as the primary save destination.

### Cache Bypass (BLOCKING)

All save-file loads MUST pass `ResourceLoader.CACHE_MODE_IGNORE`. Cached
loads return stale objects after `save_checkpoint` overwrites the file in the
same session — the in-memory cache is not invalidated by filesystem writes.
A non-bypassing load is a silent correctness bug that only surfaces on second
load of the same slot.

## Alternatives Considered

### Alternative 1: JSON via FileAccess

- **Description**: Serialize SaveContext to JSON, write via FileAccess.
- **Pros**: Human-readable (debug), no Godot import pipeline coupling.
- **Cons**: Manual type coercion (StringName, Array[EchoMark] not JSON-native),
  no schema validation, verbose code.
- **Rejection Reason**: ResourceSaver gives us typed-Resource round-tripping
  for free; schema_version becomes a simple field, not parser-logic.
  Manual JSON handling guarantees human error on the first Array[Resource]
  field added.

### Alternative 2: SQLite via GDExtension

- **Description**: Embed SQLite, store saves as rows.
- **Cons**: GDExtension dependency, query layer for per-key access we don't
  need, overkill for <50 KB payloads.
- **Rejection Reason**: Adds build and platform-port complexity for zero
  mobile benefit. Reconsider if save grows into catalog territory (1000s of
  rows), which is not on roadmap.

### Alternative 3: Single-slot (no slot enumeration)

- **Description**: One save file. Player cannot keep multiple runs.
- **Rejection Reason**: User explicitly chose multi-slot at MVP. Mobile
  players commonly share devices; 1-slot is hostile. Cost of 3 slots over 1
  is trivial (directory layout + UI loop).

### Alternative 4: No schema versioning (start simple, add later)

- **Description**: Ship v1 with no schema_version field, add versioning when
  first breaking change arrives.
- **Rejection Reason**: Adding a schema_version field in v2 means v1 saves
  have no version marker — loader must reverse-infer which is fragile.
  Cost of versioning from day 1 is a single int field + a migration registry
  that is initially empty.

## Consequences

### Positive

- **Type-safe round trip** — Array[EchoMark], StringName, int, String all
  survive unchanged through ResourceSaver.
- **Crash recovery** — atomic rename guarantees the loader never sees a
  half-written file; worst case is losing the most recent save, not the run.
- **Schema evolvability** — migration registry unblocks additive schema
  changes without breaking existing player saves.
- **Multi-slot from MVP** — no retrofit later; Save Slot UI can be built
  against a stable slot-enumeration contract immediately.
- **Signal-driven** — SaveManager is testable in isolation, no direct node
  references from gameplay code.

### Negative

- **EchoMark @export discipline** — adding a field to EchoMark without
  `@export` silently drops it on save. Must be enforced by code review
  (and eventually a lint rule in `/story-done`).
- **Enum-ordering fragility** — any BattleOutcome.Result reorder requires a
  migration function. Documented, but a human-error vector nonetheless.
- **Migration registry discipline** — pure-function constraint is by
  convention, not compiler-enforced. Violators leak memory silently.

### Risks

- **R-1 (HIGH): Live-state torn write** — mitigation: mandatory
  `duplicate_deep` in `save_checkpoint` before ResourceSaver.
- **R-2 (HIGH): Android SAF path used accidentally** — mitigation:
  `SAVE_ROOT` constant pinned to `user://`, no public API accepts an
  arbitrary save root.
- **R-3 (MEDIUM): Migration chain gap** — mitigation: `migrate_to_current`
  emits `save_load_failed` on missing step, does not silently proceed.
  Unit test verifies every version 1..CURRENT has a path to current.
- **R-4 (MEDIUM): Cache staleness** — mitigation: `CACHE_MODE_IGNORE` on
  all save-file loads, enforced by the fact that `SaveManager` is the only
  code path that loads saves.
- **R-5 (LOW): iCloud sync for iOS** — saves are included in iCloud backup
  by default. If the product decides saves should not sync (e.g. device
  ownership changes), set `NSUbiquitousItemIsExcludedFromBackupKey` on the
  save directory. Documented for future decision; default is to allow
  backup.

## Performance Implications

- **CPU**: `duplicate_deep` on a SaveContext is O(|echo_marks_archive|);
  expected 5–50 echoes per save, ~1 ms on mid-range Android. `ResourceSaver.save`
  expected 2–10 ms for <20 KB payload.
- **Memory**: +1 SaveContext snapshot during serialization window
  (≤1 frame), <50 KB.
- **Load Time**: `ResourceLoader.load` on CP-1 at Beat 1 entry: expected
  5–15 ms. Not blocking frame budget if run during scene-load frames.
- **I/O**: 3 CPs × N chapters × 3 slots = bounded. Full MVP save-directory
  size expected <2 MB per slot.

## Migration Plan

1. **Phase 1** (this ADR accepted): Create `src/core/save_context.gd`,
   `src/core/save_manager.gd`, `src/core/save_migration_registry.gd`.
2. **Phase 2**: Add `SaveManager` to project.godot autoload list AFTER
   `GameBus` and `SceneManager` (load order 3).
3. **Phase 3**: ScenarioRunner emits `checkpoint_requested` at Beat 1
   entry (CP-1), post-Beat 7 (CP-2), and next-chapter Beat 1 (CP-3).
4. **Phase 4**: Save Slot UI consumes `SaveManager.list_slots()`.
5. **Phase 5** (post-MVP): first schema change triggers authoring of a
   migration function in `SaveMigrationRegistry._migrations`.

No legacy saves exist to migrate. v1 is the origin schema.

## Validation Criteria

| # | Criterion | Measurable Test |
|---|-----------|-----------------|
| V-1 | Round-trip preserves all SaveContext fields | Unit: fill all fields with distinct values, save, load, assert deep-equal |
| V-2 | Array[EchoMark] survives serialization | Unit: 10 EchoMarks with unique fields, round-trip, assert equality |
| V-3 | Missing @export on EchoMark field fails CI | Lint rule or test that grep-checks every field in echo_mark.gd has @export |
| V-4 | Atomic write: tmp file never survives | Unit: kill mid-save (mock ResourceSaver failure), assert tmp file cleaned |
| V-5 | Crash during save leaves old file intact | Unit: save v1, fail save v2, load returns v1 unchanged |
| V-6 | Schema migration chain reaches CURRENT | Unit: for every version in 1..CURRENT, assert `migrate_to_current` succeeds |
| V-7 | CACHE_MODE_IGNORE enforced | Unit: overwrite file in same session, load returns new content (not cached) |
| V-8 | Slot isolation | Unit: save to slot 1, read slots 2 and 3, assert empty |
| V-9 | list_slots handles corrupt file | Unit: write garbage to ch_01_cp_1.res, list_slots reports corrupt: true, never crashes |
| V-10 | Save path is user:// only | Static grep: no occurrence of "/sdcard", "content://", or SAF APIs in save_manager.gd |
| V-11 | Full save cycle <50 ms on mid-range Android | Perf test: 100 iterations, 95th percentile <50 ms |
| V-12 | load_latest_checkpoint returns newest CP | Unit: write ch_01_cp_1, ch_01_cp_2, assert load returns cp_2 |
| V-13 | ADR-0001 compliance: no per-frame GameBus emits | Static grep: no GameBus.*.emit in `_process` or `_physics_process` of save_manager.gd |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `scenario-progression.md` | SaveContext schema (chapter_id, outcome, branch_key, echo_count, echo_marks_archive, flags_to_set) | Ratified as `SaveContext` Resource with all fields @export-annotated and type-stable |
| `scenario-progression.md` | 3-CP per chapter recovery policy (CP-1 Beat 1 entry, CP-2 post-Beat 7, CP-3 next-chapter entry) | SaveManager `save_checkpoint()` invoked at all three ScenarioRunner emission points; files kept as per-chapter history |
| `scenario-progression.md` | MVP does not support mid-battle save | SaveManager exposes only checkpoint-triggered saves — no continuous snapshotting API |
| `scenario-progression.md` | Echo resets at Beat 9 | Snapshot taken BEFORE Beat 9 reset at CP-3; live state freedom guaranteed by duplicate_deep |

## Registered TR Entries (tr-registry v2, 2026-04-18)

- `TR-SAVE-001`: SaveManager autoload declared at `/root/SaveManager` in
  `project.godot`, load order 3 (after GameBus and SceneManager).
- `TR-SAVE-002`: All SaveContext fields annotated `@export`; EchoMark
  extends Resource with class_name and full @export coverage.
- `TR-SAVE-003`: All save writes go through `save_checkpoint()` which
  calls `duplicate_deep` → `ResourceSaver.save(tmp)` → `rename_absolute`.
- `TR-SAVE-004`: All save loads use
  `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`.
- `TR-SAVE-005`: `BattleOutcome.Result` enum is append-only; reordering
  requires a migration registry entry and schema_version bump.
- `TR-SAVE-006`: Save root is `user://saves`; no code path accepts or
  constructs an SAF / external-storage save path.
- `TR-SAVE-007`: Migration Callables in `SaveMigrationRegistry` are pure
  functions; no captured node/singleton/object state permitted.

## Open Questions

None blocking. Two deferred-decision items:

1. **FLAG_COMPRESS on/off** — to be decided after first realistic save
   payload benchmark. Default is OFF until benchmark shows payloads
   >50 KB uncompressed.
2. **iCloud backup exclusion** — set
   `NSUbiquitousItemIsExcludedFromBackupKey` on `user://saves/`? Default
   is NO (saves backed up). Product decision deferred; documented as a
   toggle point in this ADR so future change is traceable.

## Related

- ADR-0001 (Accepted): GameBus autoload — signal contract for
  `checkpoint_requested` / `save_persisted` / `save_load_failed`.
- ADR-0002 (Accepted): SceneManager — CP-2 timing boundary
  (RETURNING_FROM_BATTLE → IDLE).
- `design/gdd/scenario-progression.md` §Detailed Rules — 3-CP policy,
  SaveContext schema definition.
- `docs/engine-reference/godot/modules/core.md` — ResourceSaver,
  ResourceLoader, DirAccess reference.

## Changelog

- 2026-04-18: Initial draft via `/architecture-decision`. Validated by
  godot-specialist (2 BLOCKING items resolved: EchoMark @export mandate,
  platform-scoped atomicity documentation; 5 RECOMMENDED items
  incorporated: CACHE_MODE_IGNORE mandatory, migration purity,
  BattleOutcome enum stability, DirAccess.get_files_at idiom, iOS backup
  exclusion noted).
- 2026-04-18: `/architecture-review` (re-run) applied F-3 (citation
  corrected to TR-gamebus-001 typed-Resource rule) and C-1 (SceneManager
  removed from `save_checkpoint_requested` emitter list — ScenarioRunner
  is sole emitter; SceneManager remains CP-2 timing boundary only).
  Transitioned Proposed → Accepted after ADR-0002 reached Accepted.
  TR-save-load-001..007 registered in tr-registry v2.
