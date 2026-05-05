## chapter_definition_validation_test.gd
##
## Covers EC-SP-8 chapter validation pipeline (FATAL on malformed data per
## ADR-0017 §JSON Schema lines 405-418).
extends GdUnitTestSuite


# ─── EC-SP-8: chapter_id format ───────────────────────────────────────────────


## chapter_id missing -> validation fails with "missing_chapter_id".
func test_missing_chapter_id_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record.erase("chapter_id")
	assert_str(runner._validate_chapter_record(record)).is_equal("missing_chapter_id")


## chapter_id with uppercase -> "chapter_id_invalid_format".
func test_chapter_id_uppercase_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record["chapter_id"] = "Ch01_BadFormat"
	assert_str(runner._validate_chapter_record(record)).is_equal("chapter_id_invalid_format")


# ─── EC-SP-8: branch_table validation ────────────────────────────────────────


## Missing branch_table -> "missing_branch_table".
func test_missing_branch_table_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record.erase("branch_table")
	assert_str(runner._validate_chapter_record(record)).is_equal("missing_branch_table")


## branch_path_id with invalid characters -> "branch_path_id_invalid_format".
func test_branch_path_id_invalid_chars_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record["branch_table"] = {
		"WIN_default":  "WIN-bad-format",  # Hyphen not allowed per F-SP-4 regex.
		"LOSS_default": "LOSS_test_default",
	}
	# canonical_branch_key must reference a valid value still.
	record["canonical_branch_key"] = "LOSS_test_default"
	assert_str(runner._validate_chapter_record(record)).is_equal("branch_path_id_invalid_format")


# ─── EC-SP-8: canonical_branch_key invariants ───────────────────────────────


## Missing canonical_branch_key -> "missing_canonical_branch_key".
func test_missing_canonical_branch_key_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record.erase("canonical_branch_key")
	assert_str(runner._validate_chapter_record(record)).is_equal("missing_canonical_branch_key")


## canonical_branch_key not in branch_table.values() -> "canonical_branch_key_not_in_table".
func test_canonical_branch_key_not_in_table_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record["canonical_branch_key"] = "ORPHAN_branch_not_in_table"
	assert_str(runner._validate_chapter_record(record)).is_equal("canonical_branch_key_not_in_table")


# ─── EC-SP-8: echo_threshold rules ───────────────────────────────────────────


## Chapter 2+ with echo_threshold == 0 -> "echo_threshold_below_one_for_non_ch1".
func test_chapter_2_echo_threshold_zero_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record["chapter_number"] = 2
	record["echo_threshold"] = 0
	assert_str(runner._validate_chapter_record(record)).is_equal("echo_threshold_below_one_for_non_ch1")


# ─── EC-SP-8: author_draw_branch + DRAW_ key requirement ────────────────────


## author_draw_branch=true without any DRAW_ key -> "author_draw_branch_missing_draw_entry".
func test_author_draw_branch_without_draw_key_fails() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	record["author_draw_branch"] = true
	# branch_table has WIN_/LOSS_ but no DRAW_
	assert_str(runner._validate_chapter_record(record)).is_equal("author_draw_branch_missing_draw_entry")


# ─── Valid record passes ─────────────────────────────────────────────────────


## Valid record returns empty fault string (success).
func test_valid_record_passes() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_valid_record()
	assert_str(runner._validate_chapter_record(record)).is_empty()


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_valid_record() -> Dictionary:
	return {
		"chapter_id": "test_ch",
		"chapter_number": 1,
		"map_id": "test_map",
		"author_draw_branch": false,
		"echo_threshold": 0,
		"branch_table": {
			"WIN_default":  "WIN_test_default",
			"LOSS_default": "LOSS_test_default",
		},
		"canonical_branch_key": "WIN_test_default",
	}
