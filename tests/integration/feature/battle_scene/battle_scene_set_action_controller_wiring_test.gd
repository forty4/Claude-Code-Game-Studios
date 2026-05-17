extends GdUnitTestSuite

## battle_scene_set_action_controller_wiring_test.gd
## Integration tests for Story S15-J (POLISH-012 closure):
##   - AC-1 (enemy-side): T5 fire for enemy unit triggers ai_action_requested emit
##   - AC-1 (player-side): T5 fire for player unit returns without dispatch
##   - AC-1 (defensive): unknown unit_id → push_warning + no dispatch
##   - AC-2: BattleScene._ready STEP 5 calls set_action_controller with correct Callable
##   - AC-6: set_action_controller DI surface contract unchanged for existing callers
##
## Pre-condition: HeroDatabase static state pre-seeded (mirrors battle_scene_smoke_test.gd
## IN-12 pattern). BattleScene.tscn loads live and triggers the full mount sequence
## including the S15-J STEP 5 wire-up.
##
## Governing ADRs:
##   ADR-0011 §Amendment 2026-05-09 (T5 await Callable contract)
##   ADR-0014 §Amendment 2026-05-10 (#3 — S15-J production-wiring residual closure)
##   ADR-0019 (AISystem ai_action_requested → ai_action_ready chain)
##
## GOTCHA AWARENESS:
##   G-4  — lambda primitive capture; use Array captures pattern (NOT bool/int locals)
##   G-6  — explicit free() at end of test body for Node-typed deps + orphan detection
##   G-10 — autoload identifier binds at engine init; emit on real GameBus only
##   G-15 — before_test() is canonical hook (NOT before_each)
##   G-27 — CONNECT_DEFERRED subscribers see post-transition state; await process_frame
##   G-28 — never bulk-disconnect-all; only disconnect test-owned handlers

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"

# Chapter-1 (Phase A 도원결의) roster hero IDs — mirrors battle_scene_smoke_test.gd MOCK_HERO_IDS.
# Player unit IDs are 1,2 (is_player=true, side=0); enemy unit IDs 3-6 (side=1).
# Sourced from BattleScene._build_battle_units_from_chapter() + chapter-1 fixture.
const HERO_LIU_BEI: StringName     = &"shu_001_liu_bei"
const HERO_GUAN_YU: StringName     = &"shu_002_guan_yu"
const HERO_ZHANG_FEI: StringName   = &"shu_003_zhang_fei"
const HERO_ZHOU_YU: StringName     = &"wu_003_zhou_yu"
const HERO_CAO_CAO: StringName     = &"wei_001_cao_cao"
const HERO_XIAHOU_DUN: StringName  = &"wei_005_xiahou_dun"
const HERO_ZHANG_LIAO: StringName  = &"wei_006_zhang_liao"
const HERO_YU_JIN: StringName      = &"wei_007_yu_jin"
const HERO_XU_CHU: StringName      = &"wei_008_xu_chu"

# Phase A — first chapter (ch01_taoyuan_yellow_turban) includes 관우 (uid=6).
const MOCK_HERO_IDS: Array[StringName] = [
	HERO_LIU_BEI, HERO_GUAN_YU, HERO_ZHANG_FEI, HERO_ZHOU_YU, HERO_CAO_CAO,
	HERO_XIAHOU_DUN, HERO_ZHANG_LIAO, HERO_YU_JIN, HERO_XU_CHU,
]

# Chapter-1 player unit_ids (from mvp_chapter_06.tres player_unit_ids field).
# Side=0 (is_player=true). BattleScene assigns unit_id from chapter.player_unit_ids.
# Hardcoded to 1 and 2 per _build_battle_units_from_chapter() ordering.
const PLAYER_UID_1: int = 1
const PLAYER_UID_2: int = 2

# Chapter-1 enemy unit_id — first enemy entry from enemy_roster.
# unit_id 3 is the first enemy in mvp_chapter_06.tres enemy_roster list.
# Verified safe: BattleScene._build_battle_units_from_chapter uses enemy_roster[i].unit_id.
const ENEMY_UID_FIRST: int = 3

