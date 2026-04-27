## Boot-time build-mode sentinel — emits one [BUILD_MODE] log line at _ready().
##
## Release-config testing precondition for AC-DC-45 (TalkBack/VoiceOver
## walkthrough, deferred to Battle HUD epic). Chip-overlay UI portion is also
## Battle-HUD-deferred (see production/epics/damage-calc/
## story-009-accessibility-ui-tests.md §Deferred to Battle HUD Epic).
##
## Registered as autoload BuildModeSentinel in project.godot.
## No class_name declaration — autoload name IS the global identifier (G-3:
## declaring class_name on an autoload script hides the singleton and prevents
## direct access by the autoload name in the scene tree).
extends Node


## Returns the formatted [BUILD_MODE] log line without printing it.
## Separated from _ready() so unit tests can assert on the string directly
## without requiring GdUnit4 print-capture support (not available in v6.1.2).
func _compose_line() -> String:
	var mode: String = "release" if not OS.is_debug_build() else "debug"
	return "[BUILD_MODE] %s" % mode


## Emits exactly one build-mode log line to stdout at boot.
## Emission count is one by construction: _ready() is called once per Node
## lifecycle. Empirical verification: local-headless capture in
## production/qa/evidence/damage_calc_build_mode_sentinel.md.
func _ready() -> void:
	print(_compose_line())
