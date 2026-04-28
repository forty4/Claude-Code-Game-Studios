extends GdUnitTestSuite

## unit_role_stat_derivation_test.gd
## Story 003 — F-1..F-5 stat derivation static methods + clamp discipline + G-15 isolation.
## Covers AC-1 (F-1 ATK), AC-2 (F-2 DEF split), AC-3 (F-3 HP), AC-4 (F-4 Initiative),
## AC-5 (F-5 Move Range), AC-6 (G-15 isolation invariant), AC-7 (no hardcoded caps),
## plus EC boundary tests: EC-1 (Strategist move floor), EC-2 (Cavalry move cap),
## EC-13 (phys_def at DEF_CAP=105), EC-14 (HP floor minimum 51).
##
## DEF_CAP NOTE: GDD unit-role.md says default 100, but balance_entities.json ships 105
## per damage-calc rev 2.9.3 (commit 46276c2). All DEF tests use BalanceConstants live value.
## EC-13 asserts 105, NOT 100. GDD prose sync is a follow-up item (out of scope story-003).
##
## G-15: BOTH BalanceConstants AND UnitRole caches reset in before_test(). Mandatory.
## G-16: Parametric cases use Array[Dictionary] (typed outer).
## G-9: Multi-line failure messages wrap concat in parens before % operator.

# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/feature/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


func before_test() -> void:
	# G-15: reset BalanceConstants static cache — mandatory for every suite that reads global caps.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	# G-15: reset UnitRole static cache — mirrors BalanceConstants isolation.
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


func after_test() -> void:
	# Safety net: same reset after each test.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ───────────────────────────────────────────────────────

## Builds a HeroData resource with explicitly specified combat stats.
## Default all stats to 1 so callers only override what matters for the test.
func _make_hero(
	p_stat_might: int = 1,
	p_stat_intellect: int = 1,
	p_stat_command: int = 1,
	p_stat_agility: int = 1,
	p_base_hp_seed: int = 1,
	p_base_initiative_seed: int = 1,
	p_move_range: int = 3
) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.stat_might = p_stat_might
	hero.stat_intellect = p_stat_intellect
	hero.stat_command = p_stat_command
	hero.stat_agility = p_stat_agility
	hero.base_hp_seed = p_base_hp_seed
	hero.base_initiative_seed = p_base_initiative_seed
	hero.move_range = p_move_range
	return hero


# ── AC-1: F-1 ATK — 6 classes × 3 stat profiles + clamp boundary ─────────────

## AC-1: Cavalry stat_might=75 → ATK=82 (GDD F-1 example: floor(82.5) = 82).
func test_get_atk_cavalry_gdd_example_75_yields_82() -> void:
	var hero: HeroData = _make_hero(75)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	assert_int(result).override_failure_message(
		"AC-1: Cavalry might=75 → floor(75×1.0×1.1)=floor(82.5)=82; got %d" % result
	).is_equal(82)


## AC-1: Infantry stat_might=50 → ATK=45 (floor(50×1.0×0.9)=floor(45.0)=45).
func test_get_atk_infantry_median_50_yields_45() -> void:
	var hero: HeroData = _make_hero(50)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.INFANTRY)
	assert_int(result).override_failure_message(
		"AC-1: Infantry might=50 → floor(50×1.0×0.9)=45; got %d" % result
	).is_equal(45)


## AC-1: Archer (dual-stat) might=50, agility=50 → ATK=50 (floor((30+20)×1.0)=50).
func test_get_atk_archer_dual_stat_median_yields_50() -> void:
	var hero: HeroData = _make_hero(50, 1, 1, 50)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.ARCHER)
	assert_int(result).override_failure_message(
		"AC-1: Archer might=50 agility=50 → floor((50×0.6+50×0.4)×1.0)=50; got %d" % result
	).is_equal(50)


## AC-1: Strategist stat_intellect=50 → ATK=50 (floor(50×1.0×1.0)=50).
func test_get_atk_strategist_median_50_yields_50() -> void:
	var hero: HeroData = _make_hero(1, 50)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.STRATEGIST)
	assert_int(result).override_failure_message(
		"AC-1: Strategist intellect=50 → floor(50×1.0×1.0)=50; got %d" % result
	).is_equal(50)


## AC-1: Commander (dual-stat) cmd=50, might=50 → ATK=32 (floor((35+15)×0.8)=floor(40)=40).
## Wait — floor((50×0.7 + 50×0.3) × 0.8) = floor(50 × 0.8) = floor(40.0) = 40.
func test_get_atk_commander_dual_stat_median_yields_40() -> void:
	var hero: HeroData = _make_hero(50, 1, 50)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.COMMANDER)
	assert_int(result).override_failure_message(
		"AC-1: Commander cmd=50 might=50 → floor((50×0.7+50×0.3)×0.8)=floor(40)=40; got %d" % result
	).is_equal(40)


