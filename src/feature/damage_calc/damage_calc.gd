## DamageCalc — stateless synchronous damage-resolution pipeline.
## Single entry point: DamageCalc.resolve(). No instance state, no signals,
## no Dictionary allocations. Per ADR-0012 §1 (RefCounted, static-only).
## Caller: GridBattle (once per primary attack + once per counter).
##
## Tuning constants (BASE_CEILING, MIN_DAMAGE, ATK_CAP, DEF_CAP,
## DEFEND_STANCE_ATK_PENALTY, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER,
## P_MULT_COMBINED_CAP, CHARGE_BONUS, AMBUSH_BONUS, BASE_DIRECTION_MULT,
## CLASS_DIRECTION_MULT) live in `assets/data/balance/entities.json` and
## are read at call time via BalanceConstants.get_const(key). Hardcoding
## these literals in damage_calc.gd is banned per AC-DC-48 + ADR-0012 §6.
## Migration path: when ADR-0006 lands, BalanceConstants internals swap to
## DataRegistry.get_const() — no call-site changes required here.
class_name DamageCalc extends RefCounted


# ---------------------------------------------------------------------------
# Sentinels — StringName identifiers, NOT tuning knobs (stay as const)
# ---------------------------------------------------------------------------

## StringName sentinel for passive_charge — used in _charge_factor and _passive_multiplier_for_test.
## Declared as a const StringName so the membership test uses StringName equality,
## not String equality (the AC-DC-51 release-build defense).
const PASSIVE_CHARGE: StringName = &"passive_charge"
## StringName sentinel for passive_ambush — same StringName equality defense as PASSIVE_CHARGE.
const PASSIVE_AMBUSH: StringName = &"passive_ambush"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Resolves one attack interaction and returns an immutable ResolveResult.
## Returns MISS with a source_flags tag on any invariant violation.
## RNG is consumed exactly once per non-counter call (replay determinism — AC-DC-26).
## Counter calls (modifiers.is_counter == true) consume RNG zero times (AC-DC-20, story-006).
## Skill-stub calls (modifiers.skill_id != "") consume RNG zero times (AC-DC-18).
static func resolve(
		attacker: AttackerContext,
		defender: DefenderContext,
		modifiers: ResolveModifiers) -> ResolveResult:

	# --- F-DC-1 invariant guards (MUST remain in this order — AC-DC-18 RNG-call-count = 0) ---

	# Guard 1 — skill stub: graceful early return, no push_error, RNG call count = 0
	if modifiers.skill_id != "":
		return ResolveResult.miss([&"skill_unresolved"])

	# Guard 2 — rng null: invariant violation, push_error
	if modifiers.rng == null:
		push_error("DamageCalc.resolve: modifiers.rng is null — caller must inject a live RandomNumberGenerator")
		return ResolveResult.miss([&"invariant_violation:rng_null"])

	# Guard 3 — bad attack_type: invariant violation, push_error
	if modifiers.attack_type not in [ResolveModifiers.AttackType.PHYSICAL, ResolveModifiers.AttackType.MAGICAL]:
		push_error("DamageCalc.resolve: modifiers.attack_type=%d is not in {PHYSICAL, MAGICAL}" % modifiers.attack_type)
		return ResolveResult.miss([&"invariant_violation:bad_attack_type"])

	# Guard 4 — unknown direction_rel: invariant violation, push_error
	if not (modifiers.direction_rel in [&"FRONT", &"FLANK", &"REAR"]):
		push_error("DamageCalc.resolve: modifiers.direction_rel=%s is not in {FRONT, FLANK, REAR}" % modifiers.direction_rel)
		return ResolveResult.miss([&"invariant_violation:unknown_direction"])

	# --- Stage 0: Evasion roll (F-DC-2) ---
	if not modifiers.is_counter:
		# Non-counter: always consume exactly one randi_range call (replay determinism — AC-DC-26).
		# roll ∈ [1, 100] inclusive (Godot 4.6 randi_range contract — pinned via AC-DC-49, story-008).
		var roll: int = modifiers.rng.randi_range(1, 100)
		if roll <= clampi(defender.terrain_evasion, 0, 30):
			return ResolveResult.miss([&"evasion"])
	# Counter path: skip evasion entirely per CR-2 + AC-DC-20. RNG call count = 0.

	# --- Stage 0 passes: proceed to Stage 1 base damage ---
	var base: int = _stage_1_base_damage(attacker, defender, modifiers)

	# --- Stage 2: AC-DC-21 unknown_class invariant guard at F-DC-4 lookup site ---
	var class_dir_mult: Dictionary = BalanceConstants.get_const("CLASS_DIRECTION_MULT") as Dictionary
	if not class_dir_mult.has(str(attacker.unit_class)):
		push_error("DamageCalc.resolve: unknown unit_class=%d" % attacker.unit_class)
		return ResolveResult.miss([&"invariant_violation:unknown_class"])

	# --- Stage 2: direction multiplier (F-DC-4) ---
	var d_mult: float = _direction_multiplier(attacker.unit_class, modifiers.direction_rel)

	# --- Stage 2.5: passive multiplier with P_MULT_COMBINED_CAP clamp (F-DC-5) ---
	# Provenance booleans captured here for source_flags + vfx_tags population (AC-DC-36).
	# Detection via != 1.0 comparison is safe here because _charge_factor and _ambush_factor
	# return ONLY one of two values: the literal 1.0 (no fire) OR a named constant
	# (CHARGE_BONUS=1.20, AMBUSH_BONUS=1.15). Neither named constant equals 1.0 in any
	# floating-point representation. There is no arithmetic path that could produce a
	# returned value coincidentally equal to 1.0.
	var charge_fired: bool = _charge_factor(attacker, modifiers) != 1.0
	var ambush_fired: bool = _ambush_factor(attacker, modifiers, defender) != 1.0
	var p_mult: float = _passive_multiplier(attacker, modifiers, defender)

	# --- Stage 3: raw damage floor + ceiling (F-DC-6, CR-9) ---
	var raw: int = _stage_3_raw_damage(base, d_mult, p_mult)

	# --- Stage 4: counter halve + MIN_DAMAGE floor (F-DC-7, CR-10) ---
	var resolved: int = _counter_reduction(raw, modifiers.is_counter)

	# --- Build output arrays (ADR-0012 §12 — always new Arrays, never mutate caller) ---
	var out_flags: Array[StringName] = _build_source_flags(modifiers, charge_fired,
			ambush_fired, defender.terrain_def > 0)
	var vfx: Array[StringName] = _build_vfx_tags(charge_fired, ambush_fired,
			modifiers.is_counter, defender.terrain_def > 0)

	# AC-DC-N1: explicit enum conversion — never via direct enum cast which silently
	# reinterprets ints if either enum diverges in ordering. See _to_result_attack_type().
	var rr_attack_type: ResolveResult.AttackType = _to_result_attack_type(modifiers.attack_type)

	return ResolveResult.hit(resolved, rr_attack_type, out_flags, vfx)


