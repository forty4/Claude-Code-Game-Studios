## story_content_test.gd
##
## Verifies assets/data/story/story_content.json: it parses to a JSON object,
## and every beat text key referenced by chapters in
## assets/data/scenarios/mvp_shu.json (beat_1, beat_3, every beat_8 revelation,
## beat_9) has a content entry with a non-empty title and body. Beat 2 is a
## silent_visual fragment — no text key — so it is not checked.
##
## This is the "the narrative the scenario points at actually exists" gate: if a
## chapter declares beat_*_text_key = "foo" but story_content.json has no "foo",
## the windowed StoryBeatScreen would skip that beat silently.
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/mvp_shu.json"
const STORY_CONTENT_PATH: String = "res://assets/data/story/story_content.json"


func _load_json_object(path: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(path)
	assert_str(raw).override_failure_message("file missing or empty: %s" % path).is_not_empty()
	var parsed: Variant = JSON.parse_string(raw)
	assert_bool(parsed is Dictionary).override_failure_message(
		"%s did not parse to a JSON object" % path
	).is_true()
	return parsed as Dictionary


## Collects every beat text key declared across all chapters in the scenario.
func _required_text_keys() -> Array[String]:
	var scenario: Dictionary = _load_json_object(SCENARIO_PATH)
	var keys: Array[String] = []
	for ch_var: Variant in (scenario.get("chapters", []) as Array):
		var ch: Dictionary = ch_var as Dictionary
		var b1: String = ch.get("beat_1_text_key", "") as String
		if not b1.is_empty():
			keys.append(b1)
		var b3: String = ch.get("beat_3_text_key", "") as String
		if not b3.is_empty():
			keys.append(b3)
		for rev_var: Variant in (ch.get("beat_8_revelations", []) as Array):
			var rev: Dictionary = rev_var as Dictionary
			var tk: String = rev.get("text_key", "") as String
			if not tk.is_empty():
				keys.append(tk)
		var b9: String = ch.get("beat_9_text_key", "") as String
		if not b9.is_empty():
			keys.append(b9)
	return keys


func test_story_content_json_parses_non_empty() -> void:
	var content: Dictionary = _load_json_object(STORY_CONTENT_PATH)
	assert_bool(content.is_empty()).override_failure_message(
		"story_content.json parsed to an empty Dictionary"
	).is_false()


func test_every_scenario_beat_key_has_content() -> void:
	var content: Dictionary = _load_json_object(STORY_CONTENT_PATH)
	var required: Array[String] = _required_text_keys()
	assert_bool(required.is_empty()).override_failure_message(
		"mvp_shu.json declared no beat text keys — scenario data regression?"
	).is_false()
	for key: String in required:
		assert_bool(content.has(key)).override_failure_message(
			"story_content.json is missing an entry for beat text key '%s'" % key
		).is_true()
		var entry: Dictionary = content.get(key, {}) as Dictionary
		assert_str((entry.get("title", "") as String).strip_edges()).override_failure_message(
			"story content '%s' has an empty title" % key
		).is_not_empty()
		assert_str((entry.get("body", "") as String).strip_edges()).override_failure_message(
			"story content '%s' has an empty body" % key
		).is_not_empty()