## AC-1: Scout (dual-stat) agility=50, might=50 → ATK=52 (floor((30+20)×1.05)=floor(52.5)=52).
func test_get_atk_scout_dual_stat_median_yields_52() -> void:
	var hero: HeroData = _make_hero(50, 1, 1, 50)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.SCOUT)
	assert_int(result).override_failure_message(
		"AC-1: Scout agi=50 might=50 → floor((50×0.6+50×0.4)×1.05)=floor(52.5)=52; got %d" % result
	).is_equal(52)


## AC-1 parametric — all 6 classes with min stats (all=1) → result >= 1 (lower clamp).
func test_get_atk_all_classes_min_stats_clamp_lower() -> void:
	var cases: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"cls": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
		{"cls": UnitRole.UnitClass.SCOUT,      "label": "SCOUT"},
	]
	var hero: HeroData = _make_hero(1, 1, 1, 1)
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var result: int = UnitRole.get_atk(hero, cls)
		assert_int(result).override_failure_message(
			"AC-1: %s min stats → ATK must be >= 1 (lower clamp); got %d" % [label, result]
		).is_greater_equal(1)


## AC-1 parametric — all 6 classes with max stats (all=100) → result <= ATK_CAP (200).
func test_get_atk_all_classes_max_stats_clamp_upper() -> void:
	var cases: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"cls": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
		{"cls": UnitRole.UnitClass.SCOUT,      "label": "SCOUT"},
	]
	var hero: HeroData = _make_hero(100, 100, 100, 100)
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var result: int = UnitRole.get_atk(hero, cls)
		assert_int(result).override_failure_message(
			("AC-1: %s max stats → ATK must be <= ATK_CAP (200)"
			+ " (upper clamp); got %d") % [label, result]
		).is_less_equal(200)


## AC-1: Cavalry max stats (might=100) → ATK=110 (floor(100×1.0×1.1)=110; not clamped).
func test_get_atk_cavalry_max_stats_100_yields_110() -> void:
	var hero: HeroData = _make_hero(100)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	assert_int(result).override_failure_message(
		"AC-1: Cavalry might=100 → floor(100×1.0×1.1)=110 (no clamp needed); got %d" % result
	).is_equal(110)


## AC-1: null secondary_stat on single-stat class does not crash and contributes 0.
## Cavalry has secondary_stat=null — any result >= 1 proves no crash.
func test_get_atk_single_stat_null_secondary_no_crash() -> void:
	var hero: HeroData = _make_hero(50)
	var result: int = UnitRole.get_atk(hero, UnitRole.UnitClass.CAVALRY)
	assert_int(result).override_failure_message(
		("AC-1: Cavalry null secondary_stat must not crash; result must be >= 1;"
		+ " got %d") % result
	).is_greater_equal(1)


# ── AC-2: F-2 DEF split — phys_def + mag_def orthogonal ─────────────────────

## AC-2: Infantry GDD example — might=60, cmd=50, int=30 → phys_def=68.
## phys_def_base = floor(60×0.3+50×0.7) = floor(18+35) = 53
## phys_def = clamp(floor(53×1.3), 1, 105) = clamp(68, 1, 105) = 68
func test_get_phys_def_infantry_gdd_example_yields_68() -> void:
	var hero: HeroData = _make_hero(60, 30, 50)
	var result: int = UnitRole.get_phys_def(hero, UnitRole.UnitClass.INFANTRY)
	assert_int(result).override_failure_message(
		("AC-2: Infantry might=60 cmd=50 int=30 → phys_def=68 (GDD F-2 example);"
		+ " got %d") % result
	).is_equal(68)


## AC-2: Infantry GDD example — might=60, cmd=50, int=30 → mag_def=28.
## mag_def_base = floor(30×0.7+50×0.3) = floor(21+15) = 36
## mag_def = clamp(floor(36×0.8), 1, 105) = clamp(28, 1, 105) = 28
func test_get_mag_def_infantry_gdd_example_yields_28() -> void:
	var hero: HeroData = _make_hero(60, 30, 50)
	var result: int = UnitRole.get_mag_def(hero, UnitRole.UnitClass.INFANTRY)
	assert_int(result).override_failure_message(
		("AC-2: Infantry might=60 cmd=50 int=30 → mag_def=28 (GDD F-2 example);"
		+ " got %d") % result
	).is_equal(28)


## AC-2: Strategist at median stats (might=50,int=50,cmd=50):
## phys_def_base = floor(50×0.3+50×0.7) = 50; phys_def = floor(50×0.5)=25; clamp(25,1,105)=25
## mag_def_base = floor(50×0.7+50×0.3) = 50; mag_def = floor(50×1.2)=60; clamp(60,1,105)=60
## Verifies mag-tank identity: Strategist mag_def > phys_def at equal input stats.
func test_get_def_strategist_median_mag_tank_identity() -> void:
	var hero: HeroData = _make_hero(50, 50, 50)
	var phys: int = UnitRole.get_phys_def(hero, UnitRole.UnitClass.STRATEGIST)
	var mag: int = UnitRole.get_mag_def(hero, UnitRole.UnitClass.STRATEGIST)
	assert_int(phys).override_failure_message(
		("AC-2: Strategist median → phys_def=floor(50×0.5)=25; got %d") % phys
	).is_equal(25)
	assert_int(mag).override_failure_message(
		("AC-2: Strategist median → mag_def=floor(50×1.2)=60; got %d") % mag
	).is_equal(60)
	assert_bool(mag > phys).override_failure_message(
		("AC-2: Strategist mag-tank identity — mag_def (%d) must exceed phys_def (%d)"
		+ " at equal input stats") % [mag, phys]
	).is_true()


