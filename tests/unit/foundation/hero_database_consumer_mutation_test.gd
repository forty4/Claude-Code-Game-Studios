extends GdUnitTestSuite

## hero_database_consumer_mutation_test.gd
## Story 004 — R-1 mitigation regression test (TR-005 read-only contract).
##
## CONTRACT BEING TESTED: HeroDatabase.get_hero returns a SHARED REFERENCE.
## Consumers MUST NOT mutate returned HeroData fields per ADR-0007 §Interactions
## "읽기 전용 계약" + forbidden_pattern hero_data_consumer_mutation. This test
## DELIBERATELY exercises the forbidden mutation to PROVE the convention is
## convention-only (no GDScript const-reference enforcement; duplicate_deep()
## rejected for performance per ADR-0007 §5).
##
## TEST PASSING (mutation visible) is the DESIRED outcome — it documents that
## the contract is enforced by code review and discipline, not by the engine.

const _HD_PATH: String = "res://src/foundation/hero_database.gd"
var _hd_script: GDScript = load(_HD_PATH) as GDScript


func before_test() -> void:
	# G-15 obligation: reset BOTH static vars before every test.
	_hd_script.set("_heroes_loaded", false)
	var empty: Dictionary[StringName, HeroData] = {}
	_hd_script.set("_heroes", empty)


func after_test() -> void:
	# Safety net: re-reset in case a test left dirty state.
	_hd_script.set("_heroes_loaded", false)
	var empty: Dictionary[StringName, HeroData] = {}
	_hd_script.set("_heroes", empty)


## AC-6 (R-1 regression): mutating a HeroData field returned from get_hero IS
## visible to subsequent get_hero calls — proving the read-only contract is
## convention-only and duplicate_deep() defense is NOT in place.
func test_get_hero_returns_shared_reference_mutation_is_visible_convention_is_sole_defense() -> void:
	# Arrange: pre-populate _heroes with one record (stat_might = 70)
	var hero: HeroData = HeroData.new()
	hero.hero_id = &"shu_001_liu_bei"
	hero.stat_might = 70
	hero.is_available_mvp = true
	var fixture: Dictionary[StringName, HeroData] = {&"shu_001_liu_bei": hero}
	_hd_script.set("_heroes", fixture)
	_hd_script.set("_heroes_loaded", true)

	# First call: returns reference; stat_might == 70
	var hero1: HeroData = HeroDatabase.get_hero(&"shu_001_liu_bei")
	assert_int(hero1.stat_might).override_failure_message(
		"AC-6 setup: initial stat_might must be 70"
	).is_equal(70)

	# Act: deliberately mutate the returned reference (forbidden in production code).
	hero1.stat_might = 99

	# Assert: subsequent get_hero call sees the mutation — proves shared reference.
	# IF THIS ASSERTION FAILS, the read-only contract has been defended against
	# (e.g. duplicate_deep added) without updating ADR-0007 §5 + R-1 mitigation.
	var hero2: HeroData = HeroDatabase.get_hero(&"shu_001_liu_bei")
	assert_int(hero2.stat_might).override_failure_message(
		("AC-6 (R-1 regression): If this assertion fails, HeroDatabase is now defending "
		+ "against mutation. Either duplicate_deep() was added (10x hot-path cost; rejected "
		+ "per ADR-0007 §5) or some other defense landed. The R-1 mitigation contract "
		+ "changed — re-evaluate ADR-0007 + this test before adjusting.")
	).is_equal(99)
