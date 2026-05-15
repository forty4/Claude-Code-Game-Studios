## chapter_visuals_verb_feedback_test.gd
##
## Session-15 verb-feedback overlays in ChapterVisuals:
##   - set_ambush_target_tiles / set_charge_ready_coord store the value
##     and request a redraw so the new overlay appears next frame
##   - Empty / sentinel inputs clear the overlay
##   - The setters are independent of selection / movement / attack overlays
##
## Mirrors chapter_visuals_hero_accent_test.gd setup pattern.
extends GdUnitTestSuite

const ChapterVisualsScript: GDScript = preload("res://src/feature/battle_scene/chapter_visuals.gd")


func _new_visuals() -> ChapterVisuals:
	var cv: ChapterVisuals = ChapterVisualsScript.new()
	auto_free(cv)
	return cv


# ─── Ambush overlay setter ───────────────────────────────────────────────────


func test_set_ambush_target_tiles_stores_array() -> void:
	# Setter accepts a PackedVector2Array and exposes it for the next draw
	# pass via the private field (which the _draw method reads).
	var cv: ChapterVisuals = _new_visuals()
	var tiles: PackedVector2Array = PackedVector2Array([Vector2(3, 2), Vector2(2, 3)])
	cv.set_ambush_target_tiles(tiles)
	assert_int(cv._ambush_target_tiles.size()).is_equal(2)
	assert_vector(cv._ambush_target_tiles[0]).is_equal(Vector2(3, 2))


func test_set_ambush_target_tiles_empty_clears_overlay() -> void:
	# Passing an empty array clears the prior overlay so previously-eligible
	# tiles (e.g., from the prior selected unit) don't linger.
	var cv: ChapterVisuals = _new_visuals()
	cv.set_ambush_target_tiles(PackedVector2Array([Vector2(3, 2)]))
	cv.set_ambush_target_tiles(PackedVector2Array())
	assert_int(cv._ambush_target_tiles.size()).is_equal(0)


# ─── Charge halo setter ──────────────────────────────────────────────────────


func test_set_charge_ready_coord_stores_value() -> void:
	# Setter accepts the attacker's tile coord and exposes it for _draw to
	# render the cyan halo.
	var cv: ChapterVisuals = _new_visuals()
	cv.set_charge_ready_coord(Vector2i(4, 7))
	assert_int(cv._charge_ready_coord.x).is_equal(4)
	assert_int(cv._charge_ready_coord.y).is_equal(7)


func test_set_charge_ready_coord_sentinel_clears_halo() -> void:
	# Vector2i(-1, -1) is the canonical "no halo" sentinel, mirroring the
	# pattern for _selected_coord / _active_turn_coord.
	var cv: ChapterVisuals = _new_visuals()
	cv.set_charge_ready_coord(Vector2i(4, 7))
	cv.set_charge_ready_coord(Vector2i(-1, -1))
	assert_int(cv._charge_ready_coord.x).is_equal(-1)
	assert_int(cv._charge_ready_coord.y).is_equal(-1)


func test_set_charge_ready_coord_idempotent_same_coord() -> void:
	# Setting the same coord twice should not throw (the early-return guard
	# inside the setter prevents redundant queue_redraw). Verifies the
	# guard does not mutate state.
	var cv: ChapterVisuals = _new_visuals()
	cv.set_charge_ready_coord(Vector2i(4, 7))
	cv.set_charge_ready_coord(Vector2i(4, 7))
	assert_int(cv._charge_ready_coord.x).is_equal(4)
	assert_int(cv._charge_ready_coord.y).is_equal(7)


# ─── Overlay independence ────────────────────────────────────────────────────


func test_ambush_overlay_independent_from_attackable_set() -> void:
	# The two setters do not touch each other's state — set ambush, verify
	# attackable_tiles remained empty, and vice versa.
	var cv: ChapterVisuals = _new_visuals()
	cv.set_ambush_target_tiles(PackedVector2Array([Vector2(3, 2)]))
	assert_int(cv._attackable_tiles.size()).is_equal(0)
	cv.set_attackable_tiles(PackedVector2Array([Vector2(5, 5)]))
	assert_int(cv._ambush_target_tiles.size()).is_equal(1)


func test_charge_halo_independent_from_selection() -> void:
	# Charge halo and selection are separate channels — both can be live at
	# the same time (the player selects a charge-ready CAVALRY).
	var cv: ChapterVisuals = _new_visuals()
	cv.set_selected_coord(Vector2i(2, 2))
	cv.set_charge_ready_coord(Vector2i(2, 2))
	assert_int(cv._selected_coord.x).is_equal(2)
	assert_int(cv._charge_ready_coord.x).is_equal(2)
	# Clearing selection does NOT clear the halo (caller owns the lifetime).
	cv.set_selected_coord(Vector2i(-1, -1))
	assert_int(cv._charge_ready_coord.x).is_equal(2)
