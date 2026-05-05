## AISystem — battle-scoped Node owning AI decision-making for non-player units.
##
## 6TH INVOCATION of battle-scoped Node pattern (after HPStatusController +
## TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD).
## 1ST INVOCATION of single-class match-dispatch over subclass hierarchy
## (4 archetypes: aggressor / skirmisher / holder / coordinator) — pattern
## boundary established for closed enum-keyed dispatch with closed MVP scope
## per CR-AI-3. Subclass hierarchy with @abstract _score_candidate test seam
## is the post-MVP refactor option per Alternative §4.
##
## SIGNAL PROTOCOL (per grid-battle.md CR-3 + CR-3a):
##   - Subscribes to GridBattleController.ai_action_requested(unit_id, snapshot)
##     with CONNECT_DEFERRED at _ready()
##   - Emits ai_action_ready(unit_id, command) declared on AISystem class
##     itself (NOT GameBus per ai_system_signal_emission_outside_action_ready
##     forbidden_pattern)
##   - 500ms timeout owned by GridBattleController-side defense (CR-3b)
##
## PILLAR 2 ARCHITECTURAL LOCK (4th project precedent):
##   AISystem MUST NOT introspect Pillar 2 hidden-fate state. The tokens
##   `hidden_fate_condition_progressed`, `DestinyBranchChoice`, and
##   `destiny_branch_chosen` MUST NOT appear anywhere in this file. Enforced
##   by lint_ai_system_no_destiny_branch_reference.sh + integration test
##   structural assertion + this inline annotation (3-layer enforcement triad).
##
## CR-AI-6 PURE-FUNCTION-TAKES-SNAPSHOT (2nd invocation after DestinyBranchJudge):
##   AISystem reads battle state ONLY through the BattleStateSnapshot parameter
##   passed to _on_ai_action_requested. NO direct MapGrid./HPStatusController./
##   TurnOrderRunner. references in scoring code. Enforced by
##   lint_ai_system_no_direct_state_read.sh.
##
## DETERMINISM (CR-AI-5 + AC-AI-2):
##   NO RNG / NO wall-clock / NO instance-var caching across calls / NO static var.
##   Identical (snapshot, unit_id, archetype, round_number) → field-identical
##   AIActionCommand output.
##
## ADR: ADR-0019 (Accepted 2026-05-05 via /architecture-review delta #14).
## TR: TR-ai-system-001..015.
class_name AISystem
extends Node


# ─── LOCAL signal (per CR-3 + ADR-0019) ───────────────────────────────────────

## Emitted in response to GridBattleController.ai_action_requested. Declared
## on AISystem class itself, NOT on GameBus.
signal ai_action_ready(unit_id: int, command: AIActionCommand)


# ─── DI'd reference (set by setup() before add_child per battle-scoped Node 6-precedent) ─

var _grid_battle_controller: GridBattleController = null


# ─── Public API ───────────────────────────────────────────────────────────────


## Sets the GridBattleController reference. MUST be called BEFORE add_child()
## per battle-scoped Node 6-precedent setup-before-add_child mandate.
func setup(controller: GridBattleController) -> void:
	_grid_battle_controller = controller


# ─── Lifecycle ────────────────────────────────────────────────────────────────


func _ready() -> void:
	# V-1: DI null-check assert per battle-scoped Node 6-precedent.
	assert(
		_grid_battle_controller != null,
		"AISystem: setup() must be called before add_child()"
	)
	if _grid_battle_controller == null:
		return
	# Subscribe with CONNECT_DEFERRED per ADR-0019 §Decision body + CR-3.
	if not _grid_battle_controller.ai_action_requested.is_connected(_on_ai_action_requested):
		var err: int = _grid_battle_controller.ai_action_requested.connect(
			_on_ai_action_requested, CONNECT_DEFERRED
		)
		assert(err == OK, "AISystem: ai_action_requested.connect failed (err=%d)" % err)


## V-2: _exit_tree disconnect per battle-scoped Node 6-precedent _exit_tree discipline.
func _exit_tree() -> void:
	if _grid_battle_controller != null and _grid_battle_controller.ai_action_requested.is_connected(_on_ai_action_requested):
		_grid_battle_controller.ai_action_requested.disconnect(_on_ai_action_requested)


