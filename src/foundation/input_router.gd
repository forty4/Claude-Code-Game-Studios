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


## InputState — 7-state FSM enum per ADR-0005 §1.
##
## Front-loaded here as a cross-epic placeholder so battle-hud story-002 can use
## `InputRouter.InputState.INPUT_BLOCKED` (S5) instead of a magic literal. The
## production InputRouter (input-handling epic) keeps this enum unchanged as
## part of its full 7-state FSM implementation. Names + ordinals are ratified
## contract surface — do NOT renumber or rename.
enum InputState {
	OBSERVATION = 0,           ## S0 — reading beat (default)
	UNIT_SELECTED = 1,         ## S1 — unit highlighted, action menu shown
	MOVEMENT_PREVIEW = 2,      ## S2 — destination chosen, ghost shown, awaiting confirm
	ATTACK_TARGET_SELECT = 3,  ## S3 — attack range shown, awaiting target
	ATTACK_CONFIRM = 4,        ## S4 — target chosen, damage preview shown, awaiting confirm
	INPUT_BLOCKED = 5,         ## S5 — enemy phase or animation; grid input silenced
	MENU_OPEN = 6,             ## S6 — overlay menu/dialog active
}