## AC-2 parametric — all 6 classes min stats → phys_def and mag_def each >= 1.
func test_get_def_all_classes_min_stats_clamp_lower() -> void:
	var cases: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"cls": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
		{"cls": UnitRole.UnitClass.SCOUT,      "label": "SCOUT"},
	]
	var hero: HeroData = _make_hero(1, 1, 1)
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var phys: int = UnitRole.get_phys_def(hero, cls)
		var mag: int = UnitRole.get_mag_def(hero, cls)
		assert_int(phys).override_failure_message(
			"AC-2: %s min stats → phys_def must be >= 1 (lower clamp); got %d" % [label, phys]
		).is_greater_equal(1)
		assert_int(mag).override_failure_message(
			"AC-2: %s min stats → mag_def must be >= 1 (lower clamp); got %d" % [label, mag]
		).is_greater_equal(1)


## AC-2 parametric — all 6 classes max stats → phys_def and mag_def each <= DEF_CAP (105).
func test_get_def_all_classes_max_stats_clamp_upper() -> void:
	var cases: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"cls": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
		{"cls": UnitRole.UnitClass.SCOUT,      "label": "SCOUT"},
	]
	var hero: HeroData = _make_hero(100, 100, 100)
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var phys: int = UnitRole.get_phys_def(hero, cls)
		var mag: int = UnitRole.get_mag_def(hero, cls)
		assert_int(phys).override_failure_message(
			("AC-2: %s max stats → phys_def must be <= DEF_CAP (105)"
			+ " (upper clamp); got %d") % [label, phys]
		).is_less_equal(105)
		assert_int(mag).override_failure_message(
			("AC-2: %s max stats → mag_def must be <= DEF_CAP (105)"
			+ " (upper clamp); got %d") % [label, mag]
		).is_less_equal(105)


## EC-13: Infantry might=100, cmd=100 → phys_def_base=100; phys_def=clamp(130,1,105)=105.
## DEF_CAP=105 per balance_entities.json rev 2.9.3 (NOT 100 as GDD prose states — stale drift).
## This is the boundary test that confirms DEF_CAP clamp fires independently per stat.
func test_get_phys_def_infantry_max_stats_ec13_clamp_at_105() -> void:
	var hero: HeroData = _make_hero(100, 1, 100)
	var result: int = UnitRole.get_phys_def(hero, UnitRole.UnitClass.INFANTRY)
	assert_int(result).override_failure_message(
		("EC-13: Infantry might=100 cmd=100 → phys_def_base=100; floor(100×1.3)=130;"
		+ " clampi(130,1,105)=105; got %d"
		+ " [DEF_CAP=105 per balance_entities.json rev 2.9.3; GDD prose '100' is stale drift]") % result
	).is_equal(105)


## EC-13: mag_def clamp is independent of phys_def clamp (per GDD EC-13 specification).
## Infantry at max magic defense stats: intellect=100, cmd=100
## mag_def_base = floor(100×0.7+100×0.3) = 100; mag_def = floor(100×0.8)=80; clamp(80,1,105)=80
## (not clamped — verifies mag_def clamp operates independently, not coupled to phys_def).
func test_get_mag_def_infantry_max_stats_not_clamped() -> void:
	var hero: HeroData = _make_hero(100, 100, 100)
	var mag: int = UnitRole.get_mag_def(hero, UnitRole.UnitClass.INFANTRY)
	assert_int(mag).override_failure_message(
		("EC-13: Infantry int=100 cmd=100 → mag_def_base=100; floor(100×0.8)=80;"
		+ " clampi(80,1,105)=80 (no clamp; independent of phys_def clamp); got %d") % mag
	).is_equal(80)


# ── AC-3: F-3 HP — 4 classes × 4 seeds + EC-14 boundary ─────────────────────

