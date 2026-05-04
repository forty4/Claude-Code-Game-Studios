## BattleScene smoke test — end-to-end mount sequence verification.
##
## Loads the live `scenes/battle/battle_scene.tscn` skeleton, triggers
## `BattleScene._ready()` via add_child, and verifies the 6-step DI-DAG-ordered
## mount sequence completes per ADR-0016 §3 + AC-1..AC-9 of story-001.
##
## Gotchas applied:
##   G-6:  explicit free() at end of test body for Node-typed deps + orphan detection
##   G-7:  Overall Summary count verification needed (headless parse-fail detection)
##   G-14: run `godot --headless --import --path .` after first creation of class_name BattleScene
##   G-15: before_test (NOT before_each) — GdUnit4 v6.1.2 only fires before_test()
##
## Pre-condition: HeroDatabase static state pre-seeded with 4 mock heroes
## (jangbi/joun/enemy_a/enemy_b) per ADR-0016 IN-12 — short-circuits the
## headless-mode `_load_heroes()` file-read path that would otherwise return
## empty, leaving HeroDatabase._heroes empty + crashing HPStatusController.
##
## ADR refs: ADR-0016 §1-§7 (NEW pattern: scene-root-as-orchestrator).

extends GdUnitTestSuite

const BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const BATTLE_SCENE_SOURCE: String = "res://src/feature/battle_scene/battle_scene.gd"

# Mock encounter heroes — match _build_mock_roster_sprint6() in battle_scene.gd
const HERO_JANGBI: StringName = &"jangbi"
const HERO_JOUN: StringName = &"joun"
const HERO_ENEMY_A: StringName = &"enemy_a"
const HERO_ENEMY_B: StringName = &"enemy_b"

const MOCK_HERO_IDS: Array[StringName] = [
	HERO_JANGBI, HERO_JOUN, HERO_ENEMY_A, HERO_ENEMY_B,
]

# AC-9: ×5 permissive gate over the 50ms wall-clock headline target.
const PERF_BUDGET_MS: int = 250


# ─── Lifecycle hooks ──────────────────────────────────────────────────────────

func before_test() -> void:
	# G-15 + ADR-0016 IN-12: pre-seed HeroDatabase before BattleScene._ready()
	# fires get_hero() calls inside the mount sequence (step 3 HPStatusController).
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}
	_seed_hero_database()


func after_test() -> void:
	# G-6 idempotent crash-safety net.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


# ─── Fixture builders ─────────────────────────────────────────────────────────

func _seed_hero_database() -> void:
	# IN-12: inject minimum-viable HeroData into static state + flip
	# `_heroes_loaded = true` so HeroDatabase.get_hero() short-circuits the
	# file-load path that fails in headless mode.
	for hero_id: StringName in MOCK_HERO_IDS:
		var hero: HeroData = HeroData.new()
		hero.hero_id = hero_id
		hero.name_ko = String(hero_id)
		HeroDatabase._heroes[hero_id] = hero
	HeroDatabase._heroes_loaded = true


func _instantiate_battle_scene() -> BattleScene:
	var packed: PackedScene = preload(BATTLE_SCENE_PATH)
	var scene: BattleScene = packed.instantiate() as BattleScene
	return scene


# ─── AC-1 + AC-2: skeleton structure ──────────────────────────────────────────

func test_battle_scene_class_declaration_resolves() -> void:
	# AC-1: src/feature/battle_scene/battle_scene.gd declares class_name BattleScene extends Node2D.
	var scene: BattleScene = _instantiate_battle_scene()

	assert_object(scene).override_failure_message(
		"AC-1: BattleScene must instantiate from %s" % BATTLE_SCENE_PATH
	).is_not_null()
	assert_bool(scene is BattleScene).override_failure_message(
		"AC-1: instantiated root must be a BattleScene"
	).is_true()
	assert_bool(scene is Node2D).override_failure_message(
		"AC-1: BattleScene must extend Node2D (not Node, not CanvasLayer)"
	).is_true()

	scene.free()


