extends GdUnitTestSuite

## hp_status_apply_damage_test.gd
## Unit tests for HP/Status story-003: apply_damage F-1 4-step pipeline.
## Covers AC-1..AC-12. AC-13 verified via full-suite regression.
##
## Governing ADR: ADR-0010 — HP/Status §6 F-1 pipeline + §5 Verification + R-1 mitigation.
## Design reference: production/epics/hp-status/story-003-apply-damage-and-f1-pipeline.md
##
## G-4:  AC-11 deferred handler uses method-reference (instance var write) — NOT lambda
##       primitive capture — to avoid outer-local reassignment trap.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.
## G-10: Real GameBus autoload subscription (NOT GameBusStub).
## G-15: before_test() + after_test() canonical hooks with BalanceConstants + UnitRole reset.
## G-22: AC-12 commander stub test uses FileAccess source-content scan.
## G-24: RHS dict-access casts wrapped in parens in == expressions.

# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript

# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController

## Signal-capture sentinel: records HP seen inside the unit_died handler.
## Set to -1 before each test; updated by _on_unit_died_handler.
var _captured_hp_at_emit: int = -1

## Counts synchronous unit_died firings in the standard (non-deferred) handler.
var _emit_count: int = 0

## Counts unit_died firings in the CONNECT_DEFERRED handler (AC-11).
var _deferred_call_count: int = 0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Resets BalanceConstants + UnitRole static caches (mandatory — apply_damage
	## calls BalanceConstants.get_const for SHIELD_WALL_FLAT / DEFEND_STANCE_REDUCTION / MIN_DAMAGE).
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	add_child(_controller)
	_captured_hp_at_emit = -1
	_emit_count = 0
	_deferred_call_count = 0
	# Connect standard (synchronous) handler for signal-capture tests.
	# G-15: matching disconnect happens in after_test().
	GameBus.unit_died.connect(_on_unit_died_handler)


func after_test() -> void:
	## G-15: disconnect signal handlers with matching symmetry per connect in before_test.
	if GameBus.unit_died.is_connected(_on_unit_died_handler):
		GameBus.unit_died.disconnect(_on_unit_died_handler)
	# Safety reset for static caches.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Signal handlers (method-references — G-4 safe) ───────────────────────────

## Standard synchronous handler: captures HP at emit time + increments counter.
## Used by AC-6, AC-7, and all death-path tests.
func _on_unit_died_handler(uid: int) -> void:
	_captured_hp_at_emit = _controller.get_current_hp(uid)
	_emit_count += 1


## CONNECT_DEFERRED handler (AC-11): instance-var write propagates correctly (G-4 safe).
func _deferred_unit_died_handler(_uid: int) -> void:
	_deferred_call_count += 1


# ── Hero fixture builder ──────────────────────────────────────────────────────

## Builds a minimal HeroData with explicitly specified base_hp_seed.
## Default all other stats to defaults so callers only override what matters.
## Mirrors hp_status_initialize_unit_test.gd::_make_hero pattern.
func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	return hero


# ── DEFEND_STANCE injection helper ───────────────────────────────────────────

## Injects a DEFEND_STANCE StatusEffect directly into the unit's status_effects array.
## Story-003 test-side shortcut — story-005 ships the canonical apply_status pathway.
## G-22: loads from .tres template and duplicates per ADR-0010 Implementation Note 5.
func _attach_defend_stance(unit_id: int) -> void:
	var ds_template: StatusEffect = load("res://assets/data/status_effects/defend_stance.tres") as StatusEffect
	assert(ds_template != null)
	var instance: StatusEffect = ds_template.duplicate()
	_controller._state_by_unit[unit_id].status_effects.append(instance)


# ── AC-1: PHYSICAL + Shield Wall basic case (GDD AC-03) ──────────────────────

## AC-1: Infantry (has passive_shield_wall) receives PHYSICAL damage.
## SHIELD_WALL_FLAT=5 subtracted: 40 - 5 = 35 damage; HP 120 → 85.
func test_physical_shield_wall_basic_case_reduces_by_5() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 120

	# Act
	_controller.apply_damage(1, 40, 0, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		("AC-1: INFANTRY PHYSICAL 40 damage with SHIELD_WALL_FLAT: "
		+ "expected HP=85 (120 - (40-5)); got %d") % hp
	).is_equal(85)


# ── AC-2: MAGICAL bypasses Shield Wall (GDD AC-04) ───────────────────────────

## AC-2: Infantry receives MAGICAL damage (attack_type=1).
## Shield Wall does NOT apply to MAGICAL; full 40 damage: HP 120 → 80.
func test_magical_bypasses_shield_wall() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 120

	# Act
	_controller.apply_damage(1, 40, 1, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		("AC-2: INFANTRY MAGICAL 40 damage (bypass Shield Wall): "
		+ "expected HP=80 (full 40 damage); got %d") % hp
	).is_equal(80)


# ── AC-3: MIN_DAMAGE floor under Shield Wall (GDD AC-05 / EC-01) ─────────────

## AC-3: PHYSICAL 3 damage on Infantry — Step 1 yields 3-5=-2; Step 3 floor to 1.
## HP 120 → 119.
func test_min_damage_floor_under_shield_wall() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 120

	# Act
	_controller.apply_damage(1, 3, 0, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		("AC-3: INFANTRY PHYSICAL 3 with SHIELD_WALL: 3-5=-2 → max(1,-2)=1; "
		+ "expected HP=119; got %d") % hp
	).is_equal(119)


# ── AC-4: DEFEND_STANCE -50% reduction (GDD AC-06) ───────────────────────────

## AC-4: DEFEND_STANCE-active unit: int(floor(20 * 0.5)) = 10; HP 80 → 70.
## Uses CAVALRY (no passive_shield_wall) so Step 1 does not interfere with Step 2 isolation.
func test_defend_stance_50_percent_reduction() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller._state_by_unit[1].current_hp = 80
	_attach_defend_stance(1)

	# Act
	_controller.apply_damage(1, 20, 0, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		("AC-4: DEFEND_STANCE -50%%: int(floor(20*0.5))=10 final_damage; "
		+ "expected HP=70; got %d") % hp
	).is_equal(70)


# ── AC-5: DEFEND_STANCE + MIN_DAMAGE floor combined (EC-02) ──────────────────

## AC-5: DEFEND_STANCE on damage=1: int(floor(1*0.5))=0 → max(1,0)=1; HP 80 → 79.
## Proves Step 2 runs BEFORE Step 3 (EC-03 bind-order, AC-10 coverage).
## Uses CAVALRY (no passive_shield_wall) so Step 1 does not alter the damage before Step 2.
func test_defend_stance_min_damage_floor_combined() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller._state_by_unit[1].current_hp = 80
	_attach_defend_stance(1)

	# Act
	_controller.apply_damage(1, 1, 0, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		("AC-5 / EC-02: DEFEND_STANCE on damage=1: int(floor(1*0.5))=0 → max(1,0)=1; "
		+ "expected HP=79; got %d") % hp
	).is_equal(79)


# ── AC-6: current_hp reaches 0 + unit_died emitted (GDD AC-17 emit-only) ─────

## AC-6: apply_damage that brings HP to exactly 0 emits unit_died exactly once.
## Uses CAVALRY (no passive_shield_wall) so PHYSICAL 10 damage is not reduced by Step 1.
func test_current_hp_reaches_zero_emits_unit_died() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller._state_by_unit[1].current_hp = 10

	# Act
	_controller.apply_damage(1, 10, 0, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		"AC-6: HP must reach 0 after 10 damage on HP=10; got %d" % hp
	).is_equal(0)
	assert_int(_emit_count).override_failure_message(
		("AC-6: unit_died must be emitted exactly once; "
		+ "emit_count=%d") % _emit_count
	).is_equal(1)


# ── AC-7: Verification §5 — emit AFTER mutation ──────────────────────────────

## AC-7: Subscriber reading get_current_hp(uid) inside the unit_died handler sees 0.
## Proves GameBus.unit_died fires AFTER current_hp = 0 assignment (not before).
func test_unit_died_emit_sees_post_mutation_zero() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 10

	# Act: _on_unit_died_handler captures get_current_hp(uid) at emit time
	_controller.apply_damage(1, 100, 0, [])

	# Assert: handler ran AND saw 0 (post-mutation), NOT the pre-mutation value 10
	assert_int(_captured_hp_at_emit).override_failure_message(
		("AC-7: Verification §5: handler captured HP=%d at emit; must be 0. "
		+ "A value of 10 would prove emit fired BEFORE the mutation (violation).") % _captured_hp_at_emit
	).is_equal(0)


# ── AC-8: Dead / unknown unit early-return ────────────────────────────────────

## AC-8a: apply_damage on unknown unit_id emits no signal + returns silently.
func test_dead_or_unknown_unit_early_return_unknown_uid() -> void:
	# Arrange: empty controller — no initialize_unit(99)

	# Act
	_controller.apply_damage(99, 10, 0, [])

	# Assert: no signal fired, no state created
	assert_int(_emit_count).override_failure_message(
		("AC-8a: unknown uid 99 must not emit unit_died; "
		+ "emit_count=%d") % _emit_count
	).is_equal(0)
	assert_bool(_controller._state_by_unit.has(99)).override_failure_message(
		"AC-8a: unknown uid 99 must not create any state entry"
	).is_false()


## AC-8b: apply_damage on already-dead unit (current_hp=0) emits no signal.
func test_dead_or_unknown_unit_early_return_already_dead() -> void:
	# Arrange: initialize unit then force HP to 0 (simulates already-dead state)
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 0

	# Act
	_controller.apply_damage(1, 10, 0, [])

	# Assert: already-dead path — no signal, HP stays 0
	assert_int(_emit_count).override_failure_message(
		("AC-8b: already-dead unit must not emit unit_died again; "
		+ "emit_count=%d") % _emit_count
	).is_equal(0)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-8b: already-dead unit HP must remain 0; got %d" % _controller.get_current_hp(1)
	).is_equal(0)


