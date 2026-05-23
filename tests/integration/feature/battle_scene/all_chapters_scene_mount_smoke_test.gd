## all_chapters_scene_mount_smoke_test.gd
##
## Phase F windowed-boot attestation — automated half. G-30 mitigation: each of
## 25 mvp_chapter_NN.tscn must instantiate cleanly under SceneTree + expose a
## ChapterVisuals node with a wired map_resource. Catches:
##
##   1. .tscn parse errors (G-7-style silent skip on the chapter wrapper)
##   2. ExtResource chain broken (script path / map .tres path moved)
##   3. ChapterVisuals.map_resource @export not assigned (chapter wrapper authored
##      without the resource binding — silent black-screen in windowed mode)
##   4. MapResource load failure (downstream of map_grid_test, but this test
##      exercises the .tscn → ExtResource resolution path which map_grid_test bypasses)
##
## NOT covered (G-30 windowed-only gap — manual attestation REQUIRED):
##   - Tween-stall (G-31) — process_mode=DISABLED parents break self.create_tween()
##   - Visual rendering — Polygon2D / Sprite2D / _draw() overlay only in windowed
##   - Input dispatch — engine _unhandled_input → InputRouter → GameBus chain
##   - Object lifetime under teardown — ObjectDB net delta (POLISH-008 pattern)
##   - Full battle-loop end-to-end — natural _begin_round.call_deferred chain
##   - Audio playback — music_id resolution is tested but AudioStream rendering is not
##
## See `.claude/rules/godot-4x-gotchas.md` G-30 for full G-30 framing + recommended
## manual attestation protocol.

extends GdUnitTestSuite


const _CHAPTER_SCENE_PATHS: Array[String] = [
	# Phase A prequel (황건적~신야)
	"res://scenes/battle/mvp_chapter_01.tscn",
	"res://scenes/battle/mvp_chapter_02.tscn",
	"res://scenes/battle/mvp_chapter_03.tscn",
	"res://scenes/battle/mvp_chapter_04.tscn",
	"res://scenes/battle/mvp_chapter_05.tscn",
	# Main campaign (장판~적벽)
	"res://scenes/battle/mvp_chapter_06.tscn",
	"res://scenes/battle/mvp_chapter_07.tscn",
	"res://scenes/battle/mvp_chapter_08.tscn",
	"res://scenes/battle/mvp_chapter_09.tscn",
	"res://scenes/battle/mvp_chapter_10.tscn",
	# Phase B (형주 4군 + 통합)
	"res://scenes/battle/mvp_chapter_11.tscn",
	"res://scenes/battle/mvp_chapter_12.tscn",
	"res://scenes/battle/mvp_chapter_13.tscn",
	"res://scenes/battle/mvp_chapter_14.tscn",
	# Phase C (익주 입성)
	"res://scenes/battle/mvp_chapter_15.tscn",
	"res://scenes/battle/mvp_chapter_16.tscn",
	"res://scenes/battle/mvp_chapter_17.tscn",
	# Phase D (한중·이릉·시그니처 분기 3개)
	"res://scenes/battle/mvp_chapter_18.tscn",
	"res://scenes/battle/mvp_chapter_19.tscn",
	"res://scenes/battle/mvp_chapter_20.tscn",
	"res://scenes/battle/mvp_chapter_21.tscn",
	"res://scenes/battle/mvp_chapter_22.tscn",
	# Phase E (남만·북벌·오장원·영걸전 finale)
	"res://scenes/battle/mvp_chapter_23.tscn",
	"res://scenes/battle/mvp_chapter_24.tscn",
	"res://scenes/battle/mvp_chapter_25.tscn",
]


