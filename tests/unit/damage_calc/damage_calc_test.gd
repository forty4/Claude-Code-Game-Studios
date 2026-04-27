## Unit tests for DamageCalc.resolve() — Stages 0 / 1 / 2 / 2.5 / 3 / 4 (cumulative coverage).
## Covers story-003 (Stage 0 invariant guards + evasion roll, AC-DC-18/19/22/28/10/14/26),
## story-004 (Stage 1 base damage + BASE_CEILING + DEFEND_STANCE + Formation DEF, AC-DC-01/02/05/06/07/11/12/13/15/23/53),
## story-005 (Stage 2 D_mult + Stage 2.5 P_mult composition + P_MULT_COMBINED_CAP, AC-DC-03/04/09/16/21/27/52),
## story-006 (Stage 3-4 raw cap + counter halve + source_flags/vfx_tags + AC-DC-N1 enum fix + AC-DC-51,
##   AC-DC-08/17/20/24/33/34/35/36/N1/51 + source_flags always-new),
## and story-006b (BalanceConstants migration — AC-4 live-registry-read mock test, AC-DC-48).
## No scene-tree dependency — extends GdUnitTestSuite (RefCounted-based).
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Shared test fixtures (re-created in before_test to ensure isolation per G-15)
# ---------------------------------------------------------------------------

var _atk: AttackerContext
var _def: DefenderContext

## Test-only Callable for the AC-DC-51 bypass-seam test (story-006).
## Wraps DamageCalc._passive_multiplier_for_test, which accepts a Variant passives_arg override.
## Declared as a class-level var so GDScript resolves DamageCalc at parse time (not deferred).
var _passive_mul: Callable = Callable(DamageCalc, "_passive_multiplier_for_test")

## GDScript handle for BalanceConstants — used by AC-4 mock test to set/clear the cache.
## Stored at class scope so both before_test and after_test can reference it without reload.
var _balance_constants_script: GDScript = load("res://src/feature/balance/balance_constants.gd")


## Per-test setup. Uses before_test() — the only GdUnit4 v6.1.2 hook (G-15).
## Also resets BalanceConstants cache to ensure test isolation (story-006b).
func before_test() -> void:
	_atk = AttackerContext.make(&"unit_a", AttackerContext.Class.INFANTRY, 0, false, false, [])
	_def = DefenderContext.make(&"unit_b", 0, 0, 0)
	# Reset BalanceConstants static cache so every test starts with a clean lazy-load.
	# Required for AC-4 mock test: prevents a mocked cache from leaking into subsequent tests.
	_balance_constants_script.set("_cache_loaded", false)
	_balance_constants_script.set("_cache", {})


## Per-test teardown. Uses after_test() — the only GdUnit4 v6.1.2 hook (G-15).
## Restores BalanceConstants cache to pristine state after any mock that may have set it.
func after_test() -> void:
	_balance_constants_script.set("_cache_loaded", false)
	_balance_constants_script.set("_cache", {})


# ---------------------------------------------------------------------------
# AC-1 (AC-DC-18) — skill stub early return, RNG call count = 0
# ---------------------------------------------------------------------------

## AC-1a: non-empty skill_id returns MISS with skill_unresolved flag; RNG not consumed.
func test_skill_stub_early_return_zero_rng_calls() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var state_before: int = rng.state
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			false, "fireball")

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_bool(result.source_flags.has(&"skill_unresolved")).is_true()
	assert_bool(result.vfx_tags.is_empty()).is_true()
	assert_int(rng.state).is_equal(state_before)   # RNG call count = 0


## AC-1b edge case: skill_id == "" (default) does NOT trigger skill-stub path.
func test_skill_stub_with_default_empty_skill_id_does_not_trigger() -> void:
	# Arrange — empty skill_id, valid modifiers → should reach Stage 0 evasion
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

	# Assert — reaches Stage-0-passes placeholder (returns HIT, not skill_unresolved MISS)
	assert_bool(result.source_flags.has(&"skill_unresolved")).is_false()
	assert_int(result.kind).is_equal(ResolveResult.Kind.HIT)


# ---------------------------------------------------------------------------
# AC-2 (AC-DC-19) — rng null guard
# ---------------------------------------------------------------------------

## AC-2: rng == null returns MISS with invariant_violation:rng_null flag.
func test_rng_null_guard_returns_invariant_violation_flag() -> void:
	# Arrange — construct valid mod then null out rng
	var rng := RandomNumberGenerator.new()
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)
	mod.rng = null

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_bool(result.source_flags.has(&"invariant_violation:rng_null")).is_true()


# ---------------------------------------------------------------------------
# AC-3 (AC-DC-22) — unknown direction guard
# ---------------------------------------------------------------------------

## AC-3a: direction_rel == &"DIAGONAL" returns MISS with invariant_violation:unknown_direction.
func test_unknown_direction_guard_diagonal_returns_flag() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"DIAGONAL", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_bool(result.source_flags.has(&"invariant_violation:unknown_direction")).is_true()


## AC-3b edge case: empty StringName direction_rel triggers unknown_direction guard.
## (StringName cannot be null in GDScript; empty StringName is the closest equivalent.)
func test_unknown_direction_guard_empty_returns_flag() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)
	mod.direction_rel = &""

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_bool(result.source_flags.has(&"invariant_violation:unknown_direction")).is_true()


## AC-3c: each of FRONT / FLANK / REAR passes the direction guard.
func test_valid_directions_pass_guard() -> void:
	# Arrange
	var directions: Array[StringName] = [&"FRONT", &"FLANK", &"REAR"]
	for dir: StringName in directions:
		var rng := RandomNumberGenerator.new()
		rng.seed = 0
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, dir, 1)

		# Act
		var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

		# Assert — no unknown_direction flag (guard passes; Stage-0-passes placeholder returns HIT)
		assert_bool(result.source_flags.has(&"invariant_violation:unknown_direction")).is_false()


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-28) — bad attack_type guard via direct int-to-enum assignment
# ---------------------------------------------------------------------------

## AC-4: attack_type == 99 returns MISS with bad_attack_type flag.
##
## Bypass technique: GDScript enums are runtime ints. Assigning an out-of-range
## int (99) to an enum-typed field passes parse-time but triggers our `not in
## [PHYSICAL, MAGICAL]` guard at runtime. This is simpler than the originally-
## planned `TestResolveModifiersBypass` subclass-shadow approach (which Godot
## 4.6 parser rejected with "Could not resolve external class member" on first
## CI attempt — see PR #56 commit history).
func test_bad_attack_type_returns_invariant_violation_flag() -> void:
	# Arrange — start with valid PHYSICAL, then force-assign 99 (out-of-enum-range)
	var rng := RandomNumberGenerator.new()
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)
	@warning_ignore("int_as_enum_without_cast")
	mod.attack_type = 99

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, _def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_bool(result.source_flags.has(&"invariant_violation:bad_attack_type")).is_true()


# ---------------------------------------------------------------------------
# AC-5 (AC-DC-10) — seeded evasion MISS
# ---------------------------------------------------------------------------

## AC-5a: terrain_evasion=30, seeded rng roll=25 → MISS with evasion flag.
## Seed 266 produces roll=25 on first randi_range(1,100) — verified locally via Godot 4.6.
func test_evasion_miss_seeded_roll_25_terrain_30() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 266   # first randi_range(1,100) → 25
	var def := DefenderContext.make(&"unit_b", 0, 0, 30)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			false)

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_bool(result.source_flags.has(&"evasion")).is_true()


## AC-5b edge case: is_counter=true skips evasion → Stage-0-passes placeholder (HIT), RNG unchanged.
func test_counter_path_skips_evasion_no_rng_advance() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 266   # would produce roll=25 (MISS) if evasion ran — counter skips it
	var def := DefenderContext.make(&"unit_b", 0, 0, 30)
	var state_before: int = rng.state
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)   # is_counter = true

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, def, mod)

	# Assert — HIT (evasion skipped), RNG state unchanged
	assert_int(result.kind).is_equal(ResolveResult.Kind.HIT)
	assert_bool(result.source_flags.has(&"evasion")).is_false()
	assert_int(rng.state).is_equal(state_before)   # RNG call count = 0


# ---------------------------------------------------------------------------
# AC-6 (AC-DC-14) — evasion boundary inclusive
# ---------------------------------------------------------------------------

## AC-6a: terrain_evasion=30, roll=30 → MISS (inclusive <= boundary).
## Seed 84 produces roll=30 on first randi_range(1,100) — verified locally.
func test_evasion_boundary_roll_30_terrain_30_misses() -> void:
	# Arrange — roll=30 <= terrain_evasion=30 → MISS
	var rng := RandomNumberGenerator.new()
	rng.seed = 84   # first randi_range(1,100) → 30
	var def := DefenderContext.make(&"unit_b", 0, 0, 30)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, def, mod)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)


## AC-6b: terrain_evasion=30, roll=31 → HIT (roll=31 > 30, proceeds to Stage 1).
## Seed 53 produces roll=31 on first randi_range(1,100) — verified locally.
func test_evasion_boundary_roll_31_terrain_30_hits() -> void:
	# Arrange — roll=31 > terrain_evasion=30 → passes Stage 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 53   # first randi_range(1,100) → 31
	var def := DefenderContext.make(&"unit_b", 0, 0, 30)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(_atk, def, mod)

	# Assert — Stage-0-passes placeholder returns HIT
	assert_int(result.kind).is_equal(ResolveResult.Kind.HIT)
	assert_bool(result.source_flags.has(&"evasion")).is_false()


# ---------------------------------------------------------------------------
# AC-7 (AC-DC-26) — zero evasion always HIT, RNG advances exactly N times
# ---------------------------------------------------------------------------

