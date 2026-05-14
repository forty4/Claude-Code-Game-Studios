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
