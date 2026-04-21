extends GdUnitTestSuite

## payload_serialization_test.gd
## Integration test for Story 004: ResourceSaver/Loader round-trip validation
## for the 6 non-provisional payload Resource classes from Story 001.
##
## Governing ADR: ADR-0001 §Implementation Guidelines §4 (Serialization contract)
##                + §Validation Criteria V-3.
## Related TRs:   TR-save-load-004 (CACHE_MODE_IGNORE discipline),
##                TR-save-load-005 (BattleOutcome.Result append-only enum ordering).
##
## AC-7 (cleanup discipline) is enforced by before_test/after_test — every tmp
## file path is tracked in _tmp_paths and deleted unconditionally in after_test.
## AC-8 (determinism) is enforced by using constant field values in all factory
## functions — no randi(), no time-dependent field values.


# ── Tmp-path management ───────────────────────────────────────────────────────

## Tracks every tmp file path created in the current test function.
## Reset to empty in before_test; iterated and deleted in after_test.
var _tmp_paths: Array[String] = []

## Per-test monotonic counter — combined with Time.get_ticks_usec() to guarantee
## no collisions even if two allocations occur within the same microsecond.
var _path_counter: int = 0


func before_test() -> void:
	_tmp_paths = []
	_path_counter = 0
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://tmp/")
	)


func after_test() -> void:
	for path: String in _tmp_paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_tmp_paths = []


## Allocates a unique tmp path and registers it for cleanup in after_test.
func _make_tmp_path(prefix: String) -> String:
	_path_counter += 1
	var path: String = "user://tmp/payload_test_%s_%d_%d.tres" % [
		prefix, Time.get_ticks_usec(), _path_counter
	]
	_tmp_paths.append(path)
	return path


# ── Factory functions (AC-7: no inline hardcoded literals beyond boundary values) ──


static func _make_populated_battle_outcome() -> BattleOutcome:
	var bo := BattleOutcome.new()
	bo.result = BattleOutcome.Result.WIN
	bo.chapter_id = "ch_03_리푸쉬"  # Korean — Unicode round-trip coverage
	bo.final_round = 17
	bo.surviving_units = PackedInt64Array([101, 102, 103])
	bo.defeated_units = PackedInt64Array([201, 202])
	bo.is_abandon = false
	return bo


static func _make_populated_battle_start_effect_a() -> BattleStartEffect:
	var bse := BattleStartEffect.new()
	bse.effect_id = "effect_alpha"
	bse.target_faction = 1
	bse.value = 50
	return bse


static func _make_populated_battle_start_effect_b() -> BattleStartEffect:
	var bse := BattleStartEffect.new()
	bse.effect_id = "effect_beta"
	bse.target_faction = 2
	bse.value = 75
	return bse


static func _make_populated_victory_conditions() -> VictoryConditions:
	var vc := VictoryConditions.new()
	vc.primary_condition_type = 3
	vc.target_unit_ids = PackedInt64Array([501, 502, 503])
	return vc


static func _make_populated_battle_payload() -> BattlePayload:
	var bp := BattlePayload.new()
	bp.map_id = "map_guandu_01"
	bp.unit_roster = PackedInt64Array([1, 2, 3, 4])
	# Keys are int (unit_id), values are Vector2i (grid coord) — per BattlePayload docstring
	# and ADR-0001 Signal Contract Schema. Story 004 AC-2 wording has this direction inverted
	# (spec-wording issue flagged for /story-done correction).
	bp.deployment_positions = {
		1: Vector2i(3, 4),
		2: Vector2i(5, 6),
		3: Vector2i(7, 8),
	}
	bp.victory_conditions = _make_populated_victory_conditions()
	bp.battle_start_effects = [
		_make_populated_battle_start_effect_a(),
		_make_populated_battle_start_effect_b(),
	]
	return bp


static func _make_populated_chapter_result() -> ChapterResult:
	var cr := ChapterResult.new()
	cr.chapter_id = "ch_02_관도"
	cr.outcome = BattleOutcome.Result.DRAW
	cr.branch_triggered = "branch_zhang_fei_joins"
	cr.flags_to_set = ["saved_liu_bei", "met_zhang_fei"]
	return cr


static func _make_populated_input_context() -> InputContext:
	var ic := InputContext.new()
	ic.target_coord = Vector2i(5, 7)
	ic.target_unit_id = 42
	ic.source_device = 2
	return ic


# ── Helper: save → assert OK → load with CACHE_MODE_IGNORE ────────────────────


