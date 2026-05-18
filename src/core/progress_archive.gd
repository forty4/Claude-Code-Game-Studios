## ProgressArchive — cross-campaign meta-progression archive.
##
## Persists 영걸전 signature unlocks (5 영웅 cascade) across campaigns and save
## slots. Unlike SaveContext.persistent_branch_flags (which lives inside a
## single campaign's save and resets on a new campaign start), ProgressArchive
## survives save-slot deletion + fresh campaign starts. Stored at
## `user://progress_archive.cfg` (ConfigFile — same namespace as
## user://settings.cfg; outside user://saves/).
##
## SoT distinction:
##   - SaveContext.persistent_branch_flags = active cascade flags in CURRENT
##     campaign (drives ch25 hidden relief, in-battle HUD badge, branch_overrides
##     synthesis).
##   - ProgressArchive.signature_unlocks = ALL-TIME unlock set across every
##     campaign + slot the player has run (drives main_menu badge "✦ N/5
##     누적" + archive popup first-unlock metadata).
##
## Idempotent: re-unlocking a key preserves the first-unlock metadata.
##
## NOTE (G-3): registered as autoload. The autoload name IS the global
## identifier — NO `class_name` declaration here.
extends Node


# ── Constants ─────────────────────────────────────────────────────────────────

## Persisted archive file. Outside user://saves/ so save-slot deletion
## does NOT clear cross-campaign progression.
const _ARCHIVE_PATH: String = "user://progress_archive.cfg"
const _SECTION: String = "signature_unlocks"


# ── State ─────────────────────────────────────────────────────────────────────

## Maps signature_key (String) → { first_chapter_id (String), first_unlocked_unix (int) }.
## Loaded from disk on _ready, write-through on every unlock_signature call.
var _signature_unlocks: Dictionary = {}


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_from_disk()


# ── Public API ────────────────────────────────────────────────────────────────

## Records a first-ever unlock for `key`. Idempotent: a repeat call for an
## already-unlocked key is a no-op (first-unlock metadata preserved). Empty
## key is silently rejected. Writes to disk on every NEW unlock.
##
## `chapter_id` should be the chapter where the cascade event resolved — used
## by the archive popup to show "처음 달성: chXX". An empty string is
## acceptable when the originating chapter is unknown (e.g. save backfill).
func unlock_signature(key: String, chapter_id: String) -> void:
	if key.is_empty():
		return
	if _signature_unlocks.has(key):
		return
	_signature_unlocks[key] = {
		"first_chapter_id": chapter_id,
		"first_unlocked_unix": int(Time.get_unix_time_from_system()),
	}
	_save_to_disk()


## Returns all unlocked signature keys (PackedStringArray for stable order
## semantics + cheap `key in arr` checks at call sites).
func get_unlocked_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: String in _signature_unlocks.keys():
		out.append(key as String)
	return out


## Returns the first-unlock metadata for `key`, or empty Dictionary if `key`
## has never been unlocked. Shape: `{first_chapter_id: String, first_unlocked_unix: int}`.
func get_unlock_metadata(key: String) -> Dictionary:
	if not _signature_unlocks.has(key):
		return {}
	return (_signature_unlocks[key] as Dictionary).duplicate()


## Convenience accessor — total unlocked-signature count for HUD/main_menu badges.
func get_unlocked_count() -> int:
	return _signature_unlocks.size()


# ── Test seam ─────────────────────────────────────────────────────────────────

## 5th-autoload reset_for_tests pattern (G-28). Drops in-memory state AND
## deletes the persisted file so subsequent tests start clean. Idempotent.
func reset_for_tests() -> void:
	_signature_unlocks.clear()
	if FileAccess.file_exists(_ARCHIVE_PATH):
		DirAccess.remove_absolute(_ARCHIVE_PATH)


# ── Private ───────────────────────────────────────────────────────────────────

func _load_from_disk() -> void:
	if not FileAccess.file_exists(_ARCHIVE_PATH):
		return
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(_ARCHIVE_PATH)
	if err != OK:
		push_warning("ProgressArchive._load_from_disk: load failed (err=%d)" % err)
		return
	if not cfg.has_section(_SECTION):
		return
	for key: String in cfg.get_section_keys(_SECTION):
		var raw: Variant = cfg.get_value(_SECTION, key)
		if raw is Dictionary:
			_signature_unlocks[key] = raw


func _save_to_disk() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in _signature_unlocks.keys():
		cfg.set_value(_SECTION, key as String, _signature_unlocks[key])
	var err: Error = cfg.save(_ARCHIVE_PATH)
	if err != OK:
		push_warning("ProgressArchive._save_to_disk: save failed (err=%d)" % err)
