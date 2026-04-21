## GameBusDiagnostics — debug-only per-frame emit counter for GameBus.
##
## Connects to every user-declared signal on GameBus at boot and counts total
## emissions per frame. Fires push_warning when the soft cap (50 emits/frame)
## is exceeded. Stripped in release builds: _ready() calls queue_free() when
## OS.is_debug_build() returns false, leaving zero runtime footprint.
##
## ADR reference: ADR-0001 §Implementation Guidelines §8, §Validation Criteria V-5.
## Requirement:   TR-gamebus-001 (Story 005)
##
## NOTE: This script is registered as the "GameBusDiagnostics" autoload, so it must
## NOT declare class_name — the autoload name IS the global identifier. This mirrors
## the same rule that keeps game_bus.gd free of a class_name declaration.
##
## ─── TEST SEAMS (DO NOT USE IN PRODUCTION CODE) ─────────────────────────────
##
## _debug_build_override (static Variant, on the GDScript resource):
##   When non-null, _is_debug_build() returns this value instead of calling
##   OS.is_debug_build(). Set via: load(DIAGNOSTICS_PATH).set("_debug_build_override", false)
##   MUST be reset to null in after_test. Never set from production code.
##
## _soft_cap_warning_fired (signal):
##   Emitted in parallel with push_warning whenever the soft cap is exceeded.
##   Exists solely so tests can assert warning semantics by connecting a lambda
##   before triggering emissions. Production code must never connect to this
##   signal — no subscribers means zero overhead.
##
## set_cap(n: int):
##   Lowers or raises the cap for test scenarios (e.g. set_cap(5) so 6 emissions
##   trigger a warning deterministically). Production always uses DEFAULT_CAP.
##   Never call set_cap from non-test code.
##
## _connect_to_bus(bus: Node):
##   Exposed so tests can bypass _ready() and inject a fresh bus instance directly,
##   without depending on the /root/GameBus autoload tree position.
##
## ─────────────────────────────────────────────────────────────────────────────
extends Node

## Soft-cap per ADR-0001 §Implementation Guidelines §8.
## "50 emissions per frame, project-wide."
const DEFAULT_CAP: int = 50

## Test-only debug-build override. When non-null, _is_debug_build() returns
## this value instead of OS.is_debug_build(). Access from tests via the loaded
## GDScript resource: load(PATH).set("_debug_build_override", false).
## MUST be reset to null in after_test. Never set from production code.
static var _debug_build_override: Variant = null

## Fires when the soft cap is exceeded, before push_warning is called.
## Intended exclusively as a test-observation seam.
## Production code MUST NOT connect to this signal.
signal _soft_cap_warning_fired(message: String, total: int, domain_counts: Dictionary)

## Active cap value. Defaults to DEFAULT_CAP. Override in tests via set_cap().
var _cap: int = DEFAULT_CAP

## Running tally of GameBus signal emissions in the current frame.
## Incremented in _on_any_emit; reset at end of _process.
var _emits_this_frame: int = 0

## Per-domain emission counts. 10 buckets matching ADR-0001 §Signal Contract
## Schema domain banners. All reset at end of each _process call.
var _domain_counts: Dictionary = {
	"scenario": 0,
	"battle": 0,
	"turn": 0,
	"unit": 0,
	"destiny": 0,
	"beat": 0,
	"input": 0,
	"ui": 0,
	"save": 0,
	"environment": 0,
}

## Signal-name → domain-key lookup. Populated once at connect time by
## _connect_to_bus(). Zero-allocation hot path: _on_any_emit uses Dictionary.get().
var _signal_to_domain: Dictionary = {}


# ── Virtual methods ────────────────────────────────────────────────────────────


func _ready() -> void:
	if not _is_debug_build():
		queue_free()
		return
	var bus: Node = get_node_or_null("/root/GameBus")
	if bus == null:
		push_warning("GameBusDiagnostics: /root/GameBus not found — diagnostics inactive.")
		queue_free()
		return
	_connect_to_bus(bus)


func _process(_delta: float) -> void:
	if _emits_this_frame > _cap:
		_fire_soft_cap_warning()
	# Reset AFTER the check (not before) — ensures a full frame's worth of emits
	# is captured even if the emitting code runs after diagnostics in tick order.
	_emits_this_frame = 0
	_reset_domain_counts()


# ── Public API ─────────────────────────────────────────────────────────────────


## Override the soft-cap for test scenarios.
## Production code always uses DEFAULT_CAP (50). Never call this from non-test code.
## Example: set_cap(5) to trigger a warning with just 6 emissions in a test.
func set_cap(n: int) -> void:
	_cap = n


## Connects a one-arity handler to every user-declared signal on bus.
## Pre-computes the signal→domain lookup so _on_any_emit has zero allocations.
## Uses .bind(sig_name).unbind(arg_count) so the handler always receives exactly
## one argument (the signal name), regardless of the signal's declared arity.
## Exposed as a non-underscore-prefixed method so tests can inject a bus directly
## without depending on _ready() / /root/GameBus tree lookup.
func _connect_to_bus(bus: Node) -> void:
	for sig_info: Dictionary in _get_user_signals(bus):
		var sig_name: String = sig_info["name"] as String
		var arg_count: int = (sig_info["args"] as Array).size()
		_signal_to_domain[sig_name] = _route_to_domain(sig_name)
		var handler: Callable = Callable(self, "_on_any_emit").bind(sig_name).unbind(arg_count)
		bus.connect(sig_name, handler)


