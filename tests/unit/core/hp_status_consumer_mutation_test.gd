# DOCUMENTED FAIL-STATE — convention is sole defense per R-5
#
# This test demonstrates that mutating returned Array[StatusEffect] IS visible cross-call.
# `get_status_effects` returns a shallow Array copy; the StatusEffect Resources INSIDE
# are SHARED references. Consumer mutation of `effect.remaining_turns` corrupts authoritative state.
#
# Mitigation: forbidden_pattern hp_status_consumer_mutation; source comment "DO NOT MUTATE";
# lint script tools/ci/lint_hp_status_consumer_mutation.sh validates this file is present.
#
# This test serves as regression guard — if the API is changed to fully duplicate the
# StatusEffect Resources (deep copy), this test would start failing AND should be UPDATED
# to assert the new immutability contract.

extends GdUnitTestSuite

## hp_status_consumer_mutation_test.gd
## Documented FAIL-STATE regression for HP/Status story-008 AC-3 + AC-10.
## This test PASSES by asserting the corruption IS observable (not that it is blocked).
##
## Governing ADR: ADR-0010 — HP/Status R-5 + Verification §12
## Design reference: production/epics/hp-status/story-008-perf-lints-and-td-entries.md §10


# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Resets BalanceConstants + UnitRole static caches.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	add_child(_controller)


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	return hero


# ── AC-3 + AC-10: Documented FAIL-STATE — consumer mutation corrupts authoritative state ──

## This test asserts the mutation IS visible (corruption proves convention is sole defense).
## get_status_effects returns a shallow copy: the Array is new, but StatusEffect References inside
## are SHARED with the authoritative _state_by_unit entry. Mutating `effects[0].remaining_turns`
## modifies the shared Resource instance — the next get_status_effects call reflects the mutation.
##
## If this test FAILS (i.e., remaining_turns is NOT 999 after mutation), it means:
##   - get_status_effects was changed to deep-copy the StatusEffect Resources
##   - This test should then be UPDATED to assert the new immutability contract
func test_consumer_mutation_corrupts_authoritative_state_documented_fail_state() -> void:
	# Arrange: initialize unit + apply DEMORALIZED (remaining_turns = template default = 4)
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var applied: bool = _controller.apply_status(1, &"demoralized", -1, 99)
	assert_bool(applied).override_failure_message(
		"Precondition: apply_status must succeed for this documented fail-state test to be valid"
	).is_true()

	# Verify precondition: initial remaining_turns value before mutation
	var effects_v1: Array = _controller.get_status_effects(1)
	assert_int(effects_v1.size()).override_failure_message(
		"Precondition: unit must have exactly 1 status effect after apply_status"
	).is_equal(1)

	# Act: mutate the returned StatusEffect Resource (FORBIDDEN by convention per R-5)
	# DO NOT MUTATE returned StatusEffect refs — this is the documented violation behavior
	var effect: StatusEffect = effects_v1[0] as StatusEffect
	effect.remaining_turns = 999

	# Assert: the mutation IS visible in the next get_status_effects call.
	# This PROVES the shared-reference hazard: convention is the sole defense.
	var effects_v2: Array = _controller.get_status_effects(1)
	var remaining_after_mutation: int = (effects_v2[0] as StatusEffect).remaining_turns
	assert_int(remaining_after_mutation).override_failure_message(
		("DOCUMENTED FAIL-STATE: remaining_turns after consumer mutation = %d; expected 999. "
		+ "If this assertion fails, get_status_effects was changed to deep-copy StatusEffect Resources — "
		+ "update this test to assert the new immutability contract instead.") % remaining_after_mutation
	).is_equal(999)
