## ScenarioRunner — autoload Node owning the 13-state per-scenario state machine.
##
## Sole emitter of 7 cross-scene signals (5 confirmed + 2 ratified delta #12):
##   chapter_started / battle_prepare_requested / battle_launch_requested /
##   chapter_completed / scenario_complete / scenario_beat_retried /
##   save_checkpoint_requested. Plus scenario_fault on validation failure.
##
## Subscribes to GameBus.battle_outcome_resolved with CONNECT_DEFERRED per ADR-0001
## cross-scene routing rule. Lifecycle owned by SceneTree (autoload); persists
## across Overworld <-> BattleScene transitions per ADR-0002.
##
## ARCHITECTURAL LOCKS (CI lint enforced):
##   - No `class_name` declaration (G-3 autoload rule).
##   - No `_process` body (event-driven only; AC-SP-25).
##   - No `_state =` direct assignment outside `_transition_to()` (TR-005 + AC-SP-13).
##   - No `chapter.branch_table` runtime mutation (TR-014 + CR-15 #4).
##   - No `SaveContext.new()` outside `_make_save_context()` helper (TR-011).
##   - No `call_deferred` between BEAT_6 and BEAT_7 (TR-008 Pillar 2 lock 2nd precedent).
##   - No assignment to `BattleOutcome.result` (TR-014 CR-3 invariant).
##
## ADR: ADR-0017 (Accepted 2026-05-04 via /architecture-review delta #12).
## TR: TR-scenario-progression-004..015.
extends Node


# ─── Enum ─────────────────────────────────────────────────────────────────────

## 13-state scenario machine. Single backward edge: BEAT_6_RESULT -> BEAT_4_PREP (retry).
## Forward-only invariant for all other transitions per AC-SP-13.
enum State {
	LOADING,
	CHAPTER_START,
	BEAT_1_ANCHOR,
	BEAT_2_ECHO,
	BEAT_3_BRIEF,
	BEAT_4_PREP,
	BATTLE_LOADING,
	BEAT_5_BATTLE,
	BEAT_6_RESULT,
	BEAT_7_JUDGMENT,
	BEAT_8_REVEAL,
	BEAT_9_TRANSITION,
	SCENARIO_END,
}


## Save checkpoint kind for `_make_save_context(cp_kind)` helper.
## CP-1: BEAT_1_ANCHOR entry. CP-2: BEAT_7_JUDGMENT entry post-seal. CP-3: BEAT_9_TRANSITION entry.
enum SaveCheckpoint { CP_1, CP_2, CP_3 }


# ─── Internal state ───────────────────────────────────────────────────────────

var _state: State = State.LOADING
var _state_entered_at_msec: int = 0

var _scenario_id: String = ""
var _chapters: Array[ChapterDefinition] = []
var _chapter_index: int = 0

var _last_battle_outcome: BattleOutcome = null
var _last_branch_choice: DestinyBranchChoice = null

# Per-chapter scenario state (resets at BEAT_9_TRANSITION).
var _echo_count: int = 0
var _first_attempt_resolved: bool = false
var _echo_marks: Array[EchoMark] = []

# Per-scenario archive (accumulates across chapters; emitted in ScenarioResult).
var _chapter_outcomes: Array[Dictionary] = []
var _scenario_path_segments: PackedStringArray = PackedStringArray()
var _canonical_delta: int = 0
var _total_echo: int = 0

# Test-seam: when true, _ready() does NOT auto-load default scenario.
# Test fixtures call load_scenario(json_path) directly.
var _test_mode: bool = false


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Subscribe to battle_outcome_resolved per ADR-0001 cross-scene routing.
	# CONNECT_DEFERRED so emission does not synchronously re-enter our handler.
	if not GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
		GameBus.battle_outcome_resolved.connect(
			_on_battle_outcome_resolved, CONNECT_DEFERRED
		)
	_state_entered_at_msec = Time.get_ticks_msec()
	# Tests + standalone-launch cases drive scenario load explicitly via load_scenario().
	# In production, BattleScene / SceneManager would trigger load on first scenario start.


func _exit_tree() -> void:
	if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
		GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome_resolved)


## Test seam — restores autoload to clean LOADING state with empty chapters.
## Mirrors the reset_for_tests pattern established at BalanceConstants + DestinyState
## + StoryEvent. Called from before_test() / after_test() hooks to prevent
## cross-test state bleed when integration tests share the production /root/ScenarioRunner.
func reset_for_tests() -> void:
	_state = State.LOADING
	_state_entered_at_msec = Time.get_ticks_msec()
	_scenario_id = ""
	_chapters.clear()
	_chapter_index = 0
	_last_battle_outcome = null
	_last_branch_choice = null
	_echo_count = 0
	_first_attempt_resolved = false
	_echo_marks.clear()
	_chapter_outcomes.clear()
	_scenario_path_segments = PackedStringArray()
	_canonical_delta = 0
	_total_echo = 0
	_test_mode = false


