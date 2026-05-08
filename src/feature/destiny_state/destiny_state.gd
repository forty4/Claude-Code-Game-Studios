## DestinyState — autoload Node owning per-save Destiny State Tracking lifecycle.
##
## Per design/gdd/destiny-state.md (rev 1.0 Designed 2026-05-05 sprint-7 S7-07).
## Implements F-DS-1..5: echo accumulation + echo_count query + flag-effect
## resolution + cross-chapter continuity + SaveContext population.
##
## SUBSCRIPTIONS (5, all CONNECT_DEFERRED at _ready):
##   - GameBus.scenario_beat_retried(mark)         → F-DS-1 echo accumulation
##   - GameBus.destiny_branch_chosen(choice)       → F-DS-3 flag-effect resolution
##   - GameBus.chapter_completed(result)           → F-DS-4 cross-chapter snapshot
##   - GameBus.save_checkpoint_requested(ctx)      → F-DS-5 SaveContext population
##   - GameBus.save_loaded(ctx)                    → CR-SL-19/20 idempotent rehydration
##
## EMISSIONS (2, already declared in game_bus.gd lines 54-55):
##   - GameBus.destiny_state_echo_added(mark)
##   - GameBus.destiny_state_flag_set(flag_key, value)
##
## ARCHITECTURAL LOCKS (CI lint enforced, sprint-8 S8-10 implementation):
##   - No `class_name` declaration (G-3 autoload rule).
##   - No subscription to `hidden_fate_condition_progressed` (CR-DS-6 — Pillar 2 lock).
##   - No introspection of ScenarioRunner internal state — fields prefixed `_state` /
##     `_echo_counts` / `_current_chapter_index` (CR-DS-19 — Pillar 2 architectural lock
##     5th invocation: destiny_state_no_scenario_runner_read forbidden_pattern).
##   - `get_current_chapter()` PUBLIC API call IS allowed for F-DS-1 chapter_id derivation
##     per CR-DS-11 schema-gap workaround; lint pattern targets only `_`-prefixed fields.
##
## ADR: ADR-0003 SaveContext (schema source-of-truth) +
##      ADR-0017 ScenarioRunner (chapter_started + chapter_completed + scenario_beat_retried emit) +
##      ADR-0018 DestinyBranch (destiny_branch_chosen emit + Pillar 2 lock 3rd precedent template).
extends Node


# ─── Internal state (CR-DS-1..2 ownership) ────────────────────────────────────

## Append-only echo archive — F-DS-1 accumulator. Reset semantics live at
## chapter boundary per CR-DS-10 (no deletion; just snapshot to history).
var _full_archive: Array[EchoMark] = []

## Per-chapter echo count workaround for CR-DS-11 EchoMark schema gap.
## Untyped Dictionary per G-1 (GDScript 4.6 enforces typed-dict syntax limits).
## Keyed by chapter_id (String).
var _chapter_echo_counts: Dictionary = {}

## Snapshot of historical chapter echo counts taken at chapter_completed boundary.
## Per F-DS-4: prior_count is archived BEFORE chapter advance for forensic queries.
var _archived_chapter_counts: Dictionary = {}

## Append-only flag set. Per CR-DS-14 PackedStringArray for ResourceSaver
## value-type round-trip safety; deduplicated on insert (FIFO uniqueness).
var _flags_to_set: PackedStringArray = PackedStringArray()


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# 4 subscriptions per CR-DS-7 (3) + F-DS-4 (chapter_completed for cross-chapter snapshot).
	# All CONNECT_DEFERRED per ADR-0001 §Implementation Guidelines.
	_connect_subscriptions()


func _exit_tree() -> void:
	if GameBus.scenario_beat_retried.is_connected(_on_scenario_beat_retried):
		GameBus.scenario_beat_retried.disconnect(_on_scenario_beat_retried)
	if GameBus.destiny_branch_chosen.is_connected(_on_destiny_branch_chosen):
		GameBus.destiny_branch_chosen.disconnect(_on_destiny_branch_chosen)
	if GameBus.chapter_completed.is_connected(_on_chapter_completed):
		GameBus.chapter_completed.disconnect(_on_chapter_completed)
	if GameBus.save_checkpoint_requested.is_connected(_on_save_checkpoint_requested):
		GameBus.save_checkpoint_requested.disconnect(_on_save_checkpoint_requested)
	if GameBus.save_loaded.is_connected(_on_save_loaded):
		GameBus.save_loaded.disconnect(_on_save_loaded)


# ─── Public API (CR-DS-4 read-only consumer surface) ──────────────────────────

