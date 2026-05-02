extends GdUnitTestSuite

## hp_status_initialize_unit_test.gd
## Unit tests for HP/Status story-002: initialize_unit + 3 read-only queries + CR-1a/CR-2 invariants.
## Covers AC-1 through AC-8. AC-9 verified via full-suite regression.
##
## Governing ADR: ADR-0010 — HP/Status — HPStatusController battle-scoped Node.
## Design reference: production/epics/hp-status/story-002-initialize-unit-and-queries.md
##
## G-15: before_test() is the canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
## G-15: BalanceConstants + UnitRole static caches both reset per-test (initialize_unit
##       calls UnitRole.get_max_hp which calls BalanceConstants.get_const internally).
## G-16: No parametric tables needed for this story; all cases are direct assertions.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.
## G-24: RHS dict-access casts wrapped in parens in == expressions.

# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript

# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Resets BalanceConstants + UnitRole static caches (mandatory — initialize_unit
	## calls UnitRole.get_max_hp which calls BalanceConstants.get_const internally).
	## Even though story-002 doesn't call BalanceConstants directly, the discipline
	## is established here for stories 003-007 per ADR-0010 story-002 Implementation Note 6.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	add_child(_controller)


func after_test() -> void:
	## Safety net: same reset after each test.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

## Builds a minimal HeroData with explicitly specified base_hp_seed.
## Default all other stats to 1 so callers only override what matters for the test.
## Mirrors tests/unit/foundation/unit_role_stat_derivation_test.gd::_make_hero pattern.
func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	return hero


# ── AC-1: Initial current_hp equals max_hp (CR-1a) ───────────────────────────

## AC-1: post-init get_current_hp returns the same value as get_max_hp.
## Verifies CR-1a: every unit starts at full HP; no exception paths on init.
func test_initialize_unit_sets_current_hp_to_max_hp() -> void:
	# Arrange
	var hero: HeroData = _make_hero(50)
	var expected_max_hp: int = UnitRole.get_max_hp(hero, UnitRole.UnitClass.INFANTRY)

	# Act
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.INFANTRY)

	# Assert
	var current: int = _controller.get_current_hp(1)
	var max_hp: int = _controller.get_max_hp(1)
	assert_int(current).override_failure_message(
		("AC-1: get_current_hp(1) should equal max_hp=%d on init; got current=%d"
		% [expected_max_hp, current])
	).is_equal(expected_max_hp)
	assert_int(max_hp).override_failure_message(
		"AC-1: get_max_hp(1) should equal UnitRole.get_max_hp result=%d; got %d" % [expected_max_hp, max_hp]
	).is_equal(expected_max_hp)
	assert_int(current).override_failure_message(
		"AC-1: current_hp must equal max_hp (CR-1a init invariant); current=%d max=%d" % [current, max_hp]
	).is_equal(max_hp)


# ── AC-2: HP read-only invariant — 100 successive queries return identical value ─

## AC-2: 100 successive get_current_hp calls return identical max_hp value.
## Confirms no internal mutation in query methods (read-only contract; no drift).
func test_post_init_get_current_hp_returns_max_hp_repeatedly() -> void:
	# Arrange
	var hero: HeroData = _make_hero(40)
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.ARCHER)
	var expected: int = _controller.get_max_hp(1)

	# Act + Assert
	for i: int in range(100):
		var result: int = _controller.get_current_hp(1)
		assert_int(result).override_failure_message(
			"AC-2: query #%d returned %d; expected constant %d (read-only drift detected)" % [i, result, expected]
		).is_equal(expected)


# ── AC-3: initialize_unit populates all 6 UnitHPState fields correctly ────────

