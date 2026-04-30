## Integration tests for DamageCalc ↔ GridBattle boundary — story-007.
##
## Covers AC-3 (AC-DC-29): dead-defender gate is Grid Battle's responsibility, not DamageCalc's.
## Covers AC-4 (AC-DC-31): ambush dead-defender gated upstream.
## Covers AC-5 (AC-DC-42): resolve() call-count exactly N for N expected interactions.
## Covers AC-6 (AC-DC-43): apply_damage called iff result is HIT; AoE coverage.
##
## All tests are deterministic: no randomness, no time-dependent assertions, no I/O.
## RNG is injected with a fixed seed per call per F-DC-1 Guard 2.
##
## GridBattleStub is a file-local class (not class_name) that orchestrates
## DamageCalc.resolve() + simulated hp_status.apply_damage() + counter-eligibility
## gate + dead-defender pre-condition gate. It records call counts for assertions.
##
## HIT/MISS discrimination: result.kind == ResolveResult.Kind.HIT (not source_flags).
##
## Seeding notes (verified against Godot 4.6 randi_range(1, 100)):
##   seed=0  → first roll is high (> 30)  → EVASION PASSES (terrain_evasion <= 30 → HIT)
##   seed=266 → first roll = 25            → EVASION MISS when terrain_evasion >= 25
##
## No scene-tree dependency — all classes are RefCounted; no Node orphans possible.
##
## ADR reference:    ADR-0012 (Damage Calc)
## Story:            story-007 (F-GB-PROV retirement + Grid Battle integration)
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# File-local GridBattleStub — orchestrates resolve() + apply_damage tracking
# ---------------------------------------------------------------------------

## GridBattleStub simulates the Grid Battle layer that wraps DamageCalc.resolve().
## Responsibilities mirrored from the spec:
##   1. Pre-condition gate: dead defender → block before resolve() (AC-DC-29).
##   2. Primary resolve() call.
##   3. apply_damage() on HIT.
##   4. Counter-eligibility gate: only call resolve() again if defender_can_counter.
##   5. Counter resolve() on eligible defender (swapped roles, is_counter=true).
##   6. apply_damage() on counter HIT.
## AoE variant: attempt_aoe_attack() loops over an array of defenders.
class GridBattleStub:
	extends RefCounted

	var resolve_call_count: int = 0
	var apply_damage_call_count: int = 0
	var apply_damage_log: Array[int] = []


	## Primary-attack orchestration with dead-defender gate and optional counter.
	## Parameters:
	##   attacker        — AttackerContext for the primary attacker
	##   defender        — DefenderContext for the primary defender
	##   modifiers       — ResolveModifiers for the primary attack (is_counter must be false)
	##   defender_alive  — Grid Battle's pre-condition gate: skip all if false
	##   defender_can_counter — whether the defender is eligible to counter-attack
	func attempt_attack(
			attacker: AttackerContext,
			defender: DefenderContext,
			modifiers: ResolveModifiers,
			defender_alive: bool,
			defender_can_counter: bool) -> void:
		# Pre-condition gate (AC-DC-29): dead defender → block resolve()
		if not defender_alive:
			return

		# Primary attack
		resolve_call_count += 1
		var primary: ResolveResult = DamageCalc.resolve(attacker, defender, modifiers)

		if primary.kind == ResolveResult.Kind.HIT:
			_apply_damage(primary.resolved_damage)

			# Counter-eligibility gate (CR-6 + CR-13 rule 4 simulation).
			# Only proceed if defender is eligible. Counter: is_counter=true, roles swapped.
			if defender_can_counter:
				resolve_call_count += 1
				# Build counter modifiers: fresh RNG same seed, is_counter=true, skip evasion.
				var counter_rng := RandomNumberGenerator.new()
				counter_rng.seed = modifiers.rng.seed
				var counter_mod: ResolveModifiers = ResolveModifiers.make(
						modifiers.attack_type,
						counter_rng,
						&"FRONT",
						modifiers.round_number,
						true)  # is_counter = true
				# Roles swapped: defender becomes attacker, attacker becomes defender.
				# Test simplification (call-count-only assertions): build minimal counter
				# contexts from the original unit_ids; raw_def is used as a proxy ATK for
				# the counter attacker. NOT a production-faithful counter context — damage
				# magnitude is not asserted at this scope. If a future story needs to verify
				# counter damage values, build a separate stub with realistic counter ATK.
				var counter_attacker: AttackerContext = AttackerContext.make(
						defender.unit_id,
						AttackerContext.Class.INFANTRY,
						defender.raw_def,
						false, false, [])
				var counter_defender: DefenderContext = DefenderContext.make(
						attacker.unit_id,
						attacker.raw_atk,
						0, 0)
				var counter: ResolveResult = DamageCalc.resolve(
						counter_attacker, counter_defender, counter_mod)
				if counter.kind == ResolveResult.Kind.HIT:
					_apply_damage(counter.resolved_damage)
		# MISS path: no apply_damage, no counter (CR-2).


	## AoE attack orchestration: dispatches a primary attack for each target.
	## No counter logic — AoE attacks are non-counter primary calls.
	## Parameters:
	##   attacker  — shared attacker for all targets
	##   targets   — array of DefenderContext (all assumed alive — caller gates HP upstream)
	##   base_mod  — template modifiers; a fresh RNG is used per target for determinism
	func attempt_aoe_attack(
			attacker: AttackerContext,
			targets: Array[DefenderContext],
			base_mod: ResolveModifiers) -> void:
		for target: DefenderContext in targets:
			resolve_call_count += 1
			# Fresh seeded RNG per target to preserve determinism.
			var per_target_rng := RandomNumberGenerator.new()
			per_target_rng.seed = base_mod.rng.seed
			var target_mod: ResolveModifiers = ResolveModifiers.make(
					base_mod.attack_type,
					per_target_rng,
					base_mod.direction_rel,
					base_mod.round_number)
			var r: ResolveResult = DamageCalc.resolve(attacker, target, target_mod)
			if r.kind == ResolveResult.Kind.HIT:
				_apply_damage(r.resolved_damage)


	func _apply_damage(amount: int) -> void:
		apply_damage_call_count += 1
		apply_damage_log.append(amount)


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

