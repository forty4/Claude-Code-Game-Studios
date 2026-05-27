## grid_battle_controller_use_item_test.gd
##
## S90 Phase B step 4 — heal_potion immediate-effect item.
## Validates strategy-systems.md v0.3 §AC-SS-4 acceptance criteria:
##   - use_item(unit, "heal_potion") with current_hp < max_hp restores HEAL_POTION_AMOUNT (25)
##   - heal capped at max_hp (apply_heal contract)
##   - pre-condition current_hp == max_hp returns false (slot NOT decremented,
##     token NOT spent — strategy-systems §4.1 EC)
##   - Slot decrement: pre inventory[0] == &"heal_potion" → post inventory[0] == &""
##   - action_token spent via TurnOrderRunner.declare_action(USE_ITEM)
##   - unit_item_used signal emits with (unit_id, item_id, slot_idx, actual_effect)
##
## Mirrors grid_battle_controller_player_defend_test.gd setup pattern.
extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func _make_unit(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	unit.inventory = []  # callers set per-test
	return unit


func _setup(roster: Array[BattleUnit]) -> Dictionary:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	auto_free(hp_controller)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	controller.setup(roster, map_grid, camera, hero_db, turn_runner,
		hp_controller, terrain_effect, unit_role)
	controller._rng = RandomNumberGenerator.new()
	controller._rng.seed = 12345
	return {
		"controller": controller,
		"hp_controller": hp_controller,
		"turn_runner": turn_runner,
	}


# ─── AC-SS-4 heal_potion happy path ───────────────────────────────────────────


## AC-SS-4: heal_potion with current_hp = max_hp - 10 → heals 10 actual (capped
## at max_hp); inventory[0] decremented; action_token spent; signal emits.
func test_use_item_heal_potion_at_low_hp_heals_capped_at_max() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 90)  # 10 below max
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item(heal_potion) at HP<max must return true (fired)"
	).is_true()

	# apply_heal called with raw_heal=25 (HEAL_POTION_AMOUNT)
	assert_int(hp_stub.apply_heal_calls.size()).override_failure_message(
		"AC-SS-4: apply_heal must be invoked exactly once"
	).is_equal(1)
	assert_int(hp_stub.apply_heal_calls[0]["raw_heal"] as int).override_failure_message(
		"AC-SS-4: raw_heal must equal HEAL_POTION_AMOUNT (25)"
	).is_equal(25)

	# Slot decremented
	assert_str(String(controller._units[1].inventory[0])).override_failure_message(
		"AC-SS-4: inventory[0] must be &\"\" after successful use_item"
	).is_equal("")

	# unit_item_used signal emitted
	assert_int(emitted.size()).override_failure_message(
		"AC-SS-4: unit_item_used signal must fire exactly once"
	).is_equal(1)
	assert_str(String(emitted[0]["item"] as StringName)).is_equal("heal_potion")
	assert_int(emitted[0]["slot"] as int).is_equal(0)


## AC-SS-4: pre-condition HP at max → use_item returns false; slot NOT decremented;
## apply_heal NOT called; token NOT spent.
func test_use_item_heal_potion_at_max_hp_rejected_slot_intact() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)  # exactly at max
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item(heal_potion) at HP=max must return false (rejected)"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).override_failure_message(
		"AC-SS-4: apply_heal must NOT be called when reject"
	).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).override_failure_message(
		"AC-SS-4: inventory[0] must REMAIN &\"heal_potion\" on reject"
	).is_equal("heal_potion")


## AC-SS-4: empty slot → use_item returns false; no side effects.
func test_use_item_empty_slot_rejected() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"", &"", &""]  # all empty
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item on empty slot must return false"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)


## AC-SS-4: out-of-range slot_idx → use_item returns false.
func test_use_item_out_of_range_slot_rejected() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act + Assert — out-of-range high
	var fired_high: bool = controller.use_item(1, 99)
	assert_bool(fired_high).override_failure_message(
		"AC-SS-4: use_item(slot=99) out-of-range must return false"
	).is_false()

	# Act + Assert — out-of-range low
	var fired_low: bool = controller.use_item(1, -1)
	assert_bool(fired_low).override_failure_message(
		"AC-SS-4: use_item(slot=-1) out-of-range must return false"
	).is_false()

	# apply_heal never called
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)


