extends GdUnitTestSuite

## battle_scene_slide_tween_test.gd
##
## Isolates the slide-tween logic from BattleScene._on_unit_moved without
## requiring full BattleScene setup (which needs scene-tree children that
## a unit test fixture can't satisfy). Verifies:
##   1. Slide tween fires its completion callback.
##   2. Polygon lands at target after slide completes.
##   3. Concurrent competing tween (mimicking attack lunge) does NOT prevent
##      slide from reaching target.

var _holder: Node2D = null  # owner of the slide tween (mimics battle_scene)
var _polygon: Node2D = null
var _label: Label = null

const _MOVE_DURATION: float = 0.6


func before_test() -> void:
	_holder = Node2D.new()
	_holder.name = "TweenHolderTestDouble"
	get_tree().root.add_child(_holder)

	_polygon = Node2D.new()
	_polygon.name = "Unit0_test_hero"
	_polygon.position = Vector2(96, 224)  # tile (1, 3) at TILE_SIZE 64
	_holder.add_child(_polygon)

	# Production polygons carry a NameLabel child — include it so any tween
	# interaction with child Controls surfaces.
	_label = Label.new()
	_label.name = "NameLabel"
	_label.text = "유비"
	_polygon.add_child(_label)


func after_test() -> void:
	if is_instance_valid(_holder):
		get_tree().root.remove_child(_holder)
		_holder.free()


## Mirror of BattleScene._on_unit_moved's slide tween logic (post-fix: dedicated
## sequential Tween with completion callback). Returns the captured callback flag.
func _start_slide(target: Vector2, callback_flag: Array) -> Tween:
	var slide_tween: Tween = _holder.create_tween()
	slide_tween.tween_property(_polygon, "position", target, _MOVE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide_tween.tween_callback(func() -> void:
		callback_flag.append(_polygon.position))
	return slide_tween


## AC-1: slide alone — callback fires, polygon lands at target.
func test_slide_alone_completes_and_callback_fires() -> void:
	var target: Vector2 = Vector2(224, 224)
	var callback_flag: Array = []
	_start_slide(target, callback_flag)

	await get_tree().create_timer(_MOVE_DURATION + 0.15).timeout

	assert_int(callback_flag.size()).override_failure_message(
		"Slide-alone: completion callback must fire exactly once; fired %d times"
		% callback_flag.size()
	).is_equal(1)
	assert_vector(_polygon.position).override_failure_message(
		"Slide-alone: polygon must land at %s; got %s"
		% [target, _polygon.position]
	).is_equal_approx(target, Vector2(0.5, 0.5))


## AC-2: slide + competing lunge (the user's actual scenario). Lunge captures
## an interpolated origin and animates back to it; slide must still complete.
func test_slide_with_concurrent_lunge_completes_to_target() -> void:
	var target: Vector2 = Vector2(224, 224)
	var callback_flag: Array = []
	_start_slide(target, callback_flag)

	# Mid-slide, kick off a competing lunge tween (mirrors damage_applied path).
	await get_tree().create_timer(0.1).timeout
	var origin: Vector2 = _polygon.position
	var lunge_target: Vector2 = origin + Vector2(12, 0)
	var lunge: Tween = _holder.create_tween()
	lunge.tween_property(_polygon, "position", lunge_target, 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.tween_property(_polygon, "position", origin, 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(_MOVE_DURATION + 0.2).timeout

	assert_int(callback_flag.size()).override_failure_message(
		"Slide+lunge: slide callback must still fire exactly once; fired %d times"
		% callback_flag.size()
	).is_equal(1)
	assert_vector(_polygon.position).override_failure_message(
		"Slide+lunge: polygon must still land at %s after slide completes; got %s"
		% [target, _polygon.position]
	).is_equal_approx(target, Vector2(0.5, 0.5))


## AC-3: slide with a SHORTER duration than lunge_total — slide ends first.
## Lunge then writes its values AFTER slide ended. Polygon ends at lunge's
## final value (origin), NOT at slide target.
##
## This documents a scenario we DON'T expect in production (move = 0.6s vs
## lunge total = 0.15s; slide is always longer). If this ever happens it's a
## tuning bug; we capture the expected interaction so a future tuning change
## doesn't surprise us.
func test_slide_shorter_than_lunge_documents_interaction() -> void:
	var target: Vector2 = Vector2(224, 224)
	var callback_flag: Array = []
	# Override duration via direct tween (mimics what happens if MOVE_ANIM_DURATION
	# were tuned shorter than lunge).
	var short_slide: Tween = _holder.create_tween()
	short_slide.tween_property(_polygon, "position", target, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	short_slide.tween_callback(func() -> void:
		callback_flag.append(_polygon.position))

	# Lunge starts before slide ends.
	await get_tree().create_timer(0.02).timeout
	var origin: Vector2 = _polygon.position
	var lunge_target: Vector2 = origin + Vector2(12, 0)
	var lunge: Tween = _holder.create_tween()
	lunge.tween_property(_polygon, "position", lunge_target, 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.tween_property(_polygon, "position", origin, 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.4).timeout

	# Slide callback fires (slide tween completes its property step).
	assert_int(callback_flag.size()).is_equal(1)
	# Polygon ends at lunge's final (origin) because lunge outlasted slide.
	assert_vector(_polygon.position).override_failure_message(
		"Slide<lunge: polygon ends at lunge origin %s, not slide target %s"
		% [origin, target]
	).is_equal_approx(origin, Vector2(1.0, 1.0))
