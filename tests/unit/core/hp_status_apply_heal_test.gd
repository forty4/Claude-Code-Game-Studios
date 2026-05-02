extends GdUnitTestSuite

## hp_status_apply_heal_test.gd
## Unit tests for HP/Status story-004: apply_heal F-2 4-step pipeline +
##   EXHAUSTED multiplier + overheal prevention + dead-unit zero-return.
## Covers AC-1..AC-9. AC-10 verified via full-suite regression.
##
## Governing ADR: ADR-0010 — HP/Status §7 healing pipeline + §5 API contract.
## Design reference: production/epics/hp-status/story-004-apply-heal-and-f2-pipeline.md
##
## G-15: before_test() / after_test() canonical hooks with BalanceConstants + UnitRole reset.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.
## G-22: AC-9 no-emit invariant via FileAccess source-content scan.
## G-24: RHS dict-access casts wrapped in parens in == expressions.

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

## Builds a minimal HeroData with explicitly specified base_hp_seed.
## Default all other stats to defaults so callers only override what matters.
func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	return hero


# ── AC-1: Basic heal pipeline (GDD AC-07) ────────────────────────────────────

## AC-1 (GDD AC-07): unit at current_hp = max_hp - 56; apply_heal(1, 26, 99) → return 26;
## current_hp increases by exactly 26 (relative delta, not hardcoded absolute value).
func test_basic_heal_returns_heal_amount_and_increases_hp() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)
	_controller._state_by_unit[1].current_hp = max_hp - 56

	# Act
	var result: int = _controller.apply_heal(1, 26, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-1: apply_heal must return 26 (actual heal applied); "
		+ "got %d") % result
	).is_equal(26)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-1: current_hp must be max_hp - 30 = %d after +26 heal; "
		+ "got %d") % [max_hp - 30, _controller.get_current_hp(1)]
	).is_equal(max_hp - 30)


# ── AC-2: Full-HP unit returns 0 (GDD AC-08 / EC-09) ────────────────────────

## AC-2 (GDD AC-08 / EC-09): Full-HP unit; apply_heal(1, 26, 99) → return 0;
## current_hp unchanged (overheal prevention via Step 3 min(26, 0) = 0).
func test_full_hp_unit_heal_returns_zero_unchanged() -> void:
	# Arrange: initialize_unit sets current_hp = max_hp per CR-1a
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)

	# Act
	var result: int = _controller.apply_heal(1, 26, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-2: apply_heal on full-HP unit must return 0; "
		+ "got %d") % result
	).is_equal(0)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-2: current_hp must remain at max_hp=%d after heal on full-HP; "
		+ "got %d") % [max_hp, _controller.get_current_hp(1)]
	).is_equal(max_hp)


# ── AC-3: EXHAUSTED multiplier via production apply_status pathway (GDD AC-09) ──

## AC-3 (GDD AC-09): EXHAUSTED unit at current_hp=50 (INFANTRY); apply_heal(1, 39, 99) →
## Step 2: int(max(1, floor(39 × 0.5))) = int(max(1, 19.5)) = int(19.5) = 19;
## Step 3: min(19, max_hp - 50); Step 4: current_hp = 50 + 19 = 69; return 19.
## Uses production apply_status pathway (story-005 → story-004 chain validation).
func test_exhausted_multiplier_halves_heal_via_production_apply_status() -> void:
	# Arrange: init INFANTRY (large max_hp so overheal prevention doesn't clip)
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)
	# Apply EXHAUSTED via production pathway (validates story-005 → story-004 interop)
	var status_applied: bool = _controller.apply_status(1, &"exhausted", -1, 99)
	assert_bool(status_applied).override_failure_message(
		"AC-3 precondition: apply_status(exhausted) must return true"
	).is_true()
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-3 precondition: status_effects must have 1 entry after apply_status(exhausted)"
	).is_equal(1)
	assert_bool(
		(_controller._state_by_unit[1].status_effects[0] as StatusEffect).effect_id == &"exhausted"
	).override_failure_message(
		"AC-3 precondition: status_effects[0].effect_id must be &\"exhausted\""
	).is_true()
	# Force current_hp = 50 (well below max_hp to avoid overheal clipping at Step 3)
	_controller._state_by_unit[1].current_hp = 50
	# Guard: max_hp must be > 69 so Step 3 does not clip the 19-heal
	assert_bool(max_hp > 69).override_failure_message(
		("AC-3 precondition: INFANTRY max_hp=%d must be > 69 so Step 3 min(19, max_hp-50) = 19; "
		+ "update fixture seed if UnitRole tuning changed") % max_hp
	).is_true()

	# Act: raw_heal=39; Step 2: int(max(1, floor(39*0.5))) = int(max(1,19.0)) = 19
	var result: int = _controller.apply_heal(1, 39, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-3: EXHAUSTED halved heal: int(max(1,floor(39×0.5)))=19; "
		+ "got %d") % result
	).is_equal(19)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-3: current_hp must be 50+19=69 after EXHAUSTED heal; "
		+ "got %d") % _controller.get_current_hp(1)
	).is_equal(69)