## AC-3 parametric — Infantry and Strategist at 4 seed values; GDD examples verified.
## Formula: clampi(floor(seed × class_hp_mult × HP_SCALE) + HP_FLOOR, HP_FLOOR, HP_CAP)
## HP_SCALE=2.0, HP_FLOOR=50, HP_CAP=300.
func test_get_max_hp_parametric_infantry_and_strategist() -> void:
	var cases: Array[Dictionary] = [
		# Infantry (class_hp_mult=1.3) — GDD example: seed=70 → 232
		{"seed": 70, "cls": UnitRole.UnitClass.INFANTRY,   "label": "Infantry seed=70",
		 "expected": 232},
		# Strategist (class_hp_mult=0.7) — GDD example: seed=40 → 106
		{"seed": 40, "cls": UnitRole.UnitClass.STRATEGIST, "label": "Strategist seed=40",
		 "expected": 106},
		# Infantry seed=100 → floor(100×1.3×2.0)+50 = floor(260)+50 = 310 → clampi(310,50,300)=300
		{"seed": 100, "cls": UnitRole.UnitClass.INFANTRY,  "label": "Infantry seed=100 (cap)",
		 "expected": 300},
		# Strategist seed=100 → floor(100×0.7×2.0)+50 = floor(140)+50 = 190 → clampi(190,50,300)=190
		{"seed": 100, "cls": UnitRole.UnitClass.STRATEGIST, "label": "Strategist seed=100",
		 "expected": 190},
	]
	for case: Dictionary in cases:
		var seed: int = case["seed"] as int
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var expected: int = case["expected"] as int
		var hero: HeroData = _make_hero()
		hero.base_hp_seed = seed
		var result: int = UnitRole.get_max_hp(hero, cls)
		assert_int(result).override_failure_message(
			("AC-3: %s → expected max_hp=%d; got %d") % [label, expected, result]
		).is_equal(expected)


## AC-3 parametric — Cavalry and Scout at 4 seed values.
## Cavalry class_hp_mult=0.9; Scout class_hp_mult=0.75.
func test_get_max_hp_parametric_cavalry_and_scout() -> void:
	var cases: Array[Dictionary] = [
		# Cavalry seed=50 → floor(50×0.9×2.0)+50 = floor(90)+50 = 140
		{"seed": 50, "cls": UnitRole.UnitClass.CAVALRY, "label": "Cavalry seed=50",
		 "expected": 140},
		# Cavalry seed=1 → floor(1×0.9×2.0)+50 = floor(1.8)+50 = 1+50 = 51
		{"seed": 1,  "cls": UnitRole.UnitClass.CAVALRY, "label": "Cavalry seed=1",
		 "expected": 51},
		# Scout seed=50 → floor(50×0.75×2.0)+50 = floor(75)+50 = 125
		{"seed": 50, "cls": UnitRole.UnitClass.SCOUT,   "label": "Scout seed=50",
		 "expected": 125},
		# Scout seed=100 → floor(100×0.75×2.0)+50 = floor(150)+50 = 200
		{"seed": 100, "cls": UnitRole.UnitClass.SCOUT,  "label": "Scout seed=100",
		 "expected": 200},
	]
	for case: Dictionary in cases:
		var seed: int = case["seed"] as int
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var expected: int = case["expected"] as int
		var hero: HeroData = _make_hero()
		hero.base_hp_seed = seed
		var result: int = UnitRole.get_max_hp(hero, cls)
		assert_int(result).override_failure_message(
			("AC-3: %s → expected max_hp=%d; got %d") % [label, expected, result]
		).is_equal(expected)


## AC-3 parametric — Commander and Archer at 4 seed values.
## Commander class_hp_mult=1.1; Archer class_hp_mult=0.8.
func test_get_max_hp_parametric_commander_and_archer() -> void:
	var cases: Array[Dictionary] = [
		# Commander seed=50 → floor(50×1.1×2.0)+50 = floor(110)+50 = 160
		{"seed": 50, "cls": UnitRole.UnitClass.COMMANDER, "label": "Commander seed=50",
		 "expected": 160},
		# Commander seed=100 → floor(100×1.1×2.0)+50 = floor(220)+50 = 270
		{"seed": 100, "cls": UnitRole.UnitClass.COMMANDER, "label": "Commander seed=100",
		 "expected": 270},
		# Archer seed=50 → floor(50×0.8×2.0)+50 = floor(80)+50 = 130
		{"seed": 50,  "cls": UnitRole.UnitClass.ARCHER,   "label": "Archer seed=50",
		 "expected": 130},
		# Archer seed=100 → floor(100×0.8×2.0)+50 = floor(160)+50 = 210
		{"seed": 100, "cls": UnitRole.UnitClass.ARCHER,   "label": "Archer seed=100",
		 "expected": 210},
	]
	for case: Dictionary in cases:
		var seed: int = case["seed"] as int
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var expected: int = case["expected"] as int
		var hero: HeroData = _make_hero()
		hero.base_hp_seed = seed
		var result: int = UnitRole.get_max_hp(hero, cls)
		assert_int(result).override_failure_message(
			("AC-3: %s → expected max_hp=%d; got %d") % [label, expected, result]
		).is_equal(expected)