# ─── Decision pipeline ────────────────────────────────────────────────────────


## Handler for GridBattleController.ai_action_requested signal. Pure-function
## over snapshot per CR-AI-6 + ai_system_direct_battle_state_read forbidden_pattern.
func _on_ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot) -> void:
	var command: AIActionCommand = decide(unit_id, snapshot)
	ai_action_ready.emit(unit_id, command)


## Decision pipeline (test-friendly entry point — no signal emission).
## CR-AI-4 5-step pipeline: extract unit + enumerate candidates + score each +
## tie-break cascade + materialize command.
func decide(unit_id: int, snapshot: BattleStateSnapshot) -> AIActionCommand:
	if snapshot == null:
		return AIActionCommand.wait(unit_id)
	var unit: Dictionary = snapshot.get_unit(unit_id)
	if unit.is_empty():
		# EC-AI-1: unit not found in snapshot — substitute WAIT.
		return AIActionCommand.wait(unit_id)
	var archetype: StringName = unit.get("archetype", &"aggressor") as StringName
	var candidates: Array[Dictionary] = _enumerate_candidates(unit, snapshot)
	if candidates.is_empty():
		# EC-AI-1: zero candidates — substitute WAIT.
		return AIActionCommand.wait(unit_id)
	# Score each candidate via per-archetype function.
	var best: Dictionary = {}
	var best_score: float = -INF
	for cand: Dictionary in candidates:
		var score: float = _score_candidate(archetype, cand, snapshot, unit)
		if score > best_score:
			best_score = score
			best = cand
		elif score == best_score and not best.is_empty():
			# Tie-break cascade per CR-AI-4: target_unit_id ASC, target_coord.y ASC, target_coord.x ASC.
			if _tie_break_prefers(cand, best):
				best = cand
	# EC-AI-2: all-suicidal scores ≤ -100 (very low) — fallback to WAIT.
	if best_score <= -100.0:
		return AIActionCommand.wait(unit_id)
	return _materialize_command(unit_id, best)


# ─── Candidate enumeration (snapshot-only, deterministic) ─────────────────────


