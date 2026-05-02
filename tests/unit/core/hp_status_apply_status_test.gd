extends GdUnitTestSuite

## hp_status_apply_status_test.gd
## Unit tests for HP/Status story-005: apply_status + CR-5c/d/e + CR-7 mutex + .duplicate().
## Covers AC-1..AC-12. AC-13 verified via full-suite regression.
##
## Governing ADR: ADR-0010 — HP/Status §8 status effect lifecycle + §10 CR-7 mutex + §5 API contract.
## Design reference: production/epics/hp-status/story-005-apply-status-and-cr5-cr7-mutex.md
##
## G-15: before_test() / after_test() canonical hooks with BalanceConstants + UnitRole reset.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.
## G-24: RHS dict-access casts wrapped in parens in == expressions.
## G-23: No is_not_equal_approx — use is_not_equal for exact float inequality.

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


# ── Hero fixture builder (mirrors hp_status_initialize_unit_test.gd) ─────────

## Builds a minimal HeroData with explicitly specified base_hp_seed.
## Default all other stats to defaults so callers only override what matters.
func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	return hero


# ── AC-1: CR-5c POISON refresh ────────────────────────────────────────────────

## AC-1: Re-apply same effect_id same source → refresh remaining_turns + update source_unit_id.
## status_effects.size() unchanged at 1; remaining_turns refreshed to template default (3).
func test_cr5c_poison_refresh_same_effect_id_updates_turns_and_source() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	var result_first: bool = _controller.apply_status(1, &"poison", -1, 99)

	# Assert first apply succeeded
	assert_bool(result_first).override_failure_message(
		"AC-1 precondition: first POISON apply must return true"
	).is_true()
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-1 precondition: size must be 1 after first POISON apply"
	).is_equal(1)

	# Act: re-apply same effect with different source
	var result_refresh: bool = _controller.apply_status(1, &"poison", -1, 42)

	# Assert
	var effects: Array = _controller._state_by_unit[1].status_effects
	assert_bool(result_refresh).override_failure_message(
		"AC-1: POISON refresh must return true"
	).is_true()
	assert_int(effects.size()).override_failure_message(
		"AC-1: size must still be 1 after POISON refresh (no stacking)"
	).is_equal(1)
	var effect: StatusEffect = effects[0] as StatusEffect
	assert_int(effect.remaining_turns).override_failure_message(
		("AC-1: remaining_turns must be refreshed to POISON_DEFAULT_DURATION=3; "
		+ "got %d") % effect.remaining_turns
	).is_equal(3)
	assert_int(effect.source_unit_id).override_failure_message(
		("AC-1: source_unit_id must be updated to 42 on refresh; "
		+ "got %d") % effect.source_unit_id
	).is_equal(42)


# ── AC-2: CR-5d different effect_id coexist ──────────────────────────────────

## AC-2: POISON active then apply DEMORALIZED → size grows 1→2; both active.
func test_cr5d_different_effect_ids_coexist_up_to_max() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"poison", -1, 99)

	# Act
	var result: bool = _controller.apply_status(1, &"demoralized", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-2: DEMORALIZED apply after POISON must return true"
	).is_true()
	var effects: Array = _controller._state_by_unit[1].status_effects
	assert_int(effects.size()).override_failure_message(
		"AC-2: size must be 2 after POISON + DEMORALIZED; no eviction below cap"
	).is_equal(2)
	assert_bool((effects[0] as StatusEffect).effect_id == &"poison").override_failure_message(
		"AC-2: effects[0].effect_id must be &\"poison\" (insertion order preserved)"
	).is_true()
	assert_bool((effects[1] as StatusEffect).effect_id == &"demoralized").override_failure_message(
		"AC-2: effects[1].effect_id must be &\"demoralized\" (insertion order preserved)"
	).is_true()


# ── AC-3: CR-5e slot eviction ────────────────────────────────────────────────

