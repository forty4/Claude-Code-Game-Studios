## StoryEvent — autoload Node owning narrative-content variant resolution.
##
## Per design/gdd/story-event.md (rev 1.0 Designed 2026-05-05 sprint-7 S7-06).
## Implements F-SE-1..5: branch-state variant resolution + Beat 8 revelation
## lookup + invalid-path UI carve-out + Beat 1/9 anchor text emission +
## revelation commit telemetry (MVP no-op stub).
##
## SUBSCRIPTIONS (4, all CONNECT_DEFERRED at _ready):
##   - GameBus.chapter_started(id, num)         → F-SE-4 Beat 1 anchor text
##   - GameBus.destiny_branch_chosen(choice)    → F-SE-3 Beat 8 revelation OR invalid-path
##   - GameBus.scenario_complete(result)        → MVP no-op (telemetry breadcrumb)
##   - GameBus.chapter_completed(result)        → F-SE-4 Beat 9 transition text
##
## EMISSIONS (3, NEW per CR-SE-4 — added to game_bus.gd same patch):
##   - GameBus.story_event_resolved(beat_number, variant_key, text_key, cue_tag)
##   - GameBus.story_event_invalid_path_detected(reason, choice_chapter_id)
##   - GameBus.story_event_revelation_committed(chapter_id, branch_key, register)
##
## CLOSED VARIANT-KEY VOCABULARY (CR-SE-13, append-only):
##   canonical_win + rewritten_win + draw_partial + draw_echo_marked +
##   draw_fallback + defeat (6 variants).
##
## ARCHITECTURAL LOCKS (CI lint enforced, sprint-8 S8-09 implementation):
##   - No `class_name` declaration (G-3 autoload rule).
##   - No subscription to `hidden_fate_condition_progressed` (CR-SE-5 — Pillar 2 lock).
##   - No introspection of ScenarioRunner internal state — fields prefixed `_state` /
##     `_echo_counts` / `_current_chapter_index` (CR-SE-19 — Pillar 2 architectural lock
##     6th invocation: story_event_reads_destiny_state and/or scenario_runner_state
##     forbidden_pattern). Public API calls (`get_current_chapter()`) ARE allowed.
##   - D1 BLOCKING invalid-gate FIRST per CR-SE-12: `_on_destiny_branch_chosen` MUST
##     check `choice.is_invalid` BEFORE any other field access. The `DestinyBranchChoice.invalid()`
##     factory sets `outcome = LOSS` as enum default — reading `outcome` before
##     `is_invalid` would silently process a corrupt path as a genuine LOSS.
##
## ADR: ADR-0017 ScenarioRunner (Beat 1/2/3/8/9 trigger source) +
##      ADR-0018 DestinyBranch (DestinyBranchChoice consumer; D1 invalid-gate contract) +
##      ADR-0001 GameBus (signal transport; minor amendment per Evolution Rule #4 pending).
extends Node


# ─── Variant-key namespace constants (CR-SE-13 closed vocabulary) ─────────────

const VARIANT_KEY_CANONICAL_WIN: StringName = &"canonical_win"
const VARIANT_KEY_REWRITTEN_WIN: StringName = &"rewritten_win"
const VARIANT_KEY_DRAW_PARTIAL: StringName = &"draw_partial"
const VARIANT_KEY_DRAW_ECHO_MARKED: StringName = &"draw_echo_marked"
const VARIANT_KEY_DRAW_FALLBACK: StringName = &"draw_fallback"
const VARIANT_KEY_DEFEAT: StringName = &"defeat"

const VARIANT_KEY_NAMESPACE: Array[StringName] = [
	VARIANT_KEY_CANONICAL_WIN,
	VARIANT_KEY_REWRITTEN_WIN,
	VARIANT_KEY_DRAW_PARTIAL,
	VARIANT_KEY_DRAW_ECHO_MARKED,
	VARIANT_KEY_DRAW_FALLBACK,
	VARIANT_KEY_DEFEAT,
]

const BEAT_8_REVELATION_FALLBACK_TEXT_KEY: String = "common.beat8.invalid_path"

# Anchor variant keys (used for Beat 1/9 emissions).
const ANCHOR_CHAPTER: StringName = &"chapter_anchor"
const ANCHOR_TRANSITION: StringName = &"chapter_transition"

# Revelation register tags emitted via story_event_revelation_committed (CR-SE-4).
const REGISTER_SOLEMN: StringName = &"solemn"
const REGISTER_MARKED: StringName = &"marked"  # rewritten_win + draw_echo_marked


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# 4 subscriptions per CR-SE-7 — all CONNECT_DEFERRED per ADR-0001.
	_connect_subscriptions()