## Saves a Resource to tmp_path and asserts the save succeeded.
## Returns the loaded Resource (with CACHE_MODE_IGNORE) or null on save failure.
func _save_and_load(resource: Resource, tmp_path: String) -> Resource:
	var err: int = ResourceSaver.save(resource, tmp_path)
	assert_int(err).override_failure_message(
		("ResourceSaver.save() failed for path '%s' with error code %d"
		+ " — check that user://tmp/ is writable and the Resource has no unserializable fields.") % [
			tmp_path, err
		]
	).is_equal(OK)
	if err != OK:
		return null
	var loaded: Resource = ResourceLoader.load(
		tmp_path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_bool(loaded != null).override_failure_message(
		("ResourceLoader.load() returned null for '%s'"
		+ " — file may be corrupted or class_name not registered.") % tmp_path
	).is_true()
	return loaded


# ── Tests ─────────────────────────────────────────────────────────────────────


## AC-1: BattleOutcome round-trip — all 6 fields, Korean chapter_id, enum WIN.
func test_battle_outcome_roundtrip() -> void:
	# Arrange
	var original: BattleOutcome = _make_populated_battle_outcome()
	var tmp_path: String = _make_tmp_path("battle_outcome")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return  # save failure already asserted above

	# Assert — class identity
	assert_bool(loaded is BattleOutcome).override_failure_message(
		"Loaded resource is not BattleOutcome — class_name may be unregistered or round-trip changed the type."
	).is_true()
	var lo: BattleOutcome = loaded as BattleOutcome

	# Assert — field-by-field with actionable failure messages
	assert_int(lo.result).override_failure_message(
		"BattleOutcome.result diverged: expected Result.WIN (%d), got %d" % [BattleOutcome.Result.WIN, lo.result]
	).is_equal(BattleOutcome.Result.WIN)

	assert_str(lo.chapter_id).override_failure_message(
		"BattleOutcome.chapter_id diverged: expected 'ch_03_리푸쉬', got '%s' — check UTF-8 round-trip." % lo.chapter_id
	).is_equal("ch_03_리푸쉬")

	assert_int(lo.final_round).override_failure_message(
		"BattleOutcome.final_round diverged: expected 17, got %d" % lo.final_round
	).is_equal(17)

	assert_bool(lo.surviving_units == PackedInt64Array([101, 102, 103])).override_failure_message(
		"BattleOutcome.surviving_units diverged: expected [101,102,103], got %s" % str(lo.surviving_units)
	).is_true()

	assert_bool(lo.defeated_units == PackedInt64Array([201, 202])).override_failure_message(
		"BattleOutcome.defeated_units diverged: expected [201,202], got %s" % str(lo.defeated_units)
	).is_true()

	assert_bool(lo.is_abandon == false).override_failure_message(
		"BattleOutcome.is_abandon diverged: expected false, got true"
	).is_true()


## AC-2: BattlePayload round-trip — Dictionary with int→Vector2i entries,
## Array[BattleStartEffect] with 2 nested Resources, nested VictoryConditions.
## Note: deployment_positions keys are int (unit_id) → Vector2i (grid coord),
## matching BattlePayload docstring and ADR-0001. Story AC-2 wording is inverted.
func test_battle_payload_roundtrip() -> void:
	# Arrange
	var original: BattlePayload = _make_populated_battle_payload()
	var tmp_path: String = _make_tmp_path("battle_payload")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is BattlePayload).override_failure_message(
		"Loaded resource is not BattlePayload."
	).is_true()
	var lo: BattlePayload = loaded as BattlePayload

	# map_id
	assert_str(lo.map_id).override_failure_message(
		"BattlePayload.map_id diverged: expected 'map_guandu_01', got '%s'" % lo.map_id
	).is_equal("map_guandu_01")

	# unit_roster
	assert_bool(lo.unit_roster == PackedInt64Array([1, 2, 3, 4])).override_failure_message(
		"BattlePayload.unit_roster diverged: expected [1,2,3,4], got %s" % str(lo.unit_roster)
	).is_true()

	# deployment_positions — Dictionary with int keys → Vector2i values
	assert_int(lo.deployment_positions.size()).override_failure_message(
		"BattlePayload.deployment_positions.size() diverged: expected 3, got %d" % lo.deployment_positions.size()
	).is_equal(3)

	assert_bool(lo.deployment_positions.has(1)).override_failure_message(
		"BattlePayload.deployment_positions missing key 1 after round-trip."
	).is_true()
	assert_bool(lo.deployment_positions[1] == Vector2i(3, 4)).override_failure_message(
		"BattlePayload.deployment_positions[1] diverged: expected Vector2i(3,4), got %s" % str(lo.deployment_positions[1])
	).is_true()

	assert_bool(lo.deployment_positions.has(2)).override_failure_message(
		"BattlePayload.deployment_positions missing key 2 after round-trip."
	).is_true()
	assert_bool(lo.deployment_positions[2] == Vector2i(5, 6)).override_failure_message(
		"BattlePayload.deployment_positions[2] diverged: expected Vector2i(5,6), got %s" % str(lo.deployment_positions[2])
	).is_true()

	assert_bool(lo.deployment_positions.has(3)).override_failure_message(
		"BattlePayload.deployment_positions missing key 3 after round-trip."
	).is_true()
	assert_bool(lo.deployment_positions[3] == Vector2i(7, 8)).override_failure_message(
		"BattlePayload.deployment_positions[3] diverged: expected Vector2i(7,8), got %s" % str(lo.deployment_positions[3])
	).is_true()

	# battle_start_effects — nested Resource array (2 elements)
	assert_int(lo.battle_start_effects.size()).override_failure_message(
		"BattlePayload.battle_start_effects.size() diverged: expected 2, got %d" % lo.battle_start_effects.size()
	).is_equal(2)

	var el0: Resource = lo.battle_start_effects[0] as Resource
	assert_bool(el0 is BattleStartEffect).override_failure_message(
		("BattlePayload.battle_start_effects[0] is not BattleStartEffect after round-trip"
		+ " — typed Array element type may not be preserved by ResourceSaver.")
	).is_true()
	var bse0: BattleStartEffect = el0 as BattleStartEffect
	assert_str(bse0.effect_id).override_failure_message(
		"BattlePayload.battle_start_effects[0].effect_id diverged: expected 'effect_alpha', got '%s'" % bse0.effect_id
	).is_equal("effect_alpha")
	assert_int(bse0.target_faction).override_failure_message(
		"BattlePayload.battle_start_effects[0].target_faction diverged: expected 1, got %d" % bse0.target_faction
	).is_equal(1)
	assert_int(bse0.value).override_failure_message(
		"BattlePayload.battle_start_effects[0].value diverged: expected 50, got %d" % bse0.value
	).is_equal(50)

	var el1: Resource = lo.battle_start_effects[1] as Resource
	assert_bool(el1 is BattleStartEffect).override_failure_message(
		"BattlePayload.battle_start_effects[1] is not BattleStartEffect after round-trip."
	).is_true()
	var bse1: BattleStartEffect = el1 as BattleStartEffect
	assert_str(bse1.effect_id).override_failure_message(
		"BattlePayload.battle_start_effects[1].effect_id diverged: expected 'effect_beta', got '%s'" % bse1.effect_id
	).is_equal("effect_beta")
	assert_int(bse1.target_faction).override_failure_message(
		"BattlePayload.battle_start_effects[1].target_faction diverged: expected 2, got %d" % bse1.target_faction
	).is_equal(2)
	assert_int(bse1.value).override_failure_message(
		"BattlePayload.battle_start_effects[1].value diverged: expected 75, got %d" % bse1.value
	).is_equal(75)

	# victory_conditions — nested Resource
	assert_bool(lo.victory_conditions is VictoryConditions).override_failure_message(
		"BattlePayload.victory_conditions is not VictoryConditions after round-trip."
	).is_true()
	var vc: VictoryConditions = lo.victory_conditions as VictoryConditions
	assert_int(vc.primary_condition_type).override_failure_message(
		"BattlePayload.victory_conditions.primary_condition_type diverged: expected 3, got %d" % vc.primary_condition_type
	).is_equal(3)
	assert_bool(vc.target_unit_ids == PackedInt64Array([501, 502, 503])).override_failure_message(
		"BattlePayload.victory_conditions.target_unit_ids diverged: expected [501,502,503], got %s" % str(vc.target_unit_ids)
	).is_true()


