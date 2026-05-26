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
## S90 step 7 update: march_scroll moved to "wired" list; use fire_scroll
## (Phase B step 6 pending OQ-DC-11) as the unwired test fixture.
func test_use_item_unwired_item_id_rejected_with_warning() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"fire_scroll", &"", &""]  # Phase B step 6 — unwired through step 7
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
		"AC-SS-4: inventory[0] must remain &\"fire_scroll\" on unwired reject"
	).is_equal("fire_scroll")


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