# ── AC-9: Non-Shield-Wall class skips Step 1 ─────────────────────────────────

## AC-9: CAVALRY has passive_charge (not passive_shield_wall); Step 1 skipped.
## PHYSICAL 20 damage on HP=80 → full 20 damage; HP → 60.
func test_non_shield_wall_class_skips_step_1() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller._state_by_unit[1].current_hp = 80

	# Act
	_controller.apply_damage(1, 20, 0, [])

	# Assert
	var hp: int = _controller.get_current_hp(1)
	assert_int(hp).override_failure_message(
		("AC-9: CAVALRY (no passive_shield_wall) PHYSICAL 20 damage: "
		+ "Step 1 skipped; expected HP=60; got %d") % hp
	).is_equal(60)


# ── AC-11: R-1 CONNECT_DEFERRED non-recursion ────────────────────────────────

## AC-11: A subscriber connected with CONNECT_DEFERRED does NOT run synchronously
## when unit_died is emitted. It runs only after process_frame drains the deferred queue.
## G-4: uses method-reference _deferred_unit_died_handler (instance var) — not lambda.
func test_unit_died_subscriber_with_deferred_does_not_synchronously_recurse() -> void:
	# Arrange
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 10
	_deferred_call_count = 0
	GameBus.unit_died.connect(_deferred_unit_died_handler, Object.CONNECT_DEFERRED)

	# Act: synchronously emit unit_died
	_controller.apply_damage(1, 100, 0, [])

	# Assert synchronous: deferred handler has NOT run yet; standard handler HAS run
	assert_int(_deferred_call_count).override_failure_message(
		("AC-11: CONNECT_DEFERRED handler must not fire synchronously; "
		+ "deferred_call_count=%d immediately after emit") % _deferred_call_count
	).is_equal(0)
	assert_int(_emit_count).override_failure_message(
		("AC-11: standard sync handler must have fired once; "
		+ "emit_count=%d") % _emit_count
	).is_equal(1)

	# Drain deferred queue
	await get_tree().process_frame

	# Assert deferred: handler ran exactly once after process_frame
	assert_int(_deferred_call_count).override_failure_message(
		("AC-11: CONNECT_DEFERRED handler must fire after process_frame; "
		+ "deferred_call_count=%d") % _deferred_call_count
	).is_equal(1)

	# Cleanup: disconnect deferred handler
	if GameBus.unit_died.is_connected(_deferred_unit_died_handler):
		GameBus.unit_died.disconnect(_deferred_unit_died_handler)