func _exit_tree() -> void:
	if GameBus.chapter_started.is_connected(_on_chapter_started):
		GameBus.chapter_started.disconnect(_on_chapter_started)
	if GameBus.destiny_branch_chosen.is_connected(_on_destiny_branch_chosen):
		GameBus.destiny_branch_chosen.disconnect(_on_destiny_branch_chosen)
	if GameBus.scenario_complete.is_connected(_on_scenario_complete):
		GameBus.scenario_complete.disconnect(_on_scenario_complete)
	if GameBus.chapter_completed.is_connected(_on_chapter_completed):
		GameBus.chapter_completed.disconnect(_on_chapter_completed)


# ─── Test seam ────────────────────────────────────────────────────────────────

## G-15 mirror obligation. Re-establishes 4 GameBus subscriptions after any
## prior test bulk-disconnects them (e.g. scenario_runner_signal_contract_test
## test cleanup loop). Called from before_test() per balance_constants.gd
## test isolation discipline.
func reset_for_tests() -> void:
	_connect_subscriptions()


## Idempotent subscription wiring; called from _ready() and reset_for_tests().
func _connect_subscriptions() -> void:
	if not GameBus.chapter_started.is_connected(_on_chapter_started):
		GameBus.chapter_started.connect(_on_chapter_started, CONNECT_DEFERRED)
	if not GameBus.destiny_branch_chosen.is_connected(_on_destiny_branch_chosen):
		GameBus.destiny_branch_chosen.connect(_on_destiny_branch_chosen, CONNECT_DEFERRED)
	if not GameBus.scenario_complete.is_connected(_on_scenario_complete):
		GameBus.scenario_complete.connect(_on_scenario_complete, CONNECT_DEFERRED)
	if not GameBus.chapter_completed.is_connected(_on_chapter_completed):
		GameBus.chapter_completed.connect(_on_chapter_completed, CONNECT_DEFERRED)


# ─── Public API ───────────────────────────────────────────────────────────────

## F-SE-1 — Branch-state variant resolution. Pure function over choice payload
## (+ chapter.echo_threshold via ScenarioRunner public API for DRAW echo-gate).
## Returns &"" when invalid path or unknown outcome — caller routes to invalid-path UI.
##
## CR-SE-12 D1 BLOCKING — caller MUST NOT read any other choice field if this
## returns &"". Inside this function, the `is_invalid` guard runs FIRST.
func resolve_variant_key(choice: DestinyBranchChoice) -> StringName:
	if choice == null or choice.is_invalid:
		return &""

	match choice.outcome:
		BattleOutcome.Result.WIN:
			if choice.is_canonical_history:
				return VARIANT_KEY_CANONICAL_WIN
			return VARIANT_KEY_REWRITTEN_WIN
		BattleOutcome.Result.DRAW:
			if choice.is_draw_fallback:
				return VARIANT_KEY_DRAW_FALLBACK
			# author_draw_branch=true chapter; differentiate by echo state.
			var echo_threshold: int = _current_echo_threshold_or_zero()
			if choice.echo_count >= echo_threshold and echo_threshold > 0:
				return VARIANT_KEY_DRAW_ECHO_MARKED
			return VARIANT_KEY_DRAW_PARTIAL
		BattleOutcome.Result.LOSS:
			return VARIANT_KEY_DEFEAT
		_:
			push_error("StoryEvent: unknown outcome enum value %d" % choice.outcome)
			return &""


# ─── Signal handlers ──────────────────────────────────────────────────────────

## F-SE-4 — Beat 1 chapter anchor text emission.
func _on_chapter_started(chapter_id: String, chapter_number: int) -> void:
	if chapter_id == "" or chapter_number <= 0:
		return  # CR-SE-8 invalid-payload guard

	var chapter: ChapterDefinition = _current_chapter_or_null()
	if chapter == null or chapter.chapter_id != chapter_id:
		# Race during cold-load OR autoload-stack mismatch — defensive skip.
		return

	GameBus.story_event_resolved.emit(
		1,
		ANCHOR_CHAPTER,
		chapter.beat_1_text_key,
		&"",
	)