# ─── Public API (per ADR-0017 §Key Interfaces) ────────────────────────────────

## Returns the active BattlePayload for the current chapter. Called by
## BattleScene._ready() per ADR-0016 Migration Plan §1 + ADR-0017 §BattleConfig.
## Returns an empty BattlePayload if state is LOADING / SCENARIO_END / no chapter.
func get_active_battle_config() -> BattlePayload:
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter == null:
		return BattlePayload.new()
	return _build_battle_payload(chapter)


## Returns the current ChapterDefinition (read-only; do NOT mutate). null when
## state is LOADING (pre-load) or SCENARIO_END or _chapters is empty.
func get_current_chapter() -> ChapterDefinition:
	if _state == State.LOADING and _chapters.is_empty():
		return null
	if _state == State.SCENARIO_END:
		return null
	if _chapter_index < 0 or _chapter_index >= _chapters.size():
		return null
	return _chapters[_chapter_index]


## Returns the 0-based current chapter index. Returns -1 when no scenario loaded.
func get_current_chapter_index() -> int:
	if _chapters.is_empty():
		return -1
	return _chapter_index


## Returns the per-chapter echo_count. Reset to 0 at BEAT_9_TRANSITION.
func get_current_echo_count() -> int:
	return _echo_count


## Returns the current state. Tests + lints query this for diagnostics.
func get_state() -> State:
	return _state


## Returns the DestinyBranchChoice resolved at the most recent BEAT_7_JUDGMENT,
## or null if no judgment has run this chapter (i.e. before the first BEAT_7, or
## after a BEAT_9 per-chapter reset). Read-only — consumers MUST NOT mutate the
## returned Resource (CR-3 outcome invariant). Used by BattleScene to look up the
## Beat 8 revelation row for the chosen branch when presenting post-battle story.
func get_last_branch_choice() -> DestinyBranchChoice:
	return _last_branch_choice


## Restores the runner to the start of the chapter described by `ctx` (MVP-level
## resume — re-plays the saved chapter from BEAT_1_ANCHOR rather than restoring
## exact mid-chapter state). Returns false if ctx is null, has an empty
## chapter_id, or refers to a chapter not present in the scenario JSON.
##
## Hardcoded scenario path for now (MVP has a single scenario, mvp_shu.json);
## a future ctx.scenario_id field would let this generalize.
##
## Implementation note: load_scenario already lands at chapter 0 BEAT_1_ANCHOR;
## for chapters 1+ we just bump `_chapter_index`, reset per-chapter state, and
## re-emit `chapter_started` so subscribers (StoryEvent, DestinyState) cache
## the right chapter. The state machine state stays at BEAT_1_ANCHOR — only
## which chapter that "BEAT_1" refers to changes. No `_state =` write outside
## the canonical mutators (lint discipline preserved).
func restore_from_save_context(ctx: SaveContext) -> bool:
	if ctx == null:
		return false
	if String(ctx.chapter_id).is_empty():
		return false
	if not load_scenario("res://assets/data/scenarios/mvp_shu.json"):
		return false
	var target_idx: int = -1
	for i: int in _chapters.size():
		if _chapters[i].chapter_id == String(ctx.chapter_id):
			target_idx = i
			break
	if target_idx == -1:
		push_warning("ScenarioRunner.restore: chapter_id '%s' not in scenario" % String(ctx.chapter_id))
		return false
	if target_idx == 0:
		return true  # already at chapter 0 BEAT_1_ANCHOR after load_scenario
	_chapter_index = target_idx
	_reset_per_chapter_state()
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter != null:
		GameBus.chapter_started.emit(chapter.chapter_id, chapter.chapter_number)
	return true


# ─── Scenario load + validation (LOADING state entry) ─────────────────────────

