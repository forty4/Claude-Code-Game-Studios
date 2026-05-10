## ChapterDefinition — typed Resource representing one chapter's data.
##
## Hydrated from assets/data/scenarios/{scenario_id}.json at ScenarioRunner
## LOADING state entry. Immutable after hydration — ScenarioRunner MUST NOT
## mutate branch_table or any other field at runtime (CR-15 + forbidden_pattern
## scenario_runner_branch_table_runtime_mutation).
##
## ADR: ADR-0017 §Decision §Chapter Data Form.
## TR: TR-scenario-progression-003 (ChapterDefinition typed Resource shape).
class_name ChapterDefinition
extends Resource


# ─── Core identity ───────────────────────────────────────────────────────────

## Stable chapter identifier, e.g. "ch01_changbanpo". Must match
## regex ^[a-z][a-z0-9_]*$ per EC-SP-8 validation pipeline.
@export var chapter_id: String = ""

## 1-indexed chapter number. Chapter 1 = silent-visual variant per art-bible §4.7.
@export var chapter_number: int = 0

## Map identifier resolved to assets/data/maps/{map_id}.tres at BEAT_4_PREP exit.
@export var map_id: String = ""


# ─── Branch authoring ─────────────────────────────────────────────────────────

## CR-14: if true, a DRAW branch MUST be authored in branch_table.
@export var author_draw_branch: bool = false

## CR-6 + F-SP-2: echo count threshold for echo-gated draw branch resolution.
## Must be 0 for chapter_number == 1; >= 1 for all other chapters.
@export var echo_threshold: int = 0

## branch_table: untyped Dictionary at @export boundary.
## GDScript 4.6 does NOT support typed Dictionary[K,V] @export — see
## terrain_effect.gd lines 16-20 for the project's no-typed-Dict-export rule.
## Runtime shape: { lookup_key: String → branch_path_id: String }.
## Keys include WIN_default, LOSS_default, and optionally DRAW_{n} keys.
## MUST NOT be mutated after LOADING state exit (forbidden_pattern
## scenario_runner_branch_table_runtime_mutation enforced by CI lint).
@export var branch_table: Dictionary = {}

## Per-chapter "official" branch id. F-SP-1 reads this to set
## DestinyBranchChoice.is_canonical_history. MUST be a value in branch_table.values().
@export var canonical_branch_key: String = ""


# ─── Beat narrative text keys ─────────────────────────────────────────────────

## i18n key for Beat 1 anchor narrative.
@export var beat_1_text_key: String = ""

## Multi-modal Beat 2 fragment: visual_cue_id + audio_cue_id.
## Chapter 1 uses silent_visual variant per art-bible §4.7.
## Untyped Dictionary — keys: variant, visual_cue_id, audio_cue_id.
@export var beat_2_fragment: Dictionary = {}

## i18n key for Beat 3 situation briefing.
@export var beat_3_text_key: String = ""

## Per-branch revelation entries for Beat 8.
## Each entry: { branch_key: String, text_key: String, cue_tag: String }.
## Array[Dictionary] — untyped inner shape per JSON flexibility.
@export var beat_8_revelations: Array[Dictionary] = []

## i18n key for Beat 9 chapter transition text.
@export var beat_9_text_key: String = ""


# ─── Battle configuration ──────────────────────────────────────────────────────

## Player unit IDs for this chapter (resolved to BattleUnit via HeroDatabase).
@export var player_unit_ids: PackedInt64Array = PackedInt64Array()

## Commander unit ID for player side (-1 = no designated commander).
@export var player_commander_id: int = -1

## Enemy unit IDs for this chapter.
@export var enemy_unit_ids: PackedInt64Array = PackedInt64Array()

## Default deployment positions: int (unit_id) → Vector2i (grid coord).
## Untyped Dictionary — GDScript typed-Dict @export prohibition per G-2.
@export var deployment_positions_default: Dictionary = {}

## Victory conditions resource (VictoryConditions typed Resource).
@export var victory_conditions: VictoryConditions = null

## Defeat conditions resource (VictoryConditions typed Resource, repurposed).
@export var defeat_conditions: VictoryConditions = null

## Battle start effects for this chapter.
@export var battle_start_effects: Array[BattleStartEffect] = []


# ─── Enemy roster (ADR-0019 §Migration Plan §8) ───────────────────────────────

## Enemy unit roster entries. Each entry is a Dictionary with at minimum:
##   unit_id: int, hero_id: String, archetype: StringName (defaults &"aggressor")
## AISystem reads archetype at chapter-load via unit.get("archetype", &"aggressor").
## ScenarioRunner does NOT validate or consume archetype — that is AISystem scope.
@export var enemy_roster: Array[Dictionary] = []


# ─── Tactical hints (S7-05 chapter-1 integration substrate) ───────────────────

## Chokepoint grid coords surfaced into BattleStateSnapshot.chokepoints for
## AISystem F-AI-3 (holder archetype) anchor scoring. Empty = no chokepoints.
## BattleScene plumbs these into GridBattleController.set_chokepoints() at
## chapter-load so they flow into _make_battle_state_snapshot() per AI turn.
@export var chokepoints: Array[Vector2i] = []


# ─── Branch-conditional deployment overrides ──────────────────────────────────

## Optional per-prior-branch deployment overrides. Keys are prior chapter
## branch_path_id strings (e.g. "WIN_changbanpo_default"); values are
## Dictionaries with optional keys: player_unit_ids (Array[int]),
## player_commander_id (int), enemy_unit_ids (Array[int]),
## deployment_positions_default (Dictionary[String, Array[int]]),
## enemy_roster (Array[Dictionary]).
## ScenarioRunner._build_battle_payload looks up the previous chapter's
## branch_path_id; if a matching key is present, those fields override the
## chapter's defaults for this battle. Empty = no overrides (always use defaults).
@export var branch_overrides: Dictionary = {}
