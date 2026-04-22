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
