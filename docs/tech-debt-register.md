# Technical Debt Register

Tracks deferred improvements, workarounds, and pre-existing issues surfaced during story implementation. Maintained via `/story-done` entries and `/tech-debt` audits.

Format:
- **ID**: TD-NNN (zero-padded, stable, never reused)
- **Origin**: story or skill that surfaced it
- **Category**: process | infra | code | docs | build
- **Severity**: low | medium | high
- **Status**: open | in-progress | resolved (with resolving commit/PR)

---

## TD-001 — gdUnit4 release install pattern needs team guidance

**Origin**: story-000 Deviation #2
**Category**: process
**Severity**: low
**Status**: open

gdUnit4's GitHub repo structure contains the addon at a nested `addons/gdUnit4/` subdirectory (because the repo IS a Godot project that uses the addon). Git submodules clone the full repo, producing `addons/gdUnit4/addons/gdUnit4/plugin.cfg` — incompatible with Godot's flat plugin discovery.

Current mitigation: vendored install pinned via `addons/gdUnit4/VERSION.txt`, upgrade path documented in that file.

Remediation options for future consideration:
1. Accept vendored install as the policy (no debt — just document in tests/README)
2. Switch to Godot Asset Library install flow for first-time contributors (requires editor interaction, breaks clean-clone workflow)
3. Script an automated fetch-and-extract in a `tools/install_gdunit4.sh` helper

**Next review**: when upgrading gdUnit4 (check if install UX changed)

---

## TD-002 — Legacy test harness wrapper pattern retired

**Origin**: story-000 Deviation #3
**Category**: docs
**Severity**: low
**Status**: resolved (story-000 — commit `c870d7e`)

Previous `tests/gdunit4_runner.gd` wrapper (authored 2026-04-18, pre-install) was a thin wrapper around `GdUnit4CliRunner.gd` from a pre-v6.x gdUnit4 API. Incompatible with v6.x on two fronts:
- Tool renamed: `GdUnit4CliRunner.gd` → `GdUnitCmdTool.gd`
- Both wrapper and CmdTool extend `SceneTree` — one cannot cleanly delegate to the other

Resolved: deleted the wrapper; `tests/README.md` now documents direct `GdUnitCmdTool.gd` invocation. The pre-run `godot --headless --import` step is called out explicitly (required to populate class cache for headless gdUnit4 runs).

Kept as historical note: any future "let's re-add a local runner wrapper" suggestion should check this entry first.

---

## TD-003 — CI workflow permissions were missing (pre-existing)

**Origin**: story-000 Deviation #5
**Category**: build
**Severity**: medium (was blocking AC-3 of any test-passing story until fixed)
**Status**: resolved (story-000 — commit `bbc5c83`)

`.github/workflows/tests.yml` was authored in an earlier session without an explicit `permissions:` block. GitHub's default-locked PR workflow permissions prevented `dorny/test-reporter@v3` (inside `MikeSchulze/gdUnit4-action@v1`) from publishing check-run results with `HttpError: Resource not accessible by integration`. Tests passed internally but the overall workflow marked red.

Resolved: added `contents:read + checks:write + pull-requests:write` to the `gdunit4` job.

Pattern to watch for: any future workflow using result-publishing actions (e.g. `dorny/test-reporter`, `coverallsapp/github-action`) needs explicit permissions. Consider adding a lint step or CODEOWNERS review trigger for `.github/workflows/*.yml` changes.

---

## TD-004 — Minor test-coverage gaps in payload_classes_test.gd

**Origin**: story-001 /code-review advisory findings
**Category**: code
**Severity**: low
**Status**: open

`tests/unit/core/payload_classes_test.gd` covers all 8 story ACs (7/7 PASSED at close), but 3 minor coverage gaps identified in review:

1. **Default-state assertions not covered**: Tests verify behavior after assignment but do not assert fresh-instance defaults for `BattlePayload.map_id == ""`, `BattlePayload.victory_conditions == null`, `ChapterResult.outcome == BattleOutcome.Result.LOSS`. Adding 3 lines to existing test functions would close this.

