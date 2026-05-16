## chapter_visuals_terrain_glyph_test.gd
##
## Session-47 — coverage for the terrain glyph dictionary + smoke that the
## draw helper doesn't crash on any terrain type (including unknown values).
##
## Pre-S47 windowed users couldn't distinguish HILLS / FOREST / BRIDGE /
## ROAD at a glance — the muted earth palette read uniformly. S47 adds a
## semi-transparent Hanja glyph (森丘山河橋城道火) on each non-PLAINS tile.
##
## Coverage:
##   - The terrain glyph dictionary maps all 8 non-PLAINS terrain types
##   - PLAINS (0) has no glyph (intentional: default state needs no mark)
##   - Each glyph color tier is authored (DARK for light tiles, BRIGHT
##     for dark tiles)
##   - _draw_terrain_glyph helper smokes cleanly for terrain types 0..8
##     (PLAINS no-op + 8 authored + unknown fall-through)
extends GdUnitTestSuite


const _CHAPTER_VISUALS_SCRIPT: String = "res://src/feature/battle_scene/chapter_visuals.gd"


var _visuals: Node = null


func before_test() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	_visuals = script.new()
	get_tree().root.add_child(_visuals)
	await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(_visuals):
		get_tree().root.remove_child(_visuals)
		_visuals.free()
	_visuals = null


# ─── Dictionary coverage ─────────────────────────────────────────────────────


func test_terrain_glyph_dict_covers_all_non_plains_terrain_types() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var glyphs: Dictionary = script.get("_TERRAIN_GLYPH_BY_TYPE") as Dictionary
	# Per terrain_cost.gd enum: 0 PLAINS / 1 FOREST / 2 HILLS / 3 MOUNTAIN /
	# 4 RIVER / 5 BRIDGE / 6 FORTRESS_WALL / 7 ROAD / 8 FIRE
	for terrain_type: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		assert_bool(glyphs.has(terrain_type)).override_failure_message(
			"S47: _TERRAIN_GLYPH_BY_TYPE missing entry for terrain_type %d" % terrain_type
		).is_true()
		var glyph: String = glyphs[terrain_type]
		assert_int(glyph.length()).override_failure_message(
			"S47: terrain_type %d glyph must be a single Hanja char (got '%s')"
				% [terrain_type, glyph]
		).is_equal(1)


func test_plains_has_no_glyph_entry_by_design() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var glyphs: Dictionary = script.get("_TERRAIN_GLYPH_BY_TYPE") as Dictionary
	# PLAINS (0) is the default state — no glyph keeps the grid readable.
	assert_bool(glyphs.has(0)).override_failure_message(
		"S47: PLAINS (0) must NOT have a glyph (it's the default state)"
	).is_false()


func test_terrain_glyph_color_dict_covers_all_glyph_types() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var glyphs: Dictionary = script.get("_TERRAIN_GLYPH_BY_TYPE") as Dictionary
	var colors: Dictionary = script.get("_TERRAIN_GLYPH_COLOR_BY_TYPE") as Dictionary
	for terrain_type: int in glyphs.keys():
		assert_bool(colors.has(terrain_type)).override_failure_message(
			"S47: _TERRAIN_GLYPH_COLOR_BY_TYPE missing color tier for terrain_type %d"
				% terrain_type
		).is_true()


# ─── Smoke: helper doesn't crash on any input ────────────────────────────────


## The draw helper runs inside _draw() — to smoke without rendering, just
## call it directly and verify no error / no crash. Terrain types 0..8 +
## an unknown 99 to exercise the fall-through path.
func test_draw_terrain_glyph_smokes_for_all_terrain_types() -> void:
	var rect: Rect2 = Rect2(Vector2(0, 0), Vector2(64, 64))
	# This test passes if the loop completes without crash. Asserting after
	# is just to anchor the test as having a meaningful expectation.
	for terrain_type: int in [0, 1, 2, 3, 4, 5, 6, 7, 8, 99]:
		_visuals._draw_terrain_glyph(rect, terrain_type)
	assert_bool(true).is_true()
