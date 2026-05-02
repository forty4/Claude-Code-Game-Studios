## BattleCameraStub — minimal Camera2D-based test stub for DI seam tests.
##
## Extends BattleCamera (`extends Camera2D`) so it satisfies the typed
## `_camera: BattleCamera` field on GridBattleController.
##
## `_ready()` override prevents the production BattleCamera._ready() from:
##   (a) calling make_current() — would steal viewport focus from test fixtures
##   (b) reading BalanceConstants.CAMERA_ZOOM_DEFAULT — avoids spurious cache load
##   (c) subscribing to GameBus.input_action_fired — avoids unintended signal wiring
##
## screen_to_grid() is NOT overridden at story-001 — story-003 FSM dispatch
## may require a stub override returning a fixed Vector2i for click hit-test
## tests; deferred to that story.
class_name BattleCameraStub
extends BattleCamera


func _ready() -> void:
	# No-op: skips production make_current() + zoom init + GameBus subscribe.
	pass


func _exit_tree() -> void:
	# No-op: production BattleCamera disconnects GameBus.input_action_fired here;
	# this stub never connects in _ready(), so no disconnect needed.
	pass
