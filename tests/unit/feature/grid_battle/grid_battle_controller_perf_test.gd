## Performance baseline tests for GridBattleController per ADR-0014 §11
## Performance Implications + story-010 AC-1.
##
## Per-event budget headlines per ADR-0014:
##   handle_grid_click (per call)        < 0.05ms (50µs) — FSM dispatch + 1-2 backend queries
##   _resolve_attack (full chain)        < 0.5ms (500µs) — multipliers + DamageCalc + apply_damage
##   setup() (8-unit roster)             < 0.01ms (10µs) — DI seam + tag-based fate detection
##
## CI permissive gates (×5-50 over headlines to absorb headless runner load + JIT warm-up):
##   handle_grid_click × 1000            < 50ms   (50_000µs total) — ×10 amortized
##   _resolve_attack × 100               < 250ms  (250_000µs total) — ×5 amortized
##   100 mixed battle actions            < 300ms  (300_000µs total) — ×3 amortized
##   setup() (8-unit roster)             < 2ms    (2_000µs) — ×200 over 10µs (cold-start tolerant)
##
## CI runs with SKIP_PERF_BUDGETS=1 env var (set in .github/workflows/tests.yml);
## permissive gates render the env-var an additional safety net rather than the
## primary mechanism. Pattern matches turn_order_perf_test + damage_calc_perf_test
## + hp_status_perf_test precedent.
##
## ISOLATION DISCIPLINE (G-15):
##   before_test() creates a fresh GridBattleController + 8-unit roster, calls
##   setup() (DI seam), and add_child() to fire _ready (loads _max_turns +
##   creates _rng). after_test() relies on auto_free + GameBus 4-disconnect
##   from the controller's own _exit_tree.

extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


# ── Constants ─────────────────────────────────────────────────────────────────

## CI permissive gates in microseconds.
const _GATE_HANDLE_CLICK_US: int   =  50_000  ## handle_grid_click × 1000: <50ms
const _GATE_RESOLVE_ATTACK_US: int = 250_000  ## _resolve_attack × 100: <250ms
const _GATE_BATTLE_FLOW_US: int    = 300_000  ## 100 mixed actions: <300ms
const _GATE_SETUP_US: int          =   2_000  ## setup() 8 units cold-start: <2ms

## Iteration counts.
const _ITER_CLICK: int   = 1_000
const _ITER_ATTACK: int  =   100
const _ITER_FLOW: int    =   100


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: GridBattleController


# ── Lifecycle (G-15) ──────────────────────────────────────────────────────────

func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)
	_controller = auto_free(GridBattleControllerScript.new())
	var roster: Array[BattleUnit] = _make_8_unit_roster()
	_controller.setup(
		roster,
		_make_map_grid(),
		auto_free(BattleCameraStubScript.new()),
		HeroDatabaseStubScript.new(),
		auto_free(TurnOrderRunnerStubScript.new()),
		auto_free(HPStatusControllerStubScript.new()),
		TerrainEffectStubScript.new(),
		UnitRoleStubScript.new(),
	)
	# add_child fires _ready (loads _max_turns + creates _rng).
	add_child(_controller)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_unit(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = StringName("perf_unit_%d" % unit_id)
	u.unit_class = 0
	u.position = pos
	u.side = side
	u.facing = 0
	u.move_range = 3
	u.attack_range = 1
	u.raw_atk = 50
	u.raw_def = 20
	return u


## 8-unit roster: 4 player (side=0) at left column + 4 enemy (side=1) at right column.
## Used for both setup() perf timing and downstream per-event throughput tests.
func _make_8_unit_roster() -> Array[BattleUnit]:
	var roster: Array[BattleUnit] = []
	for i: int in 4:
		roster.append(_make_unit(i + 1, Vector2i(1, i), 0))   # player col x=1
	for i: int in 4:
		roster.append(_make_unit(i + 5, Vector2i(6, i), 1))   # enemy col x=6
	return roster


func _make_map_grid() -> MapGridStub:
	var mg: MapGridStub = auto_free(MapGridStubScript.new())
	mg.set_dimensions_for_test(Vector2i(8, 8))
	return mg


# ── AC-1: setup() 8-unit cold-start budget ────────────────────────────────────

func test_setup_8_units_under_2ms_cold_start() -> void:
	# Arrange — fresh controller (NOT the before_test instance) for true cold-start.
	var cold: GridBattleController = auto_free(GridBattleControllerScript.new())
	var roster: Array[BattleUnit] = _make_8_unit_roster()

	# Act — timed window covers setup() only (DI bind + tag-based fate detection).
	var start_us: int = Time.get_ticks_usec()
	cold.setup(
		roster,
		_make_map_grid(),
		auto_free(BattleCameraStubScript.new()),
		HeroDatabaseStubScript.new(),
		auto_free(TurnOrderRunnerStubScript.new()),
		auto_free(HPStatusControllerStubScript.new()),
		TerrainEffectStubScript.new(),
		UnitRoleStubScript.new(),
	)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 setup() 8-unit cold-start: took %dµs, exceeds 2_000µs gate. "
		+ "Gate is ×200 over 10µs ADR-0014 §Performance Implications headline — "
		+ "check tag-based fate detection regression or DI bind cost.")
		% elapsed_us
	).is_less(_GATE_SETUP_US)


