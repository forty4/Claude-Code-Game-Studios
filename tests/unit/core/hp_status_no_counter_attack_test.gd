extends GdUnitTestSuite

## hp_status_no_counter_attack_test.gd
## Stub verification for HP/Status story-008 AC-9 (GDD AC-20 counter-attack interaction).
## Verifies that HPStatusController has ZERO counter-attack code paths (CR-13 rule 4 is
## Grid Battle / Damage Calc concern — NOT HP/Status concern per ADR-0010 §9 line 410).
##
## AC-9 verification:
##   (a) Source-file scan: `counter_attack` absent from hp_status_controller.gd (G-22 pattern)
##   (b) Functional: DEFEND_STANCE-active unit receives -50% damage AND no counter_attack
##       code path is activated from HP/Status side (structural coverage via source scan)
##
## Governing ADR: ADR-0010 — HP/Status §9 + Validation §9
## Design reference: production/epics/hp-status/story-008-perf-lints-and-td-entries.md §9
##
## G-15: before_test() / after_test() canonical hooks with BalanceConstants + UnitRole reset.
## G-22: source-file scan via FileAccess.get_file_as_string (abstract/method presence check).
## G-9:  Multi-line failure messages wrap concat in parens before % operator.


# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	add_child(_controller)


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	return hero


# ── AC-9 (a): Source-file scan — no counter_attack references ────────────────

## AC-9 (a): G-22 source-scan asserts `counter_attack` is completely absent from
## hp_status_controller.gd. CR-13 rule 4 ('DEFEND_STANCE units do NOT counter-attack')
## is Grid Battle / Damage Calc responsibility — NOT HP/Status's.
## HP/Status side must contain zero counter_attack references in its source.
func test_hp_status_controller_source_has_no_counter_attack_references() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://src/core/hp_status_controller.gd"
	)
	assert_bool(content.contains("counter_attack")).override_failure_message(
		("AC-9 (a): hp_status_controller.gd must contain ZERO 'counter_attack' references. "
		+ "CR-13 rule 4 (DEFEND_STANCE units do NOT counter-attack) is Grid Battle / Damage Calc concern. "
		+ "ADR-0010 §9 line 410 explicitly states HP/Status has no counter-attack responsibility.")
	).is_false()


# ── AC-9 (b): DEFEND_STANCE active unit receives -50% damage ─────────────────

## AC-9 (b): DEFEND_STANCE-active CAVALRY unit receives PHYSICAL 100 damage.
## F-1 Step 2: int(floor(100 * (1.0 - 0.50))) = 50 final_damage.
## HP reduction: 100 - 50 = 50 HP remaining.
## No counter-attack code path is activated from HP/Status side (source scan in AC-9(a) proves this).
##
## Uses CAVALRY (no passive_shield_wall) so Step 1 does not interfere with Step 2 isolation.
func test_defend_stance_active_unit_receives_50_percent_reduction_no_counter_attack_path() -> void:
	# Arrange: CAVALRY unit at HP=100 with DEFEND_STANCE active
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.CAVALRY)
	_controller._state_by_unit[1].current_hp = 100

	# Inject DEFEND_STANCE directly (bypass apply_status for test isolation)
	var ds_template: StatusEffect = load("res://assets/data/status_effects/defend_stance.tres") as StatusEffect
	assert_object(ds_template).override_failure_message(
		"Precondition: defend_stance.tres must exist at res://assets/data/status_effects/"
	).is_not_null()
	var ds_instance: StatusEffect = ds_template.duplicate()
	_controller._state_by_unit[1].status_effects.append(ds_instance)

	# Act: apply PHYSICAL 100 damage — DEFEND_STANCE -50% reduction applies
	_controller.apply_damage(1, 100, 0, [])

	# Assert: HP reduced by exactly 50 (100 × 0.50 = 50 final_damage; HP 100 → 50)
	var hp_after: int = _controller.get_current_hp(1)
	assert_int(hp_after).override_failure_message(
		("AC-9 (b): DEFEND_STANCE -50%%: PHYSICAL 100 → int(floor(100 * 0.50)) = 50 final_damage; "
		+ "expected HP=50; got %d. No counter-attack path should be activated from HP/Status side.") % hp_after
	).is_equal(50)

	# Assert: unit is still alive (not dead — HP=50 > 0)
	assert_bool(_controller.is_alive(1)).override_failure_message(
		"AC-9 (b): DEFEND_STANCE -50%% reduction should leave unit alive at HP=50 (not dead)"
	).is_true()