## Loads a scenario JSON file and transitions LOADING -> CHAPTER_START on success.
## Emits scenario_fault on parse / validation failure; remains in LOADING.
##
## [param json_path] res:// path to scenarios JSON, e.g. assets/data/scenarios/mvp_shu.json
## [return] true on success.
func load_scenario(json_path: String) -> bool:
	_state = State.LOADING
	_state_entered_at_msec = Time.get_ticks_msec()
	var raw: String = FileAccess.get_file_as_string(json_path)
	if raw.is_empty():
		_emit_scenario_fault("", "json_file_missing", {"path": json_path})
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		_emit_scenario_fault("", "json_parse_failed", {"path": json_path})
		return false
	var data: Dictionary = parsed as Dictionary
	# Top-level: scenario_id String + chapters Array.
	if not (data.has("scenario_id") and data["scenario_id"] is String):
		_emit_scenario_fault("", "missing_scenario_id", {})
		return false
	if not (data.has("chapters") and data["chapters"] is Array):
		_emit_scenario_fault(data.get("scenario_id", "") as String, "missing_chapters", {})
		return false
	var sid: String = data["scenario_id"] as String
	var chapter_records: Array = data["chapters"] as Array
	# Per-chapter validation pipeline (FATAL on failure per EC-SP-8).
	var chapters: Array[ChapterDefinition] = []
	for record_var: Variant in chapter_records:
		if not (record_var is Dictionary):
			_emit_scenario_fault(sid, "chapter_not_object", {"index": chapters.size()})
			return false
		var record: Dictionary = record_var as Dictionary
		var validation_error: String = _validate_chapter_record(record)
		if not validation_error.is_empty():
			_emit_scenario_fault(sid, validation_error, record)
			return false
		var chapter: ChapterDefinition = _hydrate_chapter(record)
		chapters.append(chapter)
	_scenario_id = sid
	_chapters = chapters
	_chapter_index = 0
	_reset_per_chapter_state()
	_chapter_outcomes.clear()
	_scenario_path_segments = PackedStringArray()
	_canonical_delta = 0
	_total_echo = 0
	# Synchronous transition LOADING -> CHAPTER_START (Pillar 2 seal-discipline mirror).
	_transition_to(State.CHAPTER_START)
	return true


## Per-chapter validation (FATAL on any failure per EC-SP-8). Returns "" on success
## or a fault-id String on failure (matches scenario-progression.md §EC-SP-8 vocab).
func _validate_chapter_record(record: Dictionary) -> String:
	if not (record.has("chapter_id") and record["chapter_id"] is String):
		return "missing_chapter_id"
	var cid: String = record["chapter_id"] as String
	# chapter_id regex ^[a-z][a-z0-9_]*$
	var re_id: RegEx = RegEx.new()
	re_id.compile("^[a-z][a-z0-9_]*$")
	if re_id.search(cid) == null:
		return "chapter_id_invalid_format"
	if not record.has("branch_table") or not (record["branch_table"] is Dictionary):
		return "missing_branch_table"
	var branch_table: Dictionary = record["branch_table"] as Dictionary
	# branch_path_id regex ^[A-Za-z0-9_]+$ per F-SP-4 delimiter constraint.
	var re_branch: RegEx = RegEx.new()
	re_branch.compile("^[A-Za-z0-9_]+$")
	for v in branch_table.values():
		if not (v is String):
			return "branch_table_value_not_string"
		if re_branch.search(v as String) == null:
			return "branch_path_id_invalid_format"
	# author_draw_branch == true IMPLIES at least one branch_key starts with "DRAW_".
	var author_draw: bool = (record.get("author_draw_branch", false) as bool)
	if author_draw:
		var has_draw: bool = false
		for k in branch_table.keys():
			if (k as String).begins_with("DRAW_"):
				has_draw = true
				break
		if not has_draw:
			return "author_draw_branch_missing_draw_entry"
	# echo_threshold: chapter 1 may have 0; otherwise must be >= 1.
	var chapter_number: int = (record.get("chapter_number", 0) as int)
	var echo_threshold: int = (record.get("echo_threshold", 0) as int)
	if chapter_number != 1 and echo_threshold < 1:
		return "echo_threshold_below_one_for_non_ch1"
	# canonical_branch_key in branch_table.values().
	var canonical: String = (record.get("canonical_branch_key", "") as String)
	if canonical.is_empty():
		return "missing_canonical_branch_key"
	if not branch_table.values().has(canonical):
		return "canonical_branch_key_not_in_table"
	# beat_8_revelations cross-reference.
	var revelations: Array = (record.get("beat_8_revelations", []) as Array)
	for rev in revelations:
		if not (rev is Dictionary):
			return "beat_8_revelation_not_object"
		var rkey: String = ((rev as Dictionary).get("branch_key", "") as String)
		if not branch_table.values().has(rkey):
			return "beat_8_revelation_branch_key_not_in_table"
	return ""


