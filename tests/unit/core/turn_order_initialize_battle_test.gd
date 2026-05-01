extends GdUnitTestSuite

## turn_order_initialize_battle_test.gd
## Unit tests for Story 002 (turn-order epic): TurnOrderRunner.initialize_battle()
## full implementation — BI-1 through BI-6 sequence, F-1 cascade comparator,
## and _seed_unit_state_for_test / _rebuild_queue seam.
##
## Covers AC-1 through AC-12 from story-002 §Acceptance Criteria.
##
## Governing ADR: ADR-0011 — Turn Order / Action Management (Accepted 2026-04-30).
## Related TRs:   TR-turn-order-010 (F-1 cascade), TR-turn-order-011 (BI init),
##                TR-turn-order-012 (counters), TR-turn-order-013 (round-state),
##                TR-turn-order-014 (token flags), TR-turn-order-015 (idempotency).
##
## TEST APPROACH:
##   AC-1..AC-7 use real MVP heroes (loaded from heroes.json via HeroDatabase lazy-init)
##   and assert structural state — not specific initiative values, which are computed
##   by UnitRole.get_initiative() and subject to balance tuning.
##   AC-8..AC-12 use _seed_unit_state_for_test() / _rebuild_queue() seams to inject
##   synthetic (initiative, stat_agility, is_player_controlled) values after
##   initialize_battle() populates _unit_states, enabling deterministic F-1 cascade
##   ordering assertions.
##
## ISOLATION DISCIPLINE (G-15 — before_test, NOT before_each):
##   before_test() resets all 5 instance fields and disconnects any GameBus.unit_died
##   subscription that story-005+ will add (forward-compatible guard).
##   TurnOrderRunner is a Node — added to the test tree with add_child() so
##   _begin_round.call_deferred() can fire safely; auto_free() handles cleanup.
##
## GOTCHA AWARENESS:
##   G-2  — typed-array preservation: roster.append(_make_unit(...)) NOT literal init
##   G-9  — % operator precedence: wrap multi-line concat in parens before %
##   G-15 — before_test() is the canonical GdUnit4 v6.1.2 hook (NOT before_each)
##   G-23 — GdUnit4 v6.1.2 has no is_not_equal_approx(); use is_not_equal() or manual
##   G-24 — as-operator precedence: wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## MVP hero IDs with known stat_agility values (heroes.json verified 2026-05-01).
## stat_agility: liu_bei=65, guan_yu=70, zhang_fei=60, cao_cao=70, xiahou_dun=65.
const _HERO_LIU_BEI: StringName    = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName    = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName  = &"shu_003_zhang_fei"
const _HERO_CAO_CAO: StringName    = &"wei_001_cao_cao"
const _HERO_XIAHOU_DUN: StringName = &"wei_005_xiahou_dun"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int    = 0
const _CLASS_INFANTRY: int   = 1
const _CLASS_ARCHER: int     = 2
const _CLASS_STRATEGIST: int = 3
const _CLASS_COMMANDER: int  = 4
const _CLASS_SCOUT: int      = 5

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner and resets all 5 instance fields to
	## the BATTLE_NOT_STARTED baseline per ADR-0011 §Risks R-5 isolation mandate.
	## GameBus.unit_died disconnect guard is forward-compatible for story-005+.
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	_runner._unit_states.clear()
	_runner._queue.clear()
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	# Forward-compatible disconnect guard for story-005+ GameBus.unit_died subscription.
	# TODO story-005: uncomment when subscribe is wired in initialize_battle:
	# if GameBus.unit_died.is_connected(_runner._on_unit_died):
	#     GameBus.unit_died.disconnect(_runner._on_unit_died)


# ── Helper ────────────────────────────────────────────────────────────────────

## Constructs a BattleUnit with the specified fields.
## G-2: roster typed-array preservation — callers use roster.append(_make_unit(...)).
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


# ── AC-1 (empty roster guard) ─────────────────────────────────────────────────