# ── Private methods ────────────────────────────────────────────────────────────


## Returns true if running in a debug build.
## Consults _debug_build_override (when non-null) before calling OS.is_debug_build().
## The override exists solely so tests can simulate release-build behavior.
static func _is_debug_build() -> bool:
	if _debug_build_override != null:
		return _debug_build_override as bool
	return OS.is_debug_build()


## Handler bound to every GameBus signal via _connect_to_bus.
## Payload args are discarded by .unbind(); only sig_name reaches this function.
##
## PERFORMANCE TRADE-OFF (tracked as TD-012):
##   This handler performs 2 Dictionary reads/writes per emission (_signal_to_domain.get
##   + _domain_counts[domain] = ...). Strict engine-code.md zero-alloc rule would require
##   10 individual `var _count_<domain>: int` members + a match statement instead.
##
##   We chose the Dictionary form because:
##     (a) diagnostic is debug-only — queue_free'd in release builds (_ready early-return)
##     (b) measured overhead is 0.53 µs/emission = ~0.016 ms/frame at 30 emits/frame,
##         which is 6× under the <0.1 ms/frame budget per ADR-0001 §8
##     (c) 10 fixed keys → predictable 10 writes/frame, no unbounded growth
##
##   Revisit if: measured overhead approaches the 0.1 ms/frame budget, OR if the
##   diagnostic is ever retained in release builds for telemetry.
func _on_any_emit(sig_name: String) -> void:
	_emits_this_frame += 1
	var domain: String = _signal_to_domain.get(sig_name, "unknown") as String
	_domain_counts[domain] = (_domain_counts.get(domain, 0) as int) + 1


## Emits _soft_cap_warning_fired (test seam) then push_warning.
## Called at most once per _process — the counter reset that follows prevents
## double-warning within the same frame.
func _fire_soft_cap_warning() -> void:
	var parts: Array[String] = []
	for key: String in _domain_counts:
		parts.append("%s=%d" % [key, _domain_counts[key] as int])
	var domain_str: String = ", ".join(parts)
	var message: String = (
		"GameBus soft cap exceeded: %d emits this frame (cap=%d). Top domains: [%s]"
		% [_emits_this_frame, _cap, domain_str]
	)
	# Emit test-seam signal FIRST so connected lambdas capture it before push_warning.
	_soft_cap_warning_fired.emit(message, _emits_this_frame, _domain_counts.duplicate())
	push_warning(message)


## Resets all 10 domain count buckets to 0.
func _reset_domain_counts() -> void:
	for key: String in _domain_counts:
		_domain_counts[key] = 0


## Maps a signal name to its ADR-0001 domain key via prefix matching.
## Rules mirror ADR-0001 §Signal Contract Schema domain groupings.
## The scene_ branch covers scene_transition_failed (UI/Flow domain per ADR §8).
## Note: the story's Implementation Notes §2 example omits scene_ — this is a
## spec gap; the ADR §Signal Contract Schema §8 is authoritative.
func _route_to_domain(sig_name: String) -> String:
	# battle_prepare_requested and battle_launch_requested carry the "battle_" prefix
	# but belong to Scenario Progression domain per ADR-0001 §Signal Contract Schema §1
	# (emitter: ScenarioRunner). Explicit name matches MUST precede the prefix rule.
	if sig_name == "battle_prepare_requested" or sig_name == "battle_launch_requested":
		return "scenario"
	if sig_name.begins_with("scenario_") or sig_name.begins_with("chapter_"):
		return "scenario"
	if sig_name.begins_with("battle_"):
		return "battle"
	if sig_name.begins_with("round_") or sig_name.begins_with("unit_turn_"):
		return "turn"
	if sig_name.begins_with("unit_"):
		return "unit"
	if sig_name.begins_with("destiny_"):
		return "destiny"
	if sig_name.begins_with("beat_"):
		return "beat"
	if sig_name.begins_with("input_"):
		return "input"
	if sig_name.begins_with("ui_") or sig_name.begins_with("scene_"):
		return "ui"
	if sig_name.begins_with("save_"):
		return "save"
	if sig_name.begins_with("tile_"):
		return "environment"
	return "unknown"


## Returns only user-declared signals on a Node, filtering out inherited Node signals.
## Uses a dynamic baseline (bare Node.new()) so Godot version upgrades that add new
## built-in Node signals never require a manual update here.
## Replicates the pattern from signal_contract_test.gd for consistency.
func _get_user_signals(bus: Node) -> Array[Dictionary]:
	var baseline: Node = Node.new()
	var inherited: Array[String] = []
	for sig: Dictionary in baseline.get_signal_list():
		inherited.append(sig["name"] as String)
	baseline.free()
	var user_signals: Array[Dictionary] = []
	for sig: Dictionary in bus.get_signal_list():
		if not (sig["name"] as String) in inherited:
			user_signals.append(sig)
	return user_signals
