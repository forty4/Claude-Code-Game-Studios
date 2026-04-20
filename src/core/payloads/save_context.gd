## SaveContext — payload for GameBus.save_checkpoint_requested.
## Emitter: ScenarioRunner (requests checkpoint).
## Stub — shape PROVISIONAL, owned by save-manager epic Story 001 (future).
## This class exists only so game_bus.gd signals parse; real fields land with save-manager epic.
##
## COORDINATION NOTE: class_name SaveContext and path src/core/payloads/save_context.gd
## are intentionally stable so save-manager epic Story 001 replaces this stub seamlessly
## without renaming the class or moving the file. Coordinate with save-manager epic before
## adding any fields here.
##
## TODO: shape locked by save-manager epic Story 001 — replace stub with authoritative schema when epic lands.
class_name SaveContext
extends Resource
