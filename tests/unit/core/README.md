# tests/unit/core — Unit Test Directory

This directory holds unit tests for the Core layer of 천명역전. The key
infrastructure provided here is the `GameBusStub` helper, which enables
test isolation for any code that reads from or emits to the GameBus autoload.

---

## GameBusStub — Test Isolation for /root/GameBus

`game_bus_stub.gd` provides two static methods that swap the production
`/root/GameBus` autoload out for a fresh instance during a test, then restore
it afterward. The stub runs the same script as the production node, so its
signal surface is identical — no duplication, no drift risk.

### Why this exists

GdUnit4 mounts all project autoloads in the test tree, including `/root/GameBus`.
A test that connects a handler and emits a signal would leave that connection
alive for the next test, leaking state across test functions. The stub pattern
solves this by replacing the shared autoload with a brand-new instance that has
zero subscribers — each test function starts with a clean slate.

### Usage

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

    # Explicit in-body cleanup prevents GdUnit4's orphan detector from flagging
    # the detached production node between test body end and after_test.
    # after_test's swap_out() is a safety net for crashes, not the primary path.
    GameBusStub.swap_out()
```

`swap_in()` returns the stub Node for optional direct manipulation (e.g.,
connecting a test-only observer). `swap_out()` is idempotent — safe to call
from `after_test()` even if `swap_in()` was never called or the test called
`swap_out()` itself.

### How it works internally

1. `swap_in()` calls `root.get_node_or_null("GameBus")` via
   `Engine.get_main_loop().root` (static functions cannot use `get_tree()`).
2. If the production node exists, it is removed from the tree with
   `remove_child()` and cached in a static var.
3. A fresh stub is instantiated: `(load(GAME_BUS_PATH) as GDScript).new()`.
   Its `name` is set to `"GameBus"` before `add_child()` to avoid the sibling
   name-collision error Godot enforces.
4. `swap_out()` reverses this: removes the stub with `remove_child()`, then
   calls `free()` on it for immediate synchronous deletion, then re-adds the
   cached production node.
5. All three steps are synchronous — `get_node("GameBus")` returns the
   production instance immediately after `swap_out()` returns and the stub is
   fully destroyed. `free()` is used rather than `queue_free()` to avoid
   GdUnit4's orphan detector flagging the deferred-but-not-yet-freed stub.

---

## Known Limitations

### Fresh stub has zero subscribers

The stub is a new Node instance. Any handler connected to it lives only for the
duration of that test function. When `swap_out()` frees the stub, all its signal
connections are implicitly removed — no manual `disconnect()` is needed.

### Production subscribers do not re-bind to the stub

Systems like `SceneManager` and `SaveManager` connect to `GameBus` once at
project boot in their own `_ready()`. They do not re-connect when the stub is
swapped in. Emitting on the stub will **not** reach `SceneManager` or
`SaveManager`. If a test needs to verify how those systems react to a GameBus
signal, use a full integration test rather than this stub.

### GameBusDiagnostics stays connected to the detached production node

When the stub is active, `GameBusDiagnostics` (Story 005) remains connected to
the detached production `GameBus`. Stub emits do **not** increment the
diagnostic's frame counter. On `swap_out()`, the production node is re-added
and the diagnostic automatically re-engages — Godot signal connections are
between Callable target objects, not tree paths, so they persist through
`remove_child` / `add_child` cycles.

Consequence: do **not** assert `GameBusDiagnostics` soft-cap behavior based on
stub emits. If you need to test that a system triggers the soft cap, use the
production `GameBus` directly (or inject a fresh bus into diagnostics via
`_connect_to_bus()` — see Story 005 test seam documentation).

### Serial execution only

The static-var cache in `GameBusStub` is safe only when test functions within a
suite execute serially. GdUnit4 v6.1.2 runs test functions serially per suite by
default. Parallel execution within a suite would break this pattern.

---

## Signal Observation Pattern

When a test needs to capture signal emissions from the stub (or any Node),
use the Array-append lambda pattern — GDScript lambdas cannot reassign outer
primitive locals, but they can call `.append()` on a captured Array reference:

```gdscript
var captures: Array = []
_stub.chapter_started.connect(
    func(chapter_id: String, chapter_number: int) -> void:
        captures.append({"id": chapter_id, "num": chapter_number})
)

_stub.chapter_started.emit("ch_01", 1)

assert_int(captures.size()).is_equal(1)
assert_str(captures[0].id as String).is_equal("ch_01")
```

---

## Related Files

| File | Purpose |
|------|---------|
| `game_bus_stub.gd` | The stub utility — `GameBusStub.swap_in()` / `swap_out()` |
| `game_bus_stub_self_test.gd` | Regression tests for the stub itself (AC-1..AC-5, AC-7) |
| `game_bus_declaration_test.gd` | Story 002 — GameBus signal declarations + registration |
| `signal_contract_test.gd` | Story 003 — ADR-0001 schema drift gate |
| `payload_serialization_test.gd` | Story 004 — payload Resource round-trip |
| `game_bus_diagnostics_test.gd` | Story 005 — GameBusDiagnostics soft-cap behavior |

---

## Design Rationale

See Story 006 (`production/epics/gamebus/story-006-stub-for-gdunit4.md`) for
full design rationale, implementation notes, and the QA test case specifications
that this README summarises.

ADR reference: ADR-0001 §Implementation Guidelines §9, §Validation Criteria V-6
(`docs/architecture/ADR-0001-gamebus-autoload.md`).
