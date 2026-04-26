## Unit tests for the 4 RefCounted wrapper classes: AttackerContext, DefenderContext,
## ResolveModifiers, ResolveResult. Covers story-002 AC-1 through AC-6.
## No scene-tree dependency — uses lightweight GdUnitTestSuite (RefCounted-based) per tests/README.md.
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# AC-1 + AC-2  AttackerContext
# ---------------------------------------------------------------------------

## AC-1: Default construction produces correct zero values and typed empty passives array.
func test_attacker_context_default_construction_produces_empty_typed_passives() -> void:
	# Arrange / Act
	var ctx := AttackerContext.new()

	# Assert
	assert_str(String(ctx.unit_id)).is_equal("")
	assert_int(ctx.unit_class).is_equal(0)   # CAVALRY = 0 per local enum
	assert_int(ctx.raw_atk).is_equal(0)
	assert_bool(ctx.charge_active).is_false()
	assert_bool(ctx.defend_stance_active).is_false()
	assert_array(ctx.passives).has_size(0)
	# Verify typed-array element type by appending a valid StringName element
	ctx.passives.append(&"ok")
	assert_array(ctx.passives).has_size(1)


## AC-2: make() factory assigns all fields to provided arguments.
func test_attacker_context_make_factory_assigns_all_fields() -> void:
	# Arrange
	var passives: Array[StringName] = [&"passive_charge"]

	# Act
	var ctx := AttackerContext.make(&"hero_001", AttackerContext.Class.CAVALRY, 80, true, false, passives)

	# Assert
	assert_str(String(ctx.unit_id)).is_equal("hero_001")
	assert_int(ctx.unit_class).is_equal(AttackerContext.Class.CAVALRY)
	assert_int(ctx.raw_atk).is_equal(80)
	assert_bool(ctx.charge_active).is_true()
	assert_bool(ctx.defend_stance_active).is_false()
	assert_array(ctx.passives).has_size(1)
	assert_str(String(ctx.passives[0])).is_equal("passive_charge")


# ---------------------------------------------------------------------------
# AC-3  DefenderContext
# ---------------------------------------------------------------------------

## AC-3a: DefenderContext default construction produces zero-valued fields.
func test_defender_context_default_construction_produces_zero_fields() -> void:
	# Arrange / Act
	var def_default := DefenderContext.new()

	# Assert
	assert_str(String(def_default.unit_id)).is_equal("")
	assert_int(def_default.raw_def).is_equal(0)
	assert_int(def_default.terrain_def).is_equal(0)
	assert_int(def_default.terrain_evasion).is_equal(0)


## AC-3b: DefenderContext.make() factory assigns all fields.
func test_defender_context_make_factory_assigns_all_fields() -> void:
	# Arrange / Act
	var def2 := DefenderContext.make(&"enemy_b", 50, 15, 5)

	# Assert
	assert_str(String(def2.unit_id)).is_equal("enemy_b")
	assert_int(def2.raw_def).is_equal(50)
	assert_int(def2.terrain_def).is_equal(15)
	assert_int(def2.terrain_evasion).is_equal(5)


# ---------------------------------------------------------------------------
# AC-4  ResolveModifiers
# ---------------------------------------------------------------------------

## AC-4: ResolveModifiers default values and factory with required-only args;
## also verifies all-10-args form assigns each optional field.
func test_resolve_modifiers_default_uses_physical_and_factory_assigns_required_optional() -> void:
	# Arrange
	var rng := RandomNumberGenerator.new()

	# Act — required-args-only factory
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Assert required fields
	assert_int(mod.attack_type).is_equal(ResolveModifiers.AttackType.PHYSICAL)
	assert_object(mod.rng).is_equal(rng)
	assert_str(String(mod.direction_rel)).is_equal("FRONT")
	assert_int(mod.round_number).is_equal(1)

	# Assert optional field defaults
	assert_bool(mod.is_counter).is_false()
	assert_str(mod.skill_id).is_equal("")
	assert_array(mod.source_flags).has_size(0)
	assert_float(mod.rally_bonus).is_equal(0.0)
	assert_float(mod.formation_atk_bonus).is_equal(0.0)
	assert_float(mod.formation_def_bonus).is_equal(0.0)

	# Act — all-10-args form
	var flags: Array[StringName] = [&"flanked"]
	var mod_full := ResolveModifiers.make(
			ResolveModifiers.AttackType.MAGICAL, rng, &"REAR", 3,
			true, "skill_fireball", flags, 0.05, 0.03, 0.02)

	# Assert all fields from full form
	assert_int(mod_full.attack_type).is_equal(ResolveModifiers.AttackType.MAGICAL)
	assert_str(String(mod_full.direction_rel)).is_equal("REAR")
	assert_int(mod_full.round_number).is_equal(3)
	assert_bool(mod_full.is_counter).is_true()
	assert_str(mod_full.skill_id).is_equal("skill_fireball")
	assert_array(mod_full.source_flags).has_size(1)
	assert_float(mod_full.rally_bonus).is_equal(0.05)
	assert_float(mod_full.formation_atk_bonus).is_equal(0.03)
	assert_float(mod_full.formation_def_bonus).is_equal(0.02)