## AC-SS-4: enemy side cannot use items (player-only in MVP).
func test_use_item_enemy_side_rejected() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 1)  # enemy side
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item on enemy unit must return false (player-only MVP)"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).is_equal("heal_potion")


## AC-SS-4 (regression): unwired item_id triggers push_warning + reject without
## consuming slot. Validates the dispatch match default arm.
## S91 step 6 update: fire_scroll moved to "wired" list (AC-SS-6); use
## command_scroll (Phase 4+ DEFERRED per strategy-systems.md v0.2 user
## adjudication — turn-queue mid-round mutation is a TurnOrderRunner hard
## invariant) as the unwired test fixture.
func test_use_item_unwired_item_id_rejected_with_warning() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"command_scroll", &"", &""]  # Phase 4+ deferred — guaranteed unwired
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert — push_warning is non-aborting; just reject
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item on unwired item_id must return false (slot intact, token unconsumed)"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).override_failure_message(
		"AC-SS-4: inventory[0] must remain &\"command_scroll\" on unwired reject"
	).is_equal("command_scroll")


# ─── AC-SS-5 strength_scroll buff multi-turn carry ────────────────────────────


## AC-SS-5: strength_scroll use sets pending_buff (no immediate damage),
## spends action_token, decrements slot, emits signal. Buff payload format:
## {&"kind": &"strength", &"magnitude": STRENGTH_SCROLL_MULT, &"expires_at_turn": current_round + 1}.
func test_use_item_strength_scroll_sets_pending_buff_and_decrements_slot() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"strength_scroll", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)  # full HP — buff use unaffected by HP state
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).is_true()
	# pending_buff stored on unit
	var pb: Dictionary = controller._units[1].pending_buff
	assert_bool(pb.is_empty()).override_failure_message(
		"AC-SS-5: pending_buff must be NON-empty after strength_scroll use"
	).is_false()
	assert_str(String(pb.get(&"kind", &"") as StringName)).is_equal("strength")
	assert_float(pb.get(&"magnitude", 0.0) as float).is_equal_approx(1.50, 0.001)
	# Slot decremented
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	# Signal emitted
	assert_int(emitted.size()).is_equal(1)
	assert_str(String(emitted[0]["item"] as StringName)).is_equal("strength_scroll")
	# apply_heal NOT called (buff stored, no immediate effect)
	assert_int(hp_stub.apply_heal_calls.size()).override_failure_message(
		"AC-SS-5: strength_scroll must NOT call apply_heal (buff stored, no immediate effect)"
	).is_equal(0)


## AC-SS-5: buff overwrite (EC-SS-2) — second strength_scroll while buff active
## REPLACES the existing buff. No popup, no warning (design-intent per §3.6 #4).
func test_use_item_strength_scroll_overwrite_existing_buff() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"strength_scroll", &"strength_scroll", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	controller._active_turn_unit_id = 1

	# Act — first use sets buff with expires_at_turn=2 (current_round=1+1)
	var first: bool = controller.use_item(1, 0)
	var first_pb: Dictionary = controller._units[1].pending_buff.duplicate()
	assert_bool(first).is_true()
	assert_bool(first_pb.is_empty()).is_false()

	# Act — second use overwrites
	var second: bool = controller.use_item(1, 1)

	# Assert — second succeeds; pending_buff still present (new buff, same shape)
	assert_bool(second).is_true()
	var second_pb: Dictionary = controller._units[1].pending_buff
	assert_bool(second_pb.is_empty()).is_false()
	assert_str(String(second_pb.get(&"kind", &"") as StringName)).is_equal("strength")
	# Both slots decremented
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	assert_str(String(controller._units[1].inventory[1])).is_equal("")