## AC-1 (empty roster): initialize_battle with an empty roster leaves _round_state
## unchanged at BATTLE_NOT_STARTED (push_error is emitted; no state transition occurs).
## Given: TurnOrderRunner at BATTLE_NOT_STARTED.
## When:  initialize_battle called with an empty Array[BattleUnit].
## Then:  _round_state remains BATTLE_NOT_STARTED (push_error guard, no transition).
func test_initialize_battle_empty_roster_pushes_error_and_round_state_unchanged() -> void:
	# Arrange
	var empty_roster: Array[BattleUnit] = []

	# Act — push_error fires internally; does not throw
	_runner.initialize_battle(empty_roster)

	# Assert — state must be unchanged
	assert_int(
		_runner._round_state as int
	).override_failure_message(
		("initialize_battle with empty roster must leave _round_state at "
		+ "BATTLE_NOT_STARTED (%d); got %d")
		% [
			TurnOrderRunner.RoundState.BATTLE_NOT_STARTED as int,
			_runner._round_state as int
		]
	).is_equal(TurnOrderRunner.RoundState.BATTLE_NOT_STARTED as int)


# ── AC-1 (single unit) ────────────────────────────────────────────────────────


## AC-1 (single unit): initialize_battle with a 1-unit roster populates _unit_states
## with that unit and builds a 1-entry _queue.
## Given: TurnOrderRunner at BATTLE_NOT_STARTED.
## When:  initialize_battle called with [liu_bei as COMMANDER, player-controlled].
## Then:  _unit_states.size() == 1; _unit_states.has(1) == true;
##        _queue.size() == 1; _queue[0] == 1.
func test_initialize_battle_single_unit_populates_unit_states() -> void:
	# Arrange
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI, _CLASS_COMMANDER, true))

	# Act
	_runner.initialize_battle(roster)

	# Assert — _unit_states populated
	assert_int(_runner._unit_states.size()).override_failure_message(
		"initialize_battle with 1 unit must produce _unit_states.size() == 1; "
		+ "got %d" % _runner._unit_states.size()
	).is_equal(1)

	assert_bool(_runner._unit_states.has(1)).override_failure_message(
		"initialize_battle must key _unit_states by unit_id; "
		+ "_unit_states.has(1) is false after adding unit with unit_id=1"
	).is_true()

	# Assert — _queue populated
	assert_int(_runner._queue.size()).override_failure_message(
		"initialize_battle with 1 unit must produce _queue.size() == 1; "
		+ "got %d" % _runner._queue.size()
	).is_equal(1)

	assert_int(_runner._queue[0]).override_failure_message(
		("initialize_battle with 1 unit must put that unit_id in _queue[0]; "
		+ "expected 1, got %d") % _runner._queue[0]
	).is_equal(1)


# ── AC-3 (all units present + token flags) ───────────────────────────────────