## AC-3: 3 effects [POISON, DEMORALIZED, INSPIRED] at MAX cap; apply EXHAUSTED →
## size stays 3; POISON evicted via pop_front(); final order [DEMORALIZED, INSPIRED, EXHAUSTED].
## NOTE: EXHAUSTED + DEFEND_STANCE would trigger CR-7 — composition avoids DEFEND_STANCE.
func test_cr5e_slot_eviction_oldest_evicted_when_cap_reached() -> void:
	# Arrange: fill all 3 slots
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"poison", -1, 99)
	_controller.apply_status(1, &"demoralized", -1, 99)
	_controller.apply_status(1, &"inspired", -1, 99)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-3 precondition: 3 effects must fill the cap"
	).is_equal(3)

	# Act: apply 4th effect — must evict POISON (oldest, index 0)
	var result: bool = _controller.apply_status(1, &"exhausted", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-3: EXHAUSTED apply at cap must return true (eviction + append)"
	).is_true()
	var effects: Array = _controller._state_by_unit[1].status_effects
	assert_int(effects.size()).override_failure_message(
		"AC-3: size must remain 3 after eviction + append"
	).is_equal(3)
	assert_bool((effects[0] as StatusEffect).effect_id == &"demoralized").override_failure_message(
		("AC-3: effects[0] must be &\"demoralized\" after POISON evicted; "
		+ "got %s") % (effects[0] as StatusEffect).effect_id
	).is_true()
	assert_bool((effects[1] as StatusEffect).effect_id == &"inspired").override_failure_message(
		("AC-3: effects[1] must be &\"inspired\"; "
		+ "got %s") % (effects[1] as StatusEffect).effect_id
	).is_true()
	assert_bool((effects[2] as StatusEffect).effect_id == &"exhausted").override_failure_message(
		("AC-3: effects[2] must be &\"exhausted\" (newly appended); "
		+ "got %s") % (effects[2] as StatusEffect).effect_id
	).is_true()


# ── AC-4: CR-7 EXHAUSTED → DEFEND_STANCE rejection ───────────────────────────

## AC-4: EXHAUSTED active → apply_status(defend_stance) returns false; size unchanged.
func test_cr7_exhausted_blocks_defend_stance_application() -> void:
	# Arrange: apply EXHAUSTED first
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"exhausted", -1, 99)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-4 precondition: EXHAUSTED must be active (size=1)"
	).is_equal(1)

	# Act: attempt to apply DEFEND_STANCE while EXHAUSTED
	var result: bool = _controller.apply_status(1, &"defend_stance", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-4: apply_status(defend_stance) must return false when EXHAUSTED is active"
	).is_false()
	var effects: Array = _controller._state_by_unit[1].status_effects
	assert_int(effects.size()).override_failure_message(
		"AC-4: size must remain 1 (DEFEND_STANCE rejected; no state mutation)"
	).is_equal(1)
	assert_bool((effects[0] as StatusEffect).effect_id == &"exhausted").override_failure_message(
		"AC-4: only EXHAUSTED must remain active after rejection"
	).is_true()


# ── AC-5: CR-7 DEFEND_STANCE → EXHAUSTED force-remove ────────────────────────

## AC-5: DEFEND_STANCE active → apply_status(exhausted) returns true;
## DEFEND_STANCE force-removed BEFORE EXHAUSTED appended; final size=1; only EXHAUSTED present.
func test_cr7_defend_stance_force_removed_when_exhausted_applied() -> void:
	# Arrange: apply DEFEND_STANCE first
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"defend_stance", -1, 99)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-5 precondition: DEFEND_STANCE must be active (size=1)"
	).is_equal(1)

	# Act: apply EXHAUSTED — must force-remove DEFEND_STANCE first
	var result: bool = _controller.apply_status(1, &"exhausted", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-5: apply_status(exhausted) must return true when DEFEND_STANCE is active"
	).is_true()
	var state: UnitHPState = _controller._state_by_unit[1]
	assert_int(state.status_effects.size()).override_failure_message(
		"AC-5: size must be 1 (DEFEND_STANCE removed, EXHAUSTED appended — net zero growth)"
	).is_equal(1)
	assert_bool((state.status_effects[0] as StatusEffect).effect_id == &"exhausted").override_failure_message(
		"AC-5: only EXHAUSTED must be in status_effects after force-remove + append"
	).is_true()
	# Direct helper call confirms DEFEND_STANCE is gone (test-private access per ADR-0010 §13)
	assert_bool(_controller._has_status(state, &"defend_stance")).override_failure_message(
		"AC-5: _has_status(defend_stance) must be false after CR-7 force-remove"
	).is_false()


