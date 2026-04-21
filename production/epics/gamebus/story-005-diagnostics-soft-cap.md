# Story 005: GameBusDiagnostics — debug-only 50-emit/frame soft cap

> **Epic**: gamebus
> **Status**: Complete
> **Layer**: Platform
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: medium (~3-4h) — actual ~3.5h across 4 implementation rounds + 1 real-bug fix

## Context

**GDD**: — (infrastructure; soft-cap smell detector per ADR-0001)
**Requirement**: `TR-gamebus-001`

**ADR Governing Implementation**: ADR-0001 — §Implementation Guidelines §8 + §Risks mitigation (per-frame emit violation) + §Validation Criteria V-5
**ADR Decision Summary**: "Soft cap — 50 emissions per frame, project-wide. Enforced by debug-only `GameBusDiagnostics` (stripped in release builds) that counts emits per frame and logs `push_warning` on exceed. This is a smell detector, not a hard limit."

**Engine**: Godot 4.6 | **Risk**: LOW (signal monitoring via `connect()` to every GameBus signal + `_process` frame counter)
**Engine Notes**: `OS.has_feature("debug")` distinguishes debug vs release builds (pre-cutoff stable API). Release build strip achievable via conditional autoload registration OR conditional `_ready` early-return.

**Control Manifest Rules (Platform layer)**:
- Required: 50-emits/frame soft cap; push_warning on exceed
- Required: Debug-only — stripped in release builds
- Required: Diagnostic class does not alter GameBus emission semantics (read-only observer)
- Forbidden: Per-frame work on critical path — diagnostic overhead must be <0.1 ms/frame itself
- Guardrail: GameBus total <0.5 ms/frame budget includes diagnostic overhead

## Acceptance Criteria

*Derived from ADR-0001 §Implementation Guidelines §8 + §Validation Criteria V-5:*

- [ ] `src/core/game_bus_diagnostics.gd` — `class_name GameBusDiagnostics extends Node`
- [ ] Registered as autoload at load order 2 (after GameBus, before SceneManager) — per autoload-order convention; alternatively, `GameBus` instantiates it as a child in `_ready()` (either pattern acceptable; document choice)
- [ ] At `_ready()`: connect to every user-declared signal on `/root/GameBus` via `Node.get_signal_list()` iteration; handler increments `_emits_this_frame` counter
- [ ] At `_process(delta)`: compare `_emits_this_frame` against cap (50); if exceeded, emit `push_warning` with payload listing domain + signal name counts; reset counter to 0
- [ ] Release-build strip: either (a) autoload registration gated on `OS.has_feature("debug")` (preferred), OR (b) `_ready()` early-return with `queue_free()` when not debug build. Verified by release-build lint (AC-6)
- [ ] Counter reset behavior: reset at end of `_process`, NOT at start — ensures a full frame's worth of emits are counted even if emitter runs after the diagnostic's `_process`
- [ ] Warning message format: `"GameBus soft cap exceeded: %d emits this frame (cap=50). Top domains: [scenario=%d, battle=%d, ...]"` — includes per-domain breakdown for debugging
- [ ] Counter overhead: each signal handler is a single `int` increment — no allocations, no signal name lookups in hot path
- [ ] Unit test asserts warning fires exactly once per frame regardless of how far above cap; does not double-warn within a frame
- [ ] Unit test asserts release-build equivalent path (simulated via feature flag) does NOT register the node

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §8 + §Performance Implications:*

1. **Per-domain counter layout** — 10 domain buckets (matching banner comments):
   ```gdscript
   var _domain_counts: Dictionary = {
       "scenario": 0, "battle": 0, "turn": 0, "unit": 0,
       "destiny": 0, "beat": 0, "input": 0, "ui": 0,
       "save": 0, "environment": 0,
   }
   var _emits_this_frame: int = 0
   ```
2. **Signal name → domain routing** — ADR-0001 §Signal Contract Schema is authoritative for the signal→domain mapping. The prefix-match pattern is a compact implementation strategy BUT **prefix alone is insufficient** when a signal's name prefix was chosen for semantic clarity rather than domain ownership (e.g., `battle_prepare_requested` and `battle_launch_requested` start with `battle_` but belong to Scenario Progression §1 because ScenarioRunner emits them — NOT Grid Battle).

   Implementation pattern:
   ```gdscript
   func _route_to_domain(sig_name: String) -> String:
       # Explicit name-match guards MUST precede prefix rules where the prefix
       # conflicts with the ADR-authoritative domain ownership.
       if sig_name == "battle_prepare_requested" or sig_name == "battle_launch_requested":
           return "scenario"
       if sig_name.begins_with("scenario_") or sig_name.begins_with("chapter_"): return "scenario"
       if sig_name.begins_with("battle_"): return "battle"
       if sig_name.begins_with("round_") or sig_name.begins_with("unit_turn_"): return "turn"
       if sig_name.begins_with("unit_"): return "unit"
       if sig_name.begins_with("destiny_"): return "destiny"
       if sig_name.begins_with("beat_"): return "beat"
       if sig_name.begins_with("input_"): return "input"
       if sig_name.begins_with("ui_") or sig_name.begins_with("scene_"): return "ui"   # scene_transition_failed
       if sig_name.begins_with("save_"): return "save"
       if sig_name.begins_with("tile_"): return "environment"
       return "unknown"
   ```
   Compute at connect time, not per-emit. Store a `Dictionary[signal_name -> domain_key]` lookup. A dedicated 27-signal regression test (`test_diagnostics_route_to_domain_covers_all_27_signals`) enforces the ADR schema against the routing function — failing if rule ordering is broken or a new signal is added without updating both the ADR table and this function.
