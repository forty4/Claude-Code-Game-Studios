extends GdUnitTestSuite

## hero_database_warning_tier_test.gd
## Story 004 — WARNING-tier relationship validation (EC-4 self-ref, EC-5 orphan FK, EC-6
## asymmetric conflict) + load-order independence + record resilience + typed-array return.
## Covers AC-1 through AC-5, AC-7, AC-8 per story-004 QA Test Cases.
##
## TEST SEAM: calls HeroDatabase._load_heroes_from_dict(synthetic_dict) to
## bypass file I/O. Fixtures are in-test Dictionary literals — heroes.json is NOT touched.
##
## TEST ISOLATION (G-15 + ADR-0006 §6):
##   before_test() MUST reset BOTH HeroDatabase._heroes_loaded = false
##                              AND HeroDatabase._heroes = {}

const _HD_PATH: String = "res://src/foundation/hero_database.gd"
var _hd_script: GDScript = load(_HD_PATH) as GDScript


# ── AC-9: per-test isolation reset (G-15 obligation) ─────────────────────────


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


# ── Fixture helper ────────────────────────────────────────────────────────────


## Builds a valid JSON-shape record dict. All fields populated with VALID defaults.
## Tests override the "relationships" field to trigger WARNING-tier paths.
## Mirrors _make_valid_record from hero_database_validation_test.gd.
func _make_test_record(faction: int, rels: Array[Dictionary]) -> Dictionary:
	return {
		"name_ko": "테스트", "name_zh": "测试", "name_courtesy": "",
		"faction": faction,
		"portrait_id": "", "battle_sprite_id": "",
		"stat_might": 50, "stat_intellect": 50, "stat_command": 50, "stat_agility": 50,
		"base_hp_seed": 50, "base_initiative_seed": 50,
		"move_range": 4,
		"default_class": 0,
		"equipment_slot_override": [],
		"growth_might": 1.0, "growth_intellect": 1.0, "growth_command": 1.0, "growth_agility": 1.0,
		"innate_skill_ids": [], "skill_unlock_levels": [],
		"join_chapter": 1, "join_condition_tag": "",
		"is_available_mvp": true,
		"relationships": rels,
	}


# ── AC-1: EC-4 self-reference WARNING ────────────────────────────────────────


## AC-1: record with a relationship where hero_b_id == hero_id → entry dropped;
## record itself loads normally. push_warning is a documented side effect; test
## asserts the visible-behavior consequence (entry absent from relationships).
func test_self_referencing_relationship_dropped_ec4() -> void:
	# Arrange: shu_001_liu_bei has a relationship pointing back to itself.
	var self_ref_rel: Array[Dictionary] = [
		{"hero_b_id": "shu_001_liu_bei", "relation_type": "RIVAL",
		"effect_tag": "rival_bonus", "is_symmetric": true}
	]
	var fixture: Dictionary = {
		"shu_001_liu_bei": _make_test_record(0, self_ref_rel)
	}

	# Act
	HeroDatabase._load_heroes_from_dict(fixture)

	# Assert: record loads; self-ref relationship dropped.
	assert_bool(_hd_script.get("_heroes_loaded") as bool).override_failure_message(
		"AC-1: record must load normally despite EC-4 self-ref (WARNING only)"
	).is_true()

	assert_int(HeroDatabase._heroes.size()).override_failure_message(
		"AC-1: hero record must be present in _heroes"
	).is_equal(1)

	assert_int(HeroDatabase._heroes[&"shu_001_liu_bei"].relationships.size()).override_failure_message(
		"AC-1: EC-4 self-ref relationship entry must be dropped from relationships"
	).is_equal(0)


# ── AC-2: EC-5 orphan FK WARNING ─────────────────────────────────────────────