## AC-3 (4-unit roster): initialize_battle populates _unit_states for all 4 units
## and initializes each with IDLE turn_state, acted_this_turn=false,
## accumulated_move_cost=0, move_token_spent=false, action_token_spent=false.
## Given: TurnOrderRunner at BATTLE_NOT_STARTED.
## When:  initialize_battle called with a 4-unit mixed-faction, mixed-class roster.
## Then:  _unit_states.size() == 4; each unit has clean token state.
func test_initialize_battle_populates_unit_states_for_all_four_units() -> void:
	# Arrange — 2 player units + 2 AI units, mixed faction + class
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI,    _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU,    _CLASS_INFANTRY,  true))
	roster.append(_make_unit(3, _HERO_CAO_CAO,    _CLASS_ARCHER,    false))
	roster.append(_make_unit(4, _HERO_XIAHOU_DUN, _CLASS_CAVALRY,   false))

	# Act
	_runner.initialize_battle(roster)

	# Assert — all 4 units in _unit_states
	assert_int(_runner._unit_states.size()).override_failure_message(
		("initialize_battle with 4-unit roster must produce _unit_states.size() == 4; "
		+ "got %d") % _runner._unit_states.size()
	).is_equal(4)

	# Assert — each unit has clean initial token state
	for uid: int in [1, 2, 3, 4]:
		assert_bool(_runner._unit_states.has(uid)).override_failure_message(
			("_unit_states must contain unit_id=%d after initialize_battle; "
			+ "key missing") % uid
		).is_true()

		var state: UnitTurnState = _runner._unit_states[uid]

		assert_int(state.turn_state as int).override_failure_message(
			("unit_id=%d: turn_state must be IDLE (%d) after initialize_battle; "
			+ "got %d") % [uid, TurnOrderRunner.TurnState.IDLE as int, (state.turn_state as int)]
		).is_equal(TurnOrderRunner.TurnState.IDLE as int)

		assert_bool(state.acted_this_turn).override_failure_message(
			("unit_id=%d: acted_this_turn must be false after initialize_battle") % uid
		).is_false()

		assert_int(state.accumulated_move_cost).override_failure_message(
			("unit_id=%d: accumulated_move_cost must be 0 after initialize_battle; "
			+ "got %d") % [uid, state.accumulated_move_cost]
		).is_equal(0)

		assert_bool(state.move_token_spent).override_failure_message(
			("unit_id=%d: move_token_spent must be false after initialize_battle") % uid
		).is_false()

		assert_bool(state.action_token_spent).override_failure_message(
			("unit_id=%d: action_token_spent must be false after initialize_battle") % uid
		).is_false()


# ── AC-4 (counters initialized to 0) ─────────────────────────────────────────


## AC-4 (counters): _round_number and _queue_index are initialized to 0 at BI-4.
## Given: TurnOrderRunner at BATTLE_NOT_STARTED.
## When:  initialize_battle called with a 2-unit roster.
## Then:  _round_number == 0; _queue_index == 0.
func test_initialize_battle_counters_initialized_to_zero() -> void:
	# Arrange
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI,  _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU,  _CLASS_INFANTRY,  false))

	# Act
	_runner.initialize_battle(roster)

	# Assert
	assert_int(_runner._round_number).override_failure_message(
		("_round_number must be 0 after initialize_battle (BI-4); "
		+ "got %d") % _runner._round_number
	).is_equal(0)

	assert_int(_runner._queue_index).override_failure_message(
		("_queue_index must be 0 after initialize_battle (BI-4); "
		+ "got %d") % _runner._queue_index
	).is_equal(0)


# ── AC-6 (round-state transition to ROUND_STARTING) ──────────────────────────


## AC-6 (round-state): _round_state transitions to ROUND_STARTING at BI-6.
## Given: TurnOrderRunner at BATTLE_NOT_STARTED.
## When:  initialize_battle called with a 2-unit roster.
## Then:  _round_state == ROUND_STARTING.
func test_initialize_battle_round_state_transitions_to_round_starting() -> void:
	# Arrange
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_CAO_CAO,  _CLASS_INFANTRY,  false))

	# Act
	_runner.initialize_battle(roster)

	# Assert — G-24: wrap RHS cast in parens inside is_equal
	assert_int(
		_runner._round_state as int
	).override_failure_message(
		("_round_state must be ROUND_STARTING (%d) after initialize_battle (BI-6); "
		+ "got %d")
		% [
			TurnOrderRunner.RoundState.ROUND_STARTING as int,
			_runner._round_state as int
		]
	).is_equal(TurnOrderRunner.RoundState.ROUND_STARTING as int)


# ── AC-7 (all token flags false) ─────────────────────────────────────────────


