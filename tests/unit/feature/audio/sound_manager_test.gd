## sound_manager_test.gd
##
## Verifies the SoundManager autoload's basic invariants:
##   - Headless builds skip pool construction (enabled=false; play() no-ops).
##   - reset_for_tests() forces enabled=false and rewires the GameBus subs after
##     a hypothetical bulk-disconnect (G-28 mirror obligation).
##   - Procedural stream construction produces well-formed AudioStreamWAV
##     instances when run on a fresh non-autoload instance with audio enabled
##     (covers the synthesis path that the headless autoload skips).
extends GdUnitTestSuite

const SoundManagerScript: GDScript = preload("res://src/feature/audio/sound_manager.gd")


func before_test() -> void:
	# The production /root/SoundManager autoload boots in headless mode (this test
	# runner) — its enabled is already false. Reset to be explicit + reconnect.
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.reset_for_tests()


# ─── Autoload behavior in headless ────────────────────────────────────────────


func test_autoload_disabled_in_headless() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	assert(sm != null, "SoundManager autoload must be registered (boot pos 10)")
	# Headless _ready short-circuits — no player pool, no streams.
	assert_bool(sm.enabled).is_false()


func test_play_noops_when_disabled() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	# Should not crash, should not throw, should be a clean no-op.
	sm.play(SoundManagerScript.SFX_HIT)
	sm.play(SoundManagerScript.SFX_TURN)
	sm.play(&"unknown_sfx_id")
	assert_bool(sm.enabled).is_false()  # state unchanged


func test_reset_for_tests_keeps_silent_and_rewires_subs() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	sm.reset_for_tests()
	assert_bool(sm.enabled).override_failure_message(
		"reset_for_tests must keep audio silent — tests should not trigger SFX"
	).is_false()
	assert_bool(GameBus.unit_died.is_connected(sm._on_unit_died)).is_true()
	assert_bool(GameBus.chapter_completed.is_connected(sm._on_chapter_completed)).is_true()


# ─── Procedural synthesis (run on a non-autoload instance with audio forced on) ──


func test_make_tone_produces_correctly_shaped_stream() -> void:
	# Construct a fresh instance (NOT the autoload) so we can test the synthesis
	# helpers without auto-skipping in headless. Don't add to tree → _ready does
	# not fire → the headless short-circuit is bypassed.
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var stream: AudioStreamWAV = sm._make_tone(440.0, 0.10, 12.0, 0.20)
	assert_object(stream).is_not_null()
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.mix_rate).is_equal(22050)
	assert_bool(stream.stereo).is_false()
	# 0.10s at 22050 Hz × 2 bytes per 16-bit sample = 4410 bytes.
	assert_int(stream.data.size()).is_equal(int(0.10 * 22050) * 2)


func test_make_chord_produces_correctly_shaped_stream() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var stream: AudioStreamWAV = sm._make_chord([523.25, 659.25, 783.99], 0.20, 4.0, 0.20)
	assert_object(stream).is_not_null()
	assert_int(stream.data.size()).is_equal(int(0.20 * 22050) * 2)
