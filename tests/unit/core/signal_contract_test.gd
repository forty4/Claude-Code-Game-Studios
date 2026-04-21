extends GdUnitTestSuite

## signal_contract_test.gd
## Integration test for Story 003: ADR-0001 Signal Contract Schema → GameBus drift gate.
##
## PURPOSE
## -------
## This file is the dual-gate forcing function for ADR-0001 §Signal Contract Schema
## discipline. Any change to the signal contract (rename, add, remove, payload shape
## change) MUST be reflected in BOTH:
##   (a) ADR-0001 §Signal Contract Schema table
##       (docs/architecture/ADR-0001-gamebus-autoload.md)
##   (b) The EXPECTED_SIGNALS reference list in this file
## Both changes must land in the same PR. CI blocks merge on drift.
##
## DUAL-GATE DISCIPLINE
## --------------------
## DO NOT update game_bus.gd signal declarations without also updating EXPECTED_SIGNALS
## here. DO NOT update EXPECTED_SIGNALS here without also updating the ADR-0001 schema
## table. Violations cause CI failure (this test).
##
## HOW TO ADD A SIGNAL (ADR-0001 §Evolution Rule §1)
## --------------------------------------------------
## 1. Edit ADR-0001 §Signal Contract Schema — add the row, bump signal count, add
##    a dated changelog line.
## 2. Add the signal declaration to src/core/game_bus.gd.
## 3. Add the entry to EXPECTED_SIGNALS below (in the matching domain group).
## All three changes go in one PR. This test blocks merge if step 3 is omitted.
##
## NOTE on load() + new() vs live autoload
## ----------------------------------------
## GdUnit4 mounts autoloads in the test tree, so get_tree().root.get_node("GameBus")
## is accessible. However, game_bus_declaration_test.gd (Story 002) uses
## load(GAME_BUS_PATH) + script.new() for isolation — this test follows the same
## pattern for consistency. Tradeoff: we test the script's declared signals, not the
## runtime singleton. This is sufficient for the drift-gate purpose because signal
## declarations in GDScript are static at parse time.

const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"