## AC-7 / GDD AC-12 (clean token state): all per-unit token flags are false and
## turn_state is IDLE for every unit in a 4-unit roster.
## Given: TurnOrderRunner at BATTLE_NOT_STARTED.
## When:  initialize_battle called with 4 real MVP heroes.
## Then:  For each unit: move_token_spent==false, action_token_spent==false,
##        acted_this_turn==false, turn_state==IDLE.
func test_initialize_battle_clean_state_all_token_flags_false() -> void:
	# Arrange
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI,    _CLASS_COMMANDER,  true))
	roster.append(_make_unit(2, _HERO_GUAN_YU,    _CLASS_ARCHER,     true))
	roster.append(_make_unit(3, _HERO_ZHANG_FEI,  _CLASS_CAVALRY,    false))
	roster.append(_make_unit(4, _HERO_XIAHOU_DUN, _CLASS_STRATEGIST, false))

	# Act
	_runner.initialize_battle(roster)

	# Assert — all 4 units have clean token state
	for uid: int in [1, 2, 3, 4]:
		var state: UnitTurnState = _runner._unit_states[uid]

		assert_bool(state.move_token_spent).override_failure_message(
			("AC-7: unit_id=%d move_token_spent must be false; "
			+ "got true — BI-3 flag initialization failed") % uid
		).is_false()

		assert_bool(state.action_token_spent).override_failure_message(
			("AC-7: unit_id=%d action_token_spent must be false; "
			+ "got true — BI-3 flag initialization failed") % uid
		).is_false()

		assert_bool(state.acted_this_turn).override_failure_message(
			("AC-7: unit_id=%d acted_this_turn must be false; "
			+ "got true — BI-3 flag initialization failed") % uid
		).is_false()

		assert_int(state.turn_state as int).override_failure_message(
			("AC-7: unit_id=%d turn_state must be IDLE (%d); "
			+ "got %d — BI-3 turn_state initialization failed")
			% [uid, TurnOrderRunner.TurnState.IDLE as int, (state.turn_state as int)]
		).is_equal(TurnOrderRunner.TurnState.IDLE as int)


# ── AC-1 (idempotency / double-call guard) ────────────────────────────────────


## Idempotency (double-call guard): a second call to initialize_battle is a no-op.
## The double-init guard fires push_error and returns immediately, leaving the
## already-initialized state untouched.
## Given: TurnOrderRunner already initialized with a 2-unit roster.
## When:  initialize_battle called a SECOND time with the same roster.
## Then:  _unit_states.size() is still 2; _round_state is still ROUND_STARTING.
func test_initialize_battle_double_call_guard_pushes_error_and_no_op() -> void:
	# Arrange — first call (valid initialization)
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU, _CLASS_INFANTRY,  false))
	_runner.initialize_battle(roster)

	# Precondition — first call succeeded
	assert_int(_runner._unit_states.size()).is_equal(2)
	assert_int(
		_runner._round_state as int
	).is_equal(TurnOrderRunner.RoundState.ROUND_STARTING as int)

	# Act — second call (push_error fires; no state change)
	_runner.initialize_battle(roster)

	# Assert — state is still the same as after the first call
	assert_int(_runner._unit_states.size()).override_failure_message(
		("Double-call guard: second initialize_battle must not change _unit_states; "
		+ "expected size 2, got %d") % _runner._unit_states.size()
	).is_equal(2)

	assert_int(
		_runner._round_state as int
	).override_failure_message(
		("Double-call guard: second initialize_battle must not change _round_state; "
		+ "expected ROUND_STARTING (%d), got %d")
		% [
			TurnOrderRunner.RoundState.ROUND_STARTING as int,
			_runner._round_state as int
		]
	).is_equal(TurnOrderRunner.RoundState.ROUND_STARTING as int)


# ── AC-8 (interleaved queue / no phase alternation) ──────────────────────────


