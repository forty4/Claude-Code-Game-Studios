extends GdUnitTestSuite

## game_bus_diagnostics_test.gd
## Unit tests for Story 005: GameBusDiagnostics — debug-only 50-emit/frame soft cap.
##
## Covers AC-1 through AC-7 per story QA Test Cases.
##
## TEST SEAMS USED:
##   diagnostics_script.set("_debug_build_override", false) — simulates release build (AC-4).
##     Accessed via the loaded GDScript resource because the autoload name collision rule
##     forbids class_name on autoload scripts (same constraint as game_bus.gd).
##   diagnostics._soft_cap_warning_fired — connected via lambda before emissions so
##     captures are synchronous (no await needed). Array-based capture pattern used
##     throughout because GdUnit4 v6.1.2 has no synchronous signal-count assertion
##     (assert_signal is async-only via is_emitted / is_not_emitted).
##   diagnostics.set_cap(n) — lowers cap to 5 so 6 emissions reliably trigger a warning.
##   diagnostics._connect_to_bus(bus) — bypasses _ready() so tests inject a fresh bus
##     instance without depending on the /root/GameBus autoload tree position.
##
## ISOLATION STRATEGY:
##   Each test creates a fresh GameBus instance via load()+new() and a fresh diagnostics
##   instance via load()+new(). _connect_to_bus() is called directly on the diagnostics
##   instance so tests are independent of autoload tree state.
##   AC-4 is the exception: it calls add_child(diagnostics) so _ready() fires naturally,
##   allowing is_queued_for_deletion() to verify the release-build path.
##
## LIFECYCLE:
##   before_test — reset _debug_build_override to null on the script resource
##   after_test  — reset _debug_build_override to null (primary guard)

const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"
const DIAGNOSTICS_PATH: String = "res://src/core/game_bus_diagnostics.gd"


func before_test() -> void:
	(load(DIAGNOSTICS_PATH) as GDScript).set("_debug_build_override", null)


func after_test() -> void:
	(load(DIAGNOSTICS_PATH) as GDScript).set("_debug_build_override", null)


# ── Helpers ───────────────────────────────────────────────────────────────────


## Creates a fresh GameBus script instance (not the autoload singleton).
func _make_bus() -> Node:
	return auto_free((load(GAME_BUS_PATH) as GDScript).new())


## Creates a diagnostics Node connected to the given bus, with cap=5.
## Bypasses _ready() to avoid /root/GameBus tree dependency.
func _make_diagnostics_connected(bus: Node) -> Node:
	var d: Node = auto_free((load(DIAGNOSTICS_PATH) as GDScript).new())
	d.set_cap(5)
	d._connect_to_bus(bus)
	return d


# ── AC-1: Warning fires at cap+1 ──────────────────────────────────────────────


## AC-1: Exactly one _soft_cap_warning_fired emission when emit count exceeds cap.
## Given cap=5, emitting 6 signals in one frame must fire the warning exactly once.
func test_diagnostics_fires_warning_once_at_cap_plus_one() -> void:
	# Arrange
	var bus: Node = _make_bus()
	var diagnostics: Node = _make_diagnostics_connected(bus)

	var captures: Array = []
	diagnostics._soft_cap_warning_fired.connect(
		func(msg: String, total: int, domains: Dictionary) -> void:
			captures.append({"msg": msg, "total": total, "domains": domains})
	)

	# Act — emit 6 signals (cap is 5; 6 > 5 triggers warning)
	for idx: int in 6:
		bus.chapter_started.emit("ch_%d" % idx, idx)
	diagnostics._process(0.0)

	# Assert — warning fired exactly once
	assert_int(captures.size()).override_failure_message(
		"Expected exactly 1 _soft_cap_warning_fired emission, got %d" % captures.size()
	).is_equal(1)

	# Assert — message mentions the correct total
	assert_str(captures[0].msg as String).override_failure_message(
		"Warning message missing '6 emits': '%s'" % captures[0].msg
	).contains("6 emits")


## AC-1 edge: No warning fires when emit count is exactly at cap (not above).
## Given cap=5, emitting exactly 5 signals must produce zero warnings.
func test_diagnostics_does_not_warn_at_or_below_cap() -> void:
	# Arrange
	var bus: Node = _make_bus()
	var diagnostics: Node = _make_diagnostics_connected(bus)

	var captures: Array = []
	diagnostics._soft_cap_warning_fired.connect(
		func(_msg: String, _total: int, _domains: Dictionary) -> void:
			captures.append(true)
	)

	# Act — emit exactly 5 signals (equal to cap; condition is > not >=, so no warning)
	for idx: int in 5:
		bus.chapter_started.emit("ch_%d" % idx, idx)
	diagnostics._process(0.0)

	# Assert — no warning
	assert_int(captures.size()).override_failure_message(
		"Expected zero _soft_cap_warning_fired emissions at cap boundary, got %d" % captures.size()
	).is_equal(0)


