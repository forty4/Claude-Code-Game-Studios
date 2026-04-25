extends GdUnitTestSuite

## terrain_effect_isolation_test.gd
## AC-7: Multi-suite isolation regression — the discipline-establishing test for
## the entire terrain-effect epic (ADR-0008 §Risks line 562).
##
## Purpose: proves that Suite A mutating TerrainEffect static state does NOT
## bleed into Suite B when Suite B calls reset_for_tests() in before_each().
##
## In a GdUnit4 run, test suites (GdUnitTestSuite subclasses) may run in any
## order and share the same Godot VM / GDScript runtime. Static vars persist
## across suite boundaries within a session. This test verifies the canary
## contract: reset_for_tests() is the complete isolation boundary.
##
## Governing ADR: ADR-0008 Terrain Effect System §Risks line 562.
## Related TRs:   TR-terrain-effect-010.

const TERRAIN_EFFECT_PATH: String = "res://src/core/terrain_effect.gd"


func before_each() -> void:
	# Suite B discipline: reset_for_tests() in every before_each().
	TerrainEffect.reset_for_tests()


# ── Suite A simulation (state mutation helper) ───────────────────────────────


## Simulates Suite A mutating ALL 8 TerrainEffect static state vars as a prior
## test suite would. Complete coverage ensures the canary catches bleed in any
## var, not just the most obvious ones — if reset_for_tests() ever fails to
## reset a var, this canary fires.
func _simulate_suite_a_mutation() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	script.set("_config_loaded", true)
	script.set("_terrain_table", {0: "suite_a_dirty", 1: "suite_a_dirty"})
	script.set("_elevation_table", {-1: "suite_a_dirty"})
	script.set("_max_defense_reduction", 99)
	script.set("_max_evasion", 77)
	script.set("_evasion_weight", 9.9)
	script.set("_max_possible_score", 999.0)
	script.set("_cost_default_multiplier", 5)


# ── AC-7: Multi-suite isolation regression ───────────────────────────────────


## AC-7: After Suite A mutates state, Suite B's reset_for_tests() restores all
## static vars to compile-time defaults with no bleed.
## Given: Suite A mutations applied (simulated inline).
## When:  reset_for_tests() called (simulating Suite B's before_each()).
## Then:  _config_loaded==false, _max_defense_reduction==30 — no state bleed.
## This is the canary test for ADR-0008 §Risks line 562.
## CI must treat failure of this test as an immediate epic-blocker.
func test_terrain_effect_isolation_suite_b_sees_pristine_state_after_suite_a_mutation() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# ── Simulate Suite A (mutates static state, does NOT call reset_for_tests) ──
	_simulate_suite_a_mutation()

	# Verify Suite A mutations are visible (proves the seam works correctly)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"Pre-condition: Suite A must have set _config_loaded=true"
	).is_true()
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		"Pre-condition: Suite A must have set _max_defense_reduction=99"
	).is_equal(99)

	# ── Simulate Suite B: before_each() calls reset_for_tests() ─────────────────
	TerrainEffect.reset_for_tests()

	# ── Suite B assertions: pristine state, no bleed ─────────────────────────────
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-7 CANARY: _config_loaded must be false after Suite B reset_for_tests(); Suite A bleed detected!"
	).is_false()
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("AC-7 CANARY: _max_defense_reduction must be 30 after Suite B reset_for_tests();"
		+ " Suite A bleed detected! Got: %d") % script.get("_max_defense_reduction")
	).is_equal(30)
	assert_int(script.get("_max_evasion") as int).override_failure_message(
		"AC-7 CANARY: _max_evasion must be 30 after Suite B reset_for_tests()"
	).is_equal(30)
	assert_float(script.get("_evasion_weight") as float).override_failure_message(
		"AC-7 CANARY: _evasion_weight must be ≈1.2 after Suite B reset_for_tests()"
	).is_equal_approx(1.2, 0.00001)
	assert_float(script.get("_max_possible_score") as float).override_failure_message(
		"AC-7 CANARY: _max_possible_score must be ≈43.0 after Suite B reset_for_tests()"
	).is_equal_approx(43.0, 0.00001)
	assert_int(script.get("_cost_default_multiplier") as int).override_failure_message(
		"AC-7 CANARY: _cost_default_multiplier must be 1 after Suite B reset_for_tests()"
	).is_equal(1)
	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		"AC-7 CANARY: _terrain_table must be empty after Suite B reset_for_tests()"
	).is_equal(0)
	assert_int((script.get("_elevation_table") as Dictionary).size()).override_failure_message(
		"AC-7 CANARY: _elevation_table must be empty after Suite B reset_for_tests()"
	).is_equal(0)