# ---------------------------------------------------------------------------
# Stage 1 — base damage pipeline (CR-3..CR-6, F-DC-3, story-004)
# ---------------------------------------------------------------------------

## Orchestrates the Stage 1 base damage pipeline.
## Returns base_damage ∈ [MIN_DAMAGE, BASE_CEILING] = [1, 83].
## Steps (per ADR-0012 §7 + story-004 §Implementation Notes):
##   1. Read raw_atk → apply DEFEND_STANCE penalty → clamp to [1, ATK_CAP].
##   2. Read raw_def → clamp to [1, DEF_CAP] → consume Formation DEF bonus.
##   3. Compute defense multiplier from terrain_def.
##   4. base = floori(eff_atk - eff_def × defense_mul).
##   5. Clamp base to [MIN_DAMAGE, BASE_CEILING].
static func _stage_1_base_damage(
		attacker: AttackerContext,
		defender: DefenderContext,
		modifiers: ResolveModifiers) -> int:

	var atk_cap: int = BalanceConstants.get_const("ATK_CAP") as int
	var def_cap: int = BalanceConstants.get_const("DEF_CAP") as int
	var min_damage: int = BalanceConstants.get_const("MIN_DAMAGE") as int
	var base_ceiling: int = BalanceConstants.get_const("BASE_CEILING") as int

	# Step 1: effective ATK — DEFEND_STANCE penalty then [1, ATK_CAP] clamp (AC-DC-11/15).
	var eff_atk: int = clampi(
			_apply_defend_stance_penalty(attacker.raw_atk, attacker.defend_stance_active),
			1, atk_cap)

	# Step 2: effective DEF — [1, DEF_CAP] clamp (AC-DC-13/rev-2.9.2), then Formation DEF bonus.
	var eff_def: int = _consume_formation_def_bonus(
			clampi(defender.raw_def, 1, def_cap),
			modifiers)

	# Step 3: defense multiplier from terrain_def (clamped by TerrainEffect cap).
	var defense_mul: float = _compute_defense_mul(defender)

	# Step 4: base damage formula (CR-5). floori required — rounds toward −∞
	# (distinct from the truncating int conversion which rounds toward 0). AC-DC-23 EC-DC-20.
	var base: int = floori(eff_atk - eff_def * defense_mul)

	# Step 5: apply floor and ceiling (CR-6). BASE_CEILING=83 is pre-multipliers cap.
	return mini(base_ceiling, maxi(min_damage, base))


