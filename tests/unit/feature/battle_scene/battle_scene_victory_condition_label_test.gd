## battle_scene_victory_condition_label_test.gd
##
## Covers BattleScene._resolve_victory_condition_label — the function that
## maps a ChapterDefinition's victory_conditions to the in-battle HUD label
## displayed in UI-GB-08. Pre-S37 the REACH_TILE branch returned a hardcoded
## "특정 위치 도달" (no coordinates); post-S37 interpolates the target_tile
## so the player sees WHERE to go.
##
## Coverage:
##   - null chapter → "적 부대 전멸" default
##   - null victory_conditions → "적 부대 전멸" default
##   - ConditionType.ANNIHILATION explicit → "적 부대 전멸"
##   - ConditionType.SURVIVE_N_ROUNDS → "%d라운드 버티기" with rounds value
##   - ConditionType.ESCORT → "호위 + 적 부대 전멸"
##   - ConditionType.REACH_TILE → "지정 타일 (x, y) 도달" with target coords
extends GdUnitTestSuite


const _BATTLE_SCENE_SCRIPT: String = "res://src/feature/battle_scene/battle_scene.gd"


var _scene: Node = null


func before_test() -> void:
	# Load BattleScene as a script + instantiate just for the resolver call.
	# Avoid mounting the full scene tree — we only need access to the private
	# pure-function helper. _resolve_victory_condition_label has no _ready
	# dependencies, so calling it on a bare instance is safe.
	var script: GDScript = load(_BATTLE_SCENE_SCRIPT) as GDScript
	_scene = script.new()


func after_test() -> void:
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null


# ─── Null / default fall-through paths ───────────────────────────────────────


func test_null_chapter_returns_annihilation_default() -> void:
	var label: StringName = _scene._resolve_victory_condition_label(null)
	assert_str(String(label)).override_failure_message(
		"S37: null chapter must fall through to '적 부대 전멸' default"
	).is_equal("적 부대 전멸")


func test_null_victory_conditions_returns_annihilation_default() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = null

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	assert_str(String(label)).override_failure_message(
		"S37: chapter with null victory_conditions must return '적 부대 전멸'"
	).is_equal("적 부대 전멸")


func test_explicit_annihilation_condition_returns_annihilation_label() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.ANNIHILATION
	)

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	assert_str(String(label)).is_equal("적 부대 전멸")


# ─── SURVIVE_N_ROUNDS — interpolates rounds value ────────────────────────────


func test_survive_n_rounds_interpolates_rounds_value() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.SURVIVE_N_ROUNDS
	)
	chapter.victory_conditions.survive_rounds = 5

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	assert_str(String(label)).override_failure_message(
		"S29: SURVIVE label must interpolate survive_rounds (got '%s')"
			% String(label)
	).is_equal("5라운드 버티기")


# ─── ESCORT — fixed phrasing ─────────────────────────────────────────────────


func test_escort_returns_fixed_phrasing() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.ESCORT
	)
	chapter.victory_conditions.target_unit_ids = PackedInt64Array([0])

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	assert_str(String(label)).is_equal("호위 + 적 부대 전멸")


# ─── REACH_TILE — interpolates target_tile coords (S37 fix) ──────────────────


## Pre-S37 the REACH_TILE arm returned hardcoded "특정 위치 도달" — generic,
## gave the player no information about WHERE to go. Post-S37 the label
## interpolates target_tile.x and target_tile.y. ch03's bridge at [13, 4]
## becomes "지정 타일 (13, 4) 도달".
func test_reach_tile_interpolates_target_coords() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.REACH_TILE
	)
	chapter.victory_conditions.target_unit_ids = PackedInt64Array([0])
	chapter.victory_conditions.target_tile = Vector2i(13, 4)

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	assert_str(String(label)).override_failure_message(
		"S37: REACH_TILE label must interpolate (x, y) — got '%s'" % String(label)
	).is_equal("지정 타일 (13, 4) 도달")


## REACH_TILE with the default Vector2i.ZERO target — still interpolates
## (no special-casing for origin); chapter authors picking [0, 0] as target
## must accept the literal label.
func test_reach_tile_with_zero_target_interpolates_origin() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.REACH_TILE
	)

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	assert_str(String(label)).is_equal("지정 타일 (0, 0) 도달")
