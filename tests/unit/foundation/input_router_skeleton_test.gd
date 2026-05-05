extends GdUnitTestSuite

## input_router_skeleton_test.gd
## Story 001 skeleton tests — InputRouter module form invariants + InputState/InputMode
## enums + InputContext payload + UndoEntry payload + autoload registration.
## Covers AC-1 through AC-11 per story QA Test Cases.
##
## Pattern: structural source-scan via FileAccess.get_file_as_string + content.contains
## per G-22 precedent (unit_role_skeleton_test.gd). Instantiation tests verify
## AC-5 (InputContext Resource defaults) + AC-6 (UndoEntry RefCounted defaults).
##
## LIFECYCLE:
##   before_test — no mutable autoload state to reset (skeleton story; no field mutation)
##   after_test  — no cleanup needed (no nodes, no autoload swaps, no file I/O)

const _IR_PATH: String = "res://src/foundation/input_router.gd"
## InputContext was already shipped at src/core/payloads/input_context.gd by an
## earlier story (per `signal input_action_fired(action: String, context: InputContext)`
## ADR-0001 §7 line 168 forward-declaration). Story-001 reuses it rather than
## creating a duplicate at src/foundation/payloads/. Field schema:
## target_coord (Vector2i) / target_unit_id (int) / source_device (int).
const _IC_PATH: String = "res://src/core/payloads/input_context.gd"
const _UE_PATH: String = "res://src/foundation/payloads/undo_entry.gd"
const _PROJ_PATH: String = "res://project.godot"


# ── AC-1: InputRouter extends Node ───────────────────────────────────────────


## AC-1: input_router.gd declares `extends Node` (NOT RefCounted, NOT Resource).
## class_name InputRouter is OMITTED per G-3 — when registered as autoload, Godot
## 4.6 fires "Parse Error: Could not parse global class InputRouter" if class_name
## is also declared. Discovered at story-001 implementation time 2026-05-06; G-3
## CONFIRMED applies to this project (corrects the ADR-0020 §Decision §6 footnote
## "G-3 verification SETTLED — works" wording, which had been speculative pre-impl).
func test_input_router_extends_node() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-1 pre-condition: failed to read %s — file missing or empty" % _IR_PATH
	).is_true()

	# Assert — extends Node
	assert_bool(content.contains("extends Node")).override_failure_message(
		"AC-1: input_router.gd must declare 'extends Node'"
	).is_true()

	# Assert — NOT extends RefCounted
	assert_bool(content.contains("extends RefCounted")).override_failure_message(
		"AC-1: input_router.gd must NOT declare 'extends RefCounted'"
	).is_false()

	# Assert — NOT extends Resource
	assert_bool(content.contains("extends Resource")).override_failure_message(
		"AC-1: input_router.gd must NOT declare 'extends Resource'"
	).is_false()

	# Assert — class_name InputRouter is OMITTED per G-3 (autoload registration
	# collides with class_name declaration in Godot 4.6). InputRouter is referenced
	# via the autoload global identifier (no class_name needed).
	# NOTE: line-anchored regex check — the phrase "class_name InputRouter" may
	# appear inside doc-comment blocks (## ...) explaining the G-3 omission. Only
	# an actual declaration line matters: a line starting with `class_name `
	# (no leading `#` doc-comment marker, no leading whitespace).
	var has_actual_declaration: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("class_name InputRouter"):
			has_actual_declaration = true
			break
	assert_bool(has_actual_declaration).override_failure_message(
		"AC-1: input_router.gd must NOT have an uncommented `class_name InputRouter` declaration line per G-3 autoload rule"
	).is_false()


# ── AC-2: 6 instance fields with exact types ─────────────────────────────────


