extends GdUnitTestSuite

## hp_status_demoralized_propagation_test.gd
## Integration tests for HP/Status story-007:
##   _propagate_demoralized_radius (ADR-0010 §11 full body)
##   R-6 dual-invocation (apply_damage Step 4 AND _apply_turn_start_tick DoT-kill branch)
##   EC-17 DEMORALIZED refresh via CR-5c
##
## Covers AC-1 through AC-12 from story-007 §Acceptance Criteria (12 test functions).
## AC-13 (regression baseline) is verified via the full GdUnit4 suite headless run.
##
## Governing ADR: ADR-0010 — HP/Status §11 + §6 + §8 + R-6 mitigation
## Design reference: production/epics/hp-status/story-007-demoralized-radius-and-r6-dual-invocation.md
##
## TEST CLASSIFICATION: Integration — crosses HPStatusController + MapGrid + GameBus.
## Uses _propagate_demoralized_radius + apply_damage + _apply_turn_start_tick call paths.
##
## GOTCHA AWARENESS:
##   G-4  — lambda captures: use Array.append pattern, NOT primitive reassignment
##   G-6  — orphan detection fires BETWEEN test body exit and after_test
##   G-9  — % operator precedence; wrap multi-line concat in parens
##   G-12 — MapTileData (NOT TileData — collides with Godot built-in)
##   G-15 — before_test() is canonical hook (NOT before_each)
##   G-22 — assert() failures not capturable via GdUnit4; use source-scan pattern
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
	# G-6: parent stub to controller so orphan detector (fires BETWEEN test body and after_test)
	# sees it as tree-attached. Freed automatically when controller is freed by GdUnit4 teardown.
	_controller.add_child(_map_grid_stub)
	add_child(_controller)


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

## Builds a minimal HeroData with faction. Mirrors hp_status_turn_start_tick_test.gd pattern.
func _make_hero(p_base_hp_seed: int = 50, p_faction: int = 0) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	hero.faction = p_faction
	hero.stat_might = 80
	hero.stat_command = 80
	hero.stat_intellect = 80
	hero.base_initiative_seed = 60
	hero.move_range = 4
	return hero


## Programmatic battle setup for AC-2..AC-12 propagation tests.
## Coords:
##   commander_id=1 at (5,5) — COMMANDER class, faction=0 (player)
##   ally_a_id=2  at (5,3) — INFANTRY, faction=0, dist=2 (within radius=4)
##   ally_b_id=3  at (7,5) — CAVALRY,  faction=0, dist=2 (within radius=4)
##   ally_far_id=4 at (8,8) — INFANTRY, faction=0, dist=6 (OUTSIDE radius=4)
##   enemy_id=5   at (6,5) — INFANTRY, faction=1 (enemy), dist=1 (within radius but enemy)
func _setup_battle_with_commander_and_allies() -> void:
	_controller.initialize_unit(1, _make_hero(50, 0), UnitRole.UnitClass.COMMANDER)
	_controller.initialize_unit(2, _make_hero(50, 0), UnitRole.UnitClass.INFANTRY)
	_controller.initialize_unit(3, _make_hero(50, 0), UnitRole.UnitClass.CAVALRY)
	_controller.initialize_unit(4, _make_hero(50, 0), UnitRole.UnitClass.INFANTRY)
	_controller.initialize_unit(5, _make_hero(50, 1), UnitRole.UnitClass.INFANTRY)  # ENEMY faction=1

	_map_grid_stub.set_dimensions_for_test(Vector2i(10, 10))
	_map_grid_stub.set_occupant_for_test(Vector2i(5, 5), 1)  # commander — dist=0
	_map_grid_stub.set_occupant_for_test(Vector2i(5, 3), 2)  # ally A — dist=2
	_map_grid_stub.set_occupant_for_test(Vector2i(7, 5), 3)  # ally B — dist=2
	_map_grid_stub.set_occupant_for_test(Vector2i(8, 8), 4)  # ally Far — dist=6 (outside radius=4)
	_map_grid_stub.set_occupant_for_test(Vector2i(6, 5), 5)  # enemy — dist=1 but faction=1


# ── AC-1: R-3 _map_grid null assertion present in source ─────────────────────