## Authoritative reference list — ADR-0001 §Signal Contract Schema (all 27 signals).
## Source of truth: docs/architecture/ADR-0001-gamebus-autoload.md
##
## DO NOT reorder within a domain group — must match ADR §Signal Contract Schema
## table row order so a reader can trace this file row-by-row against the ADR.
##
## Entry format:
##   { "name": String, "args": Array[Dictionary] }
## Arg format (primitives):
##   { "name": String, "type": int }
## Arg format (Resource types — TYPE_OBJECT):
##   { "name": String, "type": int, "class_name": String }
##
## Type int values use GDScript TYPE_* global constants (Godot's Variant.Type enum).
## For TYPE_OBJECT args, "class_name" is the expected Resource subclass name exactly
## as returned by get_signal_list() — matched case-sensitively.
const EXPECTED_SIGNALS: Array[Dictionary] = [
	# ── Domain: Scenario Progression (ADR-0001 §Signal Contract Schema §1) ────────
	{
		"name": "chapter_started",
		"args": [
			{"name": "chapter_id", "type": TYPE_STRING},
			{"name": "chapter_number", "type": TYPE_INT},
		],
	},
	{
		"name": "battle_prepare_requested",
		"args": [
			{"name": "payload", "type": TYPE_OBJECT, "class_name": "BattlePayload"},
		],
	},
	{
		"name": "battle_launch_requested",
		"args": [
			{"name": "payload", "type": TYPE_OBJECT, "class_name": "BattlePayload"},
		],
	},
	{
		"name": "chapter_completed",
		"args": [
			{"name": "result", "type": TYPE_OBJECT, "class_name": "ChapterResult"},
		],
	},
	{
		"name": "scenario_complete",
		"args": [
			{"name": "scenario_id", "type": TYPE_STRING},
		],
	},
	{
		"name": "scenario_beat_retried",
		"args": [
			{"name": "mark", "type": TYPE_OBJECT, "class_name": "EchoMark"},
		],
	},
	# ── Domain: Grid Battle (ADR-0001 §Signal Contract Schema §2) ─────────────────
	{
		"name": "battle_outcome_resolved",
		"args": [
			{"name": "outcome", "type": TYPE_OBJECT, "class_name": "BattleOutcome"},
		],
	},
	# ── Domain: Turn Order (ADR-0001 §Signal Contract Schema §3) ──────────────────
	{
		"name": "round_started",
		"args": [
			{"name": "round_number", "type": TYPE_INT},
		],
	},
	{
		"name": "unit_turn_started",
		"args": [
			{"name": "unit_id", "type": TYPE_INT},
		],
	},
	{
		"name": "unit_turn_ended",
		"args": [
			{"name": "unit_id", "type": TYPE_INT},
			{"name": "acted", "type": TYPE_BOOL},
		],
	},
	# ── Domain: HP/Status (ADR-0001 §Signal Contract Schema §4) ───────────────────
	{
		"name": "unit_died",
		"args": [
			{"name": "unit_id", "type": TYPE_INT},
		],
	},
	# ── Domain: Destiny (ADR-0001 §Signal Contract Schema §5) ────────────────────
	{
		"name": "destiny_branch_chosen",
		"args": [
			{"name": "choice", "type": TYPE_OBJECT, "class_name": "DestinyBranchChoice"},
		],
	},
	{
		"name": "destiny_state_flag_set",
		"args": [
			{"name": "flag_key", "type": TYPE_STRING},
			{"name": "value", "type": TYPE_BOOL},
		],
	},
	{
		"name": "destiny_state_echo_added",
		"args": [
			{"name": "mark", "type": TYPE_OBJECT, "class_name": "EchoMark"},
		],
	},
	# ── Domain: Story Event / Beat (ADR-0001 §Signal Contract Schema §6) ──────────
	{
		"name": "beat_visual_cue_fired",
		"args": [
			{"name": "cue", "type": TYPE_OBJECT, "class_name": "BeatCue"},
		],
	},
	{
		"name": "beat_audio_cue_fired",
		"args": [
			{"name": "cue", "type": TYPE_OBJECT, "class_name": "BeatCue"},
		],
	},
	{
		"name": "beat_sequence_complete",
		"args": [
			{"name": "beat_number", "type": TYPE_INT},
		],
	},
	# ── Domain: Input (ADR-0001 §Signal Contract Schema §7) ──────────────────────
	{
		"name": "input_action_fired",
		"args": [
			{"name": "action", "type": TYPE_STRING},
			{"name": "context", "type": TYPE_OBJECT, "class_name": "InputContext"},
		],
	},
	{
		"name": "input_state_changed",
		"args": [
			{"name": "from", "type": TYPE_INT},
			{"name": "to", "type": TYPE_INT},
		],
	},
	{
		"name": "input_mode_changed",
		"args": [
			{"name": "mode", "type": TYPE_INT},
		],
	},
	# ── Domain: UI / Flow (ADR-0001 §Signal Contract Schema §8) ──────────────────
	{
		"name": "ui_input_block_requested",
		"args": [
			{"name": "reason", "type": TYPE_STRING},
		],
	},
	{
		"name": "ui_input_unblock_requested",
		"args": [
			{"name": "reason", "type": TYPE_STRING},
		],
	},
	{
		"name": "scene_transition_failed",
		"args": [
			{"name": "context", "type": TYPE_STRING},
			{"name": "reason", "type": TYPE_STRING},
		],
	},
	# ── Domain: Persistence (ADR-0001 §Signal Contract Schema §9) ────────────────
	{
		"name": "save_checkpoint_requested",
		"args": [
			{"name": "ctx", "type": TYPE_OBJECT, "class_name": "SaveContext"},
		],
	},
	{
		"name": "save_persisted",
		"args": [
			{"name": "chapter_number", "type": TYPE_INT},
			{"name": "cp", "type": TYPE_INT},
		],
	},
	{
		"name": "save_load_failed",
		"args": [
			{"name": "op", "type": TYPE_STRING},
			{"name": "reason", "type": TYPE_STRING},
		],
	},
	# ── Domain: Environment (ADR-0001 §Signal Contract Schema §10) ───────────────
	{
		"name": "tile_destroyed",
		"args": [
			{"name": "coord", "type": TYPE_VECTOR2I},
		],
	},
]


