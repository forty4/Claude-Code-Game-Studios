## UnitRoleStub — concrete subclass of @abstract UnitRole for DI seam tests.
##
## UnitRole is `@abstract class_name UnitRole extends RefCounted` with all-static
## methods (per src/foundation/unit_role.gd). Direct `UnitRole.new()` is blocked
## at parse-time on typed references per G-22. A concrete subclass is required
## to instantiate for DI binding.
##
## No method overrides — UnitRole is all-static, so instance has no behavior
## to stub. Existence as a typed reference is the only requirement.
##
## NOTE: ADR-0014 §3 DI'd UnitRole as an instance — could be dropped from DI by
## the same godot-specialist revision #2 logic (all-static methods). Deferred
## to a future ADR-0014 amendment; story-001 honors the current DI pattern.
class_name UnitRoleStub
extends UnitRole
