## SaveContext — the single typed payload persisted per checkpoint.
##
## Ratified by ADR-0003. Schema versioning is MANDATORY. Every persisted
## field MUST be annotated @export. Non-exported fields are SILENTLY DROPPED
## on serialization by ResourceSaver.
##
## See ADR-0003 §Schema Stability and §Migration for the versioning contract.
##
## This file replaces the save-manager story-002 PROVISIONAL stub. The path
## src/core/payloads/save_context.gd is the historically-pinned location (see
## gamebus story-002 coordination note); do not move or rename.
class_name SaveContext
extends Resource

## Schema version. Bump on every additive or breaking change.
## Loader consults SaveMigrationRegistry to upgrade old versions.
@export var schema_version: int = 1

## Slot this save belongs to (1–3). Informational; authoritative slot
## identity is the directory path on disk.
@export var slot_id: int = 1

## Chapter identifier (StringName for fast dictionary key hashing; e.g. &"ch03").
@export var chapter_id: StringName = &""

## 1-indexed chapter number. Used for save-filename encoding (ch_MM_cp_N.res).
@export var chapter_number: int = 1

## Last checkpoint reached within this chapter. Valid range: 1, 2, or 3.
## See ADR-0003 §Decision §Requirements 3-CP policy.
@export var last_cp: int = 1

## BattleOutcome.Result enum value. Enum ORDERING IS FROZEN — any reorder
## requires a migration function.
@export var outcome: int = 0

## Destiny-branch selection key for this chapter (StringName for fast compare).
## Populated by ScenarioRunner's Beat-3 branch-locked handler.
@export var branch_key: StringName = &""

## Cumulative EchoMark count across all retry cycles in this chapter.
## Reset at Beat 9 of next chapter — see scenario-progression GDD.
@export var echo_count: int = 0

## EchoMark MUST extend Resource, declare class_name EchoMark, and annotate
## every persisted field with @export.
@export var echo_marks_archive: Array[EchoMark] = []

## Narrative flags queued for scenario-wide state application on next load.
## PackedStringArray for value-type round-trip safety through ResourceSaver.
@export var flags_to_set: PackedStringArray = PackedStringArray()

## Wall-clock time at save (unix seconds). Stamped by SaveManager.save_checkpoint
## at serialization time; source-provided values are overwritten.
@export var saved_at_unix: int = 0

## Cumulative play-time within this run (seconds). Maintained by ScenarioRunner
## across beat transitions; persisted here for Save Slot UI display.
@export var play_time_seconds: int = 0