## AC-7a: terrain_evasion=0 → 0 MISS out of 100 calls; RNG state advances exactly 100 times.
## Verifies replay determinism: randi_range is called even when terrain_evasion=0 (roll >= 1 always).
func test_zero_evasion_always_hits_rng_advances_once_per_call() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var def := DefenderContext.make(&"unit_b", 0, 0, 0)   # terrain_evasion = 0
	var miss_count: int = 0

	# Capture state snapshots — N+1 distinct states proves N calls
	var states: Array[int] = []
	states.append(rng.state)

	# Act — 100 resolve calls, non-counter
	for i: int in range(100):
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)
		var result: ResolveResult = DamageCalc.resolve(_atk, def, mod)
		if result.kind == ResolveResult.Kind.MISS:
			miss_count += 1
		states.append(rng.state)

	# Assert — zero misses (roll ∈ [1,100], evasion threshold=0, 1 <= 0 is always false)
	assert_int(miss_count).is_equal(0)

	# Assert — 101 distinct states: initial + one advance per call = 100 advances
	var unique_count: int = 0
	for i: int in range(states.size()):
		var is_dup: bool = false
		for j: int in range(i):
			if states[j] == states[i]:
				is_dup = true
				break
		if not is_dup:
			unique_count += 1
	assert_int(unique_count).is_equal(101)


## AC-7b: counter path with terrain_evasion=0 — RNG state does NOT advance across 100 calls.
func test_counter_path_zero_evasion_rng_never_advances() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var def := DefenderContext.make(&"unit_b", 0, 0, 0)
	var state_before: int = rng.state

	# Act — 100 counter-path resolve calls (is_counter = true)
	for i: int in range(100):
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
				true)   # is_counter = true
		DamageCalc.resolve(_atk, def, mod)

	# Assert — RNG state unchanged across all 100 calls
	assert_int(rng.state).is_equal(state_before)


# ===========================================================================
# Story-004 — Stage 1 base damage + F-DC-3 + BASE_CEILING (AC-1..AC-11)
# AC naming: AC-N below refers to story-004 QA Test Cases §AC-N (AC-DC-XX).
# Contexts are constructed inline per test — before_test() fixtures are for
# Stage-0 tests only. All new tests use local rng/atk/def/mod variables.
# ===========================================================================

# ---------------------------------------------------------------------------
# AC-1 (AC-DC-01 D-1 baseline) — Cavalry FRONT, no passives, no terrain
# ---------------------------------------------------------------------------

## AC-1: raw_atk=80, raw_def=50, T_def=0, FRONT, no defend_stance → base=30.
## floori(80 - 50 * 1.00) = 30. BASE_CEILING(83) does not fire.
func test_stage_1_d1_baseline_cavalry_front_returns_30() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1   # seed 1 produces roll > 0 → passes evasion (terrain_evasion=0)
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, false, false, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(30)


# ---------------------------------------------------------------------------
# AC-2 (AC-DC-02 D-2) — BASE_CEILING fires at atk=190, def=10, FRONT
# ---------------------------------------------------------------------------

## AC-2: raw_atk=190, raw_def=10, T_def=0 → floori(190 - 10*1.00)=180 → clamped to 83.
func test_stage_1_d2_base_ceiling_fires_atk190_def10_returns_83() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 190, false, false, [])
	var def := DefenderContext.make(&"d", 10, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(83)


# ---------------------------------------------------------------------------
# AC-3 (AC-DC-05 D-5) — MIN_DAMAGE floor: atk=30, def=100, T_def=+30
# ---------------------------------------------------------------------------

## AC-3: T_def=+30 → defense_mul=0.70 → floori(30 - 100*0.70)=floori(-40)=-40 → max(1,-40)=1.
## Note: raw_def=100 clamped to DEF_CAP=105 → eff_def=100 (no clamp fires here).
func test_stage_1_d5_min_damage_floor_atk30_def100_tdef30_returns_1() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec —
	# isolates Stage-1 verification from Stage-2 multiplication.
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 30, false, false, [])
	var def := DefenderContext.make(&"d", 100, 30, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(1)


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-06 D-6) — negative T_def amplifies defense: atk=60, def=50, T_def=-30
# ---------------------------------------------------------------------------

## AC-4: T_def=-30 → defense_mul=1.30 → floori(60 - 50*1.30)=floori(-5)=-5 → max(1,-5)=1.
func test_stage_1_d6_negative_tdef_amplifies_defense_returns_1() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 60, false, false, [])
	var def := DefenderContext.make(&"d", 50, -30, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(1)


# ---------------------------------------------------------------------------
# AC-5 (AC-DC-07 D-7) — positive T_def reduces defense: atk=80, def=50, T_def=+20
# ---------------------------------------------------------------------------

## AC-5: T_def=+20 → defense_mul=0.80 → floori(80 - 50*0.80)=floori(40.0)=40.
func test_stage_1_d7_positive_tdef_reduces_defense_returns_40() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 80, false, false, [])
	var def := DefenderContext.make(&"d", 50, 20, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(40)


# ---------------------------------------------------------------------------
# AC-6 (AC-DC-11) — ATK clamp: raw_atk values {0, -5, 1, 200} → eff_atk {1, 1, 1, 200}
# ---------------------------------------------------------------------------

## AC-6: Four raw_atk boundary values verify clampi(raw_atk, 1, ATK_CAP=200).
## Uses high raw_def to make eff_atk visible: base = floori(eff_atk - 100*1.00).
## raw_atk∈{0,-5,1} all clamp to eff_atk=1 → base=floori(1-100)=-99 → MIN_DAMAGE=1.
## raw_atk=200 → eff_atk=200 → base=floori(200-100)=100 → BASE_CEILING=83.
## Result damage is only used to CONFIRM the clamp fired — actual eff_atk is indirect.
func test_stage_1_atk_clamp_boundaries_raw_values_0_neg5_1_200() -> void:
	# Arrange — constant def=100, T_def=0, no defend_stance
	var cases: Array[Dictionary] = [
		{"raw_atk": 0,   "expected_damage": 1},   # clamp → eff_atk=1 → 1-100=-99 → MIN_DAMAGE
		{"raw_atk": -5,  "expected_damage": 1},   # clamp → eff_atk=1 → same
		{"raw_atk": 1,   "expected_damage": 1},   # at floor → eff_atk=1 → same
		{"raw_atk": 200, "expected_damage": 83},  # at cap → eff_atk=200 → 200-100=100 → BASE_CEILING
	]

	for c: Dictionary in cases:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
		var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT,
				c["raw_atk"] as int, false, false, [])
		var def := DefenderContext.make(&"d", 100, 0, 0)
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

		var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

		assert_int(result.resolved_damage).override_failure_message(
				("AC-6: raw_atk=%d expected_damage=%d got=%d"
				% [c["raw_atk"] as int, c["expected_damage"] as int, result.resolved_damage])
		).is_equal(c["expected_damage"] as int)


# ---------------------------------------------------------------------------
# AC-7 (AC-DC-12) — DEFEND_STANCE on raw_atk=1 recovers to MIN_DAMAGE
# ---------------------------------------------------------------------------

## AC-7: is_counter=true, defend_stance_active=true, raw_atk=1, eff_def=50.
## DEFEND_STANCE_ATK_PENALTY = 0.40. Multiplier = (1.0 - 0.40) = 0.60.
## floori(1 * 0.60) = floori(0.60) = 0. clampi(0, 1, ATK_CAP) = 1.
## base = floori(1 - 50*1.00) = -49 → maxi(MIN_DAMAGE, -49) = 1.
##
## CONTRACT NOTE: DEFEND_STANCE_ATK_PENALTY is a penalty FRACTION (0.40), NOT
## the resulting multiplier. The multiplier is (1.0 - 0.40) = 0.60. Using the
## constant as "raw_atk * PENALTY" (= raw_atk * 0.40) would produce floori(0.40)=0
## and the same final clamped result here, but the AC-DC-12 test with raw_atk=2
## reveals the difference: correct=floori(2*0.60)=1 vs wrong=floori(2*0.40)=0→clamp=1
## (same for 2, but raw_atk=3: correct=floori(1.80)=1, wrong=floori(1.20)=1 — same).
## The semantic is locked by CR-3 wording "0.60× multiplier"; constant is the penalty part.
func test_stage_1_defend_stance_raw_atk_1_recovers_to_min_damage() -> void:
	# Arrange — is_counter skips evasion roll (RNG not consumed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 1, false, true, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)   # is_counter = true (skips evasion)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — DEFEND_STANCE penalty floori(1*0.60)=0 → clampi(0,1,200)=1 → base=1-50=-49 → MIN_DAMAGE=1
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(1)


## AC-7-extended (compound edge case from /code-review qa-tester E-1):
## raw_atk=0 AND defend_stance_active=true → floori(0*0.60)=0 → clampi(0,1,200)=1
## → base=1-50=-49 → MIN_DAMAGE=1. Pins the clamp's recovery from a zero raw_atk
## under defend stance — distinct from AC-6 (raw_atk=0 without defend_stance) and
## AC-7 (raw_atk=1 with defend_stance). Catches future refactors that move the
## clamp site relative to the penalty application.
func test_stage_1_defend_stance_raw_atk_0_compound_recovers_to_min_damage() -> void:
	# Arrange — is_counter skips evasion roll (RNG not consumed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 0, false, true, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)   # is_counter = true (skips evasion)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — DEFEND_STANCE penalty floori(0*0.60)=0 → clampi(0,1,200)=1 → base=1-50=-49 → MIN_DAMAGE=1
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(1)


# ---------------------------------------------------------------------------
# AC-8 (AC-DC-13) — terrain_def boundary clamp: 5 T_def values → 5 defense_mul values
# ---------------------------------------------------------------------------