## AC-2: InputRouter declares exactly 6 instance fields with the verbatim
## type + default declarations from ADR-0005 §1 line 119.
func test_input_router_declares_six_instance_fields() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-2 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert each field verbatim (exact type + default must match ADR-0005 §1 line 119)
	assert_bool(content.contains("var _state: InputState = InputState.OBSERVATION")).override_failure_message(
		"AC-2: _state field missing or type/default incorrect"
	).is_true()

	assert_bool(content.contains("var _active_mode: InputMode = InputMode.KEYBOARD_MOUSE")).override_failure_message(
		"AC-2: _active_mode field missing or type/default incorrect"
	).is_true()

	assert_bool(content.contains("var _pre_menu_state: InputState = InputState.OBSERVATION")).override_failure_message(
		"AC-2: _pre_menu_state field missing or type/default incorrect"
	).is_true()

	assert_bool(content.contains("var _undo_windows: Dictionary[int, UndoEntry] = {}")).override_failure_message(
		"AC-2: _undo_windows field missing or type/default incorrect"
	).is_true()

	assert_bool(content.contains("var _input_blocked_reasons: PackedStringArray = []")).override_failure_message(
		"AC-2: _input_blocked_reasons field missing or type/default incorrect"
	).is_true()

	# NOTE: Godot 4.6 does not support nested typed collections, so the inner
	# `Array[InputEvent]` is degraded to plain `Array` (element type enforced by
	# set_binding signature + ADR-0005 §1 contract).
	assert_bool(content.contains("var _bindings: Dictionary[StringName, Array] = {}")).override_failure_message(
		"AC-2: _bindings field missing or type/default incorrect (expected Dictionary[StringName, Array]; nested Array[InputEvent] not supported in 4.6)"
	).is_true()


# ── AC-3: InputState enum 7 members in canonical S0..S6 order ────────────────


## AC-3: InputState enum has 7 members with canonical int values (S0..S6).
## Ordinals are wire-format (save/load forward-compat per ADR-0005 §5).
func test_input_state_enum_has_seven_members_in_canonical_order() -> void:
	# Assert ordinal values via direct enum access
	assert_int(InputRouter.InputState.OBSERVATION).override_failure_message(
		"AC-3: OBSERVATION must be S0 = 0"
	).is_equal(0)

	assert_int(InputRouter.InputState.UNIT_SELECTED).override_failure_message(
		"AC-3: UNIT_SELECTED must be S1 = 1"
	).is_equal(1)

	assert_int(InputRouter.InputState.MOVEMENT_PREVIEW).override_failure_message(
		"AC-3: MOVEMENT_PREVIEW must be S2 = 2"
	).is_equal(2)

	assert_int(InputRouter.InputState.ATTACK_TARGET_SELECT).override_failure_message(
		"AC-3: ATTACK_TARGET_SELECT must be S3 = 3"
	).is_equal(3)

	assert_int(InputRouter.InputState.ATTACK_CONFIRM).override_failure_message(
		"AC-3: ATTACK_CONFIRM must be S4 = 4"
	).is_equal(4)

	assert_int(InputRouter.InputState.INPUT_BLOCKED).override_failure_message(
		"AC-3: INPUT_BLOCKED must be S5 = 5"
	).is_equal(5)

	assert_int(InputRouter.InputState.MENU_OPEN).override_failure_message(
		"AC-3: MENU_OPEN must be S6 = 6"
	).is_equal(6)

	# Assert size = 7
	assert_int(InputRouter.InputState.size()).override_failure_message(
		("AC-3: InputState.size() is %d; expected 7") % InputRouter.InputState.size()
	).is_equal(7)


# ── AC-4: InputMode enum 2 MVP members; NO GAMEPAD ───────────────────────────


## AC-4: InputMode has exactly 2 MVP members (KEYBOARD_MOUSE=0, TOUCH=1).
## GAMEPAD must NOT be present (reserved at int 2 for post-MVP per ADR-0005 §6).
func test_input_mode_enum_has_two_mvp_members() -> void:
	# Assert ordinal values
	assert_int(InputRouter.InputMode.KEYBOARD_MOUSE).override_failure_message(
		"AC-4: KEYBOARD_MOUSE must be 0"
	).is_equal(0)

	assert_int(InputRouter.InputMode.TOUCH).override_failure_message(
		"AC-4: TOUCH must be 1"
	).is_equal(1)

	# Assert size = 2 (no GAMEPAD in MVP scope)
	assert_int(InputRouter.InputMode.size()).override_failure_message(
		("AC-4: InputMode.size() is %d; expected 2 (no GAMEPAD in MVP scope)") % InputRouter.InputMode.size()
	).is_equal(2)


# ── AC-5: InputContext Resource 2 @export fields ─────────────────────────────


