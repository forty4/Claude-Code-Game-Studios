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
signal scenario_complete(scenario_id: String)
signal scenario_beat_retried(mark: EchoMark)

# ═══ DOMAIN: Grid Battle (emitter: BattleController) ═══════════════════════════
signal battle_outcome_resolved(outcome: BattleOutcome)

# ═══ DOMAIN: Turn Order (emitter: TurnOrderRunner) ═════════════════════════════
signal round_started(round_number: int)
signal unit_turn_started(unit_id: int)
signal unit_turn_ended(unit_id: int, acted: bool)

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

# ═══ DOMAIN: Environment (emitter: MapGrid) ════════════════════════════════════
signal tile_destroyed(coord: Vector2i)