3. **Connect once per signal** — iterate `GameBus.get_signal_list()` filtering out inherited Node signals. For each user signal, `GameBus.[signal].connect(Callable(self, "_on_any_emit").bind(signal_name))`.
4. **Binding** — use `Callable.bind(signal_name)` so the handler knows which signal fired without receiving the actual payload. Avoids payload access (and the Variadic-arg complexity for signals with different arg counts).
5. **Counter reset at end of `_process`** — after the warning check. This means a burst at frame N is counted in frame N's report, not split across frames.
6. **Release strip** — preferred approach:
   ```ini
   # project.godot (autoload block)
   GameBus="*res://src/core/game_bus.gd"
   GameBusDiagnostics="*res://src/core/game_bus_diagnostics.gd"
   ```
   Inside `GameBusDiagnostics._ready()`:
   ```gdscript
   func _ready() -> void:
       if not OS.is_debug_build():
           queue_free()
           return
       # ... proceed with connect loop
   ```
   This keeps autoload registration uniform but makes release builds a no-op at the frame-work level (only cost is one `_ready()` call at boot).
7. **No emissions from GameBusDiagnostics** — it is read-only observer. Does not re-emit on GameBus. (Violating this would violate ADR-0001 §8 "NOT from `_process`" since `_process` is the tick handler — but we're receiving in handlers and processing in `_process`, which is fine.)
8. **Override for testing** — tests should be able to set `_cap` to a small value (e.g. 5) to trigger warnings deterministically. Expose via `set_cap(n: int)` method used only by tests; production uses the const default.

## Out of Scope

- **Hard-limit enforcement** — this is a smell detector, not a hard rate limiter. Bus emission is NOT blocked when cap exceeded; only warned.
- **Emission-rate metrics over time** — this is a per-frame counter, not a moving average. Time-series telemetry belongs to future analytics-engineer work.
- **Burst detection in release builds** — explicitly not needed; production performance is validated by profiling, not runtime monitoring.

## QA Test Cases

*Inline QA specification.*

**Test file**: `tests/unit/core/game_bus_diagnostics_test.gd`

- **AC-1** (warning fires at cap+1):
  - Given: GameBus + GameBusDiagnostics loaded; cap overridden to 5 via `set_cap(5)`
  - When: emit 6 GameBus signals in a single frame (via manual `GameBus.chapter_started.emit("ch_01", 1)` calls × 6 in the same tick); wait one `_process` cycle
  - Then: exactly one `push_warning` invocation for this frame (assertable via `GdUnit4` warning capture helper, or via log-file scrape); warning message contains `"exceeded: 6 emits"` and mentions scenario domain
  - Edge: emit 5 signals only → zero warnings that frame

- **AC-2** (counter resets between frames):
  - Given: cap=5
  - When: frame N emit 6 signals → warning fires; frame N+1 emit 3 signals; frame N+2 emit 4 signals
  - Then: frame N fires warning; frames N+1 and N+2 fire no warning; counter reset correctly

- **AC-3** (domain breakdown in warning):
  - Given: cap=5
  - When: emit 3 `scenario_*`, 2 `battle_*`, 2 `tile_destroyed` (total 7) in one frame
  - Then: warning message contains `"scenario=3"`, `"battle=2"`, `"environment=2"` (or equivalent structured format)

- **AC-4** (release-build strip):
  - Given: simulate release build via mock `OS.is_debug_build() = false` (test harness injectable)
  - When: GameBusDiagnostics autoload runs `_ready`
  - Then: node calls `queue_free()` in its `_ready`; no signal connections made; no `_process` handler active
  - Edge: emit 100 signals in one frame in release mode → no warnings (proves stripped)

- **AC-5** (no emission from diagnostics):
  - Given: GameBusDiagnostics running, cap exceeded
  - When: scan signals emitted during the warning cycle
  - Then: only the test-injected GameBus emits appear; GameBusDiagnostics itself emits nothing

- **AC-6** (overhead):
  - Given: 30 signals emitted per frame for 60 frames (still under cap=50; no warning)
  - When: measure frame time delta vs baseline (no diagnostic)
  - Then: diagnostic overhead <0.1 ms/frame (GdUnit4 timing assertion)
  - Note: non-blocking if platform-variable; record as performance observation not hard gate

- **AC-7** (deterministic):
  - Given: 10 consecutive test runs
  - Then: same pass result each time

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/game_bus_diagnostics_test.gd` — must exist and pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 002 (GameBus must exist to connect to)
- **Unlocks**: proactive per-frame emission hygiene; smell detection during Vertical Slice

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 7/7 ACs passing + 1 bonus regression test added during review; 41/41 full unit suite green, exit 0
**Verdict**: COMPLETE WITH NOTES

**Test Evidence**: `tests/unit/core/game_bus_diagnostics_test.gd` — 9 GdUnit4 test functions (8 AC-driven + 1 `_route_to_domain` regression), ~460 LoC, Logic gate BLOCKING satisfied

**Code Review**: Complete — `/code-review` initial verdict **CHANGES REQUIRED** (1 BLOCKING hot-path allocation, 4 ADVISORY items). Option C accepted: BLOCKING documented as trade-off (TD-012), all 4 ADVISORY items applied, **plus 1 real bug caught during regression-test drafting and fixed in-situ**. Final verdict: **APPROVED**.

**Files delivered**:
- `src/core/game_bus_diagnostics.gd` (~170 LoC) — **first real source-code file in the project**. Autoload Node with `_ready`/`_process` lifecycle, 27-signal connect loop via `Callable.bind(name).unbind(arg_count)`, 10-domain routing, debug-build strip via `queue_free()`, 4 documented test seams (`_debug_build_override` static, `_soft_cap_warning_fired` signal, `set_cap(n)`, `_connect_to_bus(bus)`)
- `tests/unit/core/game_bus_diagnostics_test.gd` (~460 LoC) — 9 test functions covering AC-1..AC-7 + domain routing regression
- `project.godot` — `GameBusDiagnostics` autoload registered as 2nd entry after `GameBus`, preserving ORDER-SENSITIVE comment

**Bug caught and fixed in-situ** (during /code-review Option C application):
`_route_to_domain("battle_prepare_requested")` incorrectly returned `"battle"` because the `begins_with("battle_")` prefix rule fired before any scenario-domain check. Per ADR-0001 §Signal Contract Schema §1, both `battle_prepare_requested` and `battle_launch_requested` are emitted by ScenarioRunner and belong to Scenario Progression. Without the new 27-signal regression test drafted during code-review, this would have silently shipped and produced incorrect warning messages (counting scenario emits under "battle" domain). Fix: explicit name-match guards added before the `battle_` prefix rule. Story Implementation Notes §2 updated above to reflect the correct pattern and document the prefix-vs-domain conflict as a general lesson.

**Implementation rounds** (documentation of specialist iteration discipline):
1. Initial write → 3 BLOCKING compile errors: autoload name collision with `class_name GameBusDiagnostics`, `assert_signal_emit_count()` doesn't exist in GdUnit4 v6.1.2, loop variable `i` scoping in GDScript 4.x
2. Fix round 1 → 1 runtime failure: GDScript lambda primitive-capture semantics (AC-3 test tried to reassign outer String/int/Dictionary from inside a lambda — doesn't propagate; only Array.append / Dictionary[k]=v method calls work)
3. Fix round 2 → 40/40 green
4. Post-review Option C → real `_route_to_domain` bug caught during regression-test drafting → fixed + 4 advisory changes applied → 41/41 green

**Advisory items applied** (not tech-debt):
- AC-5 expanded to track `chapter_started` (6 signals covering 6 of 10 domains — smell-check rationale documented)
- AC-7 iterations raised from 2 → 10 to match story spec ("10 consecutive runs")
- New `test_diagnostics_route_to_domain_covers_all_27_signals` — bidirectional coverage check + per-signal routing assertion against ADR-authoritative expected map
- Story Implementation Notes §2 corrected in-place: ADR-0001 §Signal Contract Schema declared authoritative; explicit name-match pattern documented for prefix-vs-domain conflicts

**Advisory item accepted with documentation** (logged as TD-012):
- Hot-path Dictionary allocations in `_on_any_emit` (2 Dictionary read/writes per emission) violate the letter of engine-code.md ZERO-alloc rule. Accepted because: (a) diagnostic is debug-only, queue_free'd in release; (b) measured 0.53µs/emit = 0.016ms/frame, 6× under <0.1ms/frame budget; (c) 10 fixed keys → predictable. Revisit trigger documented in code + TD-012.

**5 GDScript 4.x gotchas codified this session** (logged as TD-013 for future rule-file creation):
1. Godot 4.6.2 Node has 13 inherited signals (not 9 from training) — use dynamic baseline filter
2. `Array[T].duplicate()` demotes typed → untyped — use `.assign()` instead
3. Autoload-registered scripts must NOT declare `class_name X` matching the autoload name
4. GDScript lambdas cannot reassign outer primitive locals — use `Array.append({...})` pattern
5. Prefix-based signal routing is fragile when prefix ≠ ADR domain ownership — enforce via ADR-authoritative regression tests

**Deviations**: None from scope. Spec-wording correction applied in-situ to §2 (above). No other files touched outside the 3 listed deliverables.

**Gates skipped** (review-mode=lean): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates. Standalone `/code-review` ran with 2 specialists — findings captured, Option C fix cycle applied, real bug caught during fix application.