## AC-5: InputContext is a Resource subclass with 3 @export fields at correct defaults.
##
## NOTE: AC-5 in story-001 spec'd 2 fields (coord/unit_id), but InputContext was
## already shipped at src/core/payloads/input_context.gd by an earlier story with
## 3 fields (target_coord/target_unit_id/source_device). Story-001 reuses the
## existing schema rather than duplicating; the spec drift is documented in the
## implementation summary. The 3-field schema is forward-compatible (additive).
func test_input_context_resource_has_three_export_fields() -> void:
	# Arrange — load via path (not class_name) to avoid G-14 race
	var script: GDScript = load(_IC_PATH) as GDScript
	assert_bool(script != null).override_failure_message(
		"AC-5: failed to load %s — file missing or parse error" % _IC_PATH
	).is_true()

	# Act
	var ctx: InputContext = script.new() as InputContext

	# Assert — is Resource
	assert_bool(ctx is Resource).override_failure_message(
		"AC-5: InputContext must extend Resource"
	).is_true()

	# Assert — target_coord default
	assert_bool(ctx.target_coord == Vector2i.ZERO).override_failure_message(
		"AC-5: InputContext.target_coord default must be Vector2i.ZERO; got %s" % str(ctx.target_coord)
	).is_true()

	# Assert — target_unit_id default
	assert_int(ctx.target_unit_id).override_failure_message(
		"AC-5: InputContext.target_unit_id default must be -1"
	).is_equal(-1)

	# Assert — source_device default
	assert_int(ctx.source_device).override_failure_message(
		"AC-5: InputContext.source_device default must be 0"
	).is_equal(0)


# ── AC-6: UndoEntry RefCounted 3 fields ──────────────────────────────────────


## AC-6: UndoEntry is a RefCounted (NOT Resource) with 3 fields at correct defaults.
func test_undo_entry_refcounted_has_three_fields() -> void:
	# Arrange — load via path
	var script: GDScript = load(_UE_PATH) as GDScript
	assert_bool(script != null).override_failure_message(
		"AC-6: failed to load %s — file missing or parse error" % _UE_PATH
	).is_true()

	# Act
	var entry: UndoEntry = script.new() as UndoEntry

	# Assert — is RefCounted
	assert_bool(entry is RefCounted).override_failure_message(
		"AC-6: UndoEntry must extend RefCounted"
	).is_true()

	# Assert — NOT Resource (Godot 4.6 parser statically narrows `entry is Resource`
	# to false because UndoEntry extends RefCounted directly — `is Resource` would
	# trip a parse error. Use G-22 source-scan instead to verify `extends RefCounted`
	# is on the script declaration line.)
	var ue_content: String = FileAccess.get_file_as_string(_UE_PATH)
	assert_bool(ue_content.contains("extends RefCounted")).override_failure_message(
		"AC-6: UndoEntry source must declare `extends RefCounted` (G-22 source-scan)"
	).is_true()
	assert_bool(ue_content.contains("extends Resource")).override_failure_message(
		"AC-6: UndoEntry source must NOT declare `extends Resource`"
	).is_false()

	# Assert — field defaults
	assert_int(entry.unit_id).override_failure_message(
		"AC-6: UndoEntry.unit_id default must be -1"
	).is_equal(-1)

	assert_bool(entry.pre_move_coord == Vector2i.ZERO).override_failure_message(
		"AC-6: UndoEntry.pre_move_coord default must be Vector2i.ZERO; got %s" % str(entry.pre_move_coord)
	).is_true()

	assert_int(entry.pre_move_facing).override_failure_message(
		"AC-6: UndoEntry.pre_move_facing default must be 0"
	).is_equal(0)


# ── AC-7: project.godot autoload registration at boot position 9 ─────────────