## Applies the DEFEND_STANCE ATK penalty when the attacker is in defend stance.
## Takes the bool flag rather than the full AttackerContext to minimize coupling
## (helper depends only on `defend_stance_active`, not on the wrapper shape).
## DEFEND_STANCE_ATK_PENALTY = 0.40 is the penalty FRACTION; the effective
## multiplier is (1.0 - 0.40) = 0.60 per CR-3 + AC-DC-12.
## floori is used (not the truncating int conversion) so that fractional
## results round toward −∞ (AC-DC-23).
static func _apply_defend_stance_penalty(raw_atk: int, defend_stance_active: bool) -> int:
	if defend_stance_active:
		var penalty: float = BalanceConstants.get_const("DEFEND_STANCE_ATK_PENALTY") as float
		return floori(raw_atk * (1.0 - penalty))
	return raw_atk


## Computes the defense multiplier from the defender's terrain_def.
## terrain_def is already clamped to [−30, +30] by Terrain Effect (ADR-0008).
## DamageCalc re-clamps via TerrainEffect.max_defense_reduction() as a
## defensive double-guard (contracts owned by ADR-0008, not this ADR).
## snappedf precision = 0.01 (locked-not-tunable per AC-DC-30 EC-DC-21).
static func _compute_defense_mul(defender: DefenderContext) -> float:
	var cap: int = TerrainEffect.max_defense_reduction()
	return snappedf(1.0 - clampi(defender.terrain_def, -cap, cap) / 100.0, 0.01)


## Applies the Formation DEF bonus to the already-clamped eff_def.
## formation_def_bonus ∈ [0.0, 0.05] upstream-capped per Formation Bonus F-FB-3.
## floori is used (not the truncating int conversion) for consistent
## round-toward-−∞ semantics (AC-DC-23).
static func _consume_formation_def_bonus(eff_def: int, modifiers: ResolveModifiers) -> int:
	return eff_def + floori(eff_def * modifiers.formation_def_bonus)


# ---------------------------------------------------------------------------
# Stage 2 — direction multiplier (CR-7, F-DC-4, story-005)
# ---------------------------------------------------------------------------

