## InputRouter — Foundation-layer skeleton PLACEHOLDER.
##
## CONTEXT: Created during battle-hud story-001 (BattleHUD class skeleton + 9-param DI)
## as a TYPE PLACEHOLDER so `BattleHUD.setup(input_router: InputRouter, ...)` parses
## against ADR-0015 §3. Full implementation lives in the input-handling epic
## (production/epics/input-handling/), which is drafted (10 stories) but not yet shipped.
##
## When input-handling story-001 ("module skeleton and autoload registration") is
## implemented, this file will be REPLACED with the production InputRouter class per
## ADR-0005 §2 — 7-state FSM (S0..S6), autoload registration in project.godot, GameBus
## signal emissions (input_state_changed, input_mode_changed), action vocabulary, etc.
##
## See: docs/architecture/ADR-0005-input-handling.md, production/epics/input-handling/EPIC.md
class_name InputRouter
extends Node