# ── AC-2: Counter resets between frames ───────────────────────────────────────


## AC-2: Counter resets correctly between _process calls.
## Frame N: 6 emits → warning. Frame N+1: 3 emits → no warning. Frame N+2: 4 emits → no warning.
func test_diagnostics_resets_counter_between_frames() -> void:
	# Arrange
	var bus: Node = _make_bus()
	var diagnostics: Node = _make_diagnostics_connected(bus)

	var captures: Array = []
	diagnostics._soft_cap_warning_fired.connect(
		func(_msg: String, _total: int, _domains: Dictionary) -> void:
			captures.append(true)
	)

	# Frame N — 6 emits → warning expected
	for idx: int in 6:
		bus.chapter_started.emit("ch_%d" % idx, idx)
	diagnostics._process(0.0)

	assert_int(captures.size()).override_failure_message(
		"Frame N: expected 1 warning emission, got %d" % captures.size()
	).is_equal(1)

	# Frame N+1 — 3 emits, below cap
	for idx: int in 3:
		bus.round_started.emit(idx)
	diagnostics._process(0.0)

	assert_int(captures.size()).override_failure_message(
		"Frame N+1: expected still 1 total warning emission (no new warning), got %d" % captures.size()
	).is_equal(1)

	# Frame N+2 — 4 emits, below cap
	for idx: int in 4:
		bus.unit_died.emit(idx)
	diagnostics._process(0.0)

	assert_int(captures.size()).override_failure_message(
		"Frame N+2: expected still 1 total warning emission (no new warning), got %d" % captures.size()
	).is_equal(1)


# ── AC-3: Domain breakdown in warning message ─────────────────────────────────


## AC-3: Warning message contains per-domain breakdown.
## Emit 3 scenario, 2 battle, 2 environment signals (total 7 > cap 5).
## Warning message must contain scenario=3, battle=2, environment=2.
func test_diagnostics_warning_includes_domain_breakdown() -> void:
	# Arrange
	var bus: Node = _make_bus()
	var diagnostics: Node = _make_diagnostics_connected(bus)

	# Array-of-dicts capture: lambdas can call .append() on an Array reference but
	# CANNOT reassign outer primitive locals (String, int) — those stay at their
	# initial value in the enclosing scope. GDScript 4.x lambda capture rule.
	var captures: Array = []
	diagnostics._soft_cap_warning_fired.connect(
		func(msg: String, total: int, domains: Dictionary) -> void:
			captures.append({"msg": msg, "total": total, "domains": domains})
	)

	# Act — 3 scenario signals (chapter_started = scenario domain)
	for idx_s: int in 3:
		bus.chapter_started.emit("ch_%d" % idx_s, idx_s)
	# 2 battle signals (battle_outcome_resolved = battle domain)
	bus.battle_outcome_resolved.emit(BattleOutcome.new())
	bus.battle_outcome_resolved.emit(BattleOutcome.new())
	# 2 environment signals (tile_destroyed = environment domain)
	# Explicit coords — no loop variable reference after loop end (Fix 3)
	bus.tile_destroyed.emit(Vector2i(0, 0))
	bus.tile_destroyed.emit(Vector2i(1, 0))

	diagnostics._process(0.0)

	# Assert — exactly one warning fired
	assert_int(captures.size()).override_failure_message(
		"Expected exactly 1 _soft_cap_warning_fired emission, got %d" % captures.size()
	).is_equal(1)

	var cap: Dictionary = captures[0] as Dictionary
	var captured_total: int = cap["total"] as int
	var captured_domains: Dictionary = cap["domains"] as Dictionary
	var captured_msg: String = cap["msg"] as String

	# Assert — total
	assert_int(captured_total).override_failure_message(
		"Expected captured total=7, got %d" % captured_total
	).is_equal(7)

	# Assert — domain counts in the captured Dictionary
	assert_int(captured_domains.get("scenario", -1) as int).override_failure_message(
		"Expected domain_counts.scenario=3, got %s" % str(captured_domains.get("scenario"))
	).is_equal(3)

	assert_int(captured_domains.get("battle", -1) as int).override_failure_message(
		"Expected domain_counts.battle=2, got %s" % str(captured_domains.get("battle"))
	).is_equal(2)

	assert_int(captured_domains.get("environment", -1) as int).override_failure_message(
		"Expected domain_counts.environment=2, got %s" % str(captured_domains.get("environment"))
	).is_equal(2)

	# Assert — message string contains key domain segments
	assert_str(captured_msg).override_failure_message(
		"Warning message missing 'scenario=3': '%s'" % captured_msg
	).contains("scenario=3")

	assert_str(captured_msg).override_failure_message(
		"Warning message missing 'battle=2': '%s'" % captured_msg
	).contains("battle=2")

	assert_str(captured_msg).override_failure_message(
		"Warning message missing 'environment=2': '%s'" % captured_msg
	).contains("environment=2")

	assert_str(captured_msg).override_failure_message(
		"Warning message missing 'exceeded' keyword: '%s'" % captured_msg
	).contains("exceeded")