# ── AC-4a: Dead unit returns 0 (CR-4b) ───────────────────────────────────────

## AC-4a (GDD AC-10 / CR-4b): Dead unit (current_hp=0) → apply_heal returns 0;
## current_hp stays 0; pipeline does NOT enter.
func test_dead_unit_zero_return() -> void:
	# Arrange: init unit then force HP to 0
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 0

	# Act
	var result: int = _controller.apply_heal(1, 26, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-4a: apply_heal on dead unit (current_hp=0) must return 0; "
		+ "got %d") % result
	).is_equal(0)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-4a: current_hp must remain 0 after heal attempt on dead unit"
	).is_equal(0)


# ── AC-4b: Unknown unit returns 0 (CR-4b) ────────────────────────────────────

## AC-4b (GDD AC-10 / CR-4b): Unknown unit_id (never initialized) → apply_heal returns 0.
func test_unknown_unit_zero_return() -> void:
	# Arrange: empty controller — unit 99 never initialized

	# Act
	var result: int = _controller.apply_heal(99, 26, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-4b: apply_heal on unknown unit_id=99 must return 0; "
		+ "got %d") % result
	).is_equal(0)


# ── AC-5: EXHAUSTED preserves minimum heal of 1 (EC-08) ─────────────────────

## AC-5 (EC-08): EXHAUSTED unit; apply_heal(1, 1, 99) →
## Step 2: int(max(1, floor(1×0.5))) = int(max(1, 0.0)) = int(1) = 1;
## EXHAUSTED cannot reduce heal below 1; return 1; current_hp += 1.
func test_exhausted_preserves_minimum_heal_of_one() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)
	_controller.apply_status(1, &"exhausted", -1, 99)
	_controller._state_by_unit[1].current_hp = 50
	# Guard: max_hp > 51 so Step 3 min(1, max_hp-50) = 1
	assert_bool(max_hp > 51).override_failure_message(
		("AC-5 precondition: INFANTRY max_hp=%d must be > 51") % max_hp
	).is_true()

	# Act: raw_heal=1; Step 2: int(max(1, floor(0.5))) = int(max(1, 0.0)) = 1
	var result: int = _controller.apply_heal(1, 1, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-5: EXHAUSTED must not reduce heal below 1; raw_heal=1 → result must be 1; "
		+ "got %d") % result
	).is_equal(1)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-5: current_hp must be 51 (50+1) after min-heal-1 guard; "
		+ "got %d") % _controller.get_current_hp(1)
	).is_equal(51)


# ── AC-6: Overheal prevention — large raw_heal clamped to room remaining ─────

## AC-6: unit at current_hp = max_hp - 5; apply_heal(1, 100, 99) →
## Step 3: min(100, 5) = 5; return 5; current_hp = max_hp exactly.
func test_overheal_prevention_clamps_to_remaining_room() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)
	_controller._state_by_unit[1].current_hp = max_hp - 5

	# Act
	var result: int = _controller.apply_heal(1, 100, 99)

	# Assert
	assert_int(result).override_failure_message(
		("AC-6: overheal prevention: min(100, 5)=5; return must be 5; "
		+ "got %d") % result
	).is_equal(5)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-6: current_hp must be exactly max_hp=%d after overheal-clamped heal; "
		+ "got %d") % [max_hp, _controller.get_current_hp(1)]
	).is_equal(max_hp)


# ── AC-7: Return value = actual HP restored (not raw_heal) ───────────────────

## AC-7: current_hp = max_hp - 10; apply_heal(1, 50, 99) → return 10 (NOT 50);
## current_hp == max_hp. Confirms caller can inspect return for UI feedback.
func test_return_value_is_actual_heal_not_raw_heal() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)
	_controller._state_by_unit[1].current_hp = max_hp - 10

	# Act
	var result: int = _controller.apply_heal(1, 50, 99)

	# Assert: returned value is the actual HP restored, not the raw_heal input
	assert_int(result).override_failure_message(
		("AC-7: return must be actual heal_amount=10 (not raw_heal=50); "
		+ "got %d") % result
	).is_equal(10)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-7: current_hp must be max_hp=%d after partial overheal; "
		+ "got %d") % [max_hp, _controller.get_current_hp(1)]
	).is_equal(max_hp)