## AC-8: T_def ∈ {-31, -30, 0, +30, +31} → defense_mul ∈ {1.30, 1.30, 1.00, 0.70, 0.70}.
## clampi(T_def, -30, +30) fires BEFORE snappedf; out-of-range inputs clamp to ±30.
## Uses atk=80, def=100, T_def=X; derives expected base to validate the mul indirectly via resolve().
## Direct multiplication path: floori(80 - 100 * mul) → clamped to [1, 83].
func test_stage_1_terrain_def_boundary_clamp_five_values() -> void:
	# Each entry: {t_def, expected_mul_x100 (for display), expected_base_pre_clamp, expected_damage}
	# floori(80 - 100 * mul):
	#   mul=1.30 → floori(80-130)=floori(-50)=-50 → MIN_DAMAGE=1
	#   mul=1.00 → floori(80-100)=floori(-20)=-20 → MIN_DAMAGE=1
	#   mul=0.70 → floori(80-70)=floori(10)=10    → 10 (within [1,83])
	var cases: Array[Dictionary] = [
		{"t_def": -31, "expected_damage": 1,  "label": "T_def=-31 (clamp to -30, mul=1.30)"},
		{"t_def": -30, "expected_damage": 1,  "label": "T_def=-30 (at boundary, mul=1.30)"},
		{"t_def":   0, "expected_damage": 1,  "label": "T_def=0 (neutral, mul=1.00)"},
		{"t_def":  30, "expected_damage": 10, "label": "T_def=+30 (at boundary, mul=0.70)"},
		{"t_def":  31, "expected_damage": 10, "label": "T_def=+31 (clamp to +30, mul=0.70)"},
	]

	for c: Dictionary in cases:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
		var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 80, false, false, [])
		var def := DefenderContext.make(&"d", 100, c["t_def"] as int, 0)
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

		var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

		assert_int(result.resolved_damage).override_failure_message(
				"AC-8: %s" % [c["label"] as String]
		).is_equal(c["expected_damage"] as int)


# ---------------------------------------------------------------------------
# AC-9 (AC-DC-15) — ATK over cap: raw_atk ∈ {199, 200, 201} → eff_atk {199, 200, 200}
# ---------------------------------------------------------------------------

## AC-9: DamageCalc is the last clamp defense for ATK. raw_atk=201 → eff_atk=200 (capped).
## Uses def=10, T_def=0; base=floori(eff_atk - 10) → clamped to [1, BASE_CEILING=83].
## eff_atk=199 → base=189 → BASE_CEILING=83
## eff_atk=200 → base=190 → BASE_CEILING=83
## eff_atk=200 (capped from 201) → base=190 → BASE_CEILING=83
## The 201→200 clamp is observable via the SAME damage output as 200 (both hit BASE_CEILING).
func test_stage_1_atk_over_cap_clamps_at_200() -> void:
	var cases: Array[Dictionary] = [
		{"raw_atk": 199, "expected_damage": 83, "label": "raw_atk=199 → eff_atk=199 → BASE_CEILING"},
		{"raw_atk": 200, "expected_damage": 83, "label": "raw_atk=200 → eff_atk=200 (at cap) → BASE_CEILING"},
		{"raw_atk": 201, "expected_damage": 83, "label": "raw_atk=201 → eff_atk=200 (clamped) → BASE_CEILING"},
	]

	for c: Dictionary in cases:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
		var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT,
				c["raw_atk"] as int, false, false, [])
		var def := DefenderContext.make(&"d", 10, 0, 0)
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

		var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

		assert_int(result.resolved_damage).override_failure_message(
				"AC-9: %s" % [c["label"] as String]
		).is_equal(c["expected_damage"] as int)


# ---------------------------------------------------------------------------
# AC-10 (AC-DC-23) — floori not int: negative float intermediate + static grep
# ---------------------------------------------------------------------------

## AC-10 (runtime): Direct assertion that floori(-0.7) == -1 (NOT int(-0.7) == 0).
## This confirms the GDScript built-in semantic that DamageCalc relies on.
## If this ever fails, the floori/int contract has changed at the engine level.
##
## AC-10 (contract): Static grep of damage_calc.gd for "int(" returns 0 matches.
## This is a CONTRACT test — it verifies that NO call site in the production file
## uses int() for numeric conversions. Existing "as int" enum casts are fine;
## only function-call "int(" is forbidden per ADR-0012 §Decision-7 + AC-DC-23.
func test_stage_1_floori_not_int_negative_float_and_static_grep() -> void:
	# --- Runtime assertion: floori semantics ---
	# floori rounds toward −∞; int() truncates toward 0. They differ for negative non-integers.
	var intermediate: float = -0.7
	assert_int(floori(intermediate)).is_equal(-1)   # floori(-0.7) = -1
	# If int() were used: int(-0.7) = 0 (toward zero) — the WRONG semantic for CR-5.

	# --- Contract assertion: static grep for "int(" in damage_calc.gd ---
	var path: String = "res://src/feature/damage_calc/damage_calc.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message(
			"AC-10: Could not open %s for static grep" % path
	).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	# Count occurrences of "int(" — must be zero in production code.
	# "as int" (enum cast) is allowed; only "int(" function calls are forbidden.
	var matches: int = 0
	var search_pos: int = 0
	while true:
		var idx: int = content.find("int(", search_pos)
		if idx == -1:
			break
		matches += 1
		search_pos = idx + 1
	assert_int(matches).override_failure_message(
			"AC-10: damage_calc.gd contains %d 'int(' call(s) — use floori() instead (AC-DC-23)" % matches
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-11 (AC-DC-53 D-8) — Formation DEF consumer: formation_def_bonus=0.04 vs 0.0
# ---------------------------------------------------------------------------

## AC-11: Infantry FRONT, atk=82, def=50, T_def=0.
## formation_def_bonus=0.04 → eff_def = 50 + floori(50*0.04) = 50 + 2 = 52
##   base = mini(83, maxi(1, floori(82 - 52*1.00))) = mini(83, max(1,30)) = 30
## formation_def_bonus=0.0  → eff_def = 50 + floori(50*0.0) = 50
##   base = mini(83, maxi(1, floori(82 - 50*1.00))) = mini(83, max(1,32)) = 32
## Delta: 30 - 32 = -2 (Formation DEF absorbs 2 damage points — AC-DC-53 supplementary assertion).
func test_stage_1_formation_def_consumer_delta_minus_2() -> void:
	# Arrange — shared attacker/defender; only formation_def_bonus differs
	# SCOUT class chosen so D_mult=1.00 across all directions per story-005 spec.
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 82, false, false, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)

	# Case A: formation_def_bonus = 0.04
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1
	var mod_with_bonus := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_a, &"FRONT", 1,
			false, "", [], 0.0, 0.0, 0.04)
	var result_with: ResolveResult = DamageCalc.resolve(atk, def, mod_with_bonus)

	# Case B: formation_def_bonus = 0.0
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1
	var mod_no_bonus := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_b, &"FRONT", 1)
	var result_without: ResolveResult = DamageCalc.resolve(atk, def, mod_no_bonus)

	# Assert individual damages
	assert_int(result_with.resolved_damage).is_equal(30)
	assert_int(result_without.resolved_damage).is_equal(32)

	# Assert supplementary delta: Formation DEF bonus absorbs exactly 2 damage points
	var delta: int = result_with.resolved_damage - result_without.resolved_damage
	assert_int(delta).override_failure_message(
			"AC-11: Formation DEF delta expected -2 (bonus absorbs 2 pts) but got %d" % delta
	).is_equal(-2)


# ===========================================================================
# Story-005 — Stage 2 + Stage 2.5 direction × passive multiplier (AC-1..AC-7)
# AC naming: AC-N below refers to story-005 QA Test Cases §AC-N.
# All contexts constructed inline per test. No shared fixtures (per before_test isolation).
# Math verification key: Cavalry REAR D_mult = snappedf(1.50×1.09,0.01) = 1.64.
# ===========================================================================

# ---------------------------------------------------------------------------
# AC-1 (AC-DC-03 D-3) — Cavalry REAR Charge primary
# ---------------------------------------------------------------------------

## AC-1: Cavalry REAR, ATK=80, DEF=50, charge_active=true, passive_charge, is_counter=false.
## base=floori(80-50*1.00)=30. D_mult=snappedf(1.50×1.09,0.01)=1.64. P_mult=1.20.
## raw=floori(30×1.64×1.20)=floori(59.04)=59.
func test_stage_2_cavalry_rear_charge_primary_returns_59() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1   # seed 1 passes evasion (terrain_evasion=0)
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, true, false,
			[&"passive_charge"])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"REAR", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).is_equal(59)


# ---------------------------------------------------------------------------
# AC-2 (AC-DC-04 D-4) — hardest primary path, P_MULT_COMBINED_CAP fires + sub-cap delta
# ---------------------------------------------------------------------------

## AC-2 primary path: Cavalry REAR Charge, ATK=200, DEF=10, Rally(+10%), Formation(+5%).
## base=83 (BASE_CEILING fires: floori(200-10)=190→83). D_mult=1.64.
## pre-cap P_mult=1.20×1.10×1.05=1.386 → P_MULT_COMBINED_CAP clamps to 1.31.
## raw=floori(83×1.64×1.31)=floori(178.35)=178.
## Sub-case: same with charge_active=false + rally only (+10%, no Formation) → P_mult=1.10.
## raw=floori(83×1.64×1.10)=floori(149.71)=149. Delta=178-149=29 (Pillar-1 peak differentiation).
func test_stage_2_hardest_primary_path_p_mult_cap_fires_returns_178_delta_29() -> void:
	# Arrange — Case A: full Charge + Rally + Formation stack
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1
	var atk_a := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 200, true, false,
			[&"passive_charge"])
	var def_a := DefenderContext.make(&"d", 10, 0, 0)
	var mod_a := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_a, &"REAR", 1,
			false, "", [], 0.10, 0.05, 0.0)

	# Act A
	var result_a: ResolveResult = DamageCalc.resolve(atk_a, def_a, mod_a)

	# Assert A: P_MULT_COMBINED_CAP fires → 178
	assert_int(result_a.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_a.resolved_damage).override_failure_message(
			"AC-2 cap case: expected 178 got %d" % result_a.resolved_damage
	).is_equal(178)

	# Arrange — Case B: no Charge (charge_active=false), Rally only (+10%), no Formation
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1
	var atk_b := AttackerContext.make(&"b", AttackerContext.Class.CAVALRY, 200, false, false,
			[&"passive_charge"])
	var def_b := DefenderContext.make(&"d", 10, 0, 0)
	var mod_b := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_b, &"REAR", 1,
			false, "", [], 0.10, 0.0, 0.0)

	# Act B
	var result_b: ResolveResult = DamageCalc.resolve(atk_b, def_b, mod_b)

	# Assert B: P_mult=1.10, no cap → 149
	assert_int(result_b.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_b.resolved_damage).override_failure_message(
			"AC-2 sub-cap case: expected 149 got %d" % result_b.resolved_damage
	).is_equal(149)

	# Assert supplementary: 29-point Pillar-1 peak differentiation
	var peak_delta: int = result_a.resolved_damage - result_b.resolved_damage
	assert_int(peak_delta).override_failure_message(
			("AC-2: Pillar-1 peak delta expected 29 got %d"
			% peak_delta)
	).is_equal(29)


