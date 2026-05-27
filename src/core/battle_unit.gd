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

## Cached `stat_intellect` (0-100) from HeroData. Populated at battle init from
## HeroDatabase + chapter roster; default INT_BASELINE=60 = formula identity for
## fire_strategy / fire_scroll INT scaling (damage-calc.md rev 2.9.4 §F-DC-8).
## Falling back to 60 keeps fire damage at base_damage × 1.0 for any unit whose
## hero record is missing (mirrors the raw_atk=10 fallback discipline at
## BattleScene._make_battle_unit).
@export var stat_intellect: int = 60

## AI archetype identifier — `&"aggressor"` / `&"skirmisher"` / `&"holder"` /
## `&"coordinator"` per ADR-0019 §4 dispatch table. Distinct from `tag` field
## above: `tag` carries the FATE-COUNTER role (`tank`/`assassin`/`boss`) while
## `archetype` carries the AI behaviour bucket. Both coexist because chapter
## fixtures may map archetype=coordinator → tag=boss for fate tracking, but the
## AI snapshot builder MUST read this field (not `tag`) to preserve the original
## archetype dispatch — otherwise `&"boss"` leaks into AISystem and falls
## through to the EC-AI-4 unknown-archetype warning path. Set at battle init
## from `chapter.enemy_roster[i].archetype` (player units default to
## `&"aggressor"`). Sprint-13 S13-12 addition.
@export var archetype: StringName = &"aggressor"

## Session-15 commit 5: active "ultimate"-style skill granted by hero data.
## Source = heroes.json `innate_skill_ids[0]`. Empty StringName = no skill
## (e.g. enemy mooks, units without an authored skill). One-shot per battle:
## GridBattleController.use_skill flips skill_used and refuses re-use.
## Known values (session 15): &"skill_dragon_blade" (관우), &"skill_thunder_roar"
## (장비), &"skill_inspire" (유비). Other tags map to no-op at the controller.
@export var skill_id: StringName = &""

## True once the active skill has fired this battle. Reset only at battle init —
## intentionally persists across rounds (skills are battle-scoped, not turn-scoped).
@export var skill_used: bool = false


# ── S90 Phase B fields (Strategy Systems v0.3 §3.3.1) ──────────────────────────

## Per-hero inventory of consumable items. Each slot holds an item_id StringName
## (e.g. &"heal_potion" / &"strength_scroll") or &"" for empty slot. Default
## INVENTORY_SLOT_COUNT = 3 slots per strategy-systems.md §3.1. Loaded at battle
## init from chapter.starting_inventory_by_hero; auto-cleared at battle end
## (no permanent accumulation per §3.4 — Pillar 5 ship target rule).
@export var inventory: Array[StringName] = []

## Pending multi-turn buff from a strategy item (e.g. strength_scroll).
## Empty Dictionary {} = no active buff (use {} as null-sentinel since
## Dictionary var cannot hold null per G-25). When non-empty, must contain:
##   { &"kind": StringName, &"magnitude": float, &"expires_at_turn": int }
## Outer type intentionally untyped Dictionary (NOT `Dictionary[StringName, Variant]`)
## to avoid G-25 nested-typed-collection parse error on value type.
##
## Consumed by GridBattleController at attack/skill resolve time:
##   resolve_mods.pending_buff_magnitude = attacker.pending_buff.get(&"magnitude", 1.0)
##   attacker.pending_buff = {}  # cleared by GridBattleController ONLY, not DamageCalc
## See damage-calc.md rev 2.9.4 §CR-1 + §F-DC-5 for ABI contract.
@export var pending_buff: Dictionary = {}

## Transient move_range bonus granted by march_scroll (strategy-systems v0.3 §4.4).
## Added to `move_range` for the current turn's reachability checks. Cleared back
## to 0 at the start of this unit's next turn (GridBattleController._on_unit_turn_started)
## so the bonus only lives within the turn it was purchased. Default 0 = no bonus.
## Additive on re-use — a hero with 2× march_scroll could stack +4 within one turn
## (EC-SS-2 design intent: items overwrite without warning, but march_scroll's
## effect is a numeric addition, not a Dictionary replacement).
@export var move_range_bonus: int = 0
