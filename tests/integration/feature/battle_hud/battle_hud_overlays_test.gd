## BattleHUD UI-GB-06 + UI-GB-09 + UI-GB-12/13/14 integration test (sprint-10 S10-02 / story-007).
##
## Covers AC-1..AC-7 + AC-9 + non-emitter discipline:
##   AC-1: UI-GB-06 + UI-GB-09 mount as HUD-root children at _ready();
##         UI-GB-12/13/14 cross-tree resolution with graceful empty-dict fallback
##         when test fixture lacks BattleScene parent.
##   AC-2: show_tile_info(coord) populates 4 Labels via _map_grid + TerrainEffect.
##   AC-3: show_tile_info(Vector2i(-1,-1)) dismisses panel; idempotent dismiss.
##   AC-4: _on_battle_outcome_resolved renders UI-GB-09 with OUTCOME ONLY —
##         Pillar 2 lock audit walks UI-GB-09 child Label tree to assert NO
##         per-condition fate counter from fate_data dict appears in any Label.text.
##   AC-6: _on_formation_bonuses_updated visibility toggle for UI-GB-13/14
##         (when GridLayer present). When GridLayer absent → no crash.
##   AC-7: _on_unit_selected_changed extension for UI-GB-12 Strategist render;
##         Commander explicitly excluded per CR-2 v5.0.
##   AC-9: Pillar 2 token-absence source-grep — `hidden_fate_condition_progressed`
##         literal MUST NOT appear in battle_hud.gd source.
##
## AC-5 (≤200ms one-shot results render perf gate) + AC-8 (per-frame zoom-poll
## ≤0.05ms p99) + AC-10 (UI-GB-13 dashed border visual) deferred to evidence doc
## per Story Type UI + Integration + Performance.
##
## ADR: ADR-0015 §4 + §5 + §8 Pillar 2 lock (Accepted 2026-05-03)
## TR: TR-battle-hud-005 (UI-GB-06/09/12/13/14 partial), TR-battle-hud-006
##     (show_tile_info), TR-battle-hud-015 (cross-tree NodePath + grid-layer overlay).
##
## Gotchas applied (per `.claude/rules/godot-4x-gotchas.md`):
##   G-3: this test file declares NO class_name (test files never do)
##   G-15: before_test (NOT before_each) for HeroDatabase + TerrainEffect static reset
##   G-6: explicit free in test bodies for Node-typed deps
##   G-23: no is_not_equal_approx; is_less for float budget gates
##   G-7: Overall Summary count verified post-run
##   G-22: source-scan structural pattern (TR-007 non-emitter + Pillar 2 token absence)
##   G-25: Dictionary[StringName, Node2D] depth-1 typed dict — no nested typed collection
##   G-28: explicit _free_node_deps cleanup; no bulk-disconnect-all
extends GdUnitTestSuite