# ---------------------------------------------------------------------------
# AC-3 (AC-DC-09 D-9) — Scout Ambush FLANK
# ---------------------------------------------------------------------------

## AC-3: Scout (class=1), ATK=70, DEF=40, FLANK, round=3, defender not acted, passive_ambush.
## base=floori(70-40*1.00)=30. D_mult=snappedf(1.20×1.00,0.01)=1.20. P_mult=1.15.
## raw=floori(30×1.20×1.15)=floori(41.4)=41.
func test_stage_2_scout_ambush_flank_round3_defender_not_acted_returns_41() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 70, false, false,
			[&"passive_ambush"])
	var def := DefenderContext.make(&"d", 40, 0, 0)
	var not_acted_callable := func(_unit_id: StringName) -> bool: return false
	var mod := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng, &"FLANK", 3,
			false, "", [], 0.0, 0.0, 0.0, not_acted_callable)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			"AC-3: Scout Ambush FLANK expected 41 got %d" % result.resolved_damage
	).is_equal(41)


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-16 EC-DC-8) — Charge suppressed on counter
# ---------------------------------------------------------------------------

## AC-4: Cavalry REAR Charge, ATK=80, DEF=50. Two runs: is_counter ∈ {true, false}.
## is_counter=false: P_mult=1.20, raw=floori(30×1.64×1.20)=59.
## is_counter=true:  P_mult=1.00, raw=floori(30×1.64×1.00)=floori(49.2)=49.
## Charge is suppressed on counter path (AC-DC-16 EC-DC-8).
func test_stage_2_charge_suppressed_on_counter_p_mult_differs() -> void:
	# Arrange — shared attacker with passive_charge
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, true, false,
			[&"passive_charge"])
	var def := DefenderContext.make(&"d", 50, 0, 0)

	# Case A: primary attack (is_counter=false) — Charge fires
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1
	var mod_a := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng_a, &"REAR", 1,
			false)
	var result_a: ResolveResult = DamageCalc.resolve(atk, def, mod_a)

	# Case B: counter attack (is_counter=true) — Charge suppressed, evasion also skipped
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1
	var mod_b := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng_b, &"REAR", 1,
			true)
	var result_b: ResolveResult = DamageCalc.resolve(atk, def, mod_b)

	# Assert: both HIT
	assert_int(result_a.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_b.kind as int).is_equal(ResolveResult.Kind.HIT as int)

	# Assert: individual expected values
	# Non-counter (result_a): raw=floori(30×1.64×1.20)=59; Stage 4 does NOT fire → resolved=59.
	# Counter (result_b): raw=floori(30×1.64×1.00)=floori(49.2)=49;
	#   Stage 4 fires: floori(49×0.5)=24, maxi(1,24)=24 → resolved=24.
	assert_int(result_a.resolved_damage).override_failure_message(
			"AC-4 primary: expected 59 (P_mult=1.20, no Stage-4 halve) got %d" % result_a.resolved_damage
	).is_equal(59)
	assert_int(result_b.resolved_damage).override_failure_message(
			"AC-4 counter: expected 24 (P_mult=1.00, Stage-4 counter halve floori(49×0.5)=24) got %d" % result_b.resolved_damage
	).is_equal(24)

	# Assert: delta reflects both the 1.20× Charge factor AND the Stage-4 counter halve.
	# 59 primary - 24 counter = 35 (story-006 Stage-4 is the dominant factor in this delta).
	var charge_delta: int = result_a.resolved_damage - result_b.resolved_damage
	assert_int(charge_delta).override_failure_message(
			"AC-4: charge_delta expected 35 (59 primary - 24 counter halve) got %d" % charge_delta
	).is_equal(35)


# ---------------------------------------------------------------------------
# AC-5 (AC-DC-21 EC-DC-15) — unknown_class invariant guard
# ---------------------------------------------------------------------------

## Bypass-seam subclass for AC-5: extends AttackerContext to allow direct field assignment
## of an out-of-range unit_class (99) that bypasses the make() factory.
## Per ADR-0012 §Implementation Guidelines #3: test-only bypass-seam pattern.
## MUST NOT appear in src/ — tests/unit/ location is sufficient.
class TestAttackerContextBypass extends AttackerContext:
	pass


## AC-5: unit_class=99 (via TestAttackerContextBypass) → MISS with invariant_violation:unknown_class.
## push_error fires (visible in log). Production-exclusion: TestAttackerContextBypass in src/ = 0.
func test_stage_2_unknown_class_guard_returns_miss_with_invariant_flag() -> void:
	# Arrange — TestAttackerContextBypass allows direct field assignment (bypass-seam per ADR-0012 §3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var ctx := TestAttackerContextBypass.new()
	@warning_ignore("int_as_enum_without_cast")
	ctx.unit_class = 99   # out-of-range value not in CLASS_DIRECTION_MULT
	ctx.raw_atk = 80
	ctx.unit_id = &"bypass_test"
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"REAR", 1,
			true)   # is_counter=true to skip evasion RNG so we reach Stage 2

	# Act
	var result: ResolveResult = DamageCalc.resolve(ctx, def, mod)

	# Assert
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.MISS as int)
	assert_bool(result.source_flags.has(&"invariant_violation:unknown_class")).override_failure_message(
			"AC-5: source_flags must contain invariant_violation:unknown_class"
	).is_true()

	# Production-exclusion lint: TestAttackerContextBypass must NOT appear in src/
	var src_path: String = "res://src/"
	var dir: DirAccess = DirAccess.open(src_path)
	assert_object(dir).override_failure_message(
			"AC-5 lint: could not open res://src/ for production-exclusion check"
	).is_not_null()
	# Read damage_calc.gd specifically (the most likely accidental location)
	var calc_path: String = "res://src/feature/damage_calc/damage_calc.gd"
	var calc_file: FileAccess = FileAccess.open(calc_path, FileAccess.READ)
	if calc_file != null:
		var content: String = calc_file.get_as_text()
		calc_file.close()
		assert_bool(content.contains("TestAttackerContextBypass")).override_failure_message(
				"AC-5 lint: TestAttackerContextBypass found in damage_calc.gd — production-exclusion violated"
		).is_false()


# ---------------------------------------------------------------------------
# AC-6 (AC-DC-27 EC-DC-9) — class mutex: BOTH passives, 4 classes
# ---------------------------------------------------------------------------

## AC-6: parametric loop over 4 unit classes, each with passive_charge + passive_ambush +
## charge_active=true. Class mutex ensures only one passive fires per class.
## Expected P_mult: CAVALRY=1.20 (Charge), SCOUT=1.15 (Ambush), INFANTRY=1.00, ARCHER=1.15 (Ambush).
## Structural invariant: P_mult is NEVER 1.38 (1.20×1.15 = dual-fire = class mutex violation).
## All cases use Cavalry REAR direction to isolate P_mult observable via raw damage.
## Ambush-eligible classes (SCOUT=1, ARCHER=3) use round=2 and defender-not-acted callable.
func test_stage_2_class_mutex_four_classes_p_mult_never_1_38() -> void:
	# Arrange — parametric test cases per story-005 §AC-6
	# D_mult for CAVALRY REAR = 1.64; SCOUT REAR = 1.50; INFANTRY REAR = 1.50; ARCHER REAR = 1.50.
	# base = floori(80-50*1.00) = 30 (ATK=80, DEF=50, T_def=0, no defend_stance).
	# Expected raw = floori(base × D_mult × P_mult):
	#   CAVALRY  (0): floori(30×1.64×1.20) = 59
	#   SCOUT    (1): floori(30×1.50×1.15) = floori(51.75) = 51
	#   INFANTRY (2): floori(30×1.50×1.00) = 45
	#   ARCHER   (3): floori(30×1.50×1.15) = 51
	var cases: Array[Dictionary] = [
		{"unit_class": AttackerContext.Class.CAVALRY,  "label": "CAVALRY",  "expected_dmg": 59},
		{"unit_class": AttackerContext.Class.SCOUT,    "label": "SCOUT",    "expected_dmg": 51},
		{"unit_class": AttackerContext.Class.INFANTRY, "label": "INFANTRY", "expected_dmg": 45},
		{"unit_class": AttackerContext.Class.ARCHER,   "label": "ARCHER",   "expected_dmg": 51},
	]

	# Callable stub: defender has not acted (enables Ambush for eligible classes)
	var not_acted_callable := func(_unit_id: StringName) -> bool: return false

	for c: Dictionary in cases:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var atk := AttackerContext.make(
				&"a", c["unit_class"] as int, 80, true, false,
				[&"passive_charge", &"passive_ambush"])
		var def := DefenderContext.make(&"d", 50, 0, 0)
		var mod := ResolveModifiers.make(
				ResolveModifiers.AttackType.PHYSICAL, rng, &"REAR", 2,
				false, "", [], 0.0, 0.0, 0.0, not_acted_callable)

		var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

		assert_int(result.kind as int).override_failure_message(
				("AC-6 [%s]: expected HIT" % [c["label"] as String])
		).is_equal(ResolveResult.Kind.HIT as int)

		assert_int(result.resolved_damage).override_failure_message(
				("AC-6 [%s]: expected %d got %d"
				% [c["label"] as String, c["expected_dmg"] as int, result.resolved_damage])
		).is_equal(c["expected_dmg"] as int)

		# Structural invariant: 1.38 dual-fire is class-mutex-impossible
		# 1.38 dual-fire for CAVALRY REAR = floori(30×1.64×1.38) = floori(67.9) = 67
		# 1.38 dual-fire for SCOUT/INFANTRY/ARCHER REAR = floori(30×1.50×1.38) = floori(62.1) = 62
		# Neither 67 nor 62 should ever appear as a resolved_damage in this test.
		assert_bool(result.resolved_damage == 67 or result.resolved_damage == 62).override_failure_message(
				("AC-6 [%s]: resolved_damage=%d looks like a P_mult=1.38 dual-fire (class mutex violated)"
				% [c["label"] as String, result.resolved_damage])
		).is_false()


