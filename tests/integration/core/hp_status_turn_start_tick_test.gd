extends GdUnitTestSuite

## hp_status_turn_start_tick_test.gd
## Integration tests for HP/Status story-006:
##   _apply_turn_start_tick (DoT, duration decrement, expiry, DEMORALIZED recovery)
##   get_modified_stat (F-4 formula, EXHAUSTED move special-case)
##   get_status_effects (shallow copy)
##   GameBus.unit_turn_started subscription lifecycle
##
## Covers AC-1 through AC-14 from story-006 §Acceptance Criteria (21 test functions).
##
## Governing ADR: ADR-0010 — HP/Status §8 turn-start tick + §9 F-4 + §11 DI seam.
## Design reference: production/epics/hp-status/story-006-turn-start-tick-and-f4.md
##
## TEST CLASSIFICATION: Integration — crosses GameBus boundary (subscription lifecycle).
## Uses _apply_turn_start_tick() test seam for tick logic; GameBus.unit_died captured
## via Array captures pattern (G-4).
##
## GOTCHA AWARENESS:
##   G-4  — lambda captures: use Array.append pattern, NOT primitive reassignment
##   G-6  — orphan detection fires BETWEEN test body exit and after_test
##   G-9  — % operator precedence; wrap multi-line concat in parens
##   G-12 — MapTileData (NOT TileData — collides with Godot built-in)
##   G-14 — new class_name (MapGridStub) needs headless --import pass before first run
##   G-15 — before_test() is canonical hook (NOT before_each)
##   G-24 — as operator precedence; wrap RHS cast in parens in == expressions


# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript

# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController
var _map_grid_stub: MapGridStub


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Resets BalanceConstants + UnitRole static caches.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	_map_grid_stub = MapGridStub.new()
	_controller._map_grid = _map_grid_stub
	# G-6: parent the stub to the controller so the orphan detector (which fires
	# BETWEEN test body and after_test) sees it as a tree-attached node, not orphan.
	# When the controller is freed by GdUnit4 teardown, the stub is freed with it.
	_controller.add_child(_map_grid_stub)
	add_child(_controller)


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

## Builds a minimal HeroData with explicit base_hp_seed and optional faction.
## Mirrors hp_status_apply_status_test.gd pattern with faction parameter added
## for DEMORALIZED recovery ally-proximity tests (AC-7a/7b).
func _make_hero(p_base_hp_seed: int = 50, p_faction: int = 0) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	hero.faction = p_faction
	return hero


# ── AC-1a: GameBus subscription wired on enter_tree ──────────────────────────

## AC-1a: after add_child in before_test, unit_turn_started must be connected
## to _on_unit_turn_started with CONNECT_DEFERRED per ADR-0010 §11.
func test_enter_tree_connects_unit_turn_started() -> void:
	# before_test already called add_child(_controller) — subscription is live.
	assert_bool(
		GameBus.unit_turn_started.is_connected(Callable(_controller, "_on_unit_turn_started"))
	).override_failure_message(
		"AC-1a: GameBus.unit_turn_started must be connected to _on_unit_turn_started after add_child"
	).is_true()


# ── AC-1b: disconnect on exit_tree ───────────────────────────────────────────

## AC-1b: remove_child triggers _exit_tree → signal disconnected.
## Note: this test mutates _controller (sets null). after_test handles null safely
## via the cache-reset script path (no node cleanup needed — queue_free was called).
func test_exit_tree_disconnects_unit_turn_started() -> void:
	# Precondition: connected (from before_test add_child)
	assert_bool(
		GameBus.unit_turn_started.is_connected(Callable(_controller, "_on_unit_turn_started"))
	).override_failure_message(
		"AC-1b precondition: must be connected before remove_child"
	).is_true()

	# Act: remove from tree → _exit_tree fires
	remove_child(_controller)
	assert_bool(
		GameBus.unit_turn_started.is_connected(Callable(_controller, "_on_unit_turn_started"))
	).override_failure_message(
		"AC-1b: signal must be disconnected after remove_child / _exit_tree"
	).is_false()

	# Cleanup: free the orphaned node immediately per G-6 (orphan detection fires before after_test)
	_controller.free()
	_controller = null


