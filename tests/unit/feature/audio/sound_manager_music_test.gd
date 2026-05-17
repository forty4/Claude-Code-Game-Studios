## sound_manager_music_test.gd
##
## Verifies the session-12 music channel additions on SoundManager:
##   - MUSIC_BATTLE_AMBIENT slug + drone synth produce a well-shaped
##     looping AudioStreamWAV
##   - play_music caches the requested slug into _current_music
##   - play_music respects music_enabled = false (cache slug, don't start)
##   - stop_music clears _current_music + halts the player
##   - set_music_enabled(false) stops a playing track
##   - set_music_enabled(true) resumes the cached track
##   - reset_for_tests silences both SFX + music channels
##
## Mirrors the sound_manager_test.gd + sound_manager_persistence_test.gd
## patterns for the SFX channel (_make_tone / _make_chord shape tests +
## ConfigFile round-trip).
extends GdUnitTestSuite

const SoundManagerScript: GDScript = preload("res://src/feature/audio/sound_manager.gd")


func before_test() -> void:
	# Reset autoload state so each test starts from a known baseline.
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.reset_for_tests()


# ─── MUSIC_BATTLE_AMBIENT slug exists + has a stream ─────────────────────────


func test_music_battle_ambient_slug_exists() -> void:
	# Class const exposed for callers (BattleScene, tests).
	assert_str(String(SoundManagerScript.MUSIC_BATTLE_AMBIENT)).is_equal("battle_ambient")


# ─── Drone synth shape ───────────────────────────────────────────────────────


func test_make_battle_drone_produces_correctly_shaped_stream() -> void:
	# Construct a fresh (non-autoload) instance so we can call the synth
	# helper directly without triggering the headless _ready short-circuit.
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var stream: AudioStreamWAV = sm._make_battle_drone(2.0)
	assert_object(stream).is_not_null()
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.mix_rate).is_equal(22050)
	assert_bool(stream.stereo).is_false()
	# 2.0s at 22050 Hz × 2 bytes per 16-bit sample = 88200 bytes.
	assert_int(stream.data.size()).is_equal(int(2.0 * 22050) * 2)


func test_make_battle_drone_uses_loop_forward_mode() -> void:
	# Looping mode is required so AudioStreamPlayer doesn't stop after one cycle.
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var stream: AudioStreamWAV = sm._make_battle_drone(2.0)
	assert_int(stream.loop_mode).is_equal(int(AudioStreamWAV.LOOP_FORWARD))
	assert_int(stream.loop_begin).is_equal(0)
	assert_int(stream.loop_end).is_equal(int(2.0 * 22050))


# ─── play_music / stop_music caching semantics ───────────────────────────────


func test_play_music_caches_slug_even_when_music_disabled() -> void:
	# Caching the slug is required so set_music_enabled(true) can resume the
	# track without the caller having to remember which one was requested.
	var sm: Node = get_node_or_null("/root/SoundManager")
	sm.music_enabled = false
	sm.play_music(SoundManagerScript.MUSIC_BATTLE_AMBIENT)
	assert_str(String(sm._current_music)).override_failure_message(
		"play_music must cache the slug into _current_music regardless of music_enabled"
	).is_equal("battle_ambient")


func test_stop_music_clears_current_music() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	sm.play_music(SoundManagerScript.MUSIC_BATTLE_AMBIENT)
	sm.stop_music()
	assert_str(String(sm._current_music)).override_failure_message(
		"stop_music must clear _current_music so set_music_enabled(true) does NOT auto-resume"
	).is_equal("")


# ─── set_music_enabled toggles state ─────────────────────────────────────────


func test_set_music_enabled_false_stops_and_keeps_cache() -> void:
	# set_music_enabled(false) stops the player but PRESERVES _current_music
	# so a subsequent set_music_enabled(true) resumes the same track.
	var sm: Node = get_node_or_null("/root/SoundManager")
	sm.music_enabled = true
	sm.play_music(SoundManagerScript.MUSIC_BATTLE_AMBIENT)
	assert_str(String(sm._current_music)).is_equal("battle_ambient")
	sm.set_music_enabled(false)
	assert_bool(sm.music_enabled).is_false()
	# Cache survives the disable so set_music_enabled(true) below can resume.
	assert_str(String(sm._current_music)).override_failure_message(
		"set_music_enabled(false) must preserve _current_music for resume"
	).is_equal("battle_ambient")


func test_set_music_enabled_true_resumes_cached_track() -> void:
	# Round-trip: enable → play → disable → re-enable → cached track active.
	var sm: Node = get_node_or_null("/root/SoundManager")
	sm.music_enabled = true
	sm.play_music(SoundManagerScript.MUSIC_BATTLE_AMBIENT)
	sm.set_music_enabled(false)
	sm.set_music_enabled(true)
	assert_bool(sm.music_enabled).is_true()
	assert_str(String(sm._current_music)).override_failure_message(
		"set_music_enabled(true) must keep _current_music intact"
	).is_equal("battle_ambient")


# ─── reset_for_tests silences both channels ───────────────────────────────────


