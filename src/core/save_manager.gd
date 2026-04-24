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
## Load order: 3rd autoload, after GameBus and SceneManager
## (see TR-save-load-001, ADR-0003 §Migration Plan Phase 2).
##
## NOTE (G-3): This script is registered as autoload "SaveManager" in
## project.godot. It must NOT declare class_name SaveManager — that
## would cause "Class hides autoload singleton" parse error.
## The autoload name IS the global identifier.
##
## See ADR-0003 §Decision for topology and §Key Interfaces for full API.
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────

## Root directory for all save data. MUST remain user:// — SAF / external-storage
## paths do not guarantee DirAccess.rename_absolute atomicity (ADR-0003 TR-save-load-006).
const SAVE_ROOT: String = "user://saves"

## Number of independent save slots supported from MVP (ADR-0003 §Decision).
const SLOT_COUNT: int = 3

## Current schema version. Bump on every additive or breaking SaveContext change,
## then add a migration function in SaveMigrationRegistry._migrations (ADR-0003 §Migration).
const CURRENT_SCHEMA_VERSION: int = 1

# ── Public variables ──────────────────────────────────────────────────────────

## Read-only active save slot (1..SLOT_COUNT). Changes via set_active_slot() only.
## Direct writes are rejected with push_error; external code must never write directly.
var active_slot: int = 1:
	get:
		return _active_slot
	set(_v):
		push_error("SaveManager.active_slot is read-only; call set_active_slot()")

# ── Private variables ─────────────────────────────────────────────────────────

var _active_slot: int = 1

## Test-only seam set by SaveManagerStub.swap_in(). Production code MUST NOT set
## this. When empty, _effective_save_root() falls back to the SAVE_ROOT constant.
## Setting this before add_child ensures _ready() → _ensure_save_root() creates
## directories at the override path rather than at the production user://saves root.
var _save_root_override: String = ""

## TEST-ONLY — forces _do_resource_saver_save() to return this error code instead of
## calling ResourceSaver.save(). Production code MUST NOT set this.
## Set to a non-OK Error value in tests to simulate ResourceSaver failure (AC-V4).
var _test_force_save_error: Error = OK

## TEST-ONLY — forces _do_rename_absolute() to return this error code instead of
## calling DirAccess.rename_absolute(). Production code MUST NOT set this.
## Set to a non-OK Error value in tests to simulate atomic-rename failure (AC-V5).
var _test_force_rename_error: Error = OK

## TEST-ONLY — forces _do_dir_access_open() to return null instead of calling
## DirAccess.open(). Production code MUST NOT set this.
## Set to true in tests to simulate DirAccess.open() returning null (AC-DIRACCESS-FAIL).
var _test_force_dir_open_null: bool = false

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	## Subscribe to save_checkpoint_requested with CONNECT_DEFERRED per ADR-0001 §7.
	## CONNECT_DEFERRED is mandatory for cross-system subscribes to avoid
	## re-entrancy hazards and physics→idle ordering issues.
	GameBus.save_checkpoint_requested.connect(
		_on_save_checkpoint_requested, CONNECT_DEFERRED
	)
	## Ensure save directory hierarchy exists (idempotent on subsequent calls).
	_ensure_save_root()


func _exit_tree() -> void:
	## Disconnect GameBus subscription guarded by is_connected to avoid
	## double-disconnect errors (e.g. if called during test cleanup or scene reload).
	if GameBus.save_checkpoint_requested.is_connected(_on_save_checkpoint_requested):
		GameBus.save_checkpoint_requested.disconnect(_on_save_checkpoint_requested)

# ── Public methods ────────────────────────────────────────────────────────────

## Sets the active save slot. Slot must be in range [1, SLOT_COUNT].
## All subsequent save and load operations target this slot.
func set_active_slot(slot: int) -> void:
	assert(slot >= 1 and slot <= SLOT_COUNT, "slot must be 1..%d" % SLOT_COUNT)
	_active_slot = slot