## F-SE-3 — Beat 8 revelation OR invalid-path UI carve-out.
## CR-SE-12 D1 BLOCKING: is_invalid checked FIRST before any other field access.
func _on_destiny_branch_chosen(choice: DestinyBranchChoice) -> void:
	# D1 BLOCKING — read is_invalid FIRST. DestinyBranchChoice.invalid() factory
	# sets outcome=LOSS as enum default; reading outcome here would silently
	# misclassify a corrupt path as defeat.
	if choice == null or choice.is_invalid:
		var reason: StringName = &""
		var chapter_id_arg: String = ""
		if choice != null:
			reason = choice.invalid_reason
			chapter_id_arg = choice.chapter_id
		GameBus.story_event_invalid_path_detected.emit(reason, chapter_id_arg)
		return

	var resolved: Dictionary = _resolve_beat_8_text_and_cue(choice)
	if resolved.is_empty():
		# F-SE-2 already pushed error; route to invalid-path UI as defensive fallback.
		GameBus.story_event_invalid_path_detected.emit(&"beat_8_revelation_missing", choice.chapter_id)
		return

	GameBus.story_event_resolved.emit(
		8,
		resolved["variant_key"] as StringName,
		resolved["text_key"] as String,
		resolved["cue_tag"] as StringName,
	)
	# F-SE-5 revelation commit telemetry — emit immediately at MVP scope (no
	# dwell-window enforcement here; ScenarioRunner owns the 2.0s gate).
	var register: StringName = REGISTER_SOLEMN
	var vk: StringName = resolved["variant_key"] as StringName
	if vk == VARIANT_KEY_REWRITTEN_WIN or vk == VARIANT_KEY_DRAW_ECHO_MARKED:
		register = REGISTER_MARKED
	GameBus.story_event_revelation_committed.emit(choice.chapter_id, choice.branch_key, register)


## F-SE-5 (MVP scope) — telemetry breadcrumb only. Multi-chapter scenario-end
## per-chapter Beat 9 fires via _on_chapter_completed; this handler is a no-op
## stub at MVP.
func _on_scenario_complete(result: ScenarioResult) -> void:
	if result == null:
		return
	# MVP no-op — sprint-8+ adds scenario-credits-roll trigger.


## F-SE-4 — Beat 9 per-chapter transition text emission.
func _on_chapter_completed(result: ChapterResult) -> void:
	if result == null or result.chapter_id == "":
		return  # CR-SE-8 invalid-payload guard

	var chapter: ChapterDefinition = _current_chapter_or_null()
	if chapter == null:
		return  # Race protection per EC-DS-9-style mitigation.

	GameBus.story_event_resolved.emit(
		9,
		ANCHOR_TRANSITION,
		chapter.beat_9_text_key,
		&"",
	)


# ─── Private helpers ──────────────────────────────────────────────────────────

## F-SE-2 — Beat 8 revelation lookup. Filters chapter.beat_8_revelations for
## entry matching choice.branch_key. Returns {} on (a) is_invalid choice,
## (b) F-SE-1 returns empty, (c) chapter null, (d) no matching revelation row.
func _resolve_beat_8_text_and_cue(choice: DestinyBranchChoice) -> Dictionary:
	# Defense-in-depth: caller already guarded is_invalid, but enforce here too.
	if choice == null or choice.is_invalid:
		return {}

	var variant_key: StringName = resolve_variant_key(choice)
	if variant_key == &"":
		return {}

	var chapter: ChapterDefinition = _current_chapter_or_null()
	if chapter == null:
		push_error("StoryEvent: no active chapter at beat_8 lookup")
		return {}

	for entry: Dictionary in chapter.beat_8_revelations:
		if (entry.get("branch_key", "") as String) == choice.branch_key:
			return {
				"variant_key": variant_key,
				"text_key": (entry.get("text_key", "") as String),
				"cue_tag": StringName(entry.get("cue_tag", "") as String),
			}

	# Authoring drift — no row matched.
	push_error("StoryEvent: chapter %s missing beat_8 revelation for branch_key %s" % [
		chapter.chapter_id, choice.branch_key,
	])
	return {}


## Public-API access to ScenarioRunner.get_current_chapter() — allowed under
## CR-SE-19 Pillar 2 lock (lint targets `_`-prefixed internal state only).
## Returns null when ScenarioRunner unavailable (test mode) or no active scenario.
func _current_chapter_or_null() -> ChapterDefinition:
	var sr: Node = get_node_or_null("/root/ScenarioRunner")
	if sr == null:
		return null
	return sr.get_current_chapter()


## Reads echo_threshold via the public-API chapter ref. Returns 0 when no chapter.
func _current_echo_threshold_or_zero() -> int:
	var chapter: ChapterDefinition = _current_chapter_or_null()
	if chapter == null:
		return 0
	return chapter.echo_threshold