## AC-SS-5: _resolve_pending_buff_magnitude consumption — when buff is fresh
## (expires_at_turn >= current_round), helper returns magnitude AND clears
## the buff. Default round_number=1 from turn_runner stub.
func test_resolve_pending_buff_magnitude_consumes_fresh_buff() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.pending_buff = {
		&"kind": &"strength",
		&"magnitude": 1.50,
		&"expires_at_turn": 2,  # >= 1 (default round_number)
	}
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	# Act
	var magnitude: float = controller._resolve_pending_buff_magnitude(1)

	# Assert — magnitude returned, buff cleared
	assert_float(magnitude).is_equal_approx(1.50, 0.001)
	assert_bool(controller._units[1].pending_buff.is_empty()).override_failure_message(
		"AC-SS-5: pending_buff must be cleared after _resolve_pending_buff_magnitude consumption"
	).is_true()


## AC-SS-5: stale buff (expires_at_turn < current_round) cleared without
## consumption — helper returns 1.0 (identity) + clears buff. Simulates
## EC-SS-3 scenario: buff used round 7 (expires=8), no attack until round 10.
## Uses expires_at_turn=-1 to guarantee staleness regardless of stub's
## get_current_round_number() return value (typically 1 in fresh setup).
func test_resolve_pending_buff_magnitude_clears_stale_buff_returns_identity() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.pending_buff = {
		&"kind": &"strength",
		&"magnitude": 1.50,
		&"expires_at_turn": -1,  # unambiguously stale (< any valid round)
	}
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	# Act
	var magnitude: float = controller._resolve_pending_buff_magnitude(1)

	# Assert — identity returned (buff did NOT fire), pending_buff cleared
	assert_float(magnitude).override_failure_message(
		"AC-SS-5: stale buff must return identity magnitude 1.0"
	).is_equal_approx(1.0, 0.001)
	assert_bool(controller._units[1].pending_buff.is_empty()).override_failure_message(
		"AC-SS-5: stale buff must be cleared (no carryover risk)"
	).is_true()


## AC-SS-5: no buff active → helper returns identity 1.0 + no side effects.
func test_resolve_pending_buff_magnitude_no_buff_returns_identity() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.pending_buff = {}  # explicitly empty
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	# Act
	var magnitude: float = controller._resolve_pending_buff_magnitude(1)

	# Assert
	assert_float(magnitude).is_equal_approx(1.0, 0.001)
	assert_bool(controller._units[1].pending_buff.is_empty()).is_true()


# ─── AC-SS-4 b-variant march_scroll move-token re-grant (S90 step 7) ──────────


## Helper — builds a UnitTurnState fixture in ACTING phase with both tokens fresh.
func _make_acting_state(unit_id: int) -> UnitTurnState:
	var state: UnitTurnState = UnitTurnState.new()
	state.unit_id = unit_id
	state.turn_state = TurnOrderRunner.TurnState.ACTING
	state.move_token_spent = false
	state.action_token_spent = false
	return state


## S90 step 7: march_scroll on fresh turn (no action_token spent) succeeds.
## Bonus added to move_range_bonus, refresh_move_token invoked, slot decremented,
## declare_action(USE_ITEM) called for action_token spend, signal emits.
func test_use_item_march_scroll_grants_bonus_and_refreshes_move_token() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"march_scroll", &"", &""]
	unit.move_range = 3
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	turn_stub.set_unit_turn_state_for_test(1, _make_acting_state(1))
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4b: march_scroll on fresh turn must succeed (action_token free)"
	).is_true()
	# Bonus applied additively (3 + 2 effective range)
	assert_int(controller._units[1].move_range_bonus).override_failure_message(
		"AC-SS-4b: move_range_bonus must equal MARCH_SCROLL_BONUS (2) after first use"
	).is_equal(2)
	# refresh_move_token invoked
	assert_int(turn_stub.refresh_move_token_calls.size()).override_failure_message(
		"AC-SS-4b: refresh_move_token must be called exactly once on success"
	).is_equal(1)
	assert_int(turn_stub.refresh_move_token_calls[0]).is_equal(1)
	# Slot decremented
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	# action_token spent via declare_action(USE_ITEM)
	assert_int(turn_stub.declared_actions.size()).is_equal(1)
	assert_int(turn_stub.declared_actions[0]["action"] as int).is_equal(
		TurnOrderRunner.ActionType.USE_ITEM as int
	)
	# Signal emit
	assert_int(emitted.size()).is_equal(1)
	assert_str(String(emitted[0]["item"] as StringName)).is_equal("march_scroll")