## F-DS-2 echo_count query. Returns 0 for unknown chapter_id.
## Consumed by DestinyBranchJudge for F-SP-2 echo-gate predicate.
func get_echo_count(chapter_id: String) -> int:
	return int(_chapter_echo_counts.get(chapter_id, 0))


## F-DS-2 archive query. Returns deep-duplicated snapshot per CR-DS-4.
func get_full_archive() -> Array[EchoMark]:
	var copy: Array[EchoMark] = []
	for mark in _full_archive:
		copy.append(mark.duplicate(true) as EchoMark)
	return copy


## CR-DS-4 read-only flags query. Returns deep-duplicated snapshot.
func get_flags_to_set() -> PackedStringArray:
	return PackedStringArray(_flags_to_set)


## Test-seam reset (canonical pattern per balance_constants.gd test isolation
## discipline). Tests MUST call this in before_test() to prevent state bleed.
##
## Also re-establishes the 4 GameBus subscriptions: scenario_runner_signal_contract_test.gd
## bulk-disconnects all subscribers per its post-conditions, severing the autoload
## handler chain. Calling _connect_subscriptions() (idempotent via is_connected guard)
## restores them so this test suite operates on a live signal pipeline.
func reset_for_tests() -> void:
	_full_archive.clear()
	_chapter_echo_counts.clear()
	_archived_chapter_counts.clear()
	_flags_to_set = PackedStringArray()
	_connect_subscriptions()


## Idempotent subscription wiring; called from _ready() and reset_for_tests().
func _connect_subscriptions() -> void:
	if not GameBus.scenario_beat_retried.is_connected(_on_scenario_beat_retried):
		GameBus.scenario_beat_retried.connect(_on_scenario_beat_retried, CONNECT_DEFERRED)
	if not GameBus.destiny_branch_chosen.is_connected(_on_destiny_branch_chosen):
		GameBus.destiny_branch_chosen.connect(_on_destiny_branch_chosen, CONNECT_DEFERRED)
	if not GameBus.chapter_completed.is_connected(_on_chapter_completed):
		GameBus.chapter_completed.connect(_on_chapter_completed, CONNECT_DEFERRED)
	if not GameBus.save_checkpoint_requested.is_connected(_on_save_checkpoint_requested):
		GameBus.save_checkpoint_requested.connect(_on_save_checkpoint_requested, CONNECT_DEFERRED)
	if not GameBus.save_loaded.is_connected(_on_save_loaded):
		GameBus.save_loaded.connect(_on_save_loaded, CONNECT_DEFERRED)


# ─── Signal handlers (F-DS-1, F-DS-3, F-DS-4, F-DS-5) ─────────────────────────

## F-DS-1 — EchoMark accumulation. Per CR-DS-1 sole-owner of archive lifecycle.
func _on_scenario_beat_retried(mark: EchoMark) -> void:
	# CR-DS-8 invalid-payload guard.
	if mark == null or mark.beat_index <= 0 or mark.outcome == &"":
		return

	# CR-DS-12 hard cap with FIFO eviction.
	var hard_cap: int = int(BalanceConstants.get_const("DESTINY_STATE_ECHO_ARCHIVE_HARD_CAP"))
	if hard_cap > 0 and _full_archive.size() >= hard_cap:
		push_warning("DestinyState: echo archive at hard cap %d; evicting oldest" % hard_cap)
		_full_archive.pop_front()

	# CR-DS-11 chapter_id derivation via PUBLIC ScenarioRunner API
	# (allowed per CR-DS-19 lint targets `_`-prefixed internal state only).
	var chapter_id: String = _current_chapter_id_or_empty()

	_full_archive.append(mark)
	if not chapter_id.is_empty():
		_chapter_echo_counts[chapter_id] = int(_chapter_echo_counts.get(chapter_id, 0)) + 1
	GameBus.destiny_state_echo_added.emit(mark)


## F-DS-3 — flag-effect resolution. Per CR-DS-2 sole-owner of flags lifecycle.
func _on_destiny_branch_chosen(choice: DestinyBranchChoice) -> void:
	# CR-DS-8 + CR-DB-10 invalid-payload guard (D1 BLOCKING for #10/#16/#17 VS).
	if choice == null or choice.is_invalid:
		return

	# CR-DS-15 sentinel flags (always-on, MVP scope).
	if not choice.is_canonical_history:
		_add_flag("divergence_recorded__%s__%s" % [choice.chapter_id, choice.branch_key])
	if choice.is_draw_fallback:
		_add_flag("draw_fallback__%s" % choice.chapter_id)

	# Per-branch authored effects (sprint-8+ scope; MVP no-op per CR-DS-13).
	# Future: read flag_effects: Dictionary[String, PackedStringArray] from
	# ChapterDefinition.branch_table[branch_key] entry.