## AC-3: ChapterResult round-trip — enum DRAW (int 1), Array[String] flags.
func test_chapter_result_roundtrip() -> void:
	# Arrange
	var original: ChapterResult = _make_populated_chapter_result()
	var tmp_path: String = _make_tmp_path("chapter_result")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is ChapterResult).override_failure_message(
		"Loaded resource is not ChapterResult."
	).is_true()
	var lo: ChapterResult = loaded as ChapterResult

	assert_str(lo.chapter_id).override_failure_message(
		"ChapterResult.chapter_id diverged: expected 'ch_02_관도', got '%s'" % lo.chapter_id
	).is_equal("ch_02_관도")

	assert_int(lo.outcome).override_failure_message(
		"ChapterResult.outcome diverged: expected Result.DRAW (%d), got %d" % [BattleOutcome.Result.DRAW, lo.outcome]
	).is_equal(BattleOutcome.Result.DRAW)

	assert_str(lo.branch_triggered).override_failure_message(
		"ChapterResult.branch_triggered diverged: expected 'branch_zhang_fei_joins', got '%s'" % lo.branch_triggered
	).is_equal("branch_zhang_fei_joins")

	assert_int(lo.flags_to_set.size()).override_failure_message(
		"ChapterResult.flags_to_set.size() diverged: expected 2, got %d" % lo.flags_to_set.size()
	).is_equal(2)
	assert_str(lo.flags_to_set[0]).override_failure_message(
		"ChapterResult.flags_to_set[0] diverged: expected 'saved_liu_bei', got '%s'" % lo.flags_to_set[0]
	).is_equal("saved_liu_bei")
	assert_str(lo.flags_to_set[1]).override_failure_message(
		"ChapterResult.flags_to_set[1] diverged: expected 'met_zhang_fei', got '%s'" % lo.flags_to_set[1]
	).is_equal("met_zhang_fei")