## Hydrates a ChapterDefinition from a validated JSON record.
func _hydrate_chapter(record: Dictionary) -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = record.get("chapter_id", "") as String
	c.chapter_number = record.get("chapter_number", 0) as int
	c.map_id = record.get("map_id", "") as String
	c.author_draw_branch = record.get("author_draw_branch", false) as bool
	c.echo_threshold = record.get("echo_threshold", 0) as int
	c.branch_table = (record.get("branch_table", {}) as Dictionary).duplicate(true)
	c.canonical_branch_key = record.get("canonical_branch_key", "") as String
	c.beat_1_text_key = record.get("beat_1_text_key", "") as String
	c.beat_2_fragment = (record.get("beat_2_fragment", {}) as Dictionary).duplicate(true)
	c.beat_3_text_key = record.get("beat_3_text_key", "") as String
	var revs: Array[Dictionary] = []
	for r_var: Variant in (record.get("beat_8_revelations", []) as Array):
		revs.append((r_var as Dictionary).duplicate(true))
	c.beat_8_revelations = revs
	c.beat_9_text_key = record.get("beat_9_text_key", "") as String
	# Battle config
	var pids: Array = record.get("player_unit_ids", []) as Array
	var p_arr: PackedInt64Array = PackedInt64Array()
	for x in pids:
		p_arr.append(int(x))
	c.player_unit_ids = p_arr
	c.player_commander_id = record.get("player_commander_id", -1) as int
	# player_hero_ids — JSON has String keys (unit_id-as-text → hero_id-as-string);
	# normalize to {int → String} so consumers can index by unit_id directly.
	var hero_raw: Dictionary = (record.get("player_hero_ids", {}) as Dictionary)
	var hero_map: Dictionary = {}
	for k in hero_raw.keys():
		hero_map[int(k as String)] = hero_raw[k] as String
	c.player_hero_ids = hero_map
	var eids: Array = record.get("enemy_unit_ids", []) as Array
	var e_arr: PackedInt64Array = PackedInt64Array()
	for x in eids:
		e_arr.append(int(x))
	c.enemy_unit_ids = e_arr
	# deployment_positions_default — JSON has Array[int,int] values, convert to Vector2i.
	var dep_raw: Dictionary = (record.get("deployment_positions_default", {}) as Dictionary)
	var dep: Dictionary = {}
	for k in dep_raw.keys():
		var v: Variant = dep_raw[k]
		if v is Array and (v as Array).size() >= 2:
			var arr: Array = v as Array
			dep[int(k as String)] = Vector2i(int(arr[0]), int(arr[1]))
	c.deployment_positions_default = dep
	# enemy_roster (ADR-0019 hook)
	var roster: Array[Dictionary] = []
	for r_var: Variant in (record.get("enemy_roster", []) as Array):
		roster.append((r_var as Dictionary).duplicate(true))
	c.enemy_roster = roster
	# chokepoints (S7-05 chapter-1 substrate; JSON Array[Array[int,int]] -> Array[Vector2i])
	var chokes: Array[Vector2i] = []
	for cp_var: Variant in (record.get("chokepoints", []) as Array):
		if cp_var is Array and (cp_var as Array).size() >= 2:
			var cp_arr: Array = cp_var as Array
			chokes.append(Vector2i(int(cp_arr[0]), int(cp_arr[1])))
	c.chokepoints = chokes
	# branch_overrides (deep-copied; per-prior-branch deployment overrides applied
	# in _build_battle_payload when a previous chapter's branch_path_id matches).
	c.branch_overrides = (record.get("branch_overrides", {}) as Dictionary).duplicate(true)
	# enemy_atk_mult — sentinel -1.0 when absent so BattleScene falls back to
	# BalanceConstants global. Float cast handles JSON int (1) or float (0.85).
	if record.has("enemy_atk_mult"):
		c.enemy_atk_mult = float(record.get("enemy_atk_mult", -1.0))
	# Session-29 — victory_conditions hydration (S28 architecture).
	# Optional; absent JSON field leaves c.victory_conditions = null, which the
	# controller dispatcher interprets as ANNIHILATION default per S28 design.
	# Session-30 expanded for ESCORT type (target_unit_ids load-bearing).
	# Session-31 expanded for REACH_TILE type (target_tile coord field).
	if record.has("victory_conditions") and record["victory_conditions"] is Dictionary:
		var vc_data: Dictionary = record["victory_conditions"] as Dictionary
		var vc: VictoryConditions = VictoryConditions.new()
		vc.primary_condition_type = (vc_data.get("primary_condition_type", 0) as int)
		vc.survive_rounds = (vc_data.get("survive_rounds", 0) as int)
		# target_unit_ids — JSON Array[int] → PackedInt64Array. Used by ESCORT
		# (all ids = protectees) + REACH_TILE ([0] = unit that must reach tile).
		if vc_data.has("target_unit_ids") and vc_data["target_unit_ids"] is Array:
			var t_arr: PackedInt64Array = PackedInt64Array()
			for x: Variant in (vc_data["target_unit_ids"] as Array):
				t_arr.append(int(x))
			vc.target_unit_ids = t_arr
		# target_tile — JSON Array[int,int] → Vector2i. REACH_TILE destination.
		# Absent → Vector2i.ZERO default (also valid for ANNIHILATION/ESCORT —
		# the dispatcher only consults this field when type == REACH_TILE).
		if vc_data.has("target_tile") and vc_data["target_tile"] is Array:
			var tile_arr: Array = vc_data["target_tile"] as Array
			if tile_arr.size() >= 2:
				vc.target_tile = Vector2i(int(tile_arr[0]), int(tile_arr[1]))
		c.victory_conditions = vc
	return c