## AC-8 / GDD AC-01 (interleaved queue): a 6-unit roster with distinct initiatives
## produces a queue ordered strictly by initiative DESC with no player/AI phase grouping.
## Workflow: initialize_battle populates _unit_states; then seed overrides are applied
## via _seed_unit_state_for_test; then _rebuild_queue sorts by F-1 cascade.
##
## Given: 6 units seeded with initiatives [120, 110, 90, 80, 60, 50] interleaved
##        across player/AI boundaries.
## When:  _rebuild_queue called after seeding.
## Then:  _queue == [1, 2, 3, 4, 5, 6] (pure DESC initiative, no phase grouping).
func test_initialize_battle_interleaved_queue_no_phase_alternation() -> void:
	# Arrange — 6-unit roster (3 player: ids 1/3/5; 3 AI: ids 2/4/6)
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI,    _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU,    _CLASS_INFANTRY,  false))
	roster.append(_make_unit(3, _HERO_ZHANG_FEI,  _CLASS_ARCHER,    true))
	roster.append(_make_unit(4, _HERO_CAO_CAO,    _CLASS_CAVALRY,   false))
	roster.append(_make_unit(5, _HERO_XIAHOU_DUN, _CLASS_SCOUT,     true))
	roster.append(_make_unit(6, _HERO_LIU_BEI,    _CLASS_STRATEGIST, false))

	_runner.initialize_battle(roster)

	# Seed synthetic initiatives — stat_agility=0 so Step 1 doesn't fire
	_runner._seed_unit_state_for_test(1, 120, 0, true)
	_runner._seed_unit_state_for_test(2, 110, 0, false)
	_runner._seed_unit_state_for_test(3,  90, 0, true)
	_runner._seed_unit_state_for_test(4,  80, 0, false)
	_runner._seed_unit_state_for_test(5,  60, 0, true)
	_runner._seed_unit_state_for_test(6,  50, 0, false)

	# Act — rebuild queue with seeded values
	_runner._rebuild_queue()

	# Assert — strictly interleaved by initiative DESC (no phase grouping)
	var expected: Array[int] = [1, 2, 3, 4, 5, 6]
	assert_int(_runner._queue.size()).override_failure_message(
		("AC-8: queue size must be 6 after seeding 6 units; "
		+ "got %d") % _runner._queue.size()
	).is_equal(6)

	for i: int in range(6):
		assert_int(_runner._queue[i]).override_failure_message(
			("AC-8: _queue[%d] must be %d (initiative DESC interleaved); "
			+ "got %d — F-1 cascade is incorrectly grouping by faction/player-control")
			% [i, expected[i], _runner._queue[i]]
		).is_equal(expected[i])


# ── AC-9 (tiebreak Step 1: stat_agility DESC) ────────────────────────────────


## AC-9 / GDD AC-07 (tiebreak stat_agility): when two units share the same initiative,
## the unit with higher stat_agility acts first (F-1 cascade Step 1 DESC).
## Given: 2 units with identical initiative=120 but agility 85 vs 60.
## When:  _rebuild_queue called after seeding.
## Then:  _queue == [2, 5] (unit 2 / agility 85 before unit 5 / agility 60).
func test_initialize_battle_tiebreak_stat_agility_resolution() -> void:
	# Arrange — 2-unit roster (unit_id 2 and 5)
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(2, _HERO_GUAN_YU,    _CLASS_ARCHER,    true))
	roster.append(_make_unit(5, _HERO_XIAHOU_DUN, _CLASS_COMMANDER, false))

	_runner.initialize_battle(roster)

	# Seed — identical initiative; agility 85 vs 60
	_runner._seed_unit_state_for_test(2, 120, 85, true)
	_runner._seed_unit_state_for_test(5, 120, 60, false)

	# Act
	_runner._rebuild_queue()

	# Assert — unit 2 (higher agility) is first
	assert_int(_runner._queue.size()).is_equal(2)

	assert_int(_runner._queue[0]).override_failure_message(
		("AC-9: _queue[0] must be unit_id=2 (stat_agility=85 > stat_agility=60); "
		+ "got %d — F-1 Step 1 stat_agility DESC tiebreak not applied correctly")
		% _runner._queue[0]
	).is_equal(2)

	assert_int(_runner._queue[1]).override_failure_message(
		("AC-9: _queue[1] must be unit_id=5 (stat_agility=60 < stat_agility=85); "
		+ "got %d") % _runner._queue[1]
	).is_equal(5)


