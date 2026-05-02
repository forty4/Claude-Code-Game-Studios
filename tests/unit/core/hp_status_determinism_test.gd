extends GdUnitTestSuite

## hp_status_determinism_test.gd
## Cross-platform determinism fixture for HP/Status story-008 AC-11.
## Runs a 50-step synthetic battle scenario and asserts final state matches a
## hardcoded macOS-Metal known-good baseline.
##
## F-1/F-2/F-3/F-4 use only integer arithmetic + floor() + clamp() — cross-platform
## identical by construction; test guards against future floating-point introduction.
##
## Governing ADR: ADR-0010 — HP/Status §Verification (1) cross-platform determinism
## Design reference: production/epics/hp-status/story-008-perf-lints-and-td-entries.md §11
##
## G-15: before_test() / after_test() canonical hooks with BalanceConstants + UnitRole reset.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.


# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController
var _map_grid_stub: MapGridStub


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	_map_grid_stub = MapGridStub.new()
	_controller._map_grid = _map_grid_stub
	_controller.add_child(_map_grid_stub)
	add_child(_controller)
	_map_grid_stub.set_dimensions_for_test(Vector2i(8, 8))
	_map_grid_stub.set_occupant_for_test(Vector2i(0, 0), 1)


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

## Minimal HeroData seeded for determinism test. Stat fields set explicitly so UnitRole
## computed stats are reproducible regardless of HeroData defaults.
func _make_hero_det(p_base_hp_seed: int, p_faction: int = 0) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	hero.faction = p_faction
	hero.stat_might = 80
	hero.stat_command = 80
	hero.stat_intellect = 80
	hero.base_initiative_seed = 60
	hero.move_range = 4
	return hero


# ── AC-11: 50-step synthetic battle determinism fixture ───────────────────────

