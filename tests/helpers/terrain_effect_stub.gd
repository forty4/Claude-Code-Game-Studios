## TerrainEffectStub — concrete subclass of TerrainEffect for DI seam tests.
##
## TerrainEffect is concrete `class_name TerrainEffect extends RefCounted`
## (per src/core/terrain_effect.gd). Could be instantiated directly via
## `TerrainEffect.new()`, but a stub class provides a clean test seam for
## future story tests that need to override `get_modifiers(...)` etc.
##
## No method overrides at story-001 — existence as a typed reference is the
## only requirement for DI binding.
class_name TerrainEffectStub
extends TerrainEffect