## BalanceConstants script handle — used to reset the cache for test isolation.
var _balance_constants_script: GDScript = load("res://src/foundation/balance/balance_constants.gd")


## Per-test setup. Uses before_test() — the only GdUnit4 v6.1.2 lifecycle hook (G-15).
func before_test() -> void:
	# Reset BalanceConstants static cache for isolation (mirrors damage_calc_test.gd pattern).
	_balance_constants_script.set("_cache_loaded", false)
	_balance_constants_script.set("_cache", {})


## Per-test teardown.
func after_test() -> void:
	_balance_constants_script.set("_cache_loaded", false)
	_balance_constants_script.set("_cache", {})


## Build a minimal RNG with a given seed.
func _make_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


## Build a standard "live Infantry attacker" for the primary attack role.
## raw_atk=50 ensures eff_atk - eff_def > MIN_DAMAGE under default defender stats.
func _make_infantry_attacker(unit_id: StringName) -> AttackerContext:
	return AttackerContext.make(unit_id, AttackerContext.Class.INFANTRY, 50, false, false, [])


## Build a standard "live Infantry defender" with zero evasion (always HIT on seed=0).
func _make_live_defender(unit_id: StringName) -> DefenderContext:
	return DefenderContext.make(unit_id, 10, 0, 0)


## Build a dead defender (HP=0 has no field in DefenderContext — the dead flag is passed
## separately as `defender_alive=false` to the stub, matching the spec design).
## The DefenderContext itself is the same shape; the gate is entirely in the stub.
func _make_dead_defender(unit_id: StringName) -> DefenderContext:
	return DefenderContext.make(unit_id, 10, 0, 0)


## Build a standard PHYSICAL FRONT modifiers block, seeded for guaranteed HIT.
## seed=0 → first randi_range(1,100) produces a value > 30, so terrain_evasion=0 → HIT.
func _make_hit_modifiers(round_number: int = 1) -> ResolveModifiers:
	return ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL,
			_make_rng(0),
			&"FRONT",
			round_number)


## Build modifiers that produce a forced MISS via high terrain evasion.
## Defender terrain_evasion=30 + seed=266 → roll=25 ≤ 30 → MISS (evasion).
func _make_miss_defender() -> DefenderContext:
	return DefenderContext.make(&"evader", 10, 0, 30)


