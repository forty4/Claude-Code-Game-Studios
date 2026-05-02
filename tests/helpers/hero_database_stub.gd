## HeroDatabaseStub — concrete subclass of @abstract HeroDatabase for DI seam tests.
##
## HeroDatabase is `@abstract class_name HeroDatabase extends RefCounted` with
## all-static methods (per src/foundation/hero_database.gd). Direct
## `HeroDatabase.new()` is blocked at parse-time on typed references per G-22.
## A concrete subclass is required to instantiate for DI binding.
##
## No method overrides — HeroDatabase is all-static, so instance has no behavior
## to stub. Existence as a typed reference is the only requirement.
##
## NOTE: ADR-0014 §3 DI'd HeroDatabase as an instance (`hero_db: HeroDatabase`
## in setup() params) — by the same godot-specialist revision #2 logic that
## dropped DamageCalc from DI (all-static methods), HeroDatabase could also be
## dropped. Deferred to a future ADR-0014 amendment; story-001 honors the
## current DI pattern.
class_name HeroDatabaseStub
extends HeroDatabase