## AC-2: record with a relationship to an unknown hero_b_id → entry dropped;
## record itself loads normally.
func test_orphan_hero_b_id_dropped_ec5() -> void:
	# Arrange: shu_001_liu_bei has a relationship to a hero not in the fixture.
	var orphan_rel: Array[Dictionary] = [
		{"hero_b_id": "qun_099_fictional", "relation_type": "RIVAL",
		"effect_tag": "rival_bonus", "is_symmetric": true}
	]
	var fixture: Dictionary = {
		"shu_001_liu_bei": _make_test_record(0, orphan_rel)
	}

	# Act
	HeroDatabase._load_heroes_from_dict(fixture)

	# Assert: record loads; orphan FK relationship dropped.
	assert_bool(_hd_script.get("_heroes_loaded") as bool).override_failure_message(
		"AC-2: record must load normally despite EC-5 orphan FK (WARNING only)"
	).is_true()

	assert_int(HeroDatabase._heroes.size()).override_failure_message(
		"AC-2: hero record must be present in _heroes"
	).is_equal(1)

	assert_int(HeroDatabase._heroes[&"shu_001_liu_bei"].relationships.size()).override_failure_message(
		"AC-2: EC-5 orphan FK entry must be dropped from relationships"
	).is_equal(0)


# ── AC-3: EC-6 asymmetric conflict WARNING ────────────────────────────────────


## AC-3: A→B RIVAL is_symmetric=true and B→A SWORN_BROTHER is_symmetric=true →
## BOTH entries kept; Hero DB does NOT adjudicate. push_warning is side effect.
func test_asymmetric_conflict_keeps_both_entries_ec6() -> void:
	# Arrange: A has RIVAL rel to B; B has SWORN_BROTHER rel to A — both symmetric.
	var rel_a_to_b: Array[Dictionary] = [
		{"hero_b_id": "wei_001_cao_cao", "relation_type": "RIVAL",
		"effect_tag": "rival_bonus", "is_symmetric": true}
	]
	var rel_b_to_a: Array[Dictionary] = [
		{"hero_b_id": "shu_001_liu_bei", "relation_type": "SWORN_BROTHER",
		"effect_tag": "sworn_bonus", "is_symmetric": true}
	]
	var fixture: Dictionary = {
		"shu_001_liu_bei": _make_test_record(0, rel_a_to_b),
		"wei_001_cao_cao": _make_test_record(1, rel_b_to_a),
	}

	# Act
	HeroDatabase._load_heroes_from_dict(fixture)

	# Assert: both records load; both entries kept (Hero DB doesn't adjudicate EC-6).
	assert_bool(_hd_script.get("_heroes_loaded") as bool).override_failure_message(
		"AC-3: both records must load normally with EC-6 conflict (WARNING only, no drop)"
	).is_true()

	assert_int(HeroDatabase._heroes.size()).override_failure_message(
		"AC-3: both hero records must be present in _heroes"
	).is_equal(2)

	assert_int(HeroDatabase._heroes[&"shu_001_liu_bei"].relationships.size()).override_failure_message(
		"AC-3: A's relationship entry must be KEPT (EC-6 keeps both sides)"
	).is_equal(1)

	assert_int(HeroDatabase._heroes[&"wei_001_cao_cao"].relationships.size()).override_failure_message(
		"AC-3: B's relationship entry must be KEPT (EC-6 keeps both sides)"
	).is_equal(1)


# ── AC-4: load-order independence ────────────────────────────────────────────


## AC-4 (forward ref): A is listed BEFORE B in JSON. A's relationship references B.
## Pass 3 (EC-5 orphan check) runs after Pass 2 inserts all valid records → A's rel kept.
func test_forward_ref_relationship_resolves_post_pass_2() -> void:
	# Arrange: shu_001 listed first; its rel targets wei_001 listed second.
	var rel_a_to_b: Array[Dictionary] = [
		{"hero_b_id": "wei_001_cao_cao", "relation_type": "RIVAL",
		"effect_tag": "rival_bonus", "is_symmetric": false}
	]
	var fixture: Dictionary = {
		"shu_001_liu_bei": _make_test_record(0, rel_a_to_b),
		"wei_001_cao_cao": _make_test_record(1, []),
	}

	# Act
	HeroDatabase._load_heroes_from_dict(fixture)

	# Assert: A's relationship to B is kept (B was inserted in Pass 2 before Pass 3 runs).
	assert_bool(_hd_script.get("_heroes_loaded") as bool).override_failure_message(
		"AC-4 forward-ref: load must succeed"
	).is_true()

	assert_int(HeroDatabase._heroes[&"shu_001_liu_bei"].relationships.size()).override_failure_message(
		"AC-4 forward-ref: A's relationship to B must be kept when A is listed before B"
	).is_equal(1)


