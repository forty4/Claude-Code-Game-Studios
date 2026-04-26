## DamageCalc — stateless synchronous damage-resolution pipeline.
## Single entry point: DamageCalc.resolve(). No instance state, no signals,
## no Dictionary allocations. Per ADR-0012 §1 (RefCounted, static-only).
## Caller: GridBattle (once per primary attack + once per counter).
class_name DamageCalc extends RefCounted


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

	# --- Stage 0 passes: proceed to Stage 1+ ---
	# TODO(story-004): Replace this Stage-0-passes placeholder with real Stage 1 base damage call.
	return ResolveResult.hit(0, modifiers.attack_type as ResolveResult.AttackType, [], [])
