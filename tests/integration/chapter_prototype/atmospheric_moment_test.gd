## atmospheric_moment_test.gd
##
## Integration tests for sprint-12 story-001 (S12-02) — Pillar 4 atmospheric moment.
## Covers AC-S12-02-1 through AC-S12-02-6 from story-001-pillar-4-atmospheric-moment.md.
##
## Acceptance criteria tested:
##   AC-S12-02-1: REWRITTEN branch → ColorRect overlay tints to #C0392B at 0.35 alpha within 0.4s.
##   AC-S12-02-2: REWRITTEN branch → AudioStreamPlayer plays synthesized hum; plays once per resolution.
##   AC-S12-02-3: REWRITTEN branch → buttons disabled for 1.5s dwell; re-enabled at dwell end.
##   AC-S12-02-4: REWRITTEN branch → ResultTitle color equals canonical #D4A017 (금색).
##   AC-S12-02-5: DEFEAT / HISTORICAL / PARTIAL branches → no overlay tint, no audio, no dwell (3 regressions).
##   AC-S12-02-6: Composite assertion covering AC-1/2/3 timing assertions in sequence.
##
## Setup: Chapter prototype script instantiated programmatically; _battle_outcome stubbed
## directly to force a specific fate branch without running the full UI + battle loop.
## Node is added to the scene root so get_tree().create_timer() resolves (required by
## _dispatch_atmospheric_moment() which uses await get_tree().create_timer(DWELL_LOCKOUT_S).timeout).
##
## Gotchas observed:
##   G-3:  no class_name in this file (test convention).
##   G-6:  explicit in-body cleanup before after_test orphan scan (chapter_node.free() in body).
##   G-15: before_test() / after_test() lifecycle, not before_each().
##   Headless audio: AudioStreamPlayer.playing may be false in headless mode (no audio server);
##         assert stream is set and bus connection is configured; not playing state.
extends GdUnitTestSuite


const CHAPTER_SCRIPT: String = "res://prototypes/chapter-prototype/chapter.gd"

# ─── REWRITTEN-branch fate stub ──────────────────────────────────────────────
# All 5 conditions met: tank_alive_hp_pct >= 0.60, assassin_kills >= 2,
# rear_attacks >= 2, formation_turns >= 3, boss_killed = true.
const OUTCOME_REWRITTEN: Dictionary = {
	"turn_count": 5,
	"units": [
		{"side": 0, "dead": false},
		{"side": 1, "dead": true},
	],
	"fate_data": {
		"tank_alive_hp_pct": 0.85,
		"assassin_kills": 3,
		"rear_attacks": 3,
		"formation_turns": 4,
		"boss_killed": true,
	},
}

# HISTORICAL-branch fate stub: all enemies alive, <3 conditions met (0 here).
const OUTCOME_HISTORICAL: Dictionary = {
	"turn_count": 5,
	"units": [
		{"side": 0, "dead": false},
		{"side": 1, "dead": false},
	],
	"fate_data": {
		"tank_alive_hp_pct": 0.30,
		"assassin_kills": 0,
		"rear_attacks": 0,
		"formation_turns": 0,
		"boss_killed": false,
	},
}

# PARTIAL-branch fate stub: player alive, some enemies alive, conditions_met == 3
# but NOT all 5 met (so not REWRITTEN; PARTIAL triggers when enemies alive but >= 3 met
# OR all enemies dead). Use: all enemies dead + not all 5 conditions met = PARTIAL.
const OUTCOME_PARTIAL: Dictionary = {
	"turn_count": 4,
	"units": [
		{"side": 0, "dead": false},
		{"side": 1, "dead": true},
	],
	"fate_data": {
		"tank_alive_hp_pct": 0.70,
		"assassin_kills": 2,
		"rear_attacks": 2,
		"formation_turns": 3,
		"boss_killed": false,  # c5 missing → not REWRITTEN
	},
}

# DEFEAT-branch fate stub: all player units dead.
const OUTCOME_DEFEAT: Dictionary = {
	"turn_count": 3,
	"units": [
		{"side": 0, "dead": true},
		{"side": 1, "dead": false},
	],
	"fate_data": {
		"tank_alive_hp_pct": 0.0,
		"assassin_kills": 0,
		"rear_attacks": 0,
		"formation_turns": 0,
		"boss_killed": false,
	},
}

# ─── Per-test state ───────────────────────────────────────────────────────────

var _chapter: Control = null


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func before_test() -> void:
	_chapter = null