# ---------------------------------------------------------------------------
# AC-5a  ResolveResult.hit()
# ---------------------------------------------------------------------------

## AC-5: ResolveResult.hit() sets kind=HIT, damage, flags, and vfx_tags correctly.
func test_resolve_result_hit_factory_sets_kind_hit_and_damage_and_flags() -> void:
	# Arrange
	var flags: Array[StringName] = [&"counter"]
	var vfx: Array[StringName] = [&"vfx_counter"]

	# Act
	var result := ResolveResult.hit(50, ResolveResult.AttackType.PHYSICAL, flags, vfx)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.HIT)
	assert_int(result.resolved_damage).is_equal(50)
	assert_int(result.attack_type).is_equal(ResolveResult.AttackType.PHYSICAL)
	assert_array(result.source_flags).has_size(1)
	assert_str(String(result.source_flags[0])).is_equal("counter")
	assert_array(result.vfx_tags).has_size(1)
	assert_str(String(result.vfx_tags[0])).is_equal("vfx_counter")


# ---------------------------------------------------------------------------
# AC-5b  ResolveResult.miss() with flags
# ---------------------------------------------------------------------------

## AC-5: ResolveResult.miss() with flags sets kind=MISS and zero damage.
func test_resolve_result_miss_factory_sets_kind_miss_and_zero_damage() -> void:
	# Arrange
	var flags: Array[StringName] = [&"invariant_violation:rng_null"]

	# Act
	var result := ResolveResult.miss(flags)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_int(result.resolved_damage).is_equal(0)
	assert_array(result.source_flags).has_size(1)
	assert_str(String(result.source_flags[0])).is_equal("invariant_violation:rng_null")


# ---------------------------------------------------------------------------
# AC-5c  ResolveResult.miss() zero-args overload
# ---------------------------------------------------------------------------

## AC-5 edge case: ResolveResult.miss() with no arguments returns MISS with empty source_flags.
## Also asserts attack_type field default (PHYSICAL) is preserved on MISS — ADR-0012 §2 says
## attack_type is "immaterial on MISS" but having a defined default avoids Variant-state hazards.
func test_resolve_result_miss_zero_args_overload_returns_empty_source_flags() -> void:
	# Arrange / Act
	var result := ResolveResult.miss()

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.MISS)
	assert_int(result.resolved_damage).is_equal(0)
	assert_int(result.attack_type).is_equal(ResolveResult.AttackType.PHYSICAL)  # field default preserved
	assert_array(result.source_flags).has_size(0)


# ---------------------------------------------------------------------------
# AC-5d  ResolveResult.hit() with empty vfx_tags edge case
# ---------------------------------------------------------------------------

## AC-5 edge case: ResolveResult.hit() with empty vfx_tags is valid (no VFX dispatch).
func test_resolve_result_hit_empty_vfx_tags_is_valid() -> void:
	# Arrange
	var empty_flags: Array[StringName] = []
	var empty_vfx: Array[StringName] = []

	# Act
	var result := ResolveResult.hit(1, ResolveResult.AttackType.MAGICAL, empty_flags, empty_vfx)

	# Assert
	assert_int(result.kind).is_equal(ResolveResult.Kind.HIT)
	assert_int(result.resolved_damage).is_equal(1)
	assert_int(result.attack_type).is_equal(ResolveResult.AttackType.MAGICAL)
	assert_array(result.source_flags).has_size(0)
	assert_array(result.vfx_tags).has_size(0)


# ---------------------------------------------------------------------------
# AC-2 (extended)  AttackerContext.raw_atk pass-through (no wrapper clamp)
# ---------------------------------------------------------------------------