# ── AC-1: handle_grid_click × 1000 throughput ─────────────────────────────────

func test_handle_grid_click_1000_calls_under_50ms() -> void:
	# Arrange — warmup to hot-load the FSM dispatch path.
	_controller.handle_grid_click("unit_select", Vector2i(1, 0), 1)
	# Reset controller state so iteration loop is in OBSERVATION (acted-unit
	# guard would short-circuit further selects).
	_controller._acted_this_turn.clear()
	_controller._state = GridBattleController.BattleState.OBSERVATION
	_controller._selected_unit_id = -1

	# Act — timed window measures FSM dispatch + acted-unit guard + signal emit.
	# Mix of selects/deselects: even iter selects unit 1; odd iter clicks same
	# selected unit again to deselect (covers both FSM transitions).
	var start_us: int = Time.get_ticks_usec()
	for i: int in _ITER_CLICK:
		_controller.handle_grid_click("unit_select", Vector2i(1, 0), 1)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 handle_grid_click × 1000: took %dµs, exceeds 50_000µs gate. "
		+ "Gate is ×10 over 0.05ms × 1000 ADR-0014 headline — investigate FSM "
		+ "dispatch overhead or signal-emit cost.")
		% elapsed_us
	).is_less(_GATE_HANDLE_CLICK_US)


# ── AC-1: _resolve_attack × 100 full-chain throughput ─────────────────────────

func test_resolve_attack_100_calls_under_250ms() -> void:
	# Arrange — pick attacker (unit 1, side=0) + defender (unit 5, side=1).
	# Reposition adjacent so attack-range check passes per call.
	var attacker: BattleUnit = _controller._units[1]
	var defender: BattleUnit = _controller._units[5]
	attacker.position = Vector2i(2, 2)
	defender.position = Vector2i(2, 3)  # Manhattan 1
	defender.facing = 0  # N (rear from south)
	# Warmup pass.
	_controller._resolve_attack(attacker, defender)

	# Act — timed window covers full multiplier + DamageCalc + apply_damage chain.
	var start_us: int = Time.get_ticks_usec()
	for i: int in _ITER_ATTACK:
		_controller._resolve_attack(attacker, defender)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 _resolve_attack × 100: took %dµs, exceeds 250_000µs gate. "
		+ "Gate is ×5 over 0.5ms × 100 ADR-0014 headline — investigate "
		+ "multiplier compute, DamageCalc.resolve, or HPStatusController.apply_damage.")
		% elapsed_us
	).is_less(_GATE_RESOLVE_ATTACK_US)


# ── AC-1: 100 mixed battle actions throughput ────────────────────────────────

func test_100_synthetic_battle_actions_under_300ms() -> void:
	# Mixed-action sequence: 50× handle_grid_click + 50× _resolve_attack to
	# exercise the "real battle" mix per ADR-0014 §Performance Implications.
	var attacker: BattleUnit = _controller._units[1]
	var defender: BattleUnit = _controller._units[5]
	attacker.position = Vector2i(2, 2)
	defender.position = Vector2i(2, 3)
	defender.facing = 0
	# Warmup.
	_controller.handle_grid_click("unit_select", Vector2i(2, 2), 1)
	_controller._acted_this_turn.clear()
	_controller._state = GridBattleController.BattleState.OBSERVATION
	_controller._selected_unit_id = -1
	_controller._resolve_attack(attacker, defender)

	# Act — 100 mixed actions.
	var start_us: int = Time.get_ticks_usec()
	for i: int in _ITER_FLOW:
		if i % 2 == 0:
			_controller.handle_grid_click("unit_select", Vector2i(2, 2), 1)
		else:
			_controller._resolve_attack(attacker, defender)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 100 mixed actions: took %dµs, exceeds 300_000µs gate. "
		+ "Gate is ×3 over 100ms ADR-0014 headline — full-throughput regression "
		+ "would indicate cumulative per-event drift; bisect via the handle_grid_click "
		+ "and resolve_attack micro-tests above.")
		% elapsed_us
	).is_less(_GATE_BATTLE_FLOW_US)
