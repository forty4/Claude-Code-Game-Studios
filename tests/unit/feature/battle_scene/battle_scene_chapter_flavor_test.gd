## battle_scene_chapter_flavor_test.gd
##
## Covers BattleScene.CHAPTER_FLAVOR completeness + the title-card objective
## line composition. Pre-S39 only ch06-ch08 had flavor entries; ch09 + ch10
## fell through to the "제N장" default with no tagline, breaking the chapter
## intro's narrative read. S39 backfilled the missing entries + added an
## objective line composed from _resolve_victory_condition_label.
##
## Coverage:
##   - CHAPTER_FLAVOR has entries for all 5 production chapters
##   - Each entry has non-empty title + tagline
##   - The S39 objective line composition: "▶  " + resolved condition label
##   - REACH_TILE chapter (ch08) yields the coord-interpolated objective per S37
extends GdUnitTestSuite


const _BATTLE_SCENE_SCRIPT: String = "res://src/feature/battle_scene/battle_scene.gd"

const _EXPECTED_CHAPTER_IDS: Array[String] = [
	# Phase A prequel (황건적~신야).
	"ch01_taoyuan_yellow_turban",
	"ch02_hulao_gate",
	"ch03_xuzhou_rescue",
	"ch04_bowang_slope",
	"ch05_xinye_fire",
	# Main campaign (장판~적벽).
	"ch06_changbanpo",
	"ch07_changban_bridge",
	"ch08_xiakou_outskirts",
	"ch09_chibi_prelude",
	"ch10_chibi_main",
]


var _scene: Node = null


func before_test() -> void:
	var script: GDScript = load(_BATTLE_SCENE_SCRIPT) as GDScript
	_scene = script.new()


func after_test() -> void:
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null


# ─── CHAPTER_FLAVOR audit ────────────────────────────────────────────────────


## S39 backfill: every production chapter must have a flavor entry. The fall-
## through "제N장" default exists for safety but should not be reached for
## any retrofitted production chapter — every retrofitted chapter needs
## narrative framing at intro time.
func test_chapter_flavor_covers_all_production_chapters() -> void:
	var script: GDScript = load(_BATTLE_SCENE_SCRIPT) as GDScript
	var flavor: Dictionary = script.get("CHAPTER_FLAVOR") as Dictionary
	assert_object(flavor).is_not_null()
	for ch_id: String in _EXPECTED_CHAPTER_IDS:
		assert_bool(flavor.has(ch_id)).override_failure_message(
			"S39: CHAPTER_FLAVOR must have entry for '%s' (pre-S39 fell through to default)"
				% ch_id
		).is_true()


func test_each_chapter_flavor_has_nonempty_title_and_tagline() -> void:
	var script: GDScript = load(_BATTLE_SCENE_SCRIPT) as GDScript
	var flavor: Dictionary = script.get("CHAPTER_FLAVOR") as Dictionary
	for ch_id: String in _EXPECTED_CHAPTER_IDS:
		var entry: Dictionary = flavor.get(ch_id, {}) as Dictionary
		var title: String = entry.get("title", "") as String
		var tagline: String = entry.get("tagline", "") as String
		assert_bool(title.is_empty()).override_failure_message(
			"S39: '%s' must have non-empty title (got '%s')" % [ch_id, title]
		).is_false()
		assert_bool(tagline.is_empty()).override_failure_message(
			"S39: '%s' must have non-empty tagline (got '%s')" % [ch_id, tagline]
		).is_false()


# ─── Objective line composition ──────────────────────────────────────────────


## S39 — objective line is composed via _resolve_victory_condition_label so
## the title-card briefing stays in sync with the in-battle UI-GB-08 label.
## REACH_TILE coord interpolation per S37 → objective shows actual target tile.
func test_objective_line_for_reach_tile_chapter_includes_target_coords() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.REACH_TILE
	)
	chapter.victory_conditions.target_unit_ids = PackedInt64Array([0])
	chapter.victory_conditions.target_tile = Vector2i(13, 4)

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	var expected_objective: String = "▶  %s" % String(label)
	assert_str(expected_objective).override_failure_message(
		"S39: REACH_TILE objective composition must be '▶  지정 타일 (13, 4) 도달'"
	).is_equal("▶  지정 타일 (13, 4) 도달")


## S39 — ESCORT chapter (ch07) yields the fixed phrasing per S30.
func test_objective_line_for_escort_chapter_yields_escort_phrasing() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.ESCORT
	)
	chapter.victory_conditions.target_unit_ids = PackedInt64Array([0])

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	var expected_objective: String = "▶  %s" % String(label)
	assert_str(expected_objective).is_equal("▶  호위 + 적 부대 전멸")


## S39 — SURVIVE chapter (ch10) interpolates the round target per S29.
func test_objective_line_for_survive_chapter_includes_round_count() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.victory_conditions = VictoryConditions.new()
	chapter.victory_conditions.primary_condition_type = (
		VictoryConditions.ConditionType.SURVIVE_N_ROUNDS
	)
	chapter.victory_conditions.survive_rounds = 5

	var label: StringName = _scene._resolve_victory_condition_label(chapter)
	var expected_objective: String = "▶  %s" % String(label)
	assert_str(expected_objective).is_equal("▶  5라운드 버티기")


## S39 — ANNIHILATION default (ch06, ch09) yields the legacy phrasing —
## the briefing line still appears (no fall-through to empty).
func test_objective_line_for_annihilation_default_yields_legacy_phrasing() -> void:
	# Null chapter path — same as ANNIHILATION explicit
	var label: StringName = _scene._resolve_victory_condition_label(null)
	var expected_objective: String = "▶  %s" % String(label)
	assert_str(expected_objective).is_equal("▶  적 부대 전멸")