# ── AC-2: 3-tick POISON cumulative DoT ───────────────────────────────────────

## AC-2: POISON (3 turns) deals DoT once per tick for 3 ticks, then expires.
## DoT formula: clamp(floor(max_hp * 0.04) + 3, 1, 20) — from poison.tres TickEffect.
func test_poison_dot_cumulative_three_ticks() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"poison", -1, 99)
	var max_hp: int = _controller.get_max_hp(1)
	var dot_per_tick: int = clamp(int(floor(max_hp * 0.04)) + 3, 1, 20)

	# Act: 3 ticks
	_controller._apply_turn_start_tick(1)
	_controller._apply_turn_start_tick(1)
	_controller._apply_turn_start_tick(1)

	# Assert: HP reduced by dot × 3; POISON expired (remaining_turns decremented 3→2→1→0)
	var expected_hp: int = max_hp - dot_per_tick * 3
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-2: current_hp must be max_hp - dot*3 = %d after 3 POISON ticks; "
		+ "dot_per_tick=%d max_hp=%d") % [expected_hp, dot_per_tick, max_hp]
	).is_equal(expected_hp)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-2: POISON must have expired after 3 ticks (size=0)"
	).is_equal(0)


# ── AC-2 edge: 4th tick no DoT after POISON expiry ───────────────────────────

## AC-2 edge: 4th tick fires after POISON expired — HP must NOT decrease further.
func test_poison_no_dot_after_expiry_on_fourth_tick() -> void:
	# Arrange + 3 ticks (same setup as AC-2)
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"poison", -1, 99)
	var max_hp: int = _controller.get_max_hp(1)
	var dot_per_tick: int = clamp(int(floor(max_hp * 0.04)) + 3, 1, 20)
	_controller._apply_turn_start_tick(1)
	_controller._apply_turn_start_tick(1)
	_controller._apply_turn_start_tick(1)
	var hp_after_3: int = _controller.get_current_hp(1)

	# Verify precondition: POISON gone
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-2 edge precondition: POISON must be expired after 3 ticks"
	).is_equal(0)

	# Act: 4th tick
	_controller._apply_turn_start_tick(1)

	# Assert: HP unchanged from post-3-tick value
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-2 edge: HP must not decrease on 4th tick after POISON expiry; "
		+ "hp_after_3=%d got=%d") % [hp_after_3, _controller.get_current_hp(1)]
	).is_equal(hp_after_3)
	# Verify the total damage matches expectation: 3 ticks only
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-2 edge: final HP must equal max_hp - dot*3 (no 4th tick DoT)"
	).is_equal(max_hp - dot_per_tick * 3)


# ── AC-3: DoT bypasses F-1 (not reduced by DEFEND_STANCE) ────────────────────

## AC-3: POISON DoT is true damage — bypasses SHIELD_WALL_FLAT + DEFEND_STANCE reduction.
## Apply INFANTRY (passive_shield_wall) + DEFEND_STANCE + POISON simultaneously.
## POISON tick damage must equal the raw F-3 DoT, NOT less.
func test_poison_dot_bypasses_f1_intake_with_defend_stance_active() -> void:
	# Arrange: INFANTRY has passive_shield_wall; add DEFEND_STANCE + POISON
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"defend_stance", -1, 99)  # ACTION_LOCKED
	_controller.apply_status(1, &"poison", -1, 99)          # TURN_BASED
	var max_hp: int = _controller.get_max_hp(1)
	var expected_dot: int = clamp(int(floor(max_hp * 0.04)) + 3, 1, 20)

	# Act: 1 tick
	_controller._apply_turn_start_tick(1)

	# Assert: damage equals raw DoT (not reduced by DEFEND_STANCE or shield wall)
	var actual_damage: int = max_hp - _controller.get_current_hp(1)
	assert_int(actual_damage).override_failure_message(
		("AC-3: POISON DoT must bypass F-1; expected raw dot=%d but actual damage=%d "
		+ "(would be less if DEFEND_STANCE or SHIELD_WALL_FLAT applied)") % [expected_dot, actual_damage]
	).is_equal(expected_dot)