## AC-3: directly inspect _state_by_unit[1] (test-private access per ADR-0010 §13
## DI-seam convention; _-prefix marks test bypass-seam allowed).
## Verifies all 6 UnitHPState fields match the constructor arguments exactly.
func test_initialize_unit_populates_six_fields_correctly() -> void:
	# Arrange
	var hero: HeroData = _make_hero(50)
	var expected_max_hp: int = UnitRole.get_max_hp(hero, UnitRole.UnitClass.CAVALRY)

	# Act
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.CAVALRY)

	# Assert — direct private-field inspection (test bypass-seam)
	var state: UnitHPState = _controller._state_by_unit[1]
	assert_object(state).is_not_null()
	assert_int(state.unit_id).override_failure_message(
		"AC-3: state.unit_id should be 1; got %d" % state.unit_id
	).is_equal(1)
	assert_int(state.max_hp).override_failure_message(
		"AC-3: state.max_hp should be UnitRole result=%d; got %d" % [expected_max_hp, state.max_hp]
	).is_equal(expected_max_hp)
	assert_int(state.current_hp).override_failure_message(
		("AC-3: state.current_hp should equal max_hp=%d (CR-1a); got %d"
		% [expected_max_hp, state.current_hp])
	).is_equal(expected_max_hp)
	assert_int(state.status_effects.size()).override_failure_message(
		"AC-3: state.status_effects must be empty [] on init; size=%d" % state.status_effects.size()
	).is_equal(0)
	assert_bool(state.hero == hero).override_failure_message(
		"AC-3: state.hero must be the same reference as the constructor arg"
	).is_true()
	assert_int(state.unit_class).override_failure_message(
		"AC-3: state.unit_class should be CAVALRY=%d; got %d" % [UnitRole.UnitClass.CAVALRY, state.unit_class]
	).is_equal(UnitRole.UnitClass.CAVALRY)


# ── AC-4: get_max_hp returns the cached value consistently ───────────────────

## AC-4: 100 successive get_max_hp calls return identical cached value.
## Validates one-time-per-battle UnitRole.get_max_hp cadence per ADR-0009 line 328.
func test_get_max_hp_returns_cached_value_consistently() -> void:
	# Arrange
	var hero: HeroData = _make_hero(60)
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.INFANTRY)
	var expected: int = UnitRole.get_max_hp(hero, UnitRole.UnitClass.INFANTRY)

	# Act + Assert
	for i: int in range(100):
		var result: int = _controller.get_max_hp(1)
		assert_int(result).override_failure_message(
			"AC-4: get_max_hp call #%d returned %d; expected constant cached=%d" % [i, result, expected]
		).is_equal(expected)


# ── AC-5: is_alive returns true on freshly-initialized unit ──────────────────

## AC-5: post-init is_alive returns true (current_hp == max_hp > 0 per UnitRole F-3 guarantee).
func test_is_alive_returns_true_on_init() -> void:
	# Arrange
	var hero: HeroData = _make_hero(50)
	_controller.initialize_unit(1, hero, UnitRole.UnitClass.INFANTRY)

	# Act + Assert
	assert_bool(_controller.is_alive(1)).override_failure_message(
		"AC-5: is_alive(1) must be true for a freshly-initialized unit (current_hp=max_hp>0)"
	).is_true()


# ── AC-6: Unknown unit_id defense-in-depth ────────────────────────────────────

## AC-6: get_current_hp(99), get_max_hp(99) return 0; is_alive(99) returns false.
## No initialize_unit call for unit_id=99 — tests the unknown-unit defense path.
## push_warning fires for the *_hp variants (ADR-0010 §5 line 211 spec);
## is_alive does NOT push_warning (canonical guard query — silent on unknown).
func test_unknown_unit_id_defense() -> void:
	# Arrange: empty controller — no initialize_unit calls

	# Act + Assert
	var current_hp: int = _controller.get_current_hp(99)
	assert_int(current_hp).override_failure_message(
		"AC-6: get_current_hp(99) must return 0 for unknown unit; got %d" % current_hp
	).is_equal(0)

	var max_hp: int = _controller.get_max_hp(99)
	assert_int(max_hp).override_failure_message(
		"AC-6: get_max_hp(99) must return 0 for unknown unit; got %d" % max_hp
	).is_equal(0)

	var alive: bool = _controller.is_alive(99)
	assert_bool(alive).override_failure_message(
		"AC-6: is_alive(99) must return false for unknown unit"
	).is_false()


# ── AC-7: Multiple-unit registry isolation ────────────────────────────────────