func _make_miss_modifiers() -> ResolveModifiers:
	# seed=266 → first randi_range(1,100) = 25 ≤ terrain_evasion=30 → MISS
	return ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL,
			_make_rng(266),
			&"FRONT",
			1)


# ---------------------------------------------------------------------------
# AC-3 (AC-DC-29) — dead-defender gate is Grid Battle's responsibility
# ---------------------------------------------------------------------------

## AC-3a: DamageCalc.resolve() called DIRECTLY with HP=0 defender returns HIT.
## Proves DamageCalc has NO internal dead-defender guard (AC-DC-29).
func test_dead_defender_returns_hit_when_called_directly() -> void:
	# Arrange
	var attacker: AttackerContext = _make_infantry_attacker(&"atk_a")
	var dead_defender: DefenderContext = _make_dead_defender(&"dead_def")
	var modifiers: ResolveModifiers = _make_hit_modifiers()

	# Act — direct resolve(), bypassing GridBattleStub
	var result: ResolveResult = DamageCalc.resolve(attacker, dead_defender, modifiers)

	# Assert: DamageCalc returns HIT (no internal dead-defender guard)
	assert_int(result.kind).is_equal(ResolveResult.Kind.HIT)
	assert_int(result.resolved_damage).is_greater_equal(1)
	assert_bool(result.source_flags.has(&"invariant_violation:dead_defender")).is_false()


## AC-3b: GridBattleStub blocks resolve() when defender is dead (defender_alive=false).
func test_grid_battle_stub_blocks_resolve_when_defender_dead() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"atk_b")
	var dead_defender: DefenderContext = _make_dead_defender(&"dead_def_b")
	var modifiers: ResolveModifiers = _make_hit_modifiers()

	# Act — stub gates on defender_alive=false
	stub.attempt_attack(attacker, dead_defender, modifiers, false, false)

	# Assert: gate fires before resolve(); zero calls
	assert_int(stub.resolve_call_count).is_equal(0)
	assert_int(stub.apply_damage_call_count).is_equal(0)


# ---------------------------------------------------------------------------
# AC-4 (AC-DC-31) — ambush dead-defender gated upstream
# ---------------------------------------------------------------------------

## AC-4a: Ambush attacker against dead defender — stub blocks before resolve().
func test_ambush_dead_defender_blocked_by_stub() -> void:
	# Arrange — Scout with passive_ambush, round=3 (satisfies ambush conditions)
	var stub := GridBattleStub.new()
	var scout_passives: Array[StringName] = [&"passive_ambush"]
	var attacker: AttackerContext = AttackerContext.make(
			&"scout_001", AttackerContext.Class.SCOUT, 50, false, false, scout_passives)
	var dead_defender: DefenderContext = _make_dead_defender(&"dead_def_c")
	var modifiers: ResolveModifiers = _make_hit_modifiers(3)  # round=3 qualifies for ambush

	# Act — defender_alive=false → pre-condition gate blocks
	stub.attempt_attack(attacker, dead_defender, modifiers, false, false)

	# Assert: gate fires upstream; resolve() never called
	assert_int(stub.resolve_call_count).is_equal(0)


## AC-4b: Ambush attacker against live defender — stub proceeds; resolve() called once.
func test_ambush_live_defender_proceeds_normally() -> void:
	# Arrange — Scout with passive_ambush, round=3, live defender
	var stub := GridBattleStub.new()
	var scout_passives: Array[StringName] = [&"passive_ambush"]
	var attacker: AttackerContext = AttackerContext.make(
			&"scout_002", AttackerContext.Class.SCOUT, 50, false, false, scout_passives)
	var live_defender: DefenderContext = _make_live_defender(&"live_def_d")
	# Inject acted_this_turn_callable returning false so ambush fires
	var not_acted: Callable = func(_uid: StringName) -> bool: return false
	var modifiers: ResolveModifiers = ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL,
			_make_rng(0),
			&"FRONT",
			3,  # round_number >= 2 satisfies ambush condition
			false, "", [], 0.0, 0.0, 0.0,
			not_acted)

	# Act — defender_alive=true → no gate; primary attack proceeds
	stub.attempt_attack(attacker, live_defender, modifiers, true, false)

	# Assert: resolve() called exactly once; result was HIT (ambush fires)
	assert_int(stub.resolve_call_count).is_equal(1)
	assert_int(stub.apply_damage_call_count).is_equal(1)
	assert_int(stub.apply_damage_log[0]).is_greater_equal(1)


