## consequence_screen_test.gd
##
## Session-42 — covers the new "역사의 두 갈래" comparison overlay shown
## between Beat 8 and Beat 9 in the post-battle flow. The screen sets up
## two columns (OTHER muted / YOUR vivid), a header, and an advance button
## that fires sequence_finished on press / Enter / click.
##
## Coverage:
##   - make() factory stores the two titles and they render after _ready()
##   - both columns mount with TitleLabel children carrying the right text
##   - header label carries "역사의 두 갈래"
##   - advance() fires sequence_finished exactly once + flips visible false
##   - empty other-title falls back to "기록되지 않은 결말" placeholder
##     (defensive — caller should skip the mount entirely, but if it slips
##     through the widget renders gracefully rather than blanking)
extends GdUnitTestSuite


var _screen: ConsequenceScreen = null


func after_test() -> void:
	if is_instance_valid(_screen):
		get_tree().root.remove_child(_screen)
		_screen.free()  # G-6 — no external Callables on the subtree
	_screen = null


func _mount(other_title: String, your_title: String) -> ConsequenceScreen:
	var s: ConsequenceScreen = ConsequenceScreen.make(other_title, your_title)
	get_tree().root.add_child(s)
	return s


# ─── Factory + mount ─────────────────────────────────────────────────────────


func test_make_stores_titles_and_mounts_cleanly() -> void:
	_screen = _mount("후위가 무너지다", "장판의 먼지가 가라앉다")
	await get_tree().process_frame
	assert_object(_screen).is_not_null()
	assert_bool(_screen.is_inside_tree()).is_true()


# ─── Column rendering ────────────────────────────────────────────────────────


func test_other_column_renders_other_title_in_muted_color() -> void:
	var other: String = "후위가 무너지다"
	var your: String = "장판의 먼지가 가라앉다"
	_screen = _mount(other, your)
	await get_tree().process_frame
	var col: Node = _screen.find_child("OtherColumn", true, false)
	assert_object(col).override_failure_message(
		"S42: OtherColumn VBoxContainer must mount"
	).is_not_null()
	var title_label: Label = col.find_child("TitleLabel", true, false) as Label
	assert_object(title_label).is_not_null()
	assert_str(title_label.text).is_equal(other)


func test_your_column_renders_your_title_in_vivid_color() -> void:
	var other: String = "후위가 무너지다"
	var your: String = "장판의 먼지가 가라앉다"
	_screen = _mount(other, your)
	await get_tree().process_frame
	var col: Node = _screen.find_child("YourColumn", true, false)
	assert_object(col).is_not_null()
	var title_label: Label = col.find_child("TitleLabel", true, false) as Label
	assert_object(title_label).is_not_null()
	assert_str(title_label.text).is_equal(your)


## Empty `other_title` is a defensive case — the caller (battle_scene) should
## skip mount when there's no other branch, but if it slips through the
## widget renders the placeholder rather than blanking the column.
func test_empty_other_title_falls_back_to_placeholder() -> void:
	_screen = _mount("", "장판의 먼지가 가라앉다")
	await get_tree().process_frame
	var col: Node = _screen.find_child("OtherColumn", true, false)
	var title_label: Label = col.find_child("TitleLabel", true, false) as Label
	assert_str(title_label.text).override_failure_message(
		"S42: empty other_title must fall back to '기록되지 않은 결말' (got '%s')"
			% title_label.text
	).is_equal("기록되지 않은 결말")


# ─── Advance flow ────────────────────────────────────────────────────────────


func test_advance_emits_sequence_finished_once_and_hides_screen() -> void:
	_screen = _mount("후위가 무너지다", "장판의 먼지가 가라앉다")
	await get_tree().process_frame
	var fired: Array = []  # G-4 — array capture so lambda can mutate observable state
	_screen.sequence_finished.connect(func() -> void: fired.append(true))

	_screen.advance()
	assert_int(fired.size()).override_failure_message(
		"S42: sequence_finished must fire exactly once on advance"
	).is_equal(1)
	assert_bool(_screen.visible).is_false()

	# Idempotent — second advance() does NOT re-fire.
	_screen.advance()
	assert_int(fired.size()).override_failure_message(
		"S42: advance() must be idempotent after first finish"
	).is_equal(1)


# ─── Header presence ─────────────────────────────────────────────────────────


func test_header_text_is_역사의_두_갈래() -> void:
	_screen = _mount("a", "b")
	await get_tree().process_frame
	# Header is the first Label child of the inner VBoxContainer (added before
	# the comparison HBox). Walk the tree to find a Label whose text matches.
	var found: bool = false
	for child: Node in _find_all_labels(_screen):
		if (child as Label).text == ConsequenceScreen.HEADER_TEXT:
			found = true
			break
	assert_bool(found).override_failure_message(
		"S42: a Label with text '%s' must be in the widget tree" \
			% ConsequenceScreen.HEADER_TEXT
	).is_true()


# ─── Helpers ─────────────────────────────────────────────────────────────────


func _find_all_labels(parent: Node) -> Array[Label]:
	var out: Array[Label] = []
	for child: Node in parent.get_children():
		if child is Label:
			out.append(child as Label)
		out.append_array(_find_all_labels(child))
	return out
