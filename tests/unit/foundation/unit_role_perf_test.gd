extends GdUnitTestSuite

## unit_role_perf_test.gd
## Story 010 — Headless CI perf baseline per ADR-0009 §Performance Implications.
##
## Per-method <0.05ms (50µs); cost_table <0.01ms (10µs); direction_mult <0.01ms (10µs);
## per-battle init pass <0.6ms (600µs) for 12 units × 5 derived-stat methods (60 calls).
##
## On-device measurement is Polish-deferred per damage-calc story-010 pattern (5+
## Polish-deferral instances stable in this project). See:
##   production/qa/evidence/unit-role-perf-polish-deferred.md
##
## G-15: BOTH BalanceConstants AND UnitRole caches reset in before_test per the
##       canonical pattern (consistent with stories 003-009).
##
## NOTE: warm-up call before timed loop excludes first JSON parse + cache fill
##       from the measurement (per damage-calc story-010 perf test precedent).

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript

const N: int = 10000
const PER_METHOD_BUDGET_USEC: int = 50           # 0.05ms per ADR-0009 §Performance
const COST_TABLE_BUDGET_USEC: int = 10           # 0.01ms per ADR-0009 §Performance
const DIRECTION_MULT_BUDGET_USEC: int = 10       # 0.01ms per ADR-0009 §Performance
const PER_BATTLE_INIT_BUDGET_USEC: int = 600     # 0.6ms (12 units × 5 methods = 60 calls)


func before_test() -> void:
	# G-15: reset BOTH static caches per the canonical pattern from stories 003-009
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


func after_test() -> void:
	# Idempotent cleanup
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Helpers ────────────────────────────────────────────────────────────────


func _make_hero() -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.stat_might = 50
	hero.stat_intellect = 50
	hero.stat_command = 50
	hero.stat_agility = 50
	hero.base_hp_seed = 50
	hero.base_initiative_seed = 50
	hero.move_range = 4
	hero.default_class = 0
	return hero


# ── Per-method latency baselines (AC-1: <50µs each) ───────────────────────


## AC-1: get_atk avg per-call latency < 50µs (0.05ms) per ADR-0009 §Performance.
## Warm-up triggers JSON parse + BalanceConstants cache fill before timed loop.
func test_get_atk_under_50us() -> void:
	var hero: HeroData = _make_hero()
	UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-1: get_atk avg %dµs > %dµs budget" % [avg, PER_METHOD_BUDGET_USEC]
	).is_less(PER_METHOD_BUDGET_USEC)


## AC-1: get_phys_def avg < 50µs.
func test_get_phys_def_under_50us() -> void:
	var hero: HeroData = _make_hero()
	UnitRole.get_phys_def(hero, UnitRole.UnitClass.INFANTRY)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		UnitRole.get_phys_def(hero, UnitRole.UnitClass.INFANTRY)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-1: get_phys_def avg %dµs > %dµs budget" % [avg, PER_METHOD_BUDGET_USEC]
	).is_less(PER_METHOD_BUDGET_USEC)


## AC-1: get_mag_def avg < 50µs.
func test_get_mag_def_under_50us() -> void:
	var hero: HeroData = _make_hero()
	UnitRole.get_mag_def(hero, UnitRole.UnitClass.STRATEGIST)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		UnitRole.get_mag_def(hero, UnitRole.UnitClass.STRATEGIST)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-1: get_mag_def avg %dµs > %dµs budget" % [avg, PER_METHOD_BUDGET_USEC]
	).is_less(PER_METHOD_BUDGET_USEC)


## AC-1: get_max_hp avg < 50µs.
func test_get_max_hp_under_50us() -> void:
	var hero: HeroData = _make_hero()
	UnitRole.get_max_hp(hero, UnitRole.UnitClass.INFANTRY)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		UnitRole.get_max_hp(hero, UnitRole.UnitClass.INFANTRY)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-1: get_max_hp avg %dµs > %dµs budget" % [avg, PER_METHOD_BUDGET_USEC]
	).is_less(PER_METHOD_BUDGET_USEC)


