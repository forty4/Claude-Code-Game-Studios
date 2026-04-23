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
## Returns true on success, false on failure (failure also emits save_load_failed on GameBus).
## STUB — body implemented in story-004.
## TODO story-004: duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS) → ResourceSaver.save(tmp) → rename_absolute
func save_checkpoint(source: SaveContext) -> bool:
	# TODO story-004: implement atomic save pipeline
	return false


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
	var root: String = _effective_save_root()
	DirAccess.make_dir_recursive_absolute(root)
	for i: int in range(1, SLOT_COUNT + 1):
		DirAccess.make_dir_recursive_absolute("%s/slot_%d" % [root, i])


## Returns the canonical file path for a given slot, chapter, and checkpoint index.
## Uses _effective_save_root() so SaveManagerStub can redirect to a temp path.
## Format: <save_root>/slot_{slot}/ch_{MM}_cp_{cp}.res  (MM is zero-padded to 2 digits).
## Example (production): _path_for(2, 3, 1) → "user://saves/slot_2/ch_03_cp_1.res"
func _path_for(slot: int, chapter_number: int, cp: int) -> String:
	return "%s/slot_%d/ch_%02d_cp_%d.res" % [_effective_save_root(), slot, chapter_number, cp]


## Scans the given slot directory and returns the path to the newest checkpoint file,
## or an empty String if no valid checkpoint files are found.
## Newest = highest chapter_number, then highest cp index.
## STUB — body implemented in story-005.
## TODO story-005: use DirAccess.get_files_at (4.6-idiomatic) + sort by ch/cp key
func _find_latest_cp_file(slot: int) -> String:
	# TODO story-005: implement newest-CP file discovery
	return ""

# ── Signal callbacks ──────────────────────────────────────────────────────────

## Handles save_checkpoint_requested from GameBus.
## Delegates to save_checkpoint for the actual persistence pipeline.
## STUB — body delegates to save_checkpoint; guard logic in story-004.
## TODO story-004: add is_instance_valid guard on source before delegating
func _on_save_checkpoint_requested(source: SaveContext) -> void:
	# TODO story-004: implement handler body (guard + save_checkpoint delegation)
	return