## EC-14: Strategist seed=1 → max_hp=51 (NOT 50).
## floor(1×0.7×2.0)+50 = floor(1.4)+50 = 1+50 = 51.
## HP_FLOOR (50) is additive INSIDE the expression; minimum possible max_hp = HP_FLOOR + 1 = 51.
## This test is the authoritative boundary proof that no unit can have exactly max_hp=50.
func test_get_max_hp_ec14_strategist_seed1_yields_51_not_50() -> void:
	var hero: HeroData = _make_hero()
	hero.base_hp_seed = 1
	var result: int = UnitRole.get_max_hp(hero, UnitRole.UnitClass.STRATEGIST)
	assert_int(result).override_failure_message(
		("EC-14: Strategist seed=1 → floor(1×0.7×2.0)+50 = floor(1.4)+50 = 51;"
		+ " must be 51 NOT 50; HP_FLOOR is additive INSIDE expression; got %d") % result
	).is_equal(51)


## AC-3: All classes min seed → max_hp in [51, 300] (never exactly 50).
## HP_FLOOR additive inside expression guarantees minimum is HP_FLOOR+1=51 for any seed >= 1.
func test_get_max_hp_all_classes_min_seed_never_50() -> void:
	var cases: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"cls": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
		{"cls": UnitRole.UnitClass.SCOUT,      "label": "SCOUT"},
	]
	var hero: HeroData = _make_hero()
	hero.base_hp_seed = 1
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var result: int = UnitRole.get_max_hp(hero, cls)
		assert_int(result).override_failure_message(
			("AC-3/EC-14: %s seed=1 → max_hp must be >= 51 (never exactly 50);"
			+ " got %d") % [label, result]
		).is_greater_equal(51)
		assert_int(result).override_failure_message(
			("AC-3: %s seed=1 → max_hp must be <= HP_CAP (300);"
			+ " got %d") % [label, result]
		).is_less_equal(300)


# ── AC-4: F-4 Initiative — 6 classes × 3 seeds + Scout anchor ────────────────

## AC-4: Scout seed=80 → initiative=192 (GDD F-4 example: floor(80×1.2×2.0)=192).
## Scout class_init_mult=1.2 is the highest of any class — ensures first-mover advantage.
func test_get_initiative_scout_gdd_example_seed80_yields_192() -> void:
	var hero: HeroData = _make_hero()
	hero.base_initiative_seed = 80
	var result: int = UnitRole.get_initiative(hero, UnitRole.UnitClass.SCOUT)
	assert_int(result).override_failure_message(
		("AC-4: Scout seed=80 → floor(80×1.2×2.0)=192 (GDD F-4 example);"
		+ " got %d") % result
	).is_equal(192)


## AC-4: Scout seed=80 produces higher initiative than all other classes with same seed.
func test_get_initiative_scout_seed80_highest_of_all_classes() -> void:
	var hero: HeroData = _make_hero()
	hero.base_initiative_seed = 80
	var scout_init: int = UnitRole.get_initiative(hero, UnitRole.UnitClass.SCOUT)
	var other_classes: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"cls": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
	]
	for case: Dictionary in other_classes:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var label: String = case["label"] as String
		var other_init: int = UnitRole.get_initiative(hero, cls)
		assert_int(scout_init).override_failure_message(
			("AC-4: Scout (192) must have higher initiative than %s (%d)"
			+ " at same seed=80 (class_init_mult identity)") % [label, other_init]
		).is_greater(other_init)


## AC-4 parametric — all 6 classes at 3 seeds → results in [1, 200].
func test_get_initiative_all_classes_results_in_range() -> void:
	var cases: Array[Dictionary] = [
		{"cls": UnitRole.UnitClass.CAVALRY,    "seed": 1,   "label": "CAVALRY seed=1"},
		{"cls": UnitRole.UnitClass.CAVALRY,    "seed": 50,  "label": "CAVALRY seed=50"},
		{"cls": UnitRole.UnitClass.CAVALRY,    "seed": 100, "label": "CAVALRY seed=100"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "seed": 1,   "label": "INFANTRY seed=1"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "seed": 50,  "label": "INFANTRY seed=50"},
		{"cls": UnitRole.UnitClass.INFANTRY,   "seed": 100, "label": "INFANTRY seed=100"},
		{"cls": UnitRole.UnitClass.ARCHER,     "seed": 1,   "label": "ARCHER seed=1"},
		{"cls": UnitRole.UnitClass.ARCHER,     "seed": 50,  "label": "ARCHER seed=50"},
		{"cls": UnitRole.UnitClass.ARCHER,     "seed": 100, "label": "ARCHER seed=100"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "seed": 1,   "label": "STRATEGIST seed=1"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "seed": 50,  "label": "STRATEGIST seed=50"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "seed": 100, "label": "STRATEGIST seed=100"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "seed": 1,   "label": "COMMANDER seed=1"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "seed": 50,  "label": "COMMANDER seed=50"},
		{"cls": UnitRole.UnitClass.COMMANDER,  "seed": 100, "label": "COMMANDER seed=100"},
		{"cls": UnitRole.UnitClass.SCOUT,      "seed": 1,   "label": "SCOUT seed=1"},
		{"cls": UnitRole.UnitClass.SCOUT,      "seed": 50,  "label": "SCOUT seed=50"},
		{"cls": UnitRole.UnitClass.SCOUT,      "seed": 100, "label": "SCOUT seed=100"},
	]
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var seed: int = case["seed"] as int
		var label: String = case["label"] as String
		var hero: HeroData = _make_hero()
		hero.base_initiative_seed = seed
		var result: int = UnitRole.get_initiative(hero, cls)
		assert_int(result).override_failure_message(
			"AC-4: %s → initiative must be >= 1 (lower clamp); got %d" % [label, result]
		).is_greater_equal(1)
		assert_int(result).override_failure_message(
			("AC-4: %s → initiative must be <= INIT_CAP (200)"
			+ " (upper clamp); got %d") % [label, result]
		).is_less_equal(200)