## Persists the given SaveContext at the appropriate checkpoint path in the active slot.
## Returns true on success, false on any failure (failure also emits save_load_failed
## on GameBus so callers can observe the result via signals).
##
## Pipeline (ADR-0003 §Key Interfaces, TR-save-load-003):
##   1. duplicate_deep(DEEP_DUPLICATE_ALL) — snapshot decoupled from live state (ADR errata: TD-024)
##   2. Stamp schema_version and saved_at_unix on the snapshot
##   3. Compute final_path and tmp_path via _path_for
##   4. ResourceSaver.save(snapshot, tmp_path) — routed through _do_resource_saver_save seam
##   5. DirAccess.open(_effective_save_root()) — routed through _do_dir_access_open seam
##   6. DirAccess.rename_absolute(tmp, final) — atomic on user://; routed through _do_rename_absolute seam
##   7. Emit GameBus.save_persisted on success
##
## V-4 tmp-cleanup policy (story-004):
##   On resource_saver_error: tmp may have been partially written. Attempt best-effort
##   DirAccess.remove_absolute(tmp_path) before returning false. If the cleanup call
##   itself returns non-OK AND the file still exists, emit push_warning and accept
##   silently — a compensating sweep at story-006 will clear any lingering .tmp files.
##   On atomic_rename_failed: tmp definitely exists (ResourceSaver succeeded). Same
##   best-effort cleanup policy applies.
##   On dir_access_open_failed: tmp definitely exists (ResourceSaver succeeded). Same
##   best-effort cleanup policy applies.
func save_checkpoint(source: SaveContext) -> bool:
	# Deep-duplicate the source so serialization is fully decoupled from live state (R-1).
	# ADR-0003 §Key Interfaces cites `Resource.DUPLICATE_DEEP_ALL_BUT_SCRIPTS`, but that enum
	# value does not exist in the Godot 4.6 DeepDuplicateMode enum (NONE/INTERNAL/ALL only).
	# DEEP_DUPLICATE_ALL is the correct max-depth mode: it duplicates embedded sub-resources
	# (EchoMark instances) including non-local-to-scene references. ADR errata tracked as TD-024.
	var snapshot: SaveContext = source.duplicate_deep(
		Resource.DEEP_DUPLICATE_ALL
	) as SaveContext

	# Steps 2a + 2b — stamp canonical values on the snapshot, never on the source.
	snapshot.schema_version = CURRENT_SCHEMA_VERSION
	snapshot.saved_at_unix = int(Time.get_unix_time_from_system())

	# Steps 3a + 3b — derive paths from the snapshot's chapter/cp values.
	var final_path: String = _path_for(_active_slot, snapshot.chapter_number, snapshot.last_cp)
	# ADR-0003 §Key Interfaces specifies `final_path + ".tmp"` but Godot 4.6's
	# ResourceSaver picks its serializer from the TRAILING extension — `.res.tmp`
	# yields err=15 (ERR_FILE_CANT_WRITE) because `.tmp` isn't a registered format.
	# Use `.tmp.res` so the trailing extension is `.res` (binary saver recognized).
	# ADR errata tracked as TD-026. (G-15)
	var tmp_path: String = final_path.get_basename() + ".tmp.res"

	# Step 4 — write to tmp via seam (enables V-4/V-5 test injection).
	var err: Error = _do_resource_saver_save(snapshot, tmp_path)
	if err != OK:
		# Best-effort cleanup: tmp may be partially written; attempt removal.
		var cleanup_err: Error = DirAccess.remove_absolute(tmp_path)
		if cleanup_err != OK and FileAccess.file_exists(tmp_path):
			push_warning(
				("SaveManager.save_checkpoint: ResourceSaver failed (err=%d) and tmp cleanup"
				+ " also failed (err=%d). Tmp file may linger at '%s'."
				+ " Compensating sweep deferred to story-006.") % [err, cleanup_err, tmp_path]
			)
		GameBus.save_load_failed.emit("save", "resource_saver_error:%d" % err)
		return false

	# Step 5 — open the save root directory via seam (enables DIRACCESS-FAIL test injection).
	var da: DirAccess = _do_dir_access_open(_effective_save_root())
	if da == null:
		# tmp exists (ResourceSaver succeeded); best-effort cleanup before returning.
		var cleanup_err: Error = DirAccess.remove_absolute(tmp_path)
		if cleanup_err != OK and FileAccess.file_exists(tmp_path):
			push_warning(
				("SaveManager.save_checkpoint: DirAccess.open failed and tmp cleanup"
				+ " also failed (err=%d). Tmp file may linger at '%s'."
				+ " Compensating sweep deferred to story-006.") % [cleanup_err, tmp_path]
			)
		GameBus.save_load_failed.emit("save", "dir_access_open_failed")
		return false

	# Step 6 — atomic rename via seam (enables V-5 test injection).
	err = _do_rename_absolute(da, tmp_path, final_path)
	if err != OK:
		# tmp exists; best-effort cleanup to avoid leaving orphan tmp files.
		var cleanup_err: Error = DirAccess.remove_absolute(tmp_path)
		if cleanup_err != OK and FileAccess.file_exists(tmp_path):
			push_warning(
				("SaveManager.save_checkpoint: rename_absolute failed (err=%d) and tmp cleanup"
				+ " also failed (err=%d). Tmp file may linger at '%s'."
				+ " Compensating sweep deferred to story-006.") % [err, cleanup_err, tmp_path]
			)
		GameBus.save_load_failed.emit("save", "atomic_rename_failed:%d" % err)
		return false

	# Step 7 — success path: notify listeners via GameBus.
	GameBus.save_persisted.emit(snapshot.chapter_number, snapshot.last_cp)
	return true