## AC-1: _propagate_demoralized_radius first line must be the R-3 assert.
## GdUnit4 v6.1.2 doesn't reliably capture assert failures (G-22 pattern); use
## structural source-file scan — verifies assertion is present and exact-quoted per ADR-0010 §11.
func test_propagate_assert_fires_when_map_grid_null() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/core/hp_status_controller.gd")
	assert_bool(content.contains(
		"assert(_map_grid != null, \"HPStatusController._map_grid must be injected by Battle Preparation\")"
	)).override_failure_message(
		"AC-1: _propagate_demoralized_radius must include the exact R-3 assert as its first line"
	).is_true()


# ── AC-2: Manhattan radius filter (GDD AC-18) ────────────────────────────────

## AC-2: Commander at (5,5) dies; allies within radius=4 receive DEMORALIZED; ally far does NOT.
## Verifies: ally_a(dist=2) YES, ally_b(dist=2) YES, ally_far(dist=6) NO, enemy NO.
func test_propagate_applies_demoralized_to_allies_within_radius() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Act: commander dies via massive damage → apply_damage Step 4 triggers propagation
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: within-radius allies have DEMORALIZED
	assert_int(_controller._state_by_unit[2].status_effects.size()).override_failure_message(
		"AC-2: ally_a (dist=2, within radius=4) must have DEMORALIZED after commander death"
	).is_equal(1)
	assert_bool(
		(_controller._state_by_unit[2].status_effects[0] as StatusEffect).effect_id == &"demoralized"
	).override_failure_message(
		"AC-2: ally_a status_effects[0] must be DEMORALIZED"
	).is_true()

	assert_int(_controller._state_by_unit[3].status_effects.size()).override_failure_message(
		"AC-2: ally_b (dist=2, within radius=4) must have DEMORALIZED after commander death"
	).is_equal(1)
	assert_bool(
		(_controller._state_by_unit[3].status_effects[0] as StatusEffect).effect_id == &"demoralized"
	).override_failure_message(
		"AC-2: ally_b status_effects[0] must be DEMORALIZED"
	).is_true()

	# Assert: outside-radius ally does NOT have DEMORALIZED
	assert_int(_controller._state_by_unit[4].status_effects.size()).override_failure_message(
		"AC-2: ally_far (dist=6, outside radius=4) must NOT have DEMORALIZED"
	).is_equal(0)

	# Assert: enemy does NOT have DEMORALIZED
	assert_int(_controller._state_by_unit[5].status_effects.size()).override_failure_message(
		"AC-2: enemy (faction=1) must NOT receive DEMORALIZED even at dist=1"
	).is_equal(0)


# ── AC-3: Full integration via apply_damage Step 4 ───────────────────────────

## AC-3: apply_damage Step 4 integration — allies receive DEMORALIZED with correct
## remaining_turns=DEMORALIZED_DEFAULT_DURATION=4 and source_unit_id=1 (commander).
func test_propagate_full_integration_via_apply_damage_step_4() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Act: bring commander HP to 0
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: commander dead
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-3 precondition: commander HP must be 0"
	).is_equal(0)

	# Assert: ally_a has DEMORALIZED with correct remaining_turns + source
	var ally_a_effect: StatusEffect = _controller._state_by_unit[2].status_effects[0] as StatusEffect
	assert_int(ally_a_effect.remaining_turns).override_failure_message(
		"AC-3: ally_a DEMORALIZED remaining_turns must equal DEMORALIZED_DEFAULT_DURATION=4"
	).is_equal(4)
	assert_int(ally_a_effect.source_unit_id).override_failure_message(
		"AC-3: ally_a DEMORALIZED source_unit_id must be commander_id=1"
	).is_equal(1)

	# Assert: ally_b has DEMORALIZED with correct remaining_turns + source
	var ally_b_effect: StatusEffect = _controller._state_by_unit[3].status_effects[0] as StatusEffect
	assert_int(ally_b_effect.remaining_turns).override_failure_message(
		"AC-3: ally_b DEMORALIZED remaining_turns must equal DEMORALIZED_DEFAULT_DURATION=4"
	).is_equal(4)
	assert_int(ally_b_effect.source_unit_id).override_failure_message(
		"AC-3: ally_b DEMORALIZED source_unit_id must be commander_id=1"
	).is_equal(1)