## F-DS-4 — cross-chapter continuity snapshot. Per CR-DS-10 archive grows monotonically;
## prior chapter's count is archived to historical Dictionary, not deleted.
func _on_chapter_completed(result: ChapterResult) -> void:
	if result == null or result.chapter_id.is_empty():
		return
	var prior_chapter_id: String = result.chapter_id
	var prior_count: int = int(_chapter_echo_counts.get(prior_chapter_id, 0))
	if prior_count > 0:
		_archived_chapter_counts[prior_chapter_id] = prior_count
	# NOTE: _chapter_echo_counts[prior_chapter_id] STAYS — historical query target.
	# New chapter's get_echo_count returns 0 by default (Dictionary.get fallback).


## F-DS-5 — SaveContext population. Per CR-DS-3 + CR-DS-16 SaveManager owns I/O;
## DestinyState writes its 3 owned fields and releases.
func _on_save_checkpoint_requested(ctx: SaveContext) -> void:
	# CR-DS-8 + EC-DS-8 invalid-payload guard.
	if ctx == null or ctx.chapter_id == &"":
		push_warning("DestinyState: save_checkpoint_requested with empty chapter_id; skipping populate")
		return
	var chapter_id_string: String = String(ctx.chapter_id)
	ctx.echo_count = int(_chapter_echo_counts.get(chapter_id_string, 0))
	# CR-DS-16 fresh snapshot per checkpoint (no shared mutable references).
	var archive_copy: Array[EchoMark] = []
	for mark in _full_archive:
		archive_copy.append(mark.duplicate(true) as EchoMark)
	ctx.echo_marks_archive = archive_copy
	ctx.flags_to_set = PackedStringArray(_flags_to_set)


## CR-SL-19/20 — idempotent rehydration on save_loaded.
## Re-running with the same ctx produces identical internal state (CR-SL-20).
## Per user-approved Option A: maps ctx.echo_count to _chapter_echo_counts[ctx.chapter_id].
## CR-SL-22 never-crash invariant — null payload is a no-op (failure path emits
## save_load_failed instead of save_loaded; this is defense-in-depth).
func _on_save_loaded(ctx: SaveContext) -> void:
	if ctx == null:
		return
	# Idempotent reset before hydrate — re-loading same ctx twice yields same state.
	# _archived_chapter_counts is also cleared: pre-load runtime accumulation
	# (from prior chapter_completed events in this session) must not bleed into
	# the loaded timeline; F-DS-4 archive will repopulate as chapters complete
	# in the loaded session.
	_full_archive.clear()
	_chapter_echo_counts.clear()
	_archived_chapter_counts.clear()
	_flags_to_set = PackedStringArray()
	# CR-DS-16 fresh deep-copy policy mirror — no shared references with caller's ctx.
	for mark: EchoMark in ctx.echo_marks_archive:
		if mark != null:
			_full_archive.append(mark.duplicate(true) as EchoMark)
	# Map ctx.echo_count to per-chapter dict under ctx.chapter_id key (Option A).
	# echo_count == 0 case intentionally skips dict write — get_echo_count()
	# returns 0 via Dictionary.get default fallback, so absence is semantically
	# equivalent to {chapter_id: 0}. Asymmetric with the populator (which writes
	# 0 explicitly via int() coercion); the asymmetry is benign per CR-SL-19/20.
	var chapter_id_string: String = String(ctx.chapter_id)
	if not chapter_id_string.is_empty() and ctx.echo_count > 0:
		_chapter_echo_counts[chapter_id_string] = ctx.echo_count
	# Hydrate flags (PackedStringArray copy; not shared reference).
	_flags_to_set = PackedStringArray(ctx.flags_to_set)


# ─── Private helpers ──────────────────────────────────────────────────────────

## CR-DS-14 dedup-on-insert (FIFO uniqueness). Emits destiny_state_flag_set
## ONLY on actual append (idempotent on duplicate).
func _add_flag(flag: String) -> void:
	if _flags_to_set.has(flag):
		return
	_flags_to_set.append(flag)
	GameBus.destiny_state_flag_set.emit(flag, true)


## Returns current chapter_id via ScenarioRunner PUBLIC API or empty string
## when ScenarioRunner is in pre-load state (race protection per EC-DS-9).
## Allowed under CR-DS-19 Pillar 2 lock — public API call, not `_`-prefixed
## internal state read.
func _current_chapter_id_or_empty() -> String:
	# get_node_or_null guards test-mode where autoload stack is partial.
	var sr: Node = get_node_or_null("/root/ScenarioRunner")
	if sr == null:
		return ""
	var chapter_def: ChapterDefinition = sr.get_current_chapter()
	if chapter_def == null:
		return ""
	return String(chapter_def.chapter_id)
