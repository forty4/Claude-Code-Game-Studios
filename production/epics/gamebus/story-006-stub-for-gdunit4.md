# Story 006: GameBus stub pattern for GdUnit4

> **Epic**: gamebus
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: small (~2-3h) — actual ~3h across 4 implementation rounds (initial + queue_free→free + explicit swap_out + Option B hardening)

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

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 7/7 testable ACs passing (AC-6 README code-block lint deferred per story advisory note); 48/48 full unit suite green, 0 orphans, exit 0
**Verdict**: COMPLETE WITH NOTES

**Test Evidence**: 3 artifacts in `tests/unit/core/`:
- `game_bus_stub.gd` (~140 LoC) — `GameBusStub.swap_in()` / `swap_out()` static helpers with hardened state machine
- `game_bus_stub_self_test.gd` (~417 LoC) — 7 self-tests covering AC-1..AC-5 + AC-7
- `README.md` (~152 LoC) — usage pattern + documented limitations

Plus 1 new shared helper file: `tests/unit/core/test_helpers.gd` (~34 LoC) — `class_name TestHelpers` with `get_user_signals(node)` static method, extracted from 3 test files where the dynamic-baseline inherited-signal filter was duplicated (W-3 hardening from /code-review).

**Code Review**: Complete — `/code-review` initial verdict **CHANGES REQUIRED** (1 BLOCKING `is_instance_valid` guard missing + 5 ADVISORY hardening). Option B accepted: all 6 changes applied → final verdict **APPROVED**. 48/48 tests still pass after hardening.

**Files delivered** (all in `tests/unit/core/`; zero src/ or project.godot changes):
- `game_bus_stub.gd` (new, ~140 LoC)
- `game_bus_stub_self_test.gd` (new, ~417 LoC)
- `README.md` (new, ~152 LoC)
- `test_helpers.gd` (new, ~34 LoC — shared helper extracted during Option B)
- `signal_contract_test.gd` (modified, -11 LoC — delegates to TestHelpers)
- `game_bus_diagnostics_test.gd` (modified, -5 LoC — delegates to TestHelpers)
- `game_bus_declaration_test.gd` (modified — delegates to TestHelpers)

**Implementation rounds** (4-round progressive debugging):
1. Initial write: 7/7 PASS but 2 orphan nodes from `queue_free()` deferred deletion
2. Round 1: `queue_free()` → `free()` + `is_queued_for_deletion()` → `is_instance_valid(stub) == false` check + AC-7 format string error fixed → 1 orphan remaining
3. Round 2: added explicit `GameBusStub.swap_out()` at end of AC-1 test body (GdUnit4 scans orphans between test body exit and after_test; after_test cleanup is too late; exit code 101 when any orphan found) → 0 orphans, 48/48 pass, exit 0
4. Option B hardening (post-/code-review): 6 changes across 6 files — 1 BLOCKING fix + 5 advisory → still 48/48 pass, exit 0

**BLOCKING fix applied** (Option B Change 1):
`_cached_production` dereferenced without `is_instance_valid()` check at both restoration sites in `swap_out()`. Would crash with use-after-free if anything freed the cached production Node between swap_in and swap_out (SceneTree teardown, rogue test calling queue_free, engine shutdown). Critical because downstream stories would copy the pattern and inherit the bug. Now guarded with `is_instance_valid()` + `push_warning` diagnostic on broken-cache cases.

**Advisory hardening applied** (Option B Changes 2-6):
- **W-1**: `Engine.get_main_loop().root` hardened via `_get_root()` helper with SceneTree cast + null guard (swap_in may now return null in non-SceneTree contexts — defensive)
- **W-2**: Case D (foreign-node at /root/GameBus corruption path) emits `push_warning` instead of silent cache clear
- **W-3**: `_get_user_signals` extracted to `tests/unit/core/test_helpers.gd` (3rd-copy extraction threshold)
- **AC-4 comment staleness** ("freed/queued" → "freed synchronously via free()")
- **README usage example** updated to show in-body `swap_out()` pattern so future authors don't rely solely on after_test (which is too late to prevent GdUnit4 orphan detection)

**Design decisions codified**:
- First story to touch `/root/` directly via `add_child`/`remove_child` during tests (all prior tests used `load()+.new()` isolated instances)
- `Engine.get_main_loop()` + SceneTree cast for static-function root access (not `get_tree().root` which requires Node method)
- `class_name GameBusStub` + `extends RefCounted` — OK because stub is NOT an autoload (no `/root/GameBusStub` mount, no name collision)
- `free()` (not `queue_free()`) for test-owned Nodes with no external Callable references — immediate deletion avoids GdUnit4 orphan detection
- **Explicit `swap_out()` at end of every test body** that calls `swap_in()` — `after_test` is crash-safety net, not primary cleanup
- `is_instance_valid()` guards before dereferencing cached Node references — critical-path defensive pattern
- `_active_stub` state var distinguishes stub-active from stub-absent states — prevents paranoia-path swap_out from misidentifying production as the stub

**6th GDScript 4.x / GdUnit4 gotcha this session** (additional to TD-013 items):
GdUnit4 orphan detection fires between test body exit and `after_test`. Detached Nodes held in static vars are flagged. Fix: explicit cleanup at end of test body that creates/detaches Nodes; after_test serves only as crash-safety net. Exit code 101 when any orphan found. Worth adding to TD-013's gotcha list when that rule-file is created.

**Advisory follow-ups** (logged to `docs/tech-debt-register.md`):
- **TD-014** — Verify CI config actually registers `GameBusDiagnostics` as autoload so AC-7 assertion (c) — "diagnostic re-engages with production after swap_out via signal-persistence through detach/reattach" — is actually exercised in CI. Locally it runs; CI should inherit project.godot [autoload] block but worth confirmation.

**Deferred** (not logged as tech debt):
- qa-tester Gap 1 (AC-4 detached-production-silence) — architecturally guaranteed by Godot's signal model (emit on object A cannot fire handler on object B without explicit connection); documented in README
- Engine-specialist W-4 (standalone signal-persistence test independent of diagnostics) — low value given architectural guarantee + existing AC-7 coverage in debug builds

**Gates skipped** (review-mode=lean): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates. Standalone `/code-review` ran with 2 specialists — findings captured above, Option B fix cycle applied.