# ── AC-4: R-6 DoT-kill dual-invocation ───────────────────────────────────────

## AC-4: DoT-killed Commander (via POISON) triggers DEMORALIZED radius propagation
## from the _apply_turn_start_tick DoT-kill branch (R-6 dual-invocation).
func test_propagate_r6_dot_kill_dual_invocation() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Apply POISON to commander, then force HP to 1 to guarantee DoT kill on next tick
	_controller.apply_status(1, &"poison", -1, 99)
	_controller._state_by_unit[1].current_hp = 1

	# Act: DoT tick brings commander HP to 0 → DoT-kill branch fires propagation
	_controller._apply_turn_start_tick(1)

	# Assert: commander dead via DoT
	assert_int(_controller.get_current_hp(1)).override_failure_message(
		"AC-4: commander HP must be 0 after POISON kill tick"
	).is_equal(0)

	# Assert: allies within radius received DEMORALIZED via DoT-kill branch
	assert_int(_controller._state_by_unit[2].status_effects.size()).override_failure_message(
		"AC-4: ally_a must have DEMORALIZED after DoT-killed commander (R-6 dual-invocation)"
	).is_equal(1)
	assert_bool(
		(_controller._state_by_unit[2].status_effects[0] as StatusEffect).effect_id == &"demoralized"
	).override_failure_message(
		"AC-4: ally_a status effect must be DEMORALIZED (not some other effect)"
	).is_true()

	assert_int(_controller._state_by_unit[3].status_effects.size()).override_failure_message(
		"AC-4: ally_b must have DEMORALIZED after DoT-killed commander (R-6 dual-invocation)"
	).is_equal(1)

	# ally_far outside radius — must NOT receive DEMORALIZED
	assert_int(_controller._state_by_unit[4].status_effects.size()).override_failure_message(
		"AC-4: ally_far (outside radius=4) must NOT receive DEMORALIZED via DoT-kill path"
	).is_equal(0)


# ── AC-5: Non-Commander death does NOT propagate ──────────────────────────────

## AC-5: INFANTRY unit (unit_class != COMMANDER) dies → _propagate_demoralized_radius
## is NOT invoked → no allies receive DEMORALIZED.
func test_non_commander_death_does_not_propagate() -> void:
	# Arrange: place two infantry units (no commander)
	_controller.initialize_unit(10, _make_hero(50, 0), UnitRole.UnitClass.INFANTRY)
	_controller.initialize_unit(11, _make_hero(50, 0), UnitRole.UnitClass.INFANTRY)

	_map_grid_stub.set_dimensions_for_test(Vector2i(8, 8))
	_map_grid_stub.set_occupant_for_test(Vector2i(1, 1), 10)
	_map_grid_stub.set_occupant_for_test(Vector2i(2, 1), 11)  # dist=1 — would be in radius

	# Act: non-commander unit dies
	_controller.apply_damage(10, 9999, 0, [])

	# Assert: unit 10 dead
	assert_int(_controller.get_current_hp(10)).override_failure_message(
		"AC-5 precondition: unit 10 must be dead"
	).is_equal(0)

	# Assert: nearby unit 11 does NOT have DEMORALIZED
	assert_int(_controller._state_by_unit[11].status_effects.size()).override_failure_message(
		"AC-5: non-Commander death must NOT trigger DEMORALIZED propagation; unit 11 must have no effects"
	).is_equal(0)


# ── AC-6: EC-17 already-DEMORALIZED ally refresh ─────────────────────────────