# ── AC-6: Template load null on missing effect_id ────────────────────────────

## AC-6: apply_status(unit, &"poison_typo", ...) → load() returns null → push_error fires
## → return false; status_effects unchanged.
func test_template_load_null_on_missing_effect_id_returns_false() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)

	# Act: typo in effect_template_id — no .tres exists for this name
	var result: bool = _controller.apply_status(1, &"poison_typo", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-6: apply_status with unknown template must return false"
	).is_false()
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-6: status_effects must remain empty after failed load"
	).is_equal(0)


# ── AC-7: Dead / unknown unit early-return ────────────────────────────────────

## AC-7a: Dead unit (current_hp=0) → apply_status returns false; no state mutation.
func test_dead_unit_early_return() -> void:
	# Arrange: init unit then force HP to 0
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller._state_by_unit[1].current_hp = 0

	# Act
	var result: bool = _controller.apply_status(1, &"poison", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-7a: apply_status on dead unit (current_hp=0) must return false"
	).is_false()
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-7a: status_effects must remain empty for dead unit"
	).is_equal(0)


## AC-7b: Unknown unit_id (not initialized) → apply_status returns false.
func test_unknown_unit_early_return() -> void:
	# Arrange: empty controller — unit 99 never initialized

	# Act
	var result: bool = _controller.apply_status(99, &"poison", -1, 99)

	# Assert
	assert_bool(result).override_failure_message(
		"AC-7b: apply_status on unknown unit_id=99 must return false"
	).is_false()


# ── AC-8: duration_override == -1 uses template default ─────────────────────

## AC-8: apply POISON with override=-1 → instance.remaining_turns == 3 (POISON_DEFAULT_DURATION).
func test_duration_override_minus_one_uses_template_default() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)

	# Act
	_controller.apply_status(1, &"poison", -1, 99)

	# Assert
	var effect: StatusEffect = _controller._state_by_unit[1].status_effects[0] as StatusEffect
	assert_int(effect.remaining_turns).override_failure_message(
		("AC-8: remaining_turns with override=-1 must equal POISON_DEFAULT_DURATION=3; "
		+ "got %d") % effect.remaining_turns
	).is_equal(3)


# ── AC-9: duration_override >= 0 overrides + template unchanged ──────────────

## AC-9: apply POISON with override=5 → instance.remaining_turns == 5;
## re-load template directly → template.remaining_turns still 3 (template NOT mutated).
func test_duration_override_non_negative_overrides_and_template_unchanged() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)

	# Act
	_controller.apply_status(1, &"poison", 5, 99)

	# Assert: instance has override duration
	var effect: StatusEffect = _controller._state_by_unit[1].status_effects[0] as StatusEffect
	assert_int(effect.remaining_turns).override_failure_message(
		("AC-9: remaining_turns with override=5 must be 5; "
		+ "got %d") % effect.remaining_turns
	).is_equal(5)

	# Assert: template is unchanged (proves .duplicate() was used, NOT direct mutation)
	var template: StatusEffect = load("res://assets/data/status_effects/poison.tres") as StatusEffect
	assert_int(template.remaining_turns).override_failure_message(
		("AC-9: template.remaining_turns must still be 3 (template not mutated by duplicate); "
		+ "got %d") % template.remaining_turns
	).is_equal(3)


# ── AC-10: Shallow .duplicate() instance independence + tick_effect SHARED ───