## S90 step 7: march_scroll on a unit whose action_token is already spent is
## rejected per strategy-systems v0.3 §4.4 Edge (book use IS an action;
## cannot use book after attack). Slot NOT decremented, bonus NOT applied,
## refresh_move_token NOT invoked.
func test_use_item_march_scroll_after_attack_rejected_no_side_effect() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"march_scroll", &"", &""]
	unit.move_range = 3
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	# State with action_token already spent (simulates "unit already attacked").
	var state: UnitTurnState = _make_acting_state(1)
	state.action_token_spent = true
	turn_stub.set_unit_turn_state_for_test(1, state)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4b: march_scroll must reject when action_token already spent (§4.4 Edge)"
	).is_false()
	# Bonus NOT applied
	assert_int(controller._units[1].move_range_bonus).override_failure_message(
		"AC-SS-4b: rejected march_scroll must NOT mutate move_range_bonus"
	).is_equal(0)
	# Slot intact
	assert_str(String(controller._units[1].inventory[0])).is_equal("march_scroll")
	# refresh_move_token NOT invoked
	assert_int(turn_stub.refresh_move_token_calls.size()).override_failure_message(
		"AC-SS-4b: refresh_move_token must NOT be called on reject"
	).is_equal(0)
	# declare_action NOT invoked (token preserved)
	assert_int(turn_stub.declared_actions.size()).is_equal(0)


## S90 step 7: march_scroll is additive — two consecutive uses (in same turn)
## stack the bonus to +4. EC-SS-2 (Dictionary overwrite) does NOT apply here
## because move_range_bonus is a numeric field, not a Dictionary.
func test_use_item_march_scroll_stacks_additively_on_second_use() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"march_scroll", &"march_scroll", &""]
	unit.move_range = 3
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	turn_stub.set_unit_turn_state_for_test(1, _make_acting_state(1))
	controller._active_turn_unit_id = 1

	# Act — first use
	var first: bool = controller.use_item(1, 0)
	assert_bool(first).is_true()
	assert_int(controller._units[1].move_range_bonus).is_equal(2)

	# Act — second use (stacks additively)
	var second: bool = controller.use_item(1, 1)

	# Assert
	assert_bool(second).is_true()
	assert_int(controller._units[1].move_range_bonus).override_failure_message(
		"AC-SS-4b: second march_scroll must add additively (2 + 2 = 4)"
	).is_equal(4)
	# Both slots empty
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	assert_str(String(controller._units[1].inventory[1])).is_equal("")
	# refresh_move_token invoked twice (once per use)
	assert_int(turn_stub.refresh_move_token_calls.size()).is_equal(2)


## S90 step 7: is_tile_in_move_range respects move_range_bonus. A unit with
## move_range=3 + bonus=2 can reach Manhattan distance 5 tiles. Without the
## bonus, the same tile would be out-of-range.
func test_is_tile_in_move_range_respects_march_scroll_bonus() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.move_range = 3
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	# Tile at Manhattan 5 from origin (2,2): (2,7) → dx=0, dy=5 → distance 5.

	# Assert — without bonus, distance-5 tile is out of range
	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 7), 1)).override_failure_message(
		"AC-SS-4b: baseline move_range=3 must reject Manhattan-5 tile"
	).is_false()

	# Apply bonus directly (simulates post-march_scroll state)
	controller._units[1].move_range_bonus = 2

	# Assert — with bonus, distance-5 tile now in range
	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 7), 1)).override_failure_message(
		"AC-SS-4b: move_range_bonus=2 must lift Manhattan-5 tile into range"
	).is_true()
	# Distance-6 tile must still be out of range (bonus is +2, not unlimited)
	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 8), 1)).override_failure_message(
		"AC-SS-4b: move_range_bonus does not exceed base + bonus ceiling"
	).is_false()


