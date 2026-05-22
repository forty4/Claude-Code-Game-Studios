## Synergy adjacency tests for GridBattleController.
##
## S73 backfill — S72 Synergy v1 (commit `c9e7dce`) + S73 Synergy v2 badge
## helper (commit `c158bab`).
## v1: _compute_synergy_atk_bonus / _compute_synergy_def_bonus (Peach Garden
##     +5 ATK trio / Lone Wolf +5 ATK 위연 / 방통 Counsel +3 DEF).
## v2: compute_synergy_badges → {unit_id: '義'/'策'/'獨' concat string}.
## All bonds are 4-directional adjacency only. Dead unit safety + cap rules
## also covered.

extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helpers ────────────────────────────────────────────────────────────────

func _make_hero(unit_id: int, hero_id: StringName, pos: Vector2i, side: int = 0) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = hero_id
	unit.unit_class = 0
	unit.position = pos
	unit.side = side
	unit.facing = 0
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	return unit


func _setup(roster: Array[BattleUnit]) -> GridBattleController:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	auto_free(hp_controller)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	controller.setup(roster, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)
	controller._rng = RandomNumberGenerator.new()
	controller._rng.seed = 12345
	return controller


# ═══════════════════════════════════════════════════════════════════════════
# v1 — _compute_synergy_atk_bonus
# ═══════════════════════════════════════════════════════════════════════════

# ─── Peach Garden Bond (유비/관우/장비 trio, 2+ adjacent → +5 ATK) ────────

func test_peach_garden_lone_liu_bei_gets_no_bonus() -> void:
	# 유비 alone, no trio members adjacent → 0 bonus.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var controller: GridBattleController = _setup([liu_bei])

	var bonus: int = controller._compute_synergy_atk_bonus(liu_bei)

	assert_int(bonus).is_equal(0)


func test_peach_garden_liu_bei_adjacent_to_guan_yu_grants_plus_5_atk() -> void:
	# 유비 N + 관우 N+1 (4-adj south) → both in trio → +5 ATK each.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(2, 3))
	var controller: GridBattleController = _setup([liu_bei, guan_yu])

	assert_int(controller._compute_synergy_atk_bonus(liu_bei)).is_equal(5)
	assert_int(controller._compute_synergy_atk_bonus(guan_yu)).is_equal(5)


func test_peach_garden_caps_at_plus_5_even_with_2_brothers_adjacent() -> void:
	# 유비 surrounded by both 관우 AND 장비 → +5 cap (not +10).
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(2, 3))
	var zhang_fei: BattleUnit = _make_hero(3, &"shu_003_zhang_fei", Vector2i(3, 2))
	var controller: GridBattleController = _setup([liu_bei, guan_yu, zhang_fei])

	assert_int(controller._compute_synergy_atk_bonus(liu_bei)).is_equal(5)


func test_peach_garden_diagonal_does_not_trigger() -> void:
	# Diagonal adjacency (Manhattan dist 2) → NOT 4-adj → no bonus.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(3, 3))  # diag
	var controller: GridBattleController = _setup([liu_bei, guan_yu])

	assert_int(controller._compute_synergy_atk_bonus(liu_bei)).is_equal(0)


func test_peach_garden_non_trio_hero_adjacent_no_bonus() -> void:
	# 위연 adjacent to 유비 → 위연 is not in trio → no Peach Garden bonus.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var wei_yan: BattleUnit = _make_hero(2, &"shu_009_wei_yan", Vector2i(2, 3))
	var controller: GridBattleController = _setup([liu_bei, wei_yan])

	assert_int(controller._compute_synergy_atk_bonus(liu_bei)).is_equal(0)


# ─── Lone Wolf — 위연, 0 adjacent allies → +5 ATK ────────────────────────

