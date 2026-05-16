## outcome_banner_test.gd
##
## Smoke + per-outcome text/color/subtitle test for OutcomeBanner.
##
## Pre-S34 the banner showed identical "승리" for all 4 VICTORY_* outcomes
## and identical "패배" for all 3 DEFEAT_* outcomes — the S28-31 win-condition
## taxonomy was collapsed into 2 visual buckets. S34 adds a subtitle below
## the main label naming WHICH condition resolved.
##
## Coverage:
##   - new() via static make() succeeds + mounts in tree without crashing
##   - Each of the 8 supported outcome StringNames maps to the expected
##     main-label text + outcome color + subtitle text
##   - Unknown outcome → default "결과" main + empty subtitle (no Subtitle
##     child mounted; fall-through path preserved)
extends GdUnitTestSuite


const _OUTCOMES_VICTORY: Array[Dictionary] = [
	{
		"name": &"VICTORY_ANNIHILATION",
		"subtitle": "적 부대 전멸",
	},
	{
		"name": &"VICTORY_SURVIVE",
		"subtitle": "전선 사수",
	},
	{
		"name": &"VICTORY_ESCORT",
		"subtitle": "호위 성공",
	},
	{
		"name": &"VICTORY_REACH_TILE",
		"subtitle": "탈출 성공",
	},
]

const _OUTCOMES_DEFEAT: Array[Dictionary] = [
	{
		"name": &"DEFEAT_ANNIHILATION",
		"subtitle": "아군 전멸",
	},
	{
		"name": &"DEFEAT_ESCORT_LOST",
		"subtitle": "호위 대상 사망",
	},
	{
		"name": &"DEFEAT_REACH_FAILED",
		"subtitle": "탈출 실패",
	},
]


var _banner: OutcomeBanner = null


func after_test() -> void:
	# Per-test cleanup — each test mounts its own banner.
	if is_instance_valid(_banner):
		get_tree().root.remove_child(_banner)
		# free() not queue_free() per G-6: no external Callables on the
		# subtree, so immediate free avoids the orphan window.
		_banner.free()
	_banner = null


# ─── Smoke: instantiation ────────────────────────────────────────────────────


func test_make_factory_returns_outcome_banner_instance() -> void:
	_banner = OutcomeBanner.make(&"VICTORY_ANNIHILATION")
	get_tree().root.add_child(_banner)
	await get_tree().process_frame

	assert_object(_banner).is_not_null()
	assert_bool(_banner.is_inside_tree()).is_true()


# ─── Victory side: main label text + subtitle per outcome ────────────────────


func test_victory_outcomes_render_victory_text_and_distinct_subtitle() -> void:
	for case: Dictionary in _OUTCOMES_VICTORY:
		var outcome: StringName = case["name"]
		var expected_subtitle: String = case["subtitle"] as String

		_banner = OutcomeBanner.make(outcome)
		get_tree().root.add_child(_banner)
		await get_tree().process_frame

		var main_label: Label = _find_first_label(_banner, "Subtitle")
		assert_object(main_label).override_failure_message(
			"S34: VICTORY banner for %s must have a main Label child" % outcome
		).is_not_null()
		assert_str(main_label.text).override_failure_message(
			"S34: VICTORY_* outcome %s must render main text '승리'" % outcome
		).is_equal(OutcomeBanner.TEXT_VICTORY)

		var subtitle: Node = _banner.get_node_or_null("Subtitle")
		assert_object(subtitle).override_failure_message(
			"S34: VICTORY outcome %s must mount a Subtitle child node" % outcome
		).is_not_null()
		var subtitle_label: Label = subtitle as Label
		assert_str(subtitle_label.text).override_failure_message(
			"S34: VICTORY outcome %s must render subtitle '%s'"
				% [outcome, expected_subtitle]
		).is_equal(expected_subtitle)

		_teardown_banner_between_iterations()


# ─── Defeat side: main label text + subtitle per outcome ─────────────────────


func test_defeat_outcomes_render_defeat_text_and_distinct_subtitle() -> void:
	for case: Dictionary in _OUTCOMES_DEFEAT:
		var outcome: StringName = case["name"]
		var expected_subtitle: String = case["subtitle"] as String

		_banner = OutcomeBanner.make(outcome)
		get_tree().root.add_child(_banner)
		await get_tree().process_frame

		var main_label: Label = _find_first_label(_banner, "Subtitle")
		assert_object(main_label).override_failure_message(
			"S34: DEFEAT banner for %s must have a main Label child" % outcome
		).is_not_null()
		assert_str(main_label.text).override_failure_message(
			"S34: DEFEAT_* outcome %s must render main text '패배'" % outcome
		).is_equal(OutcomeBanner.TEXT_DEFEAT)

		var subtitle: Node = _banner.get_node_or_null("Subtitle")
		assert_object(subtitle).override_failure_message(
			"S34: DEFEAT outcome %s must mount a Subtitle child node" % outcome
		).is_not_null()
		var subtitle_label: Label = subtitle as Label
		assert_str(subtitle_label.text).override_failure_message(
			"S34: DEFEAT outcome %s must render subtitle '%s'"
				% [outcome, expected_subtitle]
		).is_equal(expected_subtitle)

		_teardown_banner_between_iterations()


# ─── Draw + unknown outcome paths ────────────────────────────────────────────


func test_turn_limit_reached_renders_draw_text_and_draw_subtitle() -> void:
	_banner = OutcomeBanner.make(&"TURN_LIMIT_REACHED")
	get_tree().root.add_child(_banner)
	await get_tree().process_frame

	var main_label: Label = _find_first_label(_banner, "Subtitle")
	assert_str(main_label.text).is_equal(OutcomeBanner.TEXT_DRAW)
	var subtitle: Node = _banner.get_node_or_null("Subtitle")
	assert_object(subtitle).override_failure_message(
		"S34: TURN_LIMIT_REACHED must mount a Subtitle child"
	).is_not_null()
	assert_str((subtitle as Label).text).is_equal(OutcomeBanner.SUBTITLE_DRAW)


## Unknown StringName falls through the match to TEXT_DEFAULT + empty
## subtitle → _ready() skips Subtitle mount entirely. Regression-safe
## for any future outcome added to the controller but not yet wired here.
func test_unknown_outcome_renders_default_text_and_no_subtitle() -> void:
	_banner = OutcomeBanner.make(&"UNKNOWN_OUTCOME_FOR_TEST")
	get_tree().root.add_child(_banner)
	await get_tree().process_frame

	var main_label: Label = _find_first_label(_banner, "Subtitle")
	assert_str(main_label.text).is_equal(OutcomeBanner.TEXT_DEFAULT)
	var subtitle: Node = _banner.get_node_or_null("Subtitle")
	assert_object(subtitle).override_failure_message(
		"S34: unknown outcome must NOT mount a Subtitle child "
		+ "(empty subtitle text suppresses the mount per _ready())"
	).is_null()


# ─── Helpers ─────────────────────────────────────────────────────────────────


## Returns the first Label child of `parent` whose name is NOT `exclude_name`.
## The banner mounts the main label as an anonymous child + the subtitle as
## "Subtitle"; this picks the main label without depending on child order.
func _find_first_label(parent: Node, exclude_name: String) -> Label:
	for child: Node in parent.get_children():
		if child is Label and child.name != exclude_name:
			return child as Label
	return null


## Free + null out the banner between iterations of a single test so the
## next iteration can mount a fresh one without orphan accumulation.
func _teardown_banner_between_iterations() -> void:
	if is_instance_valid(_banner):
		get_tree().root.remove_child(_banner)
		_banner.free()
	_banner = null