## AC-11: 50-step synthetic battle sequence:
##   init (unit_id=1, INFANTRY, seed=50)
##   apply_damage × 10  (10 PHYSICAL hits of varying damage)
##   apply_heal  × 5    (5 heals of varying raw_heal)
##   apply_status × 8   (8 status applications: mix of demoralized + poison)
##   _apply_turn_start_tick × 27  (27 tick cycles)
##
## Final state assertions use hardcoded macOS-Metal known-good baseline values.
## These values were determined empirically by running this test on macOS (first run
## expects failures; actual values are then hardcoded here for the passing run).
##
## Cross-platform invariance: F-1/F-2/F-3/F-4 use only integer arithmetic + floor() + clamp()
## with no floating-point accumulation — bit-identical results guaranteed on all platforms.
func test_50_step_synthetic_battle_deterministic() -> void:
	# ── Init ──────────────────────────────────────────────────────────────────
	_controller.initialize_unit(1, _make_hero_det(50), UnitRole.UnitClass.INFANTRY)

	# ── apply_damage × 10 ─────────────────────────────────────────────────────
	# Mix of PHYSICAL (attack_type=0) hits; INFANTRY has SHIELD_WALL so PHYSICAL is reduced by SHIELD_WALL_FLAT=5
	_controller.apply_damage(1, 20, 0, [])   # PHYSICAL 20 — hit 1
	_controller.apply_damage(1, 15, 0, [])   # PHYSICAL 15 — hit 2
	_controller.apply_damage(1, 10, 0, [])   # PHYSICAL 10 — hit 3
	_controller.apply_damage(1, 8, 0, [])    # PHYSICAL 8  — hit 4
	_controller.apply_damage(1, 12, 1, [])   # MAGICAL 12 (bypasses shield wall) — hit 5
	_controller.apply_damage(1, 5, 0, [])    # PHYSICAL 5 → after SHIELD_WALL: 5-5=0 → MIN_DAMAGE=1 — hit 6
	_controller.apply_damage(1, 18, 0, [])   # PHYSICAL 18 — hit 7
	_controller.apply_damage(1, 7, 1, [])    # MAGICAL 7  — hit 8
	_controller.apply_damage(1, 3, 0, [])    # PHYSICAL 3 → after SHIELD_WALL: 3-5=-2 → MIN_DAMAGE=1 — hit 9
	_controller.apply_damage(1, 11, 0, [])   # PHYSICAL 11 — hit 10

	# If unit is dead at this point (HP reached 0), stop here — dead unit cannot be healed/statused.
	# Guard: only continue if unit is alive.
	if not _controller.is_alive(1):
		# Record state and assert against baseline (dead-end path)
		var final_hp_dead: int = _controller.get_current_hp(1)
		assert_int(final_hp_dead).override_failure_message(
			"AC-11 determinism (dead-after-damage): expected 0 HP (dead unit); got %d" % final_hp_dead
		).is_equal(0)
		return

	# ── apply_heal × 5 ───────────────────────────────────────────────────────
	_controller.apply_heal(1, 10, 99)   # heal 10 — heal 1
	_controller.apply_heal(1, 5, 99)    # heal 5  — heal 2
	_controller.apply_heal(1, 8, 99)    # heal 8  — heal 3
	_controller.apply_heal(1, 15, 99)   # heal 15 — heal 4
	_controller.apply_heal(1, 3, 99)    # heal 3  — heal 5

	# ── apply_status × 8 ─────────────────────────────────────────────────────
	_controller.apply_status(1, &"demoralized", -1, 99)   # status 1 — DEMORALIZED default duration
	_controller.apply_status(1, &"demoralized", 3, 99)    # status 2 — DEMORALIZED refresh to 3 turns (CR-5c)
	_controller.apply_status(1, &"poison", -1, 99)        # status 3 — POISON default duration
	_controller.apply_status(1, &"demoralized", -1, 99)   # status 4 — DEMORALIZED refresh to default (CR-5c)
	_controller.apply_status(1, &"poison", 2, 99)         # status 5 — POISON refresh to 2 turns (CR-5c)
	_controller.apply_status(1, &"demoralized", 1, 99)    # status 6 — DEMORALIZED refresh to 1 turn
	_controller.apply_status(1, &"poison", -1, 99)        # status 7 — POISON refresh to default
	_controller.apply_status(1, &"demoralized", -1, 99)   # status 8 — DEMORALIZED refresh to default

	# ── _apply_turn_start_tick × 27 ───────────────────────────────────────────
	# 27 tick cycles process DoT + duration decrement + DEMORALIZED recovery check per turn.
	# Unit may die from POISON DoT during ticks — if so, remaining ticks are no-ops.
	for _i: int in range(27):
		_controller._apply_turn_start_tick(1)

	# ── Final state assertions (macOS-Metal known-good baseline) ──────────────
	# Values determined empirically by running this test once on macOS-Metal stable.
	# CI verifies bit-identical match across platforms (Linux Vulkan, Windows D3D12).
	#
	# Baseline determined: 2026-05-02
	#
	# Expected final_hp: computed by running the above sequence and reading the actual value.
	# Expected status count: remaining active effects after 27 tick cycles.
	var final_hp: int = _controller.get_current_hp(1)
	var final_status_count: int = _controller.get_status_effects(1).size()

	## Hardcoded macOS-Metal baseline (captured 2026-05-02 on macOS-Metal stable, Godot 4.6.2):
	const EXPECTED_FINAL_HP: int = 118
	const EXPECTED_STATUS_COUNT: int = 1

	assert_int(final_hp).override_failure_message(
		("AC-11 determinism: final_hp=%d does not match macOS-Metal baseline=%d. "
		+ "If running on a new platform, verify the formula uses only integer arithmetic + floor() + clamp(). "
		+ "If a formula was changed, update the baseline to the new empirical value.") % [final_hp, EXPECTED_FINAL_HP]
	).is_equal(EXPECTED_FINAL_HP)

	assert_int(final_status_count).override_failure_message(
		("AC-11 determinism: status_count=%d does not match macOS-Metal baseline=%d. "
		+ "Check that status effect expiry + DEMORALIZED recovery logic is deterministic.") % [final_status_count, EXPECTED_STATUS_COUNT]
	).is_equal(EXPECTED_STATUS_COUNT)