# ─── State transitions (single source of mutation per TR-005) ────────────────

## Transitions to target state. ONLY callsite for `_state =` assignment per
## TR-005 + lint `lint_scenario_runner_state_match_exhaustive.sh`.
## Forward-only invariant per AC-SP-13: target ordinal must be >= current ordinal,
## EXCEPT the single legal backward edge BEAT_6_RESULT -> BEAT_4_PREP (retry).
func _transition_to(target: State) -> void:
	if _is_illegal_transition(_state, target):
		assert(false, "Illegal transition: %s -> %s" % [
			State.keys()[_state], State.keys()[target]
		])
		return
	_state = target
	_state_entered_at_msec = Time.get_ticks_msec()
	# Synchronous handler dispatch per state. Per TR-008 + Pillar 2 seal-discipline,
	# BEAT_6 -> BEAT_7 must be SYNCHRONOUS (no call_deferred between).
	match target:
		State.LOADING:
			pass  # load_scenario() is the entry path
		State.CHAPTER_START:
			_enter_chapter_start()
		State.BEAT_1_ANCHOR:
			_enter_beat_1_anchor()
		State.BEAT_2_ECHO:
			_enter_beat_2_echo()
		State.BEAT_3_BRIEF:
			_enter_beat_3_brief()
		State.BEAT_4_PREP:
			_enter_beat_4_prep()
		State.BATTLE_LOADING:
			_enter_battle_loading()
		State.BEAT_5_BATTLE:
			_enter_beat_5_battle()
		State.BEAT_6_RESULT:
			_enter_beat_6_result()
		State.BEAT_7_JUDGMENT:
			_enter_beat_7_judgment()
		State.BEAT_8_REVEAL:
			_enter_beat_8_reveal()
		State.BEAT_9_TRANSITION:
			_enter_beat_9_transition()
		State.SCENARIO_END:
			_enter_scenario_end()


## Returns true if (current -> target) transition is illegal per CR-15 + AC-SP-13.
func _is_illegal_transition(current: State, target: State) -> bool:
	# Only legal backward edge: BEAT_6_RESULT -> BEAT_4_PREP (retry).
	if current == State.BEAT_6_RESULT and target == State.BEAT_4_PREP:
		return false
	# Chapter advance: BEAT_9_TRANSITION -> LOADING (next chapter).
	if current == State.BEAT_9_TRANSITION and target == State.LOADING:
		return false
	# Forward-only: target ordinal must be >= current ordinal.
	if (target as int) < (current as int):
		return true
	# Cannot transition to self (except LOADING re-init via load_scenario).
	if target == current and current != State.LOADING:
		return true
	return false


# ─── State entry handlers ─────────────────────────────────────────────────────

func _enter_chapter_start() -> void:
	_reset_per_chapter_state()
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter == null:
		_emit_scenario_fault(_scenario_id, "chapter_start_no_chapter", {})
		return
	GameBus.chapter_started.emit(chapter.chapter_id, chapter.chapter_number)
	_transition_to(State.BEAT_1_ANCHOR)


func _enter_beat_1_anchor() -> void:
	# CP-1: emit save_checkpoint_requested (per AC-SP-21).
	GameBus.save_checkpoint_requested.emit(_make_save_context(SaveCheckpoint.CP_1))
	# Beat 1 advances on tap or beat_sequence_complete; tests drive via advance_beat().


func _enter_beat_2_echo() -> void:
	# Story Event consumer fires beat_visual_cue at this state per CR-2.
	pass


func _enter_beat_3_brief() -> void:
	pass


func _enter_beat_4_prep() -> void:
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter == null:
		return
	var payload: BattlePayload = _build_battle_payload(chapter)
	GameBus.battle_prepare_requested.emit(payload)


func _enter_battle_loading() -> void:
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter == null:
		return
	var payload: BattlePayload = _build_battle_payload(chapter)
	GameBus.battle_launch_requested.emit(payload)


func _enter_beat_5_battle() -> void:
	# Awaiting battle_outcome_resolved via GameBus subscription.
	pass


func _enter_beat_6_result() -> void:
	# Display outcome; player taps Retry (LOSS/DRAW only) or Accept (any).
	# Tests drive via accept_outcome() / retry_outcome().
	pass