func test_battle_scene_tscn_is_three_node_skeleton() -> void:
	# AC-2: .tscn skeleton has EXACTLY 3 nodes — BattleScene root + GridLayer + HUDLayer.
	var content: String = FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	assert_str(content).override_failure_message(
		"AC-2: %s must exist and be readable" % BATTLE_SCENE_PATH
	).is_not_empty()

	# Count [node name= declarations — each is one node entry in the .tscn.
	var node_decl_count: int = content.count("[node name=")
	assert_int(node_decl_count).override_failure_message(
		(
			"AC-2: battle_scene.tscn must declare EXACTLY 3 nodes "
			+ "(BattleScene + GridLayer + HUDLayer); found %d"
		) % node_decl_count
	).is_equal(3)

	# Verify the 3 expected name+type pairs.
	assert_bool(
		content.contains('[node name="BattleScene" type="Node2D"]')
	).override_failure_message("AC-2: BattleScene root Node2D missing").is_true()
	assert_bool(
		content.contains('[node name="GridLayer" type="Node2D" parent="."]')
	).override_failure_message("AC-2: GridLayer Node2D child missing").is_true()
	assert_bool(
		content.contains('[node name="HUDLayer" type="CanvasLayer" parent="."]')
	).override_failure_message("AC-2: HUDLayer CanvasLayer child missing").is_true()
	assert_bool(content.contains("layer = 1")).override_failure_message(
		"AC-2: HUDLayer must have layer = 1 set"
	).is_true()


# ─── AC-3 + AC-4 + AC-8: mount sequence ───────────────────────────────────────

func test_battle_scene_ready_mounts_six_children() -> void:
	# AC-3 (implicit via AC-4) + AC-4 + AC-8: _ready() runs 6-step mount sequence;
	# all 6 children resolvable via get_node(). 0 errors / 0 orphans confirmed
	# by GdUnit4 runner's automatic orphan detection.
	var scene: BattleScene = _instantiate_battle_scene()
	add_child(scene)
	await get_tree().process_frame

	# STEP 1: MapGrid (ADR-0004)
	assert_object(scene.get_node_or_null("MapGrid")).override_failure_message(
		"AC-4 STEP 1: MapGrid must be mounted as direct child of BattleScene root"
	).is_not_null()

	# STEP 2: BattleCamera (ADR-0013)
	assert_object(scene.get_node_or_null("BattleCamera")).override_failure_message(
		"AC-4 STEP 2: BattleCamera must be mounted"
	).is_not_null()

	# STEP 3: HPStatusController (ADR-0010)
	assert_object(scene.get_node_or_null("HPStatusController")).override_failure_message(
		"AC-4 STEP 3: HPStatusController must be mounted"
	).is_not_null()

	# STEP 4: TurnOrderRunner (ADR-0011)
	assert_object(scene.get_node_or_null("TurnOrderRunner")).override_failure_message(
		"AC-4 STEP 4: TurnOrderRunner must be mounted"
	).is_not_null()

	# STEP 5: GridBattleController (ADR-0014)
	assert_object(scene.get_node_or_null("GridBattleController")).override_failure_message(
		"AC-4 STEP 5: GridBattleController must be mounted"
	).is_not_null()

	# STEP 6: BattleHUD (ADR-0015) — child of HUDLayer (CanvasLayer)
	assert_object(scene.get_node_or_null("HUDLayer/BattleHUD")).override_failure_message(
		"AC-4 STEP 6: BattleHUD must be mounted under HUDLayer"
	).is_not_null()

	# Pre-existing skeleton nodes still present (from .tscn).
	assert_object(scene.get_node_or_null("GridLayer")).override_failure_message(
		"AC-2: GridLayer (skeleton) must remain present after mount"
	).is_not_null()
	assert_object(scene.get_node_or_null("HUDLayer")).override_failure_message(
		"AC-2: HUDLayer (skeleton) must remain present after mount"
	).is_not_null()

	scene.free()