# ── AC-12: Commander death triggers _propagate_demoralized_radius stub ────────

## AC-12 (a): Commander death via apply_damage does not crash (story-007 full body).
## Functionally proves the call site exists and the method is reachable.
## Story-007 adaptation: _propagate_demoralized_radius now has full body requiring
## _map_grid DI (R-3 assert). Inject MapGridStub so the real body runs without crash.
## With only 1 unit (the commander), the propagation loop skips the commander itself
## and exits — no allies to demoralize. Test verifies death + emit still work correctly.
func test_commander_death_triggers_propagate_demoralized_radius_stub() -> void:
	# Arrange: inject MapGridStub (required by story-007 _map_grid R-3 assert)
	var map_stub: MapGridStub = MapGridStub.new()
	_controller.add_child(map_stub)  # G-6: parent to controller to avoid orphan
	_controller._map_grid = map_stub
	map_stub.set_dimensions_for_test(Vector2i(8, 8))
	map_stub.set_occupant_for_test(Vector2i(0, 0), 1)  # place commander so _get_unit_coord finds it

	# Commander-class unit with low HP
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.COMMANDER)
	_controller._state_by_unit[1].current_hp = 5

	# Act: bring HP to 0 — triggers _propagate_demoralized_radius full body
	# No allies in _state_by_unit → propagation loop exits after self-exclusion → no crash
	_controller.apply_damage(1, 100, 0, [])

	# Assert: unit is dead + no crash (propagation ran with empty ally set)
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-12: Commander HP must reach 0 after lethal damage; got %d" % _controller.get_current_hp(1)
	).is_equal(0)
	assert_int(_emit_count).override_failure_message(
		"AC-12: unit_died must have been emitted for Commander death; emit_count=%d" % _emit_count
	).is_equal(1)


