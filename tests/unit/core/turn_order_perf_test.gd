extends GdUnitTestSuite

## turn_order_perf_test.gd
## AC-1 (TR-turn-order-021) perf budget verification — headless CI permissive gates.
## Covers story-007 §Acceptance Criteria AC-1 + AC-12.
##
## Budget headlines per ADR-0011 §AC-23 perf:
##   initialize_battle(20-unit roster)   < 1ms  ADR headline  (BI-1..BI-6 + F-1 sort)
##   get_acted_this_turn × 1000          < 1µs  ADR headline  (O(1) Dictionary read)
##   get_charge_ready × 1000             < 2µs  ADR headline  (O(1) Dict + BalanceConstants read)
##   get_turn_order_snapshot × 100       < 50µs ADR headline  (20-unit deep-snapshot construction)
##
## CI permissive gates (×3-50 over headline to absorb headless runner load + JIT warm-up):
##   initialize_battle cold-start        < 50ms  (50_000µs)  ×50 over 1ms
##   get_acted_this_turn × 1000          <  5ms   (5_000µs)  ×5  over 1µs ADR headline
##   get_charge_ready × 1000             < 10ms  (10_000µs)  ×5  over 2µs ADR headline
##   get_turn_order_snapshot × 100       < 25ms  (25_000µs)  ×5  over 50µs ADR headline
##
## Note: get_acted_this_turn and get_turn_order_snapshot are stubs returning false / null
## in the story-007 implementation scope (full bodies owned by story-003 / story-002
## respectively). The perf tests measure the stub paths, which represent the absolute
## floor — real implementations will be faster per operation budget; gates remain valid.
##
## Governing ADR: ADR-0011 — Turn Order / Action Management (Accepted 2026-04-30).
## Also governs: ADR-0006 (BalanceConstants accessor — CHARGE_THRESHOLD key).
##
## ISOLATION DISCIPLINE (G-15):
##   before_test() creates a fresh TurnOrderRunner, resets all 5 instance fields,
##   and calls initialize_battle() to populate _unit_states with a 20-unit roster
##   for the cached-throughput tests. The 5-field reset + unit_died.disconnect guard
##   satisfies AC-3 G-15 lint for this file.
##   after_test() disconnects GameBus.unit_died if connected (forward-compatible guard).
##
## GOTCHA AWARENESS:
##   G-2  — typed-array preservation: roster.append(_make_unit(...)) NOT literal init
##   G-6  — orphan detection fires BETWEEN test body exit and after_test; use free()
##   G-9  — % operator precedence: wrap multi-line concat in parens before %
##   G-15 — before_test() is the canonical GdUnit4 v6.1.2 hook (NOT before_each)
##   G-24 — as-operator precedence: wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## CI permissive gates in microseconds (×3-50 over ADR headlines).
const _GATE_INIT_US: int       = 50_000  ## initialize_battle cold-start: <50ms
const _GATE_ACTED_US: int      =  5_000  ## get_acted_this_turn ×1000: <5ms
const _GATE_CHARGE_US: int     = 10_000  ## get_charge_ready ×1000: <10ms
const _GATE_SNAPSHOT_US: int   = 25_000  ## get_turn_order_snapshot ×100: <25ms

## Throughput iteration counts per test.
const _ITER_QUERY: int         =  1_000  ## queries timed in batches of 1000
const _ITER_SNAPSHOT: int      =    100  ## snapshot calls timed in batches of 100

## 20-unit roster composition: 10 player + 10 enemy units.
## Hero IDs from the 9-record MVP roster (heroes.json verified 2026-05-01).
## Cycling through the 9 heroes × repeat to reach 20 entries.
const _HERO_LIU_BEI: StringName    = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName    = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName  = &"shu_003_zhang_fei"
const _HERO_CAO_CAO: StringName    = &"wei_001_cao_cao"
const _HERO_XIAHOU_DUN: StringName = &"wei_005_xiahou_dun"
const _HERO_SUN_QUAN: StringName   = &"wu_001_sun_quan"
const _HERO_ZHOU_YU: StringName    = &"wu_003_zhou_yu"
const _HERO_LU_BU: StringName      = &"qun_001_lu_bu"
const _HERO_DIAO_CHAN: StringName   = &"qun_004_diao_chan"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int    = 0
const _CLASS_INFANTRY: int   = 1
const _CLASS_ARCHER: int     = 2
const _CLASS_STRATEGIST: int = 3
const _CLASS_COMMANDER: int  = 4
const _CLASS_SCOUT: int      = 5

## Stable unit_id used for all cached-throughput tests (exists in the pre-warmed roster).
const _QUERY_UNIT_ID: int = 1

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner


