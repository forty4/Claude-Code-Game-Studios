# Story 006: GameBus stub pattern for GdUnit4

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; test-infra contract per ADR-0001)
**Requirement**: `TR-gamebus-001`

**ADR Governing Implementation**: ADR-0001 — §Implementation Guidelines §9 + §Validation Criteria V-6
**ADR Decision Summary**: "GameBus test double — in GdUnit4, `before_test` removes the production `/root/GameBus` node and registers a `GameBusStub` with the same signals. `after_test` restores. Stub inherits the same interface by loading the same script — no duplication."

**Engine**: Godot 4.6 | **Risk**: LOW (autoload tree manipulation via `get_tree().root.add_child` / `.remove_child` — pre-cutoff stable)
**Engine Notes**: GdUnit4's `before_test` / `after_test` hook signature. Autoload swap requires careful ordering — ensure production GameBus is removed BEFORE stub is added, and restored AFTER stub is removed (to avoid two `/root/GameBus` nodes and name-collision errors).

**Control Manifest Rules (Platform layer)**:
- Required: GameBus stub injectable via `before_test` / `after_test` in GdUnit4 — documented pattern
- Required: Stub inherits same script (no signal declaration duplication)
- Required: No test depends on execution order (isolation discipline)
- Forbidden: Tests modifying production autoload state without cleanup

## Acceptance Criteria

*Derived from ADR-0001 §Implementation Guidelines §9 + §Migration Plan §6 (test infrastructure README):*

- [ ] `tests/unit/core/game_bus_stub.gd` — helper module exposing `GameBusStub.swap_in()` and `GameBusStub.swap_out()` static/class methods
- [ ] `swap_in()`: if `/root/GameBus` exists, rename it to `/root/GameBus_production` (or `remove_child` + store reference); instantiate a new `GameBus` from the same script (`preload("res://src/core/game_bus.gd").new()`) and `add_child` under `/root` with name `"GameBus"`. Return the stub instance for optional direct manipulation (e.g., connect a test-only inspector handler).
- [ ] `swap_out()`: free the stub instance; restore the production `/root/GameBus` to its original name/parent. Idempotent — safe to call twice.
- [ ] `tests/unit/core/README.md` — documents the stub usage pattern with a complete example:
  ```gdscript
  extends GdUnitTestSuite
  var _stub: Node

  func before_test() -> void:
      _stub = GameBusStub.swap_in()

  func after_test() -> void:
      GameBusStub.swap_out()
      _stub = null

  func test_my_scenario() -> void:
      # use the stub like the real GameBus — same signals, same signatures
      _stub.battle_outcome_resolved.emit(BattleOutcome.new())
      # assertions...
  ```
- [ ] README also documents:
  - The swap creates a fresh GameBus instance with zero subscribers — tests cannot leak subscriber state across tests
  - Production subscribers (SceneManager, SaveManager) are unaffected because they connect to GameBus in their OWN `_ready`, which runs at project boot — they won't re-bind to the stub. If a test needs to verify SceneManager/SaveManager GameBus interaction, use `full integration test` pattern (not this stub)
  - The stub is for UNIT tests that want to inject synthetic emits and observe handler behavior in isolation
- [ ] Self-test: `tests/unit/core/game_bus_stub_self_test.gd` — verifies `swap_in` / `swap_out` idempotency, correct restoration after test, no orphaned nodes, no signal subscribers leaked

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §9:*

1. **Script reuse** — stub loads `res://src/core/game_bus.gd`. Same class, same signal declarations. Zero duplication. When a new signal is added to GameBus (via ADR-0001 §Evolution Rule §1 amendment), the stub automatically has it — no stub maintenance burden.
2. **Node naming collision avoidance** — Godot does not allow two siblings with the same name. Options (choose one and document):
   - (a) Rename production: `gamebus = get_tree().root.get_node("GameBus"); gamebus.name = "GameBus_production"; ...` then re-rename on swap_out
   - (b) Remove-and-cache: `var prod = get_tree().root.get_node("GameBus"); get_tree().root.remove_child(prod); ...` then `get_tree().root.add_child(prod); prod.name = "GameBus"` on swap_out
   - **Recommendation**: (b) — cleaner; no name manipulation; fewer edge cases. Cache the production reference in a static var.
