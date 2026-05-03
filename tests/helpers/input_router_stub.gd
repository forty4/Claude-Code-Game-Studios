## InputRouterStub — minimal test stub for InputRouter DI seam.
##
## Extends InputRouter (Node) so it satisfies the typed
## `_input_router: InputRouter` field on BattleHUD.
##
## This stub is intentionally minimal: the InputRouter placeholder
## (src/foundation/input_router.gd) declares only `class_name InputRouter
## extends Node` — no signals, no methods, no `_ready()` body. Therefore
## this stub needs no overrides at story-001; all it does is provide an
## InputRouter-typed instance for the 9-param DI seam.
##
## When input-handling story-001 ships the production InputRouter (7-state
## FSM, autoload registration, GameBus signal emissions), this stub will need
## to override `_ready()` to prevent the production autoload registration from
## firing during tests — analogous to BattleCameraStub._ready() suppressing
## make_current() + GameBus.input_action_fired subscription.
##
## See: src/foundation/input_router.gd (placeholder), ADR-0005-input-handling.md,
## production/epics/input-handling/EPIC.md
class_name InputRouterStub
extends InputRouter