const BattleHUDScript: GDScript = preload("res://src/feature/battle_hud/battle_hud.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const GridBattleControllerStubScript: GDScript = preload("res://tests/helpers/grid_battle_controller_stub.gd")
const InputRouterStubScript: GDScript = preload("res://tests/helpers/input_router_stub.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")

const TEST_STRATEGIST_UNIT_ID: int = 42
const TEST_COMMANDER_UNIT_ID: int = 77
const TEST_TILE_COORD: Vector2i = Vector2i(3, 4)


func before_test() -> void:
	# G-15: reset HeroDatabase + TerrainEffect static state per file-header obligation.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}
	TerrainEffect.reset_for_tests()


func after_test() -> void:
	# Idempotent crash-safety net per G-6.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}
	TerrainEffect.reset_for_tests()


# ─── Fixture builders ────────────────────────────────────────────────────────


func _make_hud_with_stubs() -> Dictionary:
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	var grid_controller: GridBattleControllerStub = GridBattleControllerStubScript.new()
	var input_router: InputRouterStub = InputRouterStubScript.new()
	var map_grid: MapGridStub = MapGridStubScript.new()
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()

	var hud: BattleHUD = BattleHUDScript.new()
	hud.setup(camera, hp_controller, turn_runner, grid_controller, input_router,
			map_grid, terrain_effect, unit_role, hero_db)

	return {
		"hud": hud, "camera": camera, "hp_controller": hp_controller,
		"turn_runner": turn_runner, "grid_controller": grid_controller,
		"input_router": input_router, "map_grid": map_grid,
		"terrain_effect": terrain_effect, "unit_role": unit_role, "hero_db": hero_db,
	}


func _free_node_deps(bag: Dictionary) -> void:
	for key: String in ["camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


# ─── AC-1: UI-GB-06 + UI-GB-09 mount; UI-GB-12/13/14 graceful fallback ────────


## AC-1: UI-GB-06 + UI-GB-09 instantiated as HUD-root children + start hidden.
func test_ui_gb_06_and_09_mount_at_ready_as_hud_children() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var tile_panel: Control = hud._ui_elements.get(&"UI-GB-06")
	assert_object(tile_panel).override_failure_message(
		"AC-1: _ui_elements[&'UI-GB-06'] must be non-null after _ready"
	).is_not_null()
	assert_object(tile_panel.get_parent()).is_equal(hud)
	assert_bool(tile_panel.visible).override_failure_message(
		"AC-1: UI-GB-06 must start hidden"
	).is_false()

	var results_panel: Control = hud._ui_elements.get(&"UI-GB-09")
	assert_object(results_panel).override_failure_message(
		"AC-1: _ui_elements[&'UI-GB-09'] must be non-null after _ready"
	).is_not_null()
	assert_object(results_panel.get_parent()).is_equal(hud)
	assert_bool(results_panel.visible).override_failure_message(
		"AC-1: UI-GB-09 must start hidden"
	).is_false()

	hud.free()
	_free_node_deps(bag)


## AC-1 graceful: when test fixture lacks BattleScene/GridLayer parent,
## _grid_layer_overlays must be empty (no crash; warning logged via push_warning).
func test_grid_layer_overlays_empty_when_no_grid_layer_parent() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)  # HUD is added directly to test root — no BattleScene/GridLayer above it.

	# Cross-tree resolution should fail gracefully — empty dict, no crash.
	assert_int(hud._grid_layer_overlays.size()).override_failure_message(
		"AC-1: when grid_layer_path fails to resolve, _grid_layer_overlays must be empty"
	).is_equal(0)

	hud.free()
	_free_node_deps(bag)


# ─── AC-2: show_tile_info populates UI-GB-06 from MapGrid + TerrainEffect ─────


## AC-2: show_tile_info(coord) populates 4 Labels with terrain + elevation +
## defense_bonus + evasion_bonus from MapGrid stub + TerrainEffect static helper.
## MapGridStub default get_tile returns a non-null MapTileData with default
## terrain_type=0 + elevation=0 (no set_tile_for_test injection needed — the
## stub's default suffices to validate the format-string + visibility contract).
func test_show_tile_info_populates_ui_gb_06_with_tile_data() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	hud.show_tile_info(TEST_TILE_COORD)

	var panel: Control = hud._ui_elements.get(&"UI-GB-06")
	assert_bool(panel.visible).override_failure_message(
		"AC-2: show_tile_info(valid coord) must set UI-GB-06.visible = true"
	).is_true()

	# 4 Labels populated with non-empty text.
	var vbox: VBoxContainer = panel.get_node_or_null(^"VBoxContainer") as VBoxContainer
	assert_object(vbox).is_not_null()
	for label_name: String in ["TerrainLabel", "ElevationLabel", "DefenseLabel", "EvasionLabel"]:
		var lbl: Label = vbox.get_node_or_null(NodePath(label_name)) as Label
		assert_object(lbl).override_failure_message(
			"AC-2: %s missing from UI-GB-06 VBoxContainer" % label_name
		).is_not_null()
		assert_str(lbl.text).override_failure_message(
			"AC-2: %s must have non-empty text after show_tile_info" % label_name
		).is_not_empty()

	hud.free()
	_free_node_deps(bag)


## AC-2 edge: when _map_grid DI is null, panel hides gracefully (no crash) +
## warning logged. Direct null injection exercises the handler's early-return
## guard without requiring stub API extension.
func test_show_tile_info_handles_null_map_grid_gracefully() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)
	# Inject null _map_grid post-_ready to exercise the null-guard path.
	hud._map_grid = null

	hud.show_tile_info(Vector2i(0, 0))

	var panel: Control = hud._ui_elements.get(&"UI-GB-06")
	assert_bool(panel.visible).override_failure_message(
		"AC-2 edge: show_tile_info with null _map_grid must keep UI-GB-06 hidden"
	).is_false()

	hud.free()
	_free_node_deps(bag)