## AC-4 (back ref): B is listed BEFORE A in JSON. A's relationship references B.
## Same EC-5 check post-Pass-2 should find B in _heroes and keep A's relationship.
func test_back_ref_relationship_resolves_post_pass_2() -> void:
	# Arrange: wei_001 listed first; shu_001 listed second with rel targeting wei_001.
	var rel_a_to_b: Array[Dictionary] = [
		{"hero_b_id": "wei_001_cao_cao", "relation_type": "RIVAL",
		"effect_tag": "rival_bonus", "is_symmetric": false}
	]
	var fixture: Dictionary = {
		"wei_001_cao_cao": _make_test_record(1, []),
		"shu_001_liu_bei": _make_test_record(0, rel_a_to_b),
	}

	# Act
	HeroDatabase._load_heroes_from_dict(fixture)

	# Assert: A's relationship to B is kept (B was already in _heroes when Pass 3 runs).
	assert_bool(_hd_script.get("_heroes_loaded") as bool).override_failure_message(
		"AC-4 back-ref: load must succeed"
	).is_true()

	assert_int(HeroDatabase._heroes[&"shu_001_liu_bei"].relationships.size()).override_failure_message(
		"AC-4 back-ref: A's relationship to B must be kept when B is listed before A"
	).is_equal(1)


# ── AC-5: record load resilience (EC-4 + EC-5 + EC-6 simultaneously) ─────────


## AC-5: 4-record fixture exercising EC-4 + EC-5 + EC-6 simultaneously.
## A has EC-4 self-ref; B has EC-5 orphan FK; C↔D is the EC-6 conflict pair.
## All 4 records load; specific bad relationship entries dropped or kept per tier.
func test_3_record_fixture_with_ec4_ec5_ec6_simultaneously_loads_all_records() -> void:
	# Arrange:
	# A (shu_001): EC-4 self-ref → relationship dropped (0 rels remaining)
	var rel_a_self: Array[Dictionary] = [
		{"hero_b_id": "shu_001_liu_bei", "relation_type": "RIVAL",
		"effect_tag": "rival", "is_symmetric": false}
	]
	# B (shu_002): EC-5 orphan → relationship dropped (0 rels remaining)
	var rel_b_orphan: Array[Dictionary] = [
		{"hero_b_id": "qun_099_fictional", "relation_type": "ALLY",
		"effect_tag": "ally", "is_symmetric": false}
	]
	# C (wei_001) → D (wei_002): EC-6 conflict — both kept (1 rel each)
	var rel_c_to_d: Array[Dictionary] = [
		{"hero_b_id": "wei_002_zhang_liao", "relation_type": "RIVAL",
		"effect_tag": "rival", "is_symmetric": true}
	]
	var rel_d_to_c: Array[Dictionary] = [
		{"hero_b_id": "wei_001_cao_cao", "relation_type": "SWORN_BROTHER",
		"effect_tag": "sworn", "is_symmetric": true}
	]
	var fixture: Dictionary = {
		"shu_001_liu_bei": _make_test_record(0, rel_a_self),
		"shu_002_guan_yu": _make_test_record(0, rel_b_orphan),
		"wei_001_cao_cao": _make_test_record(1, rel_c_to_d),
		"wei_002_zhang_liao": _make_test_record(1, rel_d_to_c),
	}

	# Act
	HeroDatabase._load_heroes_from_dict(fixture)

	# Assert: all 4 records loaded (record-load resilience).
	assert_bool(_hd_script.get("_heroes_loaded") as bool).override_failure_message(
		"AC-5: _heroes_loaded must be true — all records load despite WARNING-tier violations"
	).is_true()

	assert_int(HeroDatabase._heroes.size()).override_failure_message(
		"AC-5: all 4 records must be present in _heroes"
	).is_equal(4)

	# EC-4: A's self-ref dropped (0 rels).
	assert_int(HeroDatabase._heroes[&"shu_001_liu_bei"].relationships.size()).override_failure_message(
		"AC-5: EC-4 — A's self-ref relationship must be dropped (0 remaining)"
	).is_equal(0)

	# EC-5: B's orphan dropped (0 rels).
	assert_int(HeroDatabase._heroes[&"shu_002_guan_yu"].relationships.size()).override_failure_message(
		"AC-5: EC-5 — B's orphan FK relationship must be dropped (0 remaining)"
	).is_equal(0)

	# EC-6: C's entry kept (1 rel).
	assert_int(HeroDatabase._heroes[&"wei_001_cao_cao"].relationships.size()).override_failure_message(
		"AC-5: EC-6 — C's relationship entry must be KEPT (1 remaining)"
	).is_equal(1)

	# EC-6: D's entry kept (1 rel).
	assert_int(HeroDatabase._heroes[&"wei_002_zhang_liao"].relationships.size()).override_failure_message(
		"AC-5: EC-6 — D's relationship entry must be KEPT (1 remaining)"
	).is_equal(1)


