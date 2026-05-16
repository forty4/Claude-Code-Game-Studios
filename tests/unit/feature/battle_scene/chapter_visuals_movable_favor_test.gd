## chapter_visuals_movable_favor_test.gd
##
## Session-55: per-tile favor tint on the movement-range preview overlay.
## set_movable_favors() stores an Int32Array index-aligned with the array
## previously passed to set_movable_tiles(). The _draw loop reads both in
## lockstep and picks a tinted color per tile.
##
## Coverage:
##   - set_movable_favors stores the array
##   - set_movable_tiles clears stale favors (length-mismatch defense)
##   - Empty favors falls back to neutral (no crash, no tint)
##   - Mismatched-length favors fall back to neutral (defensive — array length
##     check inside _draw guards against caller error)
##
## Mirrors chapter_visuals_verb_feedback_test.gd setup pattern.
extends GdUnitTestSuite

const ChapterVisualsScript: GDScript = preload("res://src/feature/battle_scene/chapter_visuals.gd")


func _new_visuals() -> ChapterVisuals:
	var cv: ChapterVisuals = ChapterVisualsScript.new()
	auto_free(cv)
	return cv


# ─── set_movable_favors setter stores the array ──────────────────────────────


func test_set_movable_favors_stores_array() -> void:
	var cv: ChapterVisuals = _new_visuals()
	cv.set_movable_tiles(PackedVector2Array([Vector2(3, 2), Vector2(2, 3), Vector2(4, 2)]))
	cv.set_movable_favors(PackedInt32Array([1, 0, -1]))
	assert_int(cv._movable_favors.size()).is_equal(3)
	assert_int(cv._movable_favors[0]).is_equal(1)
	assert_int(cv._movable_favors[1]).is_equal(0)
	assert_int(cv._movable_favors[2]).is_equal(-1)


# ─── set_movable_tiles clears stale favors ──────────────────────────────────


func test_set_movable_tiles_clears_stale_favors() -> void:
	# Selection change pushes new tiles before favors. If the prior selection's
	# favor array lingers with a different length, the _draw loop would read
	# out-of-bounds. Setter MUST defensively clear.
	var cv: ChapterVisuals = _new_visuals()
	cv.set_movable_tiles(PackedVector2Array([Vector2(3, 2), Vector2(2, 3)]))
	cv.set_movable_favors(PackedInt32Array([1, -1]))
	# New selection — different tile set; favors not yet repushed.
	cv.set_movable_tiles(PackedVector2Array([Vector2(5, 5)]))
	assert_int(cv._movable_favors.size()).is_equal(0)


# ─── Empty favors clears overlay tint ───────────────────────────────────────


func test_set_movable_favors_empty_clears_overlay() -> void:
	var cv: ChapterVisuals = _new_visuals()
	cv.set_movable_tiles(PackedVector2Array([Vector2(3, 2)]))
	cv.set_movable_favors(PackedInt32Array([1]))
	cv.set_movable_favors(PackedInt32Array())
	assert_int(cv._movable_favors.size()).is_equal(0)