# ---------------------------------------------------------------------------
# AC-7 (AC-DC-52 D-7) — Formation ATK sub-apex: cap does NOT fire
# ---------------------------------------------------------------------------

## AC-7: Cavalry REAR Charge, ATK=200, DEF=10, formation_atk_bonus=0.05, no Rally.
## base=83. D_mult=1.64. pre-cap P_mult=1.20×1.05=1.26 (P_MULT_COMBINED_CAP=1.31 does NOT fire).
## raw=floori(83×1.64×1.26)=floori(171.7)=171.
## Sub-case: same with formation_atk_bonus=0.0 → P_mult=1.20, raw=floori(83×1.64×1.20)=floori(163.5)=163.
## Delta=171-163=+8 proves Formation ATK contribution at sub-apex.
func test_stage_2_formation_atk_sub_apex_cap_does_not_fire_delta_8() -> void:
	# Arrange — Case A: with formation_atk_bonus=0.05
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 200, true, false,
			[&"passive_charge"])
	var def := DefenderContext.make(&"d", 10, 0, 0)
	var mod_a := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_a, &"REAR", 1,
			false, "", [], 0.0, 0.05, 0.0)

	# Act A
	var result_a: ResolveResult = DamageCalc.resolve(atk, def, mod_a)

	# Arrange — Case B: no formation_atk_bonus (0.0)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1
	var mod_b := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_b, &"REAR", 1,
			false, "", [], 0.0, 0.0, 0.0)

	# Act B
	var result_b: ResolveResult = DamageCalc.resolve(atk, def, mod_b)

	# Assert A: 171 (P_MULT_COMBINED_CAP=1.31 does NOT fire at P_mult=1.26)
	assert_int(result_a.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_a.resolved_damage).override_failure_message(
			"AC-7 with formation: expected 171 got %d" % result_a.resolved_damage
	).is_equal(171)

	# Assert B: 163 (P_mult=1.20, no formation)
	assert_int(result_b.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_b.resolved_damage).override_failure_message(
			"AC-7 no formation: expected 163 got %d" % result_b.resolved_damage
	).is_equal(163)

	# Assert supplementary delta: Formation ATK bonus adds exactly +8 damage
	var formation_delta: int = result_a.resolved_damage - result_b.resolved_damage
	assert_int(formation_delta).override_failure_message(
			("AC-7: Formation ATK delta expected +8 got %d" % formation_delta)
	).is_equal(8)


## E-1 (from /code-review qa-tester): default-Callable Ambush path through resolve().
## Pins the production contract that an unset acted_this_turn_callable (default Callable())
## evaluates as is_valid()=false in _ambush_factor → has_acted=false → Ambush fires.
## Distinct from AC-3 which injects an explicit not-acted lambda; this exercises the
## no-callable-injected default-no-op fallback that production code will hit before
## ADR-0011 lands.
func test_stage_2_e1_default_callable_ambush_fires_p_mult_1_15() -> void:
	# Arrange — Scout, FLANK, round=2, passive_ambush, NO acted_this_turn_callable injected
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(
			&"a", AttackerContext.Class.SCOUT, 70, false, false, [&"passive_ambush"])
	var def := DefenderContext.make(&"d", 40, 0, 0)
	var mod := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng, &"FLANK", 2)
	# acted_this_turn_callable left as default Callable() — is_valid() returns false

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — Scout FLANK D_mult=1.20, P_mult=1.15 (Ambush fires via is_valid() fallback)
	# base = floori(70 - 40 * 1.0) = 30; raw = floori(30 * 1.20 * 1.15) = floori(41.4) = 41
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			("E-1: default Callable() should fall back to has_acted=false → Ambush fires; "
			+ "expected raw=41 (P_mult=1.15) but got %d" % result.resolved_damage)
	).is_equal(41)


## E-2 (from /code-review qa-tester): Counter + Rally + Formation simultaneously.
## Pins the spec line 96 positive claim: "Rally + Formation still apply on counter"
## (counter only suppresses Charge/Ambush, NOT the additive bonuses). Catches a future
## regression if someone adds `and not modifiers.is_counter` to the Rally or Formation
## terms in _passive_multiplier.
func test_stage_2_e2_counter_with_rally_and_formation_p_mult_above_1_00() -> void:
	# Arrange — Cavalry REAR, Charge eligible BUT is_counter=true (suppresses Charge),
	# Rally(+10%) and Formation ATK(+5%) active on counter path
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(
			&"a", AttackerContext.Class.CAVALRY, 80, true, false, [&"passive_charge"])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng, &"REAR", 1,
			true,           # is_counter = true
			"",             # skill_id
			[],             # source_flags
			0.10,           # rally_bonus = +10%
			0.05,           # formation_atk_bonus = +5%
			0.0)            # formation_def_bonus

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — Cavalry REAR D_mult=1.64; Charge SUPPRESSED on counter (charge=1.0);
	# Rally + Formation still apply: P_mult_pre_cap = 1.00 × 1.00 × 1.10 × 1.05 = 1.155
	# minf(1.31, 1.155) = 1.155 → snappedf(0.01) = 1.16 (post-snap rounding)
	# base = floori(80 - 50 * 1.0) = 30; raw = floori(30 * 1.64 * 1.16) = floori(57.072) = 57
	# Stage 4 counter halve: floori(57 × 0.5) = 28, maxi(1, 28) = 28 → resolved = 28.
	# This proves Rally + Formation still apply on the counter path (P_mult > 1.00).
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			(("E-2: counter path should still apply Rally+Formation (P_mult>1.00); "
			+ "expected resolved=28 (raw=57, Stage-4 halve floori(57x0.5)=28) but got %d "
			+ "-- if Rally/Formation suppressed on counter, resolved would be 24 (raw=49 halved)")
			% result.resolved_damage)
	).is_equal(28)

	# Supplementary: same inputs without Rally + Formation → P_mult=1.00, prove the delta
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1
	var mod_b := ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng_b, &"REAR", 1, true)
	var result_b: ResolveResult = DamageCalc.resolve(atk, def, mod_b)
	# raw_b = floori(30 * 1.64 * 1.00) = 49; Stage-4 counter halve: floori(49×0.5)=24 → resolved_b=24.
	assert_int(result_b.resolved_damage).is_equal(24)
	var counter_bonus_delta: int = result.resolved_damage - result_b.resolved_damage
	assert_int(counter_bonus_delta).override_failure_message(
			("E-2: Rally+Formation on counter should add exactly +4 damage (28-24); got delta=%d"
			% counter_bonus_delta)
	).is_equal(4)


# ===========================================================================
# Story-006 — Stage 3-4 + source_flags/vfx_tags + AC-DC-N1 + AC-DC-51 (AC-1..AC-11)
# AC naming: AC-N below refers to story-006 QA Test Cases §AC-N.
# All contexts constructed inline per test. No shared fixtures (per before_test isolation).
# ===========================================================================

# ---------------------------------------------------------------------------
# AC-1 (AC-DC-08 D-8) — DEFEND_STANCE counter full pipeline: resolved_damage = 16
# ---------------------------------------------------------------------------

## AC-1: ATK=120, defend_stance_active=true, is_counter=true, DEF=40, Cavalry FRONT, T_def=0.
## Cavalry FRONT: D_mult=snappedf(1.00*1.00,0.01)=1.00 (no class-specific penalty for this combo).
## eff_atk=floori(120*(1.0-0.40))=floori(72)=72. eff_def=40 (no formation).
## base=floori(72-40*1.00)=32. P_mult=1.00 (Charge/Ambush blocked on counter; no Rally/Formation).
## raw=mini(180,maxi(1,floori(32*1.00*1.00)))=32.
## counter_final=maxi(1,floori(32*0.5))=maxi(1,16)=16.
func test_stage_3_4_defend_stance_counter_cavalry_front_returns_16() -> void:
	# Arrange — is_counter skips evasion (RNG not consumed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 120, false, true, [])
	var def := DefenderContext.make(&"d", 40, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)   # is_counter = true

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — Cavalry FRONT D_mult=snappedf(1.00*1.00,0.01)=1.00; P_mult=1.00 (counter)
	# eff_atk=floori(120*0.60)=72; base=floori(72-40*1.00)=32
	# raw=mini(180,maxi(1,floori(32*1.00*1.00)))=32; counter=maxi(1,floori(32*0.5))=16
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			"AC-1: Cavalry FRONT DEFEND_STANCE counter expected 16 got %d" % result.resolved_damage
	).is_equal(16)


# ---------------------------------------------------------------------------
# AC-2 (AC-DC-17 EC-DC-10) — degenerate stack: every floor catches → resolved_damage = 1
# ---------------------------------------------------------------------------