## Loads the newest checkpoint in the active slot.
## Returns the SaveContext Resource after applying any needed schema migrations,
## or null if the slot is empty or the file cannot be loaded.
## STUB — body implemented in story-005.
## TODO story-005: _find_latest_cp_file → ResourceLoader.load(CACHE_MODE_IGNORE) → SaveMigrationRegistry.migrate_to_current
func load_latest_checkpoint() -> SaveContext:
	# TODO story-005: implement load pipeline with cache bypass and migration
	return null


## Enumerates all slots with their newest-CP metadata for the Save Slot UI.
## Returns an Array of length SLOT_COUNT; each Dictionary contains at minimum
## { slot_id: int, empty: bool }. Non-empty slots also include chapter_number,
## last_cp, and saved_at_unix.
## STUB — body implemented in story-005.
## TODO story-005: iterate slots, call _find_latest_cp_file per slot, load metadata
func list_slots() -> Array[Dictionary]:
	# TODO story-005: implement slot enumeration
	return []

# ── Private methods ───────────────────────────────────────────────────────────

## Returns the effective save root directory for this instance.
## Returns _save_root_override when non-empty (test seam injected by SaveManagerStub),
## otherwise falls back to the SAVE_ROOT constant (production path).
## All internal path construction MUST use this helper — never reference SAVE_ROOT directly.
func _effective_save_root() -> String:
	return _save_root_override if not _save_root_override.is_empty() else SAVE_ROOT


## Creates the save root and the three slot subdirectories if they do not exist.
## Uses _effective_save_root() so SaveManagerStub can redirect to a temp path.
## Idempotent — subsequent calls are no-ops on an already-created hierarchy.
## Uses DirAccess.make_dir_recursive_absolute per ADR-0003 §Key Interfaces.
func _ensure_save_root() -> void:
	# .rstrip("/") defends against _save_root_override containing a trailing slash
	# (SaveManagerStub convention); prevents double-slash paths that ResourceSaver
	# rejects with ERR_FILE_CANT_WRITE. DirAccess.make_dir_recursive_absolute
	# tolerates // silently; ResourceSaver does not. Fix consistently here and in
	# _path_for so all path construction shares the same normalization. (G-14)
	var root: String = _effective_save_root().rstrip("/")
	DirAccess.make_dir_recursive_absolute(root)
	for i: int in range(1, SLOT_COUNT + 1):
		DirAccess.make_dir_recursive_absolute("%s/slot_%d" % [root, i])