# Nonexistent unit_id for defensive-path testing.
const UNKNOWN_UID: int = 99999


# ─── Suite state ──────────────────────────────────────────────────────────────

## G-4: Array captures for signal observation (never primitive locals in lambdas).
var _ai_action_requested_calls: Array = []


# ─── Lifecycle hooks ──────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Pre-seeds HeroDatabase before BattleScene._ready() fires — mirrors IN-12.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}
	_ai_action_requested_calls.clear()
	_seed_hero_database()


func after_test() -> void:
	## G-15 idempotent crash-safety net.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


# ─── Fixture builders ─────────────────────────────────────────────────────────

func _seed_hero_database() -> void:
	## IN-12: inject minimum-viable HeroData into static state + flip
	## `_heroes_loaded = true` so HeroDatabase.get_hero() short-circuits the
	## file-load path that fails in headless mode.
	for hero_id: StringName in MOCK_HERO_IDS:
		var hero: HeroData = HeroData.new()
		hero.hero_id = hero_id
		hero.name_ko = String(hero_id)
		HeroDatabase._heroes[hero_id] = hero
	HeroDatabase._heroes_loaded = true


func _instantiate_and_mount_battle_scene() -> BattleScene:
	## Instantiates and adds BattleScene to the test tree, triggering _ready().
	## Caller is responsible for: await get_tree().process_frame + scene.free().
	var packed: PackedScene = preload(BATTLE_SCENE_PATH)
	var scene: BattleScene = packed.instantiate() as BattleScene
	add_child(scene)
	return scene


# ─── Test 1 (AC-2): BattleScene mount registers set_action_controller ────────

## AC-2 (S15-J): BattleScene._ready STEP 5 registers the Callable on TurnOrderRunner.
## Given: BattleScene mounted via add_child (triggers _ready → STEP 5 wire-up).
## When: await process_frame (allows _ready to complete synchronously + signals to settle).
## Then: _turn_runner._action_controller is NOT null; method name is _on_turn_runner_action_request.
func test_battle_scene_mount_registers_set_action_controller_callable() -> void:
	# Arrange + Act
	var scene: BattleScene = _instantiate_and_mount_battle_scene()
	await get_tree().process_frame

	# Assert — _action_controller must be non-null after STEP 5 wire-up
	var runner: TurnOrderRunner = scene.get_node_or_null("TurnOrderRunner") as TurnOrderRunner
	assert_object(runner).override_failure_message(
		"AC-2: TurnOrderRunner must be mounted and resolvable"
	).is_not_null()

	assert_bool(runner._action_controller.is_null()).override_failure_message(
		("AC-2: _action_controller must be non-null after BattleScene STEP 5 wire-up. "
		+ "If null, set_action_controller was not called in battle_scene.gd "
		+ "between set_chokepoints and add_child(_grid_controller).")
	).is_false()

	# Assert — registered Callable method name is _on_turn_runner_action_request
	var registered_method: String = runner._action_controller.get_method()
	assert_str(registered_method).override_failure_message(
		("AC-2: registered Callable must be _on_turn_runner_action_request; "
		+ "got '%s'. Verify battle_scene.gd passes _grid_controller._on_turn_runner_action_request.")
		% registered_method
	).is_equal("_on_turn_runner_action_request")

	# G-6: explicit free — scene contains multiple Nodes with _exit_tree() disconnects
	scene.free()


# ─── Test 2 (AC-1 enemy-side): T5 enemy unit triggers ai_action_requested ────