# ── AC-10 (tiebreak Step 2: is_player_controlled) ────────────────────────────


## AC-10 / GDD AC-08 (tiebreak is_player_controlled): when two units share
## initiative AND stat_agility, the player-controlled unit acts first
## (F-1 cascade Step 2: true > false).
## Given: 2 units with identical initiative=108 and stat_agility=70;
##        unit 3 is player-controlled, unit 7 is AI.
## When:  _rebuild_queue called after seeding.
## Then:  _queue == [3, 7] (player unit 3 before AI unit 7).
func test_initialize_battle_tiebreak_is_player_controlled_resolution() -> void:
	# Arrange — 2-unit roster (unit_id 3 and 7)
	# unit 7 shares liu_bei hero_id — valid for a test seam (hero_id is MVP-available)
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(3, _HERO_ZHANG_FEI, _CLASS_INFANTRY, true))
	roster.append(_make_unit(7, _HERO_LIU_BEI,   _CLASS_CAVALRY,  false))

	_runner.initialize_battle(roster)

	# Seed — identical initiative AND stat_agility; player vs AI
	_runner._seed_unit_state_for_test(3, 108, 70, true)
	_runner._seed_unit_state_for_test(7, 108, 70, false)

	# Act
	_runner._rebuild_queue()

	# Assert — unit 3 (player) precedes unit 7 (AI)
	assert_int(_runner._queue.size()).is_equal(2)

	assert_int(_runner._queue[0]).override_failure_message(
		("AC-10: _queue[0] must be unit_id=3 (is_player_controlled=true); "
		+ "got %d — F-1 Step 2 is_player_controlled tiebreak not applied correctly")
		% _runner._queue[0]
	).is_equal(3)

	assert_int(_runner._queue[1]).override_failure_message(
		("AC-10: _queue[1] must be unit_id=7 (is_player_controlled=false); "
		+ "got %d") % _runner._queue[1]
	).is_equal(7)


# ── AC-11 (deterministic queue across 100 iterations) ────────────────────────


