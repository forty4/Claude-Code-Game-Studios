## story_beat_screen_test.gd
##
## Verifies StoryBeatScreen sequencing: present() shows beat 0, advance() walks
## forward one beat at a time, sequence_finished fires exactly once after the
## last beat (and the screen hides), present([]) finishes immediately, and
## advance() is idempotent past the end. Pure sequencing — no input simulation.
extends GdUnitTestSuite


var _screen: StoryBeatScreen = null


func before_test() -> void:
	_screen = StoryBeatScreen.new()
	get_tree().root.add_child(_screen)
	await get_tree().process_frame  # let _ready() build the widget set


func after_test() -> void:
	if is_instance_valid(_screen):
		get_tree().root.remove_child(_screen)
		# free() (not queue_free) per G-6 — the StoryBeatScreen subtree holds no
		# external Callable references, so immediate free avoids leaving orphans
		# for GdUnit4's between-test/after_test detector.
		_screen.free()
	_screen = null


func _beats(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append({"title": "Beat %d" % i, "body": "Body text for beat %d." % i})
	return out


func test_present_shows_first_beat() -> void:
	_screen.present(_beats(3))
	assert_int(_screen.get_beat_count()).is_equal(3)
	assert_int(_screen.get_current_index()).is_equal(0)
	assert_bool(_screen.visible).is_true()


func test_advance_walks_beats_in_order() -> void:
	_screen.present(_beats(3))
	_screen.advance()
	assert_int(_screen.get_current_index()).is_equal(1)
	_screen.advance()
	assert_int(_screen.get_current_index()).is_equal(2)
	assert_bool(_screen.visible).is_true()


func test_advance_past_last_beat_emits_sequence_finished_once() -> void:
	var fired: Array = []
	_screen.sequence_finished.connect(func() -> void: fired.append(true))
	_screen.present(_beats(2))
	_screen.advance()  # -> beat 1 (the last)
	assert_bool(fired.is_empty()).override_failure_message(
		"sequence_finished fired before the last beat was passed"
	).is_true()
	_screen.advance()  # past the last -> finish
	assert_int(fired.size()).override_failure_message(
		"sequence_finished should fire exactly once; fired %d times" % fired.size()
	).is_equal(1)
	assert_bool(_screen.visible).is_false()
	# Idempotent past the end — no extra emissions, no index drift.
	_screen.advance()
	assert_int(fired.size()).is_equal(1)


func test_present_empty_finishes_immediately() -> void:
	var fired: Array = []
	_screen.sequence_finished.connect(func() -> void: fired.append(true))
	_screen.present([])
	assert_int(fired.size()).is_equal(1)
	assert_int(_screen.get_beat_count()).is_equal(0)
	assert_bool(_screen.visible).is_false()


func test_speaker_and_line_fields_render_when_present() -> void:
	_screen.present([{
		"title": "장판교",
		"body": "다리 위의 한 사람.",
		"speaker": "장비",
		"line": "\"누가 나와 죽음을 겨루겠느냐!\"",
	}])
	# Optional speaker / line fields drive their label visibility.
	assert_bool((_screen.get("_speaker_label") as Label).visible).is_true()
	assert_bool((_screen.get("_line_label") as Label).visible).is_true()
	assert_str((_screen.get("_line_label") as Label).text).contains("죽음")


func test_optional_fields_hidden_when_absent() -> void:
	_screen.present([{"title": "장판파", "body": "후위를 막아라."}])
	assert_bool((_screen.get("_speaker_label") as Label).visible).is_false()
	assert_bool((_screen.get("_line_label") as Label).visible).is_false()
	assert_bool((_screen.get("_title_label") as Label).visible).is_true()
	assert_bool((_screen.get("_body_label") as Label).visible).is_true()
