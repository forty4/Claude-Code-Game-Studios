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
##
## v1 → v2 (2026-05-18, multi-step survival cascade):
##   Added branch_history + persistent_branch_flags. Old (v1) saves load
##   with both empty — cascade plays out from current chapter forward only,
##   no historical retroactive cascade.
@export var schema_version: int = 2

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

## v2 — Multi-step survival cascade per-chapter outcome archive.
## Mirrors ScenarioRunner._chapter_outcomes. Each entry:
##   {chapter_id: String, branch_path_id: String,
##    echo_count_at_completion: int, outcome: int (BattleOutcome.Result enum)}
## Restored to _chapter_outcomes at restore_from_save_context — enables backward
## scan when chapter is resumed mid-campaign + audit of full path taken.
@export var branch_history: Array[Dictionary] = []

## v2 — Multi-step survival cascade active signature flag set.
## Mirrors ScenarioRunner._persistent_branch_flags. Each entry is a branch_path_id
## (signature key) that resolved at BEAT_9 and stays active for the remainder
## of the campaign. Restored to _persistent_branch_flags so cascade survives
## save/load roundtrip.
@export var persistent_branch_flags: PackedStringArray = PackedStringArray()


# ─── S91 Phase B step 8b — Strategy Systems per-hero state snapshots ─────────

## Per-unit inventory snapshot for mid-chapter save/load (strategy-systems.md
## v0.3 §3.4 + AC-SS-2 EC-SS-9). Restored to BattleUnit.inventory at battle
## resume (per-unit, indexed by unit_id). Empty Dictionary = no snapshot
## captured (chapter starting_inventory_by_hero re-applies on fresh load).
##
## Runtime shape: { unit_id_int -> Array[StringName] of length INVENTORY_SLOT_COUNT }.
## Outer Dictionary intentionally untyped at @export — Godot 4.6 does NOT permit
## nested-typed declarations (Dictionary[int, Array[StringName]] parses as G-25
## "Nested typed collections are not supported"). Element-type enforcement
## happens at the writer (BattleScene._capture_battle_state_for_save) and the
## reader (BattleScene._restore_inventory_from_snapshot) — see Phase B follow-up
## step (snapshot population is data-layer-ready in this commit; wiring lives in
## a separate step alongside mid-chapter save trigger).
##
## EC-SS-9 (mid-chapter save round-trip): use one item (slot 0 → empty), save,
## load, assert slot 0 empty + slots 1-2 intact. This field carries the post-
## decrement state across the round-trip.
@export var per_hero_inventory_snapshot: Dictionary = {}

## Per-unit pending_buff snapshot for mid-chapter save/load (strategy-systems.md
## v0.3 §3.6 + EC-SS-3 buff revive lifecycle). Restored to BattleUnit.pending_buff
## at battle resume. Empty Dictionary = no active buffs in any unit (default).
##
## Runtime shape: { unit_id_int -> Dictionary }. Inner Dictionary mirrors
## BattleUnit.pending_buff (typically { &"kind": StringName, &"magnitude": float,
## &"expires_at_turn": int }). Outer Dictionary untyped at @export per G-25.
##
## EC-SS-3 round-trip: a strength_scroll buff fired on round 7 (expires_at_turn=8)
## with caster killed before next attack — the buff stays in pending_buff on
## the dead unit; if save+load happens between death and revive, the buff
## survives the snapshot. Resolution gate at attack time (expires_at_turn vs
## current_round comparison) still clears stale buffs on first read.
@export var per_hero_pending_buff_snapshot: Dictionary = {}
