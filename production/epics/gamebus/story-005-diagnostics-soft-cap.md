# Story 005: GameBusDiagnostics — debug-only 50-emit/frame soft cap

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Manifest Version**: 2026-04-20

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
2. **Signal name → domain routing** — use prefix match:
   ```gdscript
   func _route_to_domain(signal_name: String) -> String:
       if signal_name.begins_with("scenario_") or signal_name.begins_with("chapter_"): return "scenario"
       if signal_name.begins_with("battle_"): return "battle"
       if signal_name.begins_with("round_") or signal_name.begins_with("unit_turn_"): return "turn"
       if signal_name.begins_with("unit_"): return "unit"
       if signal_name.begins_with("destiny_"): return "destiny"
       if signal_name.begins_with("beat_"): return "beat"
       if signal_name.begins_with("input_"): return "input"
       if signal_name.begins_with("ui_"): return "ui"
       if signal_name.begins_with("save_"): return "save"
       if signal_name.begins_with("tile_"): return "environment"
       return "unknown"
   ```
   Compute at connect time, not per-emit. Store a `Dictionary[signal_name -> domain_key]` lookup.
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