## CRITICAL: SYNCHRONOUS seal of first_attempt_resolved per F-SP-3 v2.2 + TR-008.
## NO call_deferred / NO CONNECT_DEFERRED / NO await between BEAT_6 exit and this entry.
## Lint `lint_scenario_runner_no_deferred_in_beat_7_seal.sh` enforces.
func _enter_beat_7_judgment() -> void:
	# Step 1: Seal first_attempt_resolved BEFORE judge.resolve() reads it.
	if _echo_count == 0:
		_first_attempt_resolved = true
	# Step 2: Construct transient judge + resolve branch.
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter == null or _last_battle_outcome == null:
		_emit_scenario_fault(_scenario_id, "beat_7_no_chapter_or_outcome", {})
		return
	var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter,
		_last_battle_outcome.result,
		_echo_count,
		_first_attempt_resolved,
	)
	_last_branch_choice = choice
	# Step 3: CP-2 emission post-seal (per AC-SP-21).
	GameBus.save_checkpoint_requested.emit(_make_save_context(SaveCheckpoint.CP_2))
	# Step 4: Emit destiny_branch_chosen at BEAT_7 exit per CR-DB-4 (synchronous in MVP).
	GameBus.destiny_branch_chosen.emit(choice)


func _enter_beat_8_reveal() -> void:
	# Story Event consumer fires beat_visual_cue / beat_audio_cue per branch_key.
	pass


func _enter_beat_9_transition() -> void:
	# Step 1: Snapshot echo_count BEFORE reset.
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter == null:
		return
	var echo_at_completion: int = _echo_count
	# Step 2: Append per-chapter outcome to scenario archive.
	var branch_path_id: String = ""
	if _last_branch_choice != null:
		branch_path_id = _last_branch_choice.branch_key
		if _last_branch_choice.is_canonical_history:
			_canonical_delta += 1
	_scenario_path_segments.append(branch_path_id)
	_total_echo += echo_at_completion
	_chapter_outcomes.append({
		"chapter_id": chapter.chapter_id,
		"branch_path_id": branch_path_id,
		"echo_count_at_completion": echo_at_completion,
		"outcome": int(_last_battle_outcome.result) if _last_battle_outcome != null else int(BattleOutcome.Result.LOSS),
	})
	# Step 3: Construct ChapterResult (extended + back-compat shape).
	var result: ChapterResult = ChapterResult.new()
	result.chapter_id = chapter.chapter_id
	result.outcome = _last_battle_outcome.result if _last_battle_outcome != null else BattleOutcome.Result.LOSS
	result.branch_triggered = branch_path_id
	result.branch_path_id = branch_path_id
	result.echo_count_at_completion = echo_at_completion
	# Step 4: Reset per-chapter state.
	_echo_count = 0
	_first_attempt_resolved = false
	_echo_marks.clear()
	# Step 5: CP-3 emission (per AC-SP-21).
	GameBus.save_checkpoint_requested.emit(_make_save_context(SaveCheckpoint.CP_3))
	# Step 6: Emit chapter_completed.
	GameBus.chapter_completed.emit(result)
	# Step 7: Route — next chapter LOADING or SCENARIO_END.
	if _chapter_index + 1 < _chapters.size():
		_chapter_index += 1
		_transition_to(State.LOADING)
		# After LOADING transition, immediately advance to CHAPTER_START
		# (no JSON re-load — _chapters is already populated).
		_transition_to(State.CHAPTER_START)
	else:
		_transition_to(State.SCENARIO_END)


func _enter_scenario_end() -> void:
	var sr: ScenarioResult = ScenarioResult.new()
	sr.chapter_outcomes = _chapter_outcomes.duplicate(true)
	sr.canonical_delta = _canonical_delta
	sr.scenario_path_key = _compose_scenario_path_key()
	sr.total_echo = _total_echo
	GameBus.scenario_complete.emit(sr)


# ─── Beat advancement public API (drives state machine forward) ──────────────

## Advances from BEAT_1_ANCHOR / BEAT_2_ECHO / BEAT_3_BRIEF / BEAT_8_REVEAL on player tap
## or `beat_sequence_complete` signal. Internally invokes _transition_to(next).
func advance_beat() -> void:
	match _state:
		State.BEAT_1_ANCHOR:
			_transition_to(State.BEAT_2_ECHO)
		State.BEAT_2_ECHO:
			_transition_to(State.BEAT_3_BRIEF)
		State.BEAT_3_BRIEF:
			_transition_to(State.BEAT_4_PREP)
		State.BEAT_8_REVEAL:
			_transition_to(State.BEAT_9_TRANSITION)
		_:
			push_warning("ScenarioRunner.advance_beat: invalid state %s" % State.keys()[_state])


## Player confirms deployment at BEAT_4_PREP -> BATTLE_LOADING.
func confirm_deployment() -> void:
	if _state != State.BEAT_4_PREP:
		push_warning("confirm_deployment from %s" % State.keys()[_state])
		return
	_transition_to(State.BATTLE_LOADING)
	# Provisional one-frame guard before BEAT_5_BATTLE per scenario-progression §BATTLE_LOADING.
	_transition_to(State.BEAT_5_BATTLE)