# ── AC-4: Release-build strip ─────────────────────────────────────────────────


## AC-4: Diagnostics node self-destructs in release builds.
## _ready() must call queue_free(), leave _signal_to_domain empty, and not
## increment _emits_this_frame. Verified via is_queued_for_deletion() (synchronous).
func test_diagnostics_skips_setup_in_release_build() -> void:
	# Arrange — simulate release build BEFORE the node enters the tree
	(load(DIAGNOSTICS_PATH) as GDScript).set("_debug_build_override", false)

	var diagnostics: Node = (load(DIAGNOSTICS_PATH) as GDScript).new()

	# Act — add_child triggers _ready() which must call queue_free()
	add_child(diagnostics)

	# Assert — queue_free() was called synchronously inside _ready()
	assert_bool(diagnostics.is_queued_for_deletion()).override_failure_message(
		"Release-build strip failed: diagnostics did not call queue_free() in _ready()."
	).is_true()

	# Assert — connect loop did not run (no domain mappings populated)
	assert_bool((diagnostics._signal_to_domain as Dictionary).is_empty()).override_failure_message(
		"Release-build strip failed: _signal_to_domain was populated (connect loop ran despite release mode)."
	).is_true()

	# Assert — counter was never incremented
	assert_int(diagnostics._emits_this_frame as int).override_failure_message(
		"Release-build strip failed: _emits_this_frame is non-zero."
	).is_equal(0)

	# Belt-and-suspenders reset here; after_test will also reset.
	(load(DIAGNOSTICS_PATH) as GDScript).set("_debug_build_override", null)
	# diagnostics is already queued for deletion — let Godot handle it, no auto_free


# ── AC-5: Diagnostics emits nothing on GameBus ────────────────────────────────


## AC-5: GameBusDiagnostics does not emit any signals on GameBus itself.
## Track a 6-signal sample covering 6 of the 10 domains. This is a smell check
## rather than a full 27-signal proof — diagnostics has no .emit() calls on bus
## by construction, so sampling is sufficient. A full-coverage proof would require
## iterating GameBus.get_signal_list() and connecting a spy to each, which we defer
## as tech-debt (not worth the test-LoC for a construction-enforced invariant).
func test_diagnostics_emits_no_signals_on_gamebus() -> void:
	# Arrange
	var bus: Node = _make_bus()
	var diagnostics: Node = _make_diagnostics_connected(bus)

	var chapter_captures: Array = []
	var battle_captures: Array = []
	var round_captures: Array = []
	var unit_captures: Array = []
	var tile_captures: Array = []
	var save_captures: Array = []

	bus.chapter_started.connect(
		func(_id: String, _n: int) -> void: chapter_captures.append(true)
	)
	bus.battle_outcome_resolved.connect(
		func(_o: BattleOutcome) -> void: battle_captures.append(true)
	)
	bus.round_started.connect(
		func(_r: int) -> void: round_captures.append(true)
	)
	bus.unit_died.connect(
		func(_u: int) -> void: unit_captures.append(true)
	)
	bus.tile_destroyed.connect(
		func(_c: Vector2i) -> void: tile_captures.append(true)
	)
	bus.save_persisted.connect(
		func(_ch: int, _cp: int) -> void: save_captures.append(true)
	)

	# Act — emit 6 chapter_started signals to exceed cap, then run _process
	for idx: int in 6:
		bus.chapter_started.emit("ch_%d" % idx, idx)
	diagnostics._process(0.0)

	# Assert — chapter_started fired EXACTLY the 6 we emitted, no more.
	# A diagnostics that re-emitted on incoming signals would inflate this count.
	assert_int(chapter_captures.size()).override_failure_message(
		"chapter_started fired %d times, expected exactly 6 — diagnostics may be re-emitting on received signals" % chapter_captures.size()
	).is_equal(6)

	# Assert — other sampled signals did not fire (diagnostics must not emit on GameBus)
	assert_int(battle_captures.size()).override_failure_message(
		"battle_outcome_resolved fired unexpectedly (%d times) — diagnostics must not emit on GameBus" % battle_captures.size()
	).is_equal(0)

	assert_int(round_captures.size()).override_failure_message(
		"round_started fired unexpectedly (%d times)" % round_captures.size()
	).is_equal(0)

	assert_int(unit_captures.size()).override_failure_message(
		"unit_died fired unexpectedly (%d times)" % unit_captures.size()
	).is_equal(0)

	assert_int(tile_captures.size()).override_failure_message(
		"tile_destroyed fired unexpectedly (%d times)" % tile_captures.size()
	).is_equal(0)

	assert_int(save_captures.size()).override_failure_message(
		"save_persisted fired unexpectedly (%d times)" % save_captures.size()
	).is_equal(0)


