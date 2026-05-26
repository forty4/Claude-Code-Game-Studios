## GridBattleController — central battle orchestrator for 천명역전 MVP First Chapter.
##
## Per ADR-0014 §1: 4th invocation of battle-scoped Node pattern (after ADR-0010
## HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera). Lives at
## BattleScene/GridBattleController. Freed with BattleScene exit. Not autoloaded.
##
## Class name `GridBattleController` — verified no Godot 4.6 ClassDB collision per
## ADR-0014 §1 (Battle / Grid / Controller are not Godot built-in class names).
##
## DI seam: BattleScene MUST call `setup(units, map_grid, camera, ...)` BEFORE
## `add_child()`. The `_ready()` body asserts all 7 deps non-null + units non-empty;
## without setup, the scene fails fast at mount time per ADR-0014 §3 + R-2 mitigation.
##
## MVP scope (per ADR-0014 §0): MOVE + ATTACK only; player-vs-script-bot;
## 5-turn limit; single chapter (장판파). AI integration, FormationBonusSystem,
## Rally, and USE_SKILL are explicitly deferred to future ADRs.
##
## MANDATORY `_exit_tree()` body explicitly disconnects all 5 signal subscriptions
## per ADR-0014 R-10 + ADR-0013 R-6 (camera_missing_exit_tree_disconnect forbidden_pattern
## extended to this ADR). GameBus is autoload — it outlives GridBattleController; without
## disconnect, autoload retains callables pointing at freed Node = leak + crash on next emit.
## HPStatusController + TurnOrderRunner are battle-scoped Nodes; null-guarded before disconnect.
##
## NOTE: GameBus.input_action_fired signal signature uses `String` (per ADR-0001 line 168 +
## battle_camera.gd NOTE block — `signal input_action_fired(action: String, context: InputContext)`).
## InputContext fields are `target_coord` / `target_unit_id` / `source_device` per
## src/core/payloads/input_context.gd (NOT `coord` / `unit_id` per ADR sketches).
##
## NOTE (signal routing — ADR-0014 §3 drift, verified at story-001 implementation 2026-05-02):
## ADR-0014 §3 architectural sketch shows `_hp_controller.unit_died.connect(...)` and
## `_turn_runner.unit_turn_started.connect(...)` / `.round_started.connect(...)` as INSTANCE
## signals. Production-shipped HPStatusController + TurnOrderRunner emit these via the
## GameBus autoload (per ADR-0010 §6 + ADR-0011 §Emitted signals + GameBus.gd lines 30/31/36).
## Therefore this controller subscribes to GameBus.X for all 5 signals (input_action_fired +
## unit_died + unit_turn_started + unit_turn_ended + round_started) — uniform autoload subscription
## pattern. unit_turn_ended was added later (end-of-turn polygon dim) as a view-layer re-emit;
## ADR-0014 §3 amended same-patch with "Implementation Notes" delta.

class_name GridBattleController
extends Node


# ─── Enums ───────────────────────────────────────────────────────────────────

## FSM — 2-state battle state machine per ADR-0014 §2 MVP scope.
## Full grid-battle.md GDD substates (AI_WAITING, AI_DECISION etc.) are deferred to
## the Battle AI ADR (sprint-7+).
enum BattleState {
	OBSERVATION,   ## No unit selected; click selects own unit
	UNIT_SELECTED, ## A unit is selected; click moves / attacks / deselects
}


# ─── Constants ───────────────────────────────────────────────────────────────

## The 10 grid-domain actions emitted by InputRouter that this controller filters
## per ADR-0014 §4 + input-handling GDD §93. Actions outside this list
## (camera_pan / camera_zoom_in / etc.) are silently ignored.
##
## Action semantics (MVP):
##  - unit_select: toggle unit selection (OBSERVATION→SELECTED on own unit; SELECTED→OBSERVATION on same)
##  - move_target_select / move_confirm: commit move action if tile is in move range
##  - move_cancel: deselect (return to OBSERVATION)
##  - attack_target_select / attack_confirm: commit attack action if tile is in attack range
##  - attack_cancel: deselect
##  - undo_last_move: MVP silent (post-MVP undo system)
##  - end_unit_turn: explicit player-turn-end button
##  - grid_hover: PC-only hover preview; silently ignored per CR-1c (touch parity)
const _GRID_ACTIONS: Array[String] = [
	"unit_select",
	"move_target_select",
	"move_confirm",
	"move_cancel",
	"attack_target_select",
	"attack_confirm",
	"attack_cancel",
	"undo_last_move",
	"end_unit_turn",
	"defend_stance",  # session-13: D key — selected unit takes defend stance
	"use_skill",      # session-15: S key — fire selected unit's innate skill (1×/battle)
	"grid_hover",
]


## Diagnostic-trace gate. Sessions 4-5 used inline raw `print(...)` calls (CLICK
## / TURN / HINT / SELECT / BATTLE-END categories) to debug input + turn-loop
## behavior in the windowed env. Now routed through `_trace()` and silenced by
## default; flip to `true` (then re-import) to surface the full event-stream
## again.
const _TRACE_ENABLED: bool = false

## S73 — Synergy attestation gate (independent of `_TRACE_ENABLED`). Fires only
## when a synergy bonus is actually applied (bonus > 0). Flipped to false after
## S73 windowed attestation confirmed Peach Garden +5 ATK fires correctly
## (장비 92→97 / 유비 70→75 / 관우 95→100). Flip back to true if mechanic
## investigation needed.
const _SYNERGY_TRACE_ENABLED: bool = false

## S73 — Critical chain attestation gate (independent of `_TRACE_ENABLED`).
## Fires when REAR CRIT chain advances (level ≥ 1). Flipped to false after S73
## windowed attestation confirmed natural lv1 + lv2 firing (장비 245→306 +25%
## chain). Flip back to true if chain mechanic investigation needed.
const _CRIT_CHAIN_TRACE_ENABLED: bool = false


func _trace(msg: String) -> void:
	if _TRACE_ENABLED:
		print(msg)


## Phase 1 D fix — anticipation beat between unit_turn_started(enemy) and
## ai_action_requested.emit. Lets the player read "Turn: 적장" label + tile
## highlight + chevron before the AI move/attack fires. Per session 2026-05-20
## D-track agreement; tune later if attestation reveals different sweet spot.
const AI_THINKING_PAUSE_SEC_DEFAULT: float = 0.35

## Per-instance pause override. Tests set to 0.0 to keep AI dispatch synchronous
## with the existing process_frame-based settle pattern. Production code MUST NOT
## mutate this — use set_ai_thinking_pause_sec_for_test() from tests only.
var _ai_thinking_pause_sec: float = AI_THINKING_PAUSE_SEC_DEFAULT


## Test-only: zero (or shorten) the AI thinking pause so existing wiring tests
## don't have to wait 0.35s wall-clock per dispatch. Production callers MUST NOT
## call this — battle balance assumes the default beat.
func set_ai_thinking_pause_sec_for_test(sec: float) -> void:
	_ai_thinking_pause_sec = max(0.0, sec)


# ─── Signals (Battle-domain per ADR-0014 §8) ────────────────────────────────

## Emitted when unit selection changes. was_selected == -1 for deselect.
signal unit_selected_changed(unit_id: int, was_selected: int)

## Emitted after a unit completes a move action.
signal unit_moved(unit_id: int, from: Vector2i, to: Vector2i)

## Emitted after HPStatusController.apply_damage resolves and returns.
signal damage_applied(attacker_id: int, defender_id: int, damage: int)

## Session-23 — emitted after FIRE-tile round-start damage is applied to a unit.
## Separate from `damage_applied` so the view layer can render the burn with a
## distinct visual channel (orange popup, orange flash, no camera shake / SFX_HIT)
## without coupling to the attack-hit handler. defender_id receives the tick;
## damage is the resolved FIRE_DAMAGE_PER_TURN amount (post HP-clamp).
signal fire_damage_applied(defender_id: int, damage: int)

## Session-16: emitted alongside damage_applied when the attack landed on the
## defender's REAR (×1.50 angle_mult on most classes). View-layer subscribers
## (battle_scene) use this to spawn a "치명타!" popup + camera shake + SFX cue
## so the player gets immediate "you flanked correctly" feedback. Not emitted
## on MISS, on 0-damage hits, or on FRONT/FLANK directions. `angle` is one of
## &"FRONT" / &"FLANK" / &"REAR" per _angle_to_direction_rel; only &"REAR" is
## sent today but the field is included for forward compat with a future
## "strong flank" tier.
signal critical_hit_landed(attacker_id: int, defender_id: int, damage: int, angle: StringName, chain_level: int)

## S72 Critical chain — emitted whenever the per-side CRIT chain advances OR
## resets at round_started. `level` is the new chain count (0 on reset, 1+
## post-increment). View-layer subscribers (battle_hud) render persistent
## chain indicator. Chain advances on REAR-direction CRIT; resets at round
## boundary. Per-side (0 = player, 1 = enemy) so cross-side CRITs do not
## interfere.
signal critical_chain_changed(side: int, level: int)

## Session-16: emitted when a unit is killed (cross-side, credited to a known
## last attacker) and the battle is NOT yet over. View-layer subscribers
## (battle_scene) spawn a "X 처치!" popup + play SFX_KILL so the player gets
## immediate "you got the kill" feedback rather than only seeing the polygon
## fade out. Friendly-fire deaths + battle-over-terminal deaths are filtered
## out (the result screen handles those). victim_hero_id surfaces alongside
## victim_id so the popup can show 한글 이름 without an extra HeroDatabase
## lookup at the view layer.
signal unit_killed(killer_id: int, victim_id: int, victim_hero_id: StringName)

## Session-16: emitted when a unit gains a status effect (poison / slow / etc.)
## via a skill or attack. View-layer subscribers (battle_scene) spawn a small
## glyph badge on the unit's polygon so the player sees the active debuff at a
## glance. Separate from `unit_defend_stance_applied` so the buff/debuff layer
## stays composable — defend_stance is its own visual channel (방 badge).
signal unit_status_applied(unit_id: int, effect_id: StringName)

## Controller-scoped re-emit of GameBus.unit_died so scene-tier subscribers
## (BattleScene visual feedback) can react without subscribing to GameBus
## directly (battle_scene_smoke_test AC-7: no GameBus subs in BattleScene).
signal unit_visual_died(unit_id: int)

## Controller-scoped re-emit of GameBus.unit_turn_started for the view layer
## (BattleScene turn-indicator overlay). Fires for both player and AI turns;
## the view layer reparents a single TurnIndicator child under the active
## unit's polygon. Re-emit pattern avoids R-7 (no GameBus subs on BattleScene).
signal active_unit_changed(unit_id: int)

## Controller-scoped re-emit of GameBus.unit_turn_ended for the view layer
## (BattleScene end-of-turn polygon dim). acted=false units (passed without
## spending a token) don't get dimmed. Re-emit pattern avoids R-7.
signal unit_turn_ended_visual(unit_id: int, acted: bool)

## Controller-scoped re-emit of GameBus.round_started for the view layer
## (BattleScene undim-all on round rollover). Distinct from the controller's
## own _on_round_started handler which owns the turn-limit + fate-counter
## logic — this signal exists purely as a view-layer rollover cue.
signal round_started_visual(round_number: int)

## Emitted when the battle is over. outcome is a StringName (e.g. &"TURN_LIMIT_REACHED").
## fate_data carries hidden fate condition snapshot per ADR-0014 §8.
signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)

## Emitted silently for each fate-condition update. Destiny Branch ADR (sprint-6)
## is the SOLE subscriber — Battle HUD MUST NOT subscribe (preserves "hidden" semantic).
signal hidden_fate_condition_progressed(condition_id: StringName, value: int)

## 6th LOCAL signal — emitted at AI-turn entry per ADR-0019 + ADR-0014 §8 amended
## via /architecture-review delta #14 2026-05-05. AISystem (battle-scoped Node 6th
## invocation) subscribes with CONNECT_DEFERRED and responds via its own LOCAL
## signal `ai_action_ready(unit_id, command)` within 500ms timeout per CR-3.
signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)

## Emitted on the FIRST tap of a valid enemy target while a player unit is
## selected. BattleHUD subscribes and shows UI-GB-04 Combat Forecast with the
## preview Dictionary contents. The actual attack does NOT commit on this tap —
## a second tap on the same target commits (2-step pattern matches Fire Emblem /
## Tactics Ogre convention). Preview is preview_attack()'s return value.
signal attack_preview_requested(attacker_id: int, defender_id: int, preview: Dictionary)

## Emitted when the pending attack preview should be cleared — caller deselected
## the unit, clicked elsewhere, ran out of attack range, or the round rolled
## over. BattleHUD dismisses UI-GB-04 in response. Reason is informational.
signal attack_preview_dismissed(reason: StringName)

## Emitted whenever a unit enters defend stance (via player D-key OR AI DEFEND
## decision). Scene-tier subscribers (ChapterVisuals defend indicator) toggle
## a visual marker on the unit's polygon. Cleared at round rollover via the
## standard round_started_visual signal — no separate cleared signal needed.
signal unit_defend_stance_applied(unit_id: int)

## Session-15 commit 5: emitted when a player unit fires its innate skill via
## use_skill(). View-layer (battle_scene + battle_hud) subscribes for SFX +
## visual feedback + HUD button state refresh.
signal unit_skill_used(unit_id: int, skill_id: StringName)

## S90 Phase B: emitted when a unit successfully uses an inventory item via
## use_item(). View-layer subscribes for SFX + visual feedback + HUD inventory
## panel state refresh. `actual_effect` carries effect-specific magnitude (e.g.
## heal amount, buff magnitude × 100 for display, march tile count).
signal unit_item_used(unit_id: int, item_id: StringName, slot_idx: int, actual_effect: int)


# ─── DI dependencies (ADR-0014 §3) ──────────────────────────────────────────

## Unit registry: unit_id → BattleUnit Resource. Populated by setup() from the Array.
var _units: Dictionary[int, BattleUnit] = {}

var _map_grid: MapGrid = null
var _camera: BattleCamera = null
var _hero_db: HeroDatabase = null      ## DI'd but static-method consumer; kept for future roster queries
var _turn_runner: TurnOrderRunner = null
var _hp_controller: HPStatusController = null
# NOTE: DamageCalc is NOT a DI dependency — its methods are `static func` (per
# src/feature/damage_calc/damage_calc.gd). Call as `DamageCalc.resolve(...)` directly.
# Tests that need to mock DamageCalc behavior use the existing damage-calc test
# fixture pattern (see tests/unit/feature/damage_calc/) — not DI through this controller.
var _terrain_effect: TerrainEffect = null
var _unit_role: UnitRole = null

## AISystem DI field — injected via set_ai_system() AFTER add_child() (not a setup() param).
## Null = no AI subscriber (player-only mode or battle not yet wired). Per ADR-0014 §8
## Amendment 2026-05-10 §Subscriber Contract.
var _ai_system: AISystem = null


# ─── FSM + per-turn state (ADR-0014 §2) ─────────────────────────────────────

var _state: BattleState = BattleState.OBSERVATION
var _selected_unit_id: int = -1

## Currently-previewed attack target during 2-step attack flow. -1 = no preview
## armed. Session-10 addition: first click on a valid enemy target sets this +
## emits attack_preview_requested; second click on the SAME target commits the
## attack via _handle_player_attack. Cleared on commit, deselect, click on a
## different target, or round rollover. Lives ONLY in UNIT_SELECTED state — no
## need to clear on state transitions out of UNIT_SELECTED because _deselect
## already handles that path.
var _pending_attack_target_id: int = -1

## ID of the unit whose turn is currently ACTING per TurnOrderRunner. Player
## clicks on any other own unit are ignored — only the active turn unit can
## be selected, moved, or attack. Updated in _on_unit_turn_started; -1 between
## turns. Mirrors TurnOrderRunner's internal active-unit tracking so the click
## layer doesn't have to query the runner on every input.
var _active_turn_unit_id: int = -1

## unit_id → already-acted flag for this round.
var _acted_this_turn: Dictionary[int, bool] = {}

## unit_id → MOVE token spent this turn. Tracked separately from _acted_this_turn
## so a player unit can MOVE and then ATTACK in the same turn (mirrors the turn
## runner's move_token_spent / action_token_spent split per ADR-0011). MOVE sets
## this flag (blocks a second MOVE); ATTACK sets _acted_this_turn (terminal).
var _moved_this_turn: Dictionary[int, bool] = {}

## Session-52 — per-unit cache of the data needed to roll back the most
## recent MOVE this turn (cancel_last_move). Cleared automatically when the
## turn ends — keys are erased alongside _moved_this_turn.clear() sites at
## round_started / unit_turn_started. Each entry:
##   {"prev_pos": Vector2i, "prev_facing": int, "movement_cost": int}
var _move_undo_cache: Dictionary[int, Dictionary] = {}

## Session-17 — unit_id → "stunned, must WAIT on next turn" flag. Set by
## skill_naval_strategy (주유 책략) on every adjacent enemy. Consumed by
## _on_turn_runner_action_request which force-declares WAIT and erases the
## entry. Survives round transitions (intentional — STUN locks the target's
## NEXT turn regardless of when it lands within the current round). Cleared
## en-masse via initialize_battle reset path only.
var _pending_stun: Dictionary[int, bool] = {}


## Session-21 — ch5 적벽 본전 FIRE terrain (terrain_type=8) round-start damage.
## Called from _on_round_started before round_started_visual fires. Every alive
## unit whose position resolves to a FIRE tile takes FIRE_DAMAGE_PER_TURN as
## MAGICAL damage. Side-agnostic: player and AI burn equally if they linger on
## the wrong tile — pushes the player to MOVE through fire zones, not camp on
## them. apply_damage path is reused so unit_died emits correctly for the
## COMMANDER DEMORALIZED radius trigger; MAGICAL bypasses shield_wall flat
## reduction so INFANTRY units aren't immune (5 - SHIELD_WALL_FLAT could clamp
## to MIN_DAMAGE=1 without that gate).
func _apply_fire_damage_on_round_start() -> void:
	if _map_grid == null or _hp_controller == null:
		return
	var fire_damage: int = BalanceConstants.get_const("FIRE_DAMAGE_PER_TURN") as int
	for unit: BattleUnit in _units.values():
		if not _hp_controller.is_alive(unit.unit_id):
			continue
		var tile: MapTileData = _map_grid.get_tile(unit.position)
		if tile == null:
			continue
		if tile.terrain_type != 8:  # FIRE
			continue
		_hp_controller.apply_damage(unit.unit_id, fire_damage,
			ResolveModifiers.AttackType.MAGICAL,
			[&"fire", &"terrain"] as Array[StringName])
		# Session-23 — surface burn for the view layer (orange popup + flash).
		fire_damage_applied.emit(unit.unit_id, fire_damage)

## ID of the last attacker — used by fate-counter (assassin kill attribution).
var _last_attacker_id: int = -1

## S72 Critical chain — per-side CRIT counter that boosts subsequent CRIT
## damage within the same round. Reset at round_started. Per-side (0 = player,
## 1 = enemy) so cross-side CRITs don't interfere. Bonus table:
##   chain 1 (1st CRIT this round) → +10% to that hit's final_damage
##   chain 2 (2nd CRIT) → +25%
##   chain 3+ (3rd+) → +50% (cap)
var _critical_chain_per_side: Dictionary[int, int] = {0: 0, 1: 0}


## Bonus multiplier for the chain LEVEL (the count AFTER this CRIT increments).
## level 1 → 0.10 / level 2 → 0.25 / level 3+ → 0.50 (cap). level 0 = no bonus.
static func _critical_chain_bonus_for(level: int) -> float:
	if level <= 0:
		return 0.0
	if level == 1:
		return 0.10
	if level == 2:
		return 0.25
	return 0.50  # 3+ cap


# ─── Turn limit (ADR-0014 §3 / AC-4) ────────────────────────────────────────

## Derived from BalanceConstants at _ready(); never hardcoded.
var _max_turns: int = 0


# ─── Combat resolution (story-005) ───────────────────────────────────────────

## RNG instance for DamageCalc.resolve evasion roll consumption (1 randi_range
## per non-counter call per ADR-0012 AC-DC-26 replay determinism). Fresh
## RandomNumberGenerator per battle; deterministic seeding deferred to
## scenario-progression ADR (sprint-6).
var _rng: RandomNumberGenerator = null


# ─── Hidden fate-condition counters (ADR-0014 §2 / R-8) ─────────────────────

## unit_id of the 장비-tagged unit (tank). -1 if none found in roster.
var _fate_tank_unit_id: int = -1
## unit_id of the 조운-tagged unit (assassin). -1 if none found in roster.
var _fate_assassin_unit_id: int = -1
## unit_id of the boss-tagged enemy. -1 if none found in roster.
var _fate_boss_unit_id: int = -1
var _fate_rear_attacks: int = 0
var _fate_formation_turns: int = 0
var _fate_assassin_kills: int = 0
var _fate_boss_killed: bool = false

# Phase F (영걸전식 25챕터 hidden destiny tracking) — 12 additional fate field counters.
# Each is updated in either _on_round_started (per-round predicates) or kill / damage
# hooks. fate_data dict emits all 13+5 fields at battle end; HiddenConditionEvaluator
# reads via fate_threshold field → counter mapping.
#
# Wired (concrete gameplay logic):
#   win_within_turns        — round number when WIN outcome emits (sentinel 9999 if LOSS)
#   discipline_turns        — round count where no friendly losses occurred since last round
#   escort_alive_turns      — round count where unit 5 (ch03 escort placeholder) alive
#   wei_yan_spared_turns    — round count where unit 15 (ch13 위연) alive
#   qixing_turns            — round count where unit 13 (제갈량) on tile [7,5] (ch25 칠성단)
#   counter_fire_turns      — round count where ≥1 FIRE tile (terrain 8) on map (ch22)
#   retreat_path_clear_turns— round count where tile [13,5] has no enemy within 2 cells (ch20)
#   masu_supervised_turns   — round count where chokepoint [7,5] has friendly unit (ch24)
#   dmg_to_lubu             — cumulative damage to unit with hero_id qun_001_lu_bu (ch02)
#   huang_zhong_xiahou_yuan_kill — bool 1 if 황충 (unit 9) killed 하후돈 (unit 2) (ch19)
#
# Wired (continued):
#   scout_first_turns       — round count where ≥1 friendly CAVALRY/SCOUT unit
#                             stands on a FOREST tile (terrain 1). Represents
#                             정찰 forward positioning (ch16 방통 생존 시그니처).
#
# Aspirational (counter declared, NOT incremented — needs system extension):
#   menghuo_captures        — TODO ch23; needs capture-and-release mechanic
# civilians_escorted is wired via ADR-0022 Civilian System (ch05) — see
# _civilian_commit_save below for the SOLE mutator (lint-enforced).
var _fate_dmg_to_lubu: int = 0
var _fate_escort_alive_turns: int = 0
var _fate_win_within_turns: int = 9999
var _fate_civilians_escorted: int = 0
# ADR-0022 Civilian System (ch05 백성 evacuation). Empty collection + -1 sentinel
# = no civilian system active for this chapter. Populated via set_civilian_config.
var _civilian_tokens: Array[CivilianToken] = []
var _civilian_evacuate_zone_max_col: int = -1
var _fate_wei_yan_spared_turns: int = 0
var _fate_scout_first_turns: int = 0
var _fate_huang_zhong_xiahou_yuan_kill: int = 0
var _fate_retreat_path_clear_turns: int = 0
var _fate_discipline_turns: int = 0
var _fate_counter_fire_turns: int = 0
var _fate_menghuo_captures: int = 0
var _fate_masu_supervised_turns: int = 0
var _fate_qixing_turns: int = 0
# ch10 ★ Plan §4.3 "동남풍 perfect timing — 전원 생존" mechanical lock per
# design/quick-specs/ch10-chibi-perfect-wind.md. Counts player-side unit
# deaths during the battle. ★ trigger = SURVIVE WIN + player_casualties == 0.
# Incremented in _on_unit_died for player-side (battle_unit.side == 0).
var _fate_player_casualties: int = 0
# Internal: friendly-alive snapshot for discipline_turns. -1 = uninitialized.
var _fate_friendly_alive_at_last_round: int = -1