# ── AC-4: POISON kill emits unit_died ────────────────────────────────────────

## AC-4: POISON DoT reduces HP to 0 → GameBus.unit_died emitted; is_alive returns false.
## Uses G-4 Array captures pattern for signal emission capture.
func test_poison_kill_emits_unit_died() -> void:
	# Arrange: unit with enough POISON DoT to kill in 1 tick
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"poison", -1, 99)
	var max_hp: int = _controller.get_max_hp(1)
	# Force current_hp just above 0 but below dot (dot = clamp(floor(max_hp*0.04)+3, 1, 20))
	# dot is at most 20; force current_hp = 1 to guarantee kill regardless of exact dot
	_controller._state_by_unit[1].current_hp = 1

	# Set up signal capture (G-4: array mutation, NOT primitive reassignment)
	var captures: Array = []
	GameBus.unit_died.connect(func(uid: int) -> void:
		captures.append({"unit_id": uid})
	)

	# Act: tick → POISON DoT kills
	_controller._apply_turn_start_tick(1)

	# Cleanup signal listener
	GameBus.unit_died.disconnect(GameBus.unit_died.get_connections()[0].callable)

	# Assert: unit died
	assert_int(captures.size()).override_failure_message(
		"AC-4: unit_died must have been emitted exactly once on POISON kill"
	).is_equal(1)
	assert_int((captures[0] as Dictionary)["unit_id"] as int).override_failure_message(
		"AC-4: unit_died must carry unit_id=1"
	).is_equal(1)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-4: current_hp must be 0 after POISON kill"
	).is_equal(0)
	assert_bool(_controller.is_alive(1)).override_failure_message(
		"AC-4: is_alive must be false after POISON kill"
	).is_false()


# ── AC-5: reverse-index decrement + expiry (3 effects → 2 after 1 tick) ──────

## AC-5: Apply POISON (3 turns) + INSPIRED (2 turns) + EXHAUSTED (1 turn).
## After 1 tick: POISON.remaining_turns=2, INSPIRED=1; EXHAUSTED expired (was 1→0).
## Size goes from 3 to 2. Reverse-index removal must not skip elements (delta-#7 Item 7).
func test_reverse_index_decrement_and_expiry_removes_zero_turn_effects() -> void:
	# Arrange: 3 effects
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"poison", -1, 99)     # TURN_BASED, 3 turns
	_controller.apply_status(1, &"inspired", -1, 99)   # TURN_BASED, 2 turns
	_controller.apply_status(1, &"exhausted", -1, 99)  # TURN_BASED, 2 turns (override to 1 for test)
	# Override EXHAUSTED to 1 turn so it expires on first tick
	_controller._state_by_unit[1].status_effects[2].remaining_turns = 1
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-5 precondition: 3 effects must be active"
	).is_equal(3)

	# Act: 1 tick
	_controller._apply_turn_start_tick(1)

	# Assert: EXHAUSTED expired; POISON and INSPIRED remain with decremented turns
	var effects: Array = _controller._state_by_unit[1].status_effects
	assert_int(effects.size()).override_failure_message(
		"AC-5: size must be 2 after EXHAUSTED (remaining_turns=0) expires"
	).is_equal(2)
	# POISON tick fires first (DoT), then decrements: starts 3 → after tick = 2
	assert_bool((effects[0] as StatusEffect).effect_id == &"poison").override_failure_message(
		"AC-5: effects[0] must be POISON (insertion order preserved after reverse removal)"
	).is_true()
	assert_int((effects[0] as StatusEffect).remaining_turns).override_failure_message(
		"AC-5: POISON remaining_turns must be 2 after 1 tick (3→2)"
	).is_equal(2)
	assert_bool((effects[1] as StatusEffect).effect_id == &"inspired").override_failure_message(
		"AC-5: effects[1] must be INSPIRED (insertion order preserved)"
	).is_true()
	assert_int((effects[1] as StatusEffect).remaining_turns).override_failure_message(
		"AC-5: INSPIRED remaining_turns must be 1 after 1 tick (2→1)"
	).is_equal(1)


