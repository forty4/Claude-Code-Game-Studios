extends GdUnitTestSuite

## payload_classes_test.gd
## Unit tests for Story 001: Non-provisional payload Resource classes.
## Covers AC-1 through AC-7.

const PAYLOAD_DIR: String = "res://src/core/payloads/"

const PAYLOAD_FILES: Array[String] = [
	"battle_outcome.gd",
	"battle_payload.gd",
	"chapter_result.gd",
	"input_context.gd",
	"victory_conditions.gd",
	"battle_start_effect.gd",
]


## AC-1: BattleOutcome instantiates with correct default field values and frozen enum ordering.
func test_battle_outcome_has_expected_default_field_schema() -> void:
	# Arrange / Act
	var bo := BattleOutcome.new()

	# Assert — default field values
	assert_int(bo.result).is_equal(BattleOutcome.Result.LOSS)
	assert_str(bo.chapter_id).is_equal("")
	assert_int(bo.final_round).is_equal(0)
	assert_bool(bo.surviving_units is PackedInt64Array).is_true()
	assert_bool(bo.defeated_units is PackedInt64Array).is_true()
	assert_bool(bo.is_abandon).is_false()

	# Assert — enum ordering frozen per TR-save-load-005
	assert_int(BattleOutcome.Result.WIN).is_equal(0)
	assert_int(BattleOutcome.Result.DRAW).is_equal(1)
	assert_int(BattleOutcome.Result.LOSS).is_equal(2)


## AC-2: BattlePayload fields carry correct static types after assignment.
func test_battle_payload_fields_have_correct_types() -> void:
	# Arrange
	var bp := BattlePayload.new()

	# Act
	bp.unit_roster = PackedInt64Array([1, 2, 3])
	bp.battle_start_effects = [BattleStartEffect.new(), BattleStartEffect.new()]

	# Assert
	assert_bool(bp.unit_roster is PackedInt64Array).is_true()
	assert_bool(bp.deployment_positions is Dictionary).is_true()
	assert_int(bp.battle_start_effects.size()).is_equal(2)
	assert_bool(bp.battle_start_effects[0] is BattleStartEffect).is_true()
	assert_bool(bp.battle_start_effects[1] is BattleStartEffect).is_true()


## AC-3: ChapterResult.outcome accepts BattleOutcome.Result enum values correctly.
func test_chapter_result_outcome_accepts_battle_outcome_enum() -> void:
	# Arrange
	var cr := ChapterResult.new()

	# Act + Assert — WIN
	cr.outcome = BattleOutcome.Result.WIN
	assert_int(cr.outcome).is_equal(0)

	# Act + Assert — DRAW
	cr.outcome = BattleOutcome.Result.DRAW
	assert_int(cr.outcome).is_equal(1)


## AC-4: InputContext fields round-trip assigned values identically.
func test_input_context_fields_round_trip_values() -> void:
	# Arrange
	var ic := InputContext.new()

	# Act
	ic.target_coord = Vector2i(3, 4)
	ic.target_unit_id = 42
	ic.source_device = 0

	# Assert
	assert_bool(ic.target_coord == Vector2i(3, 4)).is_true()
	assert_int(ic.target_unit_id).is_equal(42)
	assert_int(ic.source_device).is_equal(0)


## AC-5: BattlePayload accepts VictoryConditions and BattleStartEffect nested resource types.
func test_battle_payload_accepts_nested_resource_types() -> void:
	# Arrange
	var bp := BattlePayload.new()

	# Act
	bp.victory_conditions = VictoryConditions.new()
	bp.battle_start_effects = [BattleStartEffect.new(), BattleStartEffect.new()]

	# Assert
	assert_bool(bp.victory_conditions is VictoryConditions).is_true()
	assert_int(bp.battle_start_effects.size()).is_equal(2)
	assert_bool(bp.battle_start_effects[0] is BattleStartEffect).is_true()
	assert_bool(bp.battle_start_effects[1] is BattleStartEffect).is_true()


## AC-6: No payload file uses a bare untyped Array or Variant field.
## deployment_positions: Dictionary is the sole permitted untyped container
## and is explicitly exempted (rationale documented in battle_payload.gd docstring).
func test_payload_classes_use_no_untyped_array_or_variant() -> void:
	var bare_array_regex := RegEx.new()
	bare_array_regex.compile(": Array[^\\[]")

	var variant_regex := RegEx.new()
	variant_regex.compile(": Variant")

	for file_name: String in PAYLOAD_FILES:
		var path: String = PAYLOAD_DIR + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		assert_bool(file != null).is_true()
		var content: String = file.get_as_text()
		file.close()

		# Strip comment lines so docstring prose does not falsely trigger
		var lines := content.split("\n")
		var code_lines: PackedStringArray = PackedStringArray()
		for line: String in lines:
			var stripped := line.strip_edges()
			if not stripped.begins_with("#"):
				code_lines.append(line)
		var code_only: String = "\n".join(code_lines)

		assert_bool(bare_array_regex.search(code_only) == null).is_true()
		assert_bool(variant_regex.search(code_only) == null).is_true()


## AC-7: Every payload file has a class-level ## docstring with signal, emitter, and consumer references.
func test_all_payload_files_have_required_docstring() -> void:
	for file_name: String in PAYLOAD_FILES:
		var path: String = PAYLOAD_DIR + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		assert_bool(file != null).is_true()
		var content: String = file.get_as_text()
		file.close()

		# Count ## lines that appear before the class_name declaration
		var lines := content.split("\n")
		var docstring_lines: int = 0
		var found_class_name: bool = false
		for line: String in lines:
			if line.begins_with("class_name"):
				found_class_name = true
				break
			if line.begins_with("##"):
				docstring_lines += 1

		assert_bool(found_class_name).is_true()
		assert_int(docstring_lines).is_greater_equal(3)

		# Check for required docstring keywords (case-insensitive)
		var lower: String = content.to_lower()
		# "emitter:" must be present in every docstring
		assert_bool(lower.contains("emitter:")).is_true()
		# "consumed by:" or "consumer" covers consumer list
		assert_bool(lower.contains("consumed by:") or lower.contains("consumer")).is_true()
		# signal name or the word "signal" must appear
		assert_bool(
			lower.contains("signal") or
			lower.contains("battle_outcome_resolved") or
			lower.contains("battle_prepare_requested") or
			lower.contains("chapter_completed") or
			lower.contains("input_action_fired")
		).is_true()