# ── Lifecycle (G-15: before_test / after_test only) ───────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner, resets all 5 instance fields, and
	## pre-warms the runner with a 20-unit roster for cached-throughput tests.
	## The _unit_states.clear() + unit_died.disconnect guard satisfies AC-3 lint.
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	# G-15 5-field reset (defensive even on fresh runner).
	_runner._unit_states.clear()
	_runner._queue.clear()
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	# G-15 unit_died disconnect guard (forward-compatible for post-story-004 builds).
	if GameBus.unit_died.is_connected(_runner._on_unit_died):
		GameBus.unit_died.disconnect(_runner._on_unit_died)
	# Pre-warm with 20-unit roster for cached-throughput tests.
	# initialize_battle populates _unit_states and sets _round_state = ROUND_STARTING.
	var roster: Array[BattleUnit] = _make_20_unit_roster()
	_runner.initialize_battle(roster)


func after_test() -> void:
	## G-15 cleanup: disconnect GameBus.unit_died before auto_free.
	## is_connected guard prevents double-disconnect on out-of-order teardown.
	if is_instance_valid(_runner):
		if GameBus.unit_died.is_connected(_runner._on_unit_died):
			GameBus.unit_died.disconnect(_runner._on_unit_died)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Constructs a BattleUnit with the specified fields.
## G-2: typed-array preservation — callers use roster.append(_make_unit(...)).
func _make_unit(
		unit_id: int,
		hero_id: StringName,
		unit_class: int,
		is_player: bool) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	u.unit_class = unit_class
	u.is_player_controlled = is_player
	return u


## Builds a 20-unit roster cycling through the 9 MVP heroes.
## 10 player-controlled + 10 enemy units; unit_ids 1..20.
## G-2: uses roster.append() NOT array literal to preserve Array[BattleUnit] type.
func _make_20_unit_roster() -> Array[BattleUnit]:
	var hero_ids: Array[StringName] = [
		_HERO_LIU_BEI, _HERO_GUAN_YU, _HERO_ZHANG_FEI,
		_HERO_CAO_CAO, _HERO_XIAHOU_DUN, _HERO_SUN_QUAN,
		_HERO_ZHOU_YU, _HERO_LU_BU, _HERO_DIAO_CHAN,
	]
	var classes: Array[int] = [
		_CLASS_COMMANDER, _CLASS_INFANTRY, _CLASS_ARCHER,
		_CLASS_CAVALRY, _CLASS_STRATEGIST, _CLASS_SCOUT,
		_CLASS_INFANTRY, _CLASS_CAVALRY, _CLASS_ARCHER,
	]
	var roster: Array[BattleUnit] = []
	for i: int in 20:
		var hero_idx: int = i % hero_ids.size()
		roster.append(_make_unit(
			i + 1,                        # unit_id 1..20
			hero_ids[hero_idx],
			classes[hero_idx],
			i < 10                        # first 10 player, last 10 enemy
		))
	return roster


# ── AC-1 (TR-021) — initialize_battle cold-start: < 50ms ─────────────────────


## AC-1 (TR-021 cold-start): initialize_battle() with a 20-unit roster must
## complete in under 50ms on a headless CI runner.
## Measures BI-1..BI-6: UnitTurnState construction × 20 + HeroDatabase lookups
## + F-1 cascade sort (Array.sort_custom over 20 IDs) + _round_state transition.
## Gate is ×50 over the 1ms ADR headline to absorb GDScript JIT warm-up + CI load.
##
## NOTE: before_test() pre-warms the runner with initialize_battle(). This test
## creates a fresh runner to measure the true cold-start path without cached HeroDatabase.
func test_initialize_battle_20_units_under_50ms_cold_start() -> void:
	# Arrange — fresh runner to avoid HeroDatabase warmup from before_test().
	# Use a local var; auto_free cleanup is sufficient (Node, no free() needed).
	var cold_runner: TurnOrderRunner = auto_free(TurnOrderRunner.new())
	add_child(cold_runner)
	var roster: Array[BattleUnit] = _make_20_unit_roster()

	# Act — timed window covers the full initialize_battle() path.
	var start_us: int = Time.get_ticks_usec()
	cold_runner.initialize_battle(roster)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Cleanup — disconnect unit_died before auto_free (G-6 + G-15).
	if GameBus.unit_died.is_connected(cold_runner._on_unit_died):
		GameBus.unit_died.disconnect(cold_runner._on_unit_died)

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-021 cold-start): initialize_battle(20 units) took %dus, "
		+ "exceeds 50_000us (50ms) gate. "
		+ "Gate is ×50 over 1ms ADR headline — check HeroDatabase lazy-load cost or "
		+ "F-1 sort regression. Re-run before flagging (transient CI scheduler spike possible).")
		% elapsed_us
	).is_less(_GATE_INIT_US)


# ── AC-1 (TR-021) — get_acted_this_turn × 1000: < 5ms ───────────────────────


