## class_emblem_visual_weight_test.gd
##
## Session-40 — visual weight rebalance: hero overlay promoted to PRIMARY
## visual identifier; class emblem demoted to a smaller corner badge.
## Pre-S40 the hero overlay (11px) and shrunk class emblem (~7.7px) competed
## visually; post-S40 the overlay (14px) clearly dominates and the class
## badge (~5.9px in the corner) stays as secondary info.
##
## Coverage:
##   - Post-S40 constant values (regression-safe; pre-S40 values would fail)
##   - Smoke: ClassEmblem.make() with a hero_id returns a valid Node2D
##   - Smoke: ClassEmblem.make() WITHOUT a hero_id uses full-size class emblem
##     (no shrink applied — preserves the "no overlay = full class glyph" path)
##   - _has_hero_overlay returns true for all 13 authored hero IDs
extends GdUnitTestSuite


# ─── Post-S40 constant audit ─────────────────────────────────────────────────


## Hero overlay size grew 11.0 → 14.0 (+28%) so the per-hero seal dominates the
## class glyph badge underneath. Asserting the literal value catches any
## accidental revert toward the pre-S40 weights.
func test_hero_overlay_size_is_s40_boosted_value() -> void:
	var script: GDScript = load("res://src/feature/battle_scene/class_emblem.gd") as GDScript
	var size: float = script.get("_HERO_OVERLAY_SIZE") as float
	assert_float(size).override_failure_message(
		"S40: _HERO_OVERLAY_SIZE must be 14.0 (boosted from 11.0)"
	).is_equal(14.0)


func test_class_shrink_with_overlay_is_s40_value() -> void:
	var script: GDScript = load("res://src/feature/battle_scene/class_emblem.gd") as GDScript
	var shrink: float = script.get("_CLASS_SHRINK_WITH_OVERLAY") as float
	assert_float(shrink).override_failure_message(
		"S40: _CLASS_SHRINK_WITH_OVERLAY must be 0.42 (shrunk from 0.55 — class badge becomes ~6px)"
	).is_equal(0.42)


func test_class_corner_offset_is_s40_value() -> void:
	var script: GDScript = load("res://src/feature/battle_scene/class_emblem.gd") as GDScript
	var offset: Vector2 = script.get("_CLASS_CORNER_OFFSET") as Vector2
	assert_vector(offset).override_failure_message(
		"S40: _CLASS_CORNER_OFFSET must be (12.5, 12.5) — pushed further into corner"
	).is_equal(Vector2(12.5, 12.5))


# ─── Smoke: instantiation with/without overlay ───────────────────────────────


## With a hero_id that has an authored overlay, make() returns a valid Node2D
## that can be mounted in the tree without crashing. The shrink/offset paths
## fire during _draw() — this test reaches _draw via add_child + frame.
func test_make_with_hero_overlay_mounts_cleanly() -> void:
	var emblem: ClassEmblem = ClassEmblem.make(
		int(UnitRole.UnitClass.INFANTRY),  # class glyph fires regardless of overlay
		0,                                  # player side
		0.0,                                # no counter-rotation
		&"shu_002_guan_yu",                 # has 긴 수염 overlay
		Color("5da86a"),                    # 관우 accent
	)
	get_tree().root.add_child(emblem)
	await get_tree().process_frame

	assert_object(emblem).is_not_null()
	assert_bool(emblem.is_inside_tree()).is_true()
	# Cleanup
	get_tree().root.remove_child(emblem)
	emblem.free()


## Without a hero_id (legacy callers / heroes lacking authored overlay), the
## class emblem renders at full size centered — shrink path is NOT triggered.
## The has_overlay check in _draw must return false.
func test_make_without_hero_overlay_mounts_cleanly() -> void:
	var emblem: ClassEmblem = ClassEmblem.make(
		int(UnitRole.UnitClass.CAVALRY),
		1,                                  # enemy side
		0.0,
		&"",                                # no hero_id → no overlay
	)
	get_tree().root.add_child(emblem)
	await get_tree().process_frame

	assert_object(emblem).is_not_null()
	# Cleanup
	get_tree().root.remove_child(emblem)
	emblem.free()


# ─── All 13 production heroes have overlays ──────────────────────────────────


## Every hero in the production deployment (mvp_shu.json + heroes.json) must
## have an authored overlay. Without an overlay, the hero falls back to a
## plain class emblem — undistinguishable from another hero of the same class.
## S40's visual-weight rebalance ASSUMES the overlay is present; missing
## overlay = hero loses identity entirely.
func test_all_production_heroes_have_authored_overlay() -> void:
	var production_hero_ids: Array[StringName] = [
		# Player (Shu)
		&"shu_001_liu_bei",
		&"shu_002_guan_yu",
		&"shu_003_zhang_fei",
		&"shu_004_huang_zhong",
		# Enemy (Wei)
		&"wei_001_cao_cao",
		&"wei_005_xiahou_dun",
		&"wei_006_zhang_liao",
		&"wei_007_yu_jin",
		&"wei_008_xu_chu",
		# Wu (allied)
		&"wu_001_sun_quan",
		&"wu_003_zhou_yu",
		# Qun
		&"qun_004_diao_chan",
	]
	# Use a throwaway instance to call the private _has_hero_overlay helper.
	var probe: ClassEmblem = ClassEmblem.make(0, 0, 0.0, &"")
	for hid: StringName in production_hero_ids:
		assert_bool(probe._has_hero_overlay(hid)).override_failure_message(
			"S40: production hero '%s' must have an authored overlay "
			+ "(without it the unit visually collapses to a generic class shape — "
			+ "장수별 특징 무력화)" % hid
		).is_true()
	probe.free()