# ── AC-6: DEFEND_STANCE ACTION_LOCKED removal after 1 tick ───────────────────

## AC-6: DEFEND_STANCE (ACTION_LOCKED, duration_type=2) is unconditionally removed
## on the next turn-start tick per CR-13. SE-3: 1-turn DEFEND_STANCE expiry.
func test_defend_stance_action_locked_removed_on_tick() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"defend_stance", -1, 99)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-6 precondition: DEFEND_STANCE must be active (size=1)"
	).is_equal(1)

	# Act: 1 tick
	_controller._apply_turn_start_tick(1)

	# Assert: DEFEND_STANCE removed unconditionally by ACTION_LOCKED branch
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-6: DEFEND_STANCE must be removed after 1 tick (ACTION_LOCKED unconditional expiry)"
	).is_equal(0)


# ── AC-7a: DEMORALIZED recovery with nearby Commander ally ────────────────────

## AC-7a: DEMORALIZED unit with same-faction Commander within DEMORALIZED_RECOVERY_RADIUS=2.
## After 1 tick, DEMORALIZED is removed (CR-6 SE-2 recovery).
func test_demoralized_recovery_with_nearby_commander_ally() -> void:
	# Arrange: place demoralized Infantry unit at (0,0); Commander ally at (1,0) — distance=1
	_map_grid_stub.set_dimensions_for_test(Vector2i(8, 8))
	_map_grid_stub.set_occupant_for_test(Vector2i(0, 0), 1)  # unit 1 at (0,0)
	_map_grid_stub.set_occupant_for_test(Vector2i(1, 0), 99) # Commander ally at (1,0)

	var hero1: HeroData = _make_hero(50, 0)
	hero1.stat_might = 80
	hero1.stat_command = 80
	hero1.stat_intellect = 80
	hero1.base_initiative_seed = 60
	hero1.move_range = 4
	_controller.initialize_unit(1, hero1, UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"demoralized", -1, 99)

	var hero99: HeroData = _make_hero(50, 0)  # same faction=0
	hero99.stat_might = 80
	hero99.stat_command = 80
	hero99.stat_intellect = 80
	hero99.base_initiative_seed = 60
	hero99.move_range = 4
	_controller.initialize_unit(99, hero99, UnitRole.UnitClass.COMMANDER)

	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-7a precondition: DEMORALIZED must be active"
	).is_equal(1)

	# Act: 1 tick
	_controller._apply_turn_start_tick(1)

	# Assert: DEMORALIZED removed (ally Commander within radius=2)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-7a: DEMORALIZED must be removed when ally Commander is within DEMORALIZED_RECOVERY_RADIUS=2"
	).is_equal(0)


# ── AC-7b: DEMORALIZED retained when Commander too far ───────────────────────

## AC-7b: Same-faction Commander at (5,5) — manhattan distance from (0,0) = 10 > radius=2.
## After 1 tick, DEMORALIZED is retained (radius check fails → no recovery).
func test_demoralized_retained_when_ally_commander_beyond_radius() -> void:
	# Arrange: unit 1 at (0,0); Commander at (5,5) — distance=10 > radius=2
	_map_grid_stub.set_dimensions_for_test(Vector2i(8, 8))
	_map_grid_stub.set_occupant_for_test(Vector2i(0, 0), 1)  # unit 1
	_map_grid_stub.set_occupant_for_test(Vector2i(5, 5), 99) # Commander far away

	var hero1: HeroData = _make_hero(50, 0)
	hero1.stat_might = 80
	hero1.stat_command = 80
	hero1.stat_intellect = 80
	hero1.base_initiative_seed = 60
	hero1.move_range = 4
	_controller.initialize_unit(1, hero1, UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"demoralized", -1, 99)

	var hero99: HeroData = _make_hero(50, 0)  # same faction=0
	hero99.stat_might = 80
	hero99.stat_command = 80
	hero99.stat_intellect = 80
	hero99.base_initiative_seed = 60
	hero99.move_range = 4
	_controller.initialize_unit(99, hero99, UnitRole.UnitClass.COMMANDER)

	# Advance DEMORALIZED duration to reflect 1 tick decrement; it won't expire (CONDITION_BASED)
	# DEMORALIZED is duration_type=1 (CONDITION_BASED) — does NOT decrement per _apply_turn_start_tick

	# Act: 1 tick
	_controller._apply_turn_start_tick(1)

	# Assert: DEMORALIZED NOT removed (commander beyond recovery radius)
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-7b: DEMORALIZED must be retained when ally Commander is beyond DEMORALIZED_RECOVERY_RADIUS=2"
	).is_equal(1)
	assert_bool(
		(_controller._state_by_unit[1].status_effects[0] as StatusEffect).effect_id == &"demoralized"
	).override_failure_message(
		"AC-7b: effects[0] must still be DEMORALIZED"
	).is_true()


