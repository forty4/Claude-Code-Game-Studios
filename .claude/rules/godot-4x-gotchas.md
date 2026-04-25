---
paths:
  - "src/**"
  - "tests/**"
  - "tools/**"
---

# Godot 4.x / GdUnit4 Gotchas

Session-discovered pitfalls that each cost ~30-60 min of debug-cycle time to rediscover. When you hit one, the error message rarely points at the real cause — this file is the lookup table.

## Environment

- **Godot**: 4.6 (see `docs/engine-reference/godot/VERSION.md` for pinned version + API verification)
- **GdUnit4**: v6.1.2 (vendored at `addons/gdUnit4/`)

Each entry: **Context** → **Broken** → **Correct** → **Discovered** (source story for historical reference).

---

## G-1 — Node inherited signals drift across Godot versions

**Context**: filtering user-declared signals on a Node via baseline subtraction.

**Broken**: Hardcoded inherited-signal count/names drift across engine versions. Godot 4.6.2 Node has **13** inherited signals, not the 9 from pre-4.4 training data. Hardcoded lists silently break on engine upgrades.

**Correct**: Dynamic baseline — call `Node.new().get_signal_list()` at test time, filter against whatever the current engine version returns.

```gdscript
# CORRECT — auto-adapts to engine version
static func get_user_signals(node: Node) -> Array[Dictionary]:
    var baseline: Node = Node.new()
    var inherited: Array[String] = []
    for sig: Dictionary in baseline.get_signal_list():
        inherited.append(sig["name"] as String)
    baseline.free()
    var result: Array[Dictionary] = []
    for sig: Dictionary in node.get_signal_list():
        if not (sig["name"] as String) in inherited:
            result.append(sig)
    return result
```

Extracted to `tests/unit/core/test_helpers.gd::TestHelpers.get_user_signals()` — reuse from there, don't re-implement.

**Discovered**: story-002 round 1 (signal-count test failed: 31 actual vs 27 expected).

---

## G-2 — `Array[T].duplicate()` silently demotes typed arrays

**Context**: copying a typed array.

**Broken**: `Array[T].duplicate()` returns untyped `Array`. The element-type annotation is lost at the call boundary.

**Correct**: Use `.assign(source)` to preserve the typed-array annotation.

```gdscript
# BROKEN — loses Array[String] annotation
var first_names: Array[String] = []
first_names = names.duplicate()    # silently demotes to untyped Array

# CORRECT — preserves typed-array annotation
var first_names: Array[String] = []
first_names.assign(names)
```

Same class as G-8 (`Signal.get_connections()` returning untyped).

**Discovered**: story-003 `/code-review` W-1.

---

## G-3 — Autoload script must NOT declare matching `class_name`

**Context**: registering a script as an autoload in `project.godot`.

**Broken**: autoload registered as `GameBus="*res://src/core/game_bus.gd"` + script declares `class_name GameBus` → parse error: `Class "GameBus" hides an autoload singleton.`

**Correct**: Autoload scripts use `extends Node` with NO `class_name`. The autoload name IS the global identifier.

```gdscript
# BROKEN — parse error on project load
class_name GameBus      # collides with autoload registration
extends Node

# CORRECT
extends Node            # no class_name; autoload name is the global identifier
```

**Test consequence**: tests for autoload scripts use `load(PATH).new()` instead of `ClassName.new()`. Static-var access via `(load(PATH) as GDScript).set("_var", value)`.

**Discovered**: story-005 round 1 (GameBusDiagnostics parse error blocked all integration tests).

---

## G-4 — GDScript lambdas cannot reassign outer primitive locals

**Context**: capturing signal args / return values from a lambda callback.

**Broken**: Lambdas can READ outer locals and CALL METHODS on captured reference types (`arr.append`, `dict[k] = v`, `obj.field = v`). Lambdas CANNOT reassign captured primitive locals (`String`, `int`, `bool`, `float`) — the assignment is scoped to the lambda, not propagated outward.

**Correct**: Use `var captures: Array = []` + `captures.append({...})` pattern. Read from `captures[0]` after the callback fires.

```gdscript
# BROKEN — captured_total stays at -1 forever
var captured_total: int = -1
emitter.signal_x.connect(func(total: int) -> void:
    captured_total = total    # assignment scoped to lambda; doesn't propagate
)
emitter.signal_x.emit(42)
await get_tree().process_frame
assert_int(captured_total).is_equal(42)   # FAILS: captured_total is still -1

# CORRECT — Array.append works via reference mutation
var captures: Array = []
emitter.signal_x.connect(func(total: int) -> void:
    captures.append({"total": total})
)
emitter.signal_x.emit(42)
await get_tree().process_frame
assert_int(captures[0].total as int).is_equal(42)   # PASSES
```

