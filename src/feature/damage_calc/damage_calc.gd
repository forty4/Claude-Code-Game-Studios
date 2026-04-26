## DamageCalc — stateless synchronous damage-resolution pipeline.
## Single entry point: DamageCalc.resolve(). No instance state, no signals,
## no Dictionary allocations. Per ADR-0012 §1 (RefCounted, static-only).
## Caller: GridBattle (once per primary attack + once per counter).
class_name DamageCalc extends RefCounted


# ---------------------------------------------------------------------------
# Tunable constants — TODO(story-006): migrate to BalanceConstants.get_const()
# when ADR-0006 lands. Hardcoding authorized per story-004 §Implementation Notes
# (provisional workaround: BalanceConstants wrapper does not yet exist; story-006
# grep-lint AC-DC-48 will catch and require migration when balance-data ADR-0006
# is Accepted). Values locked per ADR-0012 §6 + damage-calc.md rev 2.9.2.
# ---------------------------------------------------------------------------

## Stage-1 damage ceiling (BASE_CEILING). Applied pre-multipliers. Locked-not-tunable.
const BASE_CEILING: int = 83
## Minimum resolved damage. HP/Status owns this contract; DamageCalc enforces
## the floor per CR-6 / CR-9. Locked-not-tunable.
const MIN_DAMAGE: int = 1
## Maximum effective ATK after clamping. Game-design-tier cap (AC-DC-15).
const ATK_CAP: int = 200
## Maximum effective DEF after clamping. Rev 2.9.2 (was 100; expanded to 105).
const DEF_CAP: int = 105
## DEFEND_STANCE ATK penalty FRACTION. The multiplier applied to raw_atk is
## (1.0 - DEFEND_STANCE_ATK_PENALTY) = 0.60 per CR-3 + AC-DC-12.
## Name uses "PENALTY" to denote the fraction subtracted, not the resulting multiplier.
const DEFEND_STANCE_ATK_PENALTY: float = 0.40


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

	# TODO(story-005): unknown_class guard fires at Stage-2 unit_class lookup site.

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

	# TODO(story-005): Stage 2 — direction × passive multiplier (D_mult × P_mult).
	# TODO(story-006): Stage 3-4 — raw damage + DAMAGE_CEILING + counter halve + source_flags.
	return ResolveResult.hit(base, modifiers.attack_type as ResolveResult.AttackType, [], [])


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

	# Step 1: effective ATK — DEFEND_STANCE penalty then [1, ATK_CAP] clamp (AC-DC-11/15).
	var eff_atk: int = clampi(
			_apply_defend_stance_penalty(attacker.raw_atk, attacker.defend_stance_active),
			1, ATK_CAP)

	# Step 2: effective DEF — [1, DEF_CAP] clamp (AC-DC-13/rev-2.9.2), then Formation DEF bonus.
	var eff_def: int = _consume_formation_def_bonus(
			clampi(defender.raw_def, 1, DEF_CAP),
			modifiers)

	# Step 3: defense multiplier from terrain_def (clamped by TerrainEffect cap).
	var defense_mul: float = _compute_defense_mul(defender)

	# Step 4: base damage formula (CR-5). floori required — rounds toward −∞
	# (distinct from the truncating int conversion which rounds toward 0). AC-DC-23 EC-DC-20.
	var base: int = floori(eff_atk - eff_def * defense_mul)

	# Step 5: apply floor and ceiling (CR-6). BASE_CEILING=83 is pre-multipliers cap.
	return mini(BASE_CEILING, maxi(MIN_DAMAGE, base))


## Applies the DEFEND_STANCE ATK penalty when the attacker is in defend stance.
## Takes the bool flag rather than the full AttackerContext to minimize coupling
## (helper depends only on `defend_stance_active`, not on the wrapper shape).
## DEFEND_STANCE_ATK_PENALTY = 0.40 is the penalty FRACTION; the effective
## multiplier is (1.0 - 0.40) = 0.60 per CR-3 + AC-DC-12.
## floori is used (not the truncating int conversion) so that fractional
## results round toward −∞ (AC-DC-23).
static func _apply_defend_stance_penalty(raw_atk: int, defend_stance_active: bool) -> int:
	if defend_stance_active:
		return floori(raw_atk * (1.0 - DEFEND_STANCE_ATK_PENALTY))
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