## raw_atk wrapper stores arbitrary int unmodified — clamp is DamageCalc's
## responsibility per ADR-0012 §8 (CR-3 + AC-DC-11/15). Wrapper-level invariant:
## what Grid Battle stores is what DamageCalc reads.
func test_attacker_context_raw_atk_stores_arbitrary_int_unclamped() -> void:
	# Arrange
	var passives: Array[StringName] = []

	# Act / Assert — boundary values bracket the eventual ATK_CAP=200 clamp range.
	# The wrapper itself never modifies them; DamageCalc applies clampi.
	var below_min := AttackerContext.make(&"a1", 0, 0, false, false, passives)
	var negative  := AttackerContext.make(&"a2", 0, -5, false, false, passives)
	var floor_val := AttackerContext.make(&"a3", 0, 1, false, false, passives)
	var baseline  := AttackerContext.make(&"a4", 0, 80, false, false, passives)
	var at_cap    := AttackerContext.make(&"a5", 0, 200, false, false, passives)
	var over_cap  := AttackerContext.make(&"a6", 0, 201, false, false, passives)

	assert_int(below_min.raw_atk).is_equal(0)
	assert_int(negative.raw_atk).is_equal(-5)
	assert_int(floor_val.raw_atk).is_equal(1)
	assert_int(baseline.raw_atk).is_equal(80)
	assert_int(at_cap.raw_atk).is_equal(200)
	assert_int(over_cap.raw_atk).is_equal(201)


# ---------------------------------------------------------------------------
# AC-3 (extended)  DefenderContext.raw_def pass-through (no wrapper clamp)
# ---------------------------------------------------------------------------

## raw_def wrapper stores arbitrary int unmodified — clamp is DamageCalc's
## responsibility per ADR-0012 §8 (CR-3). Wrapper-level invariant.
func test_defender_context_raw_def_stores_arbitrary_int_unclamped() -> void:
	# Act / Assert — boundary values bracket the eventual DEF_CAP=105 clamp range.
	var below_min := DefenderContext.make(&"d1", 0, 0, 0)
	var negative  := DefenderContext.make(&"d2", -5, 0, 0)
	var floor_val := DefenderContext.make(&"d3", 1, 0, 0)
	var baseline  := DefenderContext.make(&"d4", 50, 0, 0)
	var at_cap    := DefenderContext.make(&"d5", 105, 0, 0)
	var over_cap  := DefenderContext.make(&"d6", 106, 0, 0)

	assert_int(below_min.raw_def).is_equal(0)
	assert_int(negative.raw_def).is_equal(-5)
	assert_int(floor_val.raw_def).is_equal(1)
	assert_int(baseline.raw_def).is_equal(50)
	assert_int(at_cap.raw_def).is_equal(105)
	assert_int(over_cap.raw_def).is_equal(106)


# ---------------------------------------------------------------------------
# AC-6  class_name collision-free check (G-12)
# ---------------------------------------------------------------------------

## AC-6: Confirms none of the 4 class_names collide with Godot 4.6 built-in classes.
## ClassDB.class_exists() returns true only for engine-registered (C++) built-ins.
## User class_name declarations do NOT appear in ClassDB — so these assertions
## confirm our names don't shadow any built-ins (G-12 collision rule).
func test_class_names_collision_free_with_godot_builtins() -> void:
	assert_bool(ClassDB.class_exists("AttackerContext")).is_false()
	assert_bool(ClassDB.class_exists("DefenderContext")).is_false()
	assert_bool(ClassDB.class_exists("ResolveModifiers")).is_false()
	assert_bool(ClassDB.class_exists("ResolveResult")).is_false()


# ---------------------------------------------------------------------------
# AC-7 (story-005) — ResolveModifiers.acted_this_turn_callable field
# ---------------------------------------------------------------------------

## AC-7 (story-005): acted_this_turn_callable defaults to Callable() (not valid, no-op).
## Verifies the field is settable and the injected Callable invokes correctly per AC-DC-09.
func test_resolve_modifiers_acted_this_turn_callable_defaults_and_is_injectable() -> void:
	# Arrange / Act — required-args-only factory (callable defaults to Callable())
	var rng := RandomNumberGenerator.new()
	var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Assert default: Callable() is not valid (is_valid() returns false per GDScript contract)
	assert_bool(mod.acted_this_turn_callable.is_valid()).is_false()

	# Inject a test callable that returns false (defender not acted)
	var not_acted_callable := func(_unit_id: StringName) -> bool: return false
	mod.acted_this_turn_callable = not_acted_callable

	# Assert: callable is now valid and invokes correctly
	assert_bool(mod.acted_this_turn_callable.is_valid()).is_true()
	var result_not_acted: bool = mod.acted_this_turn_callable.call(&"unit_x") as bool
	assert_bool(result_not_acted).is_false()

	# Inject a callable that returns true (defender has acted)
	var acted_callable := func(_unit_id: StringName) -> bool: return true
	mod.acted_this_turn_callable = acted_callable
	var result_acted: bool = mod.acted_this_turn_callable.call(&"unit_x") as bool
	assert_bool(result_acted).is_true()