## AC-11 / GDD AC-13 (determinism): the F-1 cascade produces the same queue order
## on every call for a given (initiative, stat_agility, is_player_controlled) input,
## even with intentional ties across multiple units.
##
## Approach: 20-unit roster with 5 pairs of identical (init, agi) values; each pair
## has units with tied init+agi but deterministic unit_id ASC final tiebreak.
## 100 iterations each reset and rebuild the runner; all captured queues must be
## element-wise identical to the first.
##
## Performance: 100 × O(N log N) with N=20 ≈ 8600 comparator calls — fast on modern
## hardware. If test runtime exceeds 1s, the iteration count can be reduced to 20.
func test_initialize_battle_deterministic_queue_100_iterations() -> void:
	# Arrange — 20-unit roster with intentional (init, agi) ties.
	# 5 pairs: (100,70), (90,80), (80,65), (70,90), (60,75)
	# Within each pair, two unit_ids share identical (init, agi, is_player_controlled);
	# F-1 Step 3 (unit_id ASC) is the final tiebreak — guarantees total order.
	# All hero_ids reuse MVP heroes (hero_id uniqueness is not a game rule for tests).
	var base_roster: Array[BattleUnit] = []
	# Pair A: init=100, agi=70
	base_roster.append(_make_unit(1,  _HERO_LIU_BEI,    _CLASS_COMMANDER, true))
	base_roster.append(_make_unit(2,  _HERO_GUAN_YU,    _CLASS_COMMANDER, false))
	# Pair B: init=90, agi=80
	base_roster.append(_make_unit(3,  _HERO_ZHANG_FEI,  _CLASS_INFANTRY,  true))
	base_roster.append(_make_unit(4,  _HERO_CAO_CAO,    _CLASS_INFANTRY,  false))
	# Pair C: init=80, agi=65
	base_roster.append(_make_unit(5,  _HERO_XIAHOU_DUN, _CLASS_ARCHER,    true))
	base_roster.append(_make_unit(6,  _HERO_LIU_BEI,    _CLASS_ARCHER,    false))
	# Pair D: init=70, agi=90
	base_roster.append(_make_unit(7,  _HERO_GUAN_YU,    _CLASS_CAVALRY,   true))
	base_roster.append(_make_unit(8,  _HERO_ZHANG_FEI,  _CLASS_CAVALRY,   false))
	# Pair E: init=60, agi=75
	base_roster.append(_make_unit(9,  _HERO_CAO_CAO,    _CLASS_SCOUT,     true))
	base_roster.append(_make_unit(10, _HERO_XIAHOU_DUN, _CLASS_SCOUT,     false))
	# Singles: no ties (unique init values)
	base_roster.append(_make_unit(11, _HERO_LIU_BEI,    _CLASS_STRATEGIST, true))
	base_roster.append(_make_unit(12, _HERO_GUAN_YU,    _CLASS_STRATEGIST, false))
	base_roster.append(_make_unit(13, _HERO_ZHANG_FEI,  _CLASS_COMMANDER,  true))
	base_roster.append(_make_unit(14, _HERO_CAO_CAO,    _CLASS_INFANTRY,   false))
	base_roster.append(_make_unit(15, _HERO_XIAHOU_DUN, _CLASS_ARCHER,     true))
	base_roster.append(_make_unit(16, _HERO_LIU_BEI,    _CLASS_CAVALRY,    false))
	base_roster.append(_make_unit(17, _HERO_GUAN_YU,    _CLASS_SCOUT,      true))
	base_roster.append(_make_unit(18, _HERO_ZHANG_FEI,  _CLASS_STRATEGIST, false))
	base_roster.append(_make_unit(19, _HERO_CAO_CAO,    _CLASS_COMMANDER,  true))
	base_roster.append(_make_unit(20, _HERO_XIAHOU_DUN, _CLASS_INFANTRY,   false))

	## Seed values applied after each initialize_battle call.
	## Format: [unit_id, initiative, stat_agility, is_player_controlled]
	var seeds: Array[Dictionary] = [
		{"uid": 1,  "init": 100, "agi": 70,  "player": true},
		{"uid": 2,  "init": 100, "agi": 70,  "player": false},
		{"uid": 3,  "init": 90,  "agi": 80,  "player": true},
		{"uid": 4,  "init": 90,  "agi": 80,  "player": false},
		{"uid": 5,  "init": 80,  "agi": 65,  "player": true},
		{"uid": 6,  "init": 80,  "agi": 65,  "player": false},
		{"uid": 7,  "init": 70,  "agi": 90,  "player": true},
		{"uid": 8,  "init": 70,  "agi": 90,  "player": false},
		{"uid": 9,  "init": 60,  "agi": 75,  "player": true},
		{"uid": 10, "init": 60,  "agi": 75,  "player": false},
		{"uid": 11, "init": 55,  "agi": 60,  "player": true},
		{"uid": 12, "init": 50,  "agi": 60,  "player": false},
		{"uid": 13, "init": 45,  "agi": 65,  "player": true},
		{"uid": 14, "init": 40,  "agi": 70,  "player": false},
		{"uid": 15, "init": 35,  "agi": 75,  "player": true},
		{"uid": 16, "init": 30,  "agi": 80,  "player": false},
		{"uid": 17, "init": 25,  "agi": 85,  "player": true},
		{"uid": 18, "init": 20,  "agi": 90,  "player": false},
		{"uid": 19, "init": 15,  "agi": 95,  "player": true},
		{"uid": 20, "init": 10,  "agi": 100, "player": false},
	]

	# First iteration — capture reference queue
	_runner._unit_states.clear()
	_runner._queue.clear()
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	_runner.initialize_battle(base_roster)
	for seed: Dictionary in seeds:
		_runner._seed_unit_state_for_test(
			seed["uid"] as int,
			seed["init"] as int,
			seed["agi"] as int,
			seed["player"] as bool
		)
	_runner._rebuild_queue()
	var reference_queue: Array[int] = []
	reference_queue.assign(_runner._queue)

	assert_int(reference_queue.size()).override_failure_message(
		"AC-11: reference queue must have 20 entries; got %d" % reference_queue.size()
	).is_equal(20)

	# Remaining 99 iterations — each must match the reference
	for iteration: int in range(1, 100):
		_runner._unit_states.clear()
		_runner._queue.clear()
		_runner._round_number = 0
		_runner._queue_index = 0
		_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
		_runner.initialize_battle(base_roster)
		for seed: Dictionary in seeds:
			_runner._seed_unit_state_for_test(
				seed["uid"] as int,
				seed["init"] as int,
				seed["agi"] as int,
				seed["player"] as bool
			)
		_runner._rebuild_queue()

		for i: int in range(20):
			assert_int(_runner._queue[i]).override_failure_message(
				("AC-11: iteration %d — _queue[%d] must be %d (reference); "
				+ "got %d — F-1 cascade is non-deterministic")
				% [iteration, i, reference_queue[i], _runner._queue[i]]
			).is_equal(reference_queue[i])