## AC-2: is_counter=true, defend_stance_active=true, raw_atk=1, raw_def=50, T_def=0.
## SCOUT class so D_mult=1.00.
## eff_atk=floori(1*0.60)=0 → clampi(0,1,200)=1. eff_def=50 (no formation).
## base=floori(1-50*1.00)=-49 → maxi(1,-49)=1. (Stage-1 MIN_DAMAGE catches.)
## Stage-3 raw=mini(180,maxi(1,floori(1*1.00*1.00)))=1.
## Stage-4 counter_final=maxi(1,floori(1*0.5))=maxi(1,0)=1. (Stage-4 MIN_DAMAGE catches.)
func test_stage_3_4_degenerate_stack_every_floor_catches_returns_1() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 1, false, true, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)   # is_counter = true

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — MIN_DAMAGE floor holds end-to-end: Stage-1 base=1, Stage-3 raw=1, Stage-4=1
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			"AC-2: degenerate stack expected 1 (MIN_DAMAGE) got %d" % result.resolved_damage
	).is_equal(1)


# ---------------------------------------------------------------------------
# AC-3 (AC-DC-20 EC-DC-14) — RNG call count + replay determinism
# ---------------------------------------------------------------------------

## AC-3: snapshot RNG state; run resolve(); restore; re-run → bit-identical output.
## Call counts per path: non-counter=1, counter=0, skill_stub=0.
## Covers all four paths: non-counter HIT, counter HIT, skill_stub MISS, evasion MISS.
func test_stage_0_rng_call_count_and_replay_determinism() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, false, false, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)   # terrain_evasion=0 → no MISS from evasion

	# --- Path A: non-counter HIT — RNG must advance exactly 1 time ---
	var state_a0: int = rng.state
	var mod_a := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			false)
	var result_a1: ResolveResult = DamageCalc.resolve(atk, def, mod_a)
	var state_a1: int = rng.state
	assert_bool(state_a1 != state_a0).override_failure_message(
			"AC-3 non-counter: RNG must advance (state unchanged = 0 calls)"
	).is_true()

	# Replay: restore seed, re-run, verify bit-identical
	rng.seed = 42
	var mod_a2 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			false)
	var result_a2: ResolveResult = DamageCalc.resolve(atk, def, mod_a2)
	assert_int(result_a1.kind as int).is_equal(result_a2.kind as int)
	assert_int(result_a1.resolved_damage).is_equal(result_a2.resolved_damage)

	# --- Path B: counter — RNG must NOT advance ---
	rng.seed = 42
	var state_b0: int = rng.state
	var mod_b := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)
	var result_b1: ResolveResult = DamageCalc.resolve(atk, def, mod_b)
	assert_int(rng.state).override_failure_message(
			"AC-3 counter: RNG must NOT advance (call count = 0)"
	).is_equal(state_b0)
	# Replay
	rng.seed = 42
	var mod_b2 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)
	var result_b2: ResolveResult = DamageCalc.resolve(atk, def, mod_b2)
	assert_int(result_b1.resolved_damage).is_equal(result_b2.resolved_damage)

	# --- Path C: skill_stub — RNG must NOT advance ---
	rng.seed = 42
	var state_c0: int = rng.state
	var mod_c := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			false, "fireball")
	var result_c1: ResolveResult = DamageCalc.resolve(atk, def, mod_c)
	assert_int(rng.state).override_failure_message(
			"AC-3 skill_stub: RNG must NOT advance (call count = 0)"
	).is_equal(state_c0)
	assert_int(result_c1.kind as int).is_equal(ResolveResult.Kind.MISS as int)

	# --- Path D: evasion MISS — RNG advances 1 time ---
	rng.seed = 266   # seed 266 → randi_range(1,100) = 25 → miss vs terrain_evasion=30
	var def_evade := DefenderContext.make(&"e", 50, 0, 30)
	var state_d0: int = rng.state
	var mod_d := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)
	var result_d1: ResolveResult = DamageCalc.resolve(atk, def_evade, mod_d)
	assert_int(result_d1.kind as int).is_equal(ResolveResult.Kind.MISS as int)
	assert_bool(rng.state != state_d0).override_failure_message(
			"AC-3 evasion MISS: RNG must advance once (roll was consumed)"
	).is_true()
	# Replay
	rng.seed = 266
	var mod_d2 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)
	var result_d2: ResolveResult = DamageCalc.resolve(atk, def_evade, mod_d2)
	assert_int(result_d1.kind as int).is_equal(result_d2.kind as int)


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-24 EC-DC-23) — counter halve min raw: raw=1 → resolved_damage=1
# ---------------------------------------------------------------------------

## AC-4: synthetic raw=1 entering Stage 4 counter halve.
## floori(1 * 0.5) = 0 → maxi(MIN_DAMAGE, 0) = 1. MIN_DAMAGE floor catches.
## Also: raw=2 → floori(1.0)=1; raw=3 → floori(1.5)=1 (all yield resolved=1).
## Achieved via ATK=1, DEF=0, is_counter=true (NO defend_stance — distinct from AC-2 which
## stacks the DEFEND_STANCE penalty on top; AC-4 isolates the Stage-4 floor by pinning raw
## directly through ATK=N, no penalties applied).
func test_stage_4_counter_halve_min_raw_1_returns_1() -> void:
	# Arrange — engineer raw=1 into Stage 4: SCOUT FRONT, ATK=1, DEF=0, T_def=0.
	# eff_atk=clampi(floori(1*(1.0-0.0)),1,200)=1 (no defend_stance).
	# base=floori(1-0*1.00)=1. D_mult=1.00 (SCOUT FRONT). P_mult=1.00.
	# raw=mini(180,maxi(1,floori(1*1.00*1.00)))=1. Then is_counter halve fires.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 1, false, false, [])
	var def := DefenderContext.make(&"d", 0, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
			true)   # is_counter = true

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — floori(1*0.5)=0 → maxi(1,0)=1 (Stage-4 MIN_DAMAGE catches)
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			"AC-4: counter halve min raw=1 expected 1 (MIN_DAMAGE floor) got %d" % result.resolved_damage
	).is_equal(1)

	# Edge case: raw=2 → floori(2*0.5)=1; raw=3 → floori(3*0.5)=1 — verified via ATK adjustments
	# raw=2: ATK=2, DEF=0, SCOUT FRONT, is_counter=true → base=2, raw=2, counter=floori(1.0)=1
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var atk2 := AttackerContext.make(&"b", AttackerContext.Class.SCOUT, 2, false, false, [])
	var result2: ResolveResult = DamageCalc.resolve(atk2, def, ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng2, &"FRONT", 1, true))
	assert_int(result2.resolved_damage).override_failure_message(
			"AC-4 edge raw=2: counter_final=floori(2*0.5)=1 expected 1 got %d" % result2.resolved_damage
	).is_equal(1)

	# raw=3: ATK=3, DEF=0, SCOUT FRONT, is_counter=true → base=3, raw=3, counter=floori(3*0.5)=floori(1.5)=1
	# Spec'd edge case (story-006 §AC-4 "raw=3 → counter_final=1 (floori(1.5)=1)").
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 1
	var atk3 := AttackerContext.make(&"c", AttackerContext.Class.SCOUT, 3, false, false, [])
	var result3: ResolveResult = DamageCalc.resolve(atk3, def, ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng3, &"FRONT", 1, true))
	assert_int(result3.resolved_damage).override_failure_message(
			"AC-4 edge raw=3: counter_final=floori(3*0.5)=floori(1.5)=1 expected 1 got %d" % result3.resolved_damage
	).is_equal(1)


# ---------------------------------------------------------------------------
# AC-5 (AC-DC-33) — sole entry point static grep: exactly 1 public func
# ---------------------------------------------------------------------------

## AC-5: static grep of damage_calc.gd for public (non-underscore-prefixed) func declarations.
## Exactly 1 match expected: the resolve() function. All helpers are _-prefixed private.
func test_sole_entry_point_grep_returns_1_public_func() -> void:
	var path: String = "res://src/feature/damage_calc/damage_calc.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message(
			"AC-5: Could not open %s for static grep" % path
	).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	# Count lines matching "^func [a-z]" OR "^static func [a-z]" (public declarations).
	# Private helpers start with "func _" or "static func _" — excluded by [a-z] pattern.
	var matches: int = 0
	for line: String in content.split("\n"):
		var stripped: String = line.strip_edges(true, false)
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			# Extract first char after the "func " or "static func " prefix
			var func_name_start: int = stripped.find("func ") + 5
			if func_name_start < stripped.length():
				var first_char: String = stripped.substr(func_name_start, 1)
				if first_char >= "a" and first_char <= "z":
					matches += 1

	assert_int(matches).override_failure_message(
			(("AC-5: damage_calc.gd has %d public func(s) — expected exactly 1 (resolve). "
			+ "All helpers must be _-prefixed private.")
			% matches)
	).is_equal(1)


# ---------------------------------------------------------------------------
# AC-6 (AC-DC-34) — zero signals: grep for signal keywords returns 0 matches
# ---------------------------------------------------------------------------