## S90 step 7: move_range_bonus is cleared at the start of THIS unit's next
## turn. Simulates the bonus surviving through subsequent enemy turns and
## resetting when the unit's own _on_unit_turn_started handler fires.
func test_on_unit_turn_started_clears_march_scroll_bonus() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.move_range_bonus = 2  # leftover from prior turn's march_scroll
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	# Act — simulate the turn-started handler firing for this unit
	controller._on_unit_turn_started(1)

	# Assert
	assert_int(controller._units[1].move_range_bonus).override_failure_message(
		"AC-SS-4b: _on_unit_turn_started must clear move_range_bonus to 0 (bonus expires)"
	).is_equal(0)


# ─── AC-SS-6 fire_scroll cross-class (S91 step 6, OQ-DC-11 = option (b)) ─────


## AC-SS-6 happy path: INFANTRY caster at INT_BASELINE (60) with one enemy
## within FIRE_RANGE (3) fires the scroll, damages the enemy, decrements the
## slot, spends USE_ITEM token, emits unit_item_used. Self-cast default (no
## target_pos passed → resolves to caster.position).
func test_use_item_fire_scroll_infantry_int60_self_cast_hits_adjacent_enemy() -> void:
	# Arrange — caster at (2,2), enemy at (3,2) (Manhattan 1)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.unit_class = UnitRole.UnitClass.INFANTRY
	caster.stat_intellect = 60  # = INT_BASELINE → factor 1.0 → 20 damage
	caster.inventory = [&"fire_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-6: INFANTRY caster at INT_BASELINE must fire fire_scroll successfully"
	).is_true()
	# Damage applied — INT=60 → factor=1.0 → floori(20×1.0)=20
	assert_int(hp_stub.apply_damage_calls.size()).override_failure_message(
		"AC-SS-6: fire_scroll must apply damage to exactly 1 enemy in range"
	).is_equal(1)
	assert_int(hp_stub.apply_damage_calls[0]["unit_id"] as int).is_equal(2)
	assert_int(hp_stub.apply_damage_calls[0]["resolved_damage"] as int).override_failure_message(
		"AC-SS-6: at INT_BASELINE (60), per-tile damage = FIRE_BASE_DAMAGE (20)"
	).is_equal(20)
	# Slot decremented
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	# USE_ITEM token spent (not ATTACK — scroll is item use, not skill)
	assert_int(turn_stub.declared_actions.size()).is_equal(1)
	assert_int(turn_stub.declared_actions[0]["action"] as int).is_equal(
		TurnOrderRunner.ActionType.USE_ITEM as int
	)
	# Signal emit
	assert_int(emitted.size()).is_equal(1)
	assert_str(String(emitted[0]["item"] as StringName)).is_equal("fire_scroll")