## Computes D_mult = snappedf(BASE_DIRECTION_MULT[dir] × CLASS_DIRECTION_MULT[class][dir], 0.01).
## Precision 0.01 is locked-not-tunable per ADR-0012 §Implementation Guidelines #6 + AC-DC-30.
## Apex example: Cavalry REAR = snappedf(1.50 × 1.09, 0.01) = snappedf(1.635, 0.01) = 1.64.
## Caller (resolve) has already verified unit_class is a known string key in CLASS_DIRECTION_MULT.
## JSON delivers string keys; direction_rel is cast to String for dict lookup (approved design decision).
static func _direction_multiplier(unit_class: int, direction_rel: StringName) -> float:
	var dir_str: String = direction_rel as String
	var base_dir_mult: Dictionary = BalanceConstants.get_const("BASE_DIRECTION_MULT") as Dictionary
	var class_dir_mult: Dictionary = BalanceConstants.get_const("CLASS_DIRECTION_MULT") as Dictionary
	var base_mult: float = base_dir_mult[dir_str] as float
	var class_mult: float = (class_dir_mult[str(unit_class)] as Dictionary)[dir_str] as float
	return snappedf(base_mult * class_mult, 0.01)


# ---------------------------------------------------------------------------
# Stage 2.5 — passive multiplier composition + P_MULT_COMBINED_CAP (CR-8, F-DC-5, story-005)
# ---------------------------------------------------------------------------

## Orchestrates P_mult: Charge × Ambush × (1+rally) × (1+formation_atk_bonus).
## Applies minf(P_MULT_COMBINED_CAP, pre_cap) after full composition.
## Applies snappedf(value, 0.01) to the final post-cap result for cross-platform
## IEEE-754 residue control per AC-DC-50.
## Ordering is non-negotiable per ADR-0012 §7 + F-DC-5 line ordering.
static func _passive_multiplier(
		attacker: AttackerContext,
		modifiers: ResolveModifiers,
		defender: DefenderContext) -> float:
	var charge: float = _charge_factor(attacker, modifiers)
	var ambush: float = _ambush_factor(attacker, modifiers, defender)
	var pre_cap: float = charge * ambush * (1.0 + modifiers.rally_bonus) * (1.0 + modifiers.formation_atk_bonus)
	var p_mult_combined_cap: float = BalanceConstants.get_const("P_MULT_COMBINED_CAP") as float
	var post_cap: float = minf(p_mult_combined_cap, pre_cap)
	return snappedf(post_cap, 0.01)


## Returns CHARGE_BONUS (1.20) iff: unit is CAVALRY AND charge_active AND passive_charge present
## AND attack is not a counter. Counter suppression per AC-DC-16 (EC-DC-8).
## Class mutex: SCOUT / INFANTRY / ARCHER can never fire Charge (class guard blocks).
## Uses PASSIVE_CHARGE const (StringName) for membership test — see AC-DC-51 StringName defense.
static func _charge_factor(attacker: AttackerContext, modifiers: ResolveModifiers) -> float:
	if (attacker.unit_class == AttackerContext.Class.CAVALRY
			and attacker.charge_active
			and PASSIVE_CHARGE in attacker.passives
			and not modifiers.is_counter):
		return BalanceConstants.get_const("CHARGE_BONUS") as float
	return 1.0


## Returns AMBUSH_BONUS (1.15) iff: unit is SCOUT or ARCHER AND passive_ambush present
## AND attack is not a counter AND round_number >= 2 AND defender has not yet acted this turn.
## Counter suppression per AC-DC-16 (EC-DC-8). Class mutex: CAVALRY / INFANTRY cannot fire Ambush.
## Turn Order interface stub: modifiers.acted_this_turn_callable defaults to Callable() (no-op = false).
## Uses PASSIVE_AMBUSH const (StringName) for membership test — same StringName defense as _charge_factor.
static func _ambush_factor(
		attacker: AttackerContext,
		modifiers: ResolveModifiers,
		defender: DefenderContext) -> float:
	if attacker.unit_class not in [AttackerContext.Class.SCOUT, AttackerContext.Class.ARCHER]:
		return 1.0
	if not (PASSIVE_AMBUSH in attacker.passives):
		return 1.0
	if modifiers.is_counter:
		return 1.0
	if modifiers.round_number < 2:
		return 1.0
	# Turn Order interface: provisional ADR-0011 workaround per ADR-0012 §8.
	# Default Callable() is not valid — is_valid() returns false → treat as not-acted (false).
	var has_acted: bool = false
	if modifiers.acted_this_turn_callable.is_valid():
		has_acted = modifiers.acted_this_turn_callable.call(defender.unit_id) as bool
	if has_acted:
		return 1.0
	return BalanceConstants.get_const("AMBUSH_BONUS") as float