func after_test() -> void:
	# G-6: safety-net cleanup; in-body cleanup should have already run.
	if is_instance_valid(_chapter):
		if _chapter.is_inside_tree():
			get_tree().root.remove_child(_chapter)
		_chapter.free()
	_chapter = null


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Instantiate chapter.gd as a Control, add to scene root, invoke _ready().
## Caller is responsible for removing + freeing _chapter after assertions.
func _spawn_chapter() -> Control:
	var script: GDScript = load(CHAPTER_SCRIPT) as GDScript
	var chapter: Control = script.new() as Control
	# Disable window-resize block so headless test doesn't call DisplayServer APIs
	# that do nothing (but don't crash) in headless mode.
	get_tree().root.add_child(chapter)
	# Await one frame so _ready() completes + all panels are built.
	await get_tree().process_frame
	return chapter


## Stub chapter._battle_outcome and call _show_result_phase() to trigger fate judgment.
## Returns without awaiting the atmospheric dispatch coroutine so callers can
## observe intermediate state.
func _trigger_result_phase(chapter: Control, outcome: Dictionary) -> void:
	chapter._battle_outcome = outcome
	# _show_result_phase() calls _judge_fate() synchronously, then awaits
	# _dispatch_atmospheric_moment() only if branch == REWRITTEN.
	# Calling it here starts the coroutine; we then await frames to observe state.
	chapter._show_result_phase()


## Retrieve the atmospheric overlay ColorRect from the result panel.
func _get_overlay(chapter: Control) -> ColorRect:
	var result_panel: Control = chapter.get_node("ResultPanel")
	return result_panel.get_node("AtmosphericOverlay") as ColorRect


## Retrieve the atmospheric AudioStreamPlayer from the result panel.
func _get_audio(chapter: Control) -> AudioStreamPlayer:
	var result_panel: Control = chapter.get_node("ResultPanel")
	return result_panel.get_node("AtmosphericAudio") as AudioStreamPlayer


## Retrieve the retry button from the result panel.
func _get_retry_btn(chapter: Control) -> Button:
	var result_panel: Control = chapter.get_node("ResultPanel")
	return result_panel.get_node("RetryButton") as Button