2. **Sentinel value not round-tripped**: `InputContext.target_unit_id = -1` is the documented sentinel for "no unit targeted" but the AC-4 test only exercises `42`. Adding `ic.target_unit_id = -1; assert_int(ic.target_unit_id).is_equal(-1)` would exercise the sentinel explicitly.

3. **AC-6 regex brittleness**: `: Array[^\[]` lint pattern does not handle inline trailing `# Array...` comments because the line-comment stripper only removes full-line `#`. No current file triggers a false positive, but adding a new payload with an inline trailing comment mentioning "Array" could. Recommendation: either strip inline-trailing `#` before regex, OR defer entirely to Story 003 CI lint (planned per AC-8 story text).

Remediation path:
- Option A: fix all 3 in a 15-minute follow-up PR on payload_classes_test.gd
- Option B: defer items 1+2 to Story 004 (payload serialization test — will instantiate and round-trip all payloads, implicitly covering defaults + sentinels); defer item 3 to Story 003 (CI lint — the authoritative owner per AC-8).

**Next review**: when Story 003 (CI lint) or Story 004 (serialization test) lands — either will subsume a subset of these gaps.

---

## TD-005 — BattleStartEffect.value type may need float

**Origin**: story-001 /code-review suggestion (gdscript-specialist)
**Category**: code
**Severity**: low
**Status**: open (future-ADR concern)

`src/core/payloads/battle_start_effect.gd` declares `value: int = 0`. This is a PROVISIONAL placeholder — the final shape is locked by the future Grid Battle ADR. If the ADR specifies fractional multipliers (e.g., `value: 1.5` for a 150% damage buff), the field will need to change to `float`.

Changing `int` → `float` on an `@export` field on a `Resource` is a minor breaking change:
- Saved `.tres` / `.res` files with the old int serialization will still load (Godot auto-converts numeric types)
- Any consumer code doing strict `== 0` comparison without type conversion may break

Remediation:
- Flag this when the Grid Battle ADR is authored — the ADR author should confirm int vs float
- If float, bump the payload schema version OR add a migration note to ADR-0003 save/load migration registry

**Next review**: when the Grid Battle ADR enters /architecture-decision drafting.

---

## TD-006 — ADR-0001 §Key Interfaces code-block is stale (7 banners vs 10)

**Origin**: story-002 /code-review WARNING W-1 (gdscript-specialist)
**Category**: docs
**Severity**: low
**Status**: open

The `docs/architecture/ADR-0001-gamebus-autoload.md` §Key Interfaces section contains an embedded code-block of `game_bus.gd` showing the autoload file structure. That code-block still uses 7 grouped domain banners (Grid Battle / Turn Order / HP-Status lumped under one banner, etc.) — the pre-amendment form.

The post-amendment Signal Contract Schema tables in the same ADR define 10 separate domains, and `/architecture-review` advisory M-2 (2026-04-18) recommended implementing with 10 split banners. Story 002's `src/core/game_bus.gd` correctly implements 10 banners per the schema — but a programmer referencing only the ADR's §Key Interfaces code-block will see the old 7-banner form and may produce inconsistent derivative work.