# ---------------------------------------------------------------------------
# AC-5 (AC-DC-42) — resolve() call count exact
# ---------------------------------------------------------------------------

## AC-5a: Primary HIT + counter-eligible defender → exactly 2 resolve() calls.
func test_primary_hit_with_counter_eligible_defender_calls_resolve_twice() -> void:
	# Arrange — Infantry vs Infantry, FRONT, both alive, defender retains action
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"inf_atk")
	var defender: DefenderContext = _make_live_defender(&"inf_def")
	var modifiers: ResolveModifiers = _make_hit_modifiers()

	# Act — defender_can_counter=true
	stub.attempt_attack(attacker, defender, modifiers, true, true)

	# Assert: exactly 2 calls (primary + counter)
	assert_int(stub.resolve_call_count).is_equal(2)


## AC-5b: Primary HIT + non-counter-eligible defender → exactly 1 resolve() call.
func test_primary_hit_with_non_counter_eligible_defender_calls_resolve_once() -> void:
	# Arrange — same setup but defender cannot counter (CR-13 rule 4: suppress_counter flag)
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"inf_atk2")
	var defender: DefenderContext = _make_live_defender(&"inf_def2")
	var modifiers: ResolveModifiers = _make_hit_modifiers()

	# Act — defender_can_counter=false
	stub.attempt_attack(attacker, defender, modifiers, true, false)

	# Assert: exactly 1 call (primary only; no counter)
	assert_int(stub.resolve_call_count).is_equal(1)


## AC-5c: Primary MISS → no counter (CR-2) → exactly 1 resolve() call.
func test_primary_miss_does_not_trigger_counter() -> void:
	# Arrange — high evasion + seeded RNG forces MISS on primary
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"inf_atk3")
	var evader: DefenderContext = _make_miss_defender()
	var modifiers: ResolveModifiers = _make_miss_modifiers()

	# Act — defender_can_counter=true but MISS suppresses counter per CR-2
	stub.attempt_attack(attacker, evader, modifiers, true, true)

	# Assert: exactly 1 resolve() call (primary MISS only; no counter attempted)
	assert_int(stub.resolve_call_count).is_equal(1)
	assert_int(stub.apply_damage_call_count).is_equal(0)


# ---------------------------------------------------------------------------
# AC-6 (AC-DC-43) — apply_damage valid on HIT; AoE coverage
# ---------------------------------------------------------------------------

## AC-6a: Single HIT → apply_damage called exactly once with positive damage.
func test_single_hit_calls_apply_damage_once_with_positive_damage() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"inf_hit")
	var defender: DefenderContext = _make_live_defender(&"def_hit")
	var modifiers: ResolveModifiers = _make_hit_modifiers()

	# Act
	stub.attempt_attack(attacker, defender, modifiers, true, false)

	# Assert
	assert_int(stub.apply_damage_call_count).is_equal(1)
	assert_int(stub.apply_damage_log[0]).is_greater_equal(1)


## AC-6b: Single MISS → apply_damage NOT called.
func test_single_miss_does_not_call_apply_damage() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"inf_miss")
	var evader: DefenderContext = _make_miss_defender()
	var modifiers: ResolveModifiers = _make_miss_modifiers()

	# Act
	stub.attempt_attack(attacker, evader, modifiers, true, false)

	# Assert
	assert_int(stub.apply_damage_call_count).is_equal(0)


## AC-6c: AoE 6 targets all HIT → apply_damage called exactly 6 times.
## All 6 defenders have terrain_evasion=0; seed=0 guarantees HIT on each.
func test_aoe_six_targets_all_hit_calls_apply_damage_six_times() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"aoe_atk")
	var targets: Array[DefenderContext] = []
	for i: int in range(6):
		targets.append(DefenderContext.make(&"target_%d" % i, 10, 0, 0))
	var base_mod: ResolveModifiers = _make_hit_modifiers()

	# Act
	stub.attempt_aoe_attack(attacker, targets, base_mod)

	# Assert: 6 resolve() calls, 6 apply_damage calls, all positive
	assert_int(stub.resolve_call_count).is_equal(6)
	assert_int(stub.apply_damage_call_count).is_equal(6)
	for amount: int in stub.apply_damage_log:
		assert_int(amount).is_greater_equal(1)