## AC-1 enemy-side (S15-J): calling _on_turn_runner_action_request for enemy unit
## triggers the ai_action_requested emit → AISystem chain (S15-B).
## Given: BattleScene mounted + STEP 5 wire-up complete.
## When: _on_turn_runner_action_request called directly with ENEMY_UID_FIRST.
## Then: ai_action_requested signal fires with unit_id == ENEMY_UID_FIRST.
func test_t5_fires_for_enemy_unit_triggers_ai_dispatch_chain() -> void:
	# Arrange
	var scene: BattleScene = _instantiate_and_mount_battle_scene()
	await get_tree().process_frame

	var grid_ctrl: GridBattleController = scene.get_node_or_null("GridBattleController") as GridBattleController
	var runner: TurnOrderRunner = scene.get_node_or_null("TurnOrderRunner") as TurnOrderRunner
	assert_object(grid_ctrl).is_not_null()
	assert_object(runner).is_not_null()

	# Subscribe to ai_action_requested with G-4 Array captures pattern
	# G-10: connect to the INSTANCE signal on grid_ctrl (not a GameBus signal);
	# this is a LOCAL signal on GridBattleController — no autoload binding concern.
	var capture_handler: Callable = func(unit_id: int, _snapshot: BattleStateSnapshot) -> void:
		_ai_action_requested_calls.append({"unit_id": unit_id})
	grid_ctrl.ai_action_requested.connect(capture_handler)

	# Build a TurnOrderSnapshot to satisfy the Callable contract
	var snapshot: TurnOrderSnapshot = runner.get_turn_order_snapshot()

	# Act — call handler directly for enemy unit
	grid_ctrl._on_turn_runner_action_request(ENEMY_UID_FIRST, snapshot)

	# G-27: AISystem subscriber uses CONNECT_DEFERRED; await deferred slot for settle
	await get_tree().process_frame

	# Assert — ai_action_requested must have fired exactly once with the enemy unit_id
	assert_int(_ai_action_requested_calls.size()).override_failure_message(
		("AC-1 enemy-side: ai_action_requested must emit once for enemy unit %d; "
		+ "got %d emits. Verify unit.side==1 arm in _on_turn_runner_action_request.")
		% [ENEMY_UID_FIRST, _ai_action_requested_calls.size()]
	).is_equal(1)

	var captured_uid: int = _ai_action_requested_calls[0].get("unit_id", -1) as int
	assert_int(captured_uid).override_failure_message(
		("AC-1 enemy-side: emitted unit_id must be %d; got %d")
		% [ENEMY_UID_FIRST, captured_uid]
	).is_equal(ENEMY_UID_FIRST)

	# Cleanup — disconnect test-owned handler (G-28: never bulk-disconnect-all)
	if grid_ctrl.ai_action_requested.is_connected(capture_handler):
		grid_ctrl.ai_action_requested.disconnect(capture_handler)

	# G-6
	scene.free()


# ─── Test 3 (AC-1 player-side): T5 player unit returns without dispatch ───────

## AC-1 player-side (S15-J): calling _on_turn_runner_action_request for a player
## unit returns immediately — NO ai_action_requested emit, NO declare_action.
## T5 stays paused until grid-click fires declare_action (S15-C natural input path).
## Given: BattleScene mounted.
## When: _on_turn_runner_action_request called with PLAYER_UID_1 (side=0).
## Then: ai_action_requested NOT emitted; TurnOrderRunner has no new declare_action.
func test_t5_fires_for_player_unit_returns_without_dispatch() -> void:
	# Arrange
	var scene: BattleScene = _instantiate_and_mount_battle_scene()
	await get_tree().process_frame

	var grid_ctrl: GridBattleController = scene.get_node_or_null("GridBattleController") as GridBattleController
	var runner: TurnOrderRunner = scene.get_node_or_null("TurnOrderRunner") as TurnOrderRunner
	assert_object(grid_ctrl).is_not_null()
	assert_object(runner).is_not_null()

	# Subscribe to ai_action_requested to confirm NO emit
	var capture_handler: Callable = func(unit_id: int, _snapshot: BattleStateSnapshot) -> void:
		_ai_action_requested_calls.append({"unit_id": unit_id})
	grid_ctrl.ai_action_requested.connect(capture_handler)

	var snapshot: TurnOrderSnapshot = runner.get_turn_order_snapshot()

	# Act — call handler for player unit
	grid_ctrl._on_turn_runner_action_request(PLAYER_UID_1, snapshot)
	await get_tree().process_frame

	# Assert — ai_action_requested must NOT have fired
	assert_int(_ai_action_requested_calls.size()).override_failure_message(
		("AC-1 player-side: ai_action_requested must NOT emit for player unit %d; "
		+ "got %d emits. Verify unit.side==0 arm returns early in _on_turn_runner_action_request.")
		% [PLAYER_UID_1, _ai_action_requested_calls.size()]
	).is_equal(0)

	# Cleanup
	if grid_ctrl.ai_action_requested.is_connected(capture_handler):
		grid_ctrl.ai_action_requested.disconnect(capture_handler)

	# G-6
	scene.free()