## Player accepts outcome at BEAT_6_RESULT -> BEAT_7_JUDGMENT (synchronous).
func accept_outcome() -> void:
	if _state != State.BEAT_6_RESULT:
		push_warning("accept_outcome from %s" % State.keys()[_state])
		return
	# SYNCHRONOUS transition BEAT_6 -> BEAT_7 per F-SP-3 v2.2 B-1 invariant.
	_transition_to(State.BEAT_7_JUDGMENT)
	# Auto-advance BEAT_7 -> BEAT_8 (display dwell + tap UI deferred to MVP+).
	_transition_to(State.BEAT_8_REVEAL)


## Player chooses Retry at BEAT_6_RESULT (LOSS/DRAW only). Increments echo_count,
## emits scenario_beat_retried, transitions back to BEAT_4_PREP.
func retry_outcome() -> void:
	if _state != State.BEAT_6_RESULT:
		push_warning("retry_outcome from %s" % State.keys()[_state])
		return
	if _last_battle_outcome == null:
		return
	var outcome: BattleOutcome.Result = _last_battle_outcome.result
	if outcome == BattleOutcome.Result.WIN:
		push_error("EC-SP-7: retry on WIN outcome (CR-8 violation)")
		return
	var cap_var: Variant = BalanceConstants.get_const("SCENARIO_PROGRESSION_ECHO_CAP")
	var cap: int = int(cap_var) if cap_var != null else 100
	if _echo_count >= cap:
		push_warning("ScenarioRunner: echo_count cap reached at %d" % cap)
		return
	_echo_count += 1
	var mark: EchoMark = EchoMark.new()
	mark.beat_index = 5
	mark.outcome = _outcome_tag(outcome)
	mark.tag = StringName("retry_%s_%d" % [get_current_chapter().chapter_id, _echo_count])
	_echo_marks.append(mark)
	GameBus.scenario_beat_retried.emit(mark)
	_transition_to(State.BEAT_4_PREP)


# ─── Subscribers (cross-scene via GameBus) ────────────────────────────────────

## Consumes battle_outcome_resolved per ADR-0001 cross-scene routing.
## EC-SP-3: ignore if not in BEAT_5_BATTLE (CR-15 #6 duplicate-emit guard).
func _on_battle_outcome_resolved(outcome: BattleOutcome) -> void:
	if outcome == null:
		return
	if _state != State.BEAT_5_BATTLE:
		# EC-SP-3: outside-state emission ignored (no-op + warning, not crash).
		return
	# EC-SP-2: chapter_id mismatch -> push_error + ignore.
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter != null and outcome.chapter_id != "" and outcome.chapter_id != chapter.chapter_id:
		push_error("EC-SP-2: battle_outcome chapter_id mismatch: '%s' != '%s'" % [
			outcome.chapter_id, chapter.chapter_id
		])
		return
	# CR-3: never modify outcome.result. Store the reference; tri-state preserved.
	_last_battle_outcome = outcome
	_transition_to(State.BEAT_6_RESULT)


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Sole construction site for SaveContext per TR-011 + lint
## `lint_scenario_runner_save_context_complete.sh`.
func _make_save_context(cp_kind: SaveCheckpoint) -> SaveContext:
	var ctx: SaveContext = SaveContext.new()
	ctx.schema_version = 1
	ctx.slot_id = 1
	var chapter: ChapterDefinition = get_current_chapter()
	if chapter != null:
		ctx.chapter_id = StringName(chapter.chapter_id)
		ctx.chapter_number = chapter.chapter_number
	ctx.last_cp = (cp_kind as int) + 1  # CP_1 enum=0 -> last_cp=1
	if _last_battle_outcome != null:
		ctx.outcome = int(_last_battle_outcome.result)
	if _last_branch_choice != null:
		ctx.branch_key = StringName(_last_branch_choice.branch_key)
	ctx.echo_count = _echo_count
	ctx.echo_marks_archive = _echo_marks.duplicate()
	ctx.flags_to_set = PackedStringArray()
	ctx.saved_at_unix = Time.get_unix_time_from_system()
	ctx.play_time_seconds = 0
	return ctx