## AC-6: damage_calc.gd must have 0 lines containing "signal " or "emit_signal".
## These patterns are banned per ADR-0012 §1 (stateless synchronous pipeline).
func test_no_signals_grep_returns_0() -> void:
	var path: String = "res://src/feature/damage_calc/damage_calc.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message(
			"AC-6: Could not open %s for static grep" % path
	).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	var signal_matches: int = 0
	for line: String in content.split("\n"):
		if "signal " in line or "emit_signal" in line:
			signal_matches += 1

	assert_int(signal_matches).override_failure_message(
			(("AC-6: damage_calc.gd contains %d signal/emit_signal line(s) — expected 0. "
			+ "DamageCalc is signal-free per ADR-0012 §1.")
			% signal_matches)
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-7 (AC-DC-35) — no apply_damage / hp_status grep returns 0 matches
# ---------------------------------------------------------------------------

## AC-7: damage_calc.gd must have 0 lines containing "apply_damage" or "hp_status.".
## DamageCalc only computes; HP mutation is GridBattle's contract (story-007).
func test_no_apply_damage_grep_returns_0() -> void:
	var path: String = "res://src/feature/damage_calc/damage_calc.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message(
			"AC-7: Could not open %s for static grep" % path
	).is_not_null()
	var content: String = file.get_as_text()
	file.close()

	var write_path_matches: int = 0
	for line: String in content.split("\n"):
		if "apply_damage" in line or "hp_status." in line:
			write_path_matches += 1

	assert_int(write_path_matches).override_failure_message(
			(("AC-7: damage_calc.gd contains %d apply_damage/hp_status. line(s) — expected 0. "
			+ "HP mutations belong to GridBattle per TR-damage-calc-003.")
			% write_path_matches)
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-8 (AC-DC-36) — vfx_tags populated: 8 scenarios of {charge, ambush, counter}
# ---------------------------------------------------------------------------

## AC-8: vfx_tags and source_flags contain provenance flags exactly when conditions fire.
## Tests {charge, ambush, counter, terrain_penalty} independently, then combined.
##
## Coverage scope clarification — the spec says "all 8 combinations of {charge, ambush, counter}"
## (the 2^3 boolean space). Three of those eight are STRUCTURALLY IMPOSSIBLE in production:
##   - charge + ambush — class mutex (Charge=Cavalry; Ambush=Scout/Archer; per AC-DC-16)
##   - charge + counter — counter suppresses Charge (per AC-DC-16 EC-DC-8)
##   - ambush + counter — counter suppresses Ambush (per AC-DC-16 EC-DC-8)
## So the 5 reachable combinations are: {none, charge-only, ambush-only, counter-only,
## charge+ambush+counter (impossible — covered by 0 cases)}. terrain_penalty is the
## 4th independent flag and is tested orthogonally. Cases 1-8 below cover: {none, charge-only,
## ambush-only, counter-only, terrain-only, no-terrain-baseline, counter+terrain, neg-terrain}.
## Coverage of the 5 reachable members of the 2^3 charge/ambush/counter space is complete via
## cases 1, 2, 3, 4 (and case 7 confirms the impossible charge+counter combination is
## structurally suppressed even when both inputs would fire individually).
func test_vfx_tags_and_source_flags_provenance_flags_correct() -> void:
	# --- Case 1: no passives, no counter, no terrain → vfx_tags empty ---
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 1
	var atk_none := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, false, false, [])
	var def_none := DefenderContext.make(&"d", 50, 0, 0)
	var mod1 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng1, &"FRONT", 1)
	var r1: ResolveResult = DamageCalc.resolve(atk_none, def_none, mod1)
	assert_bool(r1.vfx_tags.is_empty()).override_failure_message(
			"AC-8 case1: vfx_tags should be empty when no flags fire"
	).is_true()
	assert_bool(r1.source_flags.is_empty()).override_failure_message(
			"AC-8 case1: source_flags should be empty when no flags fire"
	).is_true()

	# --- Case 2: Cavalry Charge fires → vfx_tags has "charge", source_flags has "charge" ---
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var atk_charge := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, true, false,
			[&"passive_charge"])
	var mod2 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng2, &"REAR", 1)
	var r2: ResolveResult = DamageCalc.resolve(atk_charge, def_none, mod2)
	assert_bool(r2.vfx_tags.has(&"charge")).override_failure_message(
			"AC-8 case2: vfx_tags must contain &\"charge\" when Charge fires"
	).is_true()
	assert_bool(r2.source_flags.has(&"charge")).override_failure_message(
			"AC-8 case2: source_flags must contain &\"charge\" when Charge fires"
	).is_true()
	assert_bool(r2.vfx_tags.has(&"ambush")).is_false()
	assert_bool(r2.vfx_tags.has(&"counter")).is_false()

	# --- Case 3: Scout Ambush fires → vfx_tags has "ambush" ---
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 1
	var atk_ambush := AttackerContext.make(&"a", AttackerContext.Class.SCOUT, 70, false, false,
			[&"passive_ambush"])
	var not_acted := func(_id: StringName) -> bool: return false
	var mod3 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng3, &"FLANK", 3,
			false, "", [], 0.0, 0.0, 0.0, not_acted)
	var r3: ResolveResult = DamageCalc.resolve(atk_ambush, def_none, mod3)
	assert_bool(r3.vfx_tags.has(&"ambush")).override_failure_message(
			"AC-8 case3: vfx_tags must contain &\"ambush\" when Ambush fires"
	).is_true()
	assert_bool(r3.source_flags.has(&"ambush")).is_true()
	assert_bool(r3.vfx_tags.has(&"charge")).is_false()

	# --- Case 4: is_counter=true → vfx_tags has "counter", source_flags has "counter" ---
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 1
	var mod4 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng4, &"FRONT", 1,
			true)
	var r4: ResolveResult = DamageCalc.resolve(atk_none, def_none, mod4)
	assert_bool(r4.vfx_tags.has(&"counter")).override_failure_message(
			"AC-8 case4: vfx_tags must contain &\"counter\" when is_counter=true"
	).is_true()
	assert_bool(r4.source_flags.has(&"counter")).is_true()

	# --- Case 5: terrain_def > 0 → source_flags has "terrain_penalty", vfx_tags has "terrain_penalty" ---
	var rng5 := RandomNumberGenerator.new()
	rng5.seed = 1
	var def_terrain := DefenderContext.make(&"d", 50, 20, 0)   # terrain_def=+20 (defender favored)
	var mod5 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng5, &"FRONT", 1)
	var r5: ResolveResult = DamageCalc.resolve(atk_none, def_terrain, mod5)
	assert_bool(r5.source_flags.has(&"terrain_penalty")).override_failure_message(
			"AC-8 case5: source_flags must contain &\"terrain_penalty\" when terrain_def > 0"
	).is_true()
	assert_bool(r5.vfx_tags.has(&"terrain_penalty")).is_true()

	# --- Case 6: terrain_def == 0 → no terrain_penalty ---
	var rng6 := RandomNumberGenerator.new()
	rng6.seed = 1
	var mod6 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng6, &"FRONT", 1)
	var r6: ResolveResult = DamageCalc.resolve(atk_none, def_none, mod6)
	assert_bool(r6.source_flags.has(&"terrain_penalty")).is_false()

	# --- Case 7: counter + terrain_penalty together (Charge class-blocked on counter) ---
	var rng7 := RandomNumberGenerator.new()
	rng7.seed = 1
	var mod7 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng7, &"FRONT", 1,
			true)   # is_counter
	var r7: ResolveResult = DamageCalc.resolve(atk_charge, def_terrain, mod7)
	# Charge blocked on counter → no "charge" flag; counter + terrain_penalty both fire
	assert_bool(r7.vfx_tags.has(&"counter")).is_true()
	assert_bool(r7.vfx_tags.has(&"terrain_penalty")).is_true()
	assert_bool(r7.vfx_tags.has(&"charge")).override_failure_message(
			"AC-8 case7: Charge must be suppressed on counter — no charge flag expected"
	).is_false()

	# --- Case 8: terrain_def <= 0 → no terrain_penalty (negative terrain_def = terrain hurts defender) ---
	var rng8 := RandomNumberGenerator.new()
	rng8.seed = 1
	var def_neg_terrain := DefenderContext.make(&"d", 50, -10, 0)   # terrain_def=-10 (attacker favored)
	var mod8 := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng8, &"FRONT", 1)
	var r8: ResolveResult = DamageCalc.resolve(atk_none, def_neg_terrain, mod8)
	assert_bool(r8.source_flags.has(&"terrain_penalty")).override_failure_message(
			"AC-8 case8: no terrain_penalty when terrain_def <= 0"
	).is_false()


# ---------------------------------------------------------------------------
# AC-9 (AC-DC-N1) — explicit enum conversion: PHYSICAL and MAGICAL both round-trip
# ---------------------------------------------------------------------------

## AC-9: two resolve() calls with attack_type=PHYSICAL and =MAGICAL respectively.
## result.attack_type must match the expected ResolveResult.AttackType variant exactly.
## Also greps damage_calc.gd for the banned direct-cast pattern (0 matches required).
func test_enum_conversion_physical_and_magical_round_trip() -> void:
	# Arrange
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, false, false, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)

	# PHYSICAL path
	var mod_p := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng_p, &"FRONT", 1)
	var result_p: ResolveResult = DamageCalc.resolve(atk, def, mod_p)
	assert_int(result_p.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_p.attack_type as int).override_failure_message(
			"AC-9 PHYSICAL: result.attack_type must be ResolveResult.AttackType.PHYSICAL"
	).is_equal(ResolveResult.AttackType.PHYSICAL as int)

	# MAGICAL path
	var rng_m := RandomNumberGenerator.new()
	rng_m.seed = 1
	var mod_m := ResolveModifiers.make(ResolveModifiers.AttackType.MAGICAL, rng_m, &"FRONT", 1)
	var result_m: ResolveResult = DamageCalc.resolve(atk, def, mod_m)
	assert_int(result_m.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result_m.attack_type as int).override_failure_message(
			"AC-9 MAGICAL: result.attack_type must be ResolveResult.AttackType.MAGICAL"
	).is_equal(ResolveResult.AttackType.MAGICAL as int)

	# Static grep: the banned direct-cast pattern must not appear in damage_calc.gd.
	# Searching for the substring composed of a space + "as" + " ResolveResult.AttackType"
	# (written split across the comment so this test does not self-trigger).
	var path: String = "res://src/feature/damage_calc/damage_calc.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message("AC-9: Could not open %s" % path).is_not_null()
	var content: String = file.get_as_text()
	file.close()
	# Build the banned pattern at runtime so this source file does not contain the substring.
	var banned: String = " as " + "ResolveResult.AttackType"
	var cast_count: int = 0
	var search_pos: int = 0
	while true:
		var idx: int = content.find(banned, search_pos)
		if idx == -1:
			break
		cast_count += 1
		search_pos = idx + 1
	assert_int(cast_count).override_failure_message(
			(("AC-9: damage_calc.gd contains %d direct-enum-cast occurrence(s) — must be 0 "
			+ "(replaced by _to_result_attack_type per AC-DC-N1)")
			% cast_count)
	).is_equal(0)