# ── AC-7: forbidden_pattern registration verified ────────────────────────────


## AC-7: docs/registry/architecture.yaml must contain both
## `hero_data_consumer_mutation` AND `hero_database_signal_emission` entries.
## Structural FileAccess read — no load required.
func test_forbidden_patterns_registered_in_architecture_yaml() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://docs/registry/architecture.yaml"
	)

	assert_bool(content.contains("hero_data_consumer_mutation")).override_failure_message(
		("AC-7: docs/registry/architecture.yaml must contain 'hero_data_consumer_mutation' "
		+ "forbidden_pattern entry (registered same-patch with ADR-0007 per §Migration Plan §6). "
		+ "If missing, add it to architecture.yaml citing ADR-0007 §7.")
	).is_true()

	assert_bool(content.contains("hero_database_signal_emission")).override_failure_message(
		("AC-7: docs/registry/architecture.yaml must contain 'hero_database_signal_emission' "
		+ "forbidden_pattern entry (registered same-patch with ADR-0007 per §Migration Plan §6). "
		+ "If missing, add it to architecture.yaml citing ADR-0007 §7.")
	).is_true()


# ── AC-8: get_relationships returns typed Array[Dictionary] ──────────────────


## AC-8: after WARNING-tier filtering, get_relationships returns Array[Dictionary]
## (typed). Typed assignment succeeds — confirms filtering doesn't demote the type.
func test_get_relationships_returns_typed_array_dictionary() -> void:
	# Arrange: one hero with a valid (non-WARNING) relationship.
	var valid_rel: Array[Dictionary] = [
		{"hero_b_id": "wei_001_cao_cao", "relation_type": "RIVAL",
		"effect_tag": "rival_bonus", "is_symmetric": false}
	]
	var fixture: Dictionary = {
		"shu_001_liu_bei": _make_test_record(0, valid_rel),
		"wei_001_cao_cao": _make_test_record(1, []),
	}
	HeroDatabase._load_heroes_from_dict(fixture)

	# Act + Assert: typed assignment of get_relationships return must succeed.
	# If the return type were demoted to untyped Array, this assignment would fail
	# at runtime with a type-boundary error, crashing the test (which would count
	# as an error, not a failure — detectable via `errors > 0` in Overall Summary).
	var rels: Array[Dictionary] = HeroDatabase.get_relationships(&"shu_001_liu_bei")

	assert_int(rels.size()).override_failure_message(
		"AC-8: get_relationships must return the 1 valid relationship entry"
	).is_equal(1)

	assert_str(rels[0].get("relation_type", "") as String).override_failure_message(
		"AC-8: relationship entry must contain expected relation_type"
	).is_equal("RIVAL")