## AC-SS-6: STRATEGIST class rejected (wrong_class — STRATEGIST owns native
## fire_strategy; no need for scroll). Slot intact, no damage, no token spend.
func test_use_item_fire_scroll_strategist_caster_rejected_wrong_class() -> void:
	# Arrange — STRATEGIST with high INT (99) but still wrong class
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.unit_class = UnitRole.UnitClass.STRATEGIST
	caster.stat_intellect = 99  # 제갈량 INT — high but irrelevant to class gate
	caster.inventory = [&"fire_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert — full reject path
	assert_bool(fired).override_failure_message(
		"AC-SS-6: STRATEGIST caster must be rejected (wrong_class — owns native)"
	).is_false()
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("fire_scroll")
	assert_int(turn_stub.declared_actions.size()).is_equal(0)


## AC-SS-6: SCOUT class rejected. Mirrors STRATEGIST case but for the second
## excluded class (SCOUT/ARCHER excluded per spec §4.3 table).
func test_use_item_fire_scroll_scout_caster_rejected_wrong_class() -> void:
	# Arrange — SCOUT with INT=75 (조운 baseline) — still wrong class
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.unit_class = UnitRole.UnitClass.SCOUT
	caster.stat_intellect = 75
	caster.inventory = [&"fire_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-6: SCOUT caster must be rejected (wrong_class)"
	).is_false()
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("fire_scroll")


## AC-SS-6: INT gate reject — INFANTRY caster with stat_intellect < INT_BASELINE
## (60). Simulates 장비 (stat_intellect=50) trying to use fire_scroll: class OK
## but INT insufficient. Pillar #3 cross-class protection — 무력형 극단 must NOT
## get a free fire scroll. Slot intact, no damage.
func test_use_item_fire_scroll_int_below_baseline_rejected_int_insufficient() -> void:
	# Arrange — INFANTRY with INT=50 (장비)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.unit_class = UnitRole.UnitClass.INFANTRY
	caster.stat_intellect = 50  # < INT_BASELINE (60)
	caster.inventory = [&"fire_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-6: stat_intellect < INT_BASELINE must reject (int_insufficient gate)"
	).is_false()
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("fire_scroll")


## AC-SS-6 damage scaling sentinel: STRATEGIST native fire_strategy at INT=99
## (제갈량) produces per-tile damage = floori(20 × 1.195) = 23. This regression
## guard ensures the rev-2.9.4 INT scaling path is wired — pre-S91 the value
## would have been a fixed 20.
func test_skill_fire_strategy_int99_scales_damage_to_23() -> void:
	# Arrange — STRATEGIST 제갈량 with INT=99 + 1 enemy at Manhattan 1
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.unit_class = UnitRole.UnitClass.STRATEGIST
	caster.stat_intellect = 99
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)

	# Act
	var fired: bool = controller._skill_fire_strategy(caster)

	# Assert — INT=99 → factor = 1 + (99-60)*0.005 = 1.195 → floori(20×1.195) = 23
	assert_bool(fired).is_true()
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(1)
	assert_int(hp_stub.apply_damage_calls[0]["resolved_damage"] as int).override_failure_message(
		"AC-SS-6 / OQ-DC-11(b): _skill_fire_strategy at INT=99 must apply floori(20 × 1.195) = 23"
	).is_equal(23)


## AC-SS-6 damage scaling sentinel: STRATEGIST native fire_strategy at
## INT_BASELINE (60) produces per-tile damage = floori(20 × 1.0) = 20 — the
## no-behavior-change at baseline guarantee. This sentinel proves the refactor
## (extracted _apply_fire_aoe + INT scaling) leaves baseline-INT callers
## untouched, satisfying OQ-DC-11 option (b) "no-behavior-change at INT=60".
func test_skill_fire_strategy_int60_baseline_keeps_fixed_20_damage() -> void:
	# Arrange — STRATEGIST with INT=60 (= INT_BASELINE) + 1 enemy at Manhattan 1
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.unit_class = UnitRole.UnitClass.STRATEGIST
	caster.stat_intellect = 60
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)

	# Act
	var fired: bool = controller._skill_fire_strategy(caster)

	# Assert — INT=60 → factor=1.0 → damage = floori(20×1.0) = 20 (pre-S91 value)
	assert_bool(fired).is_true()
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(1)
	assert_int(hp_stub.apply_damage_calls[0]["resolved_damage"] as int).override_failure_message(
		"OQ-DC-11(b) no-behavior-change at INT=60: damage must remain at FIRE_BASE_DAMAGE (20)"
	).is_equal(20)