3. **GameBusDiagnostics handling** — if GameBusDiagnostics is running (debug builds, from Story 005), it's connected to the production GameBus. When we swap in the stub, the diagnostic is still connected to the (now-detached) production GameBus and NOT the stub. Options:
   - (a) Ignore — stub emits don't trigger diagnostics; this is fine for isolated unit tests
   - (b) Re-route diagnostic to stub — complex; not worth the code
   - **Recommendation**: (a). Document in README: "GameBusDiagnostics is disconnected during stub swap; verify soft-cap behavior via explicit `_stub.emits_this_frame`-style inspectors if needed, not via warning capture."
4. **Test parallelism** — GdUnit4 tests are typically serial per-suite; the static-var cache is safe. If tests ever run in parallel within a suite, the stub pattern breaks. Document as a known limitation. Mitigation: GdUnit4 serial execution is the default.
5. **Leaked-subscriber check** — a test that calls `_stub.battle_outcome_resolved.connect(my_handler)` must disconnect in `after_test` OR trust that the stub's `swap_out` frees the stub entirely (which implicitly disconnects all handlers since the signal owner is gone). This is a Godot semantics win — no explicit cleanup needed.

## Out of Scope

- **Multi-signal test orchestration framework** — out of scope. Tests chain signals manually.
- **Production GameBus replacement at runtime** — this is a TEST-ONLY utility. Production code NEVER swaps GameBus. Document this prominently in the README.
- **Compatibility with GodotPhysics vs Jolt** — physics-unrelated; no test coverage needed.

## QA Test Cases

*Inline QA specification.*

**Test file**: `tests/unit/core/game_bus_stub_self_test.gd`

- **AC-1** (swap_in replaces production):
  - Given: production GameBus autoload loaded at `/root/GameBus`
  - When: `var stub = GameBusStub.swap_in()`
  - Then: `get_tree().root.get_node("GameBus")` returns the stub instance (not the production one); production instance is cached internally; `stub.get_script() == preload("res://src/core/game_bus.gd")` (same script)
  - Edge: stub has zero connected subscribers (fresh instance)

- **AC-2** (swap_out restores production):
  - Given: stub is active (after swap_in)
  - When: `GameBusStub.swap_out()`
  - Then: `get_tree().root.get_node("GameBus")` is the original production instance; stub is freed (`is_instance_valid(stub) == false`); production subscriber connections still intact (i.e., SceneManager / SaveManager still connected if they were before the test)

- **AC-3** (idempotent swap_out):
  - Given: swap_in called, swap_out called
  - When: swap_out called again
  - Then: no error, no double-free; production GameBus still at `/root/GameBus`

- **AC-4** (signal isolation across swap):
  - Given: stub swapped in
  - When: test connects a handler to `stub.chapter_started`; stub emits `chapter_started("ch_01", 1)`; test handler records the call
  - Then: handler fires exactly once; production GameBus (detached) sees nothing
  - Edge: after swap_out, test handler is disconnected (stub freed); new connection to `/root/GameBus.chapter_started` reaches the production instance

- **AC-5** (no orphaned nodes):
  - Given: swap_in called, swap_out called
  - When: scan `get_tree().root.get_children()` names
  - Then: exactly one node named "GameBus" (the production one); no "GameBus_production", no "GameBus_stub", no duplicates
  - Edge: repeat swap_in / swap_out 5 times; no orphan buildup

- **AC-6** (README example code block compiles):
  - Given: README contains a GDScript code block labeled "usage example"
  - When: extract block and attempt to parse as GDScript via a doc-lint step
  - Then: parses without syntax errors
  - Note: advisory-level test if doc-lint tooling isn't set up yet

- **AC-7** (works even if GameBusDiagnostics is running):
  - Given: debug build with GameBusDiagnostics autoload active
  - When: swap_in → emit 60 signals on stub → swap_out
  - Then: no crash; GameBusDiagnostics does not interfere with stub operation; on swap_out, diagnostic is still connected to restored production GameBus
  - Note: per Implementation Notes §3, diagnostic warning capture on stub is explicitly not guaranteed

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/core/game_bus_stub.gd` + `tests/unit/core/README.md` + `tests/unit/core/game_bus_stub_self_test.gd` — all must exist and self-test passes
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 002 (GameBus must exist to be swappable)
- **Unlocks**: test infrastructure for ALL downstream Platform + Foundation epics — SceneManager Story tests, SaveManager Story tests, Map/Grid Story tests all require the ability to isolate GameBus signals. This story is the critical-path enabler for every other epic's test coverage.