# ── AC-6: Overhead advisory check ────────────────────────────────────────────


## AC-6: Diagnostic overhead advisory — NOT a hard performance gate.
## Emit 30 signals per frame for 60 frames (1800 total; all under default cap=50).
## Measures wall time and prints the result. Asserts only a very generous bound
## (10 ms for 1800 emissions ≈ 5.5 µs/emission — ~100× the target budget of 0.1ms/frame).
## This sanity check catches catastrophic regressions only.
## Platform-variable: do not treat this as a CI hard gate.
func test_diagnostics_overhead_under_advisory_budget() -> void:
	# Arrange — use default cap (50) so no warning overhead during measurement
	var bus: Node = _make_bus()
	var diagnostics: Node = auto_free((load(DIAGNOSTICS_PATH) as GDScript).new())
	diagnostics._connect_to_bus(bus)

	var frame_count: int = 60
	var emits_per_frame: int = 30

	# Act — measure wall time for 60 simulated frames
	var start_usec: int = Time.get_ticks_usec()

	for _frame: int in frame_count:
		for idx: int in emits_per_frame:
			bus.chapter_started.emit("ch_%d" % idx, idx)
		diagnostics._process(0.0)

	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var elapsed_ms: float = float(elapsed_usec) / 1000.0
	var total_emits: int = frame_count * emits_per_frame
	var per_emit_us: float = float(elapsed_usec) / float(total_emits)

	# Log result (advisory)
	print(
		"[AC-6 PERF] GameBusDiagnostics overhead: %.3f ms for %d total emissions across %d frames (%.2f µs/emission)"
		% [elapsed_ms, total_emits, frame_count, per_emit_us]
	)

	# Sanity ceiling — 10 ms for 1800 emissions. Fails only on catastrophic regression.
	# This is NOT the performance budget; it is a smoke check.
	assert_float(elapsed_ms).override_failure_message(
		("[AC-6 SANITY] Diagnostic overhead %.3f ms exceeded 10 ms sanity ceiling for %d emissions."
		+ " Investigate before treating as a budget issue.") % [elapsed_ms, total_emits]
	).is_less(10.0)


# ── AC-7: Determinism ─────────────────────────────────────────────────────────


## AC-7: Results are deterministic across repeated runs within the same test session.
## Run the AC-1 scenario 10 times sequentially with fresh instances each time;
## assert every run produces exactly 1 warning — matches story AC-7 "10 consecutive runs".
func test_diagnostics_is_deterministic() -> void:
	var warning_counts: Array[int] = []

	for _run: int in 10:
		var bus: Node = _make_bus()
		var diagnostics: Node = _make_diagnostics_connected(bus)

		var captures: Array = []
		diagnostics._soft_cap_warning_fired.connect(
			func(_msg: String, _total: int, _domains: Dictionary) -> void:
				captures.append(true)
		)

		for idx: int in 6:
			bus.chapter_started.emit("ch_%d" % idx, idx)
		diagnostics._process(0.0)

		warning_counts.append(captures.size())

	# Assert — all 10 runs produced exactly 1 warning
	for run: int in 10:
		assert_int(warning_counts[run]).override_failure_message(
			"Run %d produced %d warning emission(s), expected exactly 1 — non-deterministic result"
			% [run, warning_counts[run]]
		).is_equal(1)


# ── Domain routing regression test ────────────────────────────────────────────