## AC-SS-6 EC-SS-7: enemies outside Manhattan FIRE_RANGE (3) from the AoE
## origin are NOT damaged. Caster at (0,0), in-range enemy at (3,0) hit
## (Manhattan 3 = inclusive), out-of-range enemy at (4,0) not hit.
func test_use_item_fire_scroll_range_check_excludes_out_of_range_enemies() -> void:
	# Arrange — INFANTRY caster + 2 enemies (one in range, one out)
	var caster: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	caster.unit_class = UnitRole.UnitClass.INFANTRY
	caster.stat_intellect = 60
	caster.inventory = [&"fire_scroll", &"", &""]
	var in_range: BattleUnit = _make_unit(2, Vector2i(3, 0), 1)   # Manhattan 3 — included
	var out_of_range: BattleUnit = _make_unit(3, Vector2i(4, 0), 1)  # Manhattan 4 — excluded
	var bag: Dictionary = _setup([caster, in_range, out_of_range] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	hp_stub.set_test_max_hp(3, 100)
	hp_stub.set_test_current_hp(3, 100)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).is_true()
	assert_int(hp_stub.apply_damage_calls.size()).override_failure_message(
		"AC-SS-6 EC-SS-7: only the in-range enemy (Manhattan 3) must be damaged"
	).is_equal(1)
	assert_int(hp_stub.apply_damage_calls[0]["unit_id"] as int).is_equal(2)


# ─── S91+ Phase B step 9 — unit_pending_buff_changed signal + UI target API ───


## strength_scroll use_item emits unit_pending_buff_changed(uid, true) so the
## UI-GB-16 Active Buff Indicator can show the glyph immediately.
func test_strength_scroll_emits_pending_buff_changed_true_on_apply() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"strength_scroll", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_pending_buff_changed.connect(func(uid: int, has_buff: bool) -> void:
		emitted.append({"uid": uid, "has_buff": has_buff})
	)

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).is_true()
	assert_int(emitted.size()).override_failure_message(
		"step 9: strength_scroll must emit unit_pending_buff_changed once on buff apply"
	).is_equal(1)
	assert_int(emitted[0]["uid"] as int).is_equal(1)
	assert_bool(emitted[0]["has_buff"] as bool).is_true()


## _resolve_pending_buff_magnitude emits unit_pending_buff_changed(uid, false)
## on fresh consumption so UI-GB-16 can hide the glyph.
func test_resolve_pending_buff_emits_pending_buff_changed_false_on_consume() -> void:
	# Arrange — buff already stored, ready for consumption
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.pending_buff = {
		&"kind": &"strength",
		&"magnitude": 1.50,
		&"expires_at_turn": 2,  # >= 1 (default round)
	}
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	var emitted: Array = []
	controller.unit_pending_buff_changed.connect(func(uid: int, has_buff: bool) -> void:
		emitted.append({"uid": uid, "has_buff": has_buff})
	)

	# Act
	var magnitude: float = controller._resolve_pending_buff_magnitude(1)

	# Assert
	assert_float(magnitude).is_equal_approx(1.50, 0.001)
	assert_int(emitted.size()).override_failure_message(
		"step 9: buff consumption must emit unit_pending_buff_changed(false)"
	).is_equal(1)
	assert_bool(emitted[0]["has_buff"] as bool).is_false()


## get_item_target_tiles(unit, &"fire_scroll") returns the Manhattan FIRE_RANGE
## disc tile set for a valid caster. Sanity: 25 tiles for a radius-3 diamond
## minus map clipping (no clipping at center of 8x8 grid).
func test_get_item_target_tiles_fire_scroll_returns_manhattan_disc() -> void:
	# Arrange — INFANTRY caster centered at (4,4) on 8x8 grid (no clipping)
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	caster.unit_class = UnitRole.UnitClass.INFANTRY
	caster.stat_intellect = 60
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]

	# Act
	var tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"fire_scroll")

	# Assert — Manhattan ≤ 3 disc = 25 tiles (1 + 4 + 8 + 12 = 25)
	assert_int(tiles.size()).override_failure_message(
		"step 9: fire_scroll target tiles must form a Manhattan-3 disc (25 tiles uncllpped); got %d"
		% tiles.size()
	).is_equal(25)