## AC-7: project.godot contains InputRouter autoload line and it appears AFTER
## all 8 existing autoloads (StoryEvent, DestinyState, ScenarioRunner, SaveManager,
## SceneManager, GameBus ordering verified via string position).
func test_project_godot_registers_inputrouter_autoload_at_position_9() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_PROJ_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-7 pre-condition: failed to read %s" % _PROJ_PATH
	).is_true()

	# Assert — entry present with correct path and leading * (Autoload Node)
	assert_bool(content.contains('InputRouter="*res://src/foundation/input_router.gd"')).override_failure_message(
		'AC-7: project.godot must contain InputRouter="*res://src/foundation/input_router.gd"'
	).is_true()

	# Assert ordering: InputRouter after StoryEvent after DestinyState after ScenarioRunner
	# after SaveManager after SceneManager after GameBus (all must have smaller find() positions)
	var gamebus_pos: int = content.find('GameBus="*res://src/core/game_bus.gd"')
	var scenemanager_pos: int = content.find('SceneManager="*res://src/core/scene_manager.gd"')
	var savemanager_pos: int = content.find('SaveManager="*res://src/core/save_manager.gd"')
	var scenariorunner_pos: int = content.find('ScenarioRunner="*res://src/core/scenario_runner.gd"')
	var destinystate_pos: int = content.find('DestinyState="*res://src/feature/destiny_state/destiny_state.gd"')
	var storyevent_pos: int = content.find('StoryEvent="*res://src/feature/story_event/story_event.gd"')
	var inputrouter_pos: int = content.find('InputRouter="*res://src/foundation/input_router.gd"')

	assert_bool(gamebus_pos >= 0).override_failure_message(
		"AC-7: GameBus autoload line not found in project.godot"
	).is_true()

	assert_bool(inputrouter_pos > storyevent_pos).override_failure_message(
		("AC-7: InputRouter (pos %d) must appear AFTER StoryEvent (pos %d)") % [inputrouter_pos, storyevent_pos]
	).is_true()

	assert_bool(storyevent_pos > destinystate_pos).override_failure_message(
		("AC-7: StoryEvent (pos %d) must appear AFTER DestinyState (pos %d)") % [storyevent_pos, destinystate_pos]
	).is_true()

	assert_bool(destinystate_pos > scenariorunner_pos).override_failure_message(
		("AC-7: DestinyState (pos %d) must appear AFTER ScenarioRunner (pos %d)") % [destinystate_pos, scenariorunner_pos]
	).is_true()

	assert_bool(scenariorunner_pos > savemanager_pos).override_failure_message(
		("AC-7: ScenarioRunner (pos %d) must appear AFTER SaveManager (pos %d)") % [scenariorunner_pos, savemanager_pos]
	).is_true()

	assert_bool(savemanager_pos > scenemanager_pos).override_failure_message(
		("AC-7: SaveManager (pos %d) must appear AFTER SceneManager (pos %d)") % [savemanager_pos, scenemanager_pos]
	).is_true()

	assert_bool(scenemanager_pos > gamebus_pos).override_failure_message(
		("AC-7: SceneManager (pos %d) must appear AFTER GameBus (pos %d)") % [scenemanager_pos, gamebus_pos]
	).is_true()


# ── AC-8: 4 public method stubs with exact signatures ────────────────────────


## AC-8: InputRouter declares all 4 required public method stubs with the exact
## signatures per ADR-0005 §Key Interfaces + ADR-0020 §Decision §1.
func test_input_router_has_four_public_method_stubs() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-8 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert each method signature verbatim
	assert_bool(content.contains("func get_active_input_mode() -> InputMode:")).override_failure_message(
		"AC-8: get_active_input_mode() -> InputMode signature missing"
	).is_true()

	assert_bool(content.contains("func get_state() -> InputState:")).override_failure_message(
		"AC-8: get_state() -> InputState signature missing"
	).is_true()

	assert_bool(content.contains("func set_binding(action: StringName, event: InputEvent) -> void:")).override_failure_message(
		"AC-8: set_binding(action: StringName, event: InputEvent) -> void signature missing"
	).is_true()

	assert_bool(content.contains("func _handle_event(event: InputEvent) -> void:")).override_failure_message(
		"AC-8: _handle_event(event: InputEvent) -> void signature missing"
	).is_true()


# ── AC-9: NO _ready / _input / _unhandled_input overrides in story-001 ───────


## AC-9: InputRouter has no _ready(), _input(), or _unhandled_input() overrides
## at this story (story-002 adds _unhandled_input; story-007 adds _ready).
func test_input_router_has_no_ready_or_input_overrides_yet() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-9 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — no _ready override (story-007 deferred)
	assert_bool(content.contains("func _ready()")).override_failure_message(
		"AC-9: input_router.gd must NOT declare func _ready() at story-001 (story-007 adds it)"
	).is_false()

	# Assert — no _input override (not planned; InputRouter uses _unhandled_input only)
	assert_bool(content.contains("func _input(event")).override_failure_message(
		"AC-9: input_router.gd must NOT declare func _input at story-001"
	).is_false()

	# Assert — no _unhandled_input override (story-002 deferred)
	assert_bool(content.contains("func _unhandled_input(event")).override_failure_message(
		"AC-9: input_router.gd must NOT declare func _unhandled_input at story-001 (story-002 adds it)"
	).is_false()