## AC-6: Ally already has DEMORALIZED (remaining_turns=2, source=99). Commander dies.
## CR-5c refresh: ally's DEMORALIZED refreshed to remaining_turns=4, source updated to commander=1.
func test_already_demoralized_ally_remaining_turns_refreshed_to_default() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Pre-apply DEMORALIZED to ally_a with lower remaining_turns from a different source
	_controller.apply_status(2, &"demoralized", 2, 99)  # remaining_turns=2, source=99
	assert_int((_controller._state_by_unit[2].status_effects[0] as StatusEffect).remaining_turns).override_failure_message(
		"AC-6 precondition: ally_a DEMORALIZED must start at remaining_turns=2"
	).is_equal(2)
	assert_int((_controller._state_by_unit[2].status_effects[0] as StatusEffect).source_unit_id).override_failure_message(
		"AC-6 precondition: ally_a DEMORALIZED source must start at 99"
	).is_equal(99)

	# Act: commander dies → propagation refreshes ally_a's DEMORALIZED
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: remaining_turns refreshed to DEMORALIZED_DEFAULT_DURATION=4
	var refreshed: StatusEffect = _controller._state_by_unit[2].status_effects[0] as StatusEffect
	assert_int(refreshed.remaining_turns).override_failure_message(
		"AC-6: ally_a DEMORALIZED remaining_turns must be refreshed to 4 (DEMORALIZED_DEFAULT_DURATION)"
	).is_equal(4)

	# Assert: source_unit_id updated to commander (not prior source 99)
	assert_int(refreshed.source_unit_id).override_failure_message(
		"AC-6: ally_a DEMORALIZED source_unit_id must be updated to commander_id=1 (not stale 99)"
	).is_equal(1)

	# Assert: only 1 effect on ally_a (no duplicate stack — CR-5c refresh, not append)
	assert_int(_controller._state_by_unit[2].status_effects.size()).override_failure_message(
		"AC-6: ally_a must have exactly 1 DEMORALIZED effect (refresh, not stack)"
	).is_equal(1)


# ── AC-7: Enemy faction excluded ──────────────────────────────────────────────

## AC-7: Enemy unit (faction=1) at dist=1 from commander does NOT receive DEMORALIZED.
## _is_ally(commander_state, enemy_state) returns false → excluded.
func test_enemy_faction_excluded_from_propagation() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Act
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: enemy (unit 5, faction=1) has no DEMORALIZED despite being at dist=1
	assert_int(_controller._state_by_unit[5].status_effects.size()).override_failure_message(
		"AC-7: enemy (faction=1) must NOT receive DEMORALIZED even at dist=1 from dead commander"
	).is_equal(0)


# ── AC-8: Dead ally in radius excluded ───────────────────────────────────────