## get_item_target_tiles returns empty for an invalid caster (wrong class) so
## UI-GB-17 overlay never paints when fire_scroll can't fire.
func test_get_item_target_tiles_fire_scroll_returns_empty_for_strategist() -> void:
	# Arrange — STRATEGIST caster: native fire_strategy owner, scroll rejected
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	caster.unit_class = UnitRole.UnitClass.STRATEGIST
	caster.stat_intellect = 99
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]

	# Act
	var tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"fire_scroll")

	# Assert
	assert_int(tiles.size()).override_failure_message(
		"step 9: STRATEGIST caster on fire_scroll must return 0 target tiles (class reject)"
	).is_equal(0)


## begin_item_target_selection emits item_target_selection_updated(tiles, palette)
## so UI-GB-17 overlay can render. clear_item_target_selection emits empty
## tiles + empty palette for cancel.
func test_begin_and_clear_item_target_selection_emit_overlay_signals() -> void:
	# Arrange
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	caster.unit_class = UnitRole.UnitClass.INFANTRY
	caster.stat_intellect = 60
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]

	var emitted: Array = []
	controller.item_target_selection_updated.connect(func(tiles: PackedVector2Array, palette: StringName) -> void:
		emitted.append({"tiles": tiles, "palette": palette})
	)

	# Act — begin then clear
	controller.begin_item_target_selection(1, &"fire_scroll", &"GROUND")
	controller.clear_item_target_selection()

	# Assert
	assert_int(emitted.size()).is_equal(2)
	# First emit: 25-tile Manhattan disc, GROUND palette
	assert_int((emitted[0]["tiles"] as PackedVector2Array).size()).is_equal(25)
	assert_str(String(emitted[0]["palette"] as StringName)).is_equal("GROUND")
	# Second emit: empty tiles + empty palette (clear convention)
	assert_int((emitted[1]["tiles"] as PackedVector2Array).size()).is_equal(0)
	assert_str(String(emitted[1]["palette"] as StringName)).is_equal("")


## AC-SS-6 damage formula identity: INFANTRY fire_scroll caster at INT=60 vs
## STRATEGIST native fire_strategy caster at INT=60 produce identical per-tile
## damage. Both call the shared _apply_fire_aoe helper so the assertion is
## structural — if either path drifts from the helper, this test catches it.
func test_fire_scroll_and_fire_strategy_produce_identical_damage_at_int_baseline() -> void:
	# Arrange — two identical-stat casters, one INFANTRY (scroll), one STRATEGIST (skill)
	var scroll_caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	scroll_caster.unit_class = UnitRole.UnitClass.INFANTRY
	scroll_caster.stat_intellect = 60
	scroll_caster.inventory = [&"fire_scroll", &"", &""]
	var scroll_victim: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var skill_caster: BattleUnit = _make_unit(3, Vector2i(6, 6), 0)
	skill_caster.unit_class = UnitRole.UnitClass.STRATEGIST
	skill_caster.stat_intellect = 60
	var skill_victim: BattleUnit = _make_unit(4, Vector2i(7, 6), 1)
	var bag: Dictionary = _setup([scroll_caster, scroll_victim, skill_caster, skill_victim] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	for vid: int in [2, 4]:
		hp_stub.set_test_max_hp(vid, 100)
		hp_stub.set_test_current_hp(vid, 100)

	# Act — fire scroll first (records 1 damage call on victim 2)
	controller._active_turn_unit_id = 1
	controller.use_item(1, 0)
	# Then native skill (records 1 damage call on victim 4)
	controller._active_turn_unit_id = 3
	controller._skill_fire_strategy(skill_caster)

	# Assert — both calls land identical damage values
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(2)
	var scroll_damage: int = hp_stub.apply_damage_calls[0]["resolved_damage"] as int
	var skill_damage: int = hp_stub.apply_damage_calls[1]["resolved_damage"] as int
	assert_int(scroll_damage).override_failure_message(
		"AC-SS-6 identity: fire_scroll damage (%d) must equal fire_strategy damage (%d) at same INT" %
		[scroll_damage, skill_damage]
	).is_equal(skill_damage)