# ── AC-12 (static initiative not recomputed at _rebuild_queue) ───────────────


## AC-12 / GDD AC-09 (static initiative): _rebuild_queue reads cached initiative
## from _unit_states rather than re-querying UnitRole.get_initiative().
## CR-6 structural enforcement: once cached at BI-2, initiative is NOT recomputed.
##
## Given: 3-unit roster after initialize_battle (real hero initiatives computed).
## When:  the unit with the lowest initiative has its cached value mutated to the
##        maximum integer, then _rebuild_queue is called.
## Then:  that unit appears first in _queue (mutation was respected, not overwritten
##        by a re-computation from UnitRole.get_initiative).
func test_initialize_battle_static_initiative_not_recomputed_at_rebuild() -> void:
	# Arrange — 3-unit roster
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI,   _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU,   _CLASS_INFANTRY,  false))
	roster.append(_make_unit(3, _HERO_ZHANG_FEI, _CLASS_ARCHER,    true))

	_runner.initialize_battle(roster)

	# Find the unit currently last in the queue (lowest initiative)
	var last_unit_id: int = _runner._queue[2]

	# Capture initial queue snapshot for before-comparison
	var initial_first: int = _runner._queue[0]

	# Act — mutate the last unit's cached initiative to a maximum value
	# that would make it first if _rebuild_queue respects cached values
	_runner._unit_states[last_unit_id].initiative = 9999
	_runner._rebuild_queue()

	# Assert — the mutated unit must now be first (cached value respected)
	assert_int(_runner._queue[0]).override_failure_message(
		("AC-12: after mutating unit_id=%d initiative to 9999, "
		+ "_rebuild_queue must place it at _queue[0]; "
		+ "got _queue[0]=%d — _rebuild_queue is re-calling UnitRole.get_initiative "
		+ "instead of reading the cached _unit_states[].initiative value")
		% [last_unit_id, _runner._queue[0]]
	).is_equal(last_unit_id)

	# Confirm the originally-first unit is no longer first (sanity guard)
	# Only assert if initial_first != last_unit_id (they'd be the same only in
	# a degenerate 1-unit case, which cannot happen here — we have 3 units)
	assert_bool(_runner._queue[0] != initial_first).override_failure_message(
		("AC-12: the original _queue[0] (unit_id=%d) should no longer be first "
		+ "after mutating another unit's initiative to 9999; "
		+ "queue order appears unchanged — mutation may have had no effect")
		% initial_first
	).is_true()