# ---------------------------------------------------------------------------
# Stage 3 — raw damage cap + floor (CR-9, F-DC-6, story-006)
# ---------------------------------------------------------------------------

## Computes Stage-3 raw damage: floori(base × D_mult × P_mult) then clamp to [MIN_DAMAGE, DAMAGE_CEILING].
## DAMAGE_CEILING=180 is the post-multipliers hard ceiling (CR-9). MIN_DAMAGE=1 floors at zero.
## This value is forwarded to Stage 4 (counter halve); it does NOT flow to the caller directly.
static func _stage_3_raw_damage(base: int, d_mult: float, p_mult: float) -> int:
	var damage_ceiling: int = BalanceConstants.get_const("DAMAGE_CEILING") as int
	var min_damage: int = BalanceConstants.get_const("MIN_DAMAGE") as int
	var raw: int = floori(base * d_mult * p_mult)
	return mini(damage_ceiling, maxi(min_damage, raw))


# ---------------------------------------------------------------------------
# Stage 4 — counter halve + MIN_DAMAGE floor (CR-10, F-DC-7, story-006)
# ---------------------------------------------------------------------------

## Applies the counter-attack halve when is_counter=true.
## floori(raw × COUNTER_ATTACK_MODIFIER) then maxi(MIN_DAMAGE, result).
## AC-DC-24 boundary: floori(1 × 0.5) = 0 → maxi(1, 0) = 1 (MIN_DAMAGE catches).
## Non-counter path: returns raw unchanged (no halve applied).
static func _counter_reduction(raw: int, is_counter: bool) -> int:
	if is_counter:
		var counter_mod: float = BalanceConstants.get_const("COUNTER_ATTACK_MODIFIER") as float
		var min_damage: int = BalanceConstants.get_const("MIN_DAMAGE") as int
		return maxi(min_damage, floori(raw * counter_mod))
	return raw


# ---------------------------------------------------------------------------
# source_flags builder (ADR-0012 §12 + CR-11, story-006)
# ---------------------------------------------------------------------------

## Builds the source_flags Array from caller's flags + provenance booleans.
## Always-new-Array contract (ADR-0012 §12): the returned Array is independent of
## modifiers.source_flags — caller's array is never mutated, no shared identity.
## G-2 fix: uses .assign() (not .duplicate()) to preserve typed-Array annotation
## when copying modifiers.source_flags into a fresh Array[StringName].
static func _build_source_flags(
		modifiers: ResolveModifiers,
		charge_fired: bool,
		ambush_fired: bool,
		has_terrain_penalty: bool) -> Array[StringName]:
	var out_flags: Array[StringName] = []
	out_flags.assign(modifiers.source_flags)
	if modifiers.is_counter:
		out_flags.append(&"counter")
	if charge_fired:
		out_flags.append(&"charge")
	if ambush_fired:
		out_flags.append(&"ambush")
	if has_terrain_penalty:
		out_flags.append(&"terrain_penalty")
	return out_flags


# ---------------------------------------------------------------------------
# vfx_tags builder (AC-DC-36, story-006)
# ---------------------------------------------------------------------------