# ── Helpers ───────────────────────────────────────────────────────────────────────


## Thin delegation to the shared TestHelpers module.
## Kept as a local wrapper so callers within this file are unchanged.
func _get_user_signals(instance: Node) -> Array[Dictionary]:
	return TestHelpers.get_user_signals(instance)


# ── Tests ─────────────────────────────────────────────────────────────────────────


## AC-1: User-declared signal count on GameBus == EXPECTED_SIGNALS.size() (== 27).
## Any addition or removal that is not mirrored in this file causes a count mismatch
## and fails with a message listing which signals are missing and which are extra.
func test_signal_contract_count_matches_expected() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())

	# Act
	var user_signals: Array[Dictionary] = _get_user_signals(instance)
	var actual_count: int = user_signals.size()
	var expected_count: int = EXPECTED_SIGNALS.size()  # == 27

	var actual_names: Array[String] = []
	for sig: Dictionary in user_signals:
		actual_names.append(sig["name"] as String)
	var expected_names: Array[String] = []
	for entry: Dictionary in EXPECTED_SIGNALS:
		expected_names.append(entry["name"] as String)

	var missing: Array[String] = []
	for sig_name: String in expected_names:
		if sig_name not in actual_names:
			missing.append(sig_name)
	var extra: Array[String] = []
	for sig_name: String in actual_names:
		if sig_name not in expected_names:
			extra.append(sig_name)

	# Assert
	assert_int(actual_count).override_failure_message(
		("Signal count mismatch: GameBus declares %d, reference list expects %d.\n"
		+ "Missing from GameBus: %s\nExtra on GameBus not in reference list: %s") % [
			actual_count, expected_count, str(missing), str(extra)
		]
	).is_equal(expected_count)


## AC-2: Bidirectional name coverage.
## Every signal in EXPECTED_SIGNALS must be present on GameBus AND every signal on
## GameBus must be accounted for in EXPECTED_SIGNALS. Both directions are checked so
## neither additions nor removals slip through silently.
## On mismatch, fails with "Missing: [names]" and/or "Extra: [names]" for diagnosis.
func test_signal_contract_all_names_covered() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var user_signals: Array[Dictionary] = _get_user_signals(instance)

	var actual_names: Array[String] = []
	for sig: Dictionary in user_signals:
		actual_names.append(sig["name"] as String)
	var expected_names: Array[String] = []
	for entry: Dictionary in EXPECTED_SIGNALS:
		expected_names.append(entry["name"] as String)

	# Act — compute Missing (in ADR, absent from GameBus) and Extra (on GameBus, absent from ADR)
	var missing: Array[String] = []
	for sig_name: String in expected_names:
		if sig_name not in actual_names:
			missing.append(sig_name)
	var extra: Array[String] = []
	for sig_name: String in actual_names:
		if sig_name not in expected_names:
			extra.append(sig_name)

	# Assert — both directions must be empty
	assert_array(missing).override_failure_message(
		("Signal `%s` declared in ADR-0001 but MISSING on GameBus.\n"
		+ "Add it to src/core/game_bus.gd and land the change in the same PR as the ADR update.") % str(missing)
	).is_empty()

	assert_array(extra).override_failure_message(
		("Signal `%s` on GameBus NOT in ADR-0001 reference list.\n"
		+ "Either add to ADR-0001 §Signal Contract Schema and update EXPECTED_SIGNALS here, "
		+ "or remove from src/core/game_bus.gd. Both changes must land in the same PR.") % str(extra)
	).is_empty()


