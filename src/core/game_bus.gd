## GameBus — the single cross-system signal relay for 천명역전.
##
## This file is the authoritative signal contract referenced by ADR-0001.
## Every cross-scene / cross-system event in the project is declared here.
##
## RULES:
##  - GameBus holds NO game state. It is a pure relay.
##  - Emission semantics: direct emission from emitters (`GameBus.battle_outcome_resolved.emit(payload)`).
##    Subscribers always use `CONNECT_DEFERRED`:
##      GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)
##  - Subscribers MUST disconnect in `_exit_tree` and guard payloads with `is_instance_valid`.
##  - Per-frame events are FORBIDDEN here. See ADR-0001 §Implementation Guidelines.
##
## DO NOT add fields, methods, or logic to this file beyond signal declarations
## and doc comments. See ADR-0001 §Evolution Rule for how to change the contract.
extends Node

# ═══ DOMAIN: Scenario Progression (emitter: ScenarioRunner) ════════════════════
signal chapter_started(chapter_id: String, chapter_number: int)
signal battle_prepare_requested(payload: BattlePayload)
signal battle_launch_requested(payload: BattlePayload)
signal chapter_completed(result: ChapterResult)
signal scenario_complete(result: ScenarioResult)
## scenario_fault — emitted by ScenarioRunner when JSON validation or runtime
## fault prevents scenario progression. Subscribers surface a retry/abort dialog
## per ADR-0002 §SceneManager scenario_fault handler.
## EC-SP-8: emitted on malformed branch_table / missing canonical_branch_key /
## JSON parse failure.
signal scenario_fault(scenario_id: String, fault: String, details: Dictionary)
signal scenario_beat_retried(mark: EchoMark)

# ═══ DOMAIN: Grid Battle (emitter: BattleController) ═══════════════════════════
signal battle_outcome_resolved(outcome: BattleOutcome)

## formation_bonuses_updated — emitted by GridBattleController on Formation Bonus
## state changes per ADR-0014 CR-12 + ADR-0015 §3 R-3. Emission site is owned by
## the Grid Battle epic; this declaration lands first to unblock battle-hud
## story-002 subscription. The emission contract (when fired, snapshot shape)
## will be ratified when GridBattleController formation-bonus path is implemented
## per the Grid Battle epic.
signal formation_bonuses_updated(snapshot: Dictionary)

# ═══ DOMAIN: Turn Order (emitter: TurnOrderRunner) ═════════════════════════════
signal round_started(round_number: int)
signal unit_turn_started(unit_id: int)
signal unit_turn_ended(unit_id: int, acted: bool)
signal victory_condition_detected(result: int)

# ═══ DOMAIN: HP/Status (emitter: HPStatusController) ═══════════════════════════
signal unit_died(unit_id: int)

# ═══ DOMAIN: Destiny (emitter: DestinyBranchJudge / DestinyStateStore) ═════════
signal destiny_branch_chosen(choice: DestinyBranchChoice)
signal destiny_state_flag_set(flag_key: String, value: bool)
signal destiny_state_echo_added(mark: EchoMark)

# ═══ DOMAIN: Story Event / Beat presentation (emitter: BeatConductor) ══════════
signal beat_visual_cue_fired(cue: BeatCue)
signal beat_audio_cue_fired(cue: BeatCue)
signal beat_sequence_complete(beat_number: int)

# ═══ DOMAIN: Story Event #10 (emitter: StoryEvent) ═════════════════════════════
# Per design/gdd/story-event.md CR-SE-4 (rev 1.0 Designed 2026-05-05).
# ADR-0001 minor amendment per Evolution Rule #4 ratifies these 3 additions at
# sprint-8+ /architecture-review delta — until then the source-of-truth is this
# file + the 4 expected_signals test list at game_bus_declaration_test.gd:14.
signal story_event_resolved(beat_number: int, variant_key: StringName, text_key: String, cue_tag: StringName)
signal story_event_invalid_path_detected(reason: StringName, choice_chapter_id: String)
signal story_event_revelation_committed(chapter_id: String, branch_key: String, register: StringName)

# ═══ DOMAIN: Input (emitter: InputRouter) ══════════════════════════════════════
signal input_action_fired(action: String, context: InputContext)
signal input_state_changed(from: int, to: int)
signal input_mode_changed(mode: int)

# ═══ DOMAIN: UI / Flow (emitter: UIRoot, SceneManager) ═════════════════════════
signal ui_input_block_requested(reason: String)
signal ui_input_unblock_requested(reason: String)
signal scene_transition_failed(context: String, reason: String)

# ═══ DOMAIN: Persistence (emitter: SaveManager; ScenarioRunner requests) ═══════
signal save_checkpoint_requested(ctx: SaveContext)
signal save_persisted(chapter_number: int, cp: int)
signal save_load_failed(op: String, reason: String)
signal save_loaded(ctx: SaveContext)

# ═══ DOMAIN: Environment (emitter: MapGrid) ════════════════════════════════════
signal tile_destroyed(coord: Vector2i)