# ── AC-8: F-4 DEMORALIZED + INSPIRED → -5 net modifier ──────────────────────

## AC-8: DEMORALIZED (-25 atk modifier) + INSPIRED (+20 atk modifier) → net -5.
## F-4: clamp(-5, -50, 50) = -5 → atk * (1 + -5/100) = atk * 0.95 = floor(atk * 0.95).
## Uses UnitRole.get_atk capture rather than hardcoded value (robust to balance tuning).
func test_f4_demoralized_and_inspired_net_minus_five_modifier() -> void:
	# Arrange
	var hero: HeroData = _make_hero(50, 0)
	hero.stat_might = 80
	hero.stat_command = 80
	hero.stat_intellect = 80
	hero.base_initiative_seed = 60
	hero.move_range = 4
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"demoralized", -1, 99)  # -25 atk modifier
	_controller.apply_status(1, &"inspired", -1, 99)     # +20 atk modifier

	# Capture actual base (robust to balance JSON changes)
	var base_atk: int = UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	var expected: int = max(1, int(floor(base_atk * (1 + (-5) / 100.0))))

	# Act + Assert
	assert_int(_controller.get_modified_stat(1, &"atk")).override_failure_message(
		("AC-8: DEMORALIZED + INSPIRED → net -5 → atk * 0.95 = %d; "
		+ "base_atk=%d") % [expected, base_atk]
	).is_equal(expected)


# ── AC-9: F-4 DEMORALIZED + DEFEND_STANCE → clamped to -50 ──────────────────

## AC-9: DEMORALIZED (-25) + DEFEND_STANCE (-40) = -65 → clamped to MODIFIER_FLOOR=-50.
## F-4: atk * (1 + -50/100) = atk * 0.50.
func test_f4_demoralized_and_defend_stance_clamped_to_floor() -> void:
	# Arrange: apply DEMORALIZED first; then DEFEND_STANCE (no CR-7 conflict between them)
	var hero: HeroData = _make_hero(50, 0)
	hero.stat_might = 80
	hero.stat_command = 80
	hero.stat_intellect = 80
	hero.base_initiative_seed = 60
	hero.move_range = 4
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"demoralized", -1, 99)   # -25 atk modifier
	_controller.apply_status(1, &"defend_stance", -1, 99) # -40 atk modifier

	var base_atk: int = UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	# -65 clamped to MODIFIER_FLOOR=-50 → atk * 0.50
	var expected: int = max(1, int(floor(base_atk * (1 + (-50) / 100.0))))

	assert_int(_controller.get_modified_stat(1, &"atk")).override_failure_message(
		("AC-9: DEMORALIZED + DEFEND_STANCE → -65 clamped to -50 → atk * 0.50 = %d; "
		+ "base_atk=%d") % [expected, base_atk]
	).is_equal(expected)


# ── AC-10: F-4 INSPIRED + DEFEND_STANCE → -20 net modifier ──────────────────