## Builds BattlePayload from ChapterDefinition (consumed by BattleScene + listeners).
func _build_battle_payload(chapter: ChapterDefinition) -> BattlePayload:
	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = chapter.map_id
	# Resolve branch override (if any) from the most recent prior chapter outcome.
	var override: Dictionary = _resolve_branch_override(chapter)
	# unit_roster combines player + enemy IDs (override-aware).
	var player_ids: PackedInt64Array = chapter.player_unit_ids
	if override.has("player_unit_ids"):
		player_ids = PackedInt64Array()
		for uid_var in (override["player_unit_ids"] as Array):
			player_ids.append(int(uid_var))
	var enemy_ids: PackedInt64Array = chapter.enemy_unit_ids
	if override.has("enemy_unit_ids"):
		enemy_ids = PackedInt64Array()
		for uid_var in (override["enemy_unit_ids"] as Array):
			enemy_ids.append(int(uid_var))
	var roster: PackedInt64Array = PackedInt64Array()
	for uid in player_ids:
		roster.append(uid)
	for uid in enemy_ids:
		roster.append(uid)
	payload.unit_roster = roster
	# deployment_positions (override-aware; JSON Array[int,int] -> Vector2i).
	if override.has("deployment_positions_default"):
		var dep: Dictionary = {}
		var dep_raw: Dictionary = override["deployment_positions_default"] as Dictionary
		for k in dep_raw.keys():
			var v: Variant = dep_raw[k]
			if v is Array and (v as Array).size() >= 2:
				var arr: Array = v as Array
				dep[int(k as String)] = Vector2i(int(arr[0]), int(arr[1]))
		payload.deployment_positions = dep
	else:
		payload.deployment_positions = chapter.deployment_positions_default.duplicate(true)
	payload.victory_conditions = chapter.victory_conditions
	payload.battle_start_effects = chapter.battle_start_effects.duplicate()
	return payload


## Returns the branch_overrides Dictionary entry whose key matches the most
## recent prior chapter's branch_path_id, or empty {} if no match. Empty dict
## also returned for chapter 1 (no prior chapter) or when chapter has no
## branch_overrides defined.
func _resolve_branch_override(chapter: ChapterDefinition) -> Dictionary:
	if chapter.branch_overrides.is_empty():
		return {}
	if _chapter_outcomes.is_empty():
		return {}
	var prior: Dictionary = _chapter_outcomes[_chapter_outcomes.size() - 1] as Dictionary
	var prior_branch: String = prior.get("branch_path_id", "") as String
	if prior_branch.is_empty():
		return {}
	if not chapter.branch_overrides.has(prior_branch):
		return {}
	return chapter.branch_overrides[prior_branch] as Dictionary


## F-SP-4: composes scenario_path_key from per-chapter branch_path_ids joined by "::".
func _compose_scenario_path_key() -> String:
	var parts: Array[String] = []
	for s in _scenario_path_segments:
		parts.append(s)
	return "::".join(parts)


## Maps tri-state outcome to narrative tag StringName for EchoMark.outcome.
func _outcome_tag(result: BattleOutcome.Result) -> StringName:
	match result:
		BattleOutcome.Result.WIN: return &"win"
		BattleOutcome.Result.DRAW: return &"draw"
		BattleOutcome.Result.LOSS: return &"loss"
		_: return &"unknown"


## Resets per-chapter ephemeral state. Called at CHAPTER_START + BEAT_9_TRANSITION exit.
func _reset_per_chapter_state() -> void:
	_echo_count = 0
	_first_attempt_resolved = false
	_echo_marks.clear()
	_last_battle_outcome = null
	_last_branch_choice = null


## Emits scenario_fault on validation / runtime failure.
func _emit_scenario_fault(scenario_id: String, fault: String, details: Dictionary) -> void:
	push_error("ScenarioRunner: scenario_fault scenario='%s' fault='%s' details=%s" % [
		scenario_id, fault, details
	])
	GameBus.scenario_fault.emit(scenario_id, fault, details)


# ─── Test seam ────────────────────────────────────────────────────────────────

## Test-only: directly assign chapters + reset state. Used by unit tests that
## construct ChapterDefinition objects in-memory rather than loading JSON.
## Production code MUST NOT call this — use load_scenario(json_path).
func _set_chapters_for_test(chapters: Array[ChapterDefinition], scenario_id: String = "test") -> void:
	_test_mode = true
	_scenario_id = scenario_id
	_chapters = chapters
	_chapter_index = 0
	_reset_per_chapter_state()
	_chapter_outcomes.clear()
	_scenario_path_segments = PackedStringArray()
	_canonical_delta = 0
	_total_echo = 0


## Test-only: directly inject battle outcome + transition state. Bypasses the
## CONNECT_DEFERRED GameBus subscription path for unit-test determinism.
func _force_battle_outcome_for_test(outcome: BattleOutcome) -> void:
	_last_battle_outcome = outcome


## Test-only: directly inject branch choice. Used for AC-SP-9 + AC-SP-20 tests
## that need to verify CP-3 SaveContext.branch_key without running the full BEAT_7 path.
func _force_branch_choice_for_test(choice: DestinyBranchChoice) -> void:
	_last_branch_choice = choice