**Discovered**: story-005 AC-3 (round 2 runtime failure; tests showed initial values instead of captured ones despite warning being observed in stdout).

---

## G-5 — Prefix-based signal routing is fragile when prefix ≠ domain ownership

**Context**: routing signals to domain buckets via name-prefix matching.

**Broken**: `if sig_name.begins_with("battle_"): return "battle"` routes `battle_prepare_requested` and `battle_launch_requested` to the "battle" domain. But per ADR-0001 §Signal Contract Schema §1, those signals are emitted by ScenarioRunner and belong to "scenario" domain. Prefix alone is insufficient when the signal name was chosen for semantic clarity (what it triggers) rather than domain ownership (who emits it).

**Correct**: Explicit name-match guards MUST precede prefix rules for conflicting cases. ADR §Signal Contract Schema is always authoritative. Enforce via a full-coverage regression test.

```gdscript
func _route_to_domain(sig_name: String) -> String:
    # Explicit name-match guards BEFORE prefix rules for conflicts
    if sig_name == "battle_prepare_requested" or sig_name == "battle_launch_requested":
        return "scenario"
    # Then the prefix rules for the general case
    if sig_name.begins_with("battle_"): return "battle"
    # ... etc.
```

Pair with a regression test iterating every signal name → asserting routing result against an ADR-authoritative expected map. That test is the forcing function — bare-eye code review WILL miss this.

**Discovered**: story-005 `/code-review` (new regression test caught the bug during drafting).

---

## G-6 — GdUnit4 orphan detection fires BETWEEN test body exit and `after_test`

**Context**: tests that detach Nodes from the tree (e.g., stub-swap patterns, `remove_child` during testing).

**Broken**: Relying on `after_test` to clean up detached Nodes. GdUnit4's orphan detector runs between test body exit and `after_test` invocation. Detached Nodes held in static vars (e.g., `_cached_production`) get flagged. Exit code 101 (CI failure) when any orphan found.

**Correct**: Explicit cleanup at the END of every test body that detaches Nodes. `after_test` serves as crash-safety net only.

```gdscript
# BROKEN — orphan detected between test body and after_test
func test_stub_swap() -> void:
    GameBusStub.swap_in()
    # ... test logic ...
    # Implicit cleanup via after_test — orphan detected FIRST!

func after_test() -> void:
    GameBusStub.swap_out()

# CORRECT — explicit in-body cleanup
func test_stub_swap() -> void:
    GameBusStub.swap_in()
    # ... test logic ...
    GameBusStub.swap_out()   # explicit, before test body exits

func after_test() -> void:
    GameBusStub.swap_out()   # safety net (idempotent) for crash cases
```

**Also**: use `free()` not `queue_free()` on test-owned Nodes without external Callable references. `queue_free()` defers deletion to end-of-frame; GdUnit4 scans earlier.

**Discovered**: story-006 round 2 (1 orphan remaining after `queue_free` → `free` fix).

---

## G-7 — GdUnit4 silently treats parse-failed scripts as "no tests"

**Context**: adding a new test file.

**Broken**: A script with a parse error is silently reported as "no tests in file". Overall Summary passes with exit 0 if other suites pass. The broken file is invisible in standard output. **Exit code alone does NOT prove the test ran.**

**Correct**: Always verify `Overall Summary` test count matches expected, not just the exit code. Grep stderr for `Parse Error` or `Failed to load` to diagnose silent skips.

```bash
# CORRECT verification pattern
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c \
    > /tmp/test_run.log 2>&1
godot_exit=$?
grep -aE "Overall Summary" /tmp/test_run.log       # verify count matches expected
grep -a "Parse Error\|Failed to load" /tmp/test_run.log   # check for silent failures
```

**Discovered**: story-007 round 1 (integration file parse error hidden by exit 0 from passing unit suite; looked like a clean 48/48 pass while integration file never loaded).

---

## G-8 — `Signal.get_connections()` returns untyped `Array`

**Context**: inspecting signal connections in tests.

**Broken**: `Signal.get_connections()` in Godot 4.6 returns `Array` (untyped), not `Array[Dictionary]`. Assigning to `Array[Dictionary]` triggers runtime type-boundary error: `Trying to assign an array of type "Array" to a variable of type "Array[Dictionary]"`.