## AC-10: Two units with POISON — remaining_turns independent; tick_effect is SAME reference.
## Uses GdUnit4 v6.1.2 assert_object(...).is_same(...) for reference identity per spec.
func test_shallow_duplicate_instance_independence_and_shared_tick_effect() -> void:
	# Arrange: two units
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.initialize_unit(2, _make_hero(40), UnitRole.UnitClass.CAVALRY)

	# Act: apply POISON to unit 1 (default duration) and unit 2 (override 7)
	_controller.apply_status(1, &"poison", -1, 99)
	_controller.apply_status(2, &"poison", 7, 99)

	# Assert: remaining_turns are independent
	var p1: StatusEffect = _controller._state_by_unit[1].status_effects[0] as StatusEffect
	var p2: StatusEffect = _controller._state_by_unit[2].status_effects[0] as StatusEffect
	assert_int(p1.remaining_turns).override_failure_message(
		("AC-10: unit 1 POISON remaining_turns must be 3 (default); "
		+ "got %d") % p1.remaining_turns
	).is_equal(3)
	assert_int(p2.remaining_turns).override_failure_message(
		("AC-10: unit 2 POISON remaining_turns must be 7 (override); "
		+ "got %d") % p2.remaining_turns
	).is_equal(7)

	# Assert: tick_effect is the SAME shared reference (shallow duplicate per ADR-0010 §4)
	# GdUnit4 v6.1.2 is_same() tests object reference identity
	assert_object(p1.tick_effect).override_failure_message(
		"AC-10: p1.tick_effect must not be null (POISON has a tick_effect)"
	).is_not_null()
	assert_object(p1.tick_effect).override_failure_message(
		("AC-10: p1.tick_effect and p2.tick_effect must be the SAME reference "
		+ "(shallow duplicate shares the sub-Resource per ADR-0010 §4)")
	).is_same(p2.tick_effect)


# ── AC-11: Slot eviction does NOT trigger DoT tick ────────────────────────────

## AC-11: POISON evicted via CR-5e during apply_status → current_hp unchanged.
## Eviction is silent — _apply_turn_start_tick is NOT a side effect of apply_status.
func test_slot_eviction_does_not_trigger_dot_tick() -> void:
	# Arrange: fill all 3 slots; POISON is at index 0 (oldest)
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"poison", -1, 99)
	_controller.apply_status(1, &"demoralized", -1, 99)
	_controller.apply_status(1, &"inspired", -1, 99)
	var hp_before: int = _controller.get_current_hp(1)

	# Act: apply 4th effect — POISON is evicted via pop_front()
	_controller.apply_status(1, &"exhausted", -1, 99)

	# Assert: HP unchanged (no DoT side effect from eviction)
	var hp_after: int = _controller.get_current_hp(1)
	assert_int(hp_after).override_failure_message(
		("AC-11: current_hp must be unchanged after POISON eviction via CR-5e; "
		+ "before=%d after=%d (DoT tick must NOT fire on eviction)") % [hp_before, hp_after]
	).is_equal(hp_before)


# ── AC-12: CR-5b apply timing flexibility ─────────────────────────────────────

## AC-12: init → apply_damage → apply_status(POISON) → apply_damage → apply_status(POISON refresh)
## → final state: cumulative damage correct + POISON refreshed + size=1.
## Uses CAVALRY to skip Shield Wall passive absorption (CAVALRY-substitution discipline from story-003).
func test_cr5b_apply_timing_flexibility_interleaved_damage_and_status() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	var max_hp: int = _controller.get_max_hp(1)

	# Act: sequence per AC-12 spec
	_controller.apply_damage(1, 5, 0, [])           # damage 1 — CAVALRY skips Shield Wall
	_controller.apply_status(1, &"poison", -1, 99)  # first POISON apply
	_controller.apply_damage(1, 5, 0, [])           # damage 2
	_controller.apply_status(1, &"poison", -1, 99)  # POISON refresh (CR-5c)

	# Assert: cumulative damage = 10 (2 × 5, no MIN_DAMAGE clip needed)
	var expected_hp: int = max_hp - 10
	var actual_hp: int = _controller.get_current_hp(1)
	assert_int(actual_hp).override_failure_message(
		("AC-12: current_hp must be max_hp - 10 = %d after 2×5 damage; "
		+ "got %d") % [expected_hp, actual_hp]
	).is_equal(expected_hp)

	# Assert: POISON refreshed (not stacked) — size=1
	var effects: Array = _controller._state_by_unit[1].status_effects
	assert_int(effects.size()).override_failure_message(
		"AC-12: status_effects size must be 1 (POISON refreshed, not stacked)"
	).is_equal(1)

	# Assert: remaining_turns refreshed to default (3) after second apply
	var effect: StatusEffect = effects[0] as StatusEffect
	assert_int(effect.remaining_turns).override_failure_message(
		("AC-12: POISON remaining_turns must be 3 (refreshed to default); "
		+ "got %d") % effect.remaining_turns
	).is_equal(3)