## AC-1: get_initiative avg < 50µs.
func test_get_initiative_under_50us() -> void:
	var hero: HeroData = _make_hero()
	UnitRole.get_initiative(hero, UnitRole.UnitClass.SCOUT)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		UnitRole.get_initiative(hero, UnitRole.UnitClass.SCOUT)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-1: get_initiative avg %dµs > %dµs budget" % [avg, PER_METHOD_BUDGET_USEC]
	).is_less(PER_METHOD_BUDGET_USEC)


## AC-1: get_effective_move_range avg < 50µs (simplest formula — should be fastest).
func test_get_effective_move_range_under_50us() -> void:
	var hero: HeroData = _make_hero()
	UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.CAVALRY)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.CAVALRY)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-1: get_effective_move_range avg %dµs > %dµs budget" % [avg, PER_METHOD_BUDGET_USEC]
	).is_less(PER_METHOD_BUDGET_USEC)


# ── cost_table + direction_mult baselines (AC-2: <10µs each) ──────────────


## AC-2: get_class_cost_table avg < 10µs (0.01ms).
## PackedFloat32Array per-call copy (R-1 mitigation per ADR-0009 §5) is the
## expected dominant cost. If avg exceeds budget on macOS x86, R-1 mitigation
## may need re-evaluation (but should pass at this baseline).
func test_get_class_cost_table_under_10us() -> void:
	UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		var _r: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-2: get_class_cost_table avg %dµs > %dµs budget" % [avg, COST_TABLE_BUDGET_USEC]
	).is_less(COST_TABLE_BUDGET_USEC)


## AC-2: get_class_direction_mult avg < 10µs.
## Single bracket-index lookup; should be fastest of all UnitRole methods.
func test_get_class_direction_mult_under_10us() -> void:
	UnitRole.get_class_direction_mult(UnitRole.UnitClass.CAVALRY, 2)  # warm-up
	var start: int = Time.get_ticks_usec()
	for i in N:
		var _f: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.CAVALRY, 2)
	var avg: int = (Time.get_ticks_usec() - start) / N
	assert_int(avg).override_failure_message(
		"AC-2: get_class_direction_mult avg %dµs > %dµs budget" % [avg, DIRECTION_MULT_BUDGET_USEC]
	).is_less(DIRECTION_MULT_BUDGET_USEC)


# ── Per-battle init simulation (AC-3: 60 calls <600µs total) ───────────────


## AC-3: realistic per-battle init scenario — 12 units × 5 derived-stat methods
## sequentially = 60 calls. Total elapsed must be < 600µs (0.6ms; well inside
## one-frame 16.6ms budget at 60fps; ADR-0009 §Performance budget).
func test_per_battle_init_under_600us() -> void:
	var heroes: Array[HeroData] = []
	for i in 12:
		heroes.append(_make_hero())
	var classes: Array[int] = [
		UnitRole.UnitClass.CAVALRY,
		UnitRole.UnitClass.INFANTRY,
		UnitRole.UnitClass.ARCHER,
		UnitRole.UnitClass.STRATEGIST,
		UnitRole.UnitClass.COMMANDER,
		UnitRole.UnitClass.SCOUT,
	]

	# Warm-up (excludes JSON parse + cache fill from timed pass)
	UnitRole.get_atk(heroes[0], classes[0])
	UnitRole.get_phys_def(heroes[0], classes[0])
	UnitRole.get_mag_def(heroes[0], classes[0])
	UnitRole.get_max_hp(heroes[0], classes[0])
	UnitRole.get_initiative(heroes[0], classes[0])

	var start: int = Time.get_ticks_usec()
	for unit_idx in 12:
		var cls: int = classes[unit_idx % 6]
		UnitRole.get_atk(heroes[unit_idx], cls)
		UnitRole.get_phys_def(heroes[unit_idx], cls)
		UnitRole.get_mag_def(heroes[unit_idx], cls)
		UnitRole.get_max_hp(heroes[unit_idx], cls)
		UnitRole.get_initiative(heroes[unit_idx], cls)
	var elapsed: int = Time.get_ticks_usec() - start

	assert_int(elapsed).override_failure_message(
		("AC-3: per-battle init pass %dµs > %dµs budget "
		+ "(12 units × 5 methods = 60 calls; one-time per battle)")
		% [elapsed, PER_BATTLE_INIT_BUDGET_USEC]
	).is_less(PER_BATTLE_INIT_BUDGET_USEC)