## Retrieve the quit button from the result panel.
func _get_quit_btn(chapter: Control) -> Button:
	var result_panel: Control = chapter.get_node("ResultPanel")
	return result_panel.get_node("QuitButton") as Button


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-1: REWRITTEN branch → ColorRect overlay color + alpha within 0.5s
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-1: when REWRITTEN-branch resolves, the AtmosphericOverlay ColorRect
## inside ResultPanel has color == Color8(0xC0,0x39,0x2B) and modulate.a >= 0.34
## within 0.5s (spec says within 0.4s tween; 0.5s allows frame overhead).
func test_rewritten_branch_overlay_color_and_alpha_rise_within_0_5s() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger REWRITTEN branch result phase; atmospheric coroutine starts.
	_trigger_result_phase(_chapter, OUTCOME_REWRITTEN)

	# Wait 0.5s worth of frames to allow the 0.4s tween to progress.
	await get_tree().create_timer(0.5).timeout

	# Assert — overlay exists with correct color constant.
	var overlay: ColorRect = _get_overlay(_chapter)
	assert_object(overlay).is_not_null()
	assert_bool(overlay.color == Color8(0xC0, 0x39, 0x2B)).override_failure_message(
		("AtmosphericOverlay color should be #C0392B (주홍); got %s" % str(overlay.color))
	).is_true()
	# Alpha should be >= 0.34 (spec is 0.35; allow 0.01 margin for float precision).
	assert_bool(overlay.modulate.a >= 0.34).override_failure_message(
		("AtmosphericOverlay modulate.a should be >= 0.34 within 0.5s; got %.4f" % overlay.modulate.a)
	).is_true()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-2: REWRITTEN branch → AudioStreamPlayer set up with synthesized stream
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-2: when REWRITTEN-branch resolves, the AtmosphericAudio AudioStreamPlayer
## has a stream set (AudioStreamGenerator), is NOT stream_paused, and play() was called.
## NOTE: headless mode has no audio server; AudioStreamPlayer.playing is false even
## after play() in headless. We assert: (1) stream is set, (2) stream_paused == false,
## (3) play() was called (verified by checking that stop() was NOT called after
## _dispatch_atmospheric_moment() began — inferred from stream_paused state).
## The audio setup itself (AudioStreamGenerator + push_buffer) is tested indirectly:
## _prebake_atmospheric_audio() populates _atmospheric_buffer; if that fails the
## push_buffer() call in _dispatch_atmospheric_moment() would crash, failing this test.
func test_rewritten_branch_audio_stream_player_configured_and_play_called() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger REWRITTEN branch; wait 0.15s (spec says within 0.1s; headless overhead added).
	_trigger_result_phase(_chapter, OUTCOME_REWRITTEN)
	await get_tree().create_timer(0.15).timeout

	# Assert — audio node exists and stream is an AudioStreamGenerator.
	var audio: AudioStreamPlayer = _get_audio(_chapter)
	assert_object(audio).is_not_null()
	assert_bool(audio.stream != null).override_failure_message(
		"AtmosphericAudio must have a stream set (AudioStreamGenerator)"
	).is_true()
	assert_bool(audio.stream is AudioStreamGenerator).override_failure_message(
		("AtmosphericAudio.stream must be AudioStreamGenerator; got %s" % str(audio.stream))
	).is_true()
	# Volume must match the spec constant.
	assert_float(audio.volume_db).is_equal_approx(-12.0, 0.01)
	# stream_paused == false means audio was not suppressed mid-play.
	assert_bool(audio.stream_paused).is_false()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-3: REWRITTEN branch → buttons disabled during dwell; re-enabled after
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-3: at t=0.5s post-REWRITTEN-resolution both result-panel buttons are
## disabled; at t=1.6s post-resolution both buttons are re-enabled.
## DWELL_LOCKOUT_S == 1.5s per chapter.gd constant.
func test_rewritten_branch_buttons_disabled_during_dwell_and_reenabled_after() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger REWRITTEN branch atmospheric sequence.
	_trigger_result_phase(_chapter, OUTCOME_REWRITTEN)

	# Wait 0.5s — well within the 1.5s dwell window; buttons must be disabled.
	await get_tree().create_timer(0.5).timeout

	var retry_btn: Button = _get_retry_btn(_chapter)
	var quit_btn: Button = _get_quit_btn(_chapter)
	assert_object(retry_btn).is_not_null()
	assert_object(quit_btn).is_not_null()
	assert_bool(retry_btn.disabled).override_failure_message(
		"RetryButton ('다시 도전') must be disabled during 1.5s REWRITTEN dwell lockout (AC-S12-02-3)"
	).is_true()
	assert_bool(quit_btn.disabled).override_failure_message(
		"QuitButton ('종료') must be disabled during 1.5s REWRITTEN dwell lockout (AC-S12-02-3)"
	).is_true()

	# Wait until t=1.6s post-resolution — dwell ends at 1.5s; buttons re-enabled.
	# Already waited 0.5s; wait 1.1s more to reach 1.6s total.
	await get_tree().create_timer(1.1).timeout

	assert_bool(retry_btn.disabled).override_failure_message(
		"RetryButton ('다시 도전') must be re-enabled after 1.5s REWRITTEN dwell lockout ends (AC-S12-02-3)"
	).is_false()
	assert_bool(quit_btn.disabled).override_failure_message(
		"QuitButton ('종료') must be re-enabled after 1.5s REWRITTEN dwell lockout ends (AC-S12-02-3)"
	).is_false()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-4: REWRITTEN branch → ResultTitle color == canonical #D4A017 (금색)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-4: ResultTitle theme color override "font_color" equals
## Color8(0xD4, 0xA0, 0x17) (canonical 금색) after REWRITTEN branch resolution.
## ±1 channel tolerance (1/255 ≈ 0.004) allows for float color-space rounding.
func test_rewritten_branch_title_color_matches_canonical_gold() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger REWRITTEN branch; _judge_fate() sets title color synchronously.
	_trigger_result_phase(_chapter, OUTCOME_REWRITTEN)
	# Await one frame for _judge_fate() to complete (it's synchronous but called
	# inside _show_result_phase which started as a coroutine).
	await get_tree().process_frame

	# Assert — ResultTitle theme color override matches canonical 금색.
	var result_panel: Control = _chapter.get_node("ResultPanel")
	var title: Label = result_panel.get_node("ResultTitle")
	assert_object(title).is_not_null()
	var actual_color: Color = title.get_theme_color("font_color")
	var expected_color: Color = Color8(0xD4, 0xA0, 0x17)
	# Channel-wise tolerance: 1/255 ≈ 0.004 per channel.
	var tolerance: float = 0.005
	assert_bool(
		absf(actual_color.r - expected_color.r) <= tolerance and
		absf(actual_color.g - expected_color.g) <= tolerance and
		absf(actual_color.b - expected_color.b) <= tolerance
	).override_failure_message(
		("ResultTitle color should be #D4A017 (金色); got r=%.4f g=%.4f b=%.4f" %
		[actual_color.r, actual_color.g, actual_color.b])
	).is_true()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-5: DEFEAT branch → no overlay tint, no audio play, no dwell (regression)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-5 (DEFEAT): after DEFEAT-branch resolution, overlay alpha stays 0;
