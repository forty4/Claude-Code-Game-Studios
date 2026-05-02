## unit_hp_state.gd
## Per-unit HP + status effect state, scoped to a single battle.
## Created by HPStatusController.initialize_unit; mutated exclusively by the
## HPStatusController API; freed automatically when HPStatusController (battle-scoped
## Node) is freed with BattleScene per ADR-0010 §1 + ADR-0002 lifecycle.
##
## Signal: n/a (RefCounted data wrapper; no signal emission)
## Emitter: n/a
## Consumed by: HPStatusController (sole owner + mutator); read-only by Battle HUD,
##   AI System, and Grid Battle via HPStatusController query methods.
##
## RefCounted (NOT Resource) because:
##   - Battle-scoped, never serialized per CR-1b non-persistence
##   - No @export inspector visibility required (state is HPStatusController-internal)
##   - Lighter-weight than Resource (no resource_path, no ResourceLoader cache)
##
## Field count: exactly 6 fields per ADR-0010 §3 guardrail.
class_name UnitHPState
extends RefCounted

## Unit identifier — matches ADR-0001 unit_died(unit_id: int) signal payload type.
var unit_id: int = 0

## Maximum HP, cached at battle-init via UnitRole.get_max_hp(hero, unit_class).
## One-time computation per unit per battle per ADR-0009 line 328.
var max_hp: int = 0

## Current HP. Invariant: 0 <= current_hp <= max_hp per CR-2.
## Mutated ONLY via HPStatusController.apply_damage / apply_heal / DoT tick.
var current_hp: int = 0

## Active status effects for this unit. Insertion order preserved for CR-5e
## oldest-first eviction (max MAX_STATUS_EFFECTS_PER_UNIT=3 slots per ADR-0010 §12).
var status_effects: Array[StatusEffect] = []

## Read-only reference to the unit's HeroData (ADR-0007 schema).
## Used for base_hp_seed (via UnitRole.get_max_hp) and future is_morale_anchor field.
var hero: HeroData = null

## UnitRole.UnitClass enum value (CAVALRY=0..SCOUT=5), cached at battle-init.
## Used for PASSIVE_TAG_BY_CLASS lookup in F-1 Step 1 (passive_shield_wall check).
var unit_class: int = 0
