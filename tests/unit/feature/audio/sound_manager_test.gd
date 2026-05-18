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


# ─── Session-26: FIRE noise burst ────────────────────────────────────────────


func test_make_noise_burst_produces_correctly_shaped_stream() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var stream: AudioStreamWAV = sm._make_noise_burst(0.18, 6.0, 0.18)
	assert_object(stream).is_not_null()
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.mix_rate).is_equal(22050)
	assert_bool(stream.stereo).is_false()
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	# 0.18s at 22050 Hz × 2 bytes per 16-bit sample = 7938 bytes.
	assert_int(stream.data.size()).is_equal(int(0.18 * 22050) * 2)


## Determinism check — the LCG-seeded noise burst MUST produce byte-identical
## PCM data across calls so tests don't drift on platform/RNG-state changes.
func test_make_noise_burst_is_deterministic() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var a: AudioStreamWAV = sm._make_noise_burst(0.10, 6.0, 0.18)
	var b: AudioStreamWAV = sm._make_noise_burst(0.10, 6.0, 0.18)
	assert_bool(a.data == b.data).override_failure_message(
		"_make_noise_burst PCM must be byte-identical across calls — LCG seed leaked"
	).is_true()


## Session-26: SFX_FIRE_TICK must register as part of _build_procedural_streams.
func test_sfx_fire_tick_registered() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	sm._build_procedural_streams()
	assert_bool(sm._streams.has(SoundManagerScript.SFX_FIRE_TICK)).override_failure_message(
		"SFX_FIRE_TICK must be registered after _build_procedural_streams"
	).is_true()
	var stream: AudioStreamWAV = sm._streams[SoundManagerScript.SFX_FIRE_TICK] as AudioStreamWAV
	assert_object(stream).is_not_null()
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_int(stream.data.size()).is_greater(0)


## S66: SFX_LEGENDARY must register as part of _build_procedural_streams.
## ~3s buffer (per _make_legendary_fanfare duration constant) — much longer
## than the standard ~0.6s SFX_VICTORY, so the difference is structurally
## visible at PCM length.
func test_sfx_legendary_registered_and_longer_than_victory() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	sm._build_procedural_streams()
	assert_bool(sm._streams.has(SoundManagerScript.SFX_LEGENDARY)).override_failure_message(
		"SFX_LEGENDARY must be registered after _build_procedural_streams"
	).is_true()
	var legendary: AudioStreamWAV = sm._streams[SoundManagerScript.SFX_LEGENDARY] as AudioStreamWAV
	var victory: AudioStreamWAV = sm._streams[SoundManagerScript.SFX_VICTORY] as AudioStreamWAV
	assert_object(legendary).is_not_null()
	assert_int(legendary.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	# Legendary fanfare (3s) must be at least 3x longer than SFX_VICTORY (0.6s)
	# — that gap is the audible "bigger gesture" the Legendary cue requires.
	assert_int(legendary.data.size()).override_failure_message(
		"SFX_LEGENDARY buffer (%d bytes) must be >= 3x SFX_VICTORY (%d bytes)"
		% [legendary.data.size(), victory.data.size()]
	).is_greater_equal(victory.data.size() * 3)


## S66: _make_legendary_fanfare produces deterministic PCM (pure synthesis,
## no RNG). Two consecutive calls must return byte-identical buffers.
func test_make_legendary_fanfare_is_deterministic() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	var a: AudioStreamWAV = sm._make_legendary_fanfare()
	var b: AudioStreamWAV = sm._make_legendary_fanfare()
	assert_bool(a.data == b.data).override_failure_message(
		"_make_legendary_fanfare PCM must be byte-identical across calls — pure synthesis"
	).is_true()


# ─── Session-32: volume_offset_db ────────────────────────────────────────────


## play(sfx_id, -4.0) shifts the player pool's volume_db by -4 below master.
## Drive a real instance with audio enabled + a single-slot pool so we can
## inspect player.volume_db after the play() call.
func test_play_with_volume_offset_db_shifts_player_volume() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	# Force-build a 1-player pool + the stream registry (bypass headless
	# short-circuit which would leave _players empty).
	sm.enabled = true
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = "Master"
	sm._players = [p] as Array[AudioStreamPlayer]
	auto_free(p)
	add_child(p)  # AudioStreamPlayer needs to be in the tree to play()
	sm._build_procedural_streams()
	# Master baseline = -8.0 dB per _MASTER_VOLUME_DB.
	sm.play(SoundManagerScript.SFX_HIT, -4.0)
	assert_float(p.volume_db).override_failure_message(
		"volume_offset_db=-4.0 must produce player.volume_db = -8 + -4 = -12; got %.2f"
				% p.volume_db
	).is_equal_approx(-12.0, 0.01)


## play(sfx_id) without offset preserves the master baseline (backward-compat).
func test_play_default_offset_uses_master_volume_db() -> void:
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	sm.enabled = true
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = "Master"
	sm._players = [p] as Array[AudioStreamPlayer]
	auto_free(p)
	add_child(p)
	sm._build_procedural_streams()
	sm.play(SoundManagerScript.SFX_HIT)  # default offset = 0.0
	assert_float(p.volume_db).override_failure_message(
		"default offset (0.0) must produce player.volume_db = -8.0 (master baseline); got %.2f"
				% p.volume_db
	).is_equal_approx(-8.0, 0.01)