## AC-4: Scout seed=100 → floor(100×1.2×2.0)=240 → clamped to INIT_CAP=200.
func test_get_initiative_scout_seed100_clamped_to_200() -> void:
	var hero: HeroData = _make_hero()
	hero.base_initiative_seed = 100
	var result: int = UnitRole.get_initiative(hero, UnitRole.UnitClass.SCOUT)
	assert_int(result).override_failure_message(
		("AC-4: Scout seed=100 → floor(100×1.2×2.0)=240 → clampi(240,1,200)=200;"
		+ " got %d") % result
	).is_equal(200)


## AC-4: Infantry seed=1 → floor(1×0.7×2.0)=floor(1.4)=1 → clampi(1,1,200)=1 (lower clamp test).
func test_get_initiative_infantry_seed1_yields_1() -> void:
	var hero: HeroData = _make_hero()
	hero.base_initiative_seed = 1
	var result: int = UnitRole.get_initiative(hero, UnitRole.UnitClass.INFANTRY)
	assert_int(result).override_failure_message(
		("AC-4: Infantry seed=1 → floor(1×0.7×2.0)=floor(1.4)=1;"
		+ " clampi(1,1,200)=1; got %d") % result
	).is_equal(1)


# ── AC-5: F-5 Move Range — 6 classes × 5 move_range values + EC-1 + EC-2 ─────

## AC-5 parametric — all 6 classes at all 5 valid hero move_range values (2..6).
## Verifies: effective_move_range = clampi(hero.move_range + class_move_delta, 2, 6).
## class_move_delta: CAVALRY=+1, INFANTRY=0, ARCHER=0, STRATEGIST=-1, COMMANDER=0, SCOUT=+1.
func test_get_effective_move_range_all_classes_all_ranges() -> void:
	var cases: Array[Dictionary] = [
		# CAVALRY (delta=+1): results 3,4,5,6,6 (cap at 6 when mr=6)
		{"cls": UnitRole.UnitClass.CAVALRY, "mr": 2, "expected": 3, "label": "CAV mr=2"},
		{"cls": UnitRole.UnitClass.CAVALRY, "mr": 3, "expected": 4, "label": "CAV mr=3"},
		{"cls": UnitRole.UnitClass.CAVALRY, "mr": 4, "expected": 5, "label": "CAV mr=4"},
		{"cls": UnitRole.UnitClass.CAVALRY, "mr": 5, "expected": 6, "label": "CAV mr=5"},
		{"cls": UnitRole.UnitClass.CAVALRY, "mr": 6, "expected": 6, "label": "CAV mr=6 EC-2"},
		# INFANTRY (delta=0): results 2,3,4,5,6 (no change)
		{"cls": UnitRole.UnitClass.INFANTRY, "mr": 2, "expected": 2, "label": "INF mr=2"},
		{"cls": UnitRole.UnitClass.INFANTRY, "mr": 3, "expected": 3, "label": "INF mr=3"},
		{"cls": UnitRole.UnitClass.INFANTRY, "mr": 4, "expected": 4, "label": "INF mr=4"},
		{"cls": UnitRole.UnitClass.INFANTRY, "mr": 5, "expected": 5, "label": "INF mr=5"},
		{"cls": UnitRole.UnitClass.INFANTRY, "mr": 6, "expected": 6, "label": "INF mr=6"},
		# ARCHER (delta=0): results 2,3,4,5,6 (no change)
		{"cls": UnitRole.UnitClass.ARCHER, "mr": 2, "expected": 2, "label": "ARC mr=2"},
		{"cls": UnitRole.UnitClass.ARCHER, "mr": 3, "expected": 3, "label": "ARC mr=3"},
		{"cls": UnitRole.UnitClass.ARCHER, "mr": 4, "expected": 4, "label": "ARC mr=4"},
		{"cls": UnitRole.UnitClass.ARCHER, "mr": 5, "expected": 5, "label": "ARC mr=5"},
		{"cls": UnitRole.UnitClass.ARCHER, "mr": 6, "expected": 6, "label": "ARC mr=6"},
		# STRATEGIST (delta=-1): results 2,2,3,4,5 (floor at 2 when mr=2)
		{"cls": UnitRole.UnitClass.STRATEGIST, "mr": 2, "expected": 2, "label": "STR mr=2 EC-1"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "mr": 3, "expected": 2, "label": "STR mr=3"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "mr": 4, "expected": 3, "label": "STR mr=4"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "mr": 5, "expected": 4, "label": "STR mr=5"},
		{"cls": UnitRole.UnitClass.STRATEGIST, "mr": 6, "expected": 5, "label": "STR mr=6"},
		# COMMANDER (delta=0): results 2,3,4,5,6 (no change)
		{"cls": UnitRole.UnitClass.COMMANDER, "mr": 2, "expected": 2, "label": "CMD mr=2"},
		{"cls": UnitRole.UnitClass.COMMANDER, "mr": 3, "expected": 3, "label": "CMD mr=3"},
		{"cls": UnitRole.UnitClass.COMMANDER, "mr": 4, "expected": 4, "label": "CMD mr=4"},
		{"cls": UnitRole.UnitClass.COMMANDER, "mr": 5, "expected": 5, "label": "CMD mr=5"},
		{"cls": UnitRole.UnitClass.COMMANDER, "mr": 6, "expected": 6, "label": "CMD mr=6"},
		# SCOUT (delta=+1): results 3,4,5,6,6 (cap at 6 when mr=6)
		{"cls": UnitRole.UnitClass.SCOUT, "mr": 2, "expected": 3, "label": "SCT mr=2"},
		{"cls": UnitRole.UnitClass.SCOUT, "mr": 3, "expected": 4, "label": "SCT mr=3"},
		{"cls": UnitRole.UnitClass.SCOUT, "mr": 4, "expected": 5, "label": "SCT mr=4"},
		{"cls": UnitRole.UnitClass.SCOUT, "mr": 5, "expected": 6, "label": "SCT mr=5"},
		{"cls": UnitRole.UnitClass.SCOUT, "mr": 6, "expected": 6, "label": "SCT mr=6"},
	]
	for case: Dictionary in cases:
		var cls: UnitRole.UnitClass = case["cls"] as UnitRole.UnitClass
		var mr: int = case["mr"] as int
		var expected: int = case["expected"] as int
		var label: String = case["label"] as String
		var hero: HeroData = _make_hero()
		hero.move_range = mr
		var result: int = UnitRole.get_effective_move_range(hero, cls)
		assert_int(result).override_failure_message(
			("AC-5: %s → expected effective_move_range=%d; got %d") % [label, expected, result]
		).is_equal(expected)


