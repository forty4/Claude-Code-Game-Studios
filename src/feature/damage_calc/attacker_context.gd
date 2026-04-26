## AttackerContext — immutable-by-convention snapshot of the attacking unit's combat state.
## Constructed exclusively via make() in production code. .new() is reserved for bypass-seam tests (story-008).
class_name AttackerContext extends RefCounted

# Local provisional enum until ADR-0009 (UnitRole) lands.
# Values are locked to unit-role.md §EC-7 so migration to UnitRole.Class
# requires only a type annotation swap — no value changes at call sites.
enum Class { CAVALRY, SCOUT, INFANTRY, ARCHER }

var unit_id: StringName
## Maps to AttackerContext.Class enum (CAVALRY=0, SCOUT=1, INFANTRY=2, ARCHER=3) — local until ADR-0009 lands.
var unit_class: int = 0
## Pre-Damage-Calc-clamp ATK from HP/Status. Set at Grid Battle from
## hp_status.get_modified_stat(unit_id, &"atk"). DamageCalc applies
## clampi(raw_atk, 1, ATK_CAP) per ADR-0012 §8 + CR-3 (AC-DC-11/15).
var raw_atk: int = 0
var charge_active: bool = false
var defend_stance_active: bool = false
var passives: Array[StringName] = []


## Factory — the only sanctioned construction path in production code.
## Parameter order mirrors field declaration order (required fields first; all required for AttackerContext).
static func make(
		unit_id: StringName,
		unit_class: int,
		raw_atk: int,
		charge_active: bool,
		defend_stance_active: bool,
		passives: Array[StringName]) -> AttackerContext:
	var result := AttackerContext.new()
	result.unit_id = unit_id
	result.unit_class = unit_class
	result.raw_atk = raw_atk
	result.charge_active = charge_active
	result.defend_stance_active = defend_stance_active
	# passives assigned directly — caller owns the Array; DamageCalc reads passives read-only.
	# If defensive copy is needed for future mutation isolation, use assign() per G-2.
	result.passives = passives
	return result