## AC-2 edge: when _map_grid.get_tile(coord) returns null on a valid coord
## (e.g., out-of-bounds tile or sparse map), show_tile_info must hide the
## panel + push_warning. Distinct from null-_map_grid path: this exercises
## the second guard at battle_hud.show_tile_info source line ~909
## (`if tile == null: panel.visible = false; return`).
func test_show_tile_info_handles_null_get_tile_gracefully() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var map_grid: MapGridStub = bag["map_grid"]
	add_child(hud)

	# Force MapGridStub.get_tile to return null per story-007 test seam.
	map_grid.set_force_null_get_tile_for_test(true)

	hud.show_tile_info(TEST_TILE_COORD)

	var panel: Control = hud._ui_elements.get(&"UI-GB-06")
	assert_bool(panel.visible).override_failure_message(
		"AC-2 edge: show_tile_info with get_tile returning null must keep UI-GB-06 hidden"
	).is_false()

	hud.free()
	_free_node_deps(bag)


# ─── AC-3: dismiss path ───────────────────────────────────────────────────────


## AC-3: show_tile_info(Vector2i(-1, -1)) dismisses UI-GB-06.
func test_show_tile_info_with_negative_one_dismisses_panel() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Show first using stub default.
	hud.show_tile_info(TEST_TILE_COORD)
	var panel: Control = hud._ui_elements.get(&"UI-GB-06")
	assert_bool(panel.visible).is_true()

	# Dismiss via sentinel.
	hud.show_tile_info(Vector2i(-1, -1))
	assert_bool(panel.visible).override_failure_message(
		"AC-3: show_tile_info(Vector2i(-1,-1)) must hide UI-GB-06"
	).is_false()

	hud.free()
	_free_node_deps(bag)


## AC-3 edge: dismiss when already hidden is a no-op (no crash).
func test_show_tile_info_dismiss_when_already_hidden_is_no_op() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)
	# Panel starts hidden by default.

	hud.show_tile_info(Vector2i(-1, -1))
	# No assertion needed beyond not crashing — verify visible stays false.
	var panel: Control = hud._ui_elements.get(&"UI-GB-06")
	assert_bool(panel.visible).is_false()

	hud.free()
	_free_node_deps(bag)


# ─── AC-4: battle_outcome_resolved renders UI-GB-09 — Pillar 2 lock ───────────


## AC-4: _on_battle_outcome_resolved renders UI-GB-09 outcome label + reads
## ONLY the categorical outcome field. Pillar 2 audit: walk UI-GB-09 child
## Label tree + assert NO Label.text contains the per-condition fate counter
## value from the test payload.
func test_battle_outcome_resolved_renders_ui_gb_09_with_outcome_only_pillar_2_lock() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Pillar 2 sentinel value: a unique number that, if surfaced visually, will
	# show up in some Label's text. Walking the tree post-render must NOT find it.
	var pillar2_sentinel: int = 88765
	var fate_data: Dictionary = {
		"hidden_fate_progress": {"liu_bei_recruitment": pillar2_sentinel},
	}

	hud._on_battle_outcome_resolved(&"VICTORY_ANNIHILATION", fate_data)

	var panel: Control = hud._ui_elements.get(&"UI-GB-09")
	assert_bool(panel.visible).override_failure_message(
		"AC-4: _on_battle_outcome_resolved must set UI-GB-09.visible = true"
	).is_true()

	# Outcome label tr-routes to "hud.outcome.victory". Compare against
	# tr(expected_key) so the assertion is robust to whether a translation
	# file is loaded — without locale resources, tr() returns the key string
	# itself; either way, equality with tr(expected_key) holds when the
	# mapping is correct and fails when the match arm is wrong.
	var vbox: VBoxContainer = panel.get_node_or_null(^"VBoxContainer") as VBoxContainer
	var outcome_label: Label = vbox.get_node_or_null(^"OutcomeLabel") as Label
	assert_str(outcome_label.text).override_failure_message(
		"AC-4: outcome label must tr-route VICTORY_ANNIHILATION to hud.outcome.victory"
	).is_equal(tr(&"hud.outcome.victory"))

	# Pillar 2 audit: walk every descendant Label + assert NONE contain the sentinel.
	var sentinel_str: String = str(pillar2_sentinel)
	_assert_no_label_text_contains(panel, sentinel_str, "AC-4 Pillar 2")

	hud.free()
	_free_node_deps(bag)