## AC-3: Arg type and class_name matching.
## For each signal in EXPECTED_SIGNALS that is also present on GameBus, verifies:
##   - arg count matches
##   - each arg's type (Variant.Type int) matches
##   - for TYPE_OBJECT args, the class_name string matches exactly
## On mismatch, the failure message names the offending signal and arg index.
func test_signal_contract_arg_types_match() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())

	# Build lookup: signal name → actual signal dict
	var actual_by_name: Dictionary = {}
	for sig: Dictionary in instance.get_signal_list():
		actual_by_name[sig["name"] as String] = sig

	# Act + Assert — iterate all expected entries
	for expected_entry: Dictionary in EXPECTED_SIGNALS:
		var sig_name: String = expected_entry["name"] as String
		if not actual_by_name.has(sig_name):
			continue  # Missing-signal already surfaced by AC-2; skip to avoid noise

		var actual_sig: Dictionary = actual_by_name[sig_name] as Dictionary
		var expected_args: Array = expected_entry["args"] as Array
		var actual_args: Array = actual_sig["args"] as Array

		# Assert arg count
		assert_int(actual_args.size()).override_failure_message(
			"Signal `%s`: expected %d arg(s), got %d" % [
				sig_name, expected_args.size(), actual_args.size()
			]
		).is_equal(expected_args.size())

		# Assert each arg's type and, for TYPE_OBJECT, its class_name
		var check_count: int = mini(expected_args.size(), actual_args.size())
		for i: int in check_count:
			var exp_arg: Dictionary = expected_args[i] as Dictionary
			var act_arg: Dictionary = actual_args[i] as Dictionary
			var expected_type: int = exp_arg["type"] as int
			var actual_type: int = act_arg["type"] as int

			assert_int(actual_type).override_failure_message(
				"Signal `%s` arg[%d] ('%s'): expected type %d (%s), got %d" % [
					sig_name, i,
					exp_arg["name"],
					expected_type, type_string(expected_type),
					actual_type
				]
			).is_equal(expected_type)

			if expected_type == TYPE_OBJECT:
				var expected_class: String = exp_arg.get("class_name", "") as String
				var actual_class: String = act_arg.get("class_name", "") as String
				assert_str(actual_class).override_failure_message(
					"Signal `%s` arg[%d] ('%s'): expected class_name '%s', got '%s'" % [
						sig_name, i,
						exp_arg["name"],
						expected_class, actual_class
					]
				).is_equal(expected_class)


## AC-4: No silent signal additions allowed.
##
## Scenario: A developer adds `signal rogue_signal(x: int)` to game_bus.gd without
## updating ADR-0001 §Signal Contract Schema or EXPECTED_SIGNALS in this file.
##
## Expected CI outcome:
##   FAIL — "Extra signal on GameBus not in ADR-0001 reference list: rogue_signal"
##   Merge blocked until either:
##     (a) the signal is added to ADR-0001 and EXPECTED_SIGNALS (same PR), or
##     (b) the signal is removed from game_bus.gd.
##
## Implementation note: assertion logic is identical to AC-2's Extra check. This
## function exists as a distinct named regression point so the "silent addition"
## scenario is explicitly documented and searchable in CI history.
func test_signal_contract_rejects_extra_signals() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var user_signals: Array[Dictionary] = _get_user_signals(instance)

	var actual_names: Array[String] = []
	for sig: Dictionary in user_signals:
		actual_names.append(sig["name"] as String)
	var expected_names: Array[String] = []
	for entry: Dictionary in EXPECTED_SIGNALS:
		expected_names.append(entry["name"] as String)

	# Act — find signals present on GameBus but absent from the ADR reference list
	var extra: Array[String] = []
	for sig_name: String in actual_names:
		if sig_name not in expected_names:
			extra.append(sig_name)

	# Assert
	assert_array(extra).override_failure_message(
		("Extra signal(s) on GameBus not in ADR-0001 reference list: %s\n"
		+ "Either add to ADR-0001 §Signal Contract Schema and update EXPECTED_SIGNALS here, "
		+ "or remove from src/core/game_bus.gd. Both changes must land in the same PR.") % str(extra)
	).is_empty()


