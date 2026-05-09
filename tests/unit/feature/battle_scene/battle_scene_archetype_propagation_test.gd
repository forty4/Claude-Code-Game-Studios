## Tests for sprint-13 S13-12 — BattleUnit.archetype field separation from
## fate-counter `tag` field.
##
## Story: production/sprints/sprint-13.md S13-12 (BUG #2 — architectural smell).
## Root cause: grid_battle_controller.gd:457 was reading `u.tag` as the archetype
## source, conflating fate-counter role (`tank`/`assassin`/`boss`) with AI
## archetype dispatch bucket (`aggressor`/`skirmisher`/`holder`/`coordinator`).
## When a chapter mapped archetype=coordinator → tag=boss for fate tracking, the
## conflated read leaked `boss` into AISystem and triggered EC-AI-4 unknown-
## archetype warning (×4+ per battle).
##
## Acceptance criteria coverage:
##   AC-2: BattleUnit.archetype declared @export with default `&"aggressor"`
##         → tests 1 + 2
##   AC-3: battle_scene._make_battle_unit + _build_battle_units_from_chapter
##         populates archetype from chapter roster (player units default aggressor)
##         → tests 3 + 4 + 6 + 7
##   AC-4: grid_battle_controller snapshot reads u.archetype field, NOT u.tag
##         → test 8
##   AC-6: archetype propagation through 5+ chapter scenarios + fallback default
##         → test 4 (5 parametric cases) + test 5 (fallback)
##
## AC-1 (headless 0 warnings) is verified outside this test by stderr grep.
## AC-5 (full 1280-test suite preserved) is verified by the full-suite run.

extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")
const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _instantiate_battle_scene() -> BattleScene:
	# BattleScene extends Node2D. Instantiate without adding to tree — the
	# private helpers we exercise (_make_battle_unit + _build_battle_units_from_chapter)
	# are pure-data and do not touch scene-tree nodes.
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


## Constructs a minimal ChapterDefinition with an enemy_roster matching the
## given archetype list. Each entry uses a unique unit_id and shared hero_id
## (validation is out of scope here — the helper exercises archetype propagation).
func _make_test_chapter(roster: Array[Dictionary]) -> ChapterDefinition:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.player_unit_ids = PackedInt64Array([0, 1])
	chapter.deployment_positions_default = {}
	chapter.enemy_roster = roster
	return chapter


func _setup_minimal_controller_with_roster(roster: Array[BattleUnit]) -> GridBattleController:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	auto_free(hp_controller)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	controller.setup(roster, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)
	return controller


# ─── AC-2: BattleUnit.archetype field declarations ───────────────────────────

func test_battle_unit_archetype_default_is_aggressor() -> void:
	# Arrange / Act — fresh BattleUnit; no field assignment.
	var unit: BattleUnit = BattleUnit.new()

	# Assert — default per AC-2 + ADR-0019 §4 dispatch table fallback.
	assert_str(String(unit.archetype)).is_equal("aggressor")


func test_battle_unit_archetype_is_settable_to_all_four_dispatch_values() -> void:
	# AC-2 cross-check: the 4 archetypes that AISystem dispatches without a
	# warning fallback per ADR-0019 §4 must all be valid assignments.
	var values: Array[StringName] = [&"aggressor", &"skirmisher", &"holder", &"coordinator"]

	for v: StringName in values:
		var unit: BattleUnit = BattleUnit.new()
		unit.archetype = v
		assert_str(String(unit.archetype)).override_failure_message(
			"BattleUnit.archetype must accept %s as a valid value" % String(v)
		).is_equal(String(v))


# ─── AC-3: _make_battle_unit + _build_battle_units_from_chapter populate ─────

func test_make_battle_unit_assigns_archetype_param_to_resource_field() -> void:
	# Arrange
	var scene: BattleScene = _instantiate_battle_scene()

	# Act — call private helper directly with a non-default archetype.
	var unit: BattleUnit = scene._make_battle_unit(7, &"wei_005_xiahou_dun", false, Vector2i(4, 2), &"", &"holder")

	# Assert — archetype param flowed into the resource field, distinct from tag.
	assert_str(String(unit.archetype)).is_equal("holder")
	assert_str(String(unit.tag)).is_equal("")


# AC-3 + AC-6: 5 chapter scenarios covering the 4 dispatch archetypes + fallback.
# Cases array typed Array[Dictionary] per .claude/rules/godot-4x-gotchas.md G-16.
func test_build_battle_units_propagates_archetype_through_5_chapter_scenarios() -> void:
	# Arrange — 5 chapter scenarios, each isolating one enemy archetype and
	# asserting BattleUnit.archetype matches the chapter roster value (or default).
	var cases: Array[Dictionary] = [
		{"label": "single aggressor enemy",   "roster_archetype": "aggressor",   "expected_archetype": "aggressor"},
		{"label": "single skirmisher enemy",  "roster_archetype": "skirmisher",  "expected_archetype": "skirmisher"},
		{"label": "single holder enemy",      "roster_archetype": "holder",      "expected_archetype": "holder"},
		{"label": "single coordinator enemy", "roster_archetype": "coordinator", "expected_archetype": "coordinator"},
		{"label": "explicit aggressor entry", "roster_archetype": "aggressor",   "expected_archetype": "aggressor"},
	]
	var scene: BattleScene = _instantiate_battle_scene()

	for case: Dictionary in cases:
		var roster: Array[Dictionary] = [
			{"unit_id": 100, "hero_id": "wei_001_cao_cao", "archetype": case["roster_archetype"] as String},
		]
		var chapter: ChapterDefinition = _make_test_chapter(roster)

		# Act
		var built: Array[BattleUnit] = scene._build_battle_units_from_chapter(chapter)

		# Assert — 2 player units (defaulting to aggressor) + 1 enemy = 3 units.
		# The enemy is at index 2 (player units occupy 0 + 1).
		assert_int(built.size()).override_failure_message(
			"Case '%s': expected 3 units (2 player + 1 enemy), got %d" % [case["label"] as String, built.size()]
		).is_equal(3)
		assert_str(String(built[2].archetype)).override_failure_message(
			"Case '%s': enemy archetype mismatch" % (case["label"] as String)
		).is_equal(case["expected_archetype"] as String)