## AC-4 parametric: each outcome value tr-routes to its OWN locale key.
## Stronger than is_not_empty() so a wrong-arm match (e.g. the historical
## lowercase &"victory" arms that never matched the uppercase emits and
## silently rendered "hud.outcome.draw" for every battle) is caught.
## G-16: typed Array[Dictionary] for parametric cases.
func test_battle_outcome_resolved_emits_for_each_outcome_value() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var panel: Control = hud._ui_elements.get(&"UI-GB-09")
	var vbox: VBoxContainer = panel.get_node_or_null(^"VBoxContainer") as VBoxContainer
	var outcome_label: Label = vbox.get_node_or_null(^"OutcomeLabel") as Label

	# Session-36: extended past the ANNIHILATION-only set to also cover SURVIVE
	# / ESCORT / REACH_TILE outcomes added by S28 / S30 / S31. Pre-S36 a
	# VICTORY_ESCORT win silently routed to "draw" — coarse mapping fix routes
	# all 4 VICTORY_* → victory and all 3 DEFEAT_* → defeat.
	var cases: Array[Dictionary] = [
		{"outcome": &"VICTORY_ANNIHILATION", "expected_key": &"hud.outcome.victory"},
		{"outcome": &"VICTORY_SURVIVE",      "expected_key": &"hud.outcome.victory"},
		{"outcome": &"VICTORY_ESCORT",       "expected_key": &"hud.outcome.victory"},
		{"outcome": &"VICTORY_REACH_TILE",   "expected_key": &"hud.outcome.victory"},
		{"outcome": &"DEFEAT_ANNIHILATION",  "expected_key": &"hud.outcome.defeat"},
		{"outcome": &"DEFEAT_ESCORT_LOST",   "expected_key": &"hud.outcome.defeat"},
		{"outcome": &"DEFEAT_REACH_FAILED",  "expected_key": &"hud.outcome.defeat"},
		{"outcome": &"TURN_LIMIT_REACHED",   "expected_key": &"hud.outcome.draw"},
	]
	for case: Dictionary in cases:
		var outcome: StringName = case["outcome"] as StringName
		var expected_key: StringName = case["expected_key"] as StringName
		hud._on_battle_outcome_resolved(outcome, {})
		assert_str(outcome_label.text).override_failure_message(
			"AC-4: outcome '%s' must tr-route to '%s' (got '%s')" \
				% [str(outcome), str(expected_key), outcome_label.text]
		).is_equal(tr(expected_key))

	hud.free()
	_free_node_deps(bag)


# ─── AC-6: formation_bonuses_updated visibility toggle ────────────────────────


## AC-6: when GridLayer is absent (test fixture default), the handler runs
## without crashing — graceful no-op.
func test_formation_bonuses_updated_no_op_without_grid_layer() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# _grid_layer_overlays empty per AC-1 graceful fallback.
	assert_int(hud._grid_layer_overlays.size()).is_equal(0)

	# Should not crash.
	hud._on_formation_bonuses_updated({"rally_active": true, "formation_active": true})

	hud.free()
	_free_node_deps(bag)


