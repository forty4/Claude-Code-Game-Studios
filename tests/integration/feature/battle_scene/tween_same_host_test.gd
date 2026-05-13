extends GdUnitTestSuite

## Probe: slide tween + lunge tween, BOTH created from the same HOST node
## (battle_scene in production) targeting the same polygon. This replicates
## the user's production scenario exactly. If callback fails here, we've
## isolated the bug to multi-tween-from-same-host scheduling.

var _host: Node2D = null
var _polygon: Node2D = null


func before_test() -> void:
	_host = Node2D.new()
	_host.name = "HostTestDouble"
	get_tree().root.add_child(_host)

	_polygon = Node2D.new()
	_polygon.name = "Polygon"
	_polygon.position = Vector2(96, 224)
	_host.add_child(_polygon)


func after_test() -> void:
	if is_instance_valid(_host):
		get_tree().root.remove_child(_host)
		_host.free()


## Both slide and lunge created from _host (same node), targeting same polygon.
func test_slide_and_lunge_both_from_same_host_callback_still_fires() -> void:
	var target: Vector2 = Vector2(224, 224)
	var callback_flag: Array = []
	var finished_flag: Array = []

	# Slide — bound to _host (just like production's battle_scene.create_tween())
	var slide: Tween = _host.create_tween()
	slide.tween_property(_polygon, "position", target, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slide.tween_callback(func() -> void:
		callback_flag.append("CB"))
	slide.finished.connect(func() -> void:
		finished_flag.append("FIN"))

	await get_tree().create_timer(0.1).timeout
	var origin: Vector2 = _polygon.position

	# Lunge — also bound to _host. Targets same property.
	var lunge: Tween = _host.create_tween()
	lunge.tween_property(_polygon, "position", origin + Vector2(12, 0), 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge.tween_property(_polygon, "position", origin, 0.075) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(0.75).timeout

	print("[SAME-HOST] callback fired=%d finished fired=%d final=%s" %
		[callback_flag.size(), finished_flag.size(), _polygon.position])

	assert_int(callback_flag.size()).override_failure_message(
		"Same-host slide: tween_callback must fire; fired %d times"
		% callback_flag.size()
	).is_equal(1)
	assert_int(finished_flag.size()).override_failure_message(
		"Same-host slide: finished signal must fire; fired %d times"
		% finished_flag.size()
	).is_equal(1)
	assert_vector(_polygon.position).override_failure_message(
		"Same-host slide: polygon must land at target %s; got %s"
		% [target, _polygon.position]
	).is_equal_approx(target, Vector2(0.5, 0.5))