# ─── Test 4 (AC-1 defensive): unknown unit_id → no dispatch ──────────────────

## AC-1 defensive (S15-J): calling _on_turn_runner_action_request with an unknown
## unit_id does not crash and does not emit ai_action_requested.
## Note on push_warning assertion: GdUnit4 v6.1.2 has no built-in push_warning
## capture API. The test asserts only the ABSENCE of dispatch — the push_warning
## is exercised implicitly by the test run's stderr output.
## Given: BattleScene mounted.
## When: _on_turn_runner_action_request called with UNKNOWN_UID (99999).
## Then: no crash; ai_action_requested NOT emitted.
func test_unknown_unit_id_pushes_warning_and_returns_without_dispatch() -> void:
	# Arrange
	var scene: BattleScene = _instantiate_and_mount_battle_scene()
	await get_tree().process_frame

	var grid_ctrl: GridBattleController = scene.get_node_or_null("GridBattleController") as GridBattleController
	var runner: TurnOrderRunner = scene.get_node_or_null("TurnOrderRunner") as TurnOrderRunner
	assert_object(grid_ctrl).is_not_null()
	assert_object(runner).is_not_null()

	var capture_handler: Callable = func(unit_id: int, _snapshot: BattleStateSnapshot) -> void:
		_ai_action_requested_calls.append({"unit_id": unit_id})
	grid_ctrl.ai_action_requested.connect(capture_handler)

	var snapshot: TurnOrderSnapshot = runner.get_turn_order_snapshot()

	# Act — call with a unit_id that does not exist in _units
	# The test must not crash — if it does, the defensive guard is missing
	grid_ctrl._on_turn_runner_action_request(UNKNOWN_UID, snapshot)
	await get_tree().process_frame

	# Assert — no ai_action_requested dispatch
	assert_int(_ai_action_requested_calls.size()).override_failure_message(
		("AC-1 defensive: ai_action_requested must NOT emit for unknown unit_id=%d; "
		+ "got %d emits. Verify null-guard + push_warning + return in _on_turn_runner_action_request.")
		% [UNKNOWN_UID, _ai_action_requested_calls.size()]
	).is_equal(0)

	# Cleanup
	if grid_ctrl.ai_action_requested.is_connected(capture_handler):
		grid_ctrl.ai_action_requested.disconnect(capture_handler)

	# G-6
	scene.free()


# ─── Test 5 (AC-1 defensive): unknown unit.side → no dispatch ────────────────