## Builds the vfx_tags Array from provenance booleans.
## This is the ONLY helper allowed to perform an Array allocation inside the resolve() call graph.
## Excluded from AC-DC-41 Dictionary-alloc lint (story-008) by design per ADR-0012 §Implementation #5.
static func _build_vfx_tags(
		charge_fired: bool,
		ambush_fired: bool,
		is_counter: bool,
		has_terrain_penalty: bool) -> Array[StringName]:
	var tags: Array[StringName] = []
	if charge_fired:
		tags.append(&"charge")
	if ambush_fired:
		tags.append(&"ambush")
	if is_counter:
		tags.append(&"counter")
	if has_terrain_penalty:
		tags.append(&"terrain_penalty")
	return tags


# ---------------------------------------------------------------------------
# Enum conversion helper — AC-DC-N1 (story-006)
# ---------------------------------------------------------------------------

## Converts ResolveModifiers.AttackType to ResolveResult.AttackType explicitly.
## Pattern B per story-006 implementation notes: the match expression surfaces
## enum divergence via push_error rather than silent int-reinterpretation.
##
## DO NOT replace this helper with a direct enum cast (the substring of that
## cast is intentionally not quoted here so AC-9 grep stays clean — see
## story-004 §F-1 grep-policy for the same anti-self-trigger pattern applied
## to the truncating-int-conversion literal).
static func _to_result_attack_type(rm_type: ResolveModifiers.AttackType) -> ResolveResult.AttackType:
	match rm_type:
		ResolveModifiers.AttackType.PHYSICAL:
			return ResolveResult.AttackType.PHYSICAL
		ResolveModifiers.AttackType.MAGICAL:
			return ResolveResult.AttackType.MAGICAL
		_:
			push_error("DamageCalc: unmapped attack_type=%d — defaulting to PHYSICAL" % rm_type)
			return ResolveResult.AttackType.PHYSICAL


# ---------------------------------------------------------------------------
# Test-only entry point — AC-DC-51 bypass-seam (story-006)
# ---------------------------------------------------------------------------

## Test-only helper exposing _passive_multiplier with an external passives_arg override.
## Allows the AC-DC-51 bypass-seam test to inject a wrong-typed Array (untyped Array with
## String elements) to verify that StringName literal membership tests reject String values.
## MUST NOT be called from production code. Test-only by convention (ADR-0012 §2 + §10 #4).
## The passives_arg parameter is intentionally untyped Variant to accept both typed Array[StringName]
## (positive case) and untyped Array with String elements (negative case).
static func _passive_multiplier_for_test(
		attacker: AttackerContext,
		defender: DefenderContext,
		modifiers: ResolveModifiers,
		passives_arg: Variant) -> float:
	# Replicate _passive_multiplier logic but use passives_arg instead of attacker.passives
	# for the PASSIVE_CHARGE and PASSIVE_AMBUSH membership checks.
	var charge: float = 1.0
	if (attacker.unit_class == AttackerContext.Class.CAVALRY
			and attacker.charge_active
			and PASSIVE_CHARGE in passives_arg
			and not modifiers.is_counter):
		charge = BalanceConstants.get_const("CHARGE_BONUS") as float

	var ambush: float = 1.0
	if (attacker.unit_class in [AttackerContext.Class.SCOUT, AttackerContext.Class.ARCHER]
			and PASSIVE_AMBUSH in passives_arg
			and not modifiers.is_counter
			and modifiers.round_number >= 2):
		var has_acted: bool = false
		if modifiers.acted_this_turn_callable.is_valid():
			has_acted = modifiers.acted_this_turn_callable.call(defender.unit_id) as bool
		if not has_acted:
			ambush = BalanceConstants.get_const("AMBUSH_BONUS") as float

	var pre_cap: float = charge * ambush * (1.0 + modifiers.rally_bonus) * (1.0 + modifiers.formation_atk_bonus)
	var p_mult_combined_cap: float = BalanceConstants.get_const("P_MULT_COMBINED_CAP") as float
	var post_cap: float = minf(p_mult_combined_cap, pre_cap)
	return snappedf(post_cap, 0.01)