## AC-10: INSPIRED (+20) + DEFEND_STANCE (-40) = -20 (within bounds, no clamping).
## F-4: atk * (1 + -20/100) = atk * 0.80.
func test_f4_inspired_and_defend_stance_net_minus_twenty_modifier() -> void:
	# Arrange: apply INSPIRED then DEFEND_STANCE (no CR-7 conflict between them)
	var hero: HeroData = _make_hero(50, 0)
	hero.stat_might = 80
	hero.stat_command = 80
	hero.stat_intellect = 80
	hero.base_initiative_seed = 60
	hero.move_range = 4
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"inspired", -1, 99)      # +20 atk modifier
	_controller.apply_status(1, &"defend_stance", -1, 99) # -40 atk modifier

	var base_atk: int = UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	# +20 + (-40) = -20 (within [-50, +50] bounds — no clamping needed)
	var expected: int = max(1, int(floor(base_atk * (1 + (-20) / 100.0))))

	assert_int(_controller.get_modified_stat(1, &"atk")).override_failure_message(
		("AC-10: INSPIRED + DEFEND_STANCE → net -20 → atk * 0.80 = %d; "
		+ "base_atk=%d") % [expected, base_atk]
	).is_equal(expected)


# ── AC-11a: EXHAUSTED flat -1 move range special-case ────────────────────────

## AC-11a: EXHAUSTED active → effective_move_range gets flat -1 (not percent).
## F-4 percent modifier = 0 (EXHAUSTED has no modifier_targets); then special-case
## branch applies max(1, result - EXHAUSTED_MOVE_REDUCTION=1).
func test_exhausted_flat_minus_one_move_range() -> void:
	# Arrange: CAVALRY (class_move_delta=+1) with hero.move_range=4 → base = clampi(5, 2, 6) = 5
	var hero: HeroData = _make_hero(50, 0)
	hero.move_range = 4
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"exhausted", -1, 99)

	var base_move: int = UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.CAVALRY)
	# EXHAUSTED has no modifier_targets → F-4 percent step = 0; special case: result - 1
	var expected: int = max(1, base_move - 1)

	assert_int(_controller.get_modified_stat(1, &"effective_move_range")).override_failure_message(
		("AC-11a: EXHAUSTED must apply flat -1 to effective_move_range; "
		+ "base=%d expected=%d") % [base_move, expected]
	).is_equal(expected)


# ── AC-11b: EXHAUSTED floor protection: max(1, result) ───────────────────────

## AC-11b: Even if base - 1 would produce 0, max(1, result) floors to 1.
## MOVE_RANGE_MIN=2 means get_effective_move_range never returns < 2 for any valid hero.
## Therefore base - 1 = 1 is the minimum achievable via normal fixture (not 0).
## This test verifies the formula max(1, base - 1) for base=2 produces 1 (NOT 0 or negative).
## The max(1, ...) guard in get_modified_stat handles the pure math invariant for base=1
## hypothetically — structural floor protection is verified here via the lowest achievable base.
func test_exhausted_move_range_floor_never_below_one() -> void:
	# Arrange: STRATEGIST (class_move_delta=-1) with hero.move_range=3 → clampi(2, 2, 6)=2
	# This is the minimum base achievable (MOVE_RANGE_MIN=2 enforced by get_effective_move_range)
	var hero: HeroData = _make_hero(50, 0)
	hero.move_range = 3  # 3 + (-1) = 2, clamped to MOVE_RANGE_MIN=2
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.STRATEGIST)
	_controller.apply_status(1, &"exhausted", -1, 99)

	var base_move: int = UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.STRATEGIST)
	# base = 2; max(1, 2 - 1) = 1 — floor protection active
	var expected: int = max(1, base_move - 1)

	var result: int = _controller.get_modified_stat(1, &"effective_move_range")
	assert_int(result).override_failure_message(
		("AC-11b: EXHAUSTED on min-base unit (base=%d) must produce max(1, base-1)=%d; "
		+ "got=%d — floor must never be 0 or negative") % [base_move, expected, result]
	).is_equal(expected)
	assert_bool(result >= 1).override_failure_message(
		"AC-11b: effective_move_range must always be >= 1 even with EXHAUSTED active"
	).is_true()


# ── AC-11c: No EXHAUSTED → base move range unchanged ─────────────────────────

## AC-11c: Without EXHAUSTED, get_modified_stat returns the base from UnitRole (no special case).
func test_no_exhausted_move_range_equals_base() -> void:
	# Arrange: no status effects
	var hero: HeroData = _make_hero(50, 0)
	hero.move_range = 4
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)
	var base_move: int = UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.CAVALRY)

	assert_int(_controller.get_modified_stat(1, &"effective_move_range")).override_failure_message(
		("AC-11c: without EXHAUSTED, effective_move_range must equal base=%d "
		+ "(special-case branch must NOT fire)") % base_move
	).is_equal(base_move)