## AC-1 defensive (S15-J): calling _on_turn_runner_action_request for a unit with
## unknown side (e.g., side=2 from data corruption) does not crash and does not
## emit ai_action_requested. Exercises the match wildcard `_:` arm at
## grid_battle_controller.gd:1261-1262 (uncovered by Test 4 which goes through
## the early null-check path for unknown unit_id).
## Note on push_warning assertion: same GdUnit4 v6.1.2 limitation as Test 4.
## Given: BattleScene mounted; existing player unit's side mutated to 2.
## When: _on_turn_runner_action_request called for the corrupted unit.
## Then: no crash; ai_action_requested NOT emitted (wildcard arm returns silently).
func test_unknown_unit_side_pushes_warning_and_returns_without_dispatch() -> void:
	# Arrange
	var scene: BattleScene = _instantiate_and_mount_battle_scene()
	await get_tree().process_frame

	var grid_ctrl: GridBattleController = scene.get_node_or_null("GridBattleController") as GridBattleController
	var runner: TurnOrderRunner = scene.get_node_or_null("TurnOrderRunner") as TurnOrderRunner
	assert_object(grid_ctrl).is_not_null()
	assert_object(runner).is_not_null()

	# Mutate an existing unit's side to an unknown value (simulates data corruption);
	# BattleUnit.side has no validation guard so direct assignment works.
	var corrupted_unit: BattleUnit = grid_ctrl._units.get(PLAYER_UID_1, null)
	assert_object(corrupted_unit).override_failure_message(
		"AC-1 defensive setup: PLAYER_UID_1 must exist in _units after mount"
	).is_not_null()
	corrupted_unit.side = 2  # neither 0 (player) nor 1 (enemy) — triggers wildcard `_:` arm

	var capture_handler: Callable = func(unit_id: int, _snapshot: BattleStateSnapshot) -> void:
		_ai_action_requested_calls.append({"unit_id": unit_id})
	grid_ctrl.ai_action_requested.connect(capture_handler)

	var snapshot: TurnOrderSnapshot = runner.get_turn_order_snapshot()

	# Act — call handler for corrupted-side unit; must hit wildcard `_:` arm.
	# The test must not crash — if it does, the wildcard guard is missing.
	grid_ctrl._on_turn_runner_action_request(PLAYER_UID_1, snapshot)
	await get_tree().process_frame

	# Assert — no ai_action_requested dispatch (wildcard arm returns silently
	# after push_warning; verifies handler does not fall through to enemy-arm dispatch).
	assert_int(_ai_action_requested_calls.size()).override_failure_message(
		("AC-1 defensive: ai_action_requested must NOT emit for unit with unknown "
		+ "side=2; got %d emits. Verify wildcard `_:` arm in match unit.side at "
		+ "_on_turn_runner_action_request (grid_battle_controller.gd:1261-1262).")
		% _ai_action_requested_calls.size()
	).is_equal(0)

	# Cleanup — disconnect test-owned handler (G-28)
	if grid_ctrl.ai_action_requested.is_connected(capture_handler):
		grid_ctrl.ai_action_requested.disconnect(capture_handler)

	# G-6
	scene.free()


# ─── Test 6 (AC-6): set_action_controller DI surface contract unchanged ───────

## AC-6 backward-compat (S15-J): set_action_controller still accepts arbitrary
## Callables including the null Callable (clears the controller → TEST-SEAM mode).
## The 7 existing test sites in turn_order_t5_await_test.gd are the canonical
## regression check for the full DI surface contract. This test adds a lightweight
## sanity that the setter's null-Callable path still works post S15-J.
## Given: TurnOrderRunner standalone (no full BattleScene required).
## When: set_action_controller(Callable()) called with empty Callable.
## Then: _action_controller.is_null() == true (TEST-SEAM mode restored).
func test_set_action_controller_di_surface_contract_unchanged_for_existing_callers() -> void:
	# Arrange — standalone TurnOrderRunner; no BattleScene needed
	var runner: TurnOrderRunner = TurnOrderRunner.new()
	add_child(runner)
	await get_tree().process_frame

	# Inject a non-null Callable to establish a baseline
	var dummy: Callable = func(_unit_id: int, _snapshot: TurnOrderSnapshot) -> void: pass
	runner.set_action_controller(dummy)

	assert_bool(runner._action_controller.is_null()).override_failure_message(
		"AC-6 pre-condition: set_action_controller must accept non-null Callable"
	).is_false()

	# Act — clear with empty Callable (mirrors TEST-SEAM mode used by all 7
	# existing test sites in turn_order_t5_await_test.gd)
	runner.set_action_controller(Callable())

	# Assert — _action_controller is null again (TEST-SEAM mode)
	assert_bool(runner._action_controller.is_null()).override_failure_message(
		("AC-6: set_action_controller(Callable()) must restore null state (TEST-SEAM mode). "
		+ "If false, the setter no longer accepts null Callable — existing callers in "
		+ "turn_order_t5_await_test.gd will break.")
	).is_true()

	# G-6
	runner.free()
