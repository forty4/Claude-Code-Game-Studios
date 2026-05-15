## damage_calc_high_ground_test.gd
##
## Session-15: ARCHER HIGH_GROUND_BONUS wiring in DamageCalc._high_ground_factor.
## Gates: unit_class == ARCHER, passive_high_ground_shot in passives, attack is
## not a counter, attacker.on_high_ground == true (HILLS terrain).
## Bonus value: HIGH_GROUND_BONUS = 1.15 (mirrors AMBUSH magnitude).
##
## Pattern mirrors the existing AMBUSH / CHARGE direct-resolve tests at the top
## of damage_calc_test.gd — round_number / counter / evasion all neutral so the
## only variable across paired cases is the high-ground boolean.
extends GdUnitTestSuite


func before_test() -> void:
	# G-15 + ADR-0006 §6: reset cached balance constants per test isolation.
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func _make_archer_on(coord_is_hills: bool) -> AttackerContext:
	return AttackerContext.make(
		&"archer_1",
		AttackerContext.Class.ARCHER,
		60,
		false,  # charge_active — irrelevant for ARCHER
		false,  # defend_stance_active
		[&"passive_high_ground_shot"],
		coord_is_hills,
	)


# ─── Positive case: ARCHER + passive + on HILLS + not counter → +15% ─────────


func test_high_ground_shot_bonus_fires_when_archer_on_hills() -> void:
	# Same fixture, only on_high_ground differs. Damage must be higher when on HILLS.
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 1
	var atk_off: AttackerContext = _make_archer_on(false)
	var def_off: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_off: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_a, &"FRONT", 1)
	var dmg_off: int = DamageCalc.resolve(atk_off, def_off, mod_off).resolved_damage

	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 1
	var atk_on: AttackerContext = _make_archer_on(true)
	var def_on: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_on: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_b, &"FRONT", 1)
	var dmg_on: int = DamageCalc.resolve(atk_on, def_on, mod_on).resolved_damage

	assert_int(dmg_on).override_failure_message(
		"ARCHER on HILLS damage (%d) must exceed off-HILLS baseline (%d) by ~15%%"
		% [dmg_on, dmg_off]
	).is_greater(dmg_off)


# ─── Class mutex: only ARCHER fires the bonus ────────────────────────────────


func test_high_ground_shot_blocked_for_non_archer() -> void:
	# INFANTRY with passive_high_ground_shot (test-only — production never sets
	# this combo) stays at baseline regardless of on_high_ground.
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 1
	var atk_a: AttackerContext = AttackerContext.make(
		&"a", AttackerContext.Class.INFANTRY, 60, false, false,
		[&"passive_high_ground_shot"], false)
	var def_a: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_a: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_a, &"FRONT", 1)
	var dmg_off: int = DamageCalc.resolve(atk_a, def_a, mod_a).resolved_damage

	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 1
	var atk_b: AttackerContext = AttackerContext.make(
		&"a", AttackerContext.Class.INFANTRY, 60, false, false,
		[&"passive_high_ground_shot"], true)
	var def_b: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_b: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_b, &"FRONT", 1)
	var dmg_on: int = DamageCalc.resolve(atk_b, def_b, mod_b).resolved_damage

	assert_int(dmg_on).override_failure_message(
		"INFANTRY damage must NOT shift across on_high_ground; got %d vs %d (class mutex)"
		% [dmg_on, dmg_off]
	).is_equal(dmg_off)


# ─── Passive missing: ARCHER without passive stays at baseline ───────────────


func test_high_ground_shot_blocked_without_passive() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 1
	var atk_a: AttackerContext = AttackerContext.make(
		&"a", AttackerContext.Class.ARCHER, 60, false, false, [], false)
	var def_a: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_a: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_a, &"FRONT", 1)
	var dmg_off: int = DamageCalc.resolve(atk_a, def_a, mod_a).resolved_damage

	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 1
	var atk_b: AttackerContext = AttackerContext.make(
		&"a", AttackerContext.Class.ARCHER, 60, false, false, [], true)
	var def_b: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_b: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_b, &"FRONT", 1)
	var dmg_on: int = DamageCalc.resolve(atk_b, def_b, mod_b).resolved_damage

	assert_int(dmg_on).override_failure_message(
		"ARCHER without passive must NOT shift with on_high_ground; got %d vs %d"
		% [dmg_on, dmg_off]
	).is_equal(dmg_off)


# ─── Counter suppression: bonus does not fire on counter-attack ──────────────


func test_high_ground_shot_blocked_when_counter() -> void:
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 1
	var atk_a: AttackerContext = _make_archer_on(true)
	var def_a: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_a: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_a, &"FRONT", 1, true)  # is_counter=true
	var dmg_counter_on: int = DamageCalc.resolve(atk_a, def_a, mod_a).resolved_damage

	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 1
	var atk_b: AttackerContext = _make_archer_on(false)
	var def_b: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod_b: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng_b, &"FRONT", 1, true)  # is_counter=true
	var dmg_counter_off: int = DamageCalc.resolve(atk_b, def_b, mod_b).resolved_damage

	assert_int(dmg_counter_on).override_failure_message(
		"counter damage must NOT shift with on_high_ground (counter suppression); got %d vs %d"
		% [dmg_counter_on, dmg_counter_off]
	).is_equal(dmg_counter_off)


# ─── Source flag + vfx tag emission ──────────────────────────────────────────


func test_resolve_emits_high_ground_source_flag_when_bonus_fires() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var atk: AttackerContext = _make_archer_on(true)
	var def: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)
	assert_bool(&"high_ground" in result.source_flags).override_failure_message(
		"resolve.source_flags must include &\"high_ground\" when bonus fires; got %s"
		% str(result.source_flags)
	).is_true()
	assert_bool(&"high_ground" in result.vfx_tags).override_failure_message(
		"resolve.vfx_tags must include &\"high_ground\" when bonus fires; got %s"
		% str(result.vfx_tags)
	).is_true()


func test_resolve_omits_high_ground_flag_when_off_hills() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var atk: AttackerContext = _make_archer_on(false)
	var def: DefenderContext = DefenderContext.make(&"d", 10, 0, 0)
	var mod: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	var result: ResolveResult = DamageCalc.resolve(atk, def, mod)
	assert_bool(&"high_ground" in result.source_flags).is_false()
	assert_bool(&"high_ground" in result.vfx_tags).is_false()