func test_lone_wolf_wei_yan_isolated_grants_plus_5_atk() -> void:
	var wei_yan: BattleUnit = _make_hero(1, &"shu_009_wei_yan", Vector2i(2, 2))
	var controller: GridBattleController = _setup([wei_yan])

	assert_int(controller._compute_synergy_atk_bonus(wei_yan)).is_equal(5)


func test_lone_wolf_wei_yan_with_adjacent_ally_loses_bonus() -> void:
	# Any 4-adj ally cancels Lone Wolf — 위연's identity is solo.
	var wei_yan: BattleUnit = _make_hero(1, &"shu_009_wei_yan", Vector2i(2, 2))
	var liu_bei: BattleUnit = _make_hero(2, &"shu_001_liu_bei", Vector2i(2, 3))
	var controller: GridBattleController = _setup([wei_yan, liu_bei])

	assert_int(controller._compute_synergy_atk_bonus(wei_yan)).is_equal(0)


func test_lone_wolf_only_applies_to_wei_yan_not_other_heroes() -> void:
	# Non-위연 hero alone → no Lone Wolf (it's hero-specific).
	var huang_zhong: BattleUnit = _make_hero(1, &"shu_004_huang_zhong", Vector2i(2, 2))
	var controller: GridBattleController = _setup([huang_zhong])

	assert_int(controller._compute_synergy_atk_bonus(huang_zhong)).is_equal(0)


# ═══════════════════════════════════════════════════════════════════════════
# v1 — _compute_synergy_def_bonus (방통 Counsel)
# ═══════════════════════════════════════════════════════════════════════════

func test_counsel_pang_tong_self_buffs_when_adjacent_to_any_ally() -> void:
	# 방통 adjacent to ANY ally (not just specific) → +3 DEF self.
	var pang_tong: BattleUnit = _make_hero(1, &"shu_007_pang_tong", Vector2i(2, 2))
	var liu_bei: BattleUnit = _make_hero(2, &"shu_001_liu_bei", Vector2i(2, 3))
	var controller: GridBattleController = _setup([pang_tong, liu_bei])

	assert_int(controller._compute_synergy_def_bonus(pang_tong)).is_equal(3)


func test_counsel_pang_tong_alone_no_def_bonus() -> void:
	var pang_tong: BattleUnit = _make_hero(1, &"shu_007_pang_tong", Vector2i(2, 2))
	var controller: GridBattleController = _setup([pang_tong])

	assert_int(controller._compute_synergy_def_bonus(pang_tong)).is_equal(0)


func test_counsel_ally_adjacent_to_pang_tong_gets_plus_3_def() -> void:
	# Ally next to 방통 receives +3 DEF (Counsel beneficiary).
	var pang_tong: BattleUnit = _make_hero(1, &"shu_007_pang_tong", Vector2i(2, 2))
	var liu_bei: BattleUnit = _make_hero(2, &"shu_001_liu_bei", Vector2i(2, 3))
	var controller: GridBattleController = _setup([pang_tong, liu_bei])

	assert_int(controller._compute_synergy_def_bonus(liu_bei)).is_equal(3)


func test_counsel_no_bonus_to_non_adjacent_ally() -> void:
	# 방통 at (2,2); 유비 at (5,5) far away → no bonus.
	var pang_tong: BattleUnit = _make_hero(1, &"shu_007_pang_tong", Vector2i(2, 2))
	var liu_bei: BattleUnit = _make_hero(2, &"shu_001_liu_bei", Vector2i(5, 5))
	var controller: GridBattleController = _setup([pang_tong, liu_bei])

	assert_int(controller._compute_synergy_def_bonus(liu_bei)).is_equal(0)


# ─── Dead unit safety ──────────────────────────────────────────────────────

func test_synergy_atk_bonus_returns_0_for_dead_unit() -> void:
	# Dead unit (HP=0 via stub) must short-circuit to 0 — no synergy on corpses.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(2, 3))
	var controller: GridBattleController = _setup([liu_bei, guan_yu])
	# Mark 유비 dead via HPStatusControllerStub
	var hp: HPStatusControllerStub = controller._hp_controller as HPStatusControllerStub
	hp.set_alive_for_test(1, false)

	assert_int(controller._compute_synergy_atk_bonus(liu_bei)).is_equal(0)