**Correct**: Declare outer as untyped `Array`; typed loop variable narrows element type locally. Or use `.assign()` (see G-2).

```gdscript
# BROKEN — runtime type-boundary error
var connections: Array[Dictionary] = GameBus.my_signal.get_connections()

# CORRECT — untyped outer, typed loop var narrows elements
var connections: Array = GameBus.my_signal.get_connections()
for conn: Dictionary in connections:
    var target: Object = conn.get("callable", Callable()).get_object()
    # ...
```

**Tip**: prefer `Signal.get_connections()` (Signal method, type-safe signal reference) over `Object.get_signal_connection_list("sig_name")` (stringly-typed signal name) when possible.

**Discovered**: story-007 round 2.

---

## G-9 — `%` operator binds to immediate left operand, not the full concat

**Context**: building multi-line format strings for `override_failure_message(...)` or any `%`-formatted string.

**Broken**: `"line 1 %d " + "line 2." % args` parses as `"line 1 %d " + ("line 2." % args)`. `%` binds only to `"line 2."` — no format specifiers there → runtime error `String formatting error: not all arguments converted during string formatting`. Tests may still pass (error doesn't fail assertions, only pollutes stdout), but CI logs are cluttered.

**Correct**: Wrap the full concat in parentheses before `%`.

```gdscript
# BROKEN — "line 2." has no %d, so "not all arguments converted"
assert_int(x).override_failure_message(
    "line 1 %d " +
    "line 2."
    % runner.received.size()
).is_equal(7)

# CORRECT — parens around the concat
assert_int(x).override_failure_message(
    ("line 1 %d " +
    "line 2.")
    % runner.received.size()
).is_equal(7)
```

Common footgun in long failure messages. Broke story-007 5× in a single hardening pass. Consider adding a lint pattern: detect `")" + ".*" %` at line starts where the `%` looks like a concat-tail rather than the last string's format operator.

**Discovered**: story-007 round 5.

---

## G-10 — Autoload global identifier binds at engine init, not dynamically to /root/Name

**Context**: stub-pattern tests that swap `/root/<Autoload>` with a fresh instance mid-test, then expect subscribers instantiated AFTER the swap to receive signals emitted on the stub.

**Broken**: assuming `GameBus.signal.connect(...)` inside a subscriber's `_ready()` resolves the `GameBus` identifier to whatever is currently at `/root/GameBus`. It does NOT. The autoload identifier (`GameBus`, `SceneManager`, etc.) is bound at engine registration time to the ORIGINALLY-REGISTERED node. When `GameBusStub.swap_in()` removes production and mounts a stub at `/root/GameBus`, pre-existing references to `GameBus` still point at the detached production instance. A new subscriber's `_ready()` connects to that detached production — emits on the stub never fire the subscriber's handler.

Symptom: handler never fires; state assertions fail with the initial value (e.g., state stays 0=IDLE when the test expected 1=LOADING_BATTLE after emit). Can masquerade as a `CONNECT_DEFERRED` timing issue; adding `await get_tree().process_frame` does NOT fix it because the handler is connected to the wrong signal source.

```gdscript
# BROKEN — handler never fires because sm subscribes to detached production GameBus
var bus_stub: Node = GameBusStub.swap_in()   # /root/GameBus now = stub
var sm: Node = SceneManagerStub.swap_in()    # sm._ready connects to GameBus autoload identifier
                                              # = detached production GameBus (NOT bus_stub)
bus_stub.battle_launch_requested.emit(payload)
await get_tree().process_frame
assert_int(sm.state as int).is_equal(sm.State.LOADING_BATTLE as int)   # FAILS: state still IDLE

# CORRECT — emit on the real GameBus autoload that sm is actually subscribed to
var sm: Node = SceneManagerStub.swap_in()    # sm._ready connects to GameBus (production autoload)
GameBus.battle_launch_requested.emit(payload)
await get_tree().process_frame
assert_int(sm.state as int).is_equal(sm.State.LOADING_BATTLE as int)   # PASSES
```

**Correct**: for tests that require a subscriber's handler to actually fire in response to an emit, DO NOT use GameBusStub.swap_in() in combination with SceneManagerStub.swap_in() (or any analogous autoload-stub + subscriber-stub pair). Emit on the REAL autoload identifier. Use the subscriber stub alone for fresh-state isolation.

GameBusStub remains useful for:
- Testing GameBus itself (signal declarations, connection tracking)
- Connecting test-only observers via `bus_stub.signal.connect(my_test_handler)` BEFORE swap_in-ing dependent subscribers
- Tests where NO live subscriber needs to fire (just that emit doesn't crash or leak)

**False positive trap**: if a test forces `_state` to a specific value before emit and asserts the state is UNCHANGED after emit, both "handler ran and was rejected by guard" and "handler never fired" produce the same assertion pass. Such tests can be false positives for guard coverage. Instead, force state to a distinct value AND observe a SECONDARY side effect (e.g., a signal that would fire IF the guard had been bypassed) to distinguish.

**Discovered**: story-004 round 3 (3 failing tests: AC-1 integration, AC-3 e2e integration, AC-7 retry unit all failed with handler-never-fired symptom. AC-2 guard test was passing as a false positive).

---

## G-11 — `as Node` cast on freed Object crashes even when declared Variant

**Context**: cleanup helpers that accept a possibly-freed Object reference (typical: `_battle_scene_ref` was `queue_free()`'d by another system; defensive test cleanup wants to free it again).

**Broken**: declaring the parameter type as `Variant` does NOT defer the freed-object check. The `as Node` cast inside the function body throws `"Trying to cast a freed object."` — the script runtime checks the object's liveness AT cast time, regardless of the declared static type of the holding variable.

```gdscript
# BROKEN — crashes at line 2 with "Trying to cast a freed object."
func _cleanup_battle_ref(battle_ref: Variant) -> void:
    var node: Node = battle_ref as Node   # ← throws even if Variant param
    if is_instance_valid(node) and node.is_inside_tree():
        # never reached
        get_tree().root.remove_child(node)
```

**Correct**: `is_instance_valid()` MUST precede any `as Node` cast. The Variant param is fine — but the liveness check must happen before the cast binds.

```gdscript
# CORRECT — guard before cast
func _cleanup_battle_ref(battle_ref: Variant) -> void:
    if not is_instance_valid(battle_ref):
        return
    var node: Node = battle_ref as Node   # ← safe now, object is live
    if node.is_inside_tree():
        get_tree().root.remove_child(node)
    node.free()
```

**Symptom**: `SCRIPT ERROR: Trying to cast a freed object.` in the test log, with exit code 100 and a GdUnit4 "1 errors" (NOT "1 failures") classification — errors are thrown exceptions, failures are assertion violations. The distinction matters: if GdUnit4 reports `errors: 1`, grep for this phrase before debugging test logic.

**Also applies to**: `as Control`, `as Node2D`, `as CanvasItem`, `as Resource`, `as RefCounted`, any `as T` where T is an Object subtype. `is_instance_valid(Variant)` is the universal guard.

**Test seam note**: this pattern is common in multi-cycle teardown tests where the same helper is called across iterations — early cycles pass valid refs, later cycles may pass freed refs from prior `queue_free()`. Centralize cleanup in a guarded helper; do not inline the cast in each call site.

**Discovered**: story-006 round 2 (AC-5 retry test `test_scene_manager_loss_retry_preserves_overworld_ref` crashed at cleanup; `_cleanup_battle_ref(battle_ref: Variant)` helper cast a freed BattleScene ref).

---

## G-12 — User `class_name` must not collide with Godot built-in classes

**Context**: declaring a user `class_name` for a Resource / Node / etc.

**Broken**: Godot 4.6 silently registers user `class_name` in `.godot/global_script_class_cache.cfg` even when the name collides with a built-in (e.g., `TileData`, `Tween`, `Material`). The engine built-in wins at parse-time resolution; user-class member access fails with the misleading error:

```
Parser Error: Could not resolve external class member "foo"
```

Even a minimal probe `var m: MyClass = MyClass.new(); print(m.field)` fails. `.uid` files are generated correctly, so the error is entirely parse-time, not import-time.

**Correct**: Choose a `class_name` that doesn't collide. Prefix with project/domain scope (`MapTileData` instead of `TileData`, `GameTween` instead of `Tween`). Before declaring any new `class_name`, search Godot docs for built-in class list and verify no collision.

```gdscript
# BROKEN — silently registered, but TileData built-in wins at parse time
class_name TileData extends Resource   # collides with Godot 4.4+ TileSet API
@export var coord: Vector2i

# CORRECT — project-scoped prefix
class_name MapTileData extends Resource
@export var coord: Vector2i
```

**Collision-prone names to avoid** (non-exhaustive): `TileData`, `TileMap`, `TileSet`, `Tween`, `Material`, `Curve`, `Shape2D`, `Shape3D`, `Timer`, `Animation`, `Node`, `Resource`. When in doubt, prefix.

**Symptom misdirection**: the error message points at member access, not at the `class_name` declaration. Without knowing this gotcha, diagnosis tends toward "is my export working?" / "is the import cache stale?" — neither of which is the actual cause.

**Discovered**: map-grid story-001 round-2 (parse error blocked ALL `map_resource_test` discovery; not resolved by cache-refresh editor passes; only resolved by the `TileData` → `MapTileData` rename).

---

## G-14 — New `class_name` declarations need a class-cache refresh before tests can resolve them

**Context**: adding a brand-new `class_name X extends Resource` (or `extends RefCounted`, etc.) and immediately running tests that reference `X` directly (`var foo := X.new()`).

**Broken**: tests fail at parse time with `Identifier "X" not declared in the current scope.` even though the `.gd` file defining `X` exists on disk and looks correct. The `Overall Summary` count holds at the previous baseline (per G-7, the test file is silently treated as "no tests" because it failed to parse). Exit code can still be 0 if the rest of the suite passes — the failure is invisible without inspecting the count or the stderr `Parse Error` lines.

Root cause: the global `class_name` registry lives in `.godot/global_script_class_cache.cfg` and is rebuilt only by an asset/script import pass. Until that pass runs, the new identifier is unknown to the GDScript parser even though the file exists. `.uid` files are auto-generated correctly on file creation, but the class-name registration is not.

**Correct**: between creating the file(s) and running tests for the first time, run a headless import pass to refresh `global_script_class_cache.cfg`. Then run the test suite normally.

```bash
# CORRECT — refresh the class-name registry before first test run
godot --headless --import --path .

# Then proceed with the standard test invocation
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
```

`--headless --import --path .` is the safe, deterministic refresh — it scans assets/scripts, rebuilds caches, and exits. `--quit-after 1` does NOT work as a substitute (it errors with "no main scene defined" on projects without a Main Scene set in `project.godot`).

**Symptom checklist** — if you see any of these, run the import pass first:
- `Parse Error: Identifier "X" not declared in the current scope.` for a class you just defined
- `Parse Error: Cannot infer the type of "var" because the value doesn't have a set type.` adjacent to the above (downstream effect)
- `Parse Error: Could not find type "X" in the current scope.` in test files referencing the new class
- Test count steady at previous baseline despite added test functions (G-7-style silent skip)

**Test consequence**: in `/dev-story` workflows, the orchestrator should run `--import` immediately after writing any new `class_name`-declaring file, before invoking the test suite for verification. Skipping this step costs ~2 minutes (one failed test run + diagnosis + import pass + retry); doing it pre-emptively costs ~5 seconds.

**Distinct from G-12**: G-12 is about user-name/built-in-name *collision* (which is a real, lasting parse error that can only be fixed by renaming). G-14 is about *registration timing* (a transient parse error fixed by an import pass). Both produce parse errors of the form "Identifier not declared", but the resolutions are different. If `--headless --import --path .` does not resolve the parse error, suspect G-12 instead.

**Discovered**: terrain-effect story-001 (TerrainModifiers + CombatModifiers added; first test run failed with "Identifier TerrainModifiers not declared" parse errors despite both files on disk; resolved by `godot --headless --import --path .` between file creation and the second test run, which then passed clean — 236/236).

---

## G-15 — GdUnit4 v6.1.2 lifecycle hooks: `before_test()` is the canonical name; `before_each()` is silently ignored

**Context**: writing a new GdUnit4 test suite and using a Jest/JUnit-style `before_each()` lifecycle hook for per-test setup (e.g. resetting static state).

**Broken**: GdUnit4 v6.1.2 only recognizes `before_test()` / `after_test()` (and suite-scope `before()` / `after()`). A function named `func before_each() -> void:` is NEVER invoked by the test runner — it's a regular method that just happens to exist on the suite. Tests pass or fail based on whatever state happened to leak in from previous tests. The bug is usually invisible because the tests pass coincidentally — the default class-init state often satisfies the assertions, especially in the first run.

```gdscript
# BROKEN — before_each is a phantom hook; never invoked
extends GdUnitTestSuite

var _state_dirty: bool = false

func before_each() -> void:    # ← NEVER CALLED by GdUnit4 v6.1.2
    _state_dirty = false
    SomeSingleton.reset_for_tests()

func test_first() -> void:
    SomeSingleton.set_value(42)
    _state_dirty = true
    assert_int(SomeSingleton.get_value()).is_equal(42)   # PASSES

func test_second() -> void:
    # _state_dirty is still true — before_each didn't run!
    # SomeSingleton.value is still 42 — reset didn't run!
    assert_int(SomeSingleton.get_value()).is_equal(0)    # FAILS
```

Symptom — failures of the form: "expected X but got Y, where Y is the value left behind by a previous test." Tests that depend on independent setup (e.g., loading a different fixture) all fail with stale state from the previous test. Tests that happen to leave the right state for the next test pass coincidentally.

**Correct**: use `before_test()` / `after_test()`. These are the names the runner actually calls (verified in `addons/gdUnit4/src/core/execution/stages/GdUnitTestCaseBeforeStage.gd:18`: `await test_suite.before_test()`).

```gdscript
# CORRECT — before_test is invoked before each test
extends GdUnitTestSuite

var _state_dirty: bool = false

func before_test() -> void:
    _state_dirty = false
    SomeSingleton.reset_for_tests()

func after_test() -> void:
    # cleanup if needed
    pass
```

**Why this bug hides itself**: tests that don't rely on cross-test isolation — e.g., tests that only read class constants, or tests where the default state happens to match the expected setup — pass even with `before_each` as a phantom. The bug only surfaces when a test depends on `reset_for_tests()` actually running, which typically happens when a test mutates state via a function call (like `load_config(custom_path)`) and the next test expects fresh state. For ~6 tests that DON'T reset state via function calls, you might never notice.

**Discovery validation pattern**: if a new test fails with "expected X but got Y" where Y is suspiciously the value from a prior test in the same suite — and `reset_for_tests()` is called in `before_each()` — audit ALL existing test files in the project for `before_each` usage. The fix is mechanical: rename to `before_test()` everywhere.

```bash
# Find all phantom before_each / after_each hooks across the test suite
grep -rn "func before_each\|func after_each" tests/
# Replace with the canonical names
```

**Future-proofing**: GdUnit4 newer versions (v7+) MAY add `before_each` / `after_each` aliases (Jest-style). When upgrading GdUnit4, re-verify by reading `addons/gdUnit4/src/core/execution/stages/GdUnitTestCaseBeforeStage.gd` for the actual method name the runner invokes. Until then, only `before_test()` / `after_test()` are safe.

**Distinct from G-6**: G-6 is about WHEN cleanup runs (orphan detector fires before `after_test`). G-15 is about WHETHER the cleanup hook runs at all (`before_each` doesn't, `before_test` does). Both can produce "state from a previous test leaked in" symptoms but for different reasons. If `before_test()` is correct and tests still leak state, suspect G-6.

**Discovered**: terrain-effect story-003 (3 test files used `func before_each()`; new config tests failed with "got 15" where 15 was the production-fixture HILLS value from a prior test's `load_config()` call. Renaming all three test files' `before_each` → `before_test` fixed all 6 failures without any production code change. Story-002's tests passed despite the same bug because the default class state happened to satisfy assertions and AC-7 isolation canary explicitly called `reset_for_tests()` inline within the test body).

---

## Verification Pattern Summary

When testing changes that touch any of the above areas, always:

1. Run full test suite (`tests/unit + tests/integration`) — capture `Overall Summary` (G-7)
2. Verify test count matches expected — not just exit code
3. `grep` stderr for: `Parse Error`, `Failed to load`, `String formatting error`, `orphan`
4. If a lint script is in play (`tools/ci/*.sh`), run it separately and verify its exit-code triage (0/1/2+ distinction)

## Adding a new gotcha

When a new Godot/GdUnit4 pattern bites the team:

1. Add entry in the **G-N** format above: Context → Broken → Correct → Discovered
2. Keep the Broken example real (copy-paste from the offending code)
3. Link the source story for historical trace
4. Update `docs/tech-debt-register.md` TD-013 with a one-liner reference
5. Consider if a lint can catch it → add to `tools/ci/`

## Cross-References

- `.claude/rules/test-standards.md` — general test naming, structure, isolation
- `.claude/rules/engine-code.md` — engine-code hot-path rules (Godot-agnostic)
- `docs/engine-reference/godot/VERSION.md` — pinned engine version + API verification
- `docs/tech-debt-register.md` TD-013 (original accumulation), TD-019 (G-10 discovery — story-004), TD-021 (G-11 discovery — story-006)
- `tools/ci/lint_per_frame_emit.sh` — template for Godot-specific CI lint scripts