# ── AC-12: unknown stat_name returns 0 ────────────────────────────────────────

## AC-12: get_modified_stat with unrecognized stat_name returns 0 per ADR-0010 §9 line 388.
## push_error fires internally — not captured (G-22: no assert_error for push_error).
func test_unknown_stat_name_returns_zero() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)

	# AC-12: push_error visible in stderr; structural check on return value only
	assert_int(_controller.get_modified_stat(1, &"foo_bar")).override_failure_message(
		"AC-12: get_modified_stat with unknown stat_name must return 0"
	).is_equal(0)


# ── AC-13: DI seam — _map_grid injected by before_test ───────────────────────

## AC-13: _map_grid is non-null and is a MapGridStub instance after before_test injection.
## Verifies the DI seam (ADR-0010 §11 R-3) works correctly in test context.
func test_di_seam_map_grid_injected_in_before_test() -> void:
	# AC-13: DI seam — _map_grid is field-injected via before_test fixture.
	# Direct _apply_turn_start_tick(1) calls work in all tests by construction.
	assert_object(_controller._map_grid).override_failure_message(
		"AC-13: _map_grid must be non-null after before_test injection"
	).is_not_null()
	assert_object(_controller._map_grid).override_failure_message(
		"AC-13: _map_grid must be an instance of MapGridStub"
	).is_instanceof(MapGridStub)


# ── AC-14: POISON kill on HP=1 ───────────────────────────────────────────────

## AC-14: Force current_hp=1 with POISON active; DoT kills (1 - dot < 0 → 0).
## unit_died emitted; current_hp=0; is_alive=false.
func test_poison_kill_on_hp_one_emits_unit_died() -> void:
	# Arrange: INFANTRY with POISON; force HP to 1
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller.apply_status(1, &"poison", -1, 99)
	var max_hp: int = _controller.get_max_hp(1)
	var dot: int = clamp(int(floor(max_hp * 0.04)) + 3, 1, 20)
	# Ensure dot >= 1 (guaranteed by dot_min=1 in poison.tres) so HP=1 → kill
	_controller._state_by_unit[1].current_hp = 1

	# Capture unit_died via G-4 Array pattern
	var captures: Array = []
	GameBus.unit_died.connect(func(uid: int) -> void:
		captures.append({"unit_id": uid})
	)

	# Act
	_controller._apply_turn_start_tick(1)

	# Cleanup signal listener
	GameBus.unit_died.disconnect(GameBus.unit_died.get_connections()[0].callable)

	# Assert
	assert_int(captures.size()).override_failure_message(
		"AC-14: unit_died must be emitted exactly once when POISON kills unit with HP=1"
	).is_equal(1)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-14: current_hp must be 0 after POISON kill"
	).is_equal(0)
	assert_bool(_controller.is_alive(1)).override_failure_message(
		"AC-14: is_alive must be false after POISON kills unit with HP=1"
	).is_false()


# ── AC bonus: get_status_effects shallow copy ─────────────────────────────────

## AC bonus-1: get_status_effects returns a shallow copy (different Array object).
## Mutations to the returned array do not affect the authoritative state.
func test_get_status_effects_returns_shallow_copy() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller.apply_status(1, &"poison", -1, 99)

	# Act: get copy + mutate it
	var copy: Array = _controller.get_status_effects(1)
	copy.clear()  # mutate the copy

	# Assert: authoritative array untouched
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC bonus-1: clearing the returned shallow copy must not affect authoritative status_effects"
	).is_equal(1)


## AC bonus-2: get_status_effects returns empty Array for unknown unit_id.
func test_get_status_effects_returns_empty_for_unknown_unit() -> void:
	# Arrange: unit 99 never initialized
	var result: Array = _controller.get_status_effects(99)

	assert_int(result.size()).override_failure_message(
		"AC bonus-2: get_status_effects for unknown unit_id must return empty Array"
	).is_equal(0)
