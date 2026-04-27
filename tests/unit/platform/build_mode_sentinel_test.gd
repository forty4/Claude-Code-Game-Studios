## Unit tests for the BuildModeSentinel autoload.
## Covers story-009 AC-1 (boot-log content) and AC-3 (mode-string oracle).
##
## AC-1 two-pronged coverage:
##   - Content verified here by asserting _compose_line() return value.
##   - Emission-count-of-one verified empirically by local-headless boot capture
##     in production/qa/evidence/damage_calc_build_mode_sentinel.md.
##
## Test strategy: assert _compose_line() directly rather than intercepting
## print() output. GdUnit4 v6.1.2 has no print-capture API; the refactor
## pattern (expose _compose_line() -> String, call it from _ready()) is the
## cleanest testable alternative per story-009 Implementation Notes.
##
## Load pattern: script loaded via load() rather than class_name reference
## because autoload scripts must not declare class_name (G-3: declaring
## class_name on an autoload hides the singleton and causes "hides an autoload
## singleton" errors in the editor). load() gives us a fresh instance
## exercising the same script registered as the BuildModeSentinel autoload.
extends GdUnitTestSuite


## Script reference — loaded once at class scope; instantiated per test.
var _script: GDScript = load("res://src/platform/build_mode_sentinel.gd")

## Sentinel instance under test — recreated in before_test for isolation.
var _sentinel: Node


## Per-test setup. Uses before_test() — the GdUnit4 v6.1.2 per-test hook (G-15).
func before_test() -> void:
	_sentinel = _script.new() as Node
	add_child(_sentinel)


## Per-test teardown.
func after_test() -> void:
	if is_instance_valid(_sentinel):
		remove_child(_sentinel)
		_sentinel.free()
	_sentinel = null


# ---------------------------------------------------------------------------
# AC-1 — boot-log line format
# ---------------------------------------------------------------------------

## AC-1a: _compose_line() returns a string starting with "[BUILD_MODE] ".
## Verifies the sentinel would emit the correct prefix when _ready() fires.
## Emission-count-of-one is covered empirically by local-headless capture
## in production/qa/evidence/damage_calc_build_mode_sentinel.md.
func test_compose_line_contains_build_mode_prefix() -> void:
	var line: String = _sentinel._compose_line()
	assert_str(line).starts_with("[BUILD_MODE] ")


# ---------------------------------------------------------------------------
# AC-3 — mode string matches OS.is_debug_build() truth value
# ---------------------------------------------------------------------------

## AC-3a: mode string is "debug" when OS.is_debug_build() is true,
## "release" otherwise. Uses OS.is_debug_build() as oracle — no hardcoding
## on either side, so the test is valid for both debug and release configs.
func test_compose_line_mode_matches_os_is_debug_build() -> void:
	var expected_mode: String = "debug" if OS.is_debug_build() else "release"
	var expected_line: String = "[BUILD_MODE] %s" % expected_mode
	var actual_line: String = _sentinel._compose_line()
	assert_str(actual_line).is_equal(expected_line)