# ─── Player-facing battle stats (session-15 commit 4 — 성취감 surface) ────────
# These are categorical aggregates rendered on the UI-GB-09 result panel after
# battle_outcome_resolved fires. NOT fate counters — Pillar 2 audit clean.
## Damage dealt by each unit, regardless of side. Accumulated in _resolve_attack.
var _damage_dealt_by_unit: Dictionary[int, int] = {}
## Kill credit — incremented when _on_unit_died fires AND _last_attacker_id is
## the player on the other side. Player-side kills only; friendly fire excluded.
var _kills_by_unit: Dictionary[int, int] = {}


# ─── Terminal state (story-007 AC-7) ─────────────────────────────────────────

## Set true the moment battle_outcome_resolved is emitted. All input + signal
## handlers early-return when set, preventing duplicate outcome emission on
## edge cases (e.g., turn-limit firing simultaneously with last-enemy-death).
var _battle_over: bool = false

## Cached outcome StringName from the last _emit_battle_outcome call. Used by
## get_battle_stats() / _compute_star_rating to compute the result panel star
## tier without re-querying the alive-count predicates. &"" before first emit.
var _last_outcome: StringName = &""


# ─── Chokepoints (S7-05 chapter-1 substrate; sourced from ChapterDefinition) ─

## Tactical chokepoint coords surfaced into BattleStateSnapshot.chokepoints for
## AISystem F-AI-3 (holder archetype) anchor scoring. Set via set_chokepoints()
## by BattleScene at chapter-load. Empty = no chokepoints (default snapshot).
var _chokepoints: Array[Vector2i] = []


## Session-28 — per-chapter victory condition. Set via set_victory_conditions()
## by BattleScene at chapter-load. Null = use the default ANNIHILATION-only
## dispatcher path (preserves pre-S28 behaviour for chapters that don't set
## victory_conditions in their ChapterDefinition .tres).
var _victory_conditions: VictoryConditions = null


# ─── DI seam (BattleScene calls before add_child per ADR-0014 §3) ───────────

## Injects all 8 DI dependencies. MUST be called before add_child().
## DamageCalc is NOT a parameter — static-call site uses DamageCalc.resolve(...)
## directly per godot-specialist 2026-05-02 ADR-0014 review revision #2.
func setup(
		units: Array[BattleUnit],
		map_grid: MapGrid,
		camera: BattleCamera,
		hero_db: HeroDatabase,
		turn_runner: TurnOrderRunner,
		hp_controller: HPStatusController,
		terrain_effect: TerrainEffect,
		unit_role: UnitRole,
) -> void:
	for u: BattleUnit in units:
		_units[u.unit_id] = u
	_map_grid = map_grid
	_camera = camera
	_hero_db = hero_db
	_turn_runner = turn_runner
	_hp_controller = hp_controller
	_terrain_effect = terrain_effect
	_unit_role = unit_role
	# Tag-based fate-counter unit detection (per chapter-prototype pattern)
	_fate_tank_unit_id = _find_unit_by_tag(&"tank")
	_fate_assassin_unit_id = _find_unit_by_tag(&"assassin")
	_fate_boss_unit_id = _find_unit_by_tag(&"boss")


## Injects the AISystem subscriber for `ai_action_ready` signal. Called by
## BattleScene AFTER add_child(), once both GridBattleController and AISystem
## are in the scene tree. Safe to call before or after _ready() — connection is
## established here, not in _ready(), so ORDER of add_child() vs. set_ai_system()
## call does not matter.
##
## Idempotent: calling twice with the same AISystem does nothing (is_connected guard).
## CONNECT_DEFERRED mandatory: `_on_ai_action_ready` calls `_do_move` /
## `_resolve_attack` (NOT the `_handle_move` / `_handle_attack` wrappers — see
## handler doc comment for the bypass rationale) which mutate `_units` /
## `_map_grid` state; deferral prevents reentrance if AISystem emits synchronously
## inside `_on_ai_action_requested` (which itself fires deferred from
## GridBattleController, but AISystem may be called synchronously from tests).
## Per ADR-0014 §8 Amendment 2026-05-10.
##
## DI surface (injection point), not runtime state — mirrors set_action_controller
## precedent on TurnOrderRunner (ADR-0011 §Amendment 2026-05-09).
func set_ai_system(ai_system: AISystem) -> void:
	_ai_system = ai_system
	if _ai_system == null:
		return
	if not _ai_system.ai_action_ready.is_connected(_on_ai_action_ready):
		var err: int = _ai_system.ai_action_ready.connect(
			_on_ai_action_ready, Object.CONNECT_DEFERRED
		)
		assert(err == OK,
			"GridBattleController: ai_action_ready.connect failed (err=%d)" % err)


# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# DI guard — fail fast if BattleScene forgot setup() per ADR-0014 R-2 mitigation
	assert(_units.size() > 0,
		"GridBattleController.setup() must be called before adding to scene tree — _units is empty")
	assert(_map_grid != null,
		"GridBattleController.setup() must be called before adding to scene tree — _map_grid is null")
	assert(_camera != null,
		"GridBattleController.setup() must be called before adding to scene tree — _camera is null")
	assert(_hero_db != null,
		"GridBattleController.setup() must be called before adding to scene tree — _hero_db is null")
	assert(_turn_runner != null,
		"GridBattleController.setup() must be called before adding to scene tree — _turn_runner is null")
	assert(_hp_controller != null,
		"GridBattleController.setup() must be called before adding to scene tree — _hp_controller is null")
	assert(_terrain_effect != null,
		"GridBattleController.setup() must be called before adding to scene tree — _terrain_effect is null")
	assert(_unit_role != null,
		"GridBattleController.setup() must be called before adding to scene tree — _unit_role is null")

	_max_turns = int(BalanceConstants.get_const("MAX_TURNS_PER_BATTLE"))
	# Story-005: RNG instance for DamageCalc.resolve evasion roll consumption.
	# Deterministic seeding deferred to Scenario Progression ADR (sprint-6).
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	# CRITICAL: CONNECT_DEFERRED on unit_died is NOT merely advisory — it is
	# load-bearing reentrance prevention. Without it, _on_unit_died could fire
	# synchronously inside HPStatusController.apply_damage() called from
	# _resolve_attack(), producing reentrant _check_battle_end() invocation
	# mid-resolve. Future maintainers MUST NOT remove the DEFERRED flag here.
	# (Per godot-specialist 2026-05-02 ADR-0014 review revision #1.)
	GameBus.input_action_fired.connect(_on_input_action_fired, Object.CONNECT_DEFERRED)
	GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
	GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
	GameBus.unit_turn_ended.connect(_on_unit_turn_ended, Object.CONNECT_DEFERRED)
	GameBus.round_started.connect(_on_round_started, Object.CONNECT_DEFERRED)


func _exit_tree() -> void:
	# MANDATORY explicit disconnect per ADR-0014 R-10 + ADR-0013 R-6 +
	# camera_missing_exit_tree_disconnect forbidden_pattern extended to this ADR.
	# All 4 sources are GameBus autoload — autoload outlives this Node, so without
	# explicit disconnect the autoload retains callables pointing at freed Node =
	# leak + crash on next emit. All 4 disconnects unconditional.
	if GameBus.input_action_fired.is_connected(_on_input_action_fired):
		GameBus.input_action_fired.disconnect(_on_input_action_fired)
	if GameBus.unit_died.is_connected(_on_unit_died):
		GameBus.unit_died.disconnect(_on_unit_died)
	if GameBus.unit_turn_started.is_connected(_on_unit_turn_started):
		GameBus.unit_turn_started.disconnect(_on_unit_turn_started)
	if GameBus.unit_turn_ended.is_connected(_on_unit_turn_ended):
		GameBus.unit_turn_ended.disconnect(_on_unit_turn_ended)
	if GameBus.round_started.is_connected(_on_round_started):
		GameBus.round_started.disconnect(_on_round_started)
	# AISystem disconnect — is_instance_valid guard per G-11 (battle-scoped Node,
	# may be freed before GridBattleController in edge teardown orders). Source
	# outlives subscriber rule does NOT apply here (both are battle-scoped), so
	# the guard is purely defensive against unusual teardown order.
	if is_instance_valid(_ai_system) \
			and _ai_system.ai_action_ready.is_connected(_on_ai_action_ready):
		_ai_system.ai_action_ready.disconnect(_on_ai_action_ready)


## Handles AISystem.ai_action_ready signal (CONNECT_DEFERRED). Per ADR-0014 §8
## Amendment 2026-05-10 §Handler Dispatch Table — 6-way ActionType match:
##
##   WAIT      → declare_action(WAIT, null) only (no game-state mutation)
##   MOVE      → _do_move → declare_action(MOVE, target)
##   ATTACK    → _resolve_attack → declare_action(ATTACK, target)
##   MOVE_AND_ATTACK → decompose: _do_move → declare_action(MOVE) THEN
##                     _resolve_attack → declare_action(ATTACK)
##   DEFEND    → declare_action(WAIT, null) [DEFEND execution deferred to Skill ADR]
##   USE_SKILL → push_warning + declare_action(WAIT, null) per ADR-0014 §0 MVP scope
##
## DESIGN NOTE: This handler bypasses _handle_move/_handle_attack wrappers because
## both wrappers call _consume_unit_action() which always issues declare_action(ATTACK)
## internally (MVP single-token simplification). AI path needs the correct MOVE/ATTACK
## token split for _maybe_defer_turn_completion predicate in S15-A. Directly calling
## _do_move/_resolve_attack avoids the double declare_action problem. _acted_this_turn
## is set explicitly here to honour the re-entrancy guard that _handle_move/_handle_attack
## check. Per ADR-0014 §8 Amendment 2026-05-10 §Order of Operations.
##
## Guards: _battle_over early-return; unit_id must be in _units; command must be
## non-null. Invalid unit_id or null command → push_warning + return (no dispatch).
func _on_ai_action_ready(unit_id: int, command: AIActionCommand) -> void:
	if _battle_over:
		return
	if command == null:
		push_warning(
			"GridBattleController._on_ai_action_ready: null command for unit_id=%d — skipping dispatch"
			% unit_id
		)
		return
	if not _units.has(unit_id):
		push_warning(
			"GridBattleController._on_ai_action_ready: unit_id=%d not in registry — skipping dispatch"
			% unit_id
		)
		return
	match command.action_type:
		AIActionCommand.ActionType.WAIT:
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
		AIActionCommand.ActionType.MOVE:
			var unit: BattleUnit = _units[unit_id]
			if is_tile_in_move_range(command.move_target, unit_id):
				_do_move(unit, command.move_target)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.MOVE,
				_make_move_target(command.move_target)
			)
			# AI MOVE-only finalizes the turn: WAIT sets turn_state=DONE so
			# _maybe_defer_turn_completion can advance to the next unit. Player
			# MOVE intentionally leaves the turn open for follow-up ATTACK/WAIT;
			# AI commits its full beat in one _on_ai_action_ready dispatch.
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
		AIActionCommand.ActionType.ATTACK:
			if _units.has(command.attack_target_unit_id):
				var attacker: BattleUnit = _units[unit_id]
				var defender: BattleUnit = _units[command.attack_target_unit_id]
				if is_tile_in_attack_range(defender.position, unit_id):
					_resolve_attack(attacker, defender)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.ATTACK,
				_make_attack_target(command.attack_target_unit_id)
			)
		AIActionCommand.ActionType.MOVE_AND_ATTACK:
			# 2-call decomposition: MOVE action first, ATTACK action second.
			# _maybe_defer_turn_completion fires on the ATTACK declare_action call
			# (action_token_spent == true). Per ADR-0014 §8 Amendment §Order of Ops.
			var unit: BattleUnit = _units[unit_id]
			if is_tile_in_move_range(command.move_target, unit_id):
				_do_move(unit, command.move_target)
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.MOVE,
				_make_move_target(command.move_target)
			)
			if _units.has(command.attack_target_unit_id):
				# Re-read unit after potential _do_move position update
				unit = _units[unit_id]
				var defender: BattleUnit = _units[command.attack_target_unit_id]
				if is_tile_in_attack_range(defender.position, unit_id):
					_resolve_attack(unit, defender)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.ATTACK,
				_make_attack_target(command.attack_target_unit_id)
			)
		AIActionCommand.ActionType.DEFEND:
			# DEFEND is a basic action with token-spending semantics per ADR-0011
			# story-004 amendment (sets defend_stance_active on UnitTurnState).
			# Session-13: also bridge into HPStatusController so the 50% damage
			# reduction actually fires on incoming attacks. Without this bridge,
			# DEFEND was a no-op (TurnOrderRunner flag set, but HPStatusController
			# checks for the defend_stance status effect which wasn't applied).
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.DEFEND, null)
			_apply_defend_stance_status(unit_id)
		AIActionCommand.ActionType.USE_SKILL:
			# Session-27 — wire AI USE_SKILL through use_skill(). Closes the
			# ADR-0014 §0 MVP-scope deferral. Most skill handlers internally
			# call declare_action (thunder_roar / piercing_volley / strategist
			# / dragon_blade-after-attack); the utility skills (inspire /
			# charm / naval_strategy) intentionally don't spend the ATK token
			# so the player can chain skill+attack. For AI we only allow one
			# command per turn — declare WAIT if use_skill returned false
			# (unwired skill / already used / etc.) OR if the skill fired
			# but didn't internally declare an action (utility skills).
			var fired: bool = use_skill(unit_id)
			if not _acted_this_turn.get(unit_id, false):
				_acted_this_turn[unit_id] = true
				_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
			if not fired:
				# Diagnostic — distinguishes the "I picked USE_SKILL but
				# couldn't fire it" path from the "I picked it and it fired"
				# path. Common cause: skill_id was empty (no innate skill on
				# this unit) or already used this battle.
				push_warning(
					("GridBattleController: AI USE_SKILL no-fire for unit_id %d "
					+ "(skill_id='%s' skill_used=%s) — declared WAIT instead")
					% [unit_id,
					   String(_units[unit_id].skill_id) if _units.has(unit_id) else "",
					   _units[unit_id].skill_used if _units.has(unit_id) else false]
				)
		_:
			push_warning(
				"GridBattleController._on_ai_action_ready: unknown action_type=%d for unit_id=%d"
				% [command.action_type as int, unit_id]
			)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)


## Constructs an ActionTarget for a MOVE action to target_pos.
## movement_cost is set to 0 (stub per story-007+ refinement candidate).
## Per ADR-0011 §Key Interfaces + ADR-0014 §8 Amendment 2026-05-10.
func _make_move_target(target_pos: Vector2i) -> ActionTarget:
	var t: ActionTarget = ActionTarget.new()
	t.target_position = target_pos
	t.target_unit_id = 0
	t.movement_cost = 0  # story-007+ refinement: populate from terrain cost matrix
	return t


## Constructs an ActionTarget for an ATTACK action targeting target_unit_id.
## target_position is left at Vector2i.ZERO (unit-targeted attack, position derived
## by caller from _units registry as needed).
## Per ADR-0011 §Key Interfaces + ADR-0014 §8 Amendment 2026-05-10.
func _make_attack_target(target_unit_id: int) -> ActionTarget:
	var t: ActionTarget = ActionTarget.new()
	t.target_unit_id = target_unit_id
	t.target_position = Vector2i.ZERO
	t.movement_cost = 0
	return t


# ─── Public API: cross-system contract surface (ADR-0014 §10) ────────────────

## Session-24 — query whether `action_name` is currently available for `unit_id`.
## Used by battle_hud (UI-GB-02) to gray out spent-token action buttons during
## the player's turn. Reads turn_runner state via `get_unit_turn_state`; pure
## read — does not mutate controller or turn_runner state.
##
## action_name is one of: &"move", &"attack", &"use_skill", &"defend",
## &"wait", &"end_turn". Returns false for unknown action names.
##
## Availability rules:
##   - Battle must not be over.
##   - Unit must exist in registry, be alive, player-controlled, AND be the
##     current active turn unit. AI turns gate all buttons to disabled.
##   - turn_state must not be DONE (e.g., WAIT already declared).
##   - "move"   → !move_token_spent && !defend_stance_active (CR-4c lock)
##   - "attack" / "use_skill" / "defend" → !action_token_spent
##   - "wait" / "end_turn" → always true when the unit-level guards pass
func is_action_available(unit_id: int, action_name: StringName) -> bool:
	if _battle_over:
		return false
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	if not unit.is_player_controlled:
		return false
	if _hp_controller != null and not _hp_controller.is_alive(unit_id):
		return false
	if unit_id != _active_turn_unit_id:
		return false
	if _turn_runner == null:
		return false
	var state: UnitTurnState = _turn_runner.get_unit_turn_state(unit_id)
	if state == null:
		return false
	if state.turn_state == TurnOrderRunner.TurnState.DONE:
		return false
	match action_name:
		&"move":
			return not state.move_token_spent and not state.defend_stance_active
		&"attack":
			return not state.action_token_spent
		&"use_skill":
			return not state.action_token_spent
		&"defend":
			return not state.action_token_spent
		&"wait":
			return true
		&"end_turn":
			return true
		_:
			return false