## Returns the canonical file path for a given slot, chapter, and checkpoint index.
## Uses _effective_save_root() so SaveManagerStub can redirect to a temp path.
## Format: <save_root>/slot_{slot}/ch_{MM}_cp_{cp}.res  (MM is zero-padded to 2 digits).
## Example (production): _path_for(2, 3, 1) → "user://saves/slot_2/ch_03_cp_1.res"
func _path_for(slot: int, chapter_number: int, cp: int) -> String:
	# .rstrip("/") defends against _save_root_override containing a trailing slash
	# (SaveManagerStub convention); prevents double-slash paths that ResourceSaver
	# rejects with ERR_FILE_CANT_WRITE. See G-14 / TD-025. (G-14)
	return "%s/slot_%d/ch_%02d_cp_%d.res" % [_effective_save_root().rstrip("/"), slot, chapter_number, cp]


## Scans the given slot directory and returns the path to the newest checkpoint file,
## or an empty String if no valid checkpoint files are found.
## Newest = highest chapter_number, then highest cp index.
## STUB — body implemented in story-005.
## TODO story-005: use DirAccess.get_files_at (4.6-idiomatic) + sort by ch/cp key
func _find_latest_cp_file(slot: int) -> String:
	# TODO story-005: implement newest-CP file discovery
	return ""


## TEST-ONLY seam — wraps ResourceSaver.save() to allow injection of save errors in tests.
## In production, simply delegates to ResourceSaver.save(). In tests, returns
## _test_force_save_error if it is non-OK (bypasses the real ResourceSaver call entirely).
##
## Option C seam per story-004 §ADR-0003 deltas. Production code MUST NOT set
## _test_force_save_error — that flag is exclusively for V-4 / V-5 test scenarios.
func _do_resource_saver_save(snapshot: Resource, tmp_path: String) -> Error:
	if _test_force_save_error != OK:
		return _test_force_save_error
	return ResourceSaver.save(snapshot, tmp_path)


## TEST-ONLY seam — wraps DirAccess.rename_absolute() to allow injection of rename errors.
## In production, simply delegates to da.rename_absolute(). In tests, returns
## _test_force_rename_error if it is non-OK (bypasses the real rename call entirely).
##
## Option C seam per story-004 §ADR-0003 deltas. Production code MUST NOT set
## _test_force_rename_error — that flag is exclusively for V-5 test scenarios.
func _do_rename_absolute(da: DirAccess, tmp_path: String, final_path: String) -> Error:
	if _test_force_rename_error != OK:
		return _test_force_rename_error
	return da.rename_absolute(tmp_path, final_path)


## TEST-ONLY seam — wraps DirAccess.open() to allow injection of null returns in tests.
## In production, simply delegates to DirAccess.open(path). In tests, returns null
## when _test_force_dir_open_null is true (bypasses the real DirAccess.open call).
##
## Option C seam per story-004 §ADR-0003 deltas (AC-DIRACCESS-FAIL correction).
## Production code MUST NOT set _test_force_dir_open_null.
## Note: the pipeline passes _effective_save_root() — NOT SAVE_ROOT directly —
## so the seam is transparent to SaveManagerStub's temp-root redirect.
func _do_dir_access_open(path: String) -> DirAccess:
	if _test_force_dir_open_null:
		return null
	return DirAccess.open(path)

# ── Signal callbacks ──────────────────────────────────────────────────────────

## Handles save_checkpoint_requested from GameBus.
## Delegates to save_checkpoint for the actual persistence pipeline.
## Return value is intentionally ignored — result is observable via GameBus.save_persisted
## (success) or GameBus.save_load_failed (failure).
func _on_save_checkpoint_requested(source: SaveContext) -> void:
	save_checkpoint(source)