## AC-4: InputContext round-trip — primitives only (Vector2i, int, int).
func test_input_context_roundtrip() -> void:
	# Arrange
	var original: InputContext = _make_populated_input_context()
	var tmp_path: String = _make_tmp_path("input_context")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is InputContext).override_failure_message(
		"Loaded resource is not InputContext."
	).is_true()
	var lo: InputContext = loaded as InputContext

	assert_bool(lo.target_coord == Vector2i(5, 7)).override_failure_message(
		"InputContext.target_coord diverged: expected Vector2i(5,7), got %s" % str(lo.target_coord)
	).is_true()

	assert_int(lo.target_unit_id).override_failure_message(
		"InputContext.target_unit_id diverged: expected 42, got %d" % lo.target_unit_id
	).is_equal(42)

	assert_int(lo.source_device).override_failure_message(
		"InputContext.source_device diverged: expected 2, got %d" % lo.source_device
	).is_equal(2)


## VictoryConditions standalone round-trip — PROVISIONAL shape as-is.
## Shape is locked by future Grid Battle ADR; we test what exists now.
func test_victory_conditions_roundtrip() -> void:
	# Arrange
	var original: VictoryConditions = _make_populated_victory_conditions()
	var tmp_path: String = _make_tmp_path("victory_conditions")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is VictoryConditions).override_failure_message(
		"Loaded resource is not VictoryConditions."
	).is_true()
	var lo: VictoryConditions = loaded as VictoryConditions

	assert_int(lo.primary_condition_type).override_failure_message(
		"VictoryConditions.primary_condition_type diverged: expected 3, got %d" % lo.primary_condition_type
	).is_equal(3)

	assert_bool(lo.target_unit_ids == PackedInt64Array([501, 502, 503])).override_failure_message(
		"VictoryConditions.target_unit_ids diverged: expected [501,502,503], got %s" % str(lo.target_unit_ids)
	).is_true()


## BattleStartEffect standalone round-trip — PROVISIONAL shape as-is.
## Shape is locked by future Grid Battle ADR; we test what exists now.
func test_battle_start_effect_roundtrip() -> void:
	# Arrange
	var original: BattleStartEffect = _make_populated_battle_start_effect_a()
	var tmp_path: String = _make_tmp_path("battle_start_effect")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is BattleStartEffect).override_failure_message(
		"Loaded resource is not BattleStartEffect."
	).is_true()
	var lo: BattleStartEffect = loaded as BattleStartEffect

	assert_str(lo.effect_id).override_failure_message(
		"BattleStartEffect.effect_id diverged: expected 'effect_alpha', got '%s'" % lo.effect_id
	).is_equal("effect_alpha")

	assert_int(lo.target_faction).override_failure_message(
		"BattleStartEffect.target_faction diverged: expected 1, got %d" % lo.target_faction
	).is_equal(1)

	assert_int(lo.value).override_failure_message(
		"BattleStartEffect.value diverged: expected 50, got %d" % lo.value
	).is_equal(50)


