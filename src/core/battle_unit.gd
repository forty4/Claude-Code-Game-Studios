class_name BattleUnit
## BattleUnit — battle-scoped unit Resource carrying both turn-order roster fields
## (ADR-0011) and grid-battle controller runtime fields (ADR-0014 §3).
##
## Originally ratified as 4-field RefCounted by ADR-0011 §Decision §Public mutator
## API + §Migration Plan §3 (turn-order epic story-002). Extended on 2026-05-03 by
## grid-battle-controller story-002 (S5-03) per ADR-0014 §3 — the de-facto Battle
## Preparation contract for MVP. Original "MUST NOT add fields without Battle
## Preparation ADR amendment" boundary is honored: ADR-0014 §3 IS the MVP
## Battle Preparation contract; field additions trace 1:1 to that section.
##
## Type change (RefCounted → Resource) for @export support so designers can author
## battle-scene fixtures via .tres files (post-MVP). Resource extends RefCounted
## in Godot's class hierarchy — RefCounted-only behavior is unchanged for
## existing TurnOrderRunner integration paths.
##
## RULES:
##  - 4 ADR-0011 fields (unit_id / hero_id / unit_class / is_player_controlled)
##    are the LOCKED API surface for TurnOrderRunner.initialize_battle. DO NOT
##    rename or change their types without ADR-0011 amendment.
##  - 7 ADR-0014 §3 fields (name / side / position / facing / passive / tag /
##    move_range / attack_range) are the runtime state for GridBattleController.
##    Stories 002-008 may extend; future Battle Preparation ADR may consolidate
##    side ↔ is_player_controlled redundancy (currently coexist for back-compat).
##  - All fields public + @export (no getters/setters) — owned by Battle
##    Preparation caller; TurnOrderRunner + GridBattleController read read-only
##    during battle initialization + per-turn flow.
##  - unit_id type LOCKED to int per ADR-0001 line 153 + ADR-0011 contract.
##  - hero_id type LOCKED to StringName per ADR-0007 §2 hero_id contract.
##  - unit_class stores UnitRole.UnitClass enum int per CR-4 + ADR-0009.
extends Resource

# ── ADR-0011 fields (LOCKED — TurnOrderRunner.initialize_battle contract) ──────

## Unique unit identifier for this battle instance. int per ADR-0001 + ADR-0011 lock.
## Assigned by Battle Preparation; must be unique within a single battle roster.
@export var unit_id: int = 0

## Hero identifier — links to HeroDatabase record for stat lookup at BI-2/BI-3.
## StringName per ADR-0007 §2 hero_id format (`^[a-z]+_\d{3}_[a-z_]+$`).
@export var hero_id: StringName = &""

## Unit class as UnitRole.UnitClass int backing value [0, 5].
## Stored as int per ADR-0009 + ADR-0007 §2 cross-script @export int convention.
## Cross-doc: int values align 1:1 with UnitRole.UnitClass enum backing values.
@export var unit_class: int = 0

## True if this unit is controlled by the human player; false if AI-controlled.
## Interleaved queue (CR-1) makes ownership invisible to queue sort order at the
## initiative level; is_player_controlled is the F-1 Step 3 tie-break only.
##
## NOTE: redundant with `side` field below (is_player_controlled=true ↔ side=0).
## Both coexist for back-compat: TurnOrderRunner consumes is_player_controlled
## per ADR-0011; GridBattleController consumes side per ADR-0014 §3. A future
## Battle Preparation ADR may consolidate.
@export var is_player_controlled: bool = false


# ── ADR-0014 §3 fields (added 2026-05-03 by grid-battle-controller story-002) ──

## Display name (Korean or English) for HUD + portrait pairing. May be empty
## at fixture-load time and resolved later from HeroDatabase.get_hero(hero_id).
@export var name: String = ""

## 0 = player faction; 1 = enemy faction. Per ADR-0014 §3 + chapter-prototype
## pattern. Used by GridBattleController._has_adjacent_command_aura,
## _count_adjacent_allies, victory check (story-007), and target validation.
@export var side: int = 0

## Grid coord (Vector2i) of unit's current tile. Mutated only by
## GridBattleController._do_move per ADR-0014 §3 sole-writer contract.
@export var position: Vector2i = Vector2i.ZERO

## Cardinal facing direction: 0=N, 1=E, 2=S, 3=W. Updated by _do_move based on
## last move direction (chapter-prototype pattern). Consumed by _attack_angle
## (story-005) for front/side/rear classification.
@export var facing: int = 0

## Passive ability identifier (e.g., &"bridge_blocker", &"hit_and_run",
## &"rear_specialist", &"command_aura"). Empty StringName = no passive.
## Consumed by _resolve_attack (story-005) for rear_specialist multiplier
## + command_aura adjacency check.
@export var passive: StringName = &""

## Role tag for hidden fate-counter unit detection (story-002 + story-008):
## &"tank" / &"assassin" / &"boss" / &"". Empty = no fate role.
## Set at battle init by Battle Preparation; immutable during battle.
@export var tag: StringName = &""

## Movement range (Manhattan distance) for this unit. Default 0 = no movement
## (e.g., immobile boss). Set from UnitRole.get_class_move_range or
## chapter-fixture override at battle init.
@export var move_range: int = 0

## Attack range (Manhattan distance): 1 = melee, 2 = 황충 ranged exception.
## MVP: most units = 1; only 황충 (rear_specialist passive) = 2.
@export var attack_range: int = 1

## Pre-DamageCalc-clamp ATK from HP/Status. Set at battle init from
## HeroDatabase + UnitRole derived stats; consumed by GridBattleController._resolve_attack
## when constructing AttackerContext per ADR-0012 §8 + CR-3 (DamageCalc applies
## clampi(raw_atk, 1, ATK_CAP) per AC-DC-11/15). Story-005 addition.
@export var raw_atk: int = 10

## Pre-DamageCalc-clamp DEF from HP/Status. Set at battle init from
## HeroDatabase + UnitRole derived stats; consumed by GridBattleController._resolve_attack
## when constructing DefenderContext per ADR-0012 §8 + CR-3 (DamageCalc applies
## clampi(raw_def, 1, DEF_CAP) per AC-DC-11/15). Story-005 addition.
@export var raw_def: int = 5
