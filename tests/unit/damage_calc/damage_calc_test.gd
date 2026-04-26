## Unit tests for DamageCalc.resolve() Stage 0 — invariant guards + evasion roll.
## Covers story-003 AC-1 through AC-7 (AC-DC-18/19/22/28/10/14/26).
## No scene-tree dependency — extends GdUnitTestSuite (RefCounted-based).
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Shared test fixtures (re-created in before_test to ensure isolation per G-15)
# ---------------------------------------------------------------------------

var _atk: AttackerContext
var _def: DefenderContext


## Per-test setup. Uses before_test() — the only GdUnit4 v6.1.2 hook (G-15).
func before_test() -> void:
	_atk = AttackerContext.make(&"unit_a", AttackerContext.Class.INFANTRY, false, false, [])
	_def = DefenderContext.make(&"unit_b", 0, 0)


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
	var def := DefenderContext.make(&"unit_b", 0, 30)
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
	var def := DefenderContext.make(&"unit_b", 0, 30)
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
	var def := DefenderContext.make(&"unit_b", 0, 30)
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
	var def := DefenderContext.make(&"unit_b", 0, 30)
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
	var def := DefenderContext.make(&"unit_b", 0, 0)   # terrain_evasion = 0
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
	var def := DefenderContext.make(&"unit_b", 0, 0)
	var state_before: int = rng.state

	# Act — 100 counter-path resolve calls (is_counter = true)
	for i: int in range(100):
		var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1,
				true)   # is_counter = true
		DamageCalc.resolve(_atk, def, mod)

	# Assert — RNG state unchanged across all 100 calls
	assert_int(rng.state).is_equal(state_before)