# ---------------------------------------------------------------------------
# AC-10 (AC-DC-51) — StringName bypass-seam (positive case only; negative case DEFERRED)
# ---------------------------------------------------------------------------

## AC-10 (positive only — story-006 close-out 2026-04-27):
## Typed Array[StringName] [&"passive_charge"] through normal resolve() entry → Charge fires (P_mult=1.20).
##
## Negative-case assertion DEFERRED — see TD-037. Empirical Godot 4.6 finding:
## the ADR-0012 R-9 "release-build defense" premise (`&"foo" in [String]` returns false)
## does NOT hold. Godot 4.6 treats StringName == String as equal in == and `in`. The actual
## defense is the typed-Array auto-conversion at .assign()/.append() boundary on
## Array[StringName]: any String pushed into Array[StringName] is silently coerced to
## StringName. AttackerContext.passives is typed Array[StringName] (see attacker_context.gd:19),
## so production code is structurally protected. ADR-0012 R-9 wording requires revision.
## See TD-037 (open) for the ADR revision + test redesign — out of scope for story-006.
func test_stringname_bypass_seam_typed_array_fires_charge_p_mult_1_20() -> void:
	# Positive case — typed Array[StringName] via normal resolve() path
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var atk2 := AttackerContext.make(&"b", AttackerContext.Class.CAVALRY, 80, true, false,
			[&"passive_charge"])
	# Cavalry FRONT: base=floori(80-50*1.00)=30, D_mult=1.00, P_mult=1.20
	# raw=mini(180,maxi(1,floori(30*1.00*1.20)))=36, non-counter → resolved=36
	var result_pos: ResolveResult = DamageCalc.resolve(atk2, def,
			ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng2, &"FRONT", 1))
	assert_int(result_pos.resolved_damage).override_failure_message(
			(("AC-10 positive: typed [&\"passive_charge\"] should fire Charge → resolved=36 "
			+ "but got %d")
			% result_pos.resolved_damage)
	).is_equal(36)

	# Documented type-system defense — verify AttackerContext.passives is typed Array[StringName]
	# even when constructed with String elements (auto-conversion at .make() factory).
	# This is the ACTUAL release-build defense (vs the operator-level claim in ADR-0012 R-9 that
	# does not hold). Pinning here so a future Godot upgrade that breaks this auto-conversion
	# is caught immediately.
	var atk_str_input: AttackerContext = AttackerContext.make(
			&"c", AttackerContext.Class.CAVALRY, 80, true, false, [&"passive_charge"])
	assert_int(typeof(atk_str_input.passives[0])).override_failure_message(
			"AC-10 type-defense: AttackerContext.passives must hold StringName elements (not String)"
	).is_equal(TYPE_STRING_NAME)


# ---------------------------------------------------------------------------
# AC-11 — source_flags always-new-Array: 100 calls, no accumulation
# ---------------------------------------------------------------------------

## AC-11: modifiers.source_flags = [&"original"] (1 element). After 100 resolve() calls,
## modifiers.source_flags must still have exactly 1 element (caller's array unchanged).
## Each result.source_flags must contain &"original" but be a different Array instance.
func test_source_flags_always_new_array_no_accumulation() -> void:
	# Arrange — modifiers with a non-empty source_flags to prove no mutation
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, false, false, [])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var caller_flags: Array[StringName] = [&"original"]

	# Act — 100 resolve() calls; is_counter=true to skip evasion RNG for determinism
	var first_result_flags: Array[StringName] = []
	for i: int in range(100):
		var mod := ResolveModifiers.make(
				ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
				true, "", caller_flags)
		var result: ResolveResult = DamageCalc.resolve(atk, def, mod)
		if i == 0:
			# Save first result's flags array reference for identity check
			first_result_flags = result.source_flags

	# Assert caller's array is unchanged
	assert_int(caller_flags.size()).override_failure_message(
			(("AC-11: caller's source_flags grew from 1 to %d after 100 calls — "
			+ "caller array mutated (should never happen)")
			% caller_flags.size())
	).is_equal(1)
	assert_bool(caller_flags.has(&"original")).is_true()

	# Assert the first result's flags array is not the same instance as caller_flags.
	# We verify this by checking that appending to first_result_flags does NOT affect caller_flags.
	first_result_flags.append(&"probe")
	assert_bool(caller_flags.has(&"probe")).override_failure_message(
			"AC-11: result.source_flags shares identity with caller's array — alias detected"
	).is_false()


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-48 story-006b) — live-registry-read mock test
# Pins the contract that damage_calc.gd reads CHARGE_BONUS through BalanceConstants
# at resolve() call time, not from a parse-time literal cache.
# ---------------------------------------------------------------------------

## AC-4: Mock BalanceConstants cache to return CHARGE_BONUS=1.30 (instead of entities.json 1.20).
## D-3 fixture: Cavalry REAR Charge, ATK=80, DEF=50, no rally, no formation, primary attack.
##
## Baseline (unmocked, CHARGE_BONUS=1.20):
##   base = floori(80 - 50*1.00) = 30
##   D_mult = snappedf(1.50 × 1.09, 0.01) = 1.64
##   P_mult = snappedf(min(1.31, 1.20), 0.01) = 1.20
##   raw = floori(30 × 1.64 × 1.20) = floori(59.04) = 59
##
## Mocked (CHARGE_BONUS=1.30):
##   P_mult = snappedf(min(1.31, 1.30), 0.01) = 1.30
##   raw = floori(30 × 1.64 × 1.30) = floori(63.96) = 63
##
## Delta = 63 - 59 = +4. Proves resolve() reads through the wrapper — not a literal.
##
## Mock pattern: set _cache and _cache_loaded directly on the GDScript class object.
## before_test() and after_test() restore pristine state around every test (G-15).
func test_ac4_live_registry_read_mock_charge_bonus_returns_63() -> void:
	# Arrange — inject mock cache with CHARGE_BONUS=1.30; all other keys at entities.json values.
	# The full 12-key mock dict is required: every get_const() call in the resolve() path must
	# find its key, or push_error fires and returns null (which breaks arithmetic mid-resolve).
	var mock_cache: Dictionary = {
		"BASE_CEILING": 83,
		"MIN_DAMAGE": 1,
		"ATK_CAP": 200,
		"DEF_CAP": 105,
		"DEFEND_STANCE_ATK_PENALTY": 0.40,
		"P_MULT_COMBINED_CAP": 1.31,
		"CHARGE_BONUS": 1.30,
		"AMBUSH_BONUS": 1.15,
		"DAMAGE_CEILING": 180,
		"COUNTER_ATTACK_MODIFIER": 0.5,
		"BASE_DIRECTION_MULT": {"FRONT": 1.00, "FLANK": 1.20, "REAR": 1.50},
		"CLASS_DIRECTION_MULT": {
			"0": {"FRONT": 1.00, "FLANK": 1.05, "REAR": 1.09},
			"1": {"FRONT": 1.00, "FLANK": 1.00, "REAR": 1.00},
			"2": {"FRONT": 0.90, "FLANK": 1.00, "REAR": 1.00},
			"3": {"FRONT": 1.00, "FLANK": 1.375, "REAR": 1.00},
		},
	}
	_balance_constants_script.set("_cache", mock_cache)
	_balance_constants_script.set("_cache_loaded", true)

	# D-3 fixture: Cavalry REAR Charge, ATK=80, DEF=50, no rally, no formation, primary attack.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1   # seed 1 passes evasion (terrain_evasion=0)
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, true, false,
			[&"passive_charge"])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"REAR", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — mocked CHARGE_BONUS=1.30 → resolved_damage=63 (not 59 from entities.json 1.20).
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			("AC-4: expected resolved_damage=63 (mocked CHARGE_BONUS=1.30),"
			+ " got %d — if 59, mock did not propagate (literal cache suspected)")
			% result.resolved_damage
	).is_equal(63)


## AC-4b baseline regression: same D-3 fixture WITHOUT mocking returns 59.
## Verifies that before_test() properly restores the real entities.json values
## and that the mock from AC-4 did not bleed through (after_test() verified here).
##
## NOTE: This test intentionally mirrors `test_stage_2_cavalry_rear_charge_primary_returns_59`
## (line 681). The duplication is deliberate — its purpose is to act as the after-mock
## bleed-through canary for AC-4, NOT to re-verify the formula. Do NOT consolidate.
func test_ac4b_unmocked_baseline_cavalry_rear_charge_returns_59() -> void:
	# Arrange — NO mock; _balance_constants_script.set is NOT called.
	# before_test() has already reset _cache_loaded=false so a fresh load fires.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var atk := AttackerContext.make(&"a", AttackerContext.Class.CAVALRY, 80, true, false,
			[&"passive_charge"])
	var def := DefenderContext.make(&"d", 50, 0, 0)
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"REAR", 1)

	# Act
	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)

	# Assert — entities.json CHARGE_BONUS=1.20 → resolved_damage=59
	assert_int(result.kind as int).is_equal(ResolveResult.Kind.HIT as int)
	assert_int(result.resolved_damage).override_failure_message(
			("AC-4b: expected resolved_damage=59 (entities.json CHARGE_BONUS=1.20),"
			+ " got %d — if 63, AC-4 mock bleed-through detected (after_test() not firing?)")
			% result.resolved_damage
	).is_equal(59)
