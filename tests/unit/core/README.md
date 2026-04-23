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

---

## SceneManagerStub — Test Isolation for /root/SceneManager

`scene_manager_stub.gd` provides two static methods that swap the production
`/root/SceneManager` autoload out for a fresh instance during a test, then restore
it afterward. The stub runs the same script as the production node, so its FSM
state machine, signal subscriptions, and all internal variables are
identical — no duplication, no drift risk.

### Why this exists

GdUnit4 mounts all project autoloads in the test tree, including `/root/SceneManager`.
A test that drives the FSM through transitions would leave the manager in a
non-IDLE state for the next test, leaking state across test functions. The stub
pattern solves this by replacing the shared autoload with a brand-new instance
that starts in `State.IDLE` with zero transition history — each test function
starts with a clean FSM.

### Usage

```gdscript
extends GdUnitTestSuite
var _stub: Node

func before_test() -> void:
    _stub = SceneManagerStub.swap_in()

func after_test() -> void:
    SceneManagerStub.swap_out()
    _stub = null

func test_my_scenario() -> void:
    # fresh stub always starts in State.IDLE
    assert_bool(_stub.state == _stub.State.IDLE).is_true()
    # drive the FSM, make assertions...

    # Explicit in-body cleanup prevents GdUnit4's orphan detector from flagging
    # the detached production node between test body end and after_test.
    # after_test's swap_out() is a safety net for crashes, not the primary path.
    SceneManagerStub.swap_out()
```

`swap_in()` returns the stub Node for optional direct manipulation (e.g., reading
`stub.state` or replacing `stub._load_timer` for Timer control in load-path tests).
`swap_out()` is idempotent — safe to call from `after_test()` even if `swap_in()`
was never called or the test called `swap_out()` itself.

### How it works internally

1. `swap_in()` calls `root.get_node_or_null("SceneManager")` via
   `Engine.get_main_loop().root` (static functions cannot use `get_tree()`).
2. If the production node exists, it is removed from the tree with
   `remove_child()` and cached in a static var.
3. A fresh stub is instantiated: `(load(SCENE_MANAGER_PATH) as GDScript).new()`.
   Its `name` is set to `"SceneManager"` before `add_child()` to avoid the sibling
   name-collision error Godot enforces.
4. The stub's `_ready()` fires on `add_child()` — it creates its own Timer child
   and connects to GameBus signals exactly as production does. This is the
   isolation property: fresh instance = fresh subscriptions + fresh FSM starting
   at `State.IDLE`.
5. `swap_out()` reverses this: removes the stub with `remove_child()`, then
   calls `free()` on it for immediate synchronous deletion, then re-adds the
   cached production node.
6. All three steps are synchronous — `get_node("SceneManager")` returns the
   production instance immediately after `swap_out()` returns and the stub is
   fully destroyed. `free()` is used rather than `queue_free()` to avoid
   GdUnit4's orphan detector flagging the deferred-but-not-yet-freed stub.

---

## Known Limitations (SceneManagerStub)

### Fresh stub starts in State.IDLE with its own Timer child

The stub creates its own `_load_timer` in `_ready()`. If a test needs to
control Timer behavior (e.g., simulate a load-poll tick), replace
`stub._load_timer` after `swap_in()` returns with a test-owned Timer.

### Production GameBus subscribers are unaffected

The stub's `_ready()` connects to `GameBus.battle_launch_requested` and
`GameBus.battle_outcome_resolved` with `CONNECT_DEFERRED`. These are the
stub's own subscriptions on the production GameBus autoload. When `swap_out()`
frees the stub, these connections are automatically removed.

Tests that need to verify how other systems react to SceneManager's state
changes should use full integration tests rather than this stub.

### Combining with GameBusStub

Tests may use both `GameBusStub.swap_in()` and `SceneManagerStub.swap_in()`
in the same test for full autoload isolation. Each stub maintains its own
independent static-var cache — they do not interfere.

```gdscript
func before_test() -> void:
    _game_bus_stub = GameBusStub.swap_in()
    _scene_manager_stub = SceneManagerStub.swap_in()

func after_test() -> void:
    SceneManagerStub.swap_out()
    GameBusStub.swap_out()
```

### Serial execution only

The static-var cache in `SceneManagerStub` is safe only when test functions
within a suite execute serially. GdUnit4 v6.1.2 runs test functions serially
per suite by default. Parallel execution within a suite would break this pattern.

---

## Related Files (SceneManagerStub)

| File | Purpose |
|------|---------|
| `scene_manager_stub.gd` | The stub utility — `SceneManagerStub.swap_in()` / `swap_out()` |
| `scene_manager_stub_self_test.gd` | Regression tests for the stub itself (AC-1..AC-5, AC-7) |

---

## Design Rationale (SceneManagerStub)

See Story 002 (`production/epics/scene-manager/story-002-stub-for-gdunit4.md`) for
full design rationale, implementation notes, and the QA test case specifications
that this README summarises.

ADR reference: ADR-0002 §Validation Criteria V-10
(`docs/architecture/ADR-0002-scene-manager.md`).

See also `.claude/rules/godot-4x-gotchas.md` G-6 (orphan detection fires between
test body and `after_test` — explicit `swap_out()` in test body is required) and
G-3 (autoload scripts must not declare `class_name` — `SceneManagerStub` can use
`class_name` because it is a `RefCounted` helper, not an autoload).

---

## SaveManagerStub — Test Isolation for /root/SaveManager

`save_manager_stub.gd` provides two static methods that swap the production
`/root/SaveManager` autoload out for a fresh instance during a test, redirect
its save root to a temp directory under `user://test_saves/`, then restore the
production instance and remove the temp directory on cleanup. The stub runs the
same script as the production node, so its full API surface is identical — no
duplication, no drift risk.