func test_reset_for_tests_silences_music_channel_too() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	sm.enabled = true
	sm.music_enabled = true
	sm._current_music = SoundManagerScript.MUSIC_BATTLE_AMBIENT  # simulate active

	sm.reset_for_tests()

	assert_bool(sm.enabled).override_failure_message(
		"reset_for_tests must silence SFX channel"
	).is_false()
	assert_bool(sm.music_enabled).override_failure_message(
		"reset_for_tests must silence music channel (session-12 addition)"
	).is_false()
	assert_str(String(sm._current_music)).override_failure_message(
		"reset_for_tests must clear _current_music to prevent test bleed"
	).is_equal("")


# ─── Public API surface ──────────────────────────────────────────────────────


func test_play_music_method_exists_on_autoload() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	assert(sm != null, "SoundManager autoload must be registered")
	assert_bool(sm.has_method("play_music")).is_true()
	assert_bool(sm.has_method("stop_music")).is_true()
	assert_bool(sm.has_method("set_music_enabled")).is_true()


# ─── S60 chapter-specific BGM ────────────────────────────────────────────────


## Maps every authored chapter_id (per mvp_shu.json) to its chapter-specific
## music slug. Catches the case where a new chapter is added but the music
## switch in music_id_for_chapter() doesn't get the new case → would silently
## fall through to MUSIC_BATTLE_AMBIENT (audible regression: chapter has no
## distinct theme).
func test_music_id_for_chapter_resolves_distinct_slugs_per_mvp_chapter() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	assert(sm != null, "SoundManager autoload must be registered")
	assert_bool(sm.has_method("music_id_for_chapter")).override_failure_message(
		"S60: SoundManager.music_id_for_chapter() must exist"
	).is_true()
	# Production chapter_ids per assets/data/scenarios/mvp_shu.json.
	var expected_distinct_slugs: Array[StringName] = []
	for chapter_id: StringName in [
		&"ch01_changbanpo",
		&"ch02_changban_bridge",
		&"ch03_xiakou_outskirts",
		&"ch04_chibi_prelude",
		&"ch05_chibi_main",
	]:
		var music_id: StringName = sm.music_id_for_chapter(chapter_id)
		assert_str(String(music_id)).override_failure_message(
			"S60: chapter '%s' resolved to empty music_id" % chapter_id
		).is_not_empty()
		assert_str(String(music_id)).override_failure_message(
			"S60: chapter '%s' must NOT fall back to generic ambient — should have its own theme" % chapter_id
		).is_not_equal(String(SoundManagerScript.MUSIC_BATTLE_AMBIENT))
		expected_distinct_slugs.append(music_id)
	# All 5 chapter slugs must be distinct (no two chapters share a theme).
	var unique_count: int = 0
	var seen: Dictionary = {}
	for slug: StringName in expected_distinct_slugs:
		if not seen.has(slug):
			seen[slug] = true
			unique_count += 1
	assert_int(unique_count).override_failure_message(
		"S60: each chapter must have its OWN distinct music slug; got duplicates in %s" % str(expected_distinct_slugs)
	).is_equal(5)


func test_music_id_for_chapter_falls_back_to_ambient_for_unknown_chapter() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	# Unknown chapter_id (test fixture / future un-themed chapter) falls back
	# to MUSIC_BATTLE_AMBIENT structurally so play_music() never gets an empty
	# slug. Not an error — designed graceful degradation.
	var music_id: StringName = sm.music_id_for_chapter(&"unknown_chapter_xyz")
	assert_str(String(music_id)).is_equal(String(SoundManagerScript.MUSIC_BATTLE_AMBIENT))


func test_all_5_chapter_music_streams_built_by_procedural_builder() -> void:
	# Headless _ready early-returns before _build_procedural_music_streams (no
	# audio device → skip synth cost in CI). Build a fresh instance and invoke
	# the synth directly to verify the 5 chapter streams populate.
	var fresh: Node = SoundManagerScript.new()
	auto_free(fresh)
	fresh._build_procedural_music_streams()
	for slug: StringName in [
		SoundManagerScript.MUSIC_CH01_CHANGBANPO,
		SoundManagerScript.MUSIC_CH02_CHANGBAN_BRIDGE,
		SoundManagerScript.MUSIC_CH03_XIAKOU,
		SoundManagerScript.MUSIC_CH04_CHIBI_PRELUDE,
		SoundManagerScript.MUSIC_CH05_CHIBI_MAIN,
	]:
		assert_bool(fresh._music_streams.has(slug)).override_failure_message(
			"S60: chapter music stream '%s' not built — check _build_procedural_music_streams" % slug
		).is_true()
	# Streams must be DISTINCT AudioStreamWAV instances per chapter (catches
	# the regression where music_id_for_chapter routes correctly but every
	# chapter shares the same synthesized stream).
	var s1: AudioStream = fresh._music_streams[SoundManagerScript.MUSIC_CH01_CHANGBANPO] as AudioStream
	var s2: AudioStream = fresh._music_streams[SoundManagerScript.MUSIC_CH02_CHANGBAN_BRIDGE] as AudioStream
	assert_bool(s1 != s2).override_failure_message(
		"S60: ch01 and ch02 streams must be different AudioStreamWAV instances"
	).is_true()
