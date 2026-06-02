## battle_scene_chapter_end_ceremony_test.gd
##
## S101 sentinel — locks the chapter-end ceremony restructure (user feedback:
## finishing a chapter showed only the "승리" banner with the narrative gated
## behind a "leave"-reading exit button → "끝 느낌 0"). The WIN path now defers
## the exit buttons: banner → "▶ 계속" prompt → Beat 8 → ConsequenceScreen →
## Beat 9 → chapter-complete buttons. Source-grep level (the windowed flow is
## gated by tools/ci/g30/g30_chapter_end_smoke + manual attestation), matching
## the sibling battle_scene_macro_loop_chapter_select_return_test pattern.
##
## Also guards the 4 post-battle results-panel locale keys (UI-GB-09) that were
## rendering raw via tr() (no entry, no fallback) before S101.
extends GdUnitTestSuite


const _BATTLE_SCENE_SCRIPT_PATH: String = "res://src/feature/battle_scene/battle_scene.gd"
const _KO_PO_PATH: String = "res://assets/locale/ko.po"
const _EN_PO_PATH: String = "res://assets/locale/en.po"


func _read(path: String) -> String:
	var raw: String = FileAccess.get_file_as_string(path)
	assert_bool(raw.is_empty()).override_failure_message("Could not read %s" % path).is_false()
	return raw


# ─── WIN ceremony structure (source-grep) ────────────────────────────────────

## WIN defers the exit buttons to a "▶ 계속" prompt instead of mounting
## _mount_post_battle_buttons immediately (the pre-S101 abrupt behaviour).
func test_win_outcome_mounts_continue_prompt_not_immediate_buttons() -> void:
	var src: String = _read(_BATTLE_SCENE_SCRIPT_PATH)
	assert_bool(src.contains("func _mount_win_continue_prompt")).override_failure_message(
		"battle_scene.gd must define _mount_win_continue_prompt (the deferred-buttons WIN path)."
	).is_true()
	assert_bool(src.contains("_mount_win_continue_prompt()")).override_failure_message(
		"_on_battle_outcome_resolved WIN branch must call _mount_win_continue_prompt() "
		+ "instead of _mount_post_battle_buttons() (exit buttons are deferred until after the story)."
	).is_true()


## The narrative is extracted into a reusable helper that does NOT itself
## transition scenes, so the WIN ceremony can show chapter-complete buttons AFTER
## the beats (and the LOSS/DRAW path can still route to chapter select).
func test_post_battle_narrative_helper_and_win_ceremony_present() -> void:
	var src: String = _read(_BATTLE_SCENE_SCRIPT_PATH)
	assert_bool(src.contains("func _run_post_battle_narrative")).override_failure_message(
		"battle_scene.gd must define _run_post_battle_narrative (the Beat 8 → Consequence → "
		+ "Beat 9 helper shared by the WIN ceremony and the LOSS/DRAW proceed path)."
	).is_true()
	assert_bool(src.contains("func _begin_win_ceremony")).override_failure_message(
		"battle_scene.gd must define _begin_win_ceremony (banner → narrative → chapter-complete buttons)."
	).is_true()
	assert_bool(src.contains("func _mount_chapter_complete_buttons")).override_failure_message(
		"battle_scene.gd must define _mount_chapter_complete_buttons (shown AFTER the narrative)."
	).is_true()


## The "▶ 계속" prompt label is present (the continue affordance).
func test_continue_prompt_label_present() -> void:
	var src: String = _read(_BATTLE_SCENE_SCRIPT_PATH)
	assert_bool(src.contains("계속")).override_failure_message(
		"battle_scene.gd must surface a '계속' continue affordance in the WIN prompt."
	).is_true()


## S102 — the in-battle victory celebration: the WIN field is kept VIVID (dim
## deferred to the exit click) and the surviving units cheer in a wave.
func test_win_victory_celebration_present_and_field_kept_vivid() -> void:
	var src: String = _read(_BATTLE_SCENE_SCRIPT_PATH)
	assert_bool(src.contains("func _trigger_victory_celebration")).override_failure_message(
		"battle_scene.gd must define _trigger_victory_celebration (S102 in-battle 환호)."
	).is_true()
	assert_bool(src.contains("func _celebrate_surviving_player_units")).override_failure_message(
		"battle_scene.gd must define _celebrate_surviving_player_units (the cheering wave)."
	).is_true()
	# WIN must NOT dim the grid immediately — the dim is gated to non-WIN so the
	# won field stays vivid for the celebration (S102).
	assert_bool(src.contains("_pending_outcome != BattleOutcome.Result.WIN \\")).override_failure_message(
		"_on_battle_outcome_resolved must gate the immediate grid-dim to non-WIN outcomes "
		+ "(WIN keeps the field vivid; the dim is deferred to _begin_win_ceremony)."
	).is_true()


## The WIN chapter-complete primary goes straight to chapter select (no narrative
## replay) — i.e. _go_to_chapter_select, distinct from _proceed_scenario.
func test_chapter_complete_uses_direct_chapter_select() -> void:
	var src: String = _read(_BATTLE_SCENE_SCRIPT_PATH)
	assert_bool(src.contains("func _go_to_chapter_select")).override_failure_message(
		"battle_scene.gd must define _go_to_chapter_select (direct return, used by the WIN "
		+ "chapter-complete buttons after the narrative has already played)."
	).is_true()


# ─── Results-panel locale keys (UI-GB-09) ────────────────────────────────────

## The 4 plain-text post-battle keys must resolve in BOTH locales (pre-S101 they
## had no entry → tr() rendered the raw key in the results panel).
func test_results_panel_outcome_locale_keys_present_in_both_locales() -> void:
	var ko: String = _read(_KO_PO_PATH)
	var en: String = _read(_EN_PO_PATH)
	for key: String in [
		"hud.outcome.victory", "hud.outcome.defeat",
		"hud.outcome.draw", "hud.results.continue",
	]:
		assert_bool(ko.contains("msgid \"%s\"" % key)).override_failure_message(
			"ko.po must define '%s' (post-battle results panel rendered raw keys pre-S101)." % key
		).is_true()
		assert_bool(en.contains("msgid \"%s\"" % key)).override_failure_message(
			"en.po must define '%s' (fallback locale)." % key
		).is_true()