### Why this exists

GdUnit4 mounts all project autoloads in the test tree, including `/root/SaveManager`.
Any test that calls `save_checkpoint` or `load_latest_checkpoint` would read and
write the production `user://saves/` directory — polluting real save data across
test runs and introducing test-order-dependent state. The stub pattern solves this
by replacing the shared autoload with a brand-new instance whose save root is
redirected to an isolated temp directory. Each test function starts with a clean,
empty save hierarchy under `user://test_saves/[unique]/`.

### Usage

```gdscript
extends GdUnitTestSuite
var _stub: Node

func before_test() -> void:
    _stub = SaveManagerStub.swap_in()

func after_test() -> void:
    SaveManagerStub.swap_out()
    _stub = null

func test_my_scenario() -> void:
    # stub API is identical to production — same methods, redirected save root
    _stub.set_active_slot(2)
    assert_int(_stub.active_slot).is_equal(2)

    # Explicit in-body cleanup prevents GdUnit4's orphan detector from flagging
    # the detached production node between test body end and after_test.
    # after_test's swap_out() is a safety net for crashes, not the primary path.
    SaveManagerStub.swap_out()
```

To control the temp root path explicitly (e.g., for path-assertion tests):

```gdscript
var _stub: Node = SaveManagerStub.swap_in("user://test_saves/my_deterministic_test/")
```

`swap_in()` returns the stub Node for direct method calls. `swap_out()` is
idempotent — safe to call from `after_test()` even if `swap_in()` was never
called or the test called `swap_out()` itself.

### How it works internally

1. `swap_in(temp_root)` generates a unique path under `user://test_saves/` when
   `temp_root` is empty, using `OS.get_unique_id() + "_" + Time.get_ticks_msec()`.
2. The temp root and three slot subdirs are created via
   `DirAccess.make_dir_recursive_absolute` before `add_child`.
3. The production node is removed with `remove_child()` and cached in a static var.
4. A fresh stub is instantiated: `(load(SAVE_MANAGER_PATH) as GDScript).new()`.
   `stub._save_root_override = temp_root` is set BEFORE `add_child()` — this is
   critical because `_ready()` calls `_ensure_save_root()`, which uses
   `_effective_save_root()` to resolve the path. The override must be in place
   before `_ready()` fires or `_ensure_save_root()` would create dirs at the
   production path.
5. `swap_out()` reverses this: removes the stub with `remove_child()`, calls
   `free()` for immediate synchronous deletion, re-adds the cached production
   node, then recursively removes the temp directory via `_remove_dir_recursive()`.
6. All steps are synchronous. `get_node("SaveManager")` returns the production
   instance immediately after `swap_out()` returns.

---

## Known Limitations (SaveManagerStub)

### G-10: autoload identifier still resolves to production

The global identifier `SaveManager` binds at engine init to the production node.
After `swap_in()`, `get_tree().root.get_node("SaveManager")` IS the stub, but
`SaveManager` (the identifier) still resolves to the original production instance.

Consequence: do **not** assert `SaveManager == stub` — this always compares
against production. Use path-based access: `get_tree().root.get_node("SaveManager")`.

Also: tests that need to verify SaveManager's `_on_save_checkpoint_requested`
handler fires after a GameBus emit must use the REAL `GameBus.save_checkpoint_requested`
emit on the REAL production `SaveManager`. The stub is for tests that exercise
direct-method paths (e.g., `set_active_slot`, `_path_for`, stub save/load) without
a GameBus signal roundtrip.

### Orphan dirs on test crash

`swap_out()` removes the temp dir. If a test crashes before `swap_out()` runs,
orphan dirs remain under `user://test_saves/`. Safe to delete manually:

```
rm -rf <project_data_dir>/test_saves/
```

On macOS the project data dir is typically:
`~/Library/Application Support/Godot/app_userdata/<project_name>/`

### _save_root_override is a test seam, not a public API

`_save_root_override` on the SaveManager script is a package-private field
(leading underscore is convention-only in GDScript). Production code MUST NOT
set it. It exists solely to redirect the save root for test isolation.

### Serial execution only

The static-var cache in `SaveManagerStub` is safe only when test functions within
a suite execute serially. GdUnit4 v6.1.2 runs test functions serially per suite
by default. Parallel execution within a suite would break this pattern.

---

## Related Files (SaveManagerStub)

| File | Purpose |
|------|---------|
| `save_manager_stub.gd` | The stub utility — `SaveManagerStub.swap_in()` / `swap_out()` |
| `save_manager_stub_self_test.gd` | Regression tests for the stub itself (AC-1..AC-7) |
| `save_manager_test.gd` | Story 002 — SaveManager skeleton + project.godot registration |

---

## Design Rationale (SaveManagerStub)

See Story 003 (`production/epics/save-manager/story-003-stub-for-gdunit4.md`) for
full design rationale, implementation notes, and the QA test case specifications
that this README summarises.

ADR reference: ADR-0003 §Constraints (testing: "SaveManager stub must be injectable
for tests, swap `user://` root to a temp path in `before_test`, cleanup in `after_test`")
(`docs/architecture/ADR-0003-save-load.md`).

See also `.claude/rules/godot-4x-gotchas.md` G-6 (orphan detection fires between
test body and `after_test` — explicit `swap_out()` in test body is required), G-3
(autoload scripts must not declare `class_name` — `SaveManagerStub` can use
`class_name` because it is a `RefCounted` helper, not an autoload), and G-10
(autoload global identifier binds at engine init — verify stub mount via path-based
`get_node()`, not the `SaveManager` global identifier).