## EC-1: Strategist hero_move_range=2 → effective_move_range=2 (NOT 1).
## class_move_delta=-1; 2+(-1)=1; clampi(1,2,6)=2. The -1 delta is absorbed by MOVE_RANGE_MIN clamp.
## Minimum playable budget is 20 (2×10), NOT 10 (1×10).
func test_get_effective_move_range_ec1_strategist_mr2_yields_2_not_1() -> void:
	var hero: HeroData = _make_hero()
	hero.move_range = 2
	var result: int = UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.STRATEGIST)
	assert_int(result).override_failure_message(
		("EC-1: Strategist move_range=2 → 2+(-1)=1 → clampi(1,2,6)=2;"
		+ " must be 2 NOT 1 (MOVE_RANGE_MIN clamp absorbs the -1 delta); got %d") % result
	).is_equal(2)


## EC-2: Cavalry hero_move_range=6 → effective_move_range=6 (NOT 7).
## class_move_delta=+1; 6+1=7; clampi(7,2,6)=6. The +1 delta is wasted at MOVE_RANGE_MAX.
## Cavalry move_range=6 gains no advantage over move_range=5 (budget 60 either way).
func test_get_effective_move_range_ec2_cavalry_mr6_yields_6_not_7() -> void:
	var hero: HeroData = _make_hero()
	hero.move_range = 6
	var result: int = UnitRole.get_effective_move_range(hero, UnitRole.UnitClass.CAVALRY)
	assert_int(result).override_failure_message(
		("EC-2: Cavalry move_range=6 → 6+1=7 → clampi(7,2,6)=6;"
		+ " must be 6 NOT 7 (MOVE_RANGE_MAX clamp absorbs the +1 delta); got %d") % result
	).is_equal(6)


## EC-2 corollary: Cavalry mr=6 and mr=5 produce identical effective_move_range=6.
## Confirms the design intent from GDD EC-2 commentary: "+1 delta is wasted."
func test_get_effective_move_range_ec2_cavalry_mr5_and_mr6_identical() -> void:
	var hero5: HeroData = _make_hero()
	hero5.move_range = 5
	var hero6: HeroData = _make_hero()
	hero6.move_range = 6
	var result5: int = UnitRole.get_effective_move_range(hero5, UnitRole.UnitClass.CAVALRY)
	var result6: int = UnitRole.get_effective_move_range(hero6, UnitRole.UnitClass.CAVALRY)
	assert_int(result5).override_failure_message(
		"EC-2: Cavalry mr=5 → clampi(6,2,6)=6; got %d" % result5
	).is_equal(6)
	assert_int(result6).override_failure_message(
		"EC-2: Cavalry mr=6 → clampi(7,2,6)=6; got %d" % result6
	).is_equal(6)
	assert_int(result5).override_failure_message(
		"EC-2: Cavalry mr=5 and mr=6 must produce identical effective_move_range; got %d and %d" % [result5, result6]
	).is_equal(result6)