## Checks whether a tile is in the given unit's movement range. Implements
## input-handling §9 Bidirectional Contract (R-5) + grid-battle.md §612 + §123.
##
## MVP simplification per ADR-0014 §0 + story-004 Implementation Note #1:
## Manhattan distance check (no BFS pathfinding). Future Pathfinding ADR will
## refine to "reachable path exists" via Dijkstra against terrain cost matrix
## per UnitRole.get_class_cost_table; this method's interface stays stable.
##
## Returns false if: unit_id not in registry, tile out of unit's move_range,
## tile occupied by another unit, OR tile not passable (RIVER / MOUNTAIN per
## MapTileData.is_passable_base — set at MapResource load by ADR-0008 contract).
func is_tile_in_move_range(tile: Vector2i, unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	# Manhattan distance check (MVP per AC-2)
	var dx: int = absi(tile.x - unit.position.x)
	var dy: int = absi(tile.y - unit.position.y)
	var manhattan: int = dx + dy
	if manhattan == 0 or manhattan > unit.move_range:
		return false  # zero-distance (current tile) or out-of-range
	# Passability + occupancy via MapGrid.get_tile (single source of truth)
	var tile_data: MapTileData = _map_grid.get_tile(tile)
	if tile_data == null:
		return false  # out of bounds (defensive — get_tile may return null at edges)
	if not tile_data.is_passable_base:
		return false  # RIVER / MOUNTAIN / impassable terrain
	# Use tile_state (not occupant_id) — occupant_id is the unit_id which is 0
	# for the commander (unit 0), making that tile spuriously read as empty.
	if tile_data.tile_state == MapGrid.TILE_STATE_ALLY_OCCUPIED \
			or tile_data.tile_state == MapGrid.TILE_STATE_ENEMY_OCCUPIED:
		return false  # tile occupied by some unit
	return true


## Checks whether a tile is a valid attack target for the given unit. Implements
## input-handling §9 Bidirectional Contract (R-5) + grid-battle.md §612 + §198.
##
## Per ADR-0014 §10 + story-005 AC-1: tile must contain an ENEMY unit (different
## side) AND be within attacker's attack_range (Manhattan distance; 1 for melee,
## 2 for 황충 ranged_specialist). MVP simplification — no line-of-sight or
## terrain modifiers.
func is_tile_in_attack_range(tile: Vector2i, unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	var attacker: BattleUnit = _units[unit_id]
	# Manhattan distance check
	var dx: int = absi(tile.x - attacker.position.x)
	var dy: int = absi(tile.y - attacker.position.y)
	var manhattan: int = dx + dy
	if manhattan == 0 or manhattan > attacker.attack_range:
		return false
	# Tile must contain an enemy unit (different side) per AC-1
	for defender: BattleUnit in _units.values():
		if defender.position == tile and defender.side != attacker.side:
			return true
	return false


## Enumerates the set of tiles the unit can legally move to. Reuses
## is_tile_in_move_range as the single source of truth for movement validation,
## so the preview cannot drift from the click-time check. Scans the Manhattan
## diamond bounded by unit.move_range (≤ 5 typically, so worst-case 60 checks).
## Origin tile is excluded (manhattan == 0 returns false in is_tile_in_move_range).
func get_movable_tiles(unit_id: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if not _units.has(unit_id):
		return result
	var unit: BattleUnit = _units[unit_id]
	for dx: int in range(-unit.move_range, unit.move_range + 1):
		for dy: int in range(-unit.move_range, unit.move_range + 1):
			if absi(dx) + absi(dy) > unit.move_range:
				continue
			var coord: Vector2i = unit.position + Vector2i(dx, dy)
			if is_tile_in_move_range(coord, unit_id):
				result.append(Vector2(coord))
	return result


## Enumerates the set of tiles the unit can legally attack. Reuses
## is_tile_in_attack_range as the single source of truth, so the preview
## cannot drift from the click-time check. Scans the Manhattan diamond
## bounded by unit.attack_range (≤ 2 for MVP, worst-case 12 checks).
func get_attackable_tiles(unit_id: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if not _units.has(unit_id):
		return result
	var unit: BattleUnit = _units[unit_id]
	for dx: int in range(-unit.attack_range, unit.attack_range + 1):
		for dy: int in range(-unit.attack_range, unit.attack_range + 1):
			if absi(dx) + absi(dy) > unit.attack_range:
				continue
			var coord: Vector2i = unit.position + Vector2i(dx, dy)
			if is_tile_in_attack_range(coord, unit_id):
				result.append(Vector2(coord))
	return result


## Subset of get_attackable_tiles() where the AMBUSH conditions are met (session-15
## verb-feedback): SCOUT/ARCHER + passive_ambush + round >= 2 + defender not acted.
## Used by ChapterVisuals to overlay a distinct color on ambush-window targets so
## the player can see "this is the strike that gets +15% and no counter" without
## opening the forecast. Reuses _is_ambush_active so visuals cannot drift from
## the actual damage gate.
func get_ambush_eligible_target_tiles(unit_id: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if not _units.has(unit_id):
		return result
	var attacker: BattleUnit = _units[unit_id]
	if attacker.passive != &"passive_ambush":
		return result
	for tile: Vector2 in get_attackable_tiles(unit_id):
		var coord: Vector2i = Vector2i(int(tile.x), int(tile.y))
		var defender_id: int = _occupant_at(coord)
		if defender_id == -1 or not _units.has(defender_id):
			continue
		var defender: BattleUnit = _units[defender_id]
		if defender.side == attacker.side:
			continue
		if _is_ambush_active(attacker, defender):
			result.append(tile)
	return result


## True when the unit's next attack will receive the CHARGE +20% bonus
## (session-15 verb-feedback). Mirrors the gate DamageCalc uses: CAVALRY class,
## passive_charge carried, accumulated_move_cost >= CHARGE_THRESHOLD (queried
## via the turn runner). Used by ChapterVisuals to draw a halo on the selected
## unit's tile so the player knows "attack now to cash in the rush".
func is_charge_ready(unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	if unit.unit_class != int(UnitRole.UnitClass.CAVALRY):
		return false
	if unit.passive != &"passive_charge":
		return false
	if _turn_runner == null or not _turn_runner.has_method("is_unit_charge_eligible"):
		return false
	return _turn_runner.is_unit_charge_eligible(unit_id)


## True when the unit's next attack will receive the HIGH GROUND +15% bonus
## (session-15). Mirrors the gate DamageCalc uses: ARCHER class,
## passive_high_ground_shot carried, currently standing on HILLS terrain
## (terrain_type == 2). Used by ChapterVisuals to draw a forest-green halo
## on the attacker's tile so the player knows "you're elevated — shoot now".
func is_high_ground_ready(unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	if unit.unit_class != int(UnitRole.UnitClass.ARCHER):
		return false
	if unit.passive != &"passive_high_ground_shot":
		return false
	return _is_unit_on_high_ground(unit)


## Returns true when the unit is standing on HILLS terrain (terrain_type=2 per
## TerrainCost.HILLS / MapGrid). Defensive: returns false if MapGrid is null
## (test rigs that don't wire one) or the lookup misses. Session-15.
func _is_unit_on_high_ground(unit: BattleUnit) -> bool:
	if _map_grid == null:
		return false
	var tile: MapTileData = _map_grid.get_tile(unit.position)
	if tile == null:
		return false
	return tile.terrain_type == TerrainCost.HILLS


## Returns the unit_id occupying the given coord, or -1 if vacant. Used by
## get_ambush_eligible_target_tiles to map attackable tiles → defender BattleUnit
## without re-scanning _units for every tile.
func _occupant_at(coord: Vector2i) -> int:
	for u: BattleUnit in _units.values():
		if u.position == coord:
			return u.unit_id
	return -1


## Returns the currently selected unit_id, or -1 if no unit is selected.
func get_selected_unit_id() -> int:
	return _selected_unit_id


## get_battle_unit() — cross-epic forward-prep (battle-hud story-003).
## Returns the BattleUnit for the given unit_id, or null if not found.
## Added to support BattleHUD.show_unit_info() hero_id resolution path.
## Read-only query per ADR-0014 §3 contract.
func get_battle_unit(unit_id: int) -> BattleUnit:
	return _units.get(unit_id)


## Session-16 — convenience accessor for view layer (AttackLine class-aware
## render switch). Returns UnitRole.UnitClass int (0..5) or -1 if not found.
func get_unit_class(unit_id: int) -> int:
	if not _units.has(unit_id):
		return -1
	var unit: BattleUnit = _units[unit_id]
	return unit.unit_class


## TerrainEffect terrain_type → UnitRole.terrain_cost_table index mapping.
## Mirrors TerrainEffect._UNIT_ROLE_TERRAIN_IDX (private). RIVER (4) and
## FORTRESS_WALL (6) intentionally absent — impassable, never on movable list.
## Sync target if TerrainEffect mapping changes.
const _TERRAIN_TYPE_TO_ROLE_IDX: Dictionary = {
	0: 1,  # PLAINS
	1: 3,  # FOREST
	2: 2,  # HILLS
	3: 4,  # MOUNTAIN
	5: 5,  # BRIDGE
	7: 0,  # ROAD
}


## Returns a ternary favor signal for one (unit, tile) pair: -1 disadvantage /
## 0 neutral / +1 advantage. Used by ChapterVisuals to tint movement-range
## preview tiles so the player sees "which terrain helps this unit" at the
## moment they're deciding where to move (영걸전식 결정-모먼트 hint).
##
## Inputs:
##   cost = UnitRole.get_class_cost_table(unit_class)[ur_idx]  (float)
##   surv = defense_bonus + evasion_bonus  (TerrainModifiers)
## Rule (movement penalty dominates):
##   cost >= 2.0                          → -1 (significant mobility loss)
##   cost < 1.0 OR (cost <= 1.0 AND surv >= 15) → +1 (fast OR survivable)
##   else                                 → 0
##
## Returns 0 defensively on null grid, missing unit, OOB tile, or impassable
## terrain (RIVER/FORTRESS_WALL) — those tiles never appear on the movable
## preview list anyway, so the value is only consulted for legal moves.
func get_terrain_favor_for_unit(unit_id: int, coord: Vector2i) -> int:
	if not _units.has(unit_id) or _map_grid == null:
		return 0
	var tile: MapTileData = _map_grid.get_tile(coord)
	if tile == null:
		return 0
	if not _TERRAIN_TYPE_TO_ROLE_IDX.has(tile.terrain_type):
		return 0  # impassable; not expected on movable preview list
	var ur_idx: int = _TERRAIN_TYPE_TO_ROLE_IDX[tile.terrain_type] as int
	var unit: BattleUnit = _units[unit_id]
	var cost_row: PackedFloat32Array = UnitRole.get_class_cost_table(
		unit.unit_class as UnitRole.UnitClass
	)
	var cost: float = cost_row[ur_idx]
	var mods: TerrainModifiers = TerrainEffect.get_terrain_modifiers(_map_grid, coord)
	var surv: int = mods.defense_bonus + mods.evasion_bonus
	if cost >= 2.0:
		return -1
	if cost < 1.0 or (cost <= 1.0 and surv >= 15):
		return 1
	return 0


## Convenience batch query: returns a parallel PackedInt32Array of favor values
## for every tile in [param tiles]. Index-aligned with [param tiles] so callers
## can iterate both arrays in lockstep when rendering the movable preview.
## Used by BattleScene._on_unit_selected_changed to push the favor map to
## ChapterVisuals alongside set_movable_tiles().
func get_movable_favors(unit_id: int, tiles: PackedVector2Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(tiles.size())
	for i: int in tiles.size():
		var t: Vector2 = tiles[i]
		result[i] = get_terrain_favor_for_unit(unit_id, Vector2i(int(t.x), int(t.y)))
	return result


## Returns the unit_id of the unit whose turn is currently ACTING. -1 if no
## unit is active (between turns, before battle start, after resolution).
## Used by view-layer code (battle_scene) to track the active-turn highlight
## through slides without having to subscribe to active_unit_changed separately.
func get_active_turn_unit_id() -> int:
	return _active_turn_unit_id


## Returns a player-side stats summary for the UI-GB-09 result panel
## (session-15 commit 4). Categorical aggregates only — NO fate counter values
## are exposed (Pillar 2 lock per ADR-0015 §8). Shape:
##   {
##     "total_player_damage": int,      # sum of all player-attacker damage_applied
##     "mvp_unit_id": int,              # player unit with max damage (-1 if none)
##     "mvp_hero_id": StringName,       # convenience for display (&"" if none)
##     "mvp_damage": int,               # damage dealt by the MVP (0 if none)
##     "player_kills": int,             # sum of player-side kills (no friendly-fire)
##     "surviving_player_count": int,   # alive player units at time of call
##     "total_player_count": int,       # initial player roster size
##     "star_rating": int,              # 0 (loss/draw) / 1 / 2 / 3 — see _compute_star_rating
##     "outcome_was_win": bool,         # true iff _battle_over AND last outcome was VICTORY
##   }
## Idempotent / side-effect-free. Safe to call before / after / during battle.
func get_battle_stats() -> Dictionary:
	var total_damage: int = 0
	var mvp_id: int = -1
	var mvp_damage: int = 0
	var mvp_hero_id: StringName = &""
	for uid: int in _damage_dealt_by_unit:
		if not _units.has(uid):
			continue
		if _units[uid].side != 0:
			continue  # player-side only for the result-panel MVP
		var dmg: int = _damage_dealt_by_unit[uid]
		total_damage += dmg
		if dmg > mvp_damage:
			mvp_damage = dmg
			mvp_id = uid
			mvp_hero_id = _units[uid].hero_id
	var kills: int = 0
	for uid: int in _kills_by_unit:
		if _units.has(uid) and _units[uid].side == 0:
			kills += _kills_by_unit[uid]
	var surviving: int = 0
	var total: int = 0
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue
		total += 1
		if _hp_controller != null and _hp_controller.is_alive(unit.unit_id):
			surviving += 1
	var rating: int = _compute_star_rating(surviving, total)
	return {
		"total_player_damage": total_damage,
		"mvp_unit_id": mvp_id,
		"mvp_hero_id": mvp_hero_id,
		"mvp_damage": mvp_damage,
		"player_kills": kills,
		"surviving_player_count": surviving,
		"total_player_count": total,
		"star_rating": rating,
		"outcome_was_win": _battle_over and (_last_outcome == &"VICTORY_ANNIHILATION" or _last_outcome == &"VICTORY_SURVIVE" or _last_outcome == &"VICTORY_ESCORT" or _last_outcome == &"VICTORY_REACH_TILE"),
	}


## Star rating curve for the result panel (session-15 commit 4):
##   3★ : Victory + clean run (no losses) + fast (≤ 8 rounds)
##   2★ : Victory + (no losses OR fast)
##   1★ : Victory at any cost
##   0★ : Defeat / draw / mid-battle
## Generous on the 2★ threshold so most wins reward at least 2 stars —
## chasing 3★ is the replay incentive, surviving is the baseline.
func _compute_star_rating(surviving: int, total: int) -> int:
	if not _battle_over:
		return 0
	if _last_outcome != &"VICTORY_ANNIHILATION" and _last_outcome != &"VICTORY_SURVIVE" and _last_outcome != &"VICTORY_ESCORT" and _last_outcome != &"VICTORY_REACH_TILE":
		return 0
	var round_count: int = 0
	if _turn_runner != null and _turn_runner.has_method("get_current_round_number"):
		round_count = _turn_runner.get_current_round_number()
	var all_alive: bool = (surviving == total and total > 0)
	var fast: bool = round_count > 0 and round_count <= 8
	if all_alive and fast:
		return 3
	if all_alive or fast:
		return 2
	return 1


## Returns an opaque snapshot of battle state for AI consumer (Battle AI ADR).
## Shape is intentionally unspecified at MVP; callers must not rely on field names.
func get_battle_state_snapshot() -> Dictionary:
	# TODO (Battle AI ADR — not yet written; sprint-7+): populate FSM state, unit
	# positions, acted flags. Shape locked at ADR authoring time per ADR-0014 §10
	# Key Interfaces (opaque shape) + ADR-0014 line 598.
	return {}


## Per ADR-0014 §Amendment 2026-05-10 (#2 — player-path mirror).
## Player explicitly ends turn (`end_unit_turn` action). For each player-side
## alive unit that has NOT acted, declare WAIT to release the T5 await per
## S15-A `_maybe_defer_turn_completion` (action_token_spent == true).
## Preserves existing end_player_turn() side effects (deselect + auto-handoff).
func _handle_player_end_turn() -> void:
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue  # player-side only
		if not _hp_controller.is_alive(unit.unit_id):
			continue  # dead units don't WAIT
		if _acted_this_turn.get(unit.unit_id, false):
			continue  # already declared an action this turn
		_acted_this_turn[unit.unit_id] = true
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.WAIT, null)
	end_player_turn()


## Ends the player turn early. Also auto-called from _consume_unit_action when
## all alive player units have acted (AC-4 auto-handoff). Per ADR-0014 §6 +
## story-006 AC-5: clears _acted_this_turn for the next round + deselects.
##
## DEVIATION from ADR-0014 §6 sketch + AC-5 wording "_turn_runner.end_player_turn()":
## the shipped TurnOrderRunner has NO `end_player_turn()` method (drift #10 — see
## Implementation Notes amendment). Round advance is signal-driven via
## GameBus.round_started → _on_round_started; this method is controller-side
## bookkeeping ONLY. Full Battle Scene wiring (sprint-6+) will replace this with
## a synchronous Callable injection per ADR-0011 §Decision Contract 5.
func end_player_turn() -> void:
	_acted_this_turn.clear()
	_moved_this_turn.clear()
	_move_undo_cache.clear()  # S52 — undo only valid within the current turn
	if _selected_unit_id != -1:
		_deselect()


## Direct-callable entry point for grid click dispatch (also called by signal handler).
## Exposed as public so integration tests can drive it without emitting GameBus signals.
## Per ADR-0014 §4 + story-003 AC-5: 2-state FSM dispatch via match _state.
##
## Story-007 AC-7: terminal-state guard — once `_battle_over == true`, all click
## input is silently ignored (prevents post-resolution interaction).
##
## NOTE: action parameter type is `String` (not StringName per ADR-0014 §10 sketch)
## to match shipped GameBus.input_action_fired signal signature (String per ADR-0001
## line 168 + ADR-0001 amendment advisory delta #6 Item 10a still pending).
func handle_grid_click(action: String, coord: Vector2i, unit_id: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard — no input handling after outcome resolved
	match _state:
		BattleState.OBSERVATION:
			_handle_grid_click_observation(action, coord, unit_id)
		BattleState.UNIT_SELECTED:
			_handle_grid_click_unit_selected(action, coord, unit_id)


# ─── Signal handlers (stubs — logic in stories 003-008) ─────────────────────

## Subscribed to GameBus.input_action_fired via CONNECT_DEFERRED in _ready().
## Per ADR-0014 §4 + story-003 AC-3, AC-4, AC-6:
##   1. Filter via _is_grid_action(action) — non-grid actions silently ignored
##   2. Resolve coord from ctx.target_coord; fallback to camera.screen_to_grid()
##      if ctx.target_coord == Vector2i.ZERO (sentinel from InputRouter when
##      raw event couldn't resolve)
##   3. Off-grid sentinel Vector2i(-1, -1) → silent return
##   4. Dispatch to handle_grid_click with the resolved coord + ctx.target_unit_id
func _on_input_action_fired(action: String, ctx: InputContext) -> void:
	if not _is_grid_action(action):
		return
	# Session-13: defend_stance is keyboard-driven and unit-scoped (acts on the
	# currently-selected unit). It does NOT need a grid coord — bypass the
	# coord-resolution path so D key works regardless of mouse position.
	if action == "defend_stance":
		_handle_defend_stance_input()
		return
	# Session-15: use_skill mirrors defend_stance — S key, unit-scoped, no
	# coordinate required. Fires the selected player unit's innate skill once
	# per battle. Routes through use_skill() which gates on skill_used + side.
	if action == "use_skill":
		_handle_use_skill_input()
		return
	# S90 Phase B: use_item mirrors use_skill — I/3 key, unit-scoped, no
	# coordinate required. Uses slot 0 of the selected unit's inventory (MVP
	# default; future Phase C+ adds slot-selection UI via numeric keys 1/2/3).
	if action == "use_item":
		_handle_use_item_input()
		return
	var coord: Vector2i = ctx.target_coord
	if coord == Vector2i.ZERO and _camera != null:
		# Camera fallback per ADR-0014 §4 — re-resolve via viewport mouse position.
		coord = _camera.screen_to_grid(get_viewport().get_mouse_position())
	if coord == Vector2i(-1, -1):
		return  # off-grid sentinel from BattleCamera.screen_to_grid
	# Eyeball trace — kept lean enough to leave on; helps the user diagnose
	# why a click did or didn't do what they expected.
	_trace("[CLICK] action=%s coord=%s unit_id=%d state=%d active=%d selected=%d" %
		[action, str(coord), ctx.target_unit_id, int(_state),
		_active_turn_unit_id, _selected_unit_id])
	handle_grid_click(action, coord, ctx.target_unit_id)


func _on_unit_died(unit_id: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard — no further outcome processing
	# ADR-0022 Civilian System — ESCORTED token bound to the dead unit returns
	# to IDLE at the death cell. Short-circuits when civilian system inactive.
	_civilian_recover_on_carrier_death(unit_id)
	# ch10 ★ Plan §4.3 mechanical lock per design/quick-specs/ch10-chibi-perfect-wind.md
	# — player-side casualty counter (side==0 filter; enemy deaths不 increment).
	# Counted BEFORE unit_visual_died so the fate_data emit at battle resolution
	# reflects the up-to-date count regardless of when the resolution check runs.
	if _units.has(unit_id) and (_units[unit_id] as BattleUnit).side == 0:
		_fate_player_casualties += 1
		hidden_fate_condition_progressed.emit(&"player_casualties", _fate_player_casualties)
	# Re-emit as a controller-scoped signal for scene-tier visual handlers
	# (BattleScene polygon hide). Fires before _check_battle_end so the visual
	# update lands even if this death resolves the battle.
	unit_visual_died.emit(unit_id)
	# Story-008 AC-5: boss-killed flag (idempotent — only first kill flips it).
	if unit_id == _fate_boss_unit_id and not _fate_boss_killed:
		_fate_boss_killed = true
		hidden_fate_condition_progressed.emit(&"boss_killed", 1)
	# Story-008 AC-4: assassin-kill attribution. Last attacker is set by
	# _resolve_attack pre-apply_damage; CONNECT_DEFERRED guarantees it's
	# already populated by the time this handler fires. Defender must be
	# enemy (side==1) — friendly-fire kills don't count.
	if _last_attacker_id == _fate_assassin_unit_id and _fate_assassin_unit_id != -1:
		if _units.has(unit_id) and _units[unit_id].side == 1:
			_fate_assassin_kills += 1
			hidden_fate_condition_progressed.emit(&"assassin_kills", _fate_assassin_kills)
	# Phase F — huang_zhong_xiahou_yuan_kill (ch19 정군산 노장 결전 시그니처).
	# Bool 1 iff 황충 (shu_004_huang_zhong) directly killed 하후돈 (wei_005_xiahou_dun).
	# Hero_id matching is chapter-agnostic — works in any chapter where both heroes
	# happen to be on opposite sides (ch19 is the only one as authored).
	if _fate_huang_zhong_xiahou_yuan_kill == 0 \
			and _last_attacker_id != -1 \
			and _units.has(_last_attacker_id) and _units.has(unit_id):
		var k: BattleUnit = _units[_last_attacker_id]
		var v: BattleUnit = _units[unit_id]
		if k.hero_id == &"shu_004_huang_zhong" and v.hero_id == &"wei_005_xiahou_dun":
			_fate_huang_zhong_xiahou_yuan_kill = 1
			hidden_fate_condition_progressed.emit(&"huang_zhong_xiahou_yuan_kill", 1)
	# Session-15 commit 4: kill credit for the result-screen aggregate. Credit
	# the LAST ATTACKER only when victim is on the opposite side (no friendly-fire
	# credit). Side-agnostic — both player and enemy "kills" are tracked but only
	# the player aggregate surfaces in the UI; symmetric tracking lets future
	# enemy-MVP / lose-screen reuse the same dict.
	if _last_attacker_id != -1 and _units.has(_last_attacker_id) and _units.has(unit_id):
		var killer: BattleUnit = _units[_last_attacker_id]
		var victim: BattleUnit = _units[unit_id]
		if killer.side != victim.side:
			_kills_by_unit[_last_attacker_id] = _kills_by_unit.get(_last_attacker_id, 0) + 1
			# Session-16: mid-battle kill notification. View layer spawns the
			# "X 처치!" popup at the victim's polygon position. Emitted BEFORE
			# _check_battle_end so the popup fires even on the final kill —
			# the result screen takes over after the outcome resolves.
			unit_killed.emit(_last_attacker_id, unit_id, victim.hero_id)
	# Story-007 AC-5: victory check on every unit death.
	_check_battle_end()


func _on_unit_turn_started(unit_id: int) -> void:
	# Per ADR-0019 + grid-battle.md CR-3: AI-turn detection + ai_action_requested emission.
	# When the active turn unit is non-player-controlled, emit ai_action_requested
	# so that AISystem (battle-scoped Node 6th invocation) can produce an action.
	if _battle_over:
		return
	if not _units.has(unit_id):
		return
	var unit: BattleUnit = _units[unit_id]
	if unit == null:
		return
	# Track the active turn unit so click handlers can reject input on other own
	# units (only the active unit may move/attack on a given turn).
	_active_turn_unit_id = unit_id
	_trace("[TURN] active unit changed to %d (side=%d, player=%s)" %
		[unit_id, unit.side, unit.is_player_controlled])
	# Auto-deselect a stale selection if the new active unit differs — keeps
	# the gold-outline + range overlays on the unit the player can actually move.
	if _selected_unit_id != -1 and _selected_unit_id != unit_id:
		_deselect()
	# View-layer hook for the turn indicator. Fires for BOTH player and AI turns
	# so the on-grid cue tracks every active unit, not just AI dispatch entries.
	active_unit_changed.emit(unit_id)
	# AI dispatch happens via TurnOrderRunner T5 _action_controller →
	# _on_turn_runner_action_request (NATURAL-LOOP path per S15-J amendment).
	# Pre-S15-J emit removed here to prevent ai_action_requested dup-fire.


## Builds a flat-data BattleStateSnapshot from the current battle state.
## Called by `_on_unit_turn_started` for AI-turn entries. Read-only — does not
## mutate _units, _map_grid, _hp_controller, or _turn_runner. Per ADR-0019
## §Decision §Payload Form.
func _make_battle_state_snapshot() -> BattleStateSnapshot:
	var snap: BattleStateSnapshot = BattleStateSnapshot.new()
	# Per-unit data.
	for u: BattleUnit in _units.values():
		var hp_curr: int = _hp_controller.get_current_hp(u.unit_id) if _hp_controller != null else 0
		var hp_mx: int = _hp_controller.get_max_hp(u.unit_id) if _hp_controller != null else 1
		var alive: bool = _hp_controller.is_alive(u.unit_id) if _hp_controller != null else true
		# Session-18 — surface active status effect ids for AI status awareness
		# (e.g., aggressor avoids dying-poisoned targets; coordinator focus-fires
		# slowed ones). Pure read; doesn't mutate HP controller state.
		var status_ids: Array[StringName] = []
		if _hp_controller != null and _hp_controller.has_method("get_status_effects"):
			var effects: Array = _hp_controller.get_status_effects(u.unit_id) as Array
			for effect in effects:
				if effect != null and effect is StatusEffect:
					status_ids.append((effect as StatusEffect).effect_id)
		snap.units.append({
			"unit_id": u.unit_id,
			# S13-12: read from BattleUnit.archetype field directly. Prior code
			# read u.tag as the archetype source, which conflated the fate-counter
			# role (`tank`/`assassin`/`boss`) with the AI archetype dispatch bucket
			# (`aggressor`/`skirmisher`/`holder`/`coordinator`). When a chapter has a
			# coordinator-archetyped unit mapped to tag=`boss` for fate tracking,
			# the conflated read leaked `boss` into AISystem and fell through to
			# the EC-AI-4 unknown-archetype warning path (×4+ per battle).
			"archetype": u.archetype,
			"position": u.position,
			"hp_current": hp_curr,
			"hp_max": hp_mx,
			"atk": u.raw_atk,
			"def": u.raw_def,
			"move_range": u.move_range,
			"attack_range": u.attack_range,
			"side": u.side,
			"is_player_controlled": u.is_player_controlled,
			"passive_id": &"",
			"tag": u.tag,
			"is_alive": alive,
			"status_ids": status_ids,
			# Session-27 — surface skill_id + skill_used so AI can score
			# USE_SKILL candidates against the unit's actual innate skill
			# (was hardcoded rally before; the rally placeholder had no
			# wired handler, so no USE_SKILL ever actually fired). Gating
			# the candidate by !skill_used keeps the AI from re-picking
			# an exhausted skill mid-battle.
			"skill_id": u.skill_id,
			"skill_used": u.skill_used,
		})
	# Map dimensions + terrain grid.
	if _map_grid != null:
		var dims: Vector2i = _map_grid.get_map_dimensions()
		snap.map_dimensions = dims
		# Build flat row-major terrain grid for snapshot consumers.
		var grid: PackedInt32Array = PackedInt32Array()
		for row in range(dims.y):
			for col in range(dims.x):
				var tile: MapTileData = _map_grid.get_tile(Vector2i(col, row))
				grid.append(tile.terrain_type if tile != null else 0)
		snap.terrain_grid = grid
	# Round number.
	snap.round_number = _turn_runner.get_current_round_number() if _turn_runner != null else 0
	# Turn queue (best effort; empty if API not available).
	snap.queue_unit_ids = []
	# Chokepoints sourced from ChapterDefinition via set_chokepoints() at chapter-load
	# (S7-05); formation_center = centroid of allied (enemy-side) units' positions.
	snap.chokepoints = _chokepoints.duplicate()
	var enemy_positions: Array[Vector2i] = []
	for u: BattleUnit in _units.values():
		if u.side == 1:
			enemy_positions.append(u.position)
	if not enemy_positions.is_empty():
		var sum: Vector2i = Vector2i.ZERO
		for p: Vector2i in enemy_positions:
			sum += p
		snap.formation_center = Vector2i(sum.x / enemy_positions.size(), sum.y / enemy_positions.size())
	return snap


## Sets chokepoint coords for AISystem holder-archetype scoring. Called by
## BattleScene after ScenarioRunner hydrates the active ChapterDefinition.
## Pure setter — does not emit signals or trigger snapshot rebuilds.
func set_chokepoints(chokepoints: Array[Vector2i]) -> void:
	_chokepoints = chokepoints.duplicate()


## ADR-0022 — DI surface for ChapterDefinition.civilian_config. Called by
## BattleScene at chapter init adjacent to set_chokepoints. Empty Dictionary =
## no civilian system active for this chapter (default for ch01-ch04, ch06-ch16,
## Wei ch01-ch05, mvp_wei chapters). Idempotent: re-calling with the same config
## yields an identical token collection (token_id assigned sequentially 0..N-1).
func set_civilian_config(config: Dictionary) -> void:
	_civilian_tokens.clear()
	_civilian_evacuate_zone_max_col = -1
	if config.is_empty():
		return
	_civilian_evacuate_zone_max_col = int(config.get("evacuate_zone_max_col", -1))
	var positions: Array = config.get("positions", []) as Array
	for i in range(positions.size()):
		var pos_var: Variant = positions[i]
		if not (pos_var is Array) or (pos_var as Array).size() < 2:
			continue
		var pos_arr: Array = pos_var as Array
		var cell: Vector2i = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
		_civilian_tokens.append(CivilianToken.make(i, cell))


## Read-only snapshot of the civilian token collection. Returned array is a
## duplicate (mutation does not affect controller state). Used by tests and
## (future) visualization layer for per-redraw token state polling.
func get_civilian_tokens() -> Array[CivilianToken]:
	var out: Array[CivilianToken] = []
	out.assign(_civilian_tokens)
	return out


## ADR-0022 §4 forbidden_pattern `civilian_escorted_counter_direct_mutation` —
## this method is the SOLE mutator of `_fate_civilians_escorted`. Lint-enforced.
## Called by `_civilian_check_save_for_unit` upon SAVED-transition; do NOT call
## from elsewhere.
func _civilian_commit_save(token_id: int) -> void:
	_fate_civilians_escorted += 1
	hidden_fate_condition_progressed.emit(&"civilians_escorted", _fate_civilians_escorted)


## Pickup adjacency check at player turn-end (called from _on_unit_turn_ended).
## 8-neighbor scan for IDLE token; first found (token_id ascending) → ESCORTED
## bind. Capacity 1/carrier (skip if carrier already has ESCORTED token).
func _civilian_check_pickup_for_unit(player_unit_id: int) -> void:
	if _civilian_evacuate_zone_max_col < 0:
		return
	if not _units.has(player_unit_id):
		return
	var unit: BattleUnit = _units[player_unit_id]
	if unit.side != 0:
		return
	# Capacity 1/carrier — skip if already escorting
	for t: CivilianToken in _civilian_tokens:
		if t.state == CivilianToken.State.ESCORTED and t.carrier_unit_id == player_unit_id:
			return
	var unit_cell: Vector2i = unit.position
	for t: CivilianToken in _civilian_tokens:
		if t.state != CivilianToken.State.IDLE:
			continue
		var dx: int = absi(t.grid_cell.x - unit_cell.x)
		var dy: int = absi(t.grid_cell.y - unit_cell.y)
		if dx <= 1 and dy <= 1 and not (dx == 0 and dy == 0):
			t.bind_to_carrier(player_unit_id)
			return


## Save-zone check at player turn-end (called from _on_unit_turn_ended). If
## carrier ends turn at col <= evacuate_zone_max_col with an ESCORTED token,
## token transitions to SAVED + counter +1 via _civilian_commit_save.
func _civilian_check_save_for_unit(carrier_unit_id: int) -> void:
	if _civilian_evacuate_zone_max_col < 0:
		return
	if not _units.has(carrier_unit_id):
		return
	var unit: BattleUnit = _units[carrier_unit_id]
	if unit.side != 0:
		return
	if unit.position.x > _civilian_evacuate_zone_max_col:
		return
	for t: CivilianToken in _civilian_tokens:
		if t.state != CivilianToken.State.ESCORTED:
			continue
		if t.carrier_unit_id != carrier_unit_id:
			continue
		t.commit_save()
		_civilian_commit_save(t.token_id)
		return


## Carrier-death recovery — called from _on_unit_died. ESCORTED token bound to
## the dead unit transitions to IDLE at the carrier's last position (their death
## cell). Per ADR-0022 R-1, fallback to non-occupied non-FIRE 4-neighbor is
## deferred to next session — first-arc impl uses death cell directly.
func _civilian_recover_on_carrier_death(dead_unit_id: int) -> void:
	if _civilian_evacuate_zone_max_col < 0:
		return
	var recovery_cell: Vector2i = Vector2i.ZERO
	if _units.has(dead_unit_id):
		recovery_cell = _units[dead_unit_id].position
	for t: CivilianToken in _civilian_tokens:
		if t.state != CivilianToken.State.ESCORTED:
			continue
		if t.carrier_unit_id != dead_unit_id:
			continue
		t.recover_to_idle(recovery_cell)


## Session-28 — sets per-chapter victory_conditions. Called by BattleScene
## after ScenarioRunner hydrates the active ChapterDefinition. Null is
## valid (chapter omitted the resource entirely) and falls through to the
## default ANNIHILATION-only dispatcher path. Pure setter — does not
## emit signals or trigger snapshot rebuilds.
func set_victory_conditions(vc: VictoryConditions) -> void:
	_victory_conditions = vc


## Subscribed to GameBus.unit_turn_ended via CONNECT_DEFERRED in _ready().
## Pure view-layer re-emit so BattleScene can dim the polygon of any unit that
## actually spent a token this turn. _battle_over gate suppresses post-resolve
## dim flicker; subscribers should treat acted=false as a no-op cue.
func _on_unit_turn_ended(unit_id: int, acted: bool) -> void:
	if _battle_over:
		return
	# ADR-0022 Civilian System hooks — save check first (carrier ending turn in
	# evacuate-zone commits the SAVED), then pickup (idle token in 8-neighbor).
	# Both short-circuit when _civilian_evacuate_zone_max_col == -1.
	_civilian_check_save_for_unit(unit_id)
	_civilian_check_pickup_for_unit(unit_id)
	unit_turn_ended_visual.emit(unit_id, acted)


## Subscribed to GameBus.round_started via CONNECT_DEFERRED in _ready().
## Per ADR-0014 §7 + story-007 AC-3: when round_num exceeds _max_turns, emit
## battle_outcome_resolved with TURN_LIMIT_REACHED outcome. _max_turns is
## loaded from BalanceConstants(MAX_TURNS_PER_BATTLE)=5 in _ready().
func _on_round_started(round_num: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard
	# Session-28 — SURVIVE_N_ROUNDS check. round_num > survive_rounds means
	# the player has endured `survive_rounds` full rounds — emit VICTORY now,
	# BEFORE this new round runs its turn order (so the player's units don't
	# take any actions in the post-win round). Gated to the SURVIVE type to
	# avoid touching the ANNIHILATION default path.
	if _victory_conditions != null \
			and _victory_conditions.primary_condition_type == VictoryConditions.ConditionType.SURVIVE_N_ROUNDS \
			and round_num > _victory_conditions.survive_rounds:
		_emit_battle_outcome(&"VICTORY_SURVIVE")
		return
	# Clear per-round per-unit action flags so units can act in the new round.
	# Without this, _handle_grid_click_observation silently rejects re-selection
	# of any unit that acted in the prior round (user-reported "after 2 moves
	# the unit can't be selected again" symptom).
	_acted_this_turn.clear()
	_moved_this_turn.clear()
	_move_undo_cache.clear()  # S52 — undo only valid within the current turn
	# Session-10: also clear any pending attack preview — counters reset between
	# rounds and the relative direction/aura state may have shifted.
	_clear_attack_preview(&"round_started")
	# S72 Critical chain — reset per-side CRIT chain at round boundary so
	# momentum lives within a round, doesn't compound indefinitely.
	_critical_chain_per_side[0] = 0
	_critical_chain_per_side[1] = 0
	critical_chain_changed.emit(0, 0)
	critical_chain_changed.emit(1, 0)
	# Session-21: ch5 적벽 본전 FIRE terrain damage. Any alive unit standing on a
	# FIRE tile (terrain_type=8, burning ship debris) at round start takes
	# FIRE_DAMAGE_PER_TURN as MAGICAL damage (bypasses shield_wall flat reduction;
	# defend_stance still applies its 50% reduction — thematically "guarding
	# against the flames"). True damage path would also work but apply_damage
	# keeps the unified damage pipeline + emits unit_died correctly for the
	# COMMANDER DEMORALIZED radius trigger.
	_apply_fire_damage_on_round_start()
	round_started_visual.emit(round_num)
	# Story-008 AC-3: formation_turns counter. If any alive player unit had
	# ≥1 adjacent ally during this round, increment + emit. Per ADR-0014 §7
	# sketch + chapter-prototype's formation-active scan.
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue  # player-side only
		if not _hp_controller.is_alive(unit.unit_id):
			continue  # dead units don't form formations
		if _count_adjacent_allies(unit) >= 1:
			_fate_formation_turns += 1
			hidden_fate_condition_progressed.emit(&"formation_turns", _fate_formation_turns)
			break  # one increment per round, not per qualifying unit
	# Phase F — 25챕터 영걸전 hidden destiny per-round predicates. Each counter
	# increments when its chapter-specific predicate holds. Counters tied to
	# unit_ids that don't exist in the current chapter stay 0 (predicate false).
	_evaluate_phase_f_per_round_counters()
	# Story-007 AC-3: round 6 (>5) triggers TURN_LIMIT_REACHED.
	if round_num > _max_turns:
		_emit_battle_outcome(&"TURN_LIMIT_REACHED")


## Phase F — per-round fate field evaluation. Each counter increments when its
## chapter-specific predicate holds. Predicate references unit_ids that may
## not exist outside their owning chapter → stays 0 in other contexts.
##
## See _fate_* var declarations for the field → chapter mapping.
func _evaluate_phase_f_per_round_counters() -> void:
	# discipline_turns (ch21): no friendly losses since last round. Snapshot the
	# alive friendly count each round; if unchanged, the discipline held.
	var current_friendly_alive: int = 0
	for unit: BattleUnit in _units.values():
		if unit.side == 0 and _hp_controller.is_alive(unit.unit_id):
			current_friendly_alive += 1
	if _fate_friendly_alive_at_last_round == -1:
		_fate_friendly_alive_at_last_round = current_friendly_alive  # round 1 baseline
	elif current_friendly_alive == _fate_friendly_alive_at_last_round:
		_fate_discipline_turns += 1
		hidden_fate_condition_progressed.emit(&"discipline_turns", _fate_discipline_turns)
		_fate_friendly_alive_at_last_round = current_friendly_alive
	else:
		_fate_friendly_alive_at_last_round = current_friendly_alive  # someone died; reset baseline

	# escort_alive_turns (ch03): unit 5 (wei_001_cao_cao placeholder for 도겸) alive.
	if _units.has(5) and _hp_controller.is_alive(5):
		_fate_escort_alive_turns += 1
		hidden_fate_condition_progressed.emit(&"escort_alive_turns", _fate_escort_alive_turns)

	# wei_yan_spared_turns (ch13): unit 15 (위연) alive. Only present in ch13 enemy roster.
	if _units.has(15) and _hp_controller.is_alive(15):
		_fate_wei_yan_spared_turns += 1
		hidden_fate_condition_progressed.emit(&"wei_yan_spared_turns", _fate_wei_yan_spared_turns)

	# qixing_turns (ch25): 제갈량 (unit 13) on tile [7,5] (칠성단). 본진 사수.
	if _units.has(13) and _hp_controller.is_alive(13):
		var zhuge: BattleUnit = _units[13]
		if zhuge.position == Vector2i(7, 5):
			_fate_qixing_turns += 1
			hidden_fate_condition_progressed.emit(&"qixing_turns", _fate_qixing_turns)

	# counter_fire_turns (ch22): ≥1 FIRE tile (terrain 8) on map.
	if _map_grid != null and _map_has_fire_tile():
		_fate_counter_fire_turns += 1
		hidden_fate_condition_progressed.emit(&"counter_fire_turns", _fate_counter_fire_turns)

	# retreat_path_clear_turns (ch20): tile [13,5] has no enemy within Chebyshev distance 2.
	if not _enemy_within_radius(Vector2i(13, 5), 2):
		_fate_retreat_path_clear_turns += 1
		hidden_fate_condition_progressed.emit(
			&"retreat_path_clear_turns", _fate_retreat_path_clear_turns
		)

	# masu_supervised_turns (ch24): friendly unit on chokepoint [7,5] (가정 길목).
	if _friendly_on_tile(Vector2i(7, 5)):
		_fate_masu_supervised_turns += 1
		hidden_fate_condition_progressed.emit(
			&"masu_supervised_turns", _fate_masu_supervised_turns
		)

	# scout_first_turns (ch16 낙봉파 — 방통 생존 시그니처 #2). Friendly CAVALRY
	# (class 0) or SCOUT (class 5) on a FOREST tile (terrain 1) = 정찰 forward
	# positioning. In ch16 map, FOREST patches at rows 3 + 7 are the ambush
	# spots — 조운/마초 occupying those tiles exposes the matsumoto archers
	# before they fire on the main 방통-led column.
	if _friendly_scout_on_forest():
		_fate_scout_first_turns += 1
		hidden_fate_condition_progressed.emit(&"scout_first_turns", _fate_scout_first_turns)


func _map_has_fire_tile() -> bool:
	if _map_grid == null:
		return false
	var dims: Vector2i = _map_grid.get_map_dimensions()
	for r: int in dims.y:
		for c: int in dims.x:
			var td: MapTileData = _map_grid.get_tile(Vector2i(c, r))
			if td != null and td.terrain_type == 8:
				return true
	return false


func _enemy_within_radius(center: Vector2i, radius: int) -> bool:
	for unit: BattleUnit in _units.values():
		if unit.side != 1:
			continue
		if not _hp_controller.is_alive(unit.unit_id):
			continue
		var dx: int = absi(unit.position.x - center.x)
		var dy: int = absi(unit.position.y - center.y)
		if maxi(dx, dy) <= radius:
			return true
	return false


func _friendly_on_tile(tile: Vector2i) -> bool:
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue
		if not _hp_controller.is_alive(unit.unit_id):
			continue
		if unit.position == tile:
			return true
	return false


## Phase F (ch16) — friendly CAVALRY (class 0) or SCOUT (class 5) on a FOREST
## tile (terrain 1). Requires both a friendly mobile-class unit AND its
## position be on a FOREST tile in the current map. Used by scout_first_turns
## per-round predicate.
func _friendly_scout_on_forest() -> bool:
	if _map_grid == null:
		return false
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue
		if not _hp_controller.is_alive(unit.unit_id):
			continue
		# CAVALRY (0) or SCOUT (5) class = mobile scout role
		if unit.unit_class != 0 and unit.unit_class != 5:
			continue
		var td: MapTileData = _map_grid.get_tile(unit.position)
		if td != null and td.terrain_type == 1:
			return true
	return false


# ─── Private helpers ─────────────────────────────────────────────────────────

## Scans _units for the first unit whose BattleUnit.tag matches the given tag.
## Returns -1 if no matching unit found per ADR-0014 §3 + story-002 AC-4.
## Tag is singular (StringName) on BattleUnit per ADR-0014 §3 (NOT Array of tags
## — MVP scope. Future Rally ADR may need multi-tag, e.g., "commander+tank";
## additive amendment to BattleUnit at that point per CR-1d schema-evolution rules).
func _find_unit_by_tag(tag: StringName) -> int:
	for unit: BattleUnit in _units.values():
		if unit.tag == tag:
			return unit.unit_id
	return -1


## Returns true if the given action is one of the 10 grid-domain actions per
## ADR-0014 §4 + input-handling GDD §93. Non-grid actions (camera_pan,
## camera_zoom_in, etc.) are silently ignored by _on_input_action_fired.
func _is_grid_action(action: String) -> bool:
	return action in _GRID_ACTIONS


# ─── FSM dispatch helpers (story-003 AC-5) ───────────────────────────────────

## Dispatches a grid click in OBSERVATION state. Only `unit_select` on an own
## unit (side == 0) that has not acted-this-turn produces a state transition.
## Per ADR-0014 §4 + story-003 AC-5 + AC-7.
func _handle_grid_click_observation(action: String, _coord: Vector2i, unit_id: int) -> void:
	if action != "unit_select":
		return  # only unit_select transitions out of OBSERVATION (MVP scope)
	if unit_id == -1:
		return  # off-grid or non-unit click (e.g., empty tile)
	if not _units.has(unit_id):
		return  # invalid unit_id (defensive — shouldn't happen if InputRouter is correct)
	var unit: BattleUnit = _units[unit_id]
	if unit.side != 0:
		return  # only own units (player side) can be selected (MVP — no enemy inspection)
	if _acted_this_turn.get(unit_id, false):
		return  # acted-this-turn click guard per AC-7 (silent no-op)
	# Active-turn enforcement: only the unit whose turn is ACTING may be selected.
	# Prior behavior allowed any own unit to be selected, then declare_action would
	# silently fail with NOT_UNIT_TURN — confusing the player into thinking input
	# was broken. Now the click is rejected upfront with a console hint.
	if _active_turn_unit_id != -1 and unit_id != _active_turn_unit_id:
		_trace("[TURN] Not unit %d's turn — active unit is %d" % [unit_id, _active_turn_unit_id])
		return
	_select_unit(unit_id)


## Dispatches a grid click in UNIT_SELECTED state. Per ADR-0014 §4 + story-003 AC-5:
##  - unit_select on selected unit again → deselect
##  - move_cancel / attack_cancel → deselect
##  - move_target_select / move_confirm + valid move target → handoff to _handle_move (story-004)
##  - attack_target_select / attack_confirm + valid attack target → handoff to _handle_attack (story-005)
##  - end_unit_turn → end_player_turn (story-006 stub)
##  - other actions in this state → silent
func _handle_grid_click_unit_selected(action: String, coord: Vector2i, unit_id: int) -> void:
	match action:
		"unit_select":
			# Toggle: clicking the selected unit again ends its turn if it has
			# already moved (declare WAIT — finalises the turn so the next unit
			# can act). If it hasn't moved yet, just deselect (existing flow).
			if unit_id == _selected_unit_id:
				if _moved_this_turn.get(_selected_unit_id, false):
					_trace("[HINT] unit %d re-clicked after move — declaring WAIT to end turn" % _selected_unit_id)
					_acted_this_turn[_selected_unit_id] = true
					_turn_runner.declare_action(_selected_unit_id, TurnOrderRunner.ActionType.WAIT, null)
					_deselect()
				else:
					_deselect()
				return
			# Production click disambiguation: every grid action (unit_select /
			# move_target_select / attack_target_select / …) is bound to MOUSE_LEFT
			# in default_bindings.json. InputRouter's first-match-wins resolves any
			# left-click to `unit_select`. In S1 we re-classify by ctx:
			#   empty tile in move range  → MOVE
			#   enemy tile in attack range → ATTACK
			#   different own unit        → silent (MVP — deselect first)
			if not _units.has(_selected_unit_id):
				return  # defensive — selection orphaned
			var selector: BattleUnit = _units[_selected_unit_id]
			if unit_id == -1:
				# Click on empty tile while a preview was armed — cancel preview
				# (player wants to move, not attack). MOVE proceeds as before.
				_clear_attack_preview(&"empty_tile_click")
				if is_tile_in_move_range(coord, _selected_unit_id):
					_handle_player_move(selector, coord)
			elif _units.has(unit_id) and _units[unit_id].side != selector.side:
				if is_tile_in_attack_range(coord, _selected_unit_id):
					# 2-step attack flow: first tap on a valid enemy target shows
					# UI-GB-04 Combat Forecast (preview); second tap on the SAME
					# target commits the attack. Tapping a different enemy
					# re-arms the preview against the new target.
					if _pending_attack_target_id == unit_id:
						# Confirm: commit + clear pending state. Dismiss signal
						# fires BEFORE the attack so the forecast fades while the
						# damage animation plays — feels more responsive than
						# dismissing after damage_applied (which the HUD also
						# handles redundantly per AC-3).
						attack_preview_dismissed.emit(&"attack_committed")
						_pending_attack_target_id = -1
						_handle_player_attack(_selected_unit_id, unit_id)
					else:
						# Arm preview against this target. If another preview
						# was already armed (player switching targets), the
						# dismiss is implicit via the replaced signal — HUD
						# treats successive show_forecast calls as idempotent
						# replacements per ADR-0015 §5.
						_pending_attack_target_id = unit_id
						var preview: Dictionary = preview_attack(_selected_unit_id, unit_id)
						attack_preview_requested.emit(_selected_unit_id, unit_id, preview)
		"move_cancel", "attack_cancel":
			_deselect()
		"move_target_select", "move_confirm":
			# Per ADR-0014 §Amendment 2026-05-10 (#2): dispatch to _handle_player_move
			# (not _handle_move) so declare_action emits correctly-typed MOVE token.
			# is_tile_in_move_range guard is redundant with _handle_player_move's
			# internal check but harmless — leaves story-004/005/006 guarantees intact.
			# Explicit move via keyboard/confirm-key cancels any armed attack preview.
			_clear_attack_preview(&"move_confirm")
			if is_tile_in_move_range(coord, _selected_unit_id):
				_handle_player_move(_units[_selected_unit_id], coord)
		"attack_target_select", "attack_confirm":
			# Per ADR-0014 §Amendment 2026-05-10 (#2): dispatch to _handle_player_attack.
			# Explicit-confirm keyboard path bypasses the 2-step preview — keyboard
			# users opt into fast commit. Preview is still dismissed in case one
			# was armed via prior mouse click.
			_clear_attack_preview(&"attack_confirm")
			if is_tile_in_attack_range(coord, _selected_unit_id):
				_handle_player_attack(_selected_unit_id, unit_id)
		"end_unit_turn":
			# Per ADR-0014 §Amendment 2026-05-10 (#2): dispatch to _handle_player_end_turn
			# which declares WAIT for unacted units before calling end_player_turn().
			_handle_player_end_turn()
		_:
			# undo_last_move / grid_hover / unrecognized → silent (MVP scope)
			return


## Selects a unit. Transitions state to UNIT_SELECTED + emits unit_selected_changed
## with (new_unit_id, prev_selected_unit_id). Per ADR-0014 §8 + story-003 AC-5.
func _select_unit(unit_id: int) -> void:
	var prev: int = _selected_unit_id
	_selected_unit_id = unit_id
	_state = BattleState.UNIT_SELECTED
	_trace("[SELECT] unit=%d (active=%d)" % [unit_id, _active_turn_unit_id])
	unit_selected_changed.emit(unit_id, prev)


## Deselects the current unit. Transitions state to OBSERVATION + emits
## unit_selected_changed(-1, prev_selected_unit_id) per ADR-0014 §8.
## Also clears any armed attack preview — deselect always cancels a pending
## 2-step attack (session-10 addition).
func _deselect() -> void:
	_clear_attack_preview(&"deselect")
	var prev: int = _selected_unit_id
	_selected_unit_id = -1
	_state = BattleState.OBSERVATION
	unit_selected_changed.emit(-1, prev)


## Session-52 — public wrapper around _deselect for callers outside the
## controller that need to cancel a player's unit selection (e.g.,
## BattleScene polling-based ESC handler when the natural InputRouter →
## GameBus.input_action_fired chain isn't reaching the controller). Pre-S52
## the only path to deselect was via emit-and-subscribe on input_action_
## fired("move_cancel"), which the user reported as non-functional in
## windowed runs (event interception we can't reproduce headlessly).
## This wrapper provides a direct deterministic call path.
func cancel_selection() -> void:
	_deselect()


## Session-52 — rolls back the most-recent MOVE for `unit_id` this turn
## (영걸전식 move undo). Returns true on success. The unit's position +
## facing are restored to pre-move values, the MOVE token is retracted on
## the turn runner so the player can re-issue MOVE, and unit_moved fires
## so the visual tween animates the polygon back. The unit ends up
## re-selected, ready for the next attempt.
##
## Returns false (no-op) when:
##   - unit_id not in roster
##   - no cached pre-move state for this unit this turn (cache cleared on
##     turn_started / round_started)
##   - the unit has already declared an ATTACK / DEFEND / WAIT this turn
##     (token spent — undo would be unsafe)
##
## Caller: BattleScene._process polling on ESC + right-click, mirroring
## the cancel-selection UX but reversing the previous commit instead.
func cancel_last_move(unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	if not _move_undo_cache.has(unit_id):
		return false  # nothing to undo this turn
	if _acted_this_turn.get(unit_id, false):
		return false  # ATTACK / DEFEND / WAIT already committed
	var unit: BattleUnit = _units[unit_id]
	var entry: Dictionary = _move_undo_cache[unit_id]
	var prev_pos: Vector2i = entry["prev_pos"] as Vector2i
	var prev_facing: int = entry["prev_facing"] as int
	var movement_cost: int = entry["movement_cost"] as int
	var current_pos: Vector2i = unit.position
	# Roll back the MapGrid occupancy: clear dest, restore source.
	_map_grid.clear_occupant(current_pos)
	unit.position = prev_pos
	unit.facing = prev_facing
	var faction: int = MapGrid.FACTION_ALLY if unit.side == 0 else MapGrid.FACTION_ENEMY
	_map_grid.set_occupant(prev_pos, unit.unit_id, faction)
	# Retract the MOVE token on the turn runner so the player can re-MOVE.
	# Silent best-effort — if the runner lacks retract_move (older stubs in
	# unit tests), we still complete the visual undo. The token stays spent
	# in that case but the position is restored.
	if _turn_runner != null and _turn_runner.has_method("retract_move"):
		_turn_runner.retract_move(unit_id, movement_cost)
	# Clear flags + cache.
	_moved_this_turn[unit_id] = false
	_move_undo_cache.erase(unit_id)
	# Emit unit_moved so the visual layer tweens the polygon back. From/To
	# reversed from the original move: current → prev.
	unit_moved.emit(unit_id, current_pos, prev_pos)
	# Re-select so the player can immediately try a different destination.
	# was_selected = unit_id (non-zero) → BattleScene's _on_unit_selected_
	# changed re-renders movable_tiles preview at the restored position.
	_selected_unit_id = unit_id
	_state = BattleState.UNIT_SELECTED
	unit_selected_changed.emit(unit_id, unit_id)
	return true


## Clears any armed attack preview. Idempotent — silent no-op if no preview
## is armed. Emits attack_preview_dismissed for BattleHUD to fade UI-GB-04.
## Reason is informational (informs the receiver why dismiss fired but no
## production branching depends on it — same convention as
## BattleHUD._dismiss_forecast(reason)).
func _clear_attack_preview(reason: StringName) -> void:
	if _pending_attack_target_id == -1:
		return
	_pending_attack_target_id = -1
	attack_preview_dismissed.emit(reason)


# ─── Action handler stubs (filled by stories 004-005) ───────────────────────

## Per ADR-0014 §Amendment 2026-05-10 (#2 — player-path mirror).
## Mirrors AI-path bypass (_on_ai_action_ready MOVE arm): calls _do_move directly
## (not _handle_move wrapper) to avoid _consume_unit_action's hardcoded
## declare_action(ATTACK). Player MOVE must declare correctly-typed MOVE so
## _maybe_defer_turn_completion (S15-A) keeps the turn open for follow-up ATTACK.
func _handle_player_move(unit: BattleUnit, dest: Vector2i) -> void:
	if _active_turn_unit_id != -1 and unit.unit_id != _active_turn_unit_id:
		return  # not this unit's turn — declare would silent-fail anyway; reject early
	if _acted_this_turn.get(unit.unit_id, false):
		return  # turn already terminal (attacked/waited) — no more moves
	if _moved_this_turn.get(unit.unit_id, false):
		_trace("[HINT] unit %d already moved this turn — click an enemy to attack OR click the unit itself to skip" % unit.unit_id)
		return  # MOVE token already spent — one move per turn
	if not is_tile_in_move_range(dest, unit.unit_id):
		return  # invalid target — silent
	# Session-52 — cache pre-move state for cancel_last_move (ESC / right-
	# click undo UX). Captured BEFORE _do_move mutates unit.position /
	# unit.facing. movement_cost is computed below alongside the declare
	# call so the cache + the turn runner's accumulated_move_cost stay in
	# sync (cancel_last_move passes the cached cost back to retract_move).
	var prev_pos: Vector2i = unit.position
	var prev_facing: int = unit.facing
	_do_move(unit, dest)
	_moved_this_turn[unit.unit_id] = true
	var move_target: ActionTarget = _make_move_target(dest)
	_move_undo_cache[unit.unit_id] = {
		"prev_pos": prev_pos,
		"prev_facing": prev_facing,
		"movement_cost": move_target.movement_cost,
	}
	_turn_runner.declare_action(unit.unit_id, TurnOrderRunner.ActionType.MOVE, move_target)


## Bridges the TurnOrderRunner DEFEND declaration into HPStatusController's
## status-effect layer. Without this call, declare_action(DEFEND) sets only
## the per-turn UnitTurnState flag — HPStatusController.apply_damage checks
## for the &"defend_stance" status effect (line 117) which would never appear,
## so the 50% damage reduction never fired.
##
## Idempotent: apply_status enforces same-effect refresh per CR-5c — calling
## twice in one turn just refreshes the duration. Source = self_id by
## convention (defending is a self-applied stance).
func _apply_defend_stance_status(unit_id: int) -> void:
	if _hp_controller == null:
		return
	if not _hp_controller.has_method("apply_status"):
		return
	# duration_override = -1 means "use template default" (1 turn for
	# defend_stance per assets/data/status_effects/defend_stance.tres).
	_hp_controller.apply_status(unit_id, &"defend_stance", -1, unit_id)
	# Visual signal — ChapterVisuals adds a "방" badge to the unit's polygon
	# until round_started_visual fires (next round = fresh turn).
	unit_defend_stance_applied.emit(unit_id)


## D-key entry point. Routes the defend_stance input action to the selected
## player unit. Silent no-op when no unit is selected, when the selected unit
## isn't player-controlled, or when it isn't this unit's turn (the per-unit
## guards in _handle_player_defend would catch the latter, but we'd rather
## fail-quietly than push_warning on every misplaced D press).
func _handle_defend_stance_input() -> void:
	# S86 — selection-less fallback: if no unit is currently selected, target the
	# active turn unit (must be player-side). Playtest revealed users press D
	# without first clicking their unit; pre-S86 that silent-returned and
	# looked like a dead key.
	var target_id: int = _selected_unit_id
	if _state != BattleState.UNIT_SELECTED or target_id == -1 or not _units.has(target_id):
		target_id = _active_turn_unit_id
		if target_id == -1 or not _units.has(target_id):
			return
		var active: BattleUnit = _units[target_id]
		if active.side != 0:
			return  # active turn belongs to enemy — D is a no-op
	var unit: BattleUnit = _units[target_id]
	if unit.side != 0:
		return  # don't let players defend with enemy units
	# Cancel any armed attack preview before committing to defend — the player
	# changed their mind. Mirrors the move-cancels-preview pattern.
	_clear_attack_preview(&"defend_chosen")
	_handle_player_defend(target_id)
	# After the action declares, the turn ends naturally via _maybe_defer_turn_completion.
	# Deselect to remove the unit overlay since it can no longer act this turn.
	_deselect()


# ─── Session-15 commit 5 + session-16: hero active skills ───────────────────
#
# 1-per-battle "ultimate" buttons. heroes.json `innate_skill_ids[0]` → unit.skill_id;
# player presses S → controller fires the matching skill_<name> handler.
# Skills are battle-scoped (not turn-scoped): firing flips skill_used to true and
# the unit's S key becomes a no-op for the rest of this battle.
#
# Wired skill roster (7/7 player-roster slots covered):
#   - skill_dragon_blade    (관우):  next attack +50% damage (self-buff, ATK token NOT spent)
#   - skill_thunder_roar    (장비):  25 damage to all Manhattan-1 enemies (spends ATK)
#   - skill_inspire         (유비):  adjacent player allies get a free action token
#   - skill_piercing_volley (황충):  28 damage to up to 3 nearest enemies within
#                                    Manhattan distance ≤ attack_range (spends ATK)
#   - skill_charm           (초선):  marks Manhattan-1 enemies as already-acted
#                                    (wastes their turn this round; does NOT spend caster ATK)
#   - skill_strategist      (조조):  15 damage to ALL alive enemies on the map
#                                    (battlefield-wide; spends ATK)
#   - skill_naval_strategy  (주유):  STUN every Manhattan-1 enemy. Stolen turn:
#                                    not-yet-acted victims marked acted (current
#                                    round); already-acted victims get _pending_stun
#                                    so their NEXT turn force-WAITs (cross-round
#                                    lock). Does NOT spend caster ATK (tempo skill).
#
# S86 G2 — Shu 명장 4 skill wired (2026-05-25):
#   - skill_fire_strategy   (제갈량): 20 damage + slow status to all enemies within
#                                    Manhattan ≤ 3 (spends ATK). 박망파/적벽 화공 narrative.
#   - skill_lone_lance      (조운):  next attack +75% damage IF caster has no
#                                    adjacent allies at attack resolution time
#                                    (8-neighbor check). Differs from dragon_blade
#                                    by being conditional (alone) + stronger
#                                    multiplier. ATK token NOT spent. 단신 돌격
#                                    narrative.
#   - skill_xiliang_charge  (마초):  20 damage to enemies in any of 4 cardinal-
#                                    direction lines (Manhattan ≤ 3) from caster.
#                                    Cross-shape AoE; spends ATK. 서량 기병 돌파.
#   - skill_successor_strategy (강유): pick highest-damage (lowest HP) ally within
#                                    Manhattan ≤ 4 → 25 HP heal + refund action
#                                    token (free attack/move this round). Differs
#                                    from inspire (adjacent-all) by single-target +
#                                    heal. ATK token NOT spent. 후계자 strategy.
#
# Design notes:
#  - dragon_blade does NOT spend the ATK token — the player still has to attack
#    after activating it. Combo: select 관우 → S → click enemy → big damage.
#  - thunder_roar / piercing_volley / strategist all consume the ATK token (they
#    ARE the attack). thunder_roar is melee-burst, piercing_volley is range-burst,
#    strategist is battlefield-wide low-per-hit AoE.
#  - inspire / charm do NOT spend the caster's ATK token; they are tempo skills,
#    not damage skills. inspire grants the player extra actions; charm steals
#    actions from adjacent enemies (mirror of inspire on the enemy side).

## Per-unit "next attack gets dragon-blade bonus" flag. Set by skill_dragon_blade
## handler; consumed by _resolve_attack (which clears + marks skill_used).
var _dragon_blade_pending: Dictionary[int, bool] = {}

## Phase 2 — 위연 (INFANTRY) skill_rebel_charge: "Blade waiting for the moment"
## per design/art/characters/wei-yan.md — long restraint released. Next attack
## bypasses defender raw_def AND deals +50% damage. Mirrors dragon_blade pattern
## (one-shot, no ATK token consumed by skill itself — player must follow with
## an attack to cash in). Cinematic intent: ignored defenses, devastating strike.
var _rebel_charge_pending: Dictionary[int, bool] = {}

## S86 G2 — 조운 (SCOUT/CAVALRY) skill_lone_lance: 단신 돌격 narrative. Mirrors
## dragon_blade pattern (pending flag → consumed by next _resolve_attack) but
## with a CONDITIONAL trigger: only fires when the caster has zero adjacent
## allies (8-neighbor check) AT attack resolution time. If the lone-ness
## condition fails, the pending flag is consumed silently with no bonus —
## one-shot is gone, player must position 조운 alone for the +75% payout.
var _lone_lance_pending: Dictionary[int, bool] = {}


## S-key entry point. Mirrors _handle_defend_stance_input — routes the use_skill
## input action to the selected unit if a skill is wired AND not yet used.
## S86 — selection-less fallback (same rationale as _handle_defend_stance_input):
## active turn unit is used when no manual selection is in place. Playtest
## showed users press S immediately on turn-start without selecting first.
func _handle_use_skill_input() -> void:
	var target_id: int = _selected_unit_id
	if _state != BattleState.UNIT_SELECTED or target_id == -1 or not _units.has(target_id):
		target_id = _active_turn_unit_id
		if target_id == -1 or not _units.has(target_id):
			return
		var active: BattleUnit = _units[target_id]
		if active.side != 0:
			return  # active turn belongs to enemy — S is a no-op
	use_skill(target_id)


## S90 Phase B — I/3-key entry point. Mirrors _handle_use_skill_input —
## selection-less fallback to active turn unit when no manual selection in
## place. Routes the use_item action to slot 0 of the selected unit's
## inventory (MVP default per strategy-systems.md §3.5.2 — I/3 key uses the
## first item; future slot-selection UI deferred to Phase C+).
func _handle_use_item_input() -> void:
	var target_id: int = _selected_unit_id
	if _state != BattleState.UNIT_SELECTED or target_id == -1 or not _units.has(target_id):
		target_id = _active_turn_unit_id
		if target_id == -1 or not _units.has(target_id):
			return
		var active: BattleUnit = _units[target_id]
		if active.side != 0:
			return  # active turn belongs to enemy — I/3 is a no-op
	use_item(target_id, 0)


## Public item-firing API. Validates slot contents + item-specific conditions
## (e.g. heal_potion requires HP < max_hp), applies the effect, decrements the
## slot, spends the action token via TurnOrderRunner.declare_action(USE_ITEM).
## Returns true on success, false when blocked (no item / wrong side / active
## token spent / item-specific reject).
##
## Per strategy-systems.md v0.3 §3.3 + AC-SS-4. S90 Phase B MVP scope: heal_potion
## only (immediate self-target HP restore). Future items (strength_scroll buff
## carry, fire_scroll cross-class, march_scroll movement extension) land in
## subsequent commits per Phase B implementation order.
func use_item(unit_id: int, slot_idx: int) -> bool:
	if _battle_over:
		return false
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	# Side gate: only player units consume items in MVP (enemy inventory =
	# Phase 4+ per strategy-systems §3.1).
	if unit.side != 0:
		return false
	# Turn gate: must be this unit's active turn (mirrors use_skill).
	if _active_turn_unit_id != -1 and unit_id != _active_turn_unit_id:
		return false
	# Slot validation
	if slot_idx < 0 or slot_idx >= unit.inventory.size():
		return false  # out-of-range slot
	var item_id: StringName = unit.inventory[slot_idx]
	if item_id == &"":
		return false  # empty slot
	# Item dispatch — heal_potion (step 4) + strength_scroll (step 5) wired.
	# Other prototype items (march_scroll step 7, fire_scroll step 6 pending
	# OQ-DC-11 resolution) land in subsequent steps per strategy-systems.md
	# v0.3 Phase B implementation order.
	var fired: bool = false
	var actual_effect: int = 0
	match item_id:
		&"heal_potion":
			actual_effect = _use_item_heal_potion(unit)
			fired = actual_effect > 0
		&"strength_scroll":
			actual_effect = _use_item_strength_scroll(unit)
			fired = actual_effect > 0
		_:
			push_warning("GridBattleController.use_item: unwired item_id '%s' on unit %d slot %d — no-op"
				% [String(item_id), unit_id, slot_idx])
			return false
	if not fired:
		# Item-specific reject (e.g. heal_potion when HP at max). Slot NOT
		# decremented; token NOT spent — per strategy-systems §4.1 EC.
		return false
	# Success path: decrement slot, spend action token, emit signal.
	unit.inventory[slot_idx] = &""
	if _turn_runner != null:
		_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.USE_ITEM, null)
	unit_item_used.emit(unit_id, item_id, slot_idx, actual_effect)
	return true


## heal_potion handler — strategy-systems.md v0.3 §4.1.
## Restores HEAL_POTION_AMOUNT (25) HP to caster (self-target). Returns the
## actual HP healed (clamped to max_hp - current_hp). Returns 0 if HP already
## at max (caller treats 0 as item-rejected → slot NOT decremented).
const HEAL_POTION_AMOUNT: int = 25

func _use_item_heal_potion(unit: BattleUnit) -> int:
	if _hp_controller == null:
		return 0
	if not _hp_controller.is_alive(unit.unit_id):
		return 0  # dead unit cannot self-heal (revive_pill is a different item, Phase C+)
	var current_hp: int = _hp_controller.get_current_hp(unit.unit_id)
	var max_hp: int = _hp_controller.get_max_hp(unit.unit_id)
	if current_hp >= max_hp:
		return 0  # already at max — reject (slot not consumed)
	# apply_heal returns the ACTUAL heal applied (caps at max_hp internally).
	return _hp_controller.apply_heal(unit.unit_id, HEAL_POTION_AMOUNT, unit.unit_id)


## strength_scroll handler — strategy-systems.md v0.3 §4.2.
## Sets caster.pending_buff to a multi-turn carry buff: next attack/skill
## damage × STRENGTH_SCROLL_MULT (1.50). Buff consumed at attack-resolve time
## by `_resolve_pending_buff_magnitude` (called from _resolve_attack site).
## Returns 1 on success (signal payload — "1 buff stored"); 0 on reject.
## Reject conditions: dead unit (revival is Phase C+).
##
## Buff overwrite: if caster already carries a pending_buff, the new one
## REPLACES it (no stacking — Pillar #3 protection per strategy-systems §3.6 #4
## + EC-SS-2). No warning popup (design-intent).
const STRENGTH_SCROLL_MULT: float = 1.50

func _use_item_strength_scroll(unit: BattleUnit) -> int:
	if _hp_controller == null:
		return 0
	if not _hp_controller.is_alive(unit.unit_id):
		return 0  # dead unit cannot self-buff
	var current_round: int = _turn_runner.get_current_round_number() if _turn_runner != null else 1
	# expires_at_turn = current_round + 1; consumption gate uses >= so the buff
	# fires on the NEXT round's first attack/skill (per strategy-systems §2 +
	# AC-SS-5; v0.3 spec text said `> current_turn` but EC-SS-3 worked example
	# requires `>= current_turn` semantics — implemented per the example, with
	# spec text correction filed as a v0.3.1 carry-over).
	unit.pending_buff = {
		&"kind": &"strength",
		&"magnitude": STRENGTH_SCROLL_MULT,
		&"expires_at_turn": current_round + 1,
	}
	return 1  # success — "1 buff stored" for signal payload


## S90 Phase B step 5 — buff consumption helper. Called by _resolve_attack
## immediately before ResolveModifiers.make() to read the attacker's
## pending_buff magnitude (default 1.0 if no buff), clear the buff on
## consumption, and return the magnitude for the ResolveModifiers param.
##
## Consumption gate: `expires_at_turn >= current_round` — buff fires on the
## round at-or-after the round it was stored in (typically the NEXT round
## since action token economy prevents same-round use+attack). Stale buffs
## (expires_at_turn < current_round) are cleared without consumption.
##
## Counter guard: ResolveModifiers consumes buff only when is_counter == false
## (DamageCalc._passive_multiplier). The clear happens HERE regardless of
## counter — buff is "spent at attack resolve time" per strategy-systems §4.2.
## Counter-only resolves are rare in production; this matches the conservative
## consume-on-read pattern.
func _resolve_pending_buff_magnitude(attacker_id: int) -> float:
	if not _units.has(attacker_id):
		return 1.0
	var attacker: BattleUnit = _units[attacker_id]
	if attacker.pending_buff.is_empty():
		return 1.0
	var current_round: int = _turn_runner.get_current_round_number() if _turn_runner != null else 1
	var expires_at_turn: int = attacker.pending_buff.get(&"expires_at_turn", 0) as int
	if expires_at_turn < current_round:
		# Stale buff — clear without consumption (e.g. user used buff in round 3
		# but didn't attack until round 5+; buff expired).
		attacker.pending_buff = {}
		return 1.0
	# Fresh buff — read magnitude, clear (consumed), return for ResolveModifiers.
	var magnitude: float = attacker.pending_buff.get(&"magnitude", 1.0) as float
	attacker.pending_buff = {}
	return magnitude


## Public skill-firing API. Returns true on success, false when the skill is
## blocked (no skill_id / already used / wrong side / unknown skill_id).
## Side-effect-only — visual feedback handled by callers via the new
## `unit_skill_used` signal.
func use_skill(unit_id: int) -> bool:
	if _battle_over:
		return false
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	# Session-27 — player-side gate lifted. All wired skill handlers iterate
	# `victim.side == unit.side` (skip same-side) / `victim.side != unit.side`
	# (skip different-side), so the firing semantics are side-symmetric out
	# of the box. ADR-0014 §0 MVP scope originally deferred AI USE_SKILL;
	# session-27 closes that deferral.
	if unit.skill_id == &"":
		return false  # no skill wired
	if unit.skill_used:
		return false  # one-shot exhausted
	if _active_turn_unit_id != -1 and unit_id != _active_turn_unit_id:
		return false  # not this unit's turn
	# Dispatch to per-skill handler. Unknown skill_id falls through to a
	# warning-and-no-op so unwired skills don't silently consume the one-shot.
	var fired: bool = false
	match unit.skill_id:
		&"skill_dragon_blade":
			fired = _skill_dragon_blade(unit)
		&"skill_thunder_roar":
			fired = _skill_thunder_roar(unit)
		&"skill_rebel_charge":
			fired = _skill_rebel_charge(unit)
		&"skill_blunt_strategy":
			fired = _skill_blunt_strategy(unit)
		&"skill_phoenix_chick":
			fired = _skill_phoenix_chick(unit)
		&"skill_inspire":
			fired = _skill_inspire(unit)
		&"skill_piercing_volley":
			fired = _skill_piercing_volley(unit)
		&"skill_charm":
			fired = _skill_charm(unit)
		&"skill_strategist":
			fired = _skill_strategist(unit)
		&"skill_naval_strategy":
			fired = _skill_naval_strategy(unit)
		&"skill_fire_strategy":
			fired = _skill_fire_strategy(unit)
		&"skill_lone_lance":
			fired = _skill_lone_lance(unit)
		&"skill_xiliang_charge":
			fired = _skill_xiliang_charge(unit)
		&"skill_successor_strategy":
			fired = _skill_successor_strategy(unit)
		_:
			push_warning("GridBattleController.use_skill: unwired skill_id '%s' on unit %d — no-op"
				% [String(unit.skill_id), unit_id])
			return false
	if fired:
		unit.skill_used = true
		unit_skill_used.emit(unit_id, unit.skill_id)
	return fired


## Returns true if the unit can fire its skill RIGHT NOW (visual gate for the
## HUD skill button — battle_hud queries this to decide whether to enable / dim
## the button). Mirrors use_skill's preconditions without firing the skill.
func can_use_skill(unit_id: int) -> bool:
	if _battle_over:
		return false
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	if unit.side != 0:
		return false
	if unit.skill_id == &"":
		return false
	if unit.skill_used:
		return false
	if _active_turn_unit_id != -1 and unit_id != _active_turn_unit_id:
		return false
	return true


## 관우 dragon_blade: marks the unit's next attack to receive +50% damage.
## Does NOT consume the ATK token — the player still has to attack to cash
## in the buff. Buff persists until consumed (resolve_attack clears it) or
## battle ends; no turn-end auto-clear so the player can move first then attack.
func _skill_dragon_blade(unit: BattleUnit) -> bool:
	_dragon_blade_pending[unit.unit_id] = true
	return true


## 위연 rebel_charge (Phase 2): "Blade waiting for the moment" — marks the
## unit's next attack to (1) bypass defender raw_def (defender.raw_def → 0)
## AND (2) deal +50% post-damage. Cinematic punch: the restrained blade
## strikes through defenses. Same pattern as dragon_blade — does NOT consume
## ATK token; player follows with attack to cash in. Differs from dragon_blade
## by piercing DEF (more cinematic / situationally stronger vs high-DEF
## enemies; situationally weaker vs squishies since +50% multiplier same).
func _skill_rebel_charge(unit: BattleUnit) -> bool:
	_rebel_charge_pending[unit.unit_id] = true
	return true


## 방통 blunt_strategy (Phase 2): "기만전략" — Strategist standoff AoE control.
## Range-2 enemies (Manhattan ≤ 2) take 12 fixed damage each + slow status.
## Cinematic: 와룡-봉추 의 "기만으로 적이 헛걸음한다". Differs from 조조의
## skill_strategist (global AoE 15 damage, no status) by trading damage for
## sustained debuff — and from 장비의 thunder_roar (adjacent AoE 25, no
## status) by trading damage radius for range + control. Spends ATK token.
func _skill_blunt_strategy(unit: BattleUnit) -> bool:
	var blunt_damage: int = 12
	var blunt_range: int = 2
	var any_hit: bool = false
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		if dx + dy > blunt_range:
			continue
		_last_attacker_id = unit.unit_id
		_hp_controller.apply_damage(victim.unit_id, blunt_damage,
			ResolveModifiers.AttackType.MAGICAL, [&"skill"] as Array[StringName])
		_damage_dealt_by_unit[unit.unit_id] = \
			_damage_dealt_by_unit.get(unit.unit_id, 0) + blunt_damage
		damage_applied.emit(unit.unit_id, victim.unit_id, blunt_damage)
		# Slow always applies — sustained debuff that survives into next round.
		_apply_status_with_signal(victim.unit_id, &"slow", unit.unit_id)
		any_hit = true
	# Terminal action — spends ATK token whether or not any enemy was in range
	# (parity with skill_strategist + thunder_roar — deters probe-clicks).
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.ATTACK if any_hit else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## 방통 phoenix_chick (Phase 2): "봉추" — phoenix's healing fire. Heals each
## adjacent (Manhattan ≤ 1) alive ally for 25 HP. Cinematic: the rising
## phoenix radiates restoration around the strategist. Differs from 유비의
## skill_inspire (action token refund) by trading economy buff for raw
## sustain — strategists keep allies ALIVE rather than letting them act
## twice. Spends ATK token (terminal action).
func _skill_phoenix_chick(unit: BattleUnit) -> bool:
	var heal_amount: int = 25
	var any_heal: bool = false
	for ally: BattleUnit in _units.values():
		if ally.side != unit.side:
			continue
		if ally.unit_id == unit.unit_id:
			continue  # cinematic — phoenix heals allies, not self
		if not _hp_controller.is_alive(ally.unit_id):
			continue
		var dx: int = absi(ally.position.x - unit.position.x)
		var dy: int = absi(ally.position.y - unit.position.y)
		if dx + dy != 1:
			continue  # adjacent only
		if _hp_controller.has_method("apply_heal"):
			_hp_controller.apply_heal(ally.unit_id, heal_amount, unit.unit_id)
			any_heal = true
	# Terminal action — same probe-click deterrent as blunt_strategy.
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.USE_SKILL if any_heal else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## 장비 thunder_roar: immediate 25-fixed-damage burst to every adjacent enemy.
## Counts as the unit's terminal action (spends the ATK token via _acted_this_turn).
## If no adjacent enemies, the skill still fires (one-shot consumed) — design
## decision: prevents accidental probe-clicks from being undone, encourages the
## player to position 장비 deliberately before activating.
func _skill_thunder_roar(unit: BattleUnit) -> bool:
	var thunder_damage: int = 25  # BalanceConstant candidate; inline for v1
	var any_hit: bool = false
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		if dx + dy != 1:
			continue  # Manhattan-1 only — 4 cardinal neighbors
		_last_attacker_id = unit.unit_id
		_hp_controller.apply_damage(victim.unit_id, thunder_damage,
			ResolveModifiers.AttackType.PHYSICAL, [&"skill"] as Array[StringName])
		_damage_dealt_by_unit[unit.unit_id] = \
			_damage_dealt_by_unit.get(unit.unit_id, 0) + thunder_damage
		damage_applied.emit(unit.unit_id, victim.unit_id, thunder_damage)
		any_hit = true
	# Spend the action token regardless of whether anyone was hit — skill firing
	# is the terminal action for this unit's turn.
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.ATTACK if any_hit else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## 유비 inspire: refunds the ACTION token for every adjacent player ally so
## they can take ANOTHER action this round. Does NOT spend 유비's own ATK
## token — 유비 can still attack/move after. Skill itself is the one-shot;
## the refunded allies don't gain anything else (their stats unchanged).
## Effect surfaces as: pressing S on 유비 with 장비 + 관우 adjacent → both of
## them are eligible to act again even if they already moved + attacked.
func _skill_inspire(unit: BattleUnit) -> bool:
	for ally: BattleUnit in _units.values():
		if ally.side != unit.side:
			continue
		if ally.unit_id == unit.unit_id:
			continue  # don't refund the caster (avoid infinite-action loop)
		if not _hp_controller.is_alive(ally.unit_id):
			continue
		var dx: int = absi(ally.position.x - unit.position.x)
		var dy: int = absi(ally.position.y - unit.position.y)
		if dx + dy != 1:
			continue  # adjacent only
		_acted_this_turn[ally.unit_id] = false
	return true


## 황충 piercing_volley: ranged AoE — fires 28 fixed damage at up to 3 nearest
## alive enemies whose Manhattan distance ≤ caster's attack_range (typically 2
## for ARCHER). Spends the ATK token (the skill IS the attack). If no enemy is
## in range the skill still fires (one-shot consumed) — design parity with
## thunder_roar: punishes accidental probe-clicks, encourages deliberate
## positioning. The 3-target cap prevents an over-stacked enemy group from
## taking 5+ hits at once (would invalidate AoE pricing).
func _skill_piercing_volley(unit: BattleUnit) -> bool:
	var volley_damage: int = 28  # BalanceConstant candidate; inline for v1
	var max_targets: int = 3
	var reach: int = maxi(1, unit.attack_range)
	var candidates: Array[Dictionary] = []
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		var dist: int = dx + dy
		if dist == 0 or dist > reach:
			continue
		candidates.append({"unit_id": victim.unit_id, "dist": dist})
	# Sort by Manhattan distance ascending; closer enemies hit first.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["dist"] as int) < (b["dist"] as int))
	var hit_count: int = 0
	for entry: Dictionary in candidates:
		if hit_count >= max_targets:
			break
		var victim_id: int = entry["unit_id"] as int
		_last_attacker_id = unit.unit_id
		_hp_controller.apply_damage(victim_id, volley_damage,
			ResolveModifiers.AttackType.PHYSICAL, [&"skill"] as Array[StringName])
		_damage_dealt_by_unit[unit.unit_id] = \
			_damage_dealt_by_unit.get(unit.unit_id, 0) + volley_damage
		damage_applied.emit(unit.unit_id, victim_id, volley_damage)
		# Session-16: 황충's arrows are poison-tipped. Apply 3-turn poison DoT
		# to every hit target. The arrows hit alive units (gated above) and
		# apply_status enforces refresh semantics so re-hits stack correctly.
		_apply_status_with_signal(victim_id, &"poison", unit.unit_id)
		hit_count += 1
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.ATTACK if hit_count > 0 else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## 초선 charm: mirror of inspire on the enemy side. Marks every adjacent enemy
## who has NOT acted yet this round as already-acted, wasting their turn. Does
## NOT spend 초선's own ATK token — combo: charm two enemies, then attack a
## third with AMBUSH. Already-acted enemies are unaffected (the charm cannot
## "double-spend" a turn). Adjacent only (Manhattan-1) to keep the verb tied
## to positioning, not target select UI.
## Session-16: also applies SLOW (2-turn -20% atk + -1 move) so even acted
## enemies that aren't turn-stolen still suffer the debuff for their next turn.
func _skill_charm(unit: BattleUnit) -> bool:
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		if dx + dy != 1:
			continue  # adjacent only
		# SLOW always applies (whether the turn was wasted or not) — it's the
		# lasting effect that survives into next round.
		_apply_status_with_signal(victim.unit_id, &"slow", unit.unit_id)
		if _acted_this_turn.get(victim.unit_id, false):
			continue  # already acted; charm cannot waste a turn that's gone
		_acted_this_turn[victim.unit_id] = true
	return true


## Session-16 helper: apply_status with safety gate + signal emission.
## Centralizes the apply_status + signal pattern used by skill handlers.
## Skipped silently when _hp_controller doesn't support apply_status (legacy /
## stub paths — e.g., HPStatusControllerStub in unit tests).
func _apply_status_with_signal(unit_id: int, effect_id: StringName,
		source_unit_id: int) -> void:
	if _hp_controller == null or not _hp_controller.has_method("apply_status"):
		return
	var ok: bool = _hp_controller.apply_status(unit_id, effect_id, -1, source_unit_id)
	if ok:
		unit_status_applied.emit(unit_id, effect_id)


## 조조 strategist: 15 fixed damage to EVERY alive enemy on the map regardless
## of distance — the COMMANDER directs the full battle line to fire at once.
## Lower per-hit than thunder_roar/piercing_volley but battlefield-scoped, so
## total output scales with enemy count rather than positioning. Spends ATK.
## Currently dormant in MVP (조조 is enemy-side in ch1/ch3; player-side use_skill
## gate blocks enemy fire) — wired defensively so a future "join Wei" branch
## or boss-converts-mid-battle event becomes plug-and-play.
func _skill_strategist(unit: BattleUnit) -> bool:
	var strategist_damage: int = 15  # BalanceConstant candidate; inline for v1
	var any_hit: bool = false
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		_last_attacker_id = unit.unit_id
		_hp_controller.apply_damage(victim.unit_id, strategist_damage,
			ResolveModifiers.AttackType.PHYSICAL, [&"skill"] as Array[StringName])
		_damage_dealt_by_unit[unit.unit_id] = \
			_damage_dealt_by_unit.get(unit.unit_id, 0) + strategist_damage
		damage_applied.emit(unit.unit_id, victim.unit_id, strategist_damage)
		any_hit = true
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.ATTACK if any_hit else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## 주유 naval_strategy (책략): STUN every Manhattan-1 enemy. Two-phase tempo
## theft — not-yet-acted victims lose their current-round turn (immediate
## _acted_this_turn flip); already-acted victims get _pending_stun so their
## NEXT turn force-WAITs via _on_turn_runner_action_request. Visual STUN badge
## ("기") shown on every affected victim regardless of phase. Does NOT spend
## caster ATK token — STRATEGIST plays utility/tempo, then can still attack.
## Mirror of charm's adjacency + no-caster-ATK pattern but with cross-round
## lock instead of in-round SLOW debuff.
func _skill_naval_strategy(unit: BattleUnit) -> bool:
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		if dx + dy != 1:
			continue  # adjacent only
		_apply_status_with_signal(victim.unit_id, &"stun", unit.unit_id)
		if not _acted_this_turn.get(victim.unit_id, false):
			# Steal the current-round turn directly
			_acted_this_turn[victim.unit_id] = true
		else:
			# Already acted — lock their NEXT turn via _pending_stun gate
			_pending_stun[victim.unit_id] = true
	return true


## S86 G2 — 제갈량 (STRATEGIST) skill_fire_strategy: 박망파/적벽 화공 narrative.
## 20 fixed damage + slow status to every alive enemy within Manhattan ≤ 3 of
## caster. Spends ATK token (terminal action). Differs from skill_strategist
## (조조, battlefield-wide 15 damage no status) by trading map-coverage for
## range-3 + slow debuff — strategists with positional flair.
func _skill_fire_strategy(unit: BattleUnit) -> bool:
	var fire_damage: int = 20
	var fire_range: int = 3
	var any_hit: bool = false
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		if dx + dy > fire_range:
			continue
		_last_attacker_id = unit.unit_id
		_hp_controller.apply_damage(victim.unit_id, fire_damage,
			ResolveModifiers.AttackType.MAGICAL, [&"skill"] as Array[StringName])
		_damage_dealt_by_unit[unit.unit_id] = \
			_damage_dealt_by_unit.get(unit.unit_id, 0) + fire_damage
		damage_applied.emit(unit.unit_id, victim.unit_id, fire_damage)
		_apply_status_with_signal(victim.unit_id, &"slow", unit.unit_id)
		any_hit = true
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.ATTACK if any_hit else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## S86 G2 — 조운 (SCOUT/CAVALRY) skill_lone_lance: 단신 돌격 narrative. Pending
## flag pattern (mirror of dragon_blade) BUT conditional: +75% multiplier only
## applies when 조운 has zero adjacent allies (8-neighbor) at attack resolution.
## If lone-ness fails the pending is consumed silently. ATK token NOT spent.
func _skill_lone_lance(unit: BattleUnit) -> bool:
	_lone_lance_pending[unit.unit_id] = true
	return true


## S86 G2 — 마초 (CAVALRY) skill_xiliang_charge: 서량 기병 돌파 narrative.
## Cross-shape AoE — 20 damage to enemies on any cardinal axis (dx == 0 OR
## dy == 0) within Manhattan ≤ 3. Diagonal-only positions immune. Spends ATK.
## Differs from thunder_roar (장비 adjacency ring) + fire_strategy (제갈량
## full disc) by being axis-restricted line-shaped damage.
func _skill_xiliang_charge(unit: BattleUnit) -> bool:
	var charge_damage: int = 20
	var charge_range: int = 3
	var any_hit: bool = false
	for victim: BattleUnit in _units.values():
		if victim.side == unit.side:
			continue
		if not _hp_controller.is_alive(victim.unit_id):
			continue
		var dx: int = absi(victim.position.x - unit.position.x)
		var dy: int = absi(victim.position.y - unit.position.y)
		if dx != 0 and dy != 0:
			continue
		if dx + dy > charge_range or dx + dy < 1:
			continue
		_last_attacker_id = unit.unit_id
		_hp_controller.apply_damage(victim.unit_id, charge_damage,
			ResolveModifiers.AttackType.PHYSICAL, [&"skill"] as Array[StringName])
		_damage_dealt_by_unit[unit.unit_id] = \
			_damage_dealt_by_unit.get(unit.unit_id, 0) + charge_damage
		damage_applied.emit(unit.unit_id, victim.unit_id, charge_damage)
		any_hit = true
	_acted_this_turn[unit.unit_id] = true
	if _turn_runner != null and _turn_runner.has_method("declare_action"):
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.ATTACK if any_hit else TurnOrderRunner.ActionType.WAIT,
			null)
	return true


## S86 G2 — 강유 (STRATEGIST) skill_successor_strategy: 제갈량 후계자 narrative.
## Pick the lowest-HP alive ally within Manhattan ≤ 4 of caster (excluding
## caster). Heal 25 HP + refund their action token. Differs from inspire
## (유비 adjacent-all refund only) by trading width for depth — single target
## gets BOTH heal + refund. Does NOT spend caster ATK token (tempo skill).
func _skill_successor_strategy(unit: BattleUnit) -> bool:
	var heal_amount: int = 25
	var support_range: int = 4
	var best_ally: BattleUnit = null
	var best_hp_deficit: int = -1
	for ally: BattleUnit in _units.values():
		if ally.side != unit.side:
			continue
		if ally.unit_id == unit.unit_id:
			continue
		if not _hp_controller.is_alive(ally.unit_id):
			continue
		var dx: int = absi(ally.position.x - unit.position.x)
		var dy: int = absi(ally.position.y - unit.position.y)
		if dx + dy > support_range:
			continue
		var current_hp: int = _hp_controller.get_current_hp(ally.unit_id) if _hp_controller.has_method("get_current_hp") else 0
		var max_hp: int = _hp_controller.get_max_hp(ally.unit_id) if _hp_controller.has_method("get_max_hp") else current_hp
		var deficit: int = max_hp - current_hp
		if deficit > best_hp_deficit:
			best_hp_deficit = deficit
			best_ally = ally
	if best_ally == null:
		return true
	if _hp_controller.has_method("apply_heal"):
		_hp_controller.apply_heal(best_ally.unit_id, heal_amount, unit.unit_id)
	_acted_this_turn[best_ally.unit_id] = false
	return true


## Player-path DEFEND declaration. Mirrors AI-path semantics: spend the
## ACTION token via TurnOrderRunner + apply the defend_stance status so the
## 50% incoming damage reduction actually fires. Re-entrancy guard mirrors
## the move/attack handlers.
func _handle_player_defend(unit_id: int) -> void:
	if _active_turn_unit_id != -1 and unit_id != _active_turn_unit_id:
		return  # not this unit's turn
	if _acted_this_turn.get(unit_id, false):
		return  # already used the ACTION token this turn
	if not _units.has(unit_id):
		return  # defensive
	_acted_this_turn[unit_id] = true
	_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.DEFEND, null)
	_apply_defend_stance_status(unit_id)


## Per ADR-0014 §Amendment 2026-05-10 (#2 — player-path mirror).
## Mirrors AI-path bypass for the attack action.
func _handle_player_attack(attacker_id: int, defender_id: int) -> void:
	if _active_turn_unit_id != -1 and attacker_id != _active_turn_unit_id:
		return  # not this unit's turn — declare would silent-fail anyway; reject early
	if _acted_this_turn.get(attacker_id, false):
		return  # re-entrancy guard
	if not _units.has(attacker_id) or not _units.has(defender_id):
		return  # defensive — shouldn't happen if dispatch is correct
	# Skip dead defender — corpses stay in _units (we read .position for visuals
	# and the death animation, plus the unit_id remains stable for fate tracking)
	# but they MUST NOT be re-attackable. Pre-fix the player could click a dead
	# unit's tile and HPStatusController.apply_damage push_warning'd
	# "apply_damage on dead/unknown unit_id N" — turn was consumed for nothing.
	if _hp_controller != null and not _hp_controller.is_alive(defender_id):
		return  # silent — defender already dead, no turn consumed
	var attacker: BattleUnit = _units[attacker_id]
	var defender: BattleUnit = _units[defender_id]
	if not is_tile_in_attack_range(defender.position, attacker_id):
		return  # invalid target — silent
	_resolve_attack(attacker, defender)
	_acted_this_turn[attacker_id] = true
	_turn_runner.declare_action(attacker_id, TurnOrderRunner.ActionType.ATTACK,
		_make_attack_target(defender_id))


## Handles a move action per story-004 AC-3: validates via is_tile_in_move_range,
## applies via _do_move, consumes the unit's turn action via _consume_unit_action.
## Re-entrancy guard per AC-8: silent no-op if unit already acted this turn.
##
## Signature uses BattleUnit (not unit_id) per story-004 AC-3 — caller in
## handle_grid_click resolves unit_id → BattleUnit before dispatch.
func _handle_move(unit: BattleUnit, dest: Vector2i) -> void:
	if _acted_this_turn.get(unit.unit_id, false):
		return  # AC-8 re-entrancy guard
	if not is_tile_in_move_range(dest, unit.unit_id):
		return  # invalid target — silent (validation already happened at dispatch
		        # but this defense is per AC-3: _handle_move validates internally)
	_do_move(unit, dest)
	_consume_unit_action(unit.unit_id)  # story-006 stub


## Handles an attack action per story-005 AC-2: validates via is_tile_in_attack_range,
## runs _resolve_attack chain (multipliers + DamageCalc + HPStatusController),
## consumes the unit's turn action via _consume_unit_action.
##
## DEVIATION from ADR-0014 §5 step 9: apply_death_consequences NOT called —
## the method does not exist on shipped HPStatusController; DEMORALIZED
## propagation auto-fires inside HPStatusController.apply_damage via
## _propagate_demoralized_radius (private). ADR-0014 Implementation Notes
## amended same-patch documenting the drift.
func _handle_attack(attacker_id: int, defender_id: int) -> void:
	if _acted_this_turn.get(attacker_id, false):
		return  # re-entrancy guard (mirrors story-004 _handle_move pattern)
	if not _units.has(attacker_id) or not _units.has(defender_id):
		return  # defensive — shouldn't happen if dispatch is correct
	# Dead-defender guard — mirror of the player-path check in
	# _handle_player_attack. AI snapshot can stale-vote a target that just died
	# this frame; without this guard apply_damage warns + the attacker's turn
	# is consumed for a no-op.
	if _hp_controller != null and not _hp_controller.is_alive(defender_id):
		return
	var attacker: BattleUnit = _units[attacker_id]
	var defender: BattleUnit = _units[defender_id]
	if not is_tile_in_attack_range(defender.position, attacker_id):
		return  # invalid target — silent
	_resolve_attack(attacker, defender)
	_consume_unit_action(attacker_id)


# ─── Action implementations (story-004) ──────────────────────────────────────

## Applies a move per story-004 AC-4: updates position + facing + MapGrid
## occupancy bookkeeping + emits unit_moved AFTER all mutations complete (AC-5).
##
## Sole-writer of unit.position + unit.facing per ADR-0014 §3 (story-002
## sole-writer contract on _units extends to BattleUnit field mutations during
## battle). MapGrid occupancy bookkeeping per shipped clear_occupant +
## set_occupant API contract (strict-sync per §EC-6 — clear before set).
func _do_move(unit: BattleUnit, dest: Vector2i) -> void:
	var old_pos: Vector2i = unit.position
	if dest == old_pos:
		return  # no-op move — don't churn occupancy bookkeeping
	# Pre-flight: destination must be vacant (the AI snapshot can stale-vote a
	# tile that another unit moved into in the same frame). Without this guard
	# _map_grid.set_occupant raises ERR_ILLEGAL_STATE_TRANSITION and the unit
	# ends up at dest in unit data but with clear_occupant'd old_pos in map_grid.
	# Use tile_state (not occupant_id) — occupant_id == 0 ambiguously means both
	# "empty" AND "occupied by unit 0" (the commander has id 0).
	var dest_tile: MapTileData = _map_grid.get_tile(dest)
	if dest_tile != null and (dest_tile.tile_state == MapGrid.TILE_STATE_ALLY_OCCUPIED \
			or dest_tile.tile_state == MapGrid.TILE_STATE_ENEMY_OCCUPIED):
		return  # tile occupied; silent reject (caller's range check was stale)
	# 1. MapGrid occupancy clear (must precede set per strict-sync EC-6)
	_map_grid.clear_occupant(old_pos)
	# 2. Mutate unit fields
	unit.position = dest
	unit.facing = _direction_from_to(old_pos, dest)
	# 3. MapGrid occupancy set with faction derived from side (0→ALLY, 1→ENEMY)
	var faction: int = MapGrid.FACTION_ALLY if unit.side == 0 else MapGrid.FACTION_ENEMY
	_map_grid.set_occupant(dest, unit.unit_id, faction)
	# 4. Emit unit_moved signal AFTER position update per AC-5
	unit_moved.emit(unit.unit_id, old_pos, dest)
	# Session-31 — REACH_TILE WIN check fires here (post-position-update).
	# Cheap no-op for the non-REACH_TILE branches; cheap dict lookup for
	# the REACH_TILE branch. Idempotent (re-checks on every move — once
	# _battle_over is true the helper short-circuits via _check_battle_end's
	# guard pattern).
	_check_reach_tile_victory()


## Computes cardinal facing (0=N, 1=E, 2=S, 3=W) from movement vector per
## chapter-prototype pattern. Larger axis wins; on tie, X-axis wins.
## Used by _do_move (story-004) and consumed by _attack_angle (story-005).
func _direction_from_to(from: Vector2i, to: Vector2i) -> int:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if absi(dx) >= absi(dy):
		return 1 if dx > 0 else 3  # E or W
	return 2 if dy > 0 else 0  # S or N


## Marks the unit as having acted this turn + spends action token via
## TurnOrderRunner + deselects + auto-handoff if all player units acted.
## Per ADR-0014 §6 + story-006 AC-1..AC-4.
##
## DEVIATION from ADR-0014 §6 sketch (drift #9 — see Implementation Notes
## amendment): sketch shows `_turn_runner.spend_action_token(unit_id)` but the
## shipped TurnOrderRunner public API is `declare_action(unit_id, action,
## target) -> ActionResult` per ADR-0011 §Key Interfaces. Map to
## ActionType.ATTACK for the MVP single-token simplification — when full
## Contract 4 (move + action token split) lands post-MVP, only this single
## call site changes. ActionTarget is null for MVP per ADR-0011 story-004
## "ActionTarget validation deferred to story-007+".
func _consume_unit_action(unit_id: int) -> void:
	_acted_this_turn[unit_id] = true
	# Single-token MVP: ATTACK token represents "this unit acted this turn"
	# regardless of whether the underlying action was a MOVE or ATTACK.
	_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.ATTACK, null)
	if _selected_unit_id != -1:
		_deselect()
	if not _any_player_unit_can_act():
		end_player_turn()


## Returns true if any player-side (side==0) alive unit has NOT acted this turn.
## Per ADR-0014 §6 + story-006 AC-3. Used by _consume_unit_action for the
## auto-handoff gate (AC-4): all-player-units-acted → end_player_turn.
##
## Dead-unit exclusion via _hp_controller.is_alive(unit_id) per Implementation
## Notes #4 (`is_alive` is canonical query per shipped HPStatusController:219;
## `is_dead` is NOT a shipped API — drift catalogued at ADR-0014 review).
func _any_player_unit_can_act() -> bool:
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue  # only player-side units count for the handoff gate
		if not _hp_controller.is_alive(unit.unit_id):
			continue  # dead units excluded per Implementation Notes #4
		if not _acted_this_turn.get(unit.unit_id, false):
			return true
	return false


# ─── Combat resolution helpers (story-005) ──────────────────────────────────

## Counts same-side non-dead units within Manhattan distance 1 of the given unit.
## Per ADR-0014 §5 + story-005 AC-4. Used by _compute_formation_mult and by
## _on_round_started (story-008 _fate_formation_turns counter).
func _count_adjacent_allies(unit: BattleUnit) -> int:
	var count: int = 0
	for other: BattleUnit in _units.values():
		if other.unit_id == unit.unit_id:
			continue  # skip self
		if other.side != unit.side:
			continue  # skip enemies
		if not _hp_controller.is_alive(other.unit_id):
			continue  # skip dead units
		var dx: int = absi(other.position.x - unit.position.x)
		var dy: int = absi(other.position.y - unit.position.y)
		if dx + dy == 1:  # Manhattan adjacency
			count += 1
	return count


## Returns true if any same-side non-dead unit with passive == &"command_aura"
## (유비) is within Manhattan distance 1 of the attacker. Per ADR-0014 §5 +
## story-005 AC-5.
func _has_adjacent_command_aura(attacker: BattleUnit) -> bool:
	for other: BattleUnit in _units.values():
		if other.unit_id == attacker.unit_id:
			continue
		if other.side != attacker.side:
			continue
		if not _hp_controller.is_alive(other.unit_id):
			continue
		if other.passive != &"command_aura":
			continue
		var dx: int = absi(other.position.x - attacker.position.x)
		var dy: int = absi(other.position.y - attacker.position.y)
		if dx + dy == 1:
			return true
	return false


## Classifies the attack angle relative to defender's facing per ADR-0014 §5
## step 3 + story-005 AC-3. Returns "front" / "side" / "rear".
##
## attacker_dir is the cardinal direction FROM defender TO attacker (i.e., where
## the attacker is sitting from the defender's perspective). If attacker is in
## the direction the defender is FACING → "front". If attacker is BEHIND the
## defender (opposite direction of facing) → "rear". Otherwise → "side".
func _attack_angle(attacker: BattleUnit, defender: BattleUnit) -> String:
	var attacker_dir: int = _direction_from_to(defender.position, attacker.position)
	if attacker_dir == defender.facing:
		return "front"
	if attacker_dir == (defender.facing + 2) % 4:
		return "rear"
	return "side"


## Computes formation multiplier per chapter-prototype shape + ADR-0014 §5 step 2:
## 1.0 + 0.05 * adjacent_ally_count, capped at 1.20 (max 4 adjacent contributing).
func _compute_formation_mult(attacker: BattleUnit) -> float:
	var formation_count: int = _count_adjacent_allies(attacker)
	return minf(1.0 + 0.05 * float(formation_count), 1.20)


## Computes angle multiplier per chapter-prototype shape + ADR-0014 §5 step 4:
## front=1.00, side=1.25, rear=1.50, rear+rear_specialist passive (황충)=1.75.
func _compute_angle_mult(attacker: BattleUnit, defender: BattleUnit) -> float:
	var angle: String = _attack_angle(attacker, defender)
	match angle:
		"side":
			return 1.25
		"rear":
			if attacker.passive == &"rear_specialist":
				return 1.75
			return 1.50
		_:
			return 1.0  # front (default)


## Computes aura multiplier per chapter-prototype shape + ADR-0014 §5 step 5:
## 1.15 if any 유비 (command_aura passive) ally is adjacent to attacker, else 1.0.
func _compute_aura_mult(attacker: BattleUnit) -> float:
	if _has_adjacent_command_aura(attacker):
		return 1.15
	return 1.0


## S72 Synergy adjacency — hero-specific bonds. Computed on-demand from
## 4-directional adjacency (4 tile checks, cheap, no caching).
##
## Rules (v1 pilot):
##   - Peach Garden Bond (유비/관우/장비 trio): when ANY 2+ of them are
##     4-dir adjacent, all involved get +5 ATK
##   - Lone Wolf (위연): when no allies are 4-dir adjacent, +5 ATK
##   - Strategist's Counsel (방통): adjacent allies (and 방통 himself if
##     adjacent to any ally) get +3 DEF
const _PEACH_GARDEN_TRIO: Dictionary = {
	&"shu_001_liu_bei":   true,
	&"shu_002_guan_yu":   true,
	&"shu_003_zhang_fei": true,
}


## ATK bonus for `unit` from synergy adjacency. Adds to raw_atk before
## DamageCalc.resolve. 0 if no synergy active.
func _compute_synergy_atk_bonus(unit: BattleUnit) -> int:
	if unit == null or _hp_controller == null:
		return 0
	if not _hp_controller.is_alive(unit.unit_id):
		return 0
	var allies: Array[BattleUnit] = _adjacent_allies(unit)
	var bonus: int = 0
	var reason: String = ""
	# Peach Garden Bond
	if _PEACH_GARDEN_TRIO.has(unit.hero_id):
		for ally: BattleUnit in allies:
			if _PEACH_GARDEN_TRIO.has(ally.hero_id):
				bonus += 5
				reason = "Peach Garden Bond (ally=%s)" % ally.hero_id
				break  # cap +5 even if 2 brothers adjacent
	# Lone Wolf — 위연
	if unit.hero_id == &"shu_009_wei_yan" and allies.is_empty():
		bonus += 5
		reason = "Lone Wolf"
	if _SYNERGY_TRACE_ENABLED and bonus > 0:
		print("[SYNERGY] hero=%s raw_atk=%d synergy_atk=+%d total=%d reason='%s'" %
			[unit.hero_id, unit.raw_atk, bonus, unit.raw_atk + bonus, reason])
	return bonus


## DEF bonus for `unit` from synergy adjacency. Adds to raw_def before
## DefenderContext.make. 0 if no synergy active.
func _compute_synergy_def_bonus(unit: BattleUnit) -> int:
	if unit == null or _hp_controller == null:
		return 0
	if not _hp_controller.is_alive(unit.unit_id):
		return 0
	var allies: Array[BattleUnit] = _adjacent_allies(unit)
	var bonus: int = 0
	var reason: String = ""
	var is_pang_tong: bool = unit.hero_id == &"shu_007_pang_tong"
	if is_pang_tong:
		# 방통 self-buff when adjacent to any ally
		if not allies.is_empty():
			bonus += 3
			reason = "Strategist's Counsel (self, ally=%s)" % allies[0].hero_id
	else:
		# Ally check for 방통 in adjacency
		for ally: BattleUnit in allies:
			if ally.hero_id == &"shu_007_pang_tong":
				bonus += 3
				reason = "Strategist's Counsel (from 방통)"
				break
	if _SYNERGY_TRACE_ENABLED and bonus > 0:
		print("[SYNERGY] hero=%s raw_def=%d synergy_def=+%d total=%d reason='%s'" %
			[unit.hero_id, unit.raw_def, bonus, unit.raw_def + bonus, reason])
	return bonus


## S73 Synergy v2 — returns {unit_id: badge_chars} for all alive units. Empty
## string for units without active synergy. Chars concat possible:
## '義' Peach Garden trio (mutual adj), '策' 방통 Counsel (self or recipient),
## '獨' 위연 Lone Wolf (no adj ally). Pure read — call after any adjacency-
## changing event (spawn / move / kill / death).
func compute_synergy_badges() -> Dictionary:
	var result: Dictionary = {}
	if _hp_controller == null:
		return result
	for u: BattleUnit in _units.values():
		if not _hp_controller.is_alive(u.unit_id):
			result[u.unit_id] = ""
			continue
		var allies: Array[BattleUnit] = _adjacent_allies(u)
		var chars: String = ""
		# Peach Garden — any 4-adj ally also in trio
		if _PEACH_GARDEN_TRIO.has(u.hero_id):
			for ally: BattleUnit in allies:
				if _PEACH_GARDEN_TRIO.has(ally.hero_id):
					chars += "義"
					break
		# 방통 Counsel — 방통 self when adj to any ally, OR non-방통 with 방통 adj
		if u.hero_id == &"shu_007_pang_tong":
			if not allies.is_empty():
				chars += "策"
		else:
			for ally: BattleUnit in allies:
				if ally.hero_id == &"shu_007_pang_tong":
					chars += "策"
					break
		# Lone Wolf — 위연 with 0 adj allies
		if u.hero_id == &"shu_009_wei_yan" and allies.is_empty():
			chars += "獨"
		result[u.unit_id] = chars
	return result


## 4-directional adjacent allies (same side, alive).
func _adjacent_allies(unit: BattleUnit) -> Array[BattleUnit]:
	var allies: Array[BattleUnit] = []
	if unit == null or _hp_controller == null:
		return allies
	for u: BattleUnit in _units.values():
		if u.unit_id == unit.unit_id or u.side != unit.side:
			continue
		if not _hp_controller.is_alive(u.unit_id):
			continue
		var d: Vector2i = u.position - unit.position
		if absi(d.x) + absi(d.y) == 1:
			allies.append(u)
	return allies


## Maps controller-local angle string to ResolveModifiers.direction_rel StringName
## per ADR-0012 ResolveModifiers contract: {FRONT, FLANK, REAR}.
##
## NOTE: ADR-0014 §5 uses "side" terminology; ADR-0012 ResolveModifiers uses
## "FLANK" StringName. They map 1:1 — translation lives at controller-DamageCalc
## boundary per Migration Plan §13.
func _angle_to_direction_rel(angle: String) -> StringName:
	match angle:
		"front":
			return &"FRONT"
		"side":
			return &"FLANK"
		"rear":
			return &"REAR"
		_:
			return &"FRONT"  # defensive default


## Runs the full attack resolve chain per ADR-0014 §5 + story-005 AC-2:
## 1. Compute formation_mult (±0..0.20)
## 2. Compute angle ("front"/"side"/"rear")
## 3. Compute angle_mult (1.0/1.25/1.50/1.75)
## 4. Compute aura_mult (1.0/1.15)
## 5. Construct AttackerContext + DefenderContext + ResolveModifiers
## 6. Call DamageCalc.resolve → ResolveResult (consumes RNG once for evasion roll)
## 7. Post-multiply controller-side multipliers (angle_mult × aura_mult — NOT
##    consumed by DamageCalc; formation_atk_bonus IS consumed via P_mult formula)
## 8. Track _last_attacker_id for story-008 fate-counter attribution
## 9. Track rear-attack fate counter (story-008 partial — ADR-0014 §5 step 6 +
##    grid-battle.md §198 hook for Destiny Branch)
## 10. _hp_controller.apply_damage (4-param signature per ADR-0010 + ADR-0014 §10)
## 11. Emit damage_applied(attacker_id, defender_id, damage)
##
## Returns the final damage dealt (post-multipliers); 0 on MISS.
##
## DEVIATION from ADR-0014 §5 step 9: apply_death_consequences NOT called —
## method not on shipped HPStatusController; DEMORALIZED propagation is internal
## to apply_damage via _propagate_demoralized_radius. Documented in commit +
## ADR-0014 Implementation Notes amendment.
func _resolve_attack(attacker: BattleUnit, defender: BattleUnit) -> int:
	# Stage 1: compute multipliers
	var formation_mult: float = _compute_formation_mult(attacker)
	var angle: String = _attack_angle(attacker, defender)
	var angle_mult: float = _compute_angle_mult(attacker, defender)
	var aura_mult: float = _compute_aura_mult(attacker)

	# Stage 2: build DamageCalc inputs
	var passives: Array[StringName] = []
	if attacker.passive != &"":
		passives.append(attacker.passive)
	# Session-13: query TurnOrderRunner for charge eligibility. CAVALRY units
	# that moved >= CHARGE_THRESHOLD (40 cost ≈ 4 flat tiles) get +20% bonus
	# via DamageCalc._charge_factor (which gates on class + passive + flag).
	# Defensive: turn_runner is null in some test rigs.
	var charge_active: bool = false
	if _turn_runner != null and _turn_runner.has_method("is_unit_charge_eligible"):
		charge_active = _turn_runner.is_unit_charge_eligible(attacker.unit_id)
	# Session-15: query MapGrid for terrain at attacker's tile. HILLS (terrain_type=2)
	# unlocks the ARCHER HIGH_GROUND_BONUS via DamageCalc._high_ground_factor (which
	# also gates on class + passive + not-counter).
	var on_high_ground: bool = _is_unit_on_high_ground(attacker)
	# S72 Synergy — adjacency bond bonuses additive on raw_atk / raw_def
	# (Peach Garden +5 ATK / Lone Wolf +5 ATK / 방통 Counsel +3 DEF).
	var synergy_atk: int = _compute_synergy_atk_bonus(attacker)
	var synergy_def: int = _compute_synergy_def_bonus(defender)
	var attacker_ctx: AttackerContext = AttackerContext.make(
		attacker.hero_id,
		attacker.unit_class,
		attacker.raw_atk + synergy_atk,
		charge_active,
		false,  # defend_stance_active (attacker side; MVP doesn't defend then attack)
		passives,
		on_high_ground,
	)
	# Phase 2 위연 skill_rebel_charge: pierces defender DEF when pending.
	# Flag read here (not later) so the DEF=0 propagates through DamageCalc's
	# Stage 1 raw-damage formula. Cleared at the post-resolve site below
	# alongside the +50% multiplier (one-shot). Synergy DEF additive on top
	# of raw_def — rebel_charge bypasses ALL DEF (including synergy +3).
	var rebel_charge_active: bool = _rebel_charge_pending.get(attacker.unit_id, false)
	var defender_def_input: int = 0 if rebel_charge_active else (defender.raw_def + synergy_def)
	var defender_ctx: DefenderContext = DefenderContext.make(
		defender.hero_id,
		defender_def_input,
		0,  # terrain_def — MVP no terrain bonus
		0,  # terrain_evasion — MVP no evasion
	)
	# Session-14: real round_number from TurnOrderRunner unlocks AMBUSH_BONUS gate
	# (DamageCalc._ambush_factor requires round_number >= 2). Defensive against
	# null runner in early-init test rigs.
	var round_number: int = _turn_runner.get_current_round_number() if _turn_runner != null else 1
	if round_number < 1:
		round_number = 1
	# S90 Phase B step 5: consume pending_buff before make() — magnitude flows
	# into ResolveModifiers, attacker.pending_buff cleared (or kept at {} if no
	# active buff). Cleared regardless of HIT/MISS — "spent at resolve time"
	# per strategy-systems.md v0.3 §4.2.
	var buff_magnitude: float = _resolve_pending_buff_magnitude(attacker.unit_id)
	var modifiers: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL,
		_rng,
		_angle_to_direction_rel(angle),
		round_number,
		false,  # is_counter — MVP no counter (counter is forecast-only in production)
		"",  # skill_id — MVP no skills
		[],  # source_flags — populated by DamageCalc
		0.0,  # rally_bonus — COMMANDER 의 ally buff 는 _compute_aura_mult (+15% post-resolve) 로 이미 구현됨 (command_aura passive). unit-role.md 의 passive_rally 스펙 (+5%/+10% stacking) 과 number/naming 다르지만 같은 mechanical role. 통합은 별도 balance-tuning 작업.
		formation_mult - 1.0,  # formation_atk_bonus (consumed by DamageCalc P_mult)
		0.0,  # formation_def_bonus — MVP no def bonus
		Callable(self, "_unit_acted_this_turn"),  # AMBUSH_BONUS gate (session-14)
		buff_magnitude,  # S90 strategy-systems strength_scroll pending_buff_magnitude
	)
	# Set NEW story-005 fields (not in make() factory yet — additive same-patch).
	# These are CONTROLLER-side post-multipliers (NOT consumed by DamageCalc).
	modifiers.angle_mult = angle_mult
	modifiers.aura_mult = aura_mult

	# Stage 3: track attacker for story-008 fate-counter attribution
	_last_attacker_id = attacker.unit_id

	# Stage 4: call DamageCalc.resolve
	var result: ResolveResult = DamageCalc.resolve(attacker_ctx, defender_ctx, modifiers)
	var base_damage: int = result.resolved_damage  # 0 on MISS; 1+ on HIT

	# Stage 5: apply controller-side post-multipliers (angle_mult × aura_mult).
	# NOTE: formation_atk_bonus already consumed by DamageCalc in P_mult formula.
	var final_damage: int = roundi(float(base_damage) * angle_mult * aura_mult)
	# Session-15 commit 5: dragon_blade buff (관우 skill) applies +50% damage to
	# the buffed unit's NEXT attack. Consumed on use — clears the pending flag
	# AND marks skill_used so the unit can't re-trigger via a clear-and-refire
	# loop. Stage 5 placement chosen so the +50% multiplies the post-direction /
	# post-aura number (the same number the forecast shows).
	if _dragon_blade_pending.get(attacker.unit_id, false) and result.kind == ResolveResult.Kind.HIT:
		final_damage = roundi(float(final_damage) * 1.50)
		_dragon_blade_pending[attacker.unit_id] = false
	# Phase 2 위연 skill_rebel_charge: +50% post-damage (in addition to the
	# DEF=0 bypass already applied at DefenderContext build above). Same +50%
	# coefficient as dragon_blade; differentiation comes from the DEF pierce.
	if rebel_charge_active and result.kind == ResolveResult.Kind.HIT:
		final_damage = roundi(float(final_damage) * 1.50)
		_rebel_charge_pending[attacker.unit_id] = false
	# S86 G2 조운 skill_lone_lance: +75% post-damage IF caster has zero adjacent
	# allies at this resolution moment (8-neighbor). Pending consumed regardless
	# of whether lone-ness gate passed — one-shot is gone after the swing.
	if _lone_lance_pending.get(attacker.unit_id, false) and result.kind == ResolveResult.Kind.HIT:
		var alone: bool = true
		for ally: BattleUnit in _units.values():
			if ally.side != attacker.side:
				continue
			if ally.unit_id == attacker.unit_id:
				continue
			if not _hp_controller.is_alive(ally.unit_id):
				continue
			var ady: int = absi(ally.position.y - attacker.position.y)
			var adx: int = absi(ally.position.x - attacker.position.x)
			if adx <= 1 and ady <= 1:
				alone = false
				break
		if alone:
			final_damage = roundi(float(final_damage) * 1.75)
		_lone_lance_pending[attacker.unit_id] = false
	if result.kind == ResolveResult.Kind.HIT and final_damage < 1:
		final_damage = 1  # ensure HIT delivers minimum 1 damage post-rounding

	# Stage 6: rear-attack fate counter (story-008 partial — full impl in story-008)
	if angle == "rear":
		_fate_rear_attacks += 1
		hidden_fate_condition_progressed.emit(&"rear_attacks", _fate_rear_attacks)

	# Stage 6.5 — S72 Critical chain bonus. CRIT-only (angle == "rear"). Apply
	# BEFORE Stage 7 so the boosted number reaches HP apply + DamagePopup + the
	# critical_hit_landed feedback. Per-side chain accumulates across the round
	# (reset at _on_round_started). chain_level captured here is passed to
	# critical_hit_landed below so the popup can render the chain badge.
	var crit_chain_level: int = 0
	if angle == "rear" and result.kind == ResolveResult.Kind.HIT:
		_critical_chain_per_side[attacker.side] = \
			_critical_chain_per_side.get(attacker.side, 0) + 1
		crit_chain_level = _critical_chain_per_side[attacker.side]
		var chain_bonus: float = _critical_chain_bonus_for(crit_chain_level)
		var pre_chain_damage: int = final_damage
		if chain_bonus > 0.0:
			final_damage = int(roundi(float(final_damage) * (1.0 + chain_bonus)))
			if final_damage < 1:
				final_damage = 1
		if _CRIT_CHAIN_TRACE_ENABLED:
			print("[CRIT-CHAIN] side=%d level=%d +%d%% damage %d→%d attacker=%s" %
				[attacker.side, crit_chain_level, int(chain_bonus * 100.0),
				pre_chain_damage, final_damage, attacker.hero_id])
		critical_chain_changed.emit(attacker.side, crit_chain_level)

	# Stage 7: apply via HPStatusController (sole writer of HP per ADR-0010)
	_hp_controller.apply_damage(defender.unit_id, final_damage, modifiers.attack_type, modifiers.source_flags)

	# Session-15 commit 4: accumulate damage credit for the result-screen MVP
	# label. Side-agnostic (both player and enemy damage tracked) — the UI
	# query in get_battle_stats() filters by side.
	if result.kind == ResolveResult.Kind.HIT and final_damage > 0:
		_damage_dealt_by_unit[attacker.unit_id] = \
			_damage_dealt_by_unit.get(attacker.unit_id, 0) + final_damage

	# Phase F — dmg_to_lubu (ch02 hidden destiny 시그니처). Accumulate damage
	# dealt to any unit with hero_id qun_001_lu_bu (여포). Chapter-agnostic by
	# hero_id; only ch02 enemy roster contains lu_bu as authored.
	if result.kind == ResolveResult.Kind.HIT and final_damage > 0 \
			and defender.hero_id == &"qun_001_lu_bu" and attacker.side == 0:
		_fate_dmg_to_lubu += final_damage
		hidden_fate_condition_progressed.emit(&"dmg_to_lubu", _fate_dmg_to_lubu)

	# Stage 8: emit damage_applied per ADR-0014 §8
	damage_applied.emit(attacker.unit_id, defender.unit_id, final_damage)

	# Session-16: critical-hit visual feedback gate. REAR hits already do +50%
	# damage via angle_mult; this signal lets the view layer surface that as
	# "치명타!" popup + camera shake + SFX so the player feels the flank payoff.
	# Gated on HIT + non-zero damage so MISS / 0-damage edge cases don't pop.
	if angle == "rear" and result.kind == ResolveResult.Kind.HIT and final_damage > 0:
		critical_hit_landed.emit(attacker.unit_id, defender.unit_id, final_damage, &"REAR", crit_chain_level)

	return final_damage


# ─── Attack preview (session-10 — 2-step attack flow) ─────────────────────────

## Returns a damage / direction / counter preview for the attacker→defender pair
## WITHOUT mutating any state. Used by the 2-step attack flow: BattleHUD renders
## this Dictionary into UI-GB-04 Combat Forecast on the first tap of an enemy;
## the second tap commits the real attack via _handle_player_attack.
##
## Determinism: uses a private throwaway RandomNumberGenerator so the production
## _rng's sequence is preserved (replay determinism per AC-DC-26). In MVP
## terrain evasion is always 0, so the preview RNG never affects damage output —
## DamageCalc.resolve's evasion roll is a deterministic miss only when
## terrain_evasion > 0, which no current scenario authors.
##
## Returned Dictionary shape:
##   direction: StringName — &"FRONT" / &"FLANK" / &"REAR" relative to defender
##   damage: int — final damage post angle_mult × aura_mult; 0 on MISS
##   hit_pct: int — 100 - clampi(terrain_evasion, 0, 30); always 100 in MVP
##   counter_damage: int — defender's reciprocal damage if eligible, else 0
##   counter_eligible: bool — true if defender CAN counter-attack
##   kind: int — ResolveResult.Kind (HIT=0, MISS=1)
##   passives: Array[StringName] — attacker passives fed into AttackerContext
##   angle_mult: float — controller-side post multiplier (1.00/1.25/1.50/1.75)
##   aura_mult: float — controller-side post multiplier (1.00/1.15)
##
## Empty Dictionary returned if either unit_id is unknown (defensive — UI hides).
func preview_attack(attacker_id: int, defender_id: int) -> Dictionary:
	if not _units.has(attacker_id) or not _units.has(defender_id):
		return {}
	var attacker: BattleUnit = _units[attacker_id]
	var defender: BattleUnit = _units[defender_id]
	# Stage 1: compute multipliers — mirror of _resolve_attack lines 1306-1310.
	var formation_mult: float = _compute_formation_mult(attacker)
	var angle: String = _attack_angle(attacker, defender)
	var angle_mult: float = _compute_angle_mult(attacker, defender)
	var aura_mult: float = _compute_aura_mult(attacker)
	var passives: Array[StringName] = []
	if attacker.passive != &"":
		passives.append(attacker.passive)
	# Session-13: mirror _resolve_attack's charge eligibility query so the
	# preview damage matches what the real attack will deal.
	var charge_active: bool = false
	if _turn_runner != null and _turn_runner.has_method("is_unit_charge_eligible"):
		charge_active = _turn_runner.is_unit_charge_eligible(attacker.unit_id)
	# Session-15: mirror _resolve_attack's high-ground query so the forecast
	# damage reflects HIGH_GROUND_BONUS when ARCHER is on HILLS.
	var on_high_ground: bool = _is_unit_on_high_ground(attacker)
	# Stage 2: DamageCalc contexts — same construction as _resolve_attack.
	# S72 Synergy bonus mirrored so forecast matches live damage.
	var synergy_atk: int = _compute_synergy_atk_bonus(attacker)
	var synergy_def: int = _compute_synergy_def_bonus(defender)
	var attacker_ctx: AttackerContext = AttackerContext.make(
		attacker.hero_id, attacker.unit_class, attacker.raw_atk + synergy_atk,
		charge_active, false, passives, on_high_ground)
	var defender_ctx: DefenderContext = DefenderContext.make(
		defender.hero_id, defender.raw_def + synergy_def, 0, 0)
	# Throwaway RNG — see docstring for determinism rationale. Uses a freshly
	# constructed RNG with default-randomized seed; preview never feeds back
	# into _rng so replay determinism on the production attack is preserved.
	var preview_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Session-14: mirror _resolve_attack's round_number + acted_this_turn callable
	# so the forecast reflects AMBUSH_BONUS when conditions are met.
	var round_number: int = _turn_runner.get_current_round_number() if _turn_runner != null else 1
	if round_number < 1:
		round_number = 1
	# S90 Phase B step 5: PEEK pending_buff magnitude for forecast — preview
	# must NOT consume the buff (player previewing damage shouldn't burn the
	# scroll). Read-only inline check; consumption happens only in _resolve_attack.
	var preview_buff_magnitude: float = 1.0
	if not attacker.pending_buff.is_empty():
		var expires_at: int = attacker.pending_buff.get(&"expires_at_turn", 0) as int
		if expires_at >= round_number:
			preview_buff_magnitude = attacker.pending_buff.get(&"magnitude", 1.0) as float
	var modifiers: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, preview_rng,
		_angle_to_direction_rel(angle), round_number, false, "", [], 0.0,
		formation_mult - 1.0, 0.0, Callable(self, "_unit_acted_this_turn"),
		preview_buff_magnitude)
	modifiers.angle_mult = angle_mult
	modifiers.aura_mult = aura_mult
	# Stage 4-5: resolve + apply controller-side multipliers (mirror of
	# _resolve_attack lines 1352-1360 — same math, same post-rounding floor).
	var result: ResolveResult = DamageCalc.resolve(attacker_ctx, defender_ctx, modifiers)
	var base_damage: int = result.resolved_damage
	var final_damage: int = roundi(float(base_damage) * angle_mult * aura_mult)
	if result.kind == ResolveResult.Kind.HIT and final_damage < 1:
		final_damage = 1
	# Defender status effects — listed as StringName effect_id tokens so the
	# UI can render localized labels via tr(). HPStatusController is null in
	# some test rigs (defensive); empty array is the safe default.
	var status_ids: Array[StringName] = _preview_collect_defender_status_ids(defender.unit_id)
	# Session-13: mirror HPStatusController's defend_stance reduction (line 117-118)
	# so the forecast number matches what the player will actually see post-attack.
	# Production damage flow applies this inside apply_damage; preview must match.
	if &"defend_stance" in status_ids and result.kind == ResolveResult.Kind.HIT:
		var reduction: float = BalanceConstants.get_const("DEFEND_STANCE_REDUCTION") as float
		final_damage = int(floor(float(final_damage) * (1.0 - reduction / 100.0)))
		final_damage = maxi(BalanceConstants.get_const("MIN_DAMAGE") as int, final_damage)
	# Counter preview: defender retaliates only if in attack range of attacker
	# AND has not already acted this turn. MVP no charge / no skill / standard
	# is_counter=true halves the resolved damage per CR-2 + AC-DC-20.
	var counter_eligible: bool = _preview_counter_eligible(attacker, defender)
	var counter_damage: int = 0
	if counter_eligible:
		counter_damage = _preview_counter_damage(defender, attacker)
	# MVP hit_pct: 100 - terrain_evasion. terrain_evasion is hardcoded to 0 in
	# MVP context construction; surfaces as a real read-out when terrain
	# bonuses ship. Negative defender.terrain_evasion is clamped per F-DC-2.
	var hit_pct: int = 100 - clampi(0, 0, 30)
	return {
		"direction": _angle_to_direction_rel(angle),
		"damage": final_damage,
		"hit_pct": hit_pct,
		"counter_damage": counter_damage,
		"counter_eligible": counter_eligible,
		"kind": int(result.kind),
		"passives": passives,
		"angle_mult": angle_mult,
		"aura_mult": aura_mult,
		"defender_status_ids": status_ids,
	}


## Collects the defender's active status effect IDs for the preview. Returns
## an empty typed array when HPStatusController is missing or the defender
## has no statuses. StatusEffect.effect_id is a StringName per ADR-0010.
func _preview_collect_defender_status_ids(defender_id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if _hp_controller == null:
		return result
	if not _hp_controller.has_method("get_status_effects"):
		return result
	var effects: Array = _hp_controller.get_status_effects(defender_id) as Array
	for effect_var: Variant in effects:
		if effect_var is StatusEffect:
			var e: StatusEffect = effect_var as StatusEffect
			if e.effect_id != &"":
				result.append(e.effect_id)
	return result


## Counter eligibility check for preview. Returns true if defender CAN
## counter-attack this attacker — i.e. defender is in attack-range of
## attacker's position AND defender has not already acted this turn AND
## the attacker is not firing AMBUSH (which suppresses the counter per
## unit-role.md §passive_ambush + grid-battle.md CR-2a, session-14).
## Mirrors the implicit logic the real counter pipeline would use (story-007+
## may formalize this into a dedicated counter eligibility resolver).
func _preview_counter_eligible(attacker: BattleUnit, defender: BattleUnit) -> bool:
	if _acted_this_turn.get(defender.unit_id, false):
		return false
	# Session-14: ambush conditions (SCOUT/ARCHER + passive_ambush + round>=2 +
	# defender not acted) suppress the counter. Same gating as
	# DamageCalc._ambush_factor — when ambush damage bonus fires, the target
	# also loses its counter-strike per the GDD's "cannot counter-attack" rule.
	if _is_ambush_active(attacker, defender):
		return false
	# Range check from defender → attacker (reciprocal of attacker → defender).
	return is_tile_in_attack_range(attacker.position, defender.unit_id)


## Adapter exposed as a Callable to DamageCalc via ResolveModifiers.acted_this_turn_callable.
## Returns true when the defender has already taken its terminal action this round
## (ATTACK/DEFEND/WAIT — see _acted_this_turn write sites). Read by
## DamageCalc._ambush_factor to gate AMBUSH_BONUS on a target who has not yet acted.
## Argument is `DefenderContext.unit_id` which is a StringName holding the hero_id —
## NOT the integer unit_id used by _acted_this_turn (see defender_context.gd:6).
## Performs a hero_id → BattleUnit → unit_id reverse lookup in _units.
func _unit_acted_this_turn(hero_id: StringName) -> bool:
	for unit: BattleUnit in _units.values():
		if unit.hero_id == hero_id:
			return _acted_this_turn.get(unit.unit_id, false)
	return false


## True when the attacker's would-be attack against the defender meets all
## AMBUSH conditions: class SCOUT or ARCHER, passive_ambush carried, round >= 2,
## defender has not yet acted this round. Mirrors the gating inside
## DamageCalc._ambush_factor so production code, preview, and counter-suppression
## stay aligned. Session-14.
func _is_ambush_active(attacker: BattleUnit, defender: BattleUnit) -> bool:
	if attacker.passive != &"passive_ambush":
		return false
	var scout: int = int(UnitRole.UnitClass.SCOUT)
	var archer: int = int(UnitRole.UnitClass.ARCHER)
	if attacker.unit_class != scout and attacker.unit_class != archer:
		return false
	var round_number: int = _turn_runner.get_current_round_number() if _turn_runner != null else 1
	if round_number < 2:
		return false
	if _acted_this_turn.get(defender.unit_id, false):
		return false
	return true


## Counter damage preview. Identical to preview_attack body but with
## attacker / defender roles swapped + is_counter=true. Halved-damage path
## per CR-2 + AC-DC-20.
func _preview_counter_damage(counter_attacker: BattleUnit, original_attacker: BattleUnit) -> int:
	var formation_mult: float = _compute_formation_mult(counter_attacker)
	var angle: String = _attack_angle(counter_attacker, original_attacker)
	var angle_mult: float = _compute_angle_mult(counter_attacker, original_attacker)
	var aura_mult: float = _compute_aura_mult(counter_attacker)
	var passives: Array[StringName] = []
	if counter_attacker.passive != &"":
		passives.append(counter_attacker.passive)
	# S72 Synergy bonus mirrored on counter-preview so forecast is consistent.
	var counter_synergy_atk: int = _compute_synergy_atk_bonus(counter_attacker)
	var counter_synergy_def: int = _compute_synergy_def_bonus(original_attacker)
	var attacker_ctx: AttackerContext = AttackerContext.make(
		counter_attacker.hero_id, counter_attacker.unit_class,
		counter_attacker.raw_atk + counter_synergy_atk,
		false, false, passives)
	var defender_ctx: DefenderContext = DefenderContext.make(
		original_attacker.hero_id, original_attacker.raw_def + counter_synergy_def, 0, 0)
	var preview_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var modifiers: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, preview_rng,
		_angle_to_direction_rel(angle), 1, true,  # is_counter=true
		"", [], 0.0, formation_mult - 1.0, 0.0, Callable())
	modifiers.angle_mult = angle_mult
	modifiers.aura_mult = aura_mult
	var result: ResolveResult = DamageCalc.resolve(attacker_ctx, defender_ctx, modifiers)
	var base_damage: int = result.resolved_damage
	var final_damage: int = roundi(float(base_damage) * angle_mult * aura_mult)
	if result.kind == ResolveResult.Kind.HIT and final_damage < 1:
		final_damage = 1
	return final_damage


# ─── Battle outcome resolution (story-007) ──────────────────────────────────

## Builds the fate_data Dictionary snapshot from current 5 fate counters and
## emits battle_outcome_resolved + sets _battle_over terminal-state flag.
## Per ADR-0014 §7 + story-007 AC-4 + AC-7.
##
## fate_data shape (consumed by Destiny Branch ADR — sprint-6):
##   - tank_unit_id / assassin_unit_id / boss_unit_id (int): roster identity
##   - rear_attacks (int): cumulative rear-strike count (story-005 + story-008)
##   - formation_turns (int): rounds with active formation (story-008)
##   - assassin_kills (int): kills attributed to assassin (story-008)
##   - boss_killed (bool): boss-tagged enemy killed flag (story-008)
##
## Idempotency: this method early-returns if _battle_over is already true,
## guaranteeing exactly-once outcome emission per battle (CR-7 / AC-7).
func _emit_battle_outcome(outcome: StringName) -> void:
	_trace("[BATTLE-END] outcome=%s" % outcome)
	if _battle_over:
		return  # AC-7: idempotent — outcome already resolved
	_battle_over = true
	_last_outcome = outcome  # session-15: cached for get_battle_stats()
	# Story-008 AC-7: tank_alive_hp_pct queried on-demand (NOT a stored counter).
	# 0.0 if no tank unit in roster, dead, or HP/Status returns 0 max_hp.
	var tank_pct: float = 0.0
	if _fate_tank_unit_id != -1:
		var max_hp: int = _hp_controller.get_max_hp(_fate_tank_unit_id)
		if max_hp > 0:
			tank_pct = float(_hp_controller.get_current_hp(_fate_tank_unit_id)) / float(max_hp)
	# Phase F — win_within_turns (ch04 시그니처). Set to actual round count iff
	# outcome is a WIN-class; LOSS / DRAW keep the sentinel 9999 so the threshold
	# check `win_within_turns <= 6` only fires for fast WINs.
	if outcome == &"VICTORY_ANNIHILATION" \
			or outcome == &"VICTORY_SURVIVE" \
			or outcome == &"VICTORY_REACH_TILE" \
			or outcome == &"VICTORY_ESCORT":
		var round_now: int = 0
		if _turn_runner != null and _turn_runner.has_method("get_current_round_number"):
			round_now = _turn_runner.get_current_round_number()
		_fate_win_within_turns = round_now if round_now > 0 else 1

	var fate_data: Dictionary = {
		"tank_unit_id": _fate_tank_unit_id,
		"tank_alive_hp_pct": tank_pct,
		"assassin_unit_id": _fate_assassin_unit_id,
		"boss_unit_id": _fate_boss_unit_id,
		"rear_attacks": _fate_rear_attacks,
		"formation_turns": _fate_formation_turns,
		"assassin_kills": _fate_assassin_kills,
		"boss_killed": _fate_boss_killed,
		# Phase F — 25챕터 영걸전 hidden destiny fate fields (see _fate_* var
		# declarations for chapter mapping + wireable/aspirational status).
		"dmg_to_lubu": _fate_dmg_to_lubu,
		"escort_alive_turns": _fate_escort_alive_turns,
		"win_within_turns": _fate_win_within_turns,
		"civilians_escorted": _fate_civilians_escorted,
		"wei_yan_spared_turns": _fate_wei_yan_spared_turns,
		"scout_first_turns": _fate_scout_first_turns,
		"huang_zhong_xiahou_yuan_kill": _fate_huang_zhong_xiahou_yuan_kill,
		"retreat_path_clear_turns": _fate_retreat_path_clear_turns,
		"discipline_turns": _fate_discipline_turns,
		"counter_fire_turns": _fate_counter_fire_turns,
		"menghuo_captures": _fate_menghuo_captures,
		"masu_supervised_turns": _fate_masu_supervised_turns,
		"qixing_turns": _fate_qixing_turns,
		"player_casualties": _fate_player_casualties,
	}
	battle_outcome_resolved.emit(outcome, fate_data)


## Checks alive-unit counts on each side. Dispatches on _victory_conditions
## (session-28). If either side has 0 alive units AND the active condition
## treats annihilation as a victory/defeat trigger, emits the corresponding
## outcome and returns true. Returns false if no terminal condition fires.
## Per ADR-0014 §7 + story-007 AC-5 + AC-6 + grid-battle.md CR-7 evaluation order.
##
## Dispatcher branches:
##   - null vc OR ConditionType.ANNIHILATION (default): pre-S28 behaviour —
##     VICTORY_ANNIHILATION precedes DEFEAT_ANNIHILATION per CR-7 / EC-GB-02
##     mutual-kill precedence (player-side wins ties).
##   - ConditionType.SURVIVE_N_ROUNDS: enemy wipeout is NOT a shortcut to
##     victory (player must endure to the round threshold; emit nothing on
##     enemy-zero), but player wipeout still emits DEFEAT_ANNIHILATION.
##     The VICTORY_SURVIVE side is emitted from _on_round_started (round
##     threshold can only advance on a fresh round_started tick, not on a
##     unit_died deferred chain).
##
## Called from _on_unit_died (CONNECT_DEFERRED — no reentrance per ADR-0014 R-8).
func _check_battle_end() -> bool:
	var player_alive: int = 0
	var enemy_alive: int = 0
	for unit: BattleUnit in _units.values():
		if not _hp_controller.is_alive(unit.unit_id):
			continue
		if unit.side == 0:
			player_alive += 1
		else:
			enemy_alive += 1
	var condition_type: int = VictoryConditions.ConditionType.ANNIHILATION
	if _victory_conditions != null:
		condition_type = _victory_conditions.primary_condition_type
	match condition_type:
		VictoryConditions.ConditionType.SURVIVE_N_ROUNDS:
			# Enemy wipeout does NOT shortcut to VICTORY for survive — the
			# player must hold position through the full round count. Only
			# the wipeout-DEFEAT path fires from here.
			if player_alive == 0:
				_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
				return true
			return false
		VictoryConditions.ConditionType.ESCORT:
			# Session-30 — ESCORT semantics:
			#   1. Any target_unit_id dead → immediate DEFEAT_ESCORT_LOST
			#      (precedes WIN check, so mutual-kill rounds resolve loss).
			#   2. Else: enemy wipe + all targets alive → VICTORY_ESCORT.
			#   3. Else: player wipe → DEFEAT_ANNIHILATION.
			# Empty target_unit_ids is degenerate: fall through to
			# ANNIHILATION with a diagnostic warning so the chapter author
			# notices the missing field.
			if _victory_conditions.target_unit_ids.is_empty():
				push_warning(
					"GridBattleController: ESCORT victory_conditions has empty target_unit_ids — falling back to ANNIHILATION"
				)
				if enemy_alive == 0:
					_emit_battle_outcome(&"VICTORY_ANNIHILATION")
					return true
				if player_alive == 0:
					_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
					return true
				return false
			for target_id_var: int in _victory_conditions.target_unit_ids:
				if not _units.has(target_id_var):
					continue  # unknown id — skip silently (degenerate chapter authoring)
				if not _hp_controller.is_alive(target_id_var):
					_emit_battle_outcome(&"DEFEAT_ESCORT_LOST")
					return true
			if enemy_alive == 0:
				_emit_battle_outcome(&"VICTORY_ESCORT")
				return true
			if player_alive == 0:
				_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
				return true
			return false
		VictoryConditions.ConditionType.REACH_TILE:
			# Session-31 — REACH_TILE semantics (LOSS-only branch; WIN fires
			# from _check_reach_tile_victory on unit_moved):
			#   1. target_unit_ids[0] dead → DEFEAT_REACH_FAILED (slipping
			#      past requires the slipper to be alive).
			#   2. Else: player wipe → DEFEAT_ANNIHILATION.
			#   3. Enemy wipe does NOT shortcut to WIN — REACH-only, mirror
			#      of SURVIVE no-shortcut. Player must move the target to
			#      target_tile to actually win.
			# Empty target_unit_ids degenerate: degrade to ANNIHILATION.
			if _victory_conditions.target_unit_ids.is_empty():
				push_warning(
					"GridBattleController: REACH_TILE victory_conditions has empty target_unit_ids — falling back to ANNIHILATION"
				)
				if enemy_alive == 0:
					_emit_battle_outcome(&"VICTORY_ANNIHILATION")
					return true
				if player_alive == 0:
					_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
					return true
				return false
			var reach_target_id: int = _victory_conditions.target_unit_ids[0]
			if _units.has(reach_target_id) and not _hp_controller.is_alive(reach_target_id):
				_emit_battle_outcome(&"DEFEAT_REACH_FAILED")
				return true
			if player_alive == 0:
				_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
				return true
			return false
		_:
			# ANNIHILATION (default) — CR-7 + EC-GB-02 precedence.
			if enemy_alive == 0:
				_emit_battle_outcome(&"VICTORY_ANNIHILATION")
				return true
			if player_alive == 0:
				_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
				return true
			return false


## Session-31 — REACH_TILE WIN check. Fired from _do_move's unit_moved.emit
## site (after position update). No-op when:
##   - _battle_over already set (terminal-state guard, mirrors _check_battle_end)
##   - _victory_conditions is null OR type != REACH_TILE
##   - target_unit_ids is empty (degenerate authoring — dispatcher LOSS branch
##     emits the diagnostic warning; this WIN path silently skips)
## Reads target_unit_ids[0] and target_tile from _victory_conditions; if the
## target unit's position now equals target_tile, emits VICTORY_REACH_TILE.
##
## Why split between _check_battle_end (LOSS) and this helper (WIN):
## REACH WIN is a position-changed event (only meaningful on unit_moved);
## REACH LOSS is a unit-died event (handled in the same _check_battle_end
## flow as the other condition types). Keeping the two checks at their
## natural signal sources avoids re-scanning state on every signal.
func _check_reach_tile_victory() -> void:
	if _battle_over:
		return
	if _victory_conditions == null:
		return
	if _victory_conditions.primary_condition_type != VictoryConditions.ConditionType.REACH_TILE:
		return
	if _victory_conditions.target_unit_ids.is_empty():
		return  # degenerate — LOSS dispatcher branch handles the warning
	var target_id: int = _victory_conditions.target_unit_ids[0]
	if not _units.has(target_id):
		return  # unknown id — silently skip
	var unit: BattleUnit = _units[target_id]
	if unit.position == _victory_conditions.target_tile:
		_emit_battle_outcome(&"VICTORY_REACH_TILE")


## Per ADR-0014 §Amendment 2026-05-10 (#3 — production-wiring residual closure).
## Bridges T5 await per ADR-0011 §Amendment 2026-05-09 to the appropriate
## consumer subscriber: enemy-side via ai_action_requested emit → AISystem.decide
## → ai_action_ready chain (S15-B); player-side defers to natural grid-click input
## → _handle_player_* helpers (S15-C). Returns immediately for player units (T5
## stays paused until player declare_action fires); triggers AI dispatch for enemies.
##
## Registered as the _action_controller Callable on TurnOrderRunner by BattleScene
## STEP 5 (see battle_scene.gd S15-J insertion) so T5 calls this instead of the
## TEST-SEAM no-op pass.
##
## IMPORTANT: `snapshot` is a TurnOrderSnapshot (the type T5 passes), NOT UnitTurnState
## or BattleStateSnapshot. The parameter is typed TurnOrderSnapshot here to satisfy
## the Callable contract; this handler does not read it. For AI dispatch, a
## BattleStateSnapshot is built fresh via _make_battle_state_snapshot().
func _on_turn_runner_action_request(unit_id: int, snapshot: TurnOrderSnapshot) -> void:
	var unit: BattleUnit = _units.get(unit_id, null)
	if unit == null:
		push_warning("S15-J: _on_turn_runner_action_request received unknown unit_id=%d" % unit_id)
		return
	# Session-17 STUN gate — if this unit was stunned in a prior turn, force WAIT
	# immediately regardless of side (player or AI). Dict-based so it's robust
	# to GameBus.unit_turn_started subscription order between HPStatusController
	# tick and GridBattleController.
	if _pending_stun.get(unit_id, false):
		_pending_stun.erase(unit_id)
		_acted_this_turn[unit_id] = true
		_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
		return
	match unit.side:
		0:  # player — natural input path (S15-C); T5 stays paused until grid-click fires declare_action
			return
		1:  # enemy — Phase 1 D fix: 0.35s thinking pause before dispatch so the
			# player can read "Turn: 적장" + tile highlight + chevron before the AI
			# action fires. Snapshot built INSIDE the timer to capture the current
			# state at dispatch time (not at signal-fire time) — defensive against
			# late-arriving state changes during the pause window.
			# Tests can zero the pause via set_ai_thinking_pause_sec_for_test(0.0).
			# Also fall back to synchronous emit when not inside a SceneTree
			# (tests that instantiate the controller without add_child) — keeps
			# unit-test reachability without forcing scene-tree mounting.
			var pause_unit_id: int = unit_id
			if _ai_thinking_pause_sec <= 0.0 or not is_inside_tree():
				ai_action_requested.emit(pause_unit_id, _make_battle_state_snapshot())
			else:
				get_tree().create_timer(_ai_thinking_pause_sec).timeout.connect(func() -> void:
					if not _units.has(pause_unit_id):
						return  # unit died / removed during the pause — skip dispatch
					var battle_snapshot: BattleStateSnapshot = _make_battle_state_snapshot()
					ai_action_requested.emit(pause_unit_id, battle_snapshot))
		_:
			push_warning("S15-J: unknown unit.side=%d for unit_id=%d" % [unit.side, unit_id])