# AC-6 fallback: roster entry missing the archetype key falls back to default.
func test_build_battle_units_archetype_falls_back_to_aggressor_when_missing() -> void:
	# Arrange — enemy entry omits the "archetype" key entirely.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_test_chapter([
		{"unit_id": 200, "hero_id": "wei_001_cao_cao"},  # NO archetype key
	])

	# Act
	var built: Array[BattleUnit] = scene._build_battle_units_from_chapter(chapter)

	# Assert — _build_battle_units_from_chapter applies "aggressor" default per
	# d.get("archetype", "aggressor"); BattleUnit field also has &"aggressor"
	# default, so a missing key cascades to a known-good archetype.
	assert_int(built.size()).is_equal(3)
	assert_str(String(built[2].archetype)).is_equal("aggressor")


# AC-3 player-side: player units default archetype to &"aggressor" per S13-12
# implementation (chapter fixtures do not currently author player archetypes).
func test_build_battle_units_player_units_default_archetype_to_aggressor() -> void:
	# Arrange
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_test_chapter([
		{"unit_id": 100, "hero_id": "wei_001_cao_cao", "archetype": "skirmisher"},
	])

	# Act
	var built: Array[BattleUnit] = scene._build_battle_units_from_chapter(chapter)

	# Assert — player units (index 0 + 1) carry the &"aggressor" default; only
	# the enemy unit (index 2) carries the chapter-authored archetype.
	assert_str(String(built[0].archetype)).override_failure_message(
		"Player unit 0 must default to aggressor"
	).is_equal("aggressor")
	assert_str(String(built[1].archetype)).override_failure_message(
		"Player unit 1 must default to aggressor"
	).is_equal("aggressor")
	assert_str(String(built[2].archetype)).is_equal("skirmisher")


# Sanity check: coordinator archetype + tag=boss fate mapping coexist without
# overwriting each other. This is the bug's actual reproduction scenario.
func test_coordinator_archetype_preserved_when_tag_maps_to_boss() -> void:
	# Arrange — chapter has a single coordinator-archetyped enemy.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_test_chapter([
		{"unit_id": 100, "hero_id": "wei_008_xu_chu", "archetype": "coordinator"},
	])

	# Act
	var built: Array[BattleUnit] = scene._build_battle_units_from_chapter(chapter)

	# Assert — the enemy carries archetype=coordinator (for AISystem dispatch)
	# AND tag=boss (for fate-counter detection) on the SAME BattleUnit. Pre-S13-12
	# the conflated tag-as-archetype read would surface "boss" to AISystem.
	var enemy: BattleUnit = built[2]
	assert_str(String(enemy.archetype)).override_failure_message(
		"AISystem dispatch must see archetype=coordinator (was leaking as tag=boss pre-fix)"
	).is_equal("coordinator")
	assert_str(String(enemy.tag)).override_failure_message(
		"Fate-counter must still see tag=boss (coordinator → boss mapping preserved)"
	).is_equal("boss")


# ─── AC-4: grid_battle_controller snapshot reads u.archetype, NOT u.tag ──────

func test_make_battle_state_snapshot_reads_archetype_field_not_tag() -> void:
	# Arrange — synthesize a BattleUnit where archetype != tag. The fix at
	# grid_battle_controller.gd:457 must surface archetype to the snapshot dict
	# (the field that AISystem reads); tag is preserved separately at "tag" key.
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = 5
	unit.archetype = &"holder"   # AI dispatch bucket
	unit.tag = &"boss"           # Fate-counter role
	unit.position = Vector2i(3, 3)
	unit.side = 1
	var roster: Array[BattleUnit] = [unit]
	var controller: GridBattleController = _setup_minimal_controller_with_roster(roster)

	# Act — invoke the private snapshot builder directly. GDScript "_" prefix is
	# a convention; tests may exercise it without enforcement (no encapsulation
	# violation per ADR-0019 §Decision §Snapshot Form public-shape contract).
	var snap: BattleStateSnapshot = controller._make_battle_state_snapshot()

	# Assert — snapshot dict for unit_id=5 has archetype="holder" (the field),
	# not "boss" (the tag). Pre-S13-12 this would assert "boss" because line 457
	# read `u.tag if u.tag != &"" else &"aggressor"`.
	assert_int(snap.units.size()).is_equal(1)
	var unit_snap: Dictionary = snap.units[0] as Dictionary
	assert_str(String(unit_snap.get("archetype", &"") as StringName)).override_failure_message(
		"Snapshot must source archetype from BattleUnit.archetype field (was reading u.tag pre-S13-12)"
	).is_equal("holder")
	# tag still flows through at the "tag" key (downstream fate consumers).
	assert_str(String(unit_snap.get("tag", &"") as StringName)).is_equal("boss")