# ═══════════════════════════════════════════════════════════════════════════
# v2 — compute_synergy_badges (badge char map)
# ═══════════════════════════════════════════════════════════════════════════

func test_compute_synergy_badges_empty_for_no_synergy_units() -> void:
	# Single non-synergy hero → badge entry exists but is empty string.
	var huang_zhong: BattleUnit = _make_hero(1, &"shu_004_huang_zhong", Vector2i(2, 2))
	var controller: GridBattleController = _setup([huang_zhong])

	var badges: Dictionary = controller.compute_synergy_badges()

	assert_str(badges.get(1, "X") as String).is_equal("")


func test_compute_synergy_badges_peach_garden_emits_yi_char() -> void:
	# 유비 + 관우 adjacent in trio → both get '義'.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(2, 3))
	var controller: GridBattleController = _setup([liu_bei, guan_yu])

	var badges: Dictionary = controller.compute_synergy_badges()

	assert_str(badges[1] as String).is_equal("義")
	assert_str(badges[2] as String).is_equal("義")


func test_compute_synergy_badges_lone_wolf_emits_dok_char() -> void:
	# 위연 alone → '獨'.
	var wei_yan: BattleUnit = _make_hero(1, &"shu_009_wei_yan", Vector2i(2, 2))
	var controller: GridBattleController = _setup([wei_yan])

	var badges: Dictionary = controller.compute_synergy_badges()

	assert_str(badges[1] as String).is_equal("獨")


func test_compute_synergy_badges_counsel_emits_chaek_char() -> void:
	# 방통 + ally adjacent → both get '策'.
	var pang_tong: BattleUnit = _make_hero(1, &"shu_007_pang_tong", Vector2i(2, 2))
	var liu_bei: BattleUnit = _make_hero(2, &"shu_001_liu_bei", Vector2i(2, 3))
	var controller: GridBattleController = _setup([pang_tong, liu_bei])

	var badges: Dictionary = controller.compute_synergy_badges()

	assert_str(badges[1] as String).is_equal("策")
	# 유비 also gets 策 from being adjacent to 방통 (Counsel recipient).
	assert_str(badges[2] as String).is_equal("策")


func test_compute_synergy_badges_concat_yi_and_chaek_for_dual_synergy() -> void:
	# 유비 adjacent to BOTH 관우 (義) AND 방통 (策) → concat '義策'.
	# Layout: 유비 center; 관우 north; 방통 south.
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(2, 1))
	var pang_tong: BattleUnit = _make_hero(3, &"shu_007_pang_tong", Vector2i(2, 3))
	var controller: GridBattleController = _setup([liu_bei, guan_yu, pang_tong])

	var badges: Dictionary = controller.compute_synergy_badges()

	# Order: Peach Garden checked first, then Counsel — concat order should be 義 then 策.
	assert_str(badges[1] as String).is_equal("義策")


func test_compute_synergy_badges_dead_unit_gets_empty_string() -> void:
	# Dead units: badge should be empty (not crash).
	var liu_bei: BattleUnit = _make_hero(1, &"shu_001_liu_bei", Vector2i(2, 2))
	var guan_yu: BattleUnit = _make_hero(2, &"shu_002_guan_yu", Vector2i(2, 3))
	var controller: GridBattleController = _setup([liu_bei, guan_yu])
	var hp: HPStatusControllerStub = controller._hp_controller as HPStatusControllerStub
	hp.set_alive_for_test(1, false)

	var badges: Dictionary = controller.compute_synergy_badges()

	# Dead unit 유비 → no badge. Surviving 관우 → no trio partner alive → no 義 either.
	assert_str(badges[1] as String).is_equal("")
	assert_str(badges[2] as String).is_equal("")