## AC-6: with GridLayer parent provided, snapshot's rally_active + formation_active
## fields toggle UI-GB-13 + UI-GB-14 visibility.
func test_formation_bonuses_updated_renders_ui_gb_13_14_overlays() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]

	# Provide a fake GridLayer Node2D as sibling so cross-tree path resolves.
	# HUD will be added under a wrapper that has GridLayer as a sibling-of-parent.
	var battle_scene: Node2D = Node2D.new()
	battle_scene.name = "BattleScene"
	var hud_layer: Node = Node.new()
	hud_layer.name = "HUDLayer"
	var grid_layer: Node2D = Node2D.new()
	grid_layer.name = "GridLayer"
	add_child(battle_scene)
	battle_scene.add_child(hud_layer)
	battle_scene.add_child(grid_layer)
	hud_layer.add_child(hud)

	# Cross-tree should now resolve.
	assert_int(hud._grid_layer_overlays.size()).override_failure_message(
		"AC-6: with BattleScene/HUDLayer/BattleHUD + sibling GridLayer, " +
		"_grid_layer_overlays must have 3 entries (UI-GB-12/13/14)"
	).is_equal(3)

	# Activate via snapshot — verify UI-GB-13 + UI-GB-14 become visible.
	hud._on_formation_bonuses_updated({"rally_active": true, "formation_active": true})
	assert_bool(hud._grid_layer_overlays[&"UI-GB-13"].visible).is_true()
	assert_bool(hud._grid_layer_overlays[&"UI-GB-14"].visible).is_true()

	# Deactivate — verify hidden.
	hud._on_formation_bonuses_updated({"rally_active": false, "formation_active": false})
	assert_bool(hud._grid_layer_overlays[&"UI-GB-13"].visible).is_false()
	assert_bool(hud._grid_layer_overlays[&"UI-GB-14"].visible).is_false()

	battle_scene.free()
	_free_node_deps(bag)


# ─── AC-7: UI-GB-12 TacticalRead Strategist gating ────────────────────────────


## AC-7: when Strategist unit is selected, UI-GB-12 visibility is updated by the
## handler (defensive — gated on _unit_role.has_method("get_tactical_read_tiles");
## structural verifier asserts the handler runs without crash).
func test_unit_selected_changed_strategist_runs_ui_gb_12_path_without_crash() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]

	# Fabricate a Strategist BattleUnit + register on stub.
	var strategist_unit: BattleUnit = BattleUnit.new()
	strategist_unit.unit_id = TEST_STRATEGIST_UNIT_ID
	strategist_unit.unit_class = UnitRole.UnitClass.STRATEGIST
	grid_controller.set_test_unit(TEST_STRATEGIST_UNIT_ID, strategist_unit)

	# Set up GridLayer so UI-GB-12 exists.
	var battle_scene: Node2D = Node2D.new()
	battle_scene.name = "BattleScene"
	var hud_layer: Node = Node.new()
	hud_layer.name = "HUDLayer"
	var grid_layer: Node2D = Node2D.new()
	grid_layer.name = "GridLayer"
	add_child(battle_scene)
	battle_scene.add_child(hud_layer)
	battle_scene.add_child(grid_layer)
	hud_layer.add_child(hud)

	# Strategist selection — handler should call _update_tactical_read_overlay
	# without crashing. UI-GB-12 visibility depends on UnitRole.has_method check.
	hud._on_unit_selected_changed(TEST_STRATEGIST_UNIT_ID, 1)

	# UI-GB-12 still exists post-handler call.
	var tr_overlay: Node2D = hud._grid_layer_overlays.get(&"UI-GB-12")
	assert_object(tr_overlay).is_not_null()
	# UnitRoleStub does NOT define get_tactical_read_tiles (UnitRole is @abstract
	# all-static; the stub adds no methods per tests/helpers/unit_role_stub.gd).
	# Per battle_hud._update_tactical_read_overlay: the has_method gate falls to
	# the `else` branch → tr_overlay.visible = false. Asserting the false outcome
	# explicitly converts a trivially-passing structural reachability check into
	# an honest behavioral assertion of the current MVP-deferred state.
	# Story-007 ADVISORY: when UnitRole.get_tactical_read_tiles lands,
	# add an inverse test (visible == true) using a method-providing UnitRole stub.
	assert_bool(tr_overlay.visible).override_failure_message(
		"AC-7 Strategist+method-absent: tr_overlay.visible must be false when " +
		"UnitRole lacks get_tactical_read_tiles (current MVP-deferred state)"
	).is_false()

	battle_scene.free()
	_free_node_deps(bag)