## AC-6d: AoE 6 targets, 2 forced MISS → apply_damage called exactly 4 times;
## resolve() still called 6 times (one per target regardless of result).
## Forced MISS: 2 targets have terrain_evasion=30; remaining 4 have evasion=0.
## seed=266 → roll=25 ≤ 30 → MISS for evasion=30 targets.
## seed=0   → roll is high → HIT for evasion=0 targets.
func test_aoe_six_targets_two_miss_calls_apply_damage_four_times() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"aoe_atk2")

	# Build 6 targets: indices 0-3 have evasion=0 (will HIT), indices 4-5 have evasion=30 (will MISS)
	var targets: Array[DefenderContext] = []
	for i: int in range(4):
		targets.append(DefenderContext.make(&"target_hit_%d" % i, 10, 0, 0))
	for i: int in range(2):
		targets.append(DefenderContext.make(&"target_miss_%d" % i, 10, 0, 30))

	# Base modifiers use seed=266 (roll=25): evasion=0 targets are unaffected (25 > 0 → HIT);
	# evasion=30 targets: 25 ≤ 30 → MISS.
	var base_mod: ResolveModifiers = ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL,
			_make_rng(266),
			&"FRONT",
			1)

	# Act — attempt_aoe_attack uses fresh per-target RNG seeded from base_mod.rng.seed
	stub.attempt_aoe_attack(attacker, targets, base_mod)

	# Assert: resolve() called 6 times (one per target), apply_damage called 4 times
	assert_int(stub.resolve_call_count).is_equal(6)
	assert_int(stub.apply_damage_call_count).is_equal(4)


## AC-6e: AoE with 0 valid targets (all dead/out-of-range filtered upstream by Grid Battle)
## → 0 resolve() calls + 0 apply_damage calls.
## Story spec edge: "AoE with 0 valid targets (all dead/out-of-range) → 0 resolve() + 0 apply_damage".
## Verifies the per-target loop early-returns cleanly when given an empty array.
func test_aoe_empty_targets_calls_no_resolve_or_apply_damage() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"aoe_atk_empty")
	var targets: Array[DefenderContext] = []
	var base_mod: ResolveModifiers = _make_hit_modifiers()

	# Act
	stub.attempt_aoe_attack(attacker, targets, base_mod)

	# Assert: zero work performed; loop body never enters
	assert_int(stub.resolve_call_count).is_equal(0)
	assert_int(stub.apply_damage_call_count).is_equal(0)


## AC-6f: AoE 6 targets all MISS → resolve() called 6 times, apply_damage called 0 times.
## Story spec edge: "AoE with all MISS → 6 resolve() calls + 0 apply_damage calls".
## Distinct from AC-6d (partial MISS) — exercises the strict per-target HIT gating
## guarantee: apply_damage fires iff result.kind == HIT, never on batch-level outcome.
## All 6 targets have terrain_evasion=30; seed=266 → roll=25 ≤ 30 → MISS for all.
func test_aoe_six_targets_all_miss_calls_apply_damage_zero_times() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	var attacker: AttackerContext = _make_infantry_attacker(&"aoe_atk_all_miss")
	var targets: Array[DefenderContext] = []
	for i: int in range(6):
		targets.append(DefenderContext.make(&"target_evader_%d" % i, 10, 0, 30))
	# seed=266 → roll=25; evasion=30 → 25 ≤ 30 → MISS for all 6 targets.
	var base_mod: ResolveModifiers = ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL,
			_make_rng(266),
			&"FRONT",
			1)

	# Act
	stub.attempt_aoe_attack(attacker, targets, base_mod)

	# Assert: resolve() called once per target (6); apply_damage NEVER fires on MISS
	assert_int(stub.resolve_call_count).is_equal(6)
	assert_int(stub.apply_damage_call_count).is_equal(0)