## Regression guard: every one of the 28 declared GameBus signals routes to the
## expected domain bucket per ADR-0001 §Signal Contract Schema (incl. ADR-0011 victory_condition_detected).
##
## Protects against _route_to_domain rule-ordering bugs — e.g. swapping the
## unit_turn_ and unit_ rules would silently misroute unit_died to "turn".
## Also catches the battle_prepare_requested / battle_launch_requested bug found
## during story-005 /code-review: those two signals carry the "battle_" prefix but
## belong to the Scenario Progression domain (ADR-0001 §1, emitter: ScenarioRunner).
## Explicit name-match rules were added before the "battle_" prefix rule to fix this.
##
## If a new signal is added to GameBus without updating this map, the test will
## detect the mismatch when it iterates all user-declared signals on the bus.
func test_diagnostics_route_to_domain_covers_all_28_signals() -> void:
	# Arrange — expected signal → domain per ADR-0001 §Signal Contract Schema
	# Ordered by schema section to make ADR → test tracing straightforward.
	var expected: Dictionary = {
		# §1 Scenario Progression (emitter: ScenarioRunner)
		# NOTE: battle_prepare_requested and battle_launch_requested carry the "battle_"
		# prefix but belong here — explicit name-match rules guard this in _route_to_domain.
		"chapter_started":           "scenario",
		"battle_prepare_requested":  "scenario",
		"battle_launch_requested":   "scenario",
		"chapter_completed":         "scenario",
		"scenario_complete":         "scenario",
		"scenario_beat_retried":     "scenario",
		# §2 Grid Battle (emitter: BattleController)
		"battle_outcome_resolved":   "battle",
		# §3 Turn Order (emitter: TurnOrderRunner)
		"round_started":             "turn",
		"unit_turn_started":         "turn",
		"unit_turn_ended":           "turn",
		"victory_condition_detected": "turn",
		# §4 HP/Status (emitter: HPStatusController)
		"unit_died":                 "unit",
		# §5 Destiny (emitter: DestinyBranchJudge / DestinyStateStore)
		"destiny_branch_chosen":     "destiny",
		"destiny_state_flag_set":    "destiny",
		"destiny_state_echo_added":  "destiny",
		# §6 Story Event / Beat (emitter: BeatConductor)
		"beat_visual_cue_fired":     "beat",
		"beat_audio_cue_fired":      "beat",
		"beat_sequence_complete":    "beat",
		# §7 Input (emitter: InputRouter)
		"input_action_fired":        "input",
		"input_state_changed":       "input",
		"input_mode_changed":        "input",
		# §8 UI / Flow (emitter: UIRoot, SceneManager)
		# scene_transition_failed carries the "scene_" prefix — a spec gap in the
		# story's Implementation Notes §2 example; ADR §8 is authoritative.
		"ui_input_block_requested":  "ui",
		"ui_input_unblock_requested": "ui",
		"scene_transition_failed":   "ui",
		# §9 Persistence (emitter: SaveManager)
		"save_checkpoint_requested": "save",
		"save_persisted":            "save",
		"save_load_failed":          "save",
		# §10 Environment (emitter: MapGrid)
		"tile_destroyed":            "environment",
	}

	# Act — create a diagnostics instance and use its _route_to_domain directly
	var diagnostics: Node = auto_free((load(DIAGNOSTICS_PATH) as GDScript).new())

	# Also verify coverage: get all user-declared signals on a fresh bus and confirm
	# every one appears in our expected map (catches new signals added without updating here).
	var bus: Node = _make_bus()
	var actual_signal_names: Array[String] = []
	for sig: Dictionary in TestHelpers.get_user_signals(bus):
		actual_signal_names.append(sig["name"] as String)

	# Assert — no signal on GameBus is missing from the expected map
	var missing_from_expected: Array[String] = []
	for sname: String in actual_signal_names:
		if not expected.has(sname):
			missing_from_expected.append(sname)
	assert_array(missing_from_expected).override_failure_message(
		("Signal(s) on GameBus not covered by routing regression map: %s\n"
		+ "Add the signal and its expected domain to test_diagnostics_route_to_domain_covers_all_28_signals.") % str(missing_from_expected)
	).is_empty()

	# Assert — every expected signal routes to the correct domain
	for sig_name: String in expected:
		var got: String = diagnostics._route_to_domain(sig_name) as String
		var want: String = expected[sig_name] as String
		assert_str(got).override_failure_message(
			"_route_to_domain('%s') returned '%s', expected '%s'" % [sig_name, got, want]
		).is_equal(want)