Remediation:
- Update the §Key Interfaces code-block in ADR-0001 to show 10 banners matching the implemented `game_bus.gd`
- Keep the ADR's Status: Accepted (no supersession needed — this is a documentation sync, not a contract change)
- Add a dated changelog line: `2026-04-20 — §Key Interfaces code-block updated to match 10-banner implementation per advisory M-2`
- Do NOT add inline guidance to §Evolution Rule about keeping the code-block in sync (it's already stated)

**Next review**: before Stories 003/004/005 begin — those stories will likely reference §Key Interfaces and should see the current form.

---

## TD-007 — AC-4 lint regex doesn't cover static/enum/@tool (deferred to Story 008)

**Origin**: story-002 /code-review qa-tester Gap 2 (advisory)
**Category**: code
**Severity**: low
**Status**: deferred (planned resolver: Story 008 CI lint)

`tests/unit/core/game_bus_declaration_test.gd::test_gamebus_script_has_no_var_func_const_class_declarations` uses regex `^(var|func|const|class|@onready|@export)\s`. Three patterns are NOT covered:
- `static var` and `static func` — `static` prefix means `^var`/`^func` don't match
- `enum` — declares a named constant set (effectively state)
- `@tool` — would run the autoload in-editor, a meaningful semantic change

The story's AC-4 spec text mirrors the regex exactly, so this is a spec gap, not just a test gap. A developer could introduce a `static var` cache in `game_bus.gd` without failing the current test — subverting the zero-state rule.

Remediation path:
- Story 008 (CI lint) is the authoritative owner of this lint and will tighten the regex. Defer the fix there.
- When Story 008 lands: update both the Story 002 test AND the story-002 AC-4 text to match.
- Alternative (if Story 008 slips): add the 3 missing patterns to the existing test regex as a point fix — 1-line change.

**Next review**: when Story 008 enters /dev-story.

---

## TD-008 — EXPECTED_SIGNALS transcription risk (process gap, not code gap)

**Origin**: story-003 /code-review qa-tester ADVISORY Gap #1
**Category**: process
**Severity**: medium (silent divergence possible; only caught at human PR review)
**Status**: open

`tests/unit/core/signal_contract_test.gd` uses a hardcoded `EXPECTED_SIGNALS` reference list of 27 signal entries (per ADR-0001 Implementation Note §3, which explicitly rejected parsing the ADR markdown at test time). This design creates a subtle failure mode:

If an implementer transcribes a signal incorrectly into EXPECTED_SIGNALS AND the same error propagates to `src/core/game_bus.gd`, all 6 tests pass while BOTH files silently diverge from the ADR-0001 §Signal Contract Schema table.

Scenarios:
- Wrong `class_name` for a TYPE_OBJECT arg (e.g., `"BattleOutcom"` typo in both places)
- Wrong arg order (both files have same wrong order; ADR has correct order)
- Wrong arg type (both files have TYPE_INT; ADR specifies TYPE_VECTOR2I)

The test cannot self-mitigate without parsing the ADR markdown (explicitly rejected). Mitigation must therefore be a process control, not a code addition:

1. Add PR checklist item to `.github/PULL_REQUEST_TEMPLATE.md`:
   > "Signal contract changes: have you verified correspondence between (a) `docs/architecture/ADR-0001-gamebus-autoload.md` §Signal Contract Schema, (b) `tests/unit/core/signal_contract_test.gd` EXPECTED_SIGNALS, and (c) `src/core/game_bus.gd` signal declarations?"
2. CODEOWNERS entry: require review on `src/core/game_bus.gd` OR `tests/unit/core/signal_contract_test.gd` changes from an architecture owner.
3. Consider dual-review gate: if any PR touches EITHER of the two files AND the ADR, at least two reviewers must sign off on three-way correspondence.

**Next review**: before first ADR-0001 amendment lands (whichever story introduces the next signal or modifies an existing one).

---

## TD-009 — Autoload boot path not exercised by existing tests

**Origin**: story-003 /code-review qa-tester ADVISORY Gap #2 (shared with story-002)
**Category**: code
**Severity**: low (catches typos/wrong-path autoload registration that `--import` alone may not)
**Status**: open

Both `tests/unit/core/game_bus_declaration_test.gd` (story 002) and `tests/unit/core/signal_contract_test.gd` (story 003) use the pattern:
```gdscript
var script: GDScript = load(GAME_BUS_PATH)
var instance: Node = auto_free(script.new())
```

This tests the script's declared signals at parse time, which is correct and sufficient for the drift-gate purpose. However, it does NOT exercise the project.godot autoload boot path:

- If someone edits project.godot and changes `GameBus="*res://src/core/game_bus.gd"` to a wrong path (typo, moved file not updated), `load(GAME_BUS_PATH)` still succeeds via the hardcoded test const, but `/root/GameBus` never mounts at game runtime
- `godot --headless --import` partially catches this (fails on unresolvable autoload path at import), but may not catch autoload-registered-but-name-wrong scenarios
- Result: game crashes on first scene load with `Cannot access "GameBus" — autoload not mounted` — caught by humans, not CI

Recommendation: add a minimal live-tree smoke test in a future story (~20 LoC):
```gdscript
func test_gamebus_autoload_mounts_at_runtime() -> void:
    var gamebus_node: Node = get_tree().root.get_node_or_null("GameBus")
    assert_bool(gamebus_node != null).override_failure_message(
        "GameBus autoload not mounted at /root/GameBus — check project.godot [autoload] registration."
    ).is_true()
```

Assign to qa-lead for story targeting (likely a sub-story under the gamebus epic or a dedicated infrastructure story). This is not urgent — Godot's own boot-path failure messages are fairly clear — but it closes the last remaining silent-failure mode in the GameBus gate.

**Next review**: next time `project.godot` `[autoload]` section gains a new entry (e.g., SceneManager registration lands — story from scene-manager epic). That's the natural opportunity to add live-tree smoke tests covering all registered autoloads at once.

---

## TD-010 — payload_serialization_test.gd after_test silent-failure drop

**Origin**: story-004 /code-review GAP-1 (qa-tester) + S-3 (gdscript-specialist)
**Category**: code
**Severity**: low (CI runners are ephemeral; local repeated runs could slowly leak)
**Status**: open

`tests/unit/core/payload_serialization_test.gd::after_test` iterates `_tmp_paths` and calls `DirAccess.remove_absolute(ProjectSettings.globalize_path(path))` without checking the return value. If a removal silently fails (file locked, permissions, path typo), the tmp file stays in `user://tmp/` and accumulates across runs.

Current impact:
- CI: near-zero — GitHub Actions runners are ephemeral; `user://` never survives past the job
- Local dev: low but real — repeated `godot --headless --path . -s .../GdUnitCmdTool.gd ...` invocations could leave dozens of `payload_test_*.tres` files over a week of work

Remediation options:
1. `push_warning` on non-OK return — observable without test failure (recommended)
2. `assert_int(DirAccess.remove_absolute(...)).is_equal(OK)` — upgrade to test failure (too strict; cleanup is not the test's subject under study)
3. One-line before_test guard that clears stale `payload_test_*.tres` files unconditionally (cleanup-on-start pattern — handles any leftover from a crashed prior run)

Recommended resolver: combine (1) push_warning + (3) before_test stale-file sweep. Small LoC cost (~5 lines).

**Next review**: when the save-manager epic's own serialization test lands (same cleanup pattern will be copy-pasted — fix the source of truth here first to avoid propagating the gap).

---

## TD-011 — payload_serialization_test.gd factory functions lack field-count guard

**Origin**: story-004 /code-review GAP-3 (qa-tester)
**Category**: code
**Severity**: low (maintenance hazard — only triggers when a payload class gains a new @export field)
**Status**: open

Each `_make_populated_*` factory in `payload_serialization_test.gd` populates every `@export` field of its target class with a non-default value. This is correct today, but there is no mechanical guard against future drift.

Failure mode: A developer adds a new `@export` field to an existing payload class (e.g., `BattleOutcome.mvp_unit_id: int`) but forgets to update `_make_populated_battle_outcome()`. The new field carries its type-default (`0`) through save → load → assertion. The assertion `lo.mvp_unit_id == original.mvp_unit_id` passes vacuously because both are `0`. The field appears covered but is actually untested.

Mitigation options:
1. **Per-factory field-count comments** — e.g., `# 6 fields — update this factory if BattleOutcome adds a field` above each factory. Visual reminder during code review; zero runtime cost; relies on reviewer discipline.
2. **Factory assertion** — assert `original.get_property_list().filter(...)` returns exactly N where N is the declared field count. Runtime check; catches the drift automatically but requires per-factory N constant + property filter plumbing (~8 LoC/factory).
3. **Separate field-count test** — `test_battle_outcome_has_exactly_N_export_fields` using `get_property_list()` to count `PROPERTY_USAGE_STORAGE` fields. Auxiliary-test pattern; couples test count to story 001 payload shape; fails loudly when class gains a field without the story owner noticing.

Recommended resolver: option 1 (comments) as a cheap-and-cheerful maintenance prompt. Upgrade to option 3 if/when the codebase grows enough that payload shape churn becomes a hot spot (e.g., after save-manager epic locks SaveContext's shape and 1-2 other payloads see meaningful field additions).

**Next review**: when any payload class gains a new `@export` field — check whether the corresponding factory was updated in the same PR. If yes, close this as resolved-by-discipline. If no, escalate to option 2 or 3.

---

## TD-012 — GameBusDiagnostics `_on_any_emit` hot-path Dictionary allocations (accepted trade-off)

**Origin**: story-005 /code-review BLOCKING (godot-gdscript-specialist); resolved via Option C accept-with-documentation
**Category**: code
**Severity**: low (measured 6× under budget; debug-only path)
**Status**: accepted (revisit trigger documented inline)

`src/core/game_bus_diagnostics.gd::_on_any_emit` fires on every GameBus emission and performs 2 Dictionary operations per call:
```gdscript
var domain: String = _signal_to_domain.get(sig_name, "unknown") as String
_domain_counts[domain] = (_domain_counts.get(domain, 0) as int) + 1
```

GDScript Dictionary read/write involves Variant boxing — technically a violation of `.claude/rules/engine-code.md` "ZERO allocations in hot paths" rule. A strict zero-alloc alternative would replace `_domain_counts: Dictionary` with 10 individual `var _count_<domain>: int` members + a `match` statement.

**Why accepted as-is** (documented in the handler docstring):
- (a) Diagnostic is **debug-only** — `queue_free()`'d in release builds at `_ready()`
- (b) **Measured overhead**: 0.53 µs/emission = ~0.016 ms/frame at 30 emits/frame, which is **6× under the <0.1 ms/frame budget** per ADR-0001 §Implementation Guidelines §8
- (c) 10 fixed keys → predictable 10 writes/frame, no unbounded growth
- (d) Dictionary form is more maintainable — new domains added by inserting one entry vs. adding a new int member + match arm + reset line

**Revisit trigger** (documented in code):
- Measured overhead approaches the 0.1 ms/frame budget on any supported platform (macOS, Windows, Linux, Android, iOS)
- OR the diagnostic is ever retained in release builds for telemetry (ADR change required)
- Either would invalidate the debug-only justification; rewrite `_on_any_emit` to use individual int members + match at that point.

**Measurement provenance**: `test_diagnostics_overhead_under_advisory_budget` (AC-6 test) logs per-run overhead. 0.962ms total for 1800 emissions (60 frames × 30 emits) on the current dev machine, 2026-04-21. Future regression would show as overhead growth in CI stdout (AC-6 prints the result).

**Next review**: if the diagnostic's AC-6 perf log shows any single emission approaching 5 µs (current: 0.53 µs), investigate. Or if a future story proposes retaining diagnostics in release builds.

---

## TD-013 — Codify 9 GDScript 4.x / GdUnit4 gotchas into project rule file

**Origin**: stories 002-007 discovered 9 distinct Godot 4.x / GdUnit4 behaviors that each cost ~30-60 min of debug-cycle time to rediscover
**Category**: docs
**Severity**: medium (cumulative friction across ~9 gotchas × 30-60min each = 4.5-9h per contributor onboarding)
**Status**: **resolved 2026-04-22** — `.claude/rules/godot-4x-gotchas.md` (see commit on branch `feature/td-013-godot-4x-gotchas-rulefile`)

Across the first 5 gamebus stories, the following GDScript 4.x / Godot 4.6 behaviors bit us during implementation or testing. Each is worth documenting in a dedicated rule file (suggested: `.claude/rules/godot-4x-gotchas.md` or appending to existing `.claude/rules/test-standards.md`):

1. **Godot 4.6.2 Node has 13 inherited signals, not 9**
   Pre-cutoff LLM training knew ~9 (`ready`, `tree_*`, etc.). Godot 4.4+ added 4 more: `editor_description_changed`, `editor_state_changed`, `property_list_changed`, `script_changed`. Pattern: use dynamic `Node.new().get_signal_list()` baseline at test time — never hardcode the inherited signal list. (Source: story-002 game_bus_declaration_test.)

2. **`Array[T].duplicate()` silently demotes typed arrays to untyped `Array`**
   In Godot 4.6, calling `.duplicate()` on an `Array[String]` (or any typed array) returns an untyped `Array`. The static type annotation is lost at the call boundary. Pattern: use `.assign(source)` instead, which preserves the typed-array annotation. (Source: story-003 signal_contract_test W-1.)

3. **Autoload-registered scripts MUST NOT declare `class_name` matching the autoload name**
   Godot throws "Class X hides an autoload singleton" parse error at project load. Pattern: autoload scripts use `extends Node` with NO `class_name`. Tests access the script via `load(PATH).new()` rather than `ClassName.new()`. Static vars accessed via `(load(PATH) as GDScript).set("_var", value)`. (Source: story-005 round 1.)

4. **GDScript lambdas CAN mutate captured reference types but CANNOT reassign captured primitive locals**
   Lambdas can call `.append()` on captured Arrays or write `dict[k] = v` on captured Dictionaries (both are method calls on reference-type pointers). Lambdas CANNOT reassign outer `String`, `int`, `bool`, `float` locals — the assignment stays scoped to the lambda. Pattern: always use `var captures: Array = []` + `captures.append({...})` for signal captures in tests. (Source: story-005 AC-3 fix round 2.)

5. **Prefix-based signal routing is fragile when the prefix is chosen for semantic clarity rather than domain ownership**
   Example: `battle_prepare_requested` starts with `battle_` but is emitted by ScenarioRunner (Scenario Progression domain), not BattleController. A naive prefix-match routes it wrong. Pattern: explicit name-match guards MUST precede prefix rules for conflicting cases, and a full-coverage regression test (iterate every signal, compare routing result to ADR-authoritative domain) is the enforcement mechanism. (Source: story-005 /code-review bug caught during test drafting.)

**Remediation path**:
- Option A (minimal): Append a "GDScript 4.6 gotchas" section to `.claude/rules/test-standards.md` listing the items with one-line examples.
- Option B (organized): Create `.claude/rules/godot-4x-gotchas.md` as a standalone rule file, add cross-references from `test-standards.md` and `engine-code.md`.
- Option C (thorough): Add to `docs/engine-reference/godot/` as a dedicated gotchas page with cross-references to version-specific changelog entries.

Recommended: Option B — standalone file, well-cross-referenced. ~200 lines total. Saves ~30-60 min per gotcha-triggered test-cycle delay for every future contributor.

**Update 2026-04-21 (story-006)**: 6th gotcha discovered — GdUnit4 orphan detection fires between test body exit and `after_test`. Detached Nodes held in static vars are flagged as orphans; exit code 101 when any orphan found (CI failure gate). Fix: explicit cleanup at end of test body that creates/detaches Nodes; `after_test` serves only as crash-safety net. Add this item when creating the rule file.

**Update 2026-04-21 (story-007)**: 3 more gotchas discovered in a single story (total now 9; rule file creation is overdue):

7. **GdUnit4 silently treats parse-failed scripts as "no tests"** — a script with a parse error is reported as "no tests in file"; Overall Summary passes with exit 0 if other suites pass. Must check Overall Summary count matches expected, not just exit code. `grep "Parse Error\|Failed to load"` on the test log to diagnose silent skips.

8. **`Signal.get_connections()` returns untyped `Array`**, not `Array[Dictionary]` — same class as gotcha #2 (`Array[T].duplicate()` demotion). Cannot assign to `Array[Dictionary]` typed variable (runtime type-boundary error). Declare outer as untyped `Array` and use `for x: Dictionary in connections:` loop-var narrowing, OR use `.assign()` to preserve typed-outer annotation.

9. **`%` operator binds to immediate left operand** — `"a" + "b" % args` parses as `"a" + ("b" % args)`, NOT `("a" + "b") % args`. Multi-line string concatenations feeding into `%` always need explicit parentheses around the concat. Common pattern: `override_failure_message(("line 1 %d " + "line 2.") % arg)`. Broken version produces "String formatting error: not all arguments converted" — non-failing runtime warning, but pollutes CI stdout. This bit the same story 5 times in a single hardening pass.

**Next review**: N/A — resolved. `.claude/rules/godot-4x-gotchas.md` created 2026-04-22 with all 9 gotchas in Context → Broken → Correct → Discovered format, plus verification pattern summary, "Adding a new gotcha" contributor guide, and cross-references from `test-standards.md` and `engine-code.md`. The file is path-scoped (`src/**` + `tests/**` + `tools/**`) and will be surfaced automatically by the rule system when any GDScript work begins.

**Resolution evidence**: commit on branch `feature/td-013-godot-4x-gotchas-rulefile` adds `.claude/rules/godot-4x-gotchas.md` + one-line cross-reference additions to `.claude/rules/test-standards.md` and `.claude/rules/engine-code.md`.

**Future maintenance**: when a 10th gotcha is discovered, append a G-10 entry using the established format. Update this TD-013 entry only if the structure/scope changes materially.

---

## TD-014 — Verify CI registers GameBusDiagnostics autoload for AC-7 coverage

**Origin**: story-006 /code-review qa-tester ADVISORY Gap 2
**Category**: build
**Severity**: low (local tests pass; only CI coverage of one assertion path is in question)
**Status**: open

`tests/unit/core/game_bus_stub_self_test.gd::test_stub_coexists_with_gamebus_diagnostics` (AC-7) has a conditional assertion (c) that only runs when `GameBusDiagnostics` is actively mounted at `/root/GameBusDiagnostics`:

```gdscript
var diagnostics: Node = get_tree().root.get_node_or_null("GameBusDiagnostics")
if diagnostics == null or diagnostics.is_queued_for_deletion():
    print("[AC-7] GameBusDiagnostics not active — running without diagnostic coexistence check")
    diagnostics = null
...
if diagnostics != null:
    # Assertion (c) — signal-connection-persistence through detach/reattach
    ...
```

Assertion (c) is the most structurally interesting part of AC-7: it verifies that Godot signal connections persist through `remove_child` / `add_child` cycles, enabling GameBusDiagnostics to re-engage with production after swap_out. If this invariant ever breaks in a future Godot version, AC-7 must catch it.

**Risk**: if CI runs in release-build mode (or if GdUnit4 somehow bypasses project.godot autoload registration), `GameBusDiagnostics` is absent and assertion (c) becomes dead code. The CI log would print "[AC-7] GameBusDiagnostics not active" and silently skip the check.

**Investigation needed**:
1. Inspect CI logs from PR #5 (story-005) and PR #6 (story-006) — search for "[AC-7] GameBusDiagnostics not active" print. If present, CI is skipping assertion (c). If absent, assertion (c) IS running in CI (good).
2. Verify `.github/workflows/tests.yml` uses `godot --headless` in debug build mode (default is debug; release requires explicit flag).
3. Confirm `project.godot` `[autoload]` block is honored by `MikeSchulze/gdUnit4-action@v1` (GitHub Action for Godot test runs).

**Remediation** (if investigation finds assertion (c) is skipped in CI):
- Option A: remove the `if diagnostics == null` conditional — require diagnostics to be present for AC-7 to run. If absent, fail loudly. This is the "strictest" path.
- Option B: add a standalone signal-persistence test (no diagnostic dependency) per engine-specialist W-4 from /code-review. ~2 LoC: `var n := Node.new(); var h: Callable = func(): counter += 1; n.ready.connect(h); root.remove_child(n); root.add_child(n); n.ready.emit(); assert(counter == 1)`. Independent of diagnostics presence.
- Option C: accept the conditional skip as-is; note in CI dashboard that assertion (c) is only verified in debug builds.

Recommended: Option B (standalone test) — most robust, independent of autoload configuration, catches Godot version regressions immediately.

**Next review**: when a CI log from any gamebus epic PR confirms whether "[AC-7] GameBusDiagnostics not active" appears. Quick inspection task (<5 min) — can be closed immediately after verification.

---

## TD-015 — MockScenarioRunner `_consumed_once` semantic drift vs real ScenarioRunner

**Origin**: story-007 /code-review qa-tester Mock-vs-Real Equivalence Risk
**Category**: code
**Severity**: medium (test may prove property the real implementation does not preserve)
**Status**: open

`tests/integration/core/mock_scenario_runner.gd::MockScenarioRunner._consumed_once` is a flat boolean that locks after the first valid emission. The real `ScenarioRunner` (owned by Scenario Progression epic, not yet implemented) will per TR-scenario-progression-003 / EC-SP-5 use an IN_BATTLE state machine — the duplicate-guard fires only when state is outside IN_BATTLE.

**Divergence scenarios**:
1. **Re-entry**: Real ScenarioRunner transitions OVERWORLD → IN_BATTLE → OVERWORLD → IN_BATTLE across a multi-chapter session. On each IN_BATTLE entry, the state-machine guard resets (a fresh battle can produce a fresh outcome). Mock's `_consumed_once` is NEVER reset after construction — it locks permanently.
2. **Multi-guard interaction**: Real ScenarioRunner may guard multiple signals (battle_outcome_resolved, scenario_complete, others) via the same state check. Mock only guards one signal. Interactions between guards are not tested.

**Risk**: Story 007 AC-4 (`test_cross_scene_emit_duplicate_emission_ignored_per_ec_sp5`) asserts the EC-SP-5 duplicate-guard works via `_consumed_once == true after first emit`. If the real ScenarioRunner resets its IN_BATTLE state machine on battle entry, a second battle would NOT be blocked by the guard — but the test would still pass on the mock. The test proves a property the real system does not preserve.

**Remediation path** (choose when real ScenarioRunner is implemented):

1. **Option A (minimal)**: Add a `reset_for_new_battle()` method to MockScenarioRunner; downstream multi-battle integration tests call it to simulate re-entry. Does NOT match real behavior but closes the test coverage gap.

2. **Option B (preferred)**: Replace MockScenarioRunner's `_consumed_once` with a state enum (IDLE / IN_BATTLE / RETURNING) matching the real state machine. State transitions are test-injectable. AC-4 then proves the correct invariant (guard fires when state != IN_BATTLE) which matches the real implementation.

3. **Option C**: Delete MockScenarioRunner when real ScenarioRunner lands and rewrite Story 007's integration tests against the real implementation. Purest but highest cost.

**Recommended**: Option B when the Scenario Progression epic's ScenarioRunner story is authored. Add this to that story's Dependencies / Migration Notes section so the equivalent state machine is tested.

**Next review**: when Scenario Progression epic's ScenarioRunner implementation story enters `/story-readiness`. At that point, either upgrade MockScenarioRunner (Option B) or delete it in favor of real-implementation tests (Option C).