## AC-5: Rename drift detection.
##
## Scenario: Someone renames `battle_outcome_resolved` → `combat_outcome_resolved` in
## game_bus.gd without updating ADR-0001 §Signal Contract Schema or EXPECTED_SIGNALS.
##
## Expected CI outcome:
##   FAIL — two assertions:
##     "Missing: ['battle_outcome_resolved']"  (was in ADR, now gone from GameBus)
##     "Extra:   ['combat_outcome_resolved']"  (now on GameBus, unknown to ADR)
##
## Per ADR-0001 §Evolution Rule §2: a rename is a BREAKING change. Resolution:
##   - Author a superseding ADR, add a one-release forwarder shim to game_bus.gd,
##     and update EXPECTED_SIGNALS here — all in one PR.
##
## Implementation note: assertion logic is identical to AC-2's bidirectional check.
## This function exists as a named regression point documenting the rename scenario
## explicitly so CI failure messages are self-explanatory.
func test_signal_contract_detects_rename_drift() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var user_signals: Array[Dictionary] = _get_user_signals(instance)

	var actual_names: Array[String] = []
	for sig: Dictionary in user_signals:
		actual_names.append(sig["name"] as String)
	var expected_names: Array[String] = []
	for entry: Dictionary in EXPECTED_SIGNALS:
		expected_names.append(entry["name"] as String)

	# Act — a rename produces both a missing AND an extra entry
	var missing: Array[String] = []
	for sig_name: String in expected_names:
		if sig_name not in actual_names:
			missing.append(sig_name)
	var extra: Array[String] = []
	for sig_name: String in actual_names:
		if sig_name not in expected_names:
			extra.append(sig_name)

	# Assert
	assert_array(missing).override_failure_message(
		("Signal(s) declared in ADR-0001 MISSING from GameBus (possible rename): %s\n"
		+ "If renamed: author a superseding ADR per ADR-0001 §Evolution Rule §2, "
		+ "add a one-release forwarder shim to game_bus.gd, "
		+ "and update EXPECTED_SIGNALS here — all in one PR.") % str(missing)
	).is_empty()

	assert_array(extra).override_failure_message(
		("Signal(s) on GameBus NOT in ADR-0001 reference list (possible rename target): %s\n"
		+ "If this is a rename, the old name must also be removed; see missing list above.") % str(extra)
	).is_empty()


## AC-6: Determinism — the count and name checks produce identical results across
## 10 consecutive runs.
## No randomness, no time-dependent state, no file I/O variance. Guarantees CI
## stability regardless of test ordering or engine state.
func test_signal_contract_is_deterministic() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var first_count: int = -1
	var first_names: Array[String] = []

	# Act — run the same query 10 times and compare each run to run 0
	for run: int in 10:
		var instance: Node = auto_free(script.new())
		var user_signals: Array[Dictionary] = _get_user_signals(instance)
		var count: int = user_signals.size()
		var names: Array[String] = []
		for sig: Dictionary in user_signals:
			names.append(sig["name"] as String)
		names.sort()

		if first_count == -1:
			first_count = count
			first_names.assign(names)
		else:
			# Assert — each run must match run 0
			assert_int(count).override_failure_message(
				"Non-deterministic result: run %d returned %d signal(s), run 0 returned %d" % [
					run, count, first_count
				]
			).is_equal(first_count)

			assert_array(names).override_failure_message(
				"Non-deterministic result: signal name list changed between run 0 and run %d" % run
			).contains_exactly_in_any_order(first_names)
