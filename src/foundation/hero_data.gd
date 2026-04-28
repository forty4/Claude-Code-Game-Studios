## hero_data.gd
## provisional HeroData Resource wrapper per ADR-0009 §Migration Plan §3.
## provisional shape per ADR-0009 §Migration Plan §3; ADR-0007 Hero DB will ratify
## the authoritative field set when written. Migration parameter-stable per
## `unit-role.md` §Dependencies upstream contract.
## All fields are @export-annotated for ResourceSaver round-trip compatibility
## (non-@export fields are silently dropped — ADR-0003 TR-save-load-002).
class_name HeroData
extends Resource


## Primary combat stat — used by F-1 ATK derivation. Range [1, 100].
@export var stat_might: int = 1

## Secondary stat — used by F-2 MAG derivation (Strategist). Range [1, 100].
@export var stat_intellect: int = 1

## Support stat — used by Formation Bonus (Commander Rally). Range [1, 100].
@export var stat_command: int = 1

## Speed/positioning stat — used by F-4 Initiative derivation. Range [1, 100].
@export var stat_agility: int = 1

## HP seed for F-3 max_hp derivation. Range [1, 100].
@export var base_hp_seed: int = 1

## Initiative seed for F-4 initiative derivation. Range [1, 100].
@export var base_initiative_seed: int = 1

## Hero base move range before class delta is applied. Range [2, 6] per MOVE_RANGE_MIN floor.
@export var move_range: int = 2

## Default class as UnitRole.UnitClass enum int. Will become typed once cross-script
## enum reference is verified working in test (ADR-0009 §Migration Plan §3 annotation).
@export var default_class: int = 0

## Innate skill IDs as StringName array — per ADR-0012 damage_calc_dictionary_payload
## precedent and G-20 (StringName not String for skill/tag identifiers).
@export var innate_skill_ids: Array[StringName] = []

## Equipment slot overrides as int array. Typed pending ADR-0007 ratification.
@export var equipment_slot_override: Array[int] = []
