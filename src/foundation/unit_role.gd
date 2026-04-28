## unit_role.gd
## Foundation-layer stateless gameplay rules calculator per ADR-0009 §Engine Compatibility.
## 4-precedent class_name+RefCounted+all-static pattern (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009).
## non-emitter per ADR-0001 line 375: zero signal declarations, zero signal emissions,
## zero signal subscriptions. All methods are static. UnitRole.new() is blocked at
## parse time on typed references by @abstract (typed `var x: UnitRole = UnitRole.new()`
## triggers "Cannot construct abstract class" at GDScript reload). Reflective paths
## (`script.new()`) bypass @abstract entirely — see G-22 in .claude/rules/godot-4x-gotchas.md.
## Call static methods directly (e.g. UnitRole.UnitClass.CAVALRY).
@abstract
class_name UnitRole
extends RefCounted


## UnitClass enum — 6 class profiles with explicit integer backing values.
## Backing values 0..5 match entities.yaml + Dictionary key expectations.
enum UnitClass {
	CAVALRY    = 0,
	INFANTRY   = 1,
	ARCHER     = 2,
	STRATEGIST = 3,
	COMMANDER  = 4,
	SCOUT      = 5,
}


## Lazy-init guard flag for the coefficient data cache.
## Populated by _load_coefficients() (Story 002). This story ships the declaration only.
static var _coefficients_loaded: bool = false