# ── AC-8: source_unit_id NOT consumed — reflexive and external heals identical ─

## AC-8: source_unit_id ∈ {-1, 99, unit_id} all produce identical return + HP delta.
## 3 units initialized identically; each healed with different source_unit_id;
## all returns and final HP must be equal.
func test_source_unit_id_not_consumed_reflexive_and_external_identical() -> void:
	# Arrange: 3 units initialized with same hero + class + same pre-heal HP
	var hero: HeroData = _make_hero(50)
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.INFANTRY)
	_controller.initialize_unit(2, hero, UnitRole.UnitClass.INFANTRY)
	_controller.initialize_unit(3, hero, UnitRole.UnitClass.INFANTRY)
	var max_hp: int = _controller.get_max_hp(1)
	var pre_heal_hp: int = max_hp - 20
	_controller._state_by_unit[1].current_hp = pre_heal_hp
	_controller._state_by_unit[2].current_hp = pre_heal_hp
	_controller._state_by_unit[3].current_hp = pre_heal_hp

	# Act: heal each with a different source_unit_id
	var result_minus1: int = _controller.apply_heal(1, 15, -1)      # source = -1 (sentinel)
	var result_external: int = _controller.apply_heal(2, 15, 99)    # source = external unit
	var result_reflexive: int = _controller.apply_heal(3, 15, 3)    # source = own unit_id

	# Assert: all three returns identical
	assert_int(result_minus1).override_failure_message(
		("AC-8: source_unit_id=-1 → return must be 15; "
		+ "got %d") % result_minus1
	).is_equal(15)
	assert_int(result_external).override_failure_message(
		("AC-8: source_unit_id=99 → return must be 15; "
		+ "got %d") % result_external
	).is_equal(15)
	assert_int(result_reflexive).override_failure_message(
		("AC-8: source_unit_id=unit_id (reflexive) → return must be 15; "
		+ "got %d") % result_reflexive
	).is_equal(15)
	# Assert: all three final HP identical
	var expected_hp: int = pre_heal_hp + 15
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-8: unit 1 (source=-1) current_hp must be %d; "
		+ "got %d") % [expected_hp, _controller.get_current_hp(1)]
	).is_equal(expected_hp)
	assert_int(_controller.get_current_hp(2)).override_failure_message(
		("AC-8: unit 2 (source=99) current_hp must be %d; "
		+ "got %d") % [expected_hp, _controller.get_current_hp(2)]
	).is_equal(expected_hp)
	assert_int(_controller.get_current_hp(3)).override_failure_message(
		("AC-8: unit 3 (reflexive source=3) current_hp must be %d; "
		+ "got %d") % [expected_hp, _controller.get_current_hp(3)]
	).is_equal(expected_hp)


# ── AC-9: No GameBus emit invariant (G-22 source-file scan pattern) ──────────

## AC-9: Source-file scan asserts apply_heal body has zero GameBus.*.emit( patterns.
## G-22 pattern: FileAccess.get_file_as_string reads source; extract body between
## func apply_heal( and the next func declaration; scan for GameBus. substring.
func test_apply_heal_body_has_no_gamebus_emit() -> void:
	# Arrange: read the production source file
	var source: String = FileAccess.get_file_as_string("res://src/core/hp_status_controller.gd")

	# Sanity check: file loaded and contains the function
	assert_bool(source.contains("func apply_heal(")).override_failure_message(
		"AC-9 sanity: source file must contain 'func apply_heal(' — FileAccess load failed or wrong path"
	).is_true()

	# Extract the apply_heal body: from the func declaration line to the next func declaration
	var func_start_idx: int = source.find("func apply_heal(")
	assert_bool(func_start_idx >= 0).override_failure_message(
		"AC-9: could not locate 'func apply_heal(' in source — extraction failed"
	).is_true()

	# Find the next func declaration after apply_heal
	var next_func_idx: int = source.find("\nfunc ", func_start_idx + 1)
	var apply_heal_body: String
	if next_func_idx >= 0:
		apply_heal_body = source.substr(func_start_idx, next_func_idx - func_start_idx)
	else:
		apply_heal_body = source.substr(func_start_idx)

	# Assert: body must not reference GameBus at all (apply_heal emits no signal per ADR-0010 §5)
	assert_bool(apply_heal_body.contains("GameBus.")).override_failure_message(
		("AC-9: apply_heal body must NOT contain 'GameBus.' — "
		+ "found illegal GameBus reference in F-2 pipeline body. "
		+ "apply_heal emits no signals per ADR-0010 §5.")
	).is_false()