## AC-12 (b): Source-content scan confirms call site + COMMANDER guard both present.
## G-22 structural assertion — catches accidental removal of the call site or guard.
func test_commander_stub_call_site_and_guard_present_in_source() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://src/core/hp_status_controller.gd"
	)
	assert_bool(content.contains("_propagate_demoralized_radius(state)")).override_failure_message(
		("AC-12 (b): Source must contain _propagate_demoralized_radius(state) call site; "
		+ "story-007 depends on this call being wired by story-003.")
	).is_true()
	assert_bool(content.contains("UnitRole.UnitClass.COMMANDER")).override_failure_message(
		("AC-12 (b): Source must guard the call with UnitClass.COMMANDER check; "
		+ "non-Commander deaths must NOT trigger propagation.")
	).is_true()


# ── Non-Commander death does NOT trigger propagate stub ──────────────────────

## Regression: INFANTRY death must not enter the COMMANDER branch.
## Verifies Step 4 condition guard `if state.unit_class == UnitRole.UnitClass.COMMANDER`.
func test_non_commander_death_does_not_call_propagate_stub() -> void:
	# Arrange: INFANTRY unit — dies normally
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)
	_controller._state_by_unit[1].current_hp = 5

	# Act: INFANTRY death — should NOT trigger _propagate_demoralized_radius
	_controller.apply_damage(1, 100, 0, [])

	# Assert: unit died + emit fired + no crash
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"Regression: INFANTRY HP must reach 0 after lethal damage; got %d" % _controller.get_current_hp(1)
	).is_equal(0)
	assert_int(_emit_count).override_failure_message(
		"Regression: unit_died must have been emitted for INFANTRY death; emit_count=%d" % _emit_count
	).is_equal(1)