## Enumerates legal candidate actions for `unit` from `snapshot`. Pure function
## over snapshot per CR-AI-6. Capped at 200 candidates per CR-AI-4 step 2.
func _enumerate_candidates(unit: Dictionary, snapshot: BattleStateSnapshot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos: Vector2i = unit.get("position", Vector2i.ZERO) as Vector2i
	var attack_range: int = unit.get("attack_range", 1) as int
	# WAIT candidate.
	out.append({"action_type": AIActionCommand.ActionType.WAIT, "move_to": pos, "target_id": -1})
	# DEFEND candidate.
	out.append({"action_type": AIActionCommand.ActionType.DEFEND, "move_to": pos, "target_id": -1})
	# USE_SKILL(rally) candidate (only relevant for coordinator; scoring decides).
	out.append({
		"action_type": AIActionCommand.ActionType.USE_SKILL,
		"move_to": pos, "target_id": -1, "skill": &"rally",
	})
	# ATTACK candidates: each player unit within attack_range from current pos.
	for u: Dictionary in snapshot.units:
		if (u.get("side", 1) as int) != 0:
			continue  # Skip non-player units.
		if not (u.get("is_alive", true) as bool):
			continue
		var t_id: int = u.get("unit_id", -1) as int
		var t_pos: Vector2i = u.get("position", Vector2i.ZERO) as Vector2i
		var dist: int = _grid_distance(pos, t_pos)
		if dist <= attack_range:
			out.append({
				"action_type": AIActionCommand.ActionType.ATTACK,
				"move_to": pos, "target_id": t_id, "target_pos": t_pos,
			})
	# MOVE candidates: small radius around current position (deterministic order).
	# Cap per CR-AI-4 step 2 to keep candidates ≤ 200.
	var move_range: int = unit.get("move_range", 3) as int
	var move_count: int = 0
	for dy in range(-move_range, move_range + 1):
		for dx in range(-move_range, move_range + 1):
			if dx == 0 and dy == 0:
				continue
			if _grid_distance(Vector2i.ZERO, Vector2i(dx, dy)) > move_range:
				continue
			var dest: Vector2i = pos + Vector2i(dx, dy)
			if dest.x < 0 or dest.y < 0:
				continue
			if dest.x >= snapshot.map_dimensions.x or dest.y >= snapshot.map_dimensions.y:
				continue
			out.append({
				"action_type": AIActionCommand.ActionType.MOVE,
				"move_to": dest, "target_id": -1,
			})
			move_count += 1
			if move_count + out.size() >= 200:
				return out
	return out


## Manhattan distance on grid.
func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# ─── Tie-break ────────────────────────────────────────────────────────────────


## Per CR-AI-4 step 4 cascade: prefers candidate with lower target_unit_id,
## then lower target_pos.y, then lower target_pos.x. Deterministic.
func _tie_break_prefers(a: Dictionary, b: Dictionary) -> bool:
	var a_tid: int = a.get("target_id", -1) as int
	var b_tid: int = b.get("target_id", -1) as int
	if a_tid != b_tid:
		return a_tid < b_tid
	var a_pos: Vector2i = a.get("move_to", Vector2i.ZERO) as Vector2i
	var b_pos: Vector2i = b.get("move_to", Vector2i.ZERO) as Vector2i
	if a_pos.y != b_pos.y:
		return a_pos.y < b_pos.y
	return a_pos.x < b_pos.x


# ─── Per-archetype scoring (match-dispatch on archetype StringName) ──────────


func _score_candidate(
		archetype: StringName,
		candidate: Dictionary,
		snapshot: BattleStateSnapshot,
		unit: Dictionary,
) -> float:
	match archetype:
		&"aggressor":
			return _score_aggressor(candidate, snapshot, unit)
		&"skirmisher":
			return _score_skirmisher(candidate, snapshot, unit)
		&"holder":
			return _score_holder(candidate, snapshot, unit)
		&"coordinator":
			return _score_coordinator(candidate, snapshot, unit)
		_:
			# EC-AI-4: unknown archetype falls back to aggressor.
			push_warning("AISystem: unknown archetype '%s' — falling back to aggressor" % archetype)
			return _score_aggressor(candidate, snapshot, unit)


## F-AI-1: aggressor commits to kills.
func _score_aggressor(candidate: Dictionary, snapshot: BattleStateSnapshot, unit: Dictionary) -> float:
	var action: int = candidate.get("action_type", AIActionCommand.ActionType.WAIT) as int
	if action == AIActionCommand.ActionType.WAIT:
		return -100.0
	if action == AIActionCommand.ActionType.DEFEND:
		return -50.0
	if action == AIActionCommand.ActionType.USE_SKILL:
		return -100.0
	if action == AIActionCommand.ActionType.MOVE:
		# MOVE-only is low-priority for aggressor; favor closing distance to nearest player.
		var dest: Vector2i = candidate.get("move_to", Vector2i.ZERO) as Vector2i
		var dist_to_nearest: int = _nearest_player_distance(dest, snapshot)
		return -float(dist_to_nearest) * 2.0
	if action == AIActionCommand.ActionType.ATTACK:
		var t_id: int = candidate.get("target_id", -1) as int
		var target: Dictionary = snapshot.get_unit(t_id)
		if target.is_empty():
			return -100.0
		var hp_pct: float = float(target.get("hp_current", 1) as int) / max(1.0, float(target.get("hp_max", 1) as int))
		var bonus: float = float(BalanceConstants.get_const("AGGRESSOR_KILL_BONUS")) if hp_pct <= 0.30 else 0.0
		var weakness: float = float(BalanceConstants.get_const("AGGRESSOR_WEAKNESS_WEIGHT")) * (1.0 - hp_pct)
		var t_pos: Vector2i = target.get("position", Vector2i.ZERO) as Vector2i
		var unit_pos: Vector2i = unit.get("position", Vector2i.ZERO) as Vector2i
		var dist_penalty: float = float(_grid_distance(unit_pos, t_pos)) * 0.5
		return 20.0 + bonus + weakness - dist_penalty
	return 0.0


## F-AI-2: skirmisher kites (range > distance preference).
func _score_skirmisher(candidate: Dictionary, snapshot: BattleStateSnapshot, unit: Dictionary) -> float:
	var action: int = candidate.get("action_type", AIActionCommand.ActionType.WAIT) as int
	if action == AIActionCommand.ActionType.WAIT:
		return -50.0
	if action == AIActionCommand.ActionType.DEFEND:
		return -30.0
	if action == AIActionCommand.ActionType.USE_SKILL:
		return -100.0
	var melee_penalty: float = float(BalanceConstants.get_const("SKIRMISHER_MELEE_PENALTY"))
	var safe_bonus: float = float(BalanceConstants.get_const("SKIRMISHER_SAFE_DISTANCE_BONUS"))
	if action == AIActionCommand.ActionType.MOVE:
		var dest: Vector2i = candidate.get("move_to", Vector2i.ZERO) as Vector2i
		var nearest: int = _nearest_player_distance(dest, snapshot)
		# Prefer distance ≥ 3 (kite away).
		if nearest >= 3:
			return safe_bonus + 5.0
		if nearest <= 1:
			return -melee_penalty
		return 0.0
	if action == AIActionCommand.ActionType.ATTACK:
		var t_id: int = candidate.get("target_id", -1) as int
		var target: Dictionary = snapshot.get_unit(t_id)
		if target.is_empty():
			return -100.0
		var t_range: int = target.get("attack_range", 1) as int
		var ranged_bonus: float = float(BalanceConstants.get_const("SKIRMISHER_RANGED_TARGET_BONUS")) if t_range >= 2 else 0.0
		return 15.0 + ranged_bonus
	return 0.0


## F-AI-3: holder anchors at chokepoints.
func _score_holder(candidate: Dictionary, snapshot: BattleStateSnapshot, unit: Dictionary) -> float:
	var action: int = candidate.get("action_type", AIActionCommand.ActionType.WAIT) as int
	var unit_pos: Vector2i = unit.get("position", Vector2i.ZERO) as Vector2i
	var at_chokepoint: bool = unit_pos in snapshot.chokepoints
	var any_in_range: bool = _any_player_in_attack_range(unit, snapshot)
	if action == AIActionCommand.ActionType.WAIT:
		return 10.0 if (at_chokepoint and not any_in_range) else -30.0
	if action == AIActionCommand.ActionType.DEFEND:
		return 20.0 if any_in_range else -10.0
	if action == AIActionCommand.ActionType.USE_SKILL:
		return -100.0
	var chokepoint_bonus: float = float(BalanceConstants.get_const("HOLDER_CHOKEPOINT_BONUS"))
	var overextend: float = float(BalanceConstants.get_const("HOLDER_OVEREXTEND_PENALTY"))
	if action == AIActionCommand.ActionType.MOVE:
		var dest: Vector2i = candidate.get("move_to", Vector2i.ZERO) as Vector2i
		# Chokepoint anchor reward.
		if dest in snapshot.chokepoints:
			return chokepoint_bonus
		# Overextend penalty if moving toward player and not at chokepoint.
		var nearest: int = _nearest_player_distance(dest, snapshot)
		var current_nearest: int = _nearest_player_distance(unit_pos, snapshot)
		if nearest < current_nearest:
			return -overextend
		return 0.0
	if action == AIActionCommand.ActionType.ATTACK:
		var t_id: int = candidate.get("target_id", -1) as int
		var target: Dictionary = snapshot.get_unit(t_id)
		if target.is_empty():
			return -100.0
		return 18.0
	return 0.0


## F-AI-4: coordinator targets commander + uses rally.
func _score_coordinator(candidate: Dictionary, snapshot: BattleStateSnapshot, unit: Dictionary) -> float:
	var action: int = candidate.get("action_type", AIActionCommand.ActionType.WAIT) as int
	var hp_pct: float = float(unit.get("hp_current", 1) as int) / max(1.0, float(unit.get("hp_max", 1) as int))
	if action == AIActionCommand.ActionType.WAIT:
		return -10.0
	if action == AIActionCommand.ActionType.DEFEND:
		return 30.0 if hp_pct < 0.4 else 0.0
	if action == AIActionCommand.ActionType.USE_SKILL:
		var skill: StringName = candidate.get("skill", &"") as StringName
		if skill == &"rally":
			# Rally requires ≥2 adjacent allies.
			var adj_allies: int = _count_adjacent_allies(unit, snapshot)
			if adj_allies >= 2:
				return float(BalanceConstants.get_const("COORDINATOR_RALLY_BONUS"))
		return -100.0
	if action == AIActionCommand.ActionType.ATTACK:
		var t_id: int = candidate.get("target_id", -1) as int
		var target: Dictionary = snapshot.get_unit(t_id)
		if target.is_empty():
			return -100.0
		var has_command_aura: bool = (target.get("passive_id", &"") as StringName) == &"command_aura"
		var commander_bonus: float = float(BalanceConstants.get_const("COORDINATOR_COMMANDER_TARGET_BONUS")) if has_command_aura else 0.0
		return 15.0 + commander_bonus
	if action == AIActionCommand.ActionType.MOVE:
		# Coordinator stays near allies (formation).
		var dest: Vector2i = candidate.get("move_to", Vector2i.ZERO) as Vector2i
		var dist_to_center: int = _grid_distance(dest, snapshot.formation_center)
		return -float(dist_to_center) * 1.5
	return 0.0


# ─── Helpers (snapshot-only) ─────────────────────────────────────────────────


func _nearest_player_distance(from: Vector2i, snapshot: BattleStateSnapshot) -> int:
	var best: int = 999
	for u: Dictionary in snapshot.units:
		if (u.get("side", 1) as int) != 0:
			continue
		if not (u.get("is_alive", true) as bool):
			continue
		var pos: Vector2i = u.get("position", Vector2i.ZERO) as Vector2i
		var d: int = _grid_distance(from, pos)
		if d < best:
			best = d
	return best


func _any_player_in_attack_range(unit: Dictionary, snapshot: BattleStateSnapshot) -> bool:
	var pos: Vector2i = unit.get("position", Vector2i.ZERO) as Vector2i
	var attack_range: int = unit.get("attack_range", 1) as int
	for u: Dictionary in snapshot.units:
		if (u.get("side", 1) as int) != 0:
			continue
		if not (u.get("is_alive", true) as bool):
			continue
		var t_pos: Vector2i = u.get("position", Vector2i.ZERO) as Vector2i
		if _grid_distance(pos, t_pos) <= attack_range:
			return true
	return false


func _count_adjacent_allies(unit: Dictionary, snapshot: BattleStateSnapshot) -> int:
	var pos: Vector2i = unit.get("position", Vector2i.ZERO) as Vector2i
	var count: int = 0
	for u: Dictionary in snapshot.units:
		if (u.get("unit_id", -1) as int) == (unit.get("unit_id", -1) as int):
			continue
		if (u.get("side", 1) as int) != 1:
			continue  # Allies are same side as `unit` (enemy side=1).
		if not (u.get("is_alive", true) as bool):
			continue
		var t_pos: Vector2i = u.get("position", Vector2i.ZERO) as Vector2i
		if _grid_distance(pos, t_pos) == 1:
			count += 1
	return count


# ─── Materialization ─────────────────────────────────────────────────────────


func _materialize_command(unit_id: int, candidate: Dictionary) -> AIActionCommand:
	var action: int = candidate.get("action_type", AIActionCommand.ActionType.WAIT) as int
	match action:
		AIActionCommand.ActionType.WAIT:
			return AIActionCommand.wait(unit_id)
		AIActionCommand.ActionType.DEFEND:
			return AIActionCommand.defend(unit_id)
		AIActionCommand.ActionType.MOVE:
			return AIActionCommand.move(unit_id, candidate.get("move_to", Vector2i.ZERO) as Vector2i)
		AIActionCommand.ActionType.ATTACK:
			return AIActionCommand.attack(unit_id, candidate.get("target_id", -1) as int)
		AIActionCommand.ActionType.MOVE_AND_ATTACK:
			return AIActionCommand.move_and_attack(
				unit_id,
				candidate.get("move_to", Vector2i.ZERO) as Vector2i,
				candidate.get("target_id", -1) as int,
			)
		AIActionCommand.ActionType.USE_SKILL:
			return AIActionCommand.use_skill(unit_id, candidate.get("skill", &"") as StringName)
		_:
			return AIActionCommand.wait(unit_id)
