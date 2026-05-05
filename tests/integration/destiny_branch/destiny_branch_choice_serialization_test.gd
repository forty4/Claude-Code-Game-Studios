## destiny_branch_choice_serialization_test.gd
##
## Covers AC-DB-24 5-platform serialization scaffold per ADR-0018 §IN-1 +
## OQ-DB-6 (StringName field-type preservation through ResourceSaver/Loader).
##
## Sprint-7 R-3 mitigation: Linux Editor + Windows D3D12 lanes are CI-active;
## macOS Metal + iOS Metal + Android Vulkan are manual-fallback (full 5-platform
## CI deferred to release-prep sprint per CI lane gap).
##
## Critical assertion: typeof(loaded.invalid_reason) == TYPE_STRING_NAME — prior
## Godot versions silently downgraded StringName to String on .tres round-trip.
extends GdUnitTestSuite


const TEMP_PATH: String = "user://test_destiny_branch_choice.tres"


# ─── AC-DB-24: ResourceSaver/ResourceLoader round-trip ───────────────────────


func test_destiny_branch_choice_round_trip_preserves_all_9_fields() -> void:
	# Construct populated choice with non-default values across all 9 fields.
	var original: DestinyBranchChoice = DestinyBranchChoice.new()
	original.chapter_id = "ch3_baixia"
	original.branch_key = "DRAW_ch3_echo"
	original.outcome = BattleOutcome.Result.DRAW
	original.echo_count = 2
	original.is_draw_fallback = false
	original.is_canonical_history = false
	original.reserved_color_treatment = true
	original.is_invalid = false
	original.invalid_reason = &""
	# Save + reload.
	var save_err: int = ResourceSaver.save(original, TEMP_PATH)
	assert_int(save_err).is_equal(OK)
	var loaded_var: Variant = ResourceLoader.load(TEMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var loaded: DestinyBranchChoice = loaded_var as DestinyBranchChoice
	assert_object(loaded).is_not_null()
	# Field-equal across all 9.
	assert_str(loaded.chapter_id).is_equal(original.chapter_id)
	assert_str(loaded.branch_key).is_equal(original.branch_key)
	assert_int(loaded.outcome).is_equal(original.outcome)
	assert_int(loaded.echo_count).is_equal(original.echo_count)
	assert_bool(loaded.is_draw_fallback).is_equal(original.is_draw_fallback)
	assert_bool(loaded.is_canonical_history).is_equal(original.is_canonical_history)
	assert_bool(loaded.reserved_color_treatment).is_equal(original.reserved_color_treatment)
	assert_bool(loaded.is_invalid).is_equal(original.is_invalid)
	assert_str(String(loaded.invalid_reason)).is_equal(String(original.invalid_reason))
	# Cleanup.
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


# OQ-DB-6 critical assertion: invalid_reason StringName field-type preserved.
func test_invalid_reason_string_name_field_type_preserved() -> void:
	var original: DestinyBranchChoice = DestinyBranchChoice.new()
	original.is_invalid = true
	original.invalid_reason = &"invariant_violation:branch_table_empty"
	var save_err: int = ResourceSaver.save(original, TEMP_PATH)
	assert_int(save_err).is_equal(OK)
	var loaded: DestinyBranchChoice = ResourceLoader.load(
		TEMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as DestinyBranchChoice
	assert_object(loaded).is_not_null()
	# OQ-DB-6 critical: typeof MUST be TYPE_STRING_NAME (not TYPE_STRING).
	assert_int(typeof(loaded.invalid_reason)).override_failure_message(
		"OQ-DB-6: invalid_reason field-type must remain TYPE_STRING_NAME (=21) after round-trip"
	).is_equal(TYPE_STRING_NAME)
	assert_str(String(loaded.invalid_reason)).is_equal(
		"invariant_violation:branch_table_empty"
	)
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


# Empty StringName (default) round-trips correctly.
func test_empty_invalid_reason_round_trips() -> void:
	var original: DestinyBranchChoice = DestinyBranchChoice.new()
	original.invalid_reason = &""
	var save_err: int = ResourceSaver.save(original, TEMP_PATH)
	assert_int(save_err).is_equal(OK)
	var loaded: DestinyBranchChoice = ResourceLoader.load(
		TEMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as DestinyBranchChoice
	assert_int(typeof(loaded.invalid_reason)).is_equal(TYPE_STRING_NAME)
	assert_str(String(loaded.invalid_reason)).is_empty()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


# invalid() factory output round-trips correctly.
func test_invalid_factory_output_round_trips() -> void:
	var original: DestinyBranchChoice = DestinyBranchChoice.invalid(
		&"invariant_violation:chapter_null"
	)
	var save_err: int = ResourceSaver.save(original, TEMP_PATH)
	assert_int(save_err).is_equal(OK)
	var loaded: DestinyBranchChoice = ResourceLoader.load(
		TEMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as DestinyBranchChoice
	assert_bool(loaded.is_invalid).is_true()
	assert_str(String(loaded.invalid_reason)).is_equal(
		"invariant_violation:chapter_null"
	)
	assert_bool(loaded.reserved_color_treatment).is_false()
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