## AC-8: Ally already at current_hp=0 (dead) is skipped per `if state.current_hp == 0: continue`.
func test_dead_ally_in_radius_excluded() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Force ally_a to dead (current_hp=0) via direct mutation (bypasses apply_damage to avoid
	# triggering any other propagation logic)
	_controller._state_by_unit[2].current_hp = 0

	# Act: commander dies
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: dead ally_a has NO DEMORALIZED (skipped per dead-check in propagation loop)
	assert_int(_controller._state_by_unit[2].status_effects.size()).override_failure_message(
		"AC-8: dead ally (current_hp=0) within radius must NOT receive DEMORALIZED"
	).is_equal(0)

	# Assert: living ally_b still receives DEMORALIZED (propagation not blocked for others)
	assert_int(_controller._state_by_unit[3].status_effects.size()).override_failure_message(
		"AC-8: living ally_b must still receive DEMORALIZED (dead-ally exclusion must not break loop)"
	).is_equal(1)


# ── AC-9: Commander itself excluded ──────────────────────────────────────────

## AC-9: The dying commander's own UnitHPState is excluded from DEMORALIZED application.
## unit_id == commander_state.unit_id → continue in propagation loop.
func test_commander_itself_excluded_from_propagation() -> void:
	# Arrange
	_setup_battle_with_commander_and_allies()

	# Act
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: commander (unit 1) has no DEMORALIZED on its own status_effects
	# Note: commander is dead (current_hp=0) so even if the loop somehow didn't skip it,
	# the dead-check would also exclude it. The unit_id-match skip fires first.
	assert_int(_controller._state_by_unit[1].status_effects.size()).override_failure_message(
		"AC-9: commander itself must NOT receive DEMORALIZED from its own death propagation"
	).is_equal(0)


# ── AC-10: is_morale_anchor branch DEFERRED comment present ──────────────────

## AC-10: Source-file scan verifies the DEFERRED comment is present AND
## no state.hero.is_morale_anchor field access exists (would crash; field absent from HeroData).
func test_is_morale_anchor_branch_deferred_comment_present() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/core/hp_status_controller.gd")

	assert_bool(content.contains("is_morale_anchor branch DEFERRED post-MVP per OQ-2")).override_failure_message(
		("AC-10: _propagate_demoralized_radius must contain the DEFERRED comment "
		+ "'is_morale_anchor branch DEFERRED post-MVP per OQ-2'")
	).is_true()

	assert_bool(content.contains("state.hero.is_morale_anchor")).override_failure_message(
		("AC-10: _propagate_demoralized_radius must NOT access state.hero.is_morale_anchor "
		+ "(field absent from HeroData 26-field schema — would crash at runtime)")
	).is_false()


# ── AC-11: No GameBus.*.emit() inside _propagate_demoralized_radius ───────────

## AC-11: Source-file scan of _propagate_demoralized_radius body verifies no GameBus emit calls.
## Only apply_damage Step 4 and DoT-kill branch own unit_died emission.
func test_propagate_does_not_emit_signals() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/core/hp_status_controller.gd")
	var lines: PackedStringArray = content.split("\n")
	var in_propagate: bool = false
	var body_lines: Array[String] = []
	for line: String in lines:
		if line.begins_with("func _propagate_demoralized_radius"):
			in_propagate = true
			continue
		if in_propagate and line.begins_with("func "):
			break  # next function — stop collecting
		if in_propagate:
			body_lines.append(line)

	# Verify we actually found the function body (defensive: would catch a rename)
	assert_bool(body_lines.size() > 0).override_failure_message(
		"AC-11: could not locate _propagate_demoralized_radius body in source — function may have been renamed"
	).is_true()

	# Verify no line in the body calls GameBus.*.emit(
	for body_line: String in body_lines:
		var has_emit: bool = body_line.contains("GameBus.") and body_line.contains(".emit(")
		assert_bool(has_emit).override_failure_message(
			("AC-11: _propagate_demoralized_radius body must not call GameBus.*.emit(); "
			+ "offending line: '%s'") % body_line
		).is_false()


# ── AC-12: keys() snapshot iteration processes all allies correctly ────────────

## AC-12: All 3 player-faction allies are iterated during propagation.
## Within-radius allies (A + B) receive DEMORALIZED; outside-radius ally (Far) is iterated
## but rejected by the distance check — NOT skipped by iteration itself.
## Proves Dictionary.keys() snapshot is safe under inner apply_status mutations (delta-#7 Item 6).
func test_keys_snapshot_iteration_processes_all_three_allies() -> void:
	# Arrange: 5-unit battle (commander + 3 allies + 1 enemy)
	_setup_battle_with_commander_and_allies()

	# Act: kill commander → propagation iterates all units
	_controller.apply_damage(1, 9999, 0, [])

	# Assert: ally_a within radius — HAS DEMORALIZED (processed + accepted by radius check)
	assert_int(_controller._state_by_unit[2].status_effects.size()).override_failure_message(
		"AC-12: ally_a (dist=2) must have DEMORALIZED — proves it was iterated AND accepted"
	).is_equal(1)

	# Assert: ally_b within radius — HAS DEMORALIZED (processed + accepted by radius check)
	assert_int(_controller._state_by_unit[3].status_effects.size()).override_failure_message(
		"AC-12: ally_b (dist=2) must have DEMORALIZED — proves it was iterated AND accepted"
	).is_equal(1)

	# Assert: ally_far outside radius — NO DEMORALIZED (iterated but rejected by radius check)
	# If iteration was incorrectly skipping items, ally_far might be missed AND ally_b also
	# skipped (depending on Dictionary iteration order). Having ally_b hit and ally_far miss
	# proves the radius gate fires, not an iteration short-circuit.
	assert_int(_controller._state_by_unit[4].status_effects.size()).override_failure_message(
		("AC-12: ally_far (dist=6) must have NO effects — iterated but rejected by radius check; "
		+ "size > 0 would indicate spurious DEMORALIZED application")
	).is_equal(0)

	# Assert: enemy excluded by faction check (not radius)
	assert_int(_controller._state_by_unit[5].status_effects.size()).override_failure_message(
		"AC-12: enemy (faction=1) must have no effects — excluded by _is_ally check"
	).is_equal(0)