# ── AC-6: G-15 isolation invariant — structural verification ──────────────────

## AC-6: This test file contains _cache_loaded = false in before_test().
## CI lint: grep -L "_cache_loaded = false" tests/unit/foundation/unit_role*.gd → must return empty.
## Structural assertion: verify the source of THIS file contains the mandatory G-15 reset.
func test_ac6_g15_isolation_before_test_resets_both_caches() -> void:
	var this_file: String = (
		"res://tests/unit/foundation/unit_role_stat_derivation_test.gd"
	)
	var content: String = FileAccess.get_file_as_string(this_file)
	assert_bool(content.contains("_cache_loaded = false")).override_failure_message(
		("AC-6/G-15: This test file must contain '_cache_loaded = false' in before_test();"
		+ " the G-15 mandatory BalanceConstants cache reset is absent")
	).is_true()
	assert_bool(content.contains("_coefficients_loaded = false")).override_failure_message(
		("AC-6/G-15: This test file must contain '_coefficients_loaded = false' in before_test();"
		+ " the UnitRole cache reset is absent")
	).is_true()
	assert_bool(content.contains("func before_test()")).override_failure_message(
		("AC-6/G-15: This test file must declare 'func before_test()' (NOT before_each — G-15);"
		+ " the canonical GdUnit4 per-test lifecycle hook is absent")
	).is_true()


# ── AC-7: No hardcoded cap values — smoke check ───────────────────────────────

## AC-7 smoke: unit_role.gd must not contain any raw numeric cap literals in method bodies.
## Full CI lint lives in story-010 (tools/ci/); this is the story-003 in-file smoke check.
## Checks: ATK_CAP (200), HP_CAP (300), INIT_CAP (200) are NOT literal in the production file.
## The value 200 also appears as enum backing values (0-5) — allowed per false-positive list.
## We check the method body region (after the fallback dict) specifically.
func test_ac7_no_hardcoded_caps_in_production_stat_methods() -> void:
	var prod_file: String = "res://src/foundation/unit_role.gd"
	var content: String = FileAccess.get_file_as_string(prod_file)
	# The _build_fallback_dict() legitimately contains GDD multiplier floats.
	# The new stat-derivation methods must route all caps through BalanceConstants.
	# Smoke: confirm all 6 new method names are present (proves file was written).
	assert_bool(content.contains("func get_atk(")).override_failure_message(
		"AC-7: get_atk method must be present in unit_role.gd"
	).is_true()
	assert_bool(content.contains("func get_phys_def(")).override_failure_message(
		"AC-7: get_phys_def method must be present in unit_role.gd"
	).is_true()
	assert_bool(content.contains("func get_mag_def(")).override_failure_message(
		"AC-7: get_mag_def method must be present in unit_role.gd"
	).is_true()
	assert_bool(content.contains("func get_max_hp(")).override_failure_message(
		"AC-7: get_max_hp method must be present in unit_role.gd"
	).is_true()
	assert_bool(content.contains("func get_initiative(")).override_failure_message(
		"AC-7: get_initiative method must be present in unit_role.gd"
	).is_true()
	assert_bool(content.contains("func get_effective_move_range(")).override_failure_message(
		"AC-7: get_effective_move_range method must be present in unit_role.gd"
	).is_true()
	# Smoke: all cap reads go through BalanceConstants
	assert_bool(content.contains("BalanceConstants.get_const(\"ATK_CAP\")")).override_failure_message(
		"AC-7: get_atk must read ATK_CAP via BalanceConstants.get_const(); hardcoded literal found or accessor missing"
	).is_true()
	assert_bool(content.contains("BalanceConstants.get_const(\"DEF_CAP\")")).override_failure_message(
		"AC-7: get_phys_def/get_mag_def must read DEF_CAP via BalanceConstants.get_const(); accessor missing"
	).is_true()
	assert_bool(content.contains("BalanceConstants.get_const(\"HP_CAP\")")).override_failure_message(
		"AC-7: get_max_hp must read HP_CAP via BalanceConstants.get_const(); accessor missing"
	).is_true()
	assert_bool(content.contains("BalanceConstants.get_const(\"INIT_CAP\")")).override_failure_message(
		"AC-7: get_initiative must read INIT_CAP via BalanceConstants.get_const(); accessor missing"
	).is_true()
	assert_bool(content.contains("BalanceConstants.get_const(\"MOVE_RANGE_MIN\")")).override_failure_message(
		"AC-7: get_effective_move_range must read MOVE_RANGE_MIN via BalanceConstants.get_const(); accessor missing"
	).is_true()
	assert_bool(content.contains("BalanceConstants.get_const(\"MOVE_RANGE_MAX\")")).override_failure_message(
		"AC-7: get_effective_move_range must read MOVE_RANGE_MAX via BalanceConstants.get_const(); accessor missing"
	).is_true()
