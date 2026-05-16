## chapter_visuals_terrain_glyph_test.gd
##
## Session-47 / S48 — coverage for the terrain glyph color tier dictionary +
## smoke that the shape-based draw helper doesn't crash on any terrain type.
##
## Pre-S47 windowed users couldn't distinguish HILLS / FOREST / BRIDGE /
## ROAD at a glance — muted earth palette read uniformly. S47 first added
## Hanja glyphs (森丘山河橋城道火); S48 swapped them for primitive shapes
## (3-tree cluster / rolling arches / peak triangle / wavy lines / rails &
## planks / crenellation / dashes / flame) after user feedback "한자를
## 모르겠어" — visual recognition works regardless of locale.
##
## Coverage:
##   - Color tier dict has entries for all 8 non-PLAINS terrain types
##   - PLAINS (0) has no entry (intentional: default state needs no mark)
##   - Color tier is DARK for light-tone tiles (forest/hills/bridge/road/
##     fire) and BRIGHT for dark-tone tiles (mountain/river/fortress)
##   - _draw_terrain_glyph helper smokes cleanly for terrain types 0..8
##     plus unknown fall-through
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


func test_terrain_glyph_color_dict_covers_all_non_plains_terrain_types() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var colors: Dictionary = script.get("_TERRAIN_GLYPH_COLOR_BY_TYPE") as Dictionary
	# Per terrain_cost.gd enum: 0 PLAINS / 1 FOREST / 2 HILLS / 3 MOUNTAIN /
	# 4 RIVER / 5 BRIDGE / 6 FORTRESS_WALL / 7 ROAD / 8 FIRE
	for terrain_type: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		assert_bool(colors.has(terrain_type)).override_failure_message(
			"S48: _TERRAIN_GLYPH_COLOR_BY_TYPE missing color tier for terrain_type %d"
				% terrain_type
		).is_true()


func test_plains_has_no_glyph_color_entry_by_design() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var colors: Dictionary = script.get("_TERRAIN_GLYPH_COLOR_BY_TYPE") as Dictionary
	# PLAINS (0) is the default state — no glyph keeps the grid readable.
	assert_bool(colors.has(0)).override_failure_message(
		"S48: PLAINS (0) must NOT have a glyph color entry (default state)"
	).is_false()


## Sanity-check color tier classification — dark for light-tone tiles
## (forest/hills/bridge/road/fire), bright for dark-tone tiles (mountain/
## river/fortress wall). Catches accidental tier swaps in the color dict.
func test_terrain_glyph_color_tier_classification() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var colors: Dictionary = script.get("_TERRAIN_GLYPH_COLOR_BY_TYPE") as Dictionary
	var dark: Color = script.get("_TERRAIN_GLYPH_DARK") as Color
	var bright: Color = script.get("_TERRAIN_GLYPH_BRIGHT") as Color
	# Light-tone tiles use the dark ink (subtle on warm fills).
	for terrain_type: int in [1, 2, 5, 7, 8]:  # forest, hills, bridge, road, fire
		assert_object(colors[terrain_type]).override_failure_message(
			"S48: terrain_type %d expected DARK tier" % terrain_type
		).is_equal(dark)
	# Dark-tone tiles use the cream tier so the shape reads against near-black.
	for terrain_type: int in [3, 4, 6]:  # mountain, river, fortress
		assert_object(colors[terrain_type]).override_failure_message(
			"S48: terrain_type %d expected BRIGHT tier" % terrain_type
		).is_equal(bright)


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