## AC-7: Two units with different heroes + classes produce distinct max_hp values.
## Verifies per-unit state isolation — no cross-contamination between unit entries.
func test_multiple_unit_isolation() -> void:
	# Arrange: distinct seeds + distinct classes → guaranteed distinct UnitRole outputs
	var hero_a: HeroData = _make_hero(30)  # lower seed
	var hero_b: HeroData = _make_hero(80)  # higher seed
	var expected_max_hp_a: int = UnitRole.get_max_hp(hero_a, UnitRole.UnitClass.INFANTRY)
	var expected_max_hp_b: int = UnitRole.get_max_hp(hero_b, UnitRole.UnitClass.CAVALRY)

	# Act
	_controller.initialize_unit(1, hero_a, UnitRole.UnitClass.INFANTRY)
	_controller.initialize_unit(2, hero_b, UnitRole.UnitClass.CAVALRY)

	# Assert — distinct max_hp values
	assert_bool(expected_max_hp_a != expected_max_hp_b).override_failure_message(
		("AC-7: test pre-condition: hero_a (seed=30, INFANTRY) and hero_b (seed=80, CAVALRY) "
		+ "must produce distinct max_hp values; both returned %d") % expected_max_hp_a
	).is_true()

	# Unit 1 state
	assert_int(_controller.get_max_hp(1)).override_failure_message(
		"AC-7: unit 1 max_hp should be %d; got %d" % [expected_max_hp_a, _controller.get_max_hp(1)]
	).is_equal(expected_max_hp_a)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-7: unit 1 current_hp should equal max_hp=%d; got %d" % [expected_max_hp_a, _controller.get_current_hp(1)]
	).is_equal(expected_max_hp_a)

	# Unit 2 state
	assert_int(_controller.get_max_hp(2)).override_failure_message(
		"AC-7: unit 2 max_hp should be %d; got %d" % [expected_max_hp_b, _controller.get_max_hp(2)]
	).is_equal(expected_max_hp_b)
	assert_int(_controller.get_current_hp(2)).override_failure_message(
		"AC-7: unit 2 current_hp should equal max_hp=%d; got %d" % [expected_max_hp_b, _controller.get_current_hp(2)]
	).is_equal(expected_max_hp_b)

	# Cross-contamination check: unit 1's state did not bleed into unit 2 and vice versa
	assert_bool(_controller.get_max_hp(1) != _controller.get_max_hp(2)).override_failure_message(
		"AC-7: unit 1 and unit 2 max_hp values must be distinct (no shared state); both=%d" % _controller.get_max_hp(1)
	).is_true()


# ── AC-8: Re-initialization silently overwrites prior state ──────────────────

## AC-8: calling initialize_unit twice for the same unit_id overwrites silently.
## Validates Battle Preparation idempotency contract per ADR-0010 Migration Plan §From.
## No exception, no warning (silent last-write-wins per Implementation Note 1).
func test_re_initialization_overwrites() -> void:
	# Arrange: first init with hero_a + INFANTRY
	var hero_a: HeroData = _make_hero(30)
	_controller.initialize_unit(1, hero_a, UnitRole.UnitClass.INFANTRY)
	var max_hp_v1: int = _controller.get_max_hp(1)

	# Arrange: second init with hero_b (higher seed) + CAVALRY for a different max_hp
	var hero_b: HeroData = _make_hero(80)
	var expected_max_hp_v2: int = UnitRole.get_max_hp(hero_b, UnitRole.UnitClass.CAVALRY)

	# Act: re-initialize same unit_id=1
	_controller.initialize_unit(1, hero_b, UnitRole.UnitClass.CAVALRY)

	# Assert: new state is in effect; old state discarded
	var max_hp_v2: int = _controller.get_max_hp(1)
	assert_int(max_hp_v2).override_failure_message(
		("AC-8: after re-init, max_hp should be new hero_b+CAVALRY value=%d; got %d "
		+ "(old max_hp_v1 was %d)") % [expected_max_hp_v2, max_hp_v2, max_hp_v1]
	).is_equal(expected_max_hp_v2)

	assert_int(_controller.get_current_hp(1)).override_failure_message(
		("AC-8: after re-init, current_hp must equal new max_hp=%d (CR-1a re-applied); got %d"
		% [expected_max_hp_v2, _controller.get_current_hp(1)])
	).is_equal(expected_max_hp_v2)

	# unit_class must reflect the new CAVALRY value
	var state: UnitHPState = _controller._state_by_unit[1]
	assert_int(state.unit_class).override_failure_message(
		("AC-8: state.unit_class must be CAVALRY=%d after re-init; got %d "
		+ "(old INFANTRY=%d was not overwritten)") % [UnitRole.UnitClass.CAVALRY, state.unit_class, UnitRole.UnitClass.INFANTRY]
	).is_equal(UnitRole.UnitClass.CAVALRY)

	# hero reference must be the new hero_b
	assert_bool(state.hero == hero_b).override_failure_message(
		"AC-8: state.hero must reference hero_b after re-init, not the old hero_a"
	).is_true()