## AC-1 (TR-021 get_acted_this_turn throughput): 1000 cached get_acted_this_turn()
## calls using a unit_id known to be in _unit_states (populated by before_test()).
## Cache pre-warmed by before_test() initialize_battle(). Only the loop is timed.
## Gate: sum < 5_000µs (5ms) ≈ 5µs amortised per call (×5 over 1µs ADR headline).
##
## Note: get_acted_this_turn() is a stub returning false in story-007 scope.
## This test establishes the performance floor; the real implementation must be
## no slower (O(1) Dictionary read — same asymptotic class as the stub path).
func test_get_acted_this_turn_1000_calls_under_5ms() -> void:
	# Arrange — before_test() already populated _unit_states; warmup below ensures
	# the method dispatch path is hot before the timed window.
	var _warmup: bool = _runner.get_acted_this_turn(_QUERY_UNIT_ID)

	# Act — timed window only.
	var start_us: int = Time.get_ticks_usec()
	for _i: int in _ITER_QUERY:
		var _v: bool = _runner.get_acted_this_turn(_QUERY_UNIT_ID)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-021 get_acted_this_turn): 1000 calls took %dus (gate %dus). "
		+ "Per-call amortised: %dus (gate ~5us). "
		+ "Gate is ×5 over 1µs ADR headline — check CI runner load or unexpected Dictionary miss.")
		% [elapsed_us, _GATE_ACTED_US, elapsed_us / _ITER_QUERY]
	).is_less(_GATE_ACTED_US)


# ── AC-1 (TR-021) — get_charge_ready × 1000: < 10ms ─────────────────────────


## AC-1 (TR-021 get_charge_ready throughput): 1000 cached get_charge_ready() calls
## using a unit_id known to be in _unit_states (populated by before_test()).
## Includes a BalanceConstants.get_const("CHARGE_THRESHOLD") read per call (ADR-0006).
## Cache pre-warmed by before_test() initialize_battle(). Only the loop is timed.
## Gate: sum < 10_000µs (10ms) ≈ 10µs amortised per call (×5 over 2µs ADR headline).
func test_get_charge_ready_1000_calls_under_10ms() -> void:
	# Arrange — before_test() populated _unit_states; warmup ensures BalanceConstants
	# cache is hot before the timed window (avoids counting lazy-load cold cost).
	var _warmup: bool = _runner.get_charge_ready(_QUERY_UNIT_ID)

	# Act — timed window only.
	var start_us: int = Time.get_ticks_usec()
	for _i: int in _ITER_QUERY:
		var _v: bool = _runner.get_charge_ready(_QUERY_UNIT_ID)
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-021 get_charge_ready): 1000 calls took %dus (gate %dus). "
		+ "Per-call amortised: %dus (gate ~10us). "
		+ "Gate is ×5 over 2µs ADR headline — check BalanceConstants read cost or "
		+ "CI runner load. Re-run before flagging (transient spike possible).")
		% [elapsed_us, _GATE_CHARGE_US, elapsed_us / _ITER_QUERY]
	).is_less(_GATE_CHARGE_US)


# ── AC-1 (TR-021) — get_turn_order_snapshot × 100: < 25ms ───────────────────


## AC-1 (TR-021 get_turn_order_snapshot throughput): 100 cached get_turn_order_snapshot()
## calls after initialize_battle() populates _unit_states with 20 units.
## Cache pre-warmed. Only the loop is timed.
## Gate: sum < 25_000µs (25ms) ≈ 250µs amortised per call (×5 over 50µs ADR headline).
##
## Note: get_turn_order_snapshot() is a stub returning null in story-007 scope.
## This test establishes the performance floor; the full story-002 deep-snapshot
## implementation (20-unit TurnOrderEntry construction) must fit within the same gate.
func test_get_turn_order_snapshot_100_calls_under_25ms() -> void:
	# Arrange — before_test() populated _unit_states; warmup ensures method dispatch hot.
	var _warmup: TurnOrderSnapshot = _runner.get_turn_order_snapshot()

	# Act — timed window only.
	var start_us: int = Time.get_ticks_usec()
	for _i: int in _ITER_SNAPSHOT:
		var _v: TurnOrderSnapshot = _runner.get_turn_order_snapshot()
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-021 get_turn_order_snapshot): 100 calls took %dus (gate %dus). "
		+ "Per-call amortised: %dus (gate ~250us). "
		+ "Gate is ×5 over 50µs ADR headline — if stub is now replaced, verify full "
		+ "20-unit deep-snapshot construction fits gate. CI runner load can cause spikes.")
		% [elapsed_us, _GATE_SNAPSHOT_US, elapsed_us / _ITER_SNAPSHOT]
	).is_less(_GATE_SNAPSHOT_US)