## AC-5: BattleOutcome.Result enum ordering regression test (TR-save-load-005).
## Three separate round-trips confirm integer representation WIN=0, DRAW=1, LOSS=2
## is preserved by ResourceSaver. Fails if enum is ever reordered without a migration.
func test_battle_outcome_enum_ordering_preserves_integer_values() -> void:
	# Arrange — three instances, one per enum value
	var win_outcome := BattleOutcome.new()
	win_outcome.result = BattleOutcome.Result.WIN
	var draw_outcome := BattleOutcome.new()
	draw_outcome.result = BattleOutcome.Result.DRAW
	var loss_outcome := BattleOutcome.new()
	loss_outcome.result = BattleOutcome.Result.LOSS

	var win_path: String = _make_tmp_path("enum_win")
	var draw_path: String = _make_tmp_path("enum_draw")
	var loss_path: String = _make_tmp_path("enum_loss")

	# Act
	var loaded_win: Resource = _save_and_load(win_outcome, win_path)
	var loaded_draw: Resource = _save_and_load(draw_outcome, draw_path)
	var loaded_loss: Resource = _save_and_load(loss_outcome, loss_path)

	if loaded_win == null or loaded_draw == null or loaded_loss == null:
		return

	# Assert — WIN must be 0, DRAW must be 1, LOSS must be 2
	assert_int((loaded_win as BattleOutcome).result).override_failure_message(
		("BattleOutcome.Result.WIN should serialize/deserialize as integer 0."
		+ " Enum reordering detected — add migration entry and bump schema_version per TR-save-load-005.")
	).is_equal(0)

	assert_int((loaded_draw as BattleOutcome).result).override_failure_message(
		("BattleOutcome.Result.DRAW should serialize/deserialize as integer 1."
		+ " Enum reordering detected — add migration entry and bump schema_version per TR-save-load-005.")
	).is_equal(1)

	assert_int((loaded_loss as BattleOutcome).result).override_failure_message(
		("BattleOutcome.Result.LOSS should serialize/deserialize as integer 2."
		+ " Enum reordering detected — add migration entry and bump schema_version per TR-save-load-005.")
	).is_equal(2)


## AC-6: BattleOutcome empty boundary round-trip.
## Empty PackedInt64Arrays and empty String must survive without null-vs-empty drift.
func test_battle_outcome_empty_boundary_roundtrip() -> void:
	# Arrange — all fields at empty/zero state
	var original := BattleOutcome.new()
	original.result = BattleOutcome.Result.LOSS
	original.chapter_id = ""
	original.final_round = 0
	original.surviving_units = PackedInt64Array()
	original.defeated_units = PackedInt64Array()
	original.is_abandon = false
	var tmp_path: String = _make_tmp_path("battle_outcome_empty")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is BattleOutcome).override_failure_message(
		"Loaded resource is not BattleOutcome (empty boundary)."
	).is_true()
	var lo: BattleOutcome = loaded as BattleOutcome

	# Empty String must not become null
	assert_str(lo.chapter_id).override_failure_message(
		("BattleOutcome.chapter_id empty-boundary drift: expected '', got '%s'."
		+ " Null-vs-empty String drift detected.") % lo.chapter_id
	).is_equal("")

	# Empty PackedInt64Array must not become null and must have size 0
	assert_bool(lo.surviving_units != null).override_failure_message(
		"BattleOutcome.surviving_units became null after round-trip — expected empty PackedInt64Array."
	).is_true()
	assert_bool(lo.surviving_units is PackedInt64Array).override_failure_message(
		"BattleOutcome.surviving_units lost its PackedInt64Array type after round-trip."
	).is_true()
	assert_int(lo.surviving_units.size()).override_failure_message(
		"BattleOutcome.surviving_units.size() diverged: expected 0, got %d. Empty-array drift." % lo.surviving_units.size()
	).is_equal(0)

	assert_bool(lo.defeated_units != null).override_failure_message(
		"BattleOutcome.defeated_units became null after round-trip — expected empty PackedInt64Array."
	).is_true()
	assert_bool(lo.defeated_units is PackedInt64Array).override_failure_message(
		"BattleOutcome.defeated_units lost its PackedInt64Array type after round-trip."
	).is_true()
	assert_int(lo.defeated_units.size()).override_failure_message(
		"BattleOutcome.defeated_units.size() diverged: expected 0, got %d. Empty-array drift." % lo.defeated_units.size()
	).is_equal(0)
