## sound_manager_skill_sfx_test.gd
##
## Session-20 — verifies the 7 per-skill SFX variants registered by
## `_build_procedural_streams()`. Each SFX_SKILL_<NAME> constant must:
##   1. Be a non-empty StringName.
##   2. Be unique across the 7-cue set (no slug collisions).
##   3. Resolve to a well-formed AudioStreamWAV when streams are built.
##
## Synthesis paths reuse `_make_chord` already covered by sound_manager_test.gd
## (shape correctness for a single chord). This file checks the SKILL_* cue
## registry shape — that each of the 7 mapped skill_ids has a stream entry.
extends GdUnitTestSuite

const SoundManagerScript: GDScript = preload("res://src/feature/audio/sound_manager.gd")


## Returns the 7 SFX_SKILL_* constants as a StringName array.
func _skill_sfx_constants() -> Array[StringName]:
	return [
		SoundManagerScript.SFX_SKILL_DRAGON_BLADE,
		SoundManagerScript.SFX_SKILL_THUNDER_ROAR,
		SoundManagerScript.SFX_SKILL_INSPIRE,
		SoundManagerScript.SFX_SKILL_PIERCING_VOLLEY,
		SoundManagerScript.SFX_SKILL_CHARM,
		SoundManagerScript.SFX_SKILL_STRATEGIST,
		SoundManagerScript.SFX_SKILL_NAVAL_STRATEGY,
	]


# ─── Constants are non-empty + unique ────────────────────────────────────────


func test_skill_sfx_constants_are_non_empty() -> void:
	for sfx_id: StringName in _skill_sfx_constants():
		assert_bool(String(sfx_id).is_empty()).override_failure_message(
			"SFX_SKILL_* constant must not be empty: got '%s'" % String(sfx_id)
		).is_false()


func test_skill_sfx_constants_are_unique() -> void:
	var seen: Dictionary = {}
	for sfx_id: StringName in _skill_sfx_constants():
		assert_bool(seen.has(sfx_id)).override_failure_message(
			"SFX_SKILL_* slug collision: '%s' appears twice" % String(sfx_id)
		).is_false()
		seen[sfx_id] = true


# ─── Stream registry coverage ────────────────────────────────────────────────


func test_build_procedural_streams_registers_every_skill_sfx() -> void:
	# Construct a fresh non-autoload instance so we can call
	# `_build_procedural_streams` directly without the headless _ready short-circuit
	# (the autoload at /root/SoundManager skips synthesis when enabled=false).
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	sm._build_procedural_streams()
	for sfx_id: StringName in _skill_sfx_constants():
		assert_bool(sm._streams.has(sfx_id)).override_failure_message(
			"SFX_SKILL_* missing from _streams after _build_procedural_streams: '%s'"
				% String(sfx_id)
		).is_true()
		var stream: AudioStreamWAV = sm._streams[sfx_id] as AudioStreamWAV
		assert_object(stream).override_failure_message(
			"SFX_SKILL_* stream entry must be AudioStreamWAV, not null: '%s'"
				% String(sfx_id)
		).is_not_null()
		assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_int(stream.mix_rate).is_equal(22050)
		assert_bool(stream.stereo).is_false()
		assert_int(stream.data.size()).override_failure_message(
			"SFX_SKILL_* stream '%s' must have non-empty PCM data" % String(sfx_id)
		).is_greater(0)


# ─── Generic SFX_SKILL fallback still present ────────────────────────────────


func test_generic_sfx_skill_still_registered() -> void:
	# Session-20 adds the 7 variants but keeps SFX_SKILL as the fallback cue
	# referenced by battle_scene._sfx_for_skill for any unwired skill_id.
	var sm: Node = SoundManagerScript.new()
	auto_free(sm)
	sm._build_procedural_streams()
	assert_bool(sm._streams.has(SoundManagerScript.SFX_SKILL)).override_failure_message(
		"SFX_SKILL (generic fallback) must remain registered"
	).is_true()
