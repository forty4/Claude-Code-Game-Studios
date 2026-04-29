## hero_data.gd
## Ratified by ADR-0007 (Hero Database, Accepted 2026-04-29).
## All fields are @export-annotated for ResourceSaver round-trip + Inspector authoring
## (non-@export fields are silently dropped — ADR-0003 TR-save-load-002).
## Consumed read-only by 8+ systems via HeroDatabase static query layer; runtime
## stat changes belong to consumer-side "base + modifier" pattern (CR §Interactions
## "읽기 전용 계약" — see forbidden_pattern hero_data_consumer_mutation).
class_name HeroData
extends Resource


## Hero faction enum — locally scoped per ADR-0007 §2 (no cross-system consumer).
enum HeroFaction {
	SHU      = 0,
	WEI      = 1,
	WU       = 2,
	QUNXIONG = 3,
	NEUTRAL  = 4,
}


# ─── Identity Block (CR-2 §Identity, 7 fields) ──────────────────────────────

## Hero unique identifier per CR-1: `^[a-z]+_\d{3}_[a-z_]+$` (e.g. `shu_001_liu_bei`).
## Immutable across project lifetime. Empty StringName = unset; HeroDatabase load rejects.
@export var hero_id: StringName = &""

## Korean display name (e.g. "유비").
@export var name_ko: String = ""

## Han hanja name (e.g. "劉備").
@export var name_zh: String = ""

## Courtesy name 字 (e.g. "玄德"). Empty string allowed per GDD CR-2.
@export var name_courtesy: String = ""

## Default faction (HeroFaction enum int [0, 4]). Runtime soft-faction override
## handled by Scenario Progression — Hero DB stores immutable origin only.
@export var faction: int = 0

## Portrait asset key — Art Bible owned. Empty string = no portrait registered yet.
@export var portrait_id: String = ""

## Battle sprite asset key — Art Bible owned. Empty string = no sprite registered.
@export var battle_sprite_id: String = ""


# ─── Core Stats Block (F-DC ATK / F-1 ATK derivation input, range [1, 100]) ─

## Primary combat stat — F-1 ATK derivation. Range [1, 100].
@export var stat_might: int = 1

## Tactics / magic stat — F-2 MAG_DEF (Strategist) derivation. Range [1, 100].
@export var stat_intellect: int = 1

## Leadership stat — Formation Bonus (Commander Rally) input. Range [1, 100].
@export var stat_command: int = 1

## Speed / positioning stat — F-4 Initiative derivation. Range [1, 100].
@export var stat_agility: int = 1


# ─── Derived Stat Seeds Block (range [1, 100]) ──────────────────────────────

## HP seed for F-3 max_hp derivation (independent of stat_might per GDD CR-2).
@export var base_hp_seed: int = 1

## Initiative seed for F-4 derivation (independent of stat_agility per GDD CR-2).
@export var base_initiative_seed: int = 1


# ─── Movement Block (range [2, 6]) ──────────────────────────────────────────

## Hero base move range before class delta (UnitRole.get_effective_move_range applies
## class delta + clamp to [MOVE_RANGE_MIN, MOVE_RANGE_MAX] per F-5).
@export var move_range: int = 2


# ─── Role Block (default class + equipment slot override) ───────────────────

## Default class as UnitRole.UnitClass enum value [0, 5]. Stored as int per
## ADR-0007 §2 — cross-script @export typed-enum is brittle in Godot 4.x Inspector
## authoring. Cross-doc convention: int values align 1:1 with UnitRole.UnitClass.
@export var default_class: int = 0

## Equipment slot overrides as int array. Semantic mapping (WEAPON/ARMOR/MOUNT/
## ACCESSORY → int) deferred to Equipment/Item ADR. Empty = use class defaults.
@export var equipment_slot_override: Array[int] = []


# ─── Growth Block (per-stat level-up multiplier, range [0.5, 2.0]) ──────────

## Might growth multiplier — Character Growth ADR consumer.
@export var growth_might: float = 1.0

## Intellect growth multiplier.
@export var growth_intellect: float = 1.0

## Command growth multiplier.
@export var growth_command: float = 1.0

## Agility growth multiplier.
@export var growth_agility: float = 1.0


# ─── Skills Block (parallel arrays — must be equal length per CR-2 + EC-2) ──

## Innate skill IDs as StringName array — per ADR-0012 damage_calc_dictionary_payload
## precedent + G-20 (StringName not String for skill/tag identifiers). Order = unlock order.
@export var innate_skill_ids: Array[StringName] = []

## Parallel array of unlock levels per skill ID. innate_skill_ids.size() ==
## skill_unlock_levels.size() invariant (HeroDatabase load rejects mismatch — EC-2).
@export var skill_unlock_levels: Array[int] = []


# ─── Scenario Block (join chapter + condition + MVP roster filter) ──────────

## Scenario chapter where this hero becomes available (1-indexed).
@export var join_chapter: int = 1

## Join condition tag — opaque String for MVP. Scenario Progression ADR canonicalizes
## tag vocabulary. Empty string = unconditional join.
@export var join_condition_tag: String = ""

## MVP roster inclusion flag. HeroDatabase.get_mvp_roster() filters on this field.
@export var is_available_mvp: bool = false


# ─── Relationships Block (provisional shape; Formation Bonus ADR migration) ─

## Inter-hero relationship records. Provisional Array[Dictionary] until Formation
## Bonus ADR ratifies typed Array[HeroRelationship]. Each Dictionary has 4 fields per
## GDD CR-2 §Relationships: hero_b_id, relation_type, effect_tag, is_symmetric.
##
## NOTE: Resource.duplicate() does NOT deep-copy the inner Dictionaries — callers
## wanting isolation must use Resource.duplicate_deep() (Godot 4.5+). The typed
## Array[HeroRelationship] migration (Formation Bonus ADR) closes this structurally.
@export var relationships: Array[Dictionary] = []