## AC-7 edge: Commander unit must NOT show UI-GB-12 (CR-2 v5.0 — Commander
## passive is passive_rally, not passive_tactical_read).
func test_unit_selected_changed_commander_hides_ui_gb_12() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]

	# Fabricate a Commander BattleUnit.
	var commander_unit: BattleUnit = BattleUnit.new()
	commander_unit.unit_id = TEST_COMMANDER_UNIT_ID
	commander_unit.unit_class = UnitRole.UnitClass.COMMANDER
	grid_controller.set_test_unit(TEST_COMMANDER_UNIT_ID, commander_unit)

	# Set up GridLayer.
	var battle_scene: Node2D = Node2D.new()
	battle_scene.name = "BattleScene"
	var hud_layer: Node = Node.new()
	hud_layer.name = "HUDLayer"
	var grid_layer: Node2D = Node2D.new()
	grid_layer.name = "GridLayer"
	add_child(battle_scene)
	battle_scene.add_child(hud_layer)
	battle_scene.add_child(grid_layer)
	hud_layer.add_child(hud)

	# Commander selection — UI-GB-12 must remain hidden per CR-2.
	hud._on_unit_selected_changed(TEST_COMMANDER_UNIT_ID, 1)

	var tr_overlay: Node2D = hud._grid_layer_overlays.get(&"UI-GB-12")
	assert_object(tr_overlay).is_not_null()
	assert_bool(tr_overlay.visible).override_failure_message(
		"AC-7: Commander unit must NOT show UI-GB-12 (CR-2 v5.0)"
	).is_false()

	battle_scene.free()
	_free_node_deps(bag)


# ─── Non-emitter discipline (TR-007 mirror) + Pillar 2 token absence (AC-9) ───


## TR-battle-hud-007: BattleHUD emits ZERO GameBus signals. Source-grep verifies
## no `GameBus.*.emit` calls in battle_hud.gd. Mirrors story-005/006 patterns;
## story-008 will hoist this into a structural CI lint script.
func test_no_gamebus_emit_calls_in_battle_hud_overlays_paths() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/feature/battle_hud/battle_hud.gd")
	var lines: PackedStringArray = content.split("\n")
	var violations: PackedStringArray = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		if line.strip_edges().begins_with("#"):
			continue
		if line.contains("GameBus.") and line.contains(".emit("):
			violations.append("line %d: %s" % [i + 1, line.strip_edges()])
	assert_int(violations.size()).override_failure_message(
		"TR-battle-hud-007: BattleHUD must not emit GameBus signals. Violations:\n  %s" % "\n  ".join(violations)
	).is_equal(0)


## AC-9: Pillar 2 lock — `hidden_fate_condition_progressed` literal token MUST
## NOT appear in battle_hud.gd source code (zero subscriptions, zero references).
## Story-008 lint will automate this; this test is the structural sentinel until then.
func test_no_hidden_fate_condition_progressed_token_in_battle_hud_source() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/feature/battle_hud/battle_hud.gd")
	var lines: PackedStringArray = content.split("\n")
	var violations: PackedStringArray = []
	for i: int in range(lines.size()):
		var line: String = lines[i]
		# Skip comment lines + the docstring lines mentioning Pillar 2 lock.
		if line.strip_edges().begins_with("#"):
			continue
		if line.contains("hidden_fate_condition_progressed"):
			violations.append("line %d: %s" % [i + 1, line.strip_edges()])
	assert_int(violations.size()).override_failure_message(
		"AC-9 Pillar 2 lock: BattleHUD source MUST NOT reference " +
		"hidden_fate_condition_progressed (zero subs, zero refs). Violations:\n  %s" % "\n  ".join(violations)
	).is_equal(0)


# ─── Helper: recursive Label.text walker for Pillar 2 audit ───────────────────


## Walk every descendant Label of `root` + assert NONE contains `forbidden_substr`.
## Used by AC-4 Pillar 2 audit to verify no fate counter value bleeds into UI.
func _assert_no_label_text_contains(root: Node, forbidden_substr: String, ctx: String) -> void:
	var queue: Array[Node] = [root]
	while queue.size() > 0:
		var node: Node = queue.pop_front()
		if node is Label:
			var lbl: Label = node as Label
			assert_bool(lbl.text.contains(forbidden_substr)).override_failure_message(
				"%s: Label '%s' contains forbidden substr '%s' (Pillar 2 leak)" % [
					ctx, lbl.name, forbidden_substr,
				]
			).is_false()
		for child: Node in node.get_children():
			queue.append(child)