## G-30 mitigation: each chapter wrapper must load + instantiate without parse
## errors. Verifies the 25-chapter .tscn → ChapterVisuals → MapResource chain
## resolves end-to-end. Failure here = silent black-screen in windowed boot.
func test_all_25_chapter_scenes_instantiate_with_chapter_visuals_root() -> void:
	for path: String in _CHAPTER_SCENE_PATHS:
		# Step 1: PackedScene load via ResourceLoader.
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"Phase F: chapter scene asset missing at %s" % path
		).is_true()
		var packed: PackedScene = ResourceLoader.load(path) as PackedScene
		assert_object(packed).override_failure_message(
			"Phase F: ResourceLoader.load returned null for %s — .tscn parse error?" % path
		).is_not_null()

		# Step 2: Instantiate the scene.
		var scene: Node2D = packed.instantiate() as Node2D
		assert_object(scene).override_failure_message(
			"Phase F: PackedScene.instantiate() failed for %s" % path
		).is_not_null()
		# Auto-free on test end (orphan-detector safe per G-6).
		auto_free(scene)

		# Step 3: Verify root has ChapterVisuals script attached + map_resource wired.
		var script: GDScript = scene.get_script() as GDScript
		assert_object(script).override_failure_message(
			"Phase F: %s root node missing chapter_visuals.gd script attachment" % path
		).is_not_null()
		assert_str(script.resource_path).override_failure_message(
			("Phase F: %s root script must be chapter_visuals.gd "
				+ "(got '%s' — chapter wrapper authored with wrong script?)")
				% [path, script.resource_path]
		).is_equal("res://src/feature/battle_scene/chapter_visuals.gd")

		# Step 4: ChapterVisuals.map_resource must be a non-null MapResource.
		var map_res: Resource = scene.get("map_resource") as Resource
		assert_object(map_res).override_failure_message(
			("Phase F: %s ChapterVisuals.map_resource is null — chapter wrapper "
				+ "authored without ExtResource binding (silent black-screen in windowed mode)")
				% path
		).is_not_null()
		assert_bool(map_res is MapResource).override_failure_message(
			("Phase F: %s ChapterVisuals.map_resource is not a MapResource "
				+ "(got '%s' — wrong ExtResource target?)")
				% [path, map_res.get_class()]
		).is_true()

		# Step 5: Standard child structure — PlayerUnits + EnemyUnits container Nodes
		# must be present so BattleScene._spawn_unit_polygons_async can populate them.
		assert_object(scene.get_node_or_null("PlayerUnits")).override_failure_message(
			"Phase F: %s missing 'PlayerUnits' child Node2D (spawn container)" % path
		).is_not_null()
		assert_object(scene.get_node_or_null("EnemyUnits")).override_failure_message(
			"Phase F: %s missing 'EnemyUnits' child Node2D (spawn container)" % path
		).is_not_null()


## G-30 — chapter scene map_id matches shu_canon_main.json chapter map_id. Catches:
## wrapper authored with the wrong .tres path (e.g., ch15.tscn pointing at
## ch14.tres). Currently caught at higher granularity by map_grid_test +
## scenario hydration tests, but this assertion is the structural link between
## the .tscn ExtResource and the JSON chapter record.
func test_each_chapter_scene_map_id_matches_scenario_chapter_record() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/shu_canon_main.json")
	var data: Dictionary = JSON.parse_string(json_text) as Dictionary
	var chapters: Array = data["chapters"] as Array
	var map_id_to_chapter: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		map_id_to_chapter[d["map_id"] as String] = d["chapter_id"] as String

	for path: String in _CHAPTER_SCENE_PATHS:
		var packed: PackedScene = ResourceLoader.load(path) as PackedScene
		var scene: Node2D = packed.instantiate() as Node2D
		auto_free(scene)
		var map_res: MapResource = scene.get("map_resource") as MapResource
		var map_id: String = String(map_res.map_id)
		assert_bool(map_id_to_chapter.has(map_id)).override_failure_message(
			("Phase F: chapter scene %s loads map_id '%s' but shu_canon_main.json has no "
				+ "chapter referencing that map_id (wrapper authored with wrong ExtResource?)")
				% [path, map_id]
		).is_true()