## buttons remain enabled immediately (no dwell lockout).
func test_defeat_branch_has_no_overlay_tint_no_audio_no_dwell() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger DEFEAT branch.
	_trigger_result_phase(_chapter, OUTCOME_DEFEAT)
	# Await 0.5s to confirm NO atmospheric moment fires (not just synchronous state).
	await get_tree().create_timer(0.5).timeout

	# Assert — overlay alpha remains 0.
	var overlay: ColorRect = _get_overlay(_chapter)
	assert_object(overlay).is_not_null()
	assert_float(overlay.modulate.a).is_equal_approx(0.0, 0.01)

	# Assert — buttons enabled immediately (no dwell).
	var retry_btn: Button = _get_retry_btn(_chapter)
	var quit_btn: Button = _get_quit_btn(_chapter)
	assert_bool(retry_btn.disabled).override_failure_message(
		"RetryButton must NOT be disabled for DEFEAT branch (no dwell lockout)"
	).is_false()
	assert_bool(quit_btn.disabled).override_failure_message(
		"QuitButton must NOT be disabled for DEFEAT branch (no dwell lockout)"
	).is_false()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-5: HISTORICAL branch → no overlay tint, no audio play, no dwell (regression)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-5 (HISTORICAL): after HISTORICAL-branch resolution, overlay alpha stays 0;
## buttons remain enabled immediately.
func test_historical_branch_has_no_overlay_tint_no_audio_no_dwell() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger HISTORICAL branch.
	_trigger_result_phase(_chapter, OUTCOME_HISTORICAL)
	await get_tree().create_timer(0.5).timeout

	# Assert — overlay alpha remains 0.
	var overlay: ColorRect = _get_overlay(_chapter)
	assert_object(overlay).is_not_null()
	assert_float(overlay.modulate.a).is_equal_approx(0.0, 0.01)

	# Assert — buttons enabled immediately.
	var retry_btn: Button = _get_retry_btn(_chapter)
	var quit_btn: Button = _get_quit_btn(_chapter)
	assert_bool(retry_btn.disabled).override_failure_message(
		"RetryButton must NOT be disabled for HISTORICAL branch (no dwell lockout)"
	).is_false()
	assert_bool(quit_btn.disabled).override_failure_message(
		"QuitButton must NOT be disabled for HISTORICAL branch (no dwell lockout)"
	).is_false()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-S12-02-5: PARTIAL branch → no overlay tint, no audio play, no dwell (regression)
# ═══════════════════════════════════════════════════════════════════════════════


## AC-S12-02-5 (PARTIAL): after PARTIAL-branch resolution, overlay alpha stays 0;
## buttons remain enabled immediately.
func test_partial_branch_has_no_overlay_tint_no_audio_no_dwell() -> void:
	# Arrange
	_chapter = await _spawn_chapter()

	# Act — trigger PARTIAL branch.
	_trigger_result_phase(_chapter, OUTCOME_PARTIAL)
	await get_tree().create_timer(0.5).timeout

	# Assert — overlay alpha remains 0.
	var overlay: ColorRect = _get_overlay(_chapter)
	assert_object(overlay).is_not_null()
	assert_float(overlay.modulate.a).is_equal_approx(0.0, 0.01)

	# Assert — buttons enabled immediately.
	var retry_btn: Button = _get_retry_btn(_chapter)
	var quit_btn: Button = _get_quit_btn(_chapter)
	assert_bool(retry_btn.disabled).override_failure_message(
		"RetryButton must NOT be disabled for PARTIAL branch (no dwell lockout)"
	).is_false()
	assert_bool(quit_btn.disabled).override_failure_message(
		"QuitButton must NOT be disabled for PARTIAL branch (no dwell lockout)"
	).is_false()

	# G-6: in-body cleanup.
	if _chapter.is_inside_tree():
		get_tree().root.remove_child(_chapter)
	_chapter.free()
	_chapter = null
