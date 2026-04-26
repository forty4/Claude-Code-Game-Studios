## Test-only subclass for AC-DC-28 (EC-DC-12 bad_attack_type guard).
## Shadows attack_type as untyped int so tests can inject 99 to bypass enum binding.
## MUST NOT appear in any src/ file — static lint AC-DC-41 enforces in story-006.
class_name TestResolveModifiersBypass extends ResolveModifiers

# Shadow the parent's enum-typed attack_type with untyped int.
# Setting `instance.attack_type = 99` bypasses ResolveModifiers.AttackType enum binding.
@warning_ignore("shadowed_variable_base_class")
var attack_type: int = 0