# ─── AC-5: mock encoder marker presence ───────────────────────────────────────

func test_battle_scene_source_contains_sprint6_mock_markers() -> void:
	# AC-5: 4 explicit comment markers must exist in source so story-003 lint
	# can mechanically detect their presence (will flip to "must NOT exist" at
	# ADR-0017 acceptance).
	var content: String = FileAccess.get_file_as_string(BATTLE_SCENE_SOURCE)
	assert_str(content).override_failure_message(
		"AC-5: %s must exist and be readable" % BATTLE_SCENE_SOURCE
	).is_not_empty()

	var required_markers: Array[String] = [
		"# === SPRINT-6 MOCK ENCOUNTER ===",
		"# === END MOCK ===",
		"# === SPRINT-6 MOCK ENCOUNTER HELPERS ===",
		"# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===",
	]
	for marker: String in required_markers:
		assert_bool(content.contains(marker)).override_failure_message(
			"AC-5: battle_scene.gd must contain marker: %s" % marker
		).is_true()


# ─── AC-6: auto-tree-free delegation ──────────────────────────────────────────

func test_battle_scene_free_does_not_leak() -> void:
	# AC-6: NO _exit_tree() body on BattleScene root. Reverse-DFS auto-tree-free
	# fires _exit_tree() on each of the 6 mounted children in reverse-add order;
	# each child's R-N _exit_tree() handles its own GameBus disconnects.
	# Result: scene.free() returns cleanly with no leaked subscriptions.
	#
	# G-6 + GdUnit4 orphan detection: the runner automatically reports orphans
	# between test body exit and after_test; if any child's _exit_tree() leaks,
	# the runner will fail the test with an "orphan detected" message.
	var scene: BattleScene = _instantiate_battle_scene()
	add_child(scene)
	await get_tree().process_frame

	assert_bool(is_instance_valid(scene)).override_failure_message(
		"AC-6: scene must be valid before free()"
	).is_true()

	scene.free()

	assert_bool(is_instance_valid(scene)).override_failure_message(
		"AC-6: scene must be invalid (cleanly freed) after explicit free()"
	).is_false()


# ─── AC-7: non-emitter source discipline (manual grep gate this story) ────────

func test_battle_scene_source_has_no_gamebus_subscriptions() -> void:
	# AC-7: zero GameBus.*.connect / GameBus.*.emit substrings in source.
	# Story-003 formalizes this as CI lint; this story uses test-time grep gate.
	var content: String = FileAccess.get_file_as_string(BATTLE_SCENE_SOURCE)
	var lines: PackedStringArray = content.split("\n")

	var violations: Array[String] = []
	for line: String in lines:
		if line.contains("GameBus.") and (line.contains(".connect(") or line.contains(".emit(")):
			violations.append(line.strip_edges())

	assert_int(violations.size()).override_failure_message(
		"AC-7: battle_scene.gd must have zero GameBus.*.connect/emit; found: %s" % str(violations)
	).is_equal(0)


# ─── AC-9: performance gate ───────────────────────────────────────────────────

func test_battle_scene_ready_completes_under_perf_budget() -> void:
	# AC-9: _ready() <50ms wall-clock target on Snapdragon 7-gen reference;
	# permissive ×5 gate at 250ms for CI runner platforms (matches camera /
	# grid-battle-controller perf-gate precedent).
	var scene: BattleScene = _instantiate_battle_scene()

	var start_ms: int = Time.get_ticks_msec()
	add_child(scene)  # _ready() fires synchronously inside add_child()
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	assert_int(elapsed_ms).override_failure_message(
		(
			"AC-9: BattleScene._ready() took %d ms; permissive gate %d ms "
			+ "(headline target <50ms on reference hardware)"
		) % [elapsed_ms, PERF_BUDGET_MS]
	).is_less_equal(PERF_BUDGET_MS)

	scene.free()
