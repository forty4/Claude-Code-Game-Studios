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

## Stable chapter identifier, e.g. "ch06_changbanpo". Must match
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

## Per-unit_id → hero_id mapping for player units. Empty Dict = battle_scene
## falls back to its PLAYER_HERO_BY_UNIT_ID const (uids 0, 1 only) then to
## 장비 for unknown uids. Authored chapters with player units beyond uid 0/1
## (e.g. 관우 합류 from ch3 onwards) SHOULD populate this field.
## Untyped Dictionary at @export per G-25 (no nested typed collections in 4.6).
## Runtime shape: { unit_id_int → hero_id_string }.
@export var player_hero_ids: Dictionary = {}

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

## Optional per-chapter ENEMY_ATK_MULT override. Sentinel -1.0 = unset, fall
## back to BalanceConstants.ENEMY_ATK_MULT (global). When set to a non-negative
## float (typically 0.5–1.0), BattleScene applies THIS value to enemy raw_atk
## for this chapter instead of the global. Lets ch2 / ch3 carry their own
## difficulty curve without forcing every chapter to share one MULT.
##   Authoring convention: omit the JSON field for chapters that should use
##   the global default; set explicit value for chapters that need tuning.
##   Valid range: [0.0, 2.0] — outside that and BattleScene falls back to
##   global with a push_warning (defensive against accidental JSON typos).
@export var enemy_atk_mult: float = -1.0


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


# ─── Hidden destiny condition (Pillar 2 — 운명은 바꿀 수 있다) ──────────────────

## Optional hidden-condition branch key. When non-empty AND the corresponding
## hidden_condition predicate evaluates true on the battle's fate_data AND the
## outcome is WIN, DestinyBranchJudge routes to this branch_key INSTEAD of
## WIN_default. Empty = no hidden condition authored (standard 4-row resolution).
##
## Authoring convention: chapter that exposes a hidden-condition path MUST also
## register the resolved branch_path_id in branch_table (lookup name distinct
## from `WIN_default`, typically `WIN_hidden`), e.g.:
##   branch_table = {
##     "WIN_default":  "WIN_changbanpo_default",
##     "WIN_hidden":   "WIN_changbanpo_lord_unharmed",
##     "LOSS_default": "LOSS_changbanpo_retreat",
##   }
##   hidden_branch_key = "WIN_hidden"
@export var hidden_branch_key: String = ""

## Predicate Dictionary describing the hidden-condition check. Shape:
##   { "type": "fate_threshold", "field": <fate_data_key>, "op": ">=|>|==|<=|<",
##     "value": <number> }
## Evaluated by HiddenConditionEvaluator against BattleOutcome.fate_data.
## Empty = no predicate authored (hidden_branch_key MUST also be empty).
##
## Example — "Zhang Fei kills 2+":
##   { "type": "fate_threshold", "field": "assassin_kills", "op": ">=", "value": 2 }
@export var hidden_condition: Dictionary = {}


# ─── Legendary destiny tier (S65+ — 영걸전식 finale 매력 보강) ────────────────

## Optional legendary-tier branch key. When non-empty AND BOTH:
##   1. hidden_branch_key fires (Row 2a hidden condition satisfied), AND
##   2. legendary_condition predicate evaluates true,
## DestinyBranchJudge routes to THIS branch_key INSTEAD of hidden_branch_key.
## Empty = no legendary tier authored (hidden is the highest reachable branch).
##
## Authoring convention: legendary tier must be registered in branch_table just
## like hidden, with a distinct lookup name (typically "WIN_legendary"):
##   branch_table = {
##     "WIN_default":   "WIN_wuzhang_kongming_falls",
##     "WIN_hidden":    "WIN_wuzhang_kongming_revives",
##     "WIN_legendary": "WIN_wuzhang_legendary_dawn",
##     "LOSS_default":  "LOSS_wuzhang_consumed",
##   }
##   hidden_branch_key    = "WIN_hidden"
##   legendary_branch_key = "WIN_legendary"
##
## Designed for ch25 칠성단 회생 + 5 시그니처 누적 → "전설의 새벽" 엔딩.
@export var legendary_branch_key: String = ""

## Predicate Dictionary describing the legendary-tier check. Same shape as
## hidden_condition. Evaluated by HiddenConditionEvaluator against the cascade-
## aware fate_data (ScenarioRunner injects active_signature_count at BEAT_7).
##
## Example — "all 5 signatures active":
##   { "type": "fate_threshold", "field": "active_signature_count", "op": ">=", "value": 5 }
@export var legendary_condition: Dictionary = {}


# ─── Cascade join announcement (S65+ — 5 영웅 fan service narrative) ──────────

## Optional per-signature cascade join text key. When a signature branch resolved
## in the IMMEDIATELY PRIOR chapter AND this chapter authored a matching entry,
## ScenarioRunner emits GameBus.cascade_join_announced(signature_key, text_key)
## at CHAPTER_START — letting BattleScene / StoryEvent show the cascade hero's
## first-join prose (위연 ch14 합류 인사 / 방통 ch17 등).
##
## Runtime shape: { signature_branch_key: i18n_text_key }. Empty = no cascade
## prose authored for this chapter.
##
## Example (ch14 의 wei_yan first-join):
##   cascade_join_prose = {
##     "WIN_changsha_wei_yan_defects": "ch14.cascade_join.wei_yan"
##   }
@export var cascade_join_prose: Dictionary = {}
