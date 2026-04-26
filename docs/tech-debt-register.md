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

**Update 2026-04-25 (terrain-effect story-001)**: G-14 codified — new `class_name` declarations need a class-cache refresh (`godot --headless --import --path .`) before tests can resolve the identifier. Renumbered to G-14 to honor the pre-reserved G-13 slot for "User-defined methods can shadow inherited Node API" (still pending codification — see TD-032 batch G-13 candidate at line 1374).

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

---

## TD-016 — scene_manager_test.gd uses sm.set() where direct assignment would be more idiomatic

**Origin**: story-003 /code-review F-2 (nit)
**Category**: code
**Severity**: low
**Status**: open

Five test functions in `tests/unit/core/scene_manager_test.gd` (lines ~358, 397, 439, 472, 528) use `sm.set("_overworld_ref", fake_overworld)` to inject the fake Overworld reference. Since `_overworld_ref` is a plain typed var with no custom setter, direct assignment `sm._overworld_ref = fake_overworld` would be more idiomatic, statically type-checked, and clearer in intent.

Noted during story-003 review as a nit — no functional issue (all tests pass, 79/79). The `.set()` form bypasses static type checking, which is actually useful in `test_scene_manager_pause_restore_overworld_freed_ref_is_noop` (AC-6) where a bare `Node.new()` is assigned to a `CanvasItem`-typed field to exercise the freed-ref guard. That specific test needs `.set()`; the other 4 tests do not.

**Remediation**: swap 4 call sites to direct assignment (leave AC-6 test as-is with `.set()`). ~4 one-line edits. Cleanup candidate for a future "test polish" sweep.

**Next review**: next time `scene_manager_test.gd` gets touched for new ACs.

---

## TD-017 — Overworld `UIRoot` non-Control silent-skip path has no test

**Origin**: story-003 /code-review T-1 (qa-tester advisory)
**Category**: code
**Severity**: low
**Status**: open

`_pause_overworld` / `_restore_overworld` in `src/core/scene_manager.gd` perform `_overworld_ref.get_node_or_null("UIRoot") as Control`. If an Overworld scene has a node named "UIRoot" that is NOT a Control (e.g., a plain Node), the `as Control` cast returns null, and the mouse_filter line is silently skipped.

This is the designed runtime behavior — the implementation correctly no-ops rather than crashing — but the silent-skip path has no test coverage. A test asserting no-crash with a bare Node named "UIRoot" would document the intended contract explicitly.

Impact: if a future Overworld scene accidentally has a non-Control "UIRoot" node, pause-time mouse_filter suppression will silently not fire, with no log or warning. This could cause subtle touch-event bleed-through in IN_BATTLE state on mobile. Story-007 target-device verification would likely catch it, but earlier detection via a unit test is cheaper.

**Remediation**: add a 7th test function to `scene_manager_test.gd`:
```
func test_scene_manager_pause_overworld_ui_root_not_control_is_safe()
```
Arrange fake Overworld with Node (not Control) named "UIRoot" → `_pause_overworld()` → assert no crash + 4 primary properties still toggle. ~20 lines. Consider adding a `push_warning` in `_pause_overworld` when UIRoot exists but fails the Control cast, to surface the misconfiguration.

**Next review**: before story-007 target-device verification, or when any future Overworld scene ships with a UIRoot child.

---

## TD-018 — story-004 test polish items (batched)

**Origin**: story-004 /code-review (6 advisory findings batched)
**Category**: code
**Severity**: low
**Status**: open

Six minor advisory/nit findings surfaced during story-004 code review. None block function (87/87 tests pass, 0 orphans). Batched here as a single cleanup sweep:

**F-1** — Integration test AC-1 (`scene_handoff_timing_test.gd:173-176`): redundant `is_inside_tree()` guard before `remove_child`. `_instantiate_and_enter_battle` always adds to root, so `is_instance_valid(battle_ref)` alone is sufficient. Cleanup noise.

**F-2** — `scene_manager.gd` `_on_load_tick` line 134: `var progress: Array = []` is untyped. Could be `Array[float]` for tighter typing. Engine API accepts untyped; cosmetic tightening.

**F-3** — `scene_manager.gd` `_transition_to_error`: does not call `_load_timer.stop()` defensively. Not a bug in story-004 (both `_on_load_tick` callers stop before calling; `_on_battle_launch_requested` calls before `timer.start()`). Risk: when story-006 extends the helper to be called from additional in-flight paths, a missing `stop()` could leave the timer running. Revisit at story-006 close-out.

**F-4** — AC-7 unit test (`scene_manager_test.gd:740`) inlines the fixture path `res://scenes/battle/test_ac4_map.tscn` instead of reusing the integration file's `FIXTURE_SCENE_PATH` constant. Consider hoisting to a shared constant or `tests/unit/core/test_fixtures.gd` module.

**T-1** — `_overworld_ref` null-cast path (`scene_manager.gd:112` via `as CanvasItem`) not unit-tested. If `current_scene` is a plain Node (e.g., CI headless setups), cast yields null and `_pause_overworld` no-ops via `is_instance_valid`. Guard is correct; a test would prevent silent regression if the guard is ever refactored.

**T-2** — `_instantiate_and_enter_battle` null-packed guard (line after `load_threaded_get`) not directly tested. Engine-internal race condition between LOADED status and get returning null is low-risk in practice; advisory only.

**T-3** — `_on_load_tick` early-exit branch (state != LOADING_BATTLE → `_load_timer.stop() + return`) not directly unit-tested. Implicitly covered by AC-2/AC-7 (state forced, emit processed). A direct test would pin the timer-stop sub-contract.

**Remediation**: single cleanup PR during a quiet cycle. Estimated ~30-45 min for all six. F-3 should be addressed at story-006 close regardless (dependent on how story-006 extends the helper).

**Next review**: at story-006 close (F-3 definitely; others opportunistically). If any finding surfaces again in subsequent stories, elevate severity.

---

## TD-019 — G-10 (autoload identifier binding) empirically discovered

**Origin**: story-004 round 3 (3 failing tests traced to misunderstanding of GDScript autoload identifier resolution)
**Category**: process
**Severity**: medium
**Status**: resolved (documented in `.claude/rules/godot-4x-gotchas.md` as G-10)

During story-004 unit/integration test development, 3 tests consistently failed with the symptom "handler never fires; state stays at initial value." The team initially diagnosed this as a `CONNECT_DEFERRED` timing issue and added extra `await get_tree().process_frame` calls with no effect. Root cause: the `GameBus` autoload identifier in GDScript binds at engine registration to the ORIGINALLY-REGISTERED node — it does NOT dynamically resolve to `/root/GameBus`. Tests using `GameBusStub.swap_in()` together with `SceneManagerStub.swap_in()` had the stub SM subscribing to the DETACHED PRODUCTION GameBus during _ready(), not to the stub. Emits on the stub never fired the SM handler.

**Additional finding**: AC-2 guard test was a **false positive** for the same reason. Forcing state to LOADING_BATTLE and asserting state stays at LOADING_BATTLE after emit passes whether the handler was guard-rejected OR never fired at all.

**Remediation applied (story-004)**:
- G-10 entry added to `.claude/rules/godot-4x-gotchas.md`
- All 5 handler-firing tests in story-004 refactored to drop GameBusStub and emit on real GameBus autoload
- AC-2 test hardened: force state to IN_BATTLE (unambiguous guard trigger), observe `ui_input_block_requested` NOT firing via Callable + CONNECT_ONE_SHOT (secondary side effect proving handler ran and was rejected, not "handler never fired")
- Test file headers updated with `AUTOLOAD BINDING — CRITICAL` cross-reference

**Scope creep risk**: similar patterns exist in gamebus story-005/006/007 tests that use GameBusStub. Need to audit whether any of them rely on "fresh subscriber receives stub emits" (which would be broken per G-10). If so, add to tech debt follow-up.

**Follow-up**: pre-emptive audit pass during story-005 (next cycle) — scan all tests that use GameBusStub for subscriber-receives-emit patterns. Flag any false-positive risks.

**Next review**: during story-005 implementation; before each future story using GameBusStub.

---

## TD-020 — story-005 advisory test coverage items

**Origin**: story-005 /code-review (3 advisory items from qa-tester edge-case analysis)
**Category**: code
**Severity**: low
**Status**: open

Three advisory coverage items surfaced during story-005 code review. Implementation is sound (94/94 tests pass first-run) — these are defensive additions that protect against future changes.

**T-1** — `_free_battle_scene_and_restore_overworld` called with `_battle_scene_ref == null` (double-invocation) has no direct test. The `is_instance_valid` guard handles it correctly by design, but no regression test pins the contract. **Relevance to story-006**: error-recovery retry paths may re-enter the teardown path; if retry handling accidentally triggers double-invocation, the silent guard behavior could mask a bug. Consider adding a test during story-006 implementation.

**T-2** — `_restore_overworld()` called from within `_free_battle_scene_and_restore_overworld` when `_overworld_ref` has been freed between teardown initiation and `call_deferred` execution. Story-003 tests cover the null/freed `_overworld_ref` guard on `_restore_overworld()` in isolation, but the integration path through teardown is untested with a freed overworld. Low priority — behavior is implicitly correct via delegation. Flag at story-007 target-device verification pass.

**T-3 (nit)** — AC-5 state guard test uses a single function looping through 4 non-IN_BATTLE states. Failure locality is acceptable (message carries the failing state value), but splitting into 4 functions would give cleaner per-state failure isolation. Optional cleanup in a future test polish sweep.

**Remediation**: opportunistic — address during story-006 (T-1 most relevant there) or story-007 (T-2 natural fit). T-3 can be deferred indefinitely; not worth a dedicated PR.

**Next review**: at story-006 close (T-1 check) + story-007 close (T-2 check).

---

## TD-021 — story-006 advisory items (nits + edge cases) + G-11 discovery

**Origin**: story-006 /code-review (engine specialist nits + qa-tester advisory coverage)
**Category**: code + process
**Severity**: low
**Status**: partially resolved (G-11 codified; F-3/F-4/T-1/edge cases deferred)

**Resolved this cycle**:
- **G-11 codified** in `.claude/rules/godot-4x-gotchas.md` — `as Node` cast on freed Object crashes even when declared `Variant`. Discovered when AC-5 retry test crashed with "Trying to cast a freed object" at `_cleanup_battle_ref` helper. Fix: `is_instance_valid()` MUST precede any `as T` cast regardless of parameter declared type.
- **F-1 resolved** — AC-4 cleanup now uses `_cleanup_battle_ref(sm.get("_battle_scene_ref"))` for pattern consistency with AC-5/AC-7 (previously did the direct `as Node` cast that motivated the helper).
- **F-2 resolved** — AC-5 and AC-7 now have unconditional post-retry `assert_int(sm.state)...is_equal(IN_BATTLE)` after the `if sm.state == LOADING_BATTLE: poll` block, guarding against silent-pass on fast fixture loads where state may have already advanced past LOADING_BATTLE before the guard ran.

**Deferred to future cycles**:

**F-3** — `tests/integration/core/mock_scenario_runner.gd:1` header comment says "Story 007" only. Story-006 extended the class (added retry surface). Add Story-006 to class-level summary for discoverability. Nit-level; address opportunistically.

**F-4** — `src/core/scene_manager.gd` inline comment `# DRY — story-003` at the `_restore_overworld()` call inside `_transition_to_error` is misleading: `_restore_overworld` was defined in story-003 but THIS call is story-006's addition. A `git blame` reader might follow the line ref to the wrong story. Suggest: `# DRY — _restore_overworld defined story-003; 4 props + UIRoot mouse_filter`. Nit-level.

**T-1** — AC-6 partial coverage: combined test exercises ERROR state rejection path, not a genuine WIN outcome teardown with `scene_transition_failed` non-emission monitor. Story-005's `test_scene_manager_outcome_teardown_restores_overworld_properties` is the natural home for this 8-line addition. Covers AC-6 WIN path completely. Address at story-005 polish pass or as part of TD-018 batch.

**T-edge-1** — `_transition_to_error` called with `_overworld_ref == null` (e.g., error fires during very first launch before Overworld was captured). `_restore_overworld` guards this via `is_instance_valid`, but no test exercises the path. Address at story-007 with target-device edge-case verification.

**T-edge-2** — `_transition_to_error` called twice in succession (re-entry while already in ERROR). Both signal emits would fire twice. ERROR is spec'd as exit-only via `battle_launch_requested`, but no test verifies non-double-emit. Address at story-007 or whenever a retry flow could trigger re-entry.

**Remediation order**: F-3/F-4 can be batched with any other test polish PR. T-1 belongs in story-005 cleanup. T-edge-1/T-edge-2 fit story-007's target-device verification scope.

**Next review**: at story-007 close.

---

## TD-022 — Godot 4.6 silent class_name collision resolution (G-12 candidate)

**Origin**: save-manager story-001 /code-review + round-2 path correction
**Category**: docs (gotcha rule file candidate)
**Severity**: low (one occurrence; ~15min diagnosis cost)
**Status**: open — tracking pending recurrence

When two `.gd` files declare the same `class_name X`, Godot 4.6 resolves the collision SILENTLY via first-registered-wins. No parse error, no warning. Only detected via combined `resource_path` + field-content assertions (i.e., assertion on where the class_name globally resolved AND on what fields that class actually has).

### Concrete pattern observed (save-manager story-001)

- Gamebus story-002 shipped PROVISIONAL stubs at `src/core/payloads/save_context.gd` + `src/core/payloads/echo_mark.gd`, each declaring `class_name SaveContext` / `class_name EchoMark`
- Save-manager story-001 specialist wrote NEW files at `src/core/save_context.gd` + `src/core/echo_mark.gd` with the full schema, also declaring `class_name SaveContext` / `class_name EchoMark`
- `godot --headless --import` returned exit 0 (NO collision error)
- Tests checking field defaults (AC-2) + field counts (AC-3/AC-5) passed — because class_name resolved to the FULL-schema file at `src/core/`
- But tests checking `resource_path` (AC-4) FAILED only after the B-1 code-review fix exposed the mismatch: AC-4 asserted `res://src/core/echo_mark.gd` but resolution picked `res://src/core/payloads/echo_mark.gd` (the stub)

### Why first-registered-wins is dangerous

- Newer code with full schema can be SILENTLY OVERRIDDEN by an older stub at a different path
- Test coverage that only checks fields can give false-positive PASS while actual production code uses the stub
- Developer has zero diagnostic signal — no warning, no parse error, no compile-time failure

### Mitigations applied for save-manager story-001

1. Stubs overwritten in-place at the canonical path (`src/core/payloads/*.gd`)
2. Duplicate files at `src/core/*.gd` deleted
3. Test resource_path assertions updated

### Promotion criteria (to G-12 in `.claude/rules/godot-4x-gotchas.md`)

- Codify when this pattern recurs (threshold: 2 occurrences)
- OR codify preemptively if any new contributor hits this same failure mode

### Interim defensive practice

When creating a new class with `class_name`:
1. `Grep` for existing `class_name [NewName]` before writing: `grep -r "class_name [Name]" src/`
2. If found, decide: replace-in-place OR rename-new-class
3. Never create a second file with the same `class_name` at a different path

### Remediation path

1. Observe 1+ recurrence
2. Codify as G-12 in godot-4x-gotchas.md with Context → Broken → Correct → Discovered format
3. Cross-reference from TD-022 → resolved

**Next review**: at save-manager epic close, or on next class_name-related bug.

---

## TD-023 — ADR-0003 §Key Interfaces code listing incorrectly shows `class_name SaveManager`

**Origin**: save-manager story-002 implementation (godot-gdscript-specialist flagged)
**Category**: docs (ADR errata)
**Severity**: low (caught at implementation time; implementation is correct)
**Status**: open — ADR errata pending

ADR-0003 §Key Interfaces at approximately line 242 of `docs/architecture/ADR-0003-save-load.md` contains a code listing that declares:

```gdscript
class_name SaveManager
extends Node
```

This contradicts G-3 (Godot 4.6 autoload `class_name` collision rule — declaring `class_name X` on a script registered as autoload `X` causes the parse error "Class 'X' hides an autoload singleton"). The SaveManager script registered at `/root/SaveManager` MUST NOT declare `class_name SaveManager`.

### Why this happened

The ADR was authored before G-3 was codified in `.claude/rules/godot-4x-gotchas.md` (G-3 was discovered in gamebus story-005). The code listing was likely copied from a non-autoload Resource example.

### Implementation correctness

Story-002 §Implementation Notes §1 explicitly identifies this discrepancy and mandates the correct form. `src/core/save_manager.gd` uses `extends Node` with no `class_name` — correct.

### Resolution path

1. Edit `docs/architecture/ADR-0003-save-load.md` §Key Interfaces — remove `class_name SaveManager` from the SaveManager code listing
2. Add a one-line comment near the listing: `# NOTE: autoload scripts must NOT declare class_name (G-3 — see .claude/rules/godot-4x-gotchas.md)`
3. Add changelog entry: `2026-MM-DD: Errata — removed erroneous class_name SaveManager from §Key Interfaces code listing (G-3 compliance).`

### Scope of errata pass

Worth checking ADR-0003 other code listings (SaveContext, EchoMark, SaveMigrationRegistry) for similar drift. SaveContext and EchoMark SHOULD declare `class_name` (they are Resource subtypes, not autoloads). SaveMigrationRegistry extends RefCounted — also correctly declares `class_name`. Only SaveManager section needs correction.

**Next review**: at save-manager epic close (batch ADR errata pass across all Foundation ADRs if similar drift found in ADR-0001/0002/0004).

---

## TD-025 — G-14: Godot `user://` path APIs have asymmetric double-slash tolerance

- **Discovered**: 2026-04-23, save-manager story-004 /dev-story (7 failing tests, root cause: `//` in temp paths)
- **Origin**: save-manager story-004
- **Category**: code + docs (gotcha rule file candidate)
- **Severity**: low (latent until first ResourceSaver.save call in story-004; DirAccess APIs silently tolerated the bad paths in stories 001-003)
- **Status**: resolved in-situ (story-004 `_path_for` + `_ensure_save_root` both apply `.rstrip("/")`)

**Root cause**: `SaveManagerStub.swap_in()` sets `_save_root_override` WITH a guaranteed trailing slash (enforced by stub line 141-143 for path-concatenation safety). `_path_for` appended `/slot_N/...` directly, producing `user://test_saves/ID//slot_1/ch_01_cp_1.res` — double-slash between the temp root and `slot_X`.

**Asymmetric API behavior**:
- `DirAccess.make_dir_recursive_absolute("path//to//dir")` — tolerates `//` silently (creates dir correctly)
- `DirAccess.dir_exists_absolute("path//to//dir")` — tolerates `//` silently (returns correct result)
- `ResourceSaver.save(resource, "path//to//file.res")` — **REJECTS with `ERR_FILE_CANT_WRITE` (15)**
- `ResourceLoader.load("path//to//file.res")` — **load failure**

This asymmetry was latent through stories 001-003 (only used DirAccess APIs). Story-004 was the first to call `ResourceSaver.save`, exposing the bug. The failure symptom was all save-pipeline tests returning `"resource_saver_error:15"` regardless of what error path they were testing.

**Fix applied**: `.rstrip("/")` at the start of both `_path_for` and `_ensure_save_root`. Constructor normalizes; caller discipline not required.

**G-14 candidate**: "Godot `user://` path APIs have asymmetric double-slash tolerance. `DirAccess` static helpers (`make_dir_recursive_absolute`, `dir_exists_absolute`, `remove_absolute`) silently tolerate `//`; `ResourceSaver.save` and `ResourceLoader.load` reject double-slash paths with `ERR_FILE_CANT_WRITE (15)` / load error. Always `.rstrip("/")` user-supplied roots in path constructors — do not assume caller-side discipline."

**Resolution path**: codify as G-14 in `.claude/rules/godot-4x-gotchas.md` when the rule file is next updated (batch with G-13 from TD-024).

**Next review**: at save-manager epic close (batch G-13 + G-14 rule-file update).

---

## TD-024 — ADR-0003 errata: `DUPLICATE_DEEP_ALL_BUT_SCRIPTS` does not exist

- **Discovered**: 2026-04-23, save-manager story-004 /dev-story
- **Origin**: save-manager story-004
- **Category**: docs (ADR errata)
- **Severity**: low (text-only — implementation corrected in-situ)
- **Status**: open — ADR errata pending

**Affected docs**:
- `docs/architecture/ADR-0003-save-load.md` §Key Interfaces (code listing line ~269)
- `docs/architecture/ADR-0003-save-load.md` §Engine Compatibility §Post-Cutoff APIs Used
- `docs/architecture/control-manifest.md` SaveManager Required Patterns
- `docs/architecture/tr-registry.yaml` TR-save-load-003 requirement text
- `production/epics/save-manager/story-004-save-pipeline.md` AC-1 step 1 and Engine Notes

**Root cause**: The `DUPLICATE_DEEP_ALL_BUT_SCRIPTS` name was LLM-fabricated during ADR-0003 authoring (2026-04-18). The value does not appear in Godot 4.6's real `Resource.DeepDuplicateMode` enum. Confirmed via `ClassDB.class_get_enum_list("Resource")` introspection — the real enum has exactly three values:

```
DEEP_DUPLICATE_NONE     = 0
DEEP_DUPLICATE_INTERNAL = 1
DEEP_DUPLICATE_ALL      = 2
```

**Implementation**: story-004 uses `Resource.DEEP_DUPLICATE_ALL` (max-depth mode) with inline ADR-errata comment. Semantic intent is preserved — `DEEP_DUPLICATE_ALL` fully duplicates all embedded sub-resources (EchoMark instances in `echo_marks_archive`), satisfying the R-1 mitigation (live-state decoupling before serialization).

**New gotcha (G-13 candidate)**: "Resource deep-duplication enum values were renamed/restructured in Godot 4.5+. LLM training data and pre-4.5 documentation frequently reference `DUPLICATE_DEEP_ALL_BUT_SCRIPTS` — this name is fabricated and was never a real API. The correct enum is `Resource.DeepDuplicateMode` with values `DEEP_DUPLICATE_NONE | DEEP_DUPLICATE_INTERNAL | DEEP_DUPLICATE_ALL`. Use `ClassDB.class_get_enum_list("Resource")` to enumerate real values at runtime." Add as G-13 when `.claude/rules/godot-4x-gotchas.md` is next updated.

**Resolution path**: Batch with TD-023 (ADR-0003 `class_name SaveManager` errata) into a single ADR-0003 errata pass. Target: after save-manager epic closes, before story-006 (migration registry) begins.

**Next review**: at save-manager epic close.

---

## TD-026 — ADR-0003 errata: tmp-path extension pattern is unimplementable

- **Discovered**: 2026-04-23, save-manager story-004 /dev-story
- **Origin**: save-manager story-004
- **Category**: docs (ADR errata)
- **Severity**: low (text-only — implementation corrected in-situ)
- **Status**: open — ADR errata pending

**Affected docs**:
- `docs/architecture/ADR-0003-save-load.md` §Key Interfaces (`var tmp_path: String = final_path + ".tmp"`)
- `docs/architecture/ADR-0003-save-load.md` §Requirements item 3 ("Atomic write" — specifies `.res.tmp` tmp suffix)
- `docs/architecture/control-manifest.md` SaveManager Required Patterns (references tmp_path form)
- `production/epics/save-manager/story-004-save-pipeline.md` AC-1 step 5 verbatim

**Root cause**: ADR-0003 author assumed Godot's ResourceSaver tolerates arbitrary path extensions for tmp files. Empirical test (Godot 4.6): ResourceSaver picks serializer from the path's TRAILING extension; `.res.tmp` yields err=15 (`ERR_FILE_CANT_WRITE`) because `.tmp` isn't a registered format. `.tmp.res` works (trailing `.res` → binary saver).

Confirmed by minimal probe script:
```
.res         → err=0  (OK)
.res.tmp     → err=15 (ERR_FILE_CANT_WRITE)
.tmp.res     → err=0  (OK)
.tmp         → err=15 (ERR_FILE_CANT_WRITE)
```

**Implementation**: story-004 uses `final_path.get_basename() + ".tmp.res"` with inline ADR-errata comment. For `final_path = ".../slot_1/ch_02_cp_1.res"` this yields `".../slot_1/ch_02_cp_1.tmp.res"` — still unambiguously the tmp counterpart, still cleaned up atomically by rename, still guaranteed to collide uniquely with its final-path pair per `(slot, chapter, cp)`.

**G-15 candidate**: "Godot ResourceSaver picks serializer from the TRAILING path extension. `.res.tmp` fails with err=15 (`ERR_FILE_CANT_WRITE`); `.tmp.res` succeeds. When writing atomic-save tmp files, place disambiguation infixes BEFORE the recognised extension: use `<basename>.tmp.res` NOT `<full>.tmp`. Verify with: `ResourceSaver.save(Resource.new(), \"user://test.res.tmp\")` returns err 15."

**Resolution path**: Batch with TD-023 (`class_name SaveManager`) + TD-024 (`DUPLICATE_DEEP_ALL_BUT_SCRIPTS`) + TD-025 (double-slash path normalization) into a single ADR-0003 errata pass. Target: after save-manager epic closes, before story-006 (migration registry) begins. Four errata in one story is a strong signal the ADR needs an engine-specialist re-validation pass.

**Next review**: at save-manager epic close (batch ADR-0003 errata pass).

---

## TD-027 — Story-004 /code-review deferred advisories (batch)

**Origin**: save-manager story-004 /code-review (godot-gdscript-specialist + qa-tester, 2026-04-23)
**Category**: code + docs
**Severity**: low
**Status**: open

Six advisory items surfaced during /code-review of save-manager story-004. None were BLOCKING; story passed both specialist reviews. Deferred via Option A (lean close-out) per user decision; logged here to prevent loss.

### Items

1. **AC-NO-MUTATE field coverage gap (qa-tester ADVISORY #1)** — `test_save_manager_source_not_mutated_during_save` checks only `ctx.schema_version` post-save. Story spec says "post-save field equality check on caller's instance" — adding a `ctx.saved_at_unix == 0` assertion (source sentinel unchanged) closes the gap. 2-line addition. Target: fold into story-006 test sweep, OR address with factory helper below in a dedicated test-hardening pass.

2. **V-4 cleanup branch is a dead branch under Option C seam (qa-tester ADVISORY #2 + specialist ADVISORY)** — the `DirAccess.remove_absolute(tmp_path)` call inside each error-path branch is never executed under the current test seam (seam bypasses real write → tmp never exists). Acceptable per documented "compensating sweep deferred to story-006" policy. Story-006 scope should explicitly call out that the compensating sweep test will land coverage of this branch.

3. **No `_make_filled_save_context()` factory helper (qa-tester ADVISORY #3)** — 6 test bodies independently construct `SaveContext` fixtures. A factory helper would reduce maintenance surface when `SaveContext` schema changes in future stories. Current duplication is manageable; refactor when the test file exceeds ~10 fixture constructions or when SaveContext gains fields.

4. **`_cleanup_tmp` DRY helper (specialist ADVISORY #1)** — 3× ~5-line cleanup blocks in `save_checkpoint` (V-4 policy). Parameterized helper (`step_name: String`, `step_err: Error`) would reduce ~15 lines while preserving per-branch diagnostic specificity. Recommend folding into story-006 when that story touches this file for compensating sweep.

5. **Inline (G-14)/(G-15) citations forward-reference unpublished rule-file entries (specialist ADVISORY #5)** — `save_manager.gd` comments cite `(G-14)` and `(G-15)` but `.claude/rules/godot-4x-gotchas.md` only defines G-1..G-11. Current TD-022 (class_name collision) is provisionally G-12; TD-024/025/026 would be G-13/14/15 in the rule file. Either (a) add G-12..G-15 batch entries to the rule file now, or (b) update inline comments to reference TD IDs only until rule file is published. Resolution: batch with the epic-close rule-file update pass.

6. **`save_checkpoint(null)` crashes (qa-tester ADVISORY #4)** — defensive hardening for ScenarioRunner integration. Not in story-004 ACs, but the public API contract should guard against null input. Recommended guard: `if source == null: GameBus.save_load_failed.emit("save", "null_source"); return false`. Target: address in story-006 (migration registry) when that story adds its own input validation on the public API.

### Resolution path

Items 1, 3, 6 → natural fit for story-006 (migration registry) test sweep since that story will also extend `save_manager.gd` tests.
Items 2, 4 → batch with story-006's `save_checkpoint` modifications (`_cleanup_tmp` helper + compensating sweep coverage).
Item 5 → batch with save-manager epic close-out: single rule-file update pass that codifies G-12 through G-15 and refreshes ADR-0003 / control-manifest text (alongside TD-023 / TD-024 / TD-025 / TD-026 errata).

**Next review**: at start of save-manager story-006 (migration registry) implementation.

---

## TD-028 — Story-005 /code-review deferred advisories (batch)

**Origin**: save-manager story-005 /code-review (godot-gdscript-specialist + qa-tester, 2026-04-24)
**Category**: code + docs
**Severity**: low
**Status**: open

Six advisory items surfaced during /code-review of save-manager story-005. None BLOCKING; story passed both reviews (APPROVED + ADEQUATE). Deferred via Option A (lean close-out). Two adjacent advisories (#4 + #5, list_slots UI contract + signal asymmetry) were applied in-cycle as inline doc-comments.

### Items deferred

1. **AC-V8 `saved_at_unix` assertion gap (qa ADVISORY)** — `test_save_manager_list_slots_slot_isolation` verifies `chapter_number` + `last_cp` but not `saved_at_unix` presence in the non-empty dict. 2-line addition closes the dict-shape contract verification. Fold into story-006 migration test sweep when story-006 extends save_manager_test.gd.

2. **`not raw is SaveContext` branch untested (qa ADVISORY)** — corrupt-file test covers `raw == null`; the non-null-wrong-type branch (e.g., `Resource.new()` saved as `ch_01_cp_1.res`) has no test. Low production probability but branch is reachable. Add in story-006 when migration introduces more type-discrimination tests.

3. **`set_active_slot` cross-slot load isolation untested (qa ADVISORY)** — scenario: save to slot 1 → `set_active_slot(2)` → `load_latest_checkpoint()` should return null (slot 2 empty). Not independently confirmed. Fold into story-006 test sweep.

4. **TD-027 factory helper advisory now more pressing (qa ADVISORY)** — 6 story-005 test bodies construct `SaveContext` fixtures inline (on top of story-004's 6 sites). Total fixture duplication: 12 sites. `_make_filled_save_context()` with baseline values + override params would meaningfully reduce maintenance surface. Elevate TD-027 priority. Target: story-006 refactor pass (migration will add more fixture sites).

5. **G-16 gotcha candidate (specialist NEW)** — `DirAccess.get_files_at(path)` returns empty `PackedStringArray` (not null/error) when the directory does not exist. Asymmetric with `DirAccess.open(path)` which returns null on missing directory. Safe in `_find_latest_cp_file` (empty files array → empty best_path → empty-slot contract preserved), but subtle enough that a future consumer of `get_files_at` may wrongly expect null-error signal. Batch with G-12..G-15 rule-file update.

6. **Negative-chapter filename silent ignore (both reviewers, low-pri robustness)** — `ch_-1_cp_1.res` passes all current guards (`is_valid_int("-1")` is true) but produces negative key → never selected as newest. No crash. Option: reject negatives explicitly via `int(parts[1]) >= 0 and int(parts[3]) >= 0` guard. Nice-to-have; no test currently documents expected outcome.

### Items applied in-cycle (not deferred)

- **#4 + #5 (list_slots UI contract + signal asymmetry)** — applied as inline doc-comment additions to `list_slots` in `src/core/save_manager.gd` lines 222-241. No code behavior change. Full unit suite re-verified 134/134 PASS.

### Resolution path

Items 1, 2, 3, 4 → natural fit for story-006 (migration registry) test sweep since that story will extend `save_manager_test.gd` and add migration-specific fixtures.
Item 5 → batch with G-12..G-15 rule-file update at save-manager epic close.
Item 6 → nice-to-have; revisit if any story-006/007 scenario introduces a path where negative chapter numbers could come from an external source (e.g., imported saves).

**Next review**: at start of save-manager story-006 (migration registry) implementation.

---

## TD-029 — Story-006 /code-review advisories (A-5 deferred to story-008)

**Origin**: save-manager story-006 /code-review (godot-gdscript-specialist + qa-tester, 2026-04-24)
**Category**: code + CI lint
**Severity**: low
**Status**: open (deferred to story-008)

Five advisory items surfaced during /code-review of save-manager story-006. None BLOCKING; both reviewers verdict APPROVED/ADEQUATE. Four were applied in-cycle (Option B hardening pass); one deferred.

### Applied in-cycle (not deferred)

- **A-1 (BOTH reviewers)**: `_migrate_inner` infinite-loop guard — `_MAX_MIGRATION_STEPS = 1000` class const + iteration counter + push_error + `save_load_failed.emit("load", "migration_loop_exceeded_at_v%d")` on breach. Prevents hung test runner from a Callable that forgets to increment `ctx.schema_version`.
- **A-2 (qa ADVISORY #1)**: `_migrate_inner` null-return guard — if a migration Callable returns null (bug), `push_error` + `save_load_failed.emit("load", "migration_returned_null_from_v%d")` + return null. Load pipeline treats null identically to the invalid_resource branch. Avoids null-deref on next iteration's `ctx.schema_version`.
- **A-3 (specialist A-2)**: TD-028 #2 signal disconnect belt-and-suspenders — `if GameBus.save_load_failed.is_connected(cb_fail):` guard before disconnect. Matches AC-GAP style in save_migration_registry_test.gd.
- **A-4 (qa ADVISORY #2)**: AC-INTEGRATION-STORY-005 — replaced `if loaded != null:` silent-skip guard with early-return after null check. Cleaner failure semantics when load_latest_checkpoint returns null (GdUnit4 `is_not_null` soft-assert is reported, then test exits cleanly instead of continuing to null-deref).

Re-run: 143/143 PASS, 0 orphans, exit 0. No regressions.

### Deferred

- **A-5 (qa ADVISORY #3)**: static lint for migration Callable patterns — detect "migration Callable that does not assign `ctx.schema_version`" AND "migration Callable that skips a version step" (fn1→v3 directly, bypassing v2). Code-review gate is currently the only guard. Scope evaluation belongs to story-008 (CI lint — covers per-frame-emit lint and user://-only lint; migration Callable patterns fit the same scope). Low production risk (empty MVP registry) but worth evaluating when CI lint infrastructure is being built.

### Resolution path

Story-008 CI lint scope will evaluate whether static analysis can catch migration-callable anti-patterns. If feasible, add to the lint battery alongside the per-frame-emit and user://-only linters. If not feasible, document as a code-review checklist entry in the control manifest.

**Next review**: at start of save-manager story-008 (CI lint) implementation.

---

## TD-030 — CI lint-script template hardening (from story-008 /code-review)

**Origin**: save-manager story-008 /code-review (2026-04-24)
**Category**: CI infrastructure polish
**Severity**: low (both items are cosmetic / defensive — neither affects production lint behavior)
**Status**: open (batched refactor candidate)

Three advisory items surfaced during /code-review; story-008 verdict was APPROVED WITH SUGGESTIONS, Option A selected (lean close; batch these as TD-030).

### Items

- **A-1** — `tools/ci/lint_save_paths.sh` docstring on line 28-29 claims the comment-stripping regex `(^|\s)#.*$` "keeps '#' inside string literals untouched". This is imprecise — the regex strips any `#` preceded by whitespace, including a `#` inside a string like `"foo #bar"`. Real-world impact: negligible (save code contains no such strings today). Fix: either (a) tighten the doc comment to describe the actual behavior, OR (b) replace the regex with a state-machine parser that tracks string-literal context. Recommend (a) now; (b) if an actual false-negative ever surfaces.

- **A-2** — `tools/ci/lint_per_frame_emit.sh` legacy template uses `if ! ruby_stdout=$(...); then ruby_exit=$?; fi`. The `$?` after `if !` captures the negated test result (always 0), not Ruby's actual exit code. The crash-triage branch (`if [ "$ruby_exit" -gt 1 ]`) is effectively dead code. Production unaffected because violation detection uses the stdout-non-empty check (`[ -n "$violations" ]`). Fix: replace with direct capture `ruby_stdout=$(...); ruby_exit=$?` (the pattern used in the new story-008 scripts). One-line mechanical change.

- **A-3** — batch A-1 + A-2 into a single refactor commit touching both `lint_per_frame_emit.sh` (fix bug) and `lint_save_paths.sh` (tighten doc). Scope: ~5 lines edited across 2 files.

### Estimated effort

15-30 minutes (including smoke re-verification).

### Resolution trigger

Any future CI lint work OR a dedicated "CI infra polish" sprint.

---

## TD-031 — Story-007 AC-TARGET + perf-test polish (Polish-phase scope)

**Origin**: save-manager story-007 /code-review (godot-gdscript-specialist + qa-tester, 2026-04-24)
**Category**: perf test polish + Polish-phase AC-TARGET preparation
**Severity**: low (all items are polish, AC-TARGET fidelity, or advisory-tuning)
**Status**: open (bundled with AC-TARGET Polish-phase implementation)

Seven advisory items surfaced during /code-review of save-manager story-007. None BLOCKING; both reviewers verdict APPROVED WITH SUGGESTIONS / ADEQUATE. Story-007 was closed with Option A (lean close; 4 of 5 ACs + AC-TARGET explicitly deferred per story §7). These items naturally bundle with the AC-TARGET Polish-phase work.

### Items

- **S-1** — `save_perf_test.gd` AC-BREAKDOWN rename call form divergence. Test uses `DirAccess.rename_absolute(tmp, final)` static; production `save_manager.gd:172` uses `_do_rename_absolute(da, tmp, final)` → instance `da.rename_absolute(tmp, final)`. On desktop SSD the difference is immeasurable; on Android eMMC flash the static form pays extra `open()` per call. **Fix for AC-TARGET Polish-phase**: open DirAccess once outside the measurement loop, call instance method. ~3-line change.

- **S-2** — AC-BREAKDOWN save advisory threshold fires at `save_p95 > 15000` μs; ADR-0003 §Performance Implications states expected upper bound is 10ms. Tighten to `> 10_000` to match ADR wording exactly. ~1 line.

- **S-3** — AC-BREAKDOWN per-iteration chapter/cp variation comment imprecise: says "tmp-file collision" as rationale; actual reason is filesystem write-coalescing / page-cache shortcutting that would skew times downward without the variation. Clarify comment. ~2 lines.

- **S-4** — `_max()` helper missing empty-array guard (lines 118-123 of save_perf_test.gd). Inconsistent with `_p95()` and `_mean()` which guard the empty case. Harmless at current call sites (always passed 100-element array). ~2 lines.

- **S-5** — AC-PAYLOAD-SIZE: representative ctx builder produces 2.19 KB vs ADR's projected 5-15 KB range. The `push_warning()` advisory fires correctly (every CI run until resolved). Two remediation paths:
  - (a) Update `_build_representative_ctx()` to hit ≥5 KB (longer StringName tags, more EchoMarks, longer flag strings)
  - (b) Accept as accurate MVP observation and update ADR §Performance Implications comment to "MVP schema: 2-5 KB observed; post-MVP scenario-progression epic may grow to 5-15 KB as EchoMark schema evolves"
  Both are valid. (b) is honest; (a) preserves ADR invariant. AC-TARGET Polish-phase session is the natural decision point.

- **S-6** — AC-DESKTOP hard bound at 100ms may never trigger (measured 0.96ms → 100× gap). Consider tightening to 50ms once several CI runs provide baseline data. Defer to post-baseline collection.

- **S-7** — Story-007 file's Test Evidence checkbox `[ ] Not yet created` remains unchecked after desktop-substitute landing. Cosmetic; not operationally misleading given deferral prose directly below. AC-TARGET Polish-phase session can check it when authoring the on-device evidence doc.

### Estimated effort

- S-2, S-3, S-4 alone: ~5 min mechanical edit (can fold into any future perf-test touch commit)
- S-1 + S-5 + AC-TARGET evidence doc: ~3-4 hours during Polish-phase Android device session
- S-6: ~2 min after 5-10 CI runs provide variance data

### Resolution trigger

**Primary**: AC-TARGET Polish-phase session (mid-range Android device available). At that time:
1. Open AC-TARGET session
2. Apply S-1 (rename fidelity) to AC-BREAKDOWN
3. Decide S-5 remediation path
4. Apply S-2, S-3, S-4 as in-cycle polish
5. Run perf test on Android device
6. Author `production/qa/evidence/save-v11-android-perf-<date>.md`
7. Check S-7 checkbox
8. Close TD-031

**Secondary**: Any unrelated perf-test touch can apply S-2/S-3/S-4 opportunistically.

---

## TD-032 — Story-001 /code-review advisories + G-12 new gotcha + ADR-0004 errata batch

**Source**: map-grid story-001 `/dev-story` + `/code-review` + `/story-done` (2026-04-25)
**Priority**: Low (advisory / doc-level; zero impact on runtime correctness)
**Status**: Partially resolved (pre-story-005 batch — 2026-04-25)

### Resolution Log

**2026-04-25 — Pre-story-005 cleanup batch** (PR pending) executed the following items:

| Item | Status | Notes |
|---|---|---|
| A-1 (TileData → MapTileData rename) | RESOLVED | ADR-0004 §Decision 1 + Key Interfaces + Risks + GDD table — single replace_all pass |
| A-2 (terrain_version field reordering) | RESOLVED | Both ADR-0004 code blocks updated; loader-first convention noted |
| A-3 (G-12 gotcha entry) | RESOLVED | Appended to `.claude/rules/godot-4x-gotchas.md` between G-11 and Verification Pattern Summary |
| A-4 (story-001 AC-2 text staleness) | RESOLVED | `TileData.new()` → `MapTileData.new()` in QA Test Cases section |
| A-5 (AC-2 default-value coverage gap) | RESOLVED | Added `coord = Vector2i.ZERO` + `is_destructible = false` assertions to default-construction block |
| A-6 (AC-4 intent comment) | RESOLVED | Added 5-line note explaining why AC-3 + AC-4 use separate round-trip saves |
| A-7 (assert_bool(vec == ...) → assert_that.is_equal) | RESOLVED | 4 call sites in `map_grid_test.gd` lines 91, 133, 369, 385 |
| A-8 (redundant `as int` casts in map_grid_test.gd) | RESOLVED | 3 call sites (lines 261, 296, 299) |
| A-8 (extension — same in map_grid_mutation_test.gd) | RESOLVED | 3 call sites cleaned |
| A-9 (DEEP_DUPLICATE_ALL_BUT_SCRIPTS errata) | RESOLVED | ADR-0004 §Engine Compatibility row + §Decision 4 prose updated; enum errata noted |
| A-10 (story-002 AC-7 path mismatch) | RESOLVED | `user://test_map_v2.tres` → `user://map_grid_test_v2_round_trip.tres` (2 occurrences) |
| A-12 (`_last_load_warnings` public query) | RESOLVED | New field + `WARN_*` constants + `get_last_load_warnings()` method + per-tile warning entries in `_apply_load_time_clamps` + 2 test assertions (extended AC-7 negative-hp test + new DESTRUCTIBLE-zero-hp standalone test) |
| A-13 (assert_bool 2 call sites in mutation test) | RESOLVED | Lines 320, 394 — only 2 found at audit time (specialist's third was eliminated by AC-10 close-out edit) |
| A-14 (helper extraction to test_helpers.gd) | RESOLVED | Helper signature changed: passes `test_suite: GdUnitTestSuite` first arg because GdUnit4 v6.1.2 binds `assert_int` as instance method, not free function. 10 call sites updated. ADR-0004-relevant cache-integrity assertion now reusable for story-005/006. |

**ADR-0004 §Changelog updated** with 2026-04-25 errata sweep entry covering A-1 + A-2 + A-9.

**Test results post-batch**: 197/197 PASSED full regression across 3 consecutive runs (0 errors, 0 failures, 0 orphans). Test count delta: +1 (new DESTRUCTIBLE-zero-hp standalone test from A-12).

### Still Open (post-batch)

- **A-11**: 8 advisory edge-case tests for story-003 validator (~1.5-2h). Suggested trigger: batch with story-005 close or as standalone hardening pass.
- **A-15**: 4 advisory edge-case tests for story-004 mutation API (~45 min). Same trigger as A-11.

**Total remaining effort**: ~2-2.75h. Both items are advisory test hardening — primary ACs already covered. May be subsumed by story-005's new test coverage (some edge cases re-exercised through Dijkstra).

---

**Context**: Story-001 closed COMPLETE WITH NOTES. All 5 ACs pass (4 automated + 1 doc-level); 166/166 full regression green. Two documented ADR-0004 deviations (class rename + field ordering) and a newly-discovered Godot 4.6 gotcha (G-12) need batched correction. Two optional test-polish items surfaced by /code-review are also bundled here.

**Items** (6 total, all advisory):

### A-1 — ADR-0004 §Decision 1 class rename: `TileData` → `MapTileData`

**Root cause**: `TileData` is a Godot 4.6 built-in class (TileSet/TileMapLayer API). User `class_name TileData` collides silently — cache registers both, but parser cannot resolve user-class members (e.g., `m.tiles` fails with "Could not resolve external class member").

**Files to update in ADR-0004**:
- §Decision 1 code block — `class_name TileData extends Resource` → `class_name MapTileData extends Resource`
- §Decision 1 prose — all "TileData" mentions (several)
- §Key Interfaces code block — `func get_tile(coord: Vector2i) -> TileData` → `-> MapTileData`
- §Risks R-3 — mentions of "TileData presets" → "MapTileData presets"
- §Risks R-5 — "TileData" references in inspector ergonomics discussion
- §Consequences §Negative — "~1200 TileData Resource allocations" wording
- GDD Requirements Addressed table — `TileData.terrain_type` references

**No code change required** — implementation already uses `MapTileData`. This is doc-only.

### A-2 — ADR-0004 §Decision 1 field ordering: `terrain_version` first

**Rationale**: Implementation places `terrain_version` first in MapResource (mirrors `save_context.gd::schema_version` loader-first convention). ADR code block lists it last. Non-blocking; document the convention.

**Files to update**:
- ADR-0004 §Decision 1 code block — reorder fields to match `map_resource.gd` (terrain_version first)
- §Changelog — add errata entry

### A-3 — `.claude/rules/godot-4x-gotchas.md` — G-12 new entry

**Title**: G-12 — User `class_name` must not collide with Godot built-in classes

**Content** (following G-N format):

> **Context**: declaring a user `class_name` for a Resource / Node / etc.
>
> **Broken**: Godot 4.6 silently registers user `class_name` in `.godot/global_script_class_cache.cfg` even when the name collides with a built-in (e.g., `TileData`, `Tween`, `Material`). The engine built-in wins at parse-time resolution; user-class member access fails with the misleading error: `Parser Error: Could not resolve external class member "foo"`. Even a minimal probe `var m: MyClass = MyClass.new(); print(m.field)` fails. `.uid` files are generated correctly, so the error is entirely parse-time, not import-time.
>
> **Correct**: Choose a `class_name` that doesn't collide. Prefix with project/domain scope (`MapTileData` instead of `TileData`, `GameTween` instead of `Tween`). Before declaring any new `class_name`, search Godot docs for built-in class list and verify no collision.
>
> **Collision-prone names to avoid** (non-exhaustive): `TileData`, `TileMap`, `TileSet`, `Tween`, `Material`, `Curve`, `Shape2D`, `Shape3D`, `Timer`, `Animation`, `Node`, `Resource`, etc. When in doubt, prefix.
>
> **Discovered**: map-grid story-001 round-2 (parse error blocked ALL map_resource_test discovery; diagnosed after the cache-refresh editor pass didn't help).

### A-4 — Story 001 §QA Test Cases AC-2 text staleness

**File**: `production/epics/map-grid/story-001-resource-classes.md`
**Action**: Update AC-2 QA Test Case text: `var t := TileData.new()` → `var t := MapTileData.new()` (1 line). Same for AC-3 fixture descriptions mentioning `TileData`.

### A-5 — (Optional test polish) AC-2 default-value coverage gap

**File**: `tests/unit/core/map_resource_test.gd`
**Action**: In `test_tile_data_class_declaration_fields_and_defaults`, extend the fresh-`MapTileData.new()` block to also assert `coord = Vector2i.ZERO` and `is_destructible = false`. Current block covers 3 of 5 zero-defaults via value; extending makes regressions on field default changes immediately visible. ~4 lines.

### A-6 — (Optional test polish) AC-4 intent comment

**File**: `tests/unit/core/map_resource_test.gd`
**Action**: Add 1-line comment to `test_map_resource_round_trip_preserves_field_types` explaining that its save path is intentionally independent from AC-3's fixture (two separate round-trip saves in the file). ~1 line.

---

**Estimated remediation effort**: 30-45 min total
- A-1 + A-2 together: ~20 min (single ADR edit pass with careful §Changelog entry)
- A-3: ~5 min (append G-12 entry to existing rule file)
- A-4: ~1 min (single edit)
- A-5 + A-6: ~5 min (inline test file edits)

**Suggested trigger**: Batch with map-grid story-002 close-out (avoid repeated ADR-0004 edits across stories) OR at epic close if story-002+ don't surface additional errata.

**Links**:
- Story: `production/epics/map-grid/story-001-resource-classes.md`
- Review: standalone `/code-review` ran 2026-04-25 (godot-gdscript-specialist APPROVED + qa-tester TESTABLE)
- Session extract: `production/session-state/active.md` §Session Extract 2026-04-25

---

### A-7 — (Optional test polish) `assert_bool(vec == ...)` loses diff quality

**Source**: map-grid story-002 `/code-review` godot-gdscript-specialist SUGGESTION #6 (2026-04-25)
**File**: `tests/unit/core/map_grid_test.gd`
**Call sites**: lines 55–57, 90–92, 315–317, 331–333 (4 total)

**Current pattern** (loses diff):
```gdscript
assert_bool(dims == Vector2i.ZERO).override_failure_message("...").is_true()
```

**Preferred pattern** (shows expected vs actual on failure):
```gdscript
assert_that(dims).override_failure_message("...").is_equal(Vector2i.ZERO)
```

**Rationale**: on failure, the first form can only print "expected true, got false" — the actual `dims` value is never surfaced. The second form gives "expected Vector2i(0,0) but got Vector2i(4,2)" diffs that make cols/rows-swap bugs immediately diagnosable. Matters most when story-004/005 extend this test file.

**No correctness impact** — tests catch regressions either way. ~4 line edits.

### A-8 — (Optional test polish) Redundant `as int` casts on PackedByteArray access

**Source**: map-grid story-002 `/code-review` godot-gdscript-specialist SUGGESTION #9 (2026-04-25)
**File**: `tests/unit/core/map_grid_test.gd`
**Call sites**: lines 202, 242, 245 (3 total)

**Current pattern**:
```gdscript
assert_int(grid._passable_base_cache[i] as int)
```

**Preferred pattern**:
```gdscript
assert_int(grid._passable_base_cache[i])
```

**Rationale**: `PackedByteArray` element access returns `int` natively in Godot 4.6. The `as int` cast is a no-op. `assert_int()` in GdUnit4 v6.1.2 accepts an `int` directly — no benefit from the explicit cast. Visual noise only.

**No correctness impact**. ~3 line edits.

### A-9 — ADR-0004 §Decision 4 `DEEP_DUPLICATE_ALL_BUT_SCRIPTS` errata

**Source**: map-grid story-002 `/dev-story` + `/story-done` DEP-1 (2026-04-25)
**File**: `docs/architecture/ADR-0004-map-grid-data-model.md`

**Root cause**: ADR-0004 §Decision 4 prescribes:
> 1. `_map = res.duplicate_deep()` — clones so destruction state does not pollute the disk asset

Implementation follow-up with the explicit `DEEP_DUPLICATE_ALL_BUT_SCRIPTS` flag constant (prose in original drafts) is incorrect: Godot 4.6's `Resource.DeepDuplicateMode` enum has exactly three values — `NONE`, `INTERNAL`, `ALL`. No `ALL_BUT_SCRIPTS` variant exists. Same issue hit save_manager.gd (TD-024 precedent).

**Files to update**:
- ADR-0004 §Decision 4 — clarify the flag is `Resource.DEEP_DUPLICATE_ALL` (not `ALL_BUT_SCRIPTS`)
- ADR-0004 §Engine Compatibility Post-Cutoff APIs Used — amend to name the correct enum value
- §Changelog — add errata entry noting the enum is 3-valued in 4.6

**No code change** — implementation already uses `DEEP_DUPLICATE_ALL` (map_grid.gd:63, save_manager.gd equivalent). Doc-only.

### A-10 — Story-002 §QA Test Cases AC-7 path mismatch

**Source**: map-grid story-002 `/code-review` qa-tester ADVISORY (2026-04-25)
**File**: `production/epics/map-grid/story-002-mapgrid-skeleton-caches.md`

**Action**: Update §QA Test Cases AC-7 Given line: `user://test_map_v2.tres` → `user://map_grid_test_v2_round_trip.tres` (match the actual test file at line 7 + 356 of `map_grid_test.gd`). Keeps the story doc as accurate audit-trail documentation.

**No code change**. ~1 line edit.

---

**Updated estimated remediation effort**: 45-60 min total (original 30-45 + 15 min for A-7..A-10)
- A-1 + A-2 + A-9 together: ~25 min (single ADR-0004 edit pass with careful §Changelog entry covering all three errata)
- A-3: ~5 min (G-12 entry — already drafted verbatim above)
- A-4 + A-10: ~2 min (story-file edits)
- A-5 + A-6 + A-7 + A-8: ~10 min (inline test file edits — consolidate into one commit touching map_resource_test.gd + map_grid_test.gd)

**Suggested trigger** (revised): Batch at story-003 close-out — by then validator errata may add further ADR-0004 items (e.g., ADR §Decision covers validation contracts only implicitly). If no further ADR-0004 deviations land in story-003, execute the batch then.

**Story-002 specific links**:
- Story: `production/epics/map-grid/story-002-mapgrid-skeleton-caches.md`
- Review: standalone `/code-review` ran 2026-04-25 (godot-gdscript-specialist SUGGESTIONS + qa-tester TESTABLE)
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-002)

### A-11 — (Story-003 test hardening) 8 advisory edge-case tests

**Source**: map-grid story-003 `/code-review` qa-tester ADVISORY (2026-04-25) — 8 `Edge cases:` variants from story §QA Test Cases lines not currently exercised.

**File**: `tests/unit/core/map_grid_test.gd`

**Tests to add** (all ADVISORY; primary ACs already COVERED by existing 8 story-003 tests + 1 convergent regression):

| # | AC | Suggested function name | Setup |
|---|---|---|---|
| 1 | AC-2 | `test_map_grid_validate_dimension_bounds_all_invalid_variants` | Five fixtures (41×30, 40×31, 15×14, 0×15, 15×0); each returns `false` with `ERR_MAP_DIMENSIONS_INVALID` |
| 2 | AC-3 | `test_map_grid_validate_tile_array_size_over_limit_fails` | 15×15 resource with 226 tiles (over-size); asserts `ERR_TILE_ARRAY_SIZE_MISMATCH` |
| 3 | AC-4 | `test_map_grid_validate_forest_elev_two_fails` | 15×15 map, tile 0 terrain=FOREST(1), elevation=2; exercises multi-valued allowed-range inner loop |
| 4 | AC-4 | `test_map_grid_validate_mountain_elev_zero_fails` | 15×15 map, tile 0 terrain=MOUNTAIN(3), elevation=0; single-valued range boundary |
| 5 | AC-5 | `test_map_grid_validate_impassable_enemy_occupied_fails` | 15×15 map, tile 0 `is_passable_base=false`, `tile_state=ENEMY_OCCUPIED(2)`; exercises both state-guard branches |
| 6 | AC-5 | `test_map_grid_validate_impassable_empty_is_valid` | 15×15 map, tile 0 `is_passable_base=false`, `tile_state=EMPTY(0)`; must pass — confirms guard is exclusive not overbroad |
| 7 | AC-6 | `test_map_grid_validate_swapped_adjacent_tiles_produce_two_errors` | Swap `tiles[78].coord` and `tiles[79].coord`; asserts ≥2 `ERR_TILE_ARRAY_POSITION_MISMATCH` entries |
| 8 | AC-7 | `test_map_grid_validate_destructible_zero_hp_sets_destroyed_state` | Valid 15×15 map, tile 0 `is_destructible=true, destruction_hp=0`; asserts load returns `true` AND `_map.tiles[0].tile_state == TILE_STATE_DESTROYED` |
| 9 | AC-8 | `test_map_grid_validate_collect_all_50_elevation_errors_produces_50_entries` | 40×30 map with 50 PLAINS tiles at `elevation=2`; asserts `errors.size() == 50` (cardinality) |

**Estimated effort**: ~1.5-2h (9 small tests using existing `_make_map` factory + bespoke-fixture pattern established by story-003).

**Not blocking**: story-003 primary ACs all COVERED by existing 8 tests + 1 convergent regression. These advisory tests cover `Edge cases:` variants that increase regression value for story-004/005/006 consumers.

**Suggested trigger**: batch with story-004 close-out — by then the validator will be stress-exercised by mutation API tests. Or pick up standalone before story-005 (Dijkstra) which reads packed caches heavily and benefits from validator hardening.

### A-12 — `_last_load_warnings` public query for `push_warning` verification

**Source**: map-grid story-003 `/code-review` qa-tester Q5 (2026-04-25)

**File**: `src/core/map_grid.gd`

**Context**: AC-7 test asserts `grid._map.tiles[5].destruction_hp == 0` after clamp, but cannot assert that `push_warning` was actually emitted. Clamp could silently succeed without warning and the test would still pass. Debugging-hazard gap: the V-2 invariant narrative is "we clamped but we told you" — silent clamps violate it.

**Proposal**: Add `_last_load_warnings: PackedStringArray` symmetric to `_last_load_errors`; populate inside `_apply_load_time_clamps` with entries like `"WARN_NEGATIVE_DESTRUCTION_HP(5)"` and `"WARN_DESTRUCTIBLE_ZERO_HP_SET_DESTROYED"`. Expose via `get_last_load_warnings() -> PackedStringArray`. Tests assert entries and prefixes.

**Estimated effort**: ~30 min (new field + new public method + warning-string constants + 2 test assertions in AC-7 and new DESTROYED-standalone test).

**Alternative considered and rejected**: GdUnit4 mock-logger for `push_warning` capture — too complex, not worth maintenance cost.

**Suggested trigger**: Batch with A-11 hardening, OR execute in story-004 (more mutation warnings will benefit from the same query surface).

---

**Updated estimated remediation effort (revised)**: 2.5-3.5 hours total
- A-1 + A-2 + A-9 together: ~25 min ADR-0004 edit pass
- A-3: ~5 min (G-12 entry drafted verbatim)
- A-4 + A-10: ~2 min story-file edits
- A-5 + A-6 + A-7 + A-8: ~10 min inline test polish
- **A-11: ~1.5-2h (9 advisory edge tests)**
- **A-12: ~30 min (warnings query + 2 test assertions)**

**Suggested trigger (revised)**: Two-batch plan:
- **Before story-005**: A-1..A-10 + A-12 (ADR errata + docs polish + warnings hook) — unblocks story-005 with clean foundation.
- **After story-004 or before story-005**: A-11 (advisory edge tests) — amortize against story-004's new mutation tests which will re-exercise the validator.

**Story-003 specific links**:
- Story: `production/epics/map-grid/story-003-map-load-validation.md`
- Review: standalone `/code-review` ran 2026-04-25 (godot-gdscript-specialist SUGGESTIONS + qa-tester GAPS)
- **Convergent finding RESOLVED INLINE** during close-out: `_map = null` reset at `load_map` top + `test_..._valid_then_invalid_load_resets_to_inert` regression test. NOT deferred.
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-003)

### A-13 — (Story-004 test polish) `assert_bool(vec == ...)` → `assert_that(vec).is_equal(...)`

**Source**: map-grid story-004 `/code-review` gdscript-specialist Q11 (2026-04-25). Same anti-pattern as A-7 (originally logged for story-002 Vector2i comparisons).

**File**: `tests/integration/core/map_grid_mutation_test.gd`

**Call sites** (3 occurrences): `assert_bool(_tile_destroyed_captures[0] == Vector2i(...))` — grep `_tile_destroyed_captures\[0\] ==` to find. AC-4 destroying test, AC-5 occupant-survives test (ALLY + ENEMY branches).

**Fix**: Replace each with `assert_that(_tile_destroyed_captures[0]).is_equal(Vector2i(...))`.

**Impact**: None at runtime — tests correctly fail when coord is wrong. Pure diagnostic-quality improvement; `assert_that` surfaces actual-vs-expected values; `assert_bool(vec == ...)` prints "expected true, got false" without the coord. Existing `override_failure_message` partially mitigates but is redundant with the better assertion form.

**Estimated effort**: ~3 min (3 one-line replacements).

### A-8 (extension) — Redundant `as int` casts on `PackedByteArray` element access

**Source**: map-grid story-004 `/code-review` gdscript-specialist Q12 (2026-04-25). Same anti-pattern as original A-8 (logged for story-002 lines 202, 242, 245 in `map_grid_test.gd`).

**File**: `tests/integration/core/map_grid_mutation_test.gd` — 3 new call sites: `grid._passable_base_cache[idx] as int`.

**Fix**: Remove `as int` — `PackedByteArray` element access in Godot 4.x returns `int` already.

**Impact**: None at runtime (redundant cast is no-op on value already int). Pure style polish.

**Estimated effort**: ~2 min.

### A-14 — Promote `_assert_all_caches_match_tiledata` to shared test-helpers

**Source**: map-grid story-004 `/code-review` qa-tester Gap 11 (2026-04-25). Pre-story-005 refactor recommendation.

**File**: move from `tests/integration/core/map_grid_mutation_test.gd` (current location) to `tests/unit/core/test_helpers.gd` (existing home of `TestHelpers.get_user_signals` per G-1).

**Context**: Story-005 (Dijkstra) and story-006 (LoS) will read the same 6 packed caches and benefit from a consistent cache-integrity assertion. Keeping this helper local forces duplication or cross-file `load()` — both poor patterns.

**Proposal**:
```gdscript
# In tests/unit/core/test_helpers.gd (append)
static func assert_all_caches_match_tiledata(
        test_suite: GdUnitTestSuite,
        grid: MapGrid,
        coords: Array[Vector2i],
        step: int) -> void:
    # body moved from map_grid_mutation_test.gd unchanged
```

Call sites become: `TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)`.

**Estimated effort**: ~20 min (extract method + update 10 call sites in `map_grid_mutation_test.gd` + smoke-test re-run).

**Suggested trigger**: first task of story-005 (before writing any Dijkstra test). Avoids a second extraction pass later.

### A-15 — (Story-004 test hardening) 4 advisory edge-case tests

**Source**: map-grid story-004 `/code-review` qa-tester Gaps 3a/3b/6a/6b (2026-04-25). All ADVISORY; primary ACs covered by existing 10 tests (including AC-10 inline close-out).

**File**: `tests/integration/core/map_grid_mutation_test.gd`

**Tests to add**:

| # | AC | Function name | Setup |
|---|---|---|---|
| 1 | AC-4 edge | `test_map_grid_mutation_apply_zero_damage_on_destroyed_tile_no_op` | Destroy a tile, then call `apply_tile_damage(coord, 0)`; assert returns false, 0 new emits, state unchanged |
| 2 | AC-5 edge | `test_map_grid_mutation_apply_damage_after_clear_on_ac_edge_4_tile_no_emit` | AC-EDGE-4 scenario (destroyed with occupant), then `clear_occupant`, then `apply_tile_damage` again; assert 0 new emits |
| 3 | AC-7 edge | `test_map_grid_mutation_impassable_destructible_partial_damage_no_destroy` | IMPASSABLE+destructible hp=10; `apply_tile_damage(5)`; assert returns false, tile_state still IMPASSABLE, hp=5, 0 emits |
| 4 | AC-7 edge | `test_map_grid_mutation_impassable_destructible_repeat_damage_no_emit` | After IMPASSABLE+destructible destruction (existing AC-7 edge), apply damage again; assert 0 new emits |

**Estimated effort**: ~45 min (4 small tests using existing `_make_valid_map_for_mutation` factory + established observer pattern).

**Not blocking**: corner-case state transitions mathematically covered by guard composition but not exercised in isolation.

**Suggested trigger**: same pass as A-11 (story-003 advisory edge tests), OR batch with A-14 extract before story-005.

---

**Updated estimated remediation effort (revised — includes A-13..A-15)**: 3.5-4.5 hours total

**Suggested trigger (revised)**: Two-batch plan:
- **Before story-005**: A-1..A-10 + A-12 + A-13 + A-8 extension + A-14 (ADR errata + docs polish + warnings hook + style polish + helper promotion). Combined ~1-1.5h. Clean foundation before Dijkstra.
- **After story-004 or before story-005**: A-11 + A-15 (advisory edge tests). Combined ~2-2.75h. Amortize against story-005's new tests which re-exercise both validator (A-11 targets) and mutation paths (A-15 targets).

**Story-004 specific links**:
- Story: `production/epics/map-grid/story-004-mutation-api-signal.md`
- Review: standalone `/code-review` ran 2026-04-25 (godot-gdscript-specialist SUGGESTIONS + qa-tester TESTABLE with advisory gaps)
- **Convergent findings RESOLVED INLINE** during close-out (NOT deferred):
  1. **Q9 (gdscript-specialist)**: G-6 CI-101 orphan risk — added `_current_grid: MapGrid` tracker + defensive `after_test` free for assertion-failure safety net.
  2. **Gaps 7+8 (qa-tester)**: `ERR_UNIT_COORD_OUT_OF_BOUNDS` path + null-map pre-load mutations — new AC-10 test (`test_..._null_map_and_out_of_bounds_guards_are_noop`) exercises all 6 previously-untested guards (3 null-map + 3 OOB × multiple coord variants).
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-004)

### A-16 — TerrainCost integer ordering reconciliation (story-005) — **RESOLVED 2026-04-25**

**Resolution**: Story-005 spec line 60 carried the spec-vs-MapGrid ordering note as a documented deviation; MapGrid's already-committed ordering (PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3) is canonical and matches `terrain_cost.gd`. No spec edit required — the deviation is permanently captured in the Completion Notes block of story-005 and the inline comment at `terrain_cost.gd:13`. Closing without ADR change.



**Source**: map-grid story-005 implementation 2026-04-25.

**Issue**: Story-005 spec §Implementation Notes line 60 prescribes:
```
const PLAINS := 0, HILLS := 1, MOUNTAIN := 2, FOREST := 3, RIVER := 4, ...
```
But `MapGrid` (committed at story-003, line 47 + ELEVATION_RANGES indexing) uses:
```
PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7
```

Implementation followed `MapGrid`'s committed ordering (the `_terrain_type_cache` is already populated with this layout across 196+ baseline tests). `terrain_cost.gd` line 13 documents the deviation explicitly.

**Errata required**:
- `production/epics/map-grid/story-005-dijkstra-movement-range.md` line 60 — update to MapGrid ordering
- ADR-0004 — if the spec ordering originated there, update accordingly

**Estimated effort**: ~10 min (one story-spec edit; verify ADR alignment).

**Suggested trigger**: ADR-0004 errata pass (batched with A-17, A-18, A-20).

### A-17 — DESTRUCTIBLE skip rule not applied (story-005)

**Source**: map-grid story-005 implementation 2026-04-25; gdscript-specialist code review verified.

**Issue**: orchestrator's pre-implementation guidance asked for `TILE_STATE_DESTRUCTIBLE` to be added to the Dijkstra skip list as a safety guard. Final implementation skips only `TILE_STATE_ENEMY_OCCUPIED` and `TILE_STATE_IMPASSABLE` (`map_grid.gd:806`); the orthogonal `_passable_base_cache[nidx] == 0` guard catches DESTRUCTIBLE tiles in practice (undestroyed walls have `is_passable_base = false`).

**Resolution**: not a defect; skipping via `_passable_base_cache` is sufficient. The explicit DESTRUCTIBLE-in-skip-list belt-and-braces is purely defensive — only matters if a future tile arrives with `is_passable_base = true` AND `tile_state = DESTRUCTIBLE`, which contradicts the GDD §ST-1 schema.

**Action**: optional — add `TILE_STATE_DESTRUCTIBLE` to the skip-list at `map_grid.gd:806` for defensive symmetry. ~5 min. No errata required against ADR-0004 (the ADR doesn't enumerate DESTRUCTIBLE specifically).

**Suggested trigger**: same pass as A-16 if ADR-0004 receives an errata revision.

### A-18 — `get_path` → `get_movement_path` API rename (story-005) — **RESOLVED 2026-04-25**

**Resolution**: Applied 3-document errata in `chore/map-grid-td-032-adr-errata` branch:
- `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 5 (signature block) and §Key Interfaces signature mirror — both updated to `get_movement_path` plus errata callout linking to TD-032 A-18/A-21.
- `docs/architecture/tr-registry.yaml` TR-map-grid-003 — requirement text updated to list `get_movement_path` and the extended signatures; `revised: 2026-04-25`.
- `design/gdd/map-grid.md` Cross-system contract table — `get_path()` references replaced with `get_movement_path()` (2 occurrences).



**Source**: map-grid story-005 implementation 2026-04-25; sub-agent self-flagged Node.get_path collision.

**Issue**: ADR-0004 §Decision 7 + TR-map-grid-003 + story-005 all specify `get_path(from, to, unit_type)` as the public API name. Godot's `Node` class has an inherited `get_path() -> NodePath` method. A user `func get_path(...) -> PackedVector2Array` on a `Node`-extending class shadows the inherited method, surprising callers and potentially breaking code that expected NodePath. Implementation renamed to `get_movement_path(...)`.

**Errata required (3 documents)**:
- `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 7 + §Public API surface — update method name
- `docs/architecture/tr-registry.yaml` TR-map-grid-003 requirement text — replace `get_path` with `get_movement_path`
- `production/epics/map-grid/story-005-dijkstra-movement-range.md` AC list (lines 40, 47-48) — update spec text + AC-9 from==to and unreachable cases

Story-006 (LoS + remaining 7 queries) is unaffected — it adds `has_line_of_sight`, `get_attack_range`, etc., not `get_path`.

**Estimated effort**: ~15 min (3-document edit + verification).

**Suggested trigger**: batch with A-16, A-17, A-20 in a single ADR-0004 errata pass before story-007 close-out.

### A-19 — AC-3b move_range deviation (test-only; documented inline)

**Source**: map-grid story-005 test authoring 2026-04-25.

**Issue**: Story-005 spec AC-3 (line 107) edge case "change (1,0) to ENEMY_OCCUPIED → (2,0) and (3,0) also dropped" assumes move_range=4 (corridor budget). Under the open 15×15 grid (min validator dimensions), the row-1 detour `(0,0)→(0,1)→(1,1)→(2,1)→(2,0)` costs exactly 40 = budget at move_range=4 — making (2,0) reachable around the enemy block, defeating the spec's intent.

**Resolution**: AC-3b test (`test_get_movement_range_enemy_occupied_blocks_traversal`) uses move_range=3 (budget=30) which keeps the detour at cost 40 > 30 off-budget while preserving the corridor-cost semantics. Documented inline in test docstring at lines 273-276.

**Errata optional**: spec line 107 edge-case wording is technically correct under a 4×1 corridor (the spec's original assumption), but doesn't apply under the validator's 15×15 minimum. Update story-005 spec to clarify "in a corridor with no orthogonal alternatives" or accept the test's m=3 framing.

**Estimated effort**: ~5 min (one spec edit) or skip entirely.

**Suggested trigger**: same pass as A-18 if revising story-005 spec; otherwise no action needed.

### A-20 — Cost-model interpretation: standard Dijkstra vs origin-included (story-005) — **RESOLVED 2026-04-25**

**Resolution**: Applied 3-document errata in `chore/map-grid-td-032-adr-errata` branch:
- `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 7 — added explicit "step_cost is the cost of entering a tile (origin contributes 0)" + errata callout reconciling earlier "10+15+10=35" examples to standard Dijkstra.
- `design/gdd/map-grid.md` §F-3 — Example block rewritten to show origin-excluded math: `0+10+10+10=30 ≤ 30`, `0+10+10+15=35 > 30`, `0+10+10+7=27 ≤ 30`. Errata note linking to TD-032 A-20.
- `production/epics/map-grid/story-005-dijkstra-movement-range.md` — AC-F-3 boundary spec text updated to reference HILLS at (3,0) (the actual budget boundary discriminator under standard model); inline TD-032 A-20 errata note.



**Source**: map-grid story-005 `/code-review` 2026-04-25 (convergent gdscript-specialist + qa-tester finding via inverted assertion).

**Issue**: Implementation uses **standard Dijkstra**: origin enqueued at cost 0; `step_cost = BASE_TERRAIN_COST[terrain] × cost_multiplier(unit_type, terrain)` charged on entry to each non-origin tile. Total path cost = sum of entry costs of non-origin tiles.

Story spec line 99 + ADR-0004 §F-3 reference example reads:
```
PLAINS→HILLS→PLAINS = 10+15+10 = 35 > 30 → NOT reachable
```
This arithmetic includes the origin tile's terrain cost (3 terms for a 3-tile path), implying a **non-standard origin-included** cost model. Under standard Dijkstra the same path costs 25 (only 2 transitions; origin contributes 0).

The spec example's "35" is internally inconsistent with the standard Dijkstra interpretation that the implementation chose (and that AC-1's "Manhattan diamond r=3 + origin = 25 tiles" assertion in the test confirms). The inverted-assertion bug at the original AC-2a was a symptom of this divergence — the test was written under the spec's model, the implementation used the standard model, and the inversion masked the mismatch.

**Resolution**: AC-2a/2b restructured during /code-review — HILLS/ROAD moved from (1,0) to (3,0) so the budget boundary matches the standard model:
- HILLS at (3,0): cost 0+10+10+15 = 35 > 30 NOT reachable ✓
- ROAD at (3,0):  cost 0+10+10+7  = 27 ≤ 30 REACHABLE ✓

**Errata required (3 documents)**:
- `docs/architecture/ADR-0004-map-grid-data-model.md` §F-3 cost-formula example — update to standard model
- `production/epics/map-grid/story-005-dijkstra-movement-range.md` line 99 (AC-F-3 boundary) + line 95 (Manhattan-diamond tile count) — reconcile with standard model
- `design/gdd/map-grid.md` §F-3 (if cost formula example present) — same update

**Estimated effort**: ~30-45 min (3-document edit + careful arithmetic verification across all examples).

**Suggested trigger**: same pass as A-18 (ADR-0004 errata batch).

### G-13 candidate — User-defined methods can shadow inherited Node API

**Source**: map-grid story-005 implementation 2026-04-25 (`get_path` → `get_movement_path` rename rationale, A-18).

**Pattern**: Declaring a method on a `Node`-extending class (or any subclass of an engine type) with the same name as an inherited engine method silently shadows the engine method. Symptom: code expecting the engine-typed return value (e.g., `Node.get_path() -> NodePath`) gets the user method's return type instead, often without a parse-time warning in non-strict mode.

**Mitigation**: Prefix domain-specific verbs (`get_movement_path`, `get_attack_range`, `get_destination_node` instead of `get_node`). Cross-reference Godot's `Node` API (and parent classes) before declaring any `func get_*`, `func set_*`, `func is_*`, or other common-verb methods.

**Codification**: add as G-13 to `.claude/rules/godot-4x-gotchas.md` after this story closes; update TD-013 register cross-reference.

**Estimated effort**: ~20 min (rule-file authoring + TD-013 register touch + cross-reference).

**Suggested trigger**: next time `.claude/rules/godot-4x-gotchas.md` is touched (G-12 was added at map-grid story-001; G-14 was added at terrain-effect story-001 for class-cache refresh; this Node-API-shadowing entry remains the open G-13 reservation).

---

**Updated estimated remediation effort (revised — includes A-16..A-20 + G-13)**: 5-6 hours total

**Suggested trigger (revised, post-story-005)**: Three-batch plan:
- **Before story-006**: G-13 codification (~20 min) — keeps the rule file fresh while context is active
- **ADR-0004 errata pass**: A-16 + A-17 + A-18 + A-20 (4 deviations across 3 documents). Combined ~1-1.5h. Best done before story-007 (perf benchmark) so AC-PERF-2 measures the canonical contract.
- **Optional polish**: A-19 (story-005 spec wording) — 5 min if the ADR errata pass is happening anyway.

**Story-005 specific links**:
- Story: `production/epics/map-grid/story-005-dijkstra-movement-range.md`
- Review: standalone `/code-review` ran 2026-04-25 (godot-gdscript-specialist APPROVED WITH SUGGESTIONS + qa-tester GAPS — convergent assertion-inversion finding)
- **Convergent finding RESOLVED INLINE** during close-out (NOT deferred):
  - Inverted `assert_bool(not has(...)).is_false()` at line 200 (original AC-2a) masked a deeper cost-model divergence between spec and implementation. AC-2a/2b restructured (HILLS/ROAD at (3,0) instead of (1,0)) for the meaningful budget discriminator.
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-005)

### A-21 — Extended query signatures (story-006) — **RESOLVED 2026-04-25**

**Resolution**: Applied in `chore/map-grid-td-032-adr-errata` branch:
- `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 5 + §Key Interfaces — signatures updated to include `apply_los: bool` (get_attack_range) and `defender_facing: int` (get_attack_direction); plus optional `faction: int = -1` filter on `get_adjacent_units` and `get_occupied_tiles` for completeness with story-006 implementation.
- `docs/architecture/tr-registry.yaml` TR-map-grid-003 — requirement text now enumerates the full signature contract (revised 2026-04-25).



**Source**: map-grid story-006 implementation 2026-04-25.

**Issue**: ADR-0004 §Decision 5 lists minimal MVP signatures; story-006 spec extends both required parameters:
- `get_attack_range(origin, attack_range, apply_los: bool)` — `apply_los` needed for §CR-7 ranged-vs-melee distinction
- `get_attack_direction(attacker, defender, defender_facing: int)` — `defender_facing` needed for §F-5 angular formula

Implementation followed story-006 spec signatures (only way to satisfy AC-7 + AC-8).

**Errata required**: ADR-0004 §Decision 5 + tr-registry.yaml TR-map-grid-003 (if signature text appears).

**Estimated effort**: ~15 min.

**Suggested trigger**: ADR-0004 errata batch with A-16, A-17, A-18, A-20, A-22.

### A-22 — get_attack_direction sign convention errata (story-006) — **RESOLVED 2026-04-25**

**Resolution**: Applied 3-document errata in `chore/map-grid-td-032-adr-errata` branch:
- `production/epics/map-grid/story-006-los-attack-queries.md` line 70-73 — formula block rewritten with the AC-canonical sign convention (`dc > 0 ⇒ WEST`, `dr > 0 ⇒ NORTH`); inline TD-032 A-22 errata callout naming the previous draft's inversion.
- `design/gdd/map-grid.md` §F-5 — formula block + variable table + Example matrix all rewritten to AC-canonical convention; verification across NORTH/EAST/SOUTH/WEST attacker positions vs NORTH-facing defender; errata callout.
- `docs/architecture/ADR-0004-map-grid-data-model.md` §Decision 5 — signature update notes the `defender_facing: int` parameter addition (formula content stays in the GDD per ADR/GDD separation of concerns; ADR doesn't restate F-5 internals).

`damage-calc.md` cross-system contract verified: the canonical convention here matches the AC-8 expected matrix referenced as the cross-system contract; no change needed downstream.



**Source**: map-grid story-006 `/code-review` 2026-04-25 (caught by AC-8 expected-value comparison).

**Issue**: Story-006 spec line 70-73 prescribes "EAST if dc > 0, WEST if dc < 0; SOUTH if dr > 0, NORTH if dr < 0." This contradicts AC-8 expected matrix:
- attacker N(2,1) of defender(2,2) facing NORTH → AC-8 says FRONT
- Spec formula gives: dc=0, dr=1 → SOUTH → relative_angle=2 → REAR (wrong)

AC-canonical convention: with `dc = defender.x - attacker.x`, `dc > 0` means attacker is WEST of defender, so attack came from WEST (attack_dir = WEST). Same for `dr > 0` → NORTH.

**Resolution**: Implementation uses inverted (AC-canonical) mapping:
```
attack_dir = WEST if dc > 0 else EAST   # spec said EAST/WEST
attack_dir = NORTH if dr > 0 else SOUTH # spec said SOUTH/NORTH
```

Inline comment at `src/core/map_grid.gd:1263-1267` documents.

**Errata required (3 documents)**:
- `production/epics/map-grid/story-006-los-attack-queries.md` line 70-73 — flip sign convention
- `docs/architecture/ADR-0004-map-grid-data-model.md` §F-5 — verify sign convention matches AC-8
- `design/gdd/map-grid.md` §F-5 — same verification + cross-check with `damage-calc.md`

**Estimated effort**: ~30 min (3-document edit + cross-check damage-calc.md).

**Suggested trigger**: ADR-0004 errata batch with A-16, A-17, A-18, A-20, A-21.

### A-23 — Destroyed-wall LoS restoration test missing (story-006)

**Source**: map-grid story-006 `/code-review` qa-tester gap 1 (2026-04-25).

**Issue**: Story-006 V-3 matrix spec line 126 lists "2 destroyed-wall cases (mutation via story-004 API to set STATE_DESTROYED → LoS restored)". Implementation V-3 fixture has NONE — the destroyed-wall LoS-restoration branch is unexercised.

**Resolution**: Add test function building a map with FORTRESS_WALL, calling `apply_tile_damage` to destroy it, then asserting `has_line_of_sight` across the former wall returns `true`.

**Estimated effort**: ~20 min.

**Suggested trigger**: advisory test batch with A-24, A-25, A-26.

### A-24 — Defensive guard tests + doc-comment correction (story-006)

**Source**: map-grid story-006 `/code-review` qa-tester edge-case findings (2026-04-25).

**Issue**: 3 untested defensive guards:
- `has_line_of_sight` with `_map == null` (line 1047)
- `has_line_of_sight` with out-of-bounds coords (lines 1054-1057)
- `get_adjacent_units` with out-of-bounds `coord` (lines 1300-1301)

Plus 1 doc accuracy issue: `get_attack_direction` doc comment (line 1239) says "out-of-range `defender_facing` values produce undefined behavior" but actual behavior is well-defined (modulo arithmetic gives `relative_angle ∈ [0,3]` for any integer).

**Resolution**: 2 small test functions + 1 doc-comment correction.

**Estimated effort**: ~30 min.

**Suggested trigger**: advisory test batch with A-23, A-25, A-26.

### A-25 — Attack-direction matrix incomplete (story-006)

**Source**: map-grid story-006 `/code-review` qa-tester gap (2026-04-25).

**Issue**: AC-8 covers `get_attack_direction` for NORTH and EAST `defender_facing` only. Full canonical contract with `damage-calc.md` is the 4×4 cross-product. SOUTH and WEST are deterministic by the same formula but not explicitly verified.

**Resolution**: 2 test functions mirroring AC-8 NORTH/EAST tests for SOUTH and WEST facing.

**Estimated effort**: ~15 min (copy-paste-modify + 8 expected pairs).

**Suggested trigger**: advisory test batch with A-23, A-24, A-26.

### A-26 — Tie-break × non-NORTH facing edge case (story-006)

**Source**: map-grid story-006 `/code-review` qa-tester observation (2026-04-25).

**Issue**: AC-9 verifies horizontal tie-break only against NORTH-facing defender. Tie-break × non-NORTH is tested only implicitly via formula derivation.

**Resolution**: 1 test function with 4 cross-product cases (e.g., SE diagonal vs EAST-facing → FRONT).

**Estimated effort**: ~10 min.

**Suggested trigger**: advisory test batch with A-23, A-24, A-25.

---

**Updated estimated remediation effort (revised — includes A-21..A-26)**: 7-8 hours total

**Suggested trigger (revised, post-story-006)**: Two-batch plan:
- **ADR-0004 errata pass**: A-16 + A-17 + A-18 + A-20 + A-21 + A-22 (6 deviations across 3 documents). Combined ~2-2.5h. Best done before story-007 close-out so AC-PERF-2 measures the canonical contract and `damage-calc.md` cross-system contract reflects A-22's sign convention correctly.
- **Advisory test pass**: A-23 + A-24 + A-25 + A-26 (4 follow-up tests + 1 doc fix). Combined ~75 min.

**Story-006 specific links**:
- Story: `production/epics/map-grid/story-006-los-attack-queries.md`
- Review: standalone `/code-review` 2026-04-25 (godot-gdscript-specialist CLEAN + qa-tester TESTABLE WITH ADVISORY GAPS)
- **Real bugs caught and fixed during integration testing** (NOT deferred — validates test rigor):
  1. Bresenham corner-cut order: D=2 diagonal reached destination in one iteration, skipping corner-cut. Fixed by running corner-cut BEFORE destination guard.
  2. Diagonal-step intermediate: post-step `(x,y)` was never evaluated. Fixed with unconditional `_tile_blocks_los(x,y)` after destination guard.
  3. Test fixture: FORTRESS_WALL elev=0 violated CR-3 ELEVATION_RANGES → load_map silent fail → all LoS returned false. Fixed factory to elev=1.
- **Spec-canonical sign convention divergence (A-22)**: caught by AC-8 expected-value comparison; spec wrong, AC canonical.
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-006)

### A-27 — Increase perf-test warmup from 10 → 20 iterations (story-007)

**Source**: map-grid story-007 `/code-review` qa-tester suggestion 5 (2026-04-25).

**Issue**: 10 warmup iterations is marginal for cold-cache eviction on Linux x86_64 CI runners (L2/L3 cache capacity differs significantly from macOS arm64 unified memory). Observed warmup_ratio=1.08× on the developer machine suggests caches were already warm before warmup began (probable fixture-loader effect during gdunit4 boot). On a fresh headless CI runner with cold cache, 10 warmup iters may not stabilize p50 on x86_64.

**Resolution**: Bump `WARMUP_ITERATIONS` constant from 10 to 20 in `map_grid_perf_test.gd`. Cost: ~1ms additional test time (negligible).

**Estimated effort**: ~5 min.

**Suggested trigger**: same pass as A-28 + A-29 (perf-test polish batch).

### A-28 — Normalize AC-FRAME-TIME warmup to match AC-DESKTOP (story-007)

**Source**: map-grid story-007 `/code-review` qa-tester edge case (2026-04-25).

**Issue**: `test_map_grid_perf_get_movement_range_p95_under_desktop_budget` runs 10 warmup iterations before the measurement loop. `test_map_grid_perf_frame_time_no_three_consecutive_above_16ms` runs only 1 warmup iteration. The asymmetry is unexplained and could cause the first 1-2 samples in the AC-FRAME-TIME measurement array to be cold-cache-inflated, creating false 2-consecutive advisories.

**Resolution**: Increase AC-FRAME-TIME warmup to 10 iterations (or 20 if A-27 lands first); add a brief comment explaining why both tests use the same warmup count.

**Estimated effort**: ~5 min.

**Suggested trigger**: same pass as A-27.

### A-29 — JSON-structured perf artifact for trend-dashboard ingestion (story-007)

**Source**: map-grid story-007 `/code-review` qa-tester suggestion 6 (2026-04-25).

**Issue**: AC-DESKTOP test currently emits stats via plain `print()` to stdout. CI captures the log but downstream consumers (e.g., a future perf-trend dashboard) would need to parse human-readable text. Story-007 unlocks epic DoD item "V-1 performance: get_movement_range() <16 ms on 40×30" — a structured artifact would enable multi-run trend tracking.

**Resolution**: Add a single `print(JSON.stringify({...}))` line emitting `{p50_us, p95_us, max_us, mean_us, warmup_ratio, iterations}` after the existing diagnostic print. A future `tools/ci/parse_perf_log.sh` can grep for the JSON line and POST to whatever consumer exists.

**Estimated effort**: ~10 min.

**Priority**: LOW — defer until a trend-dashboard consumer exists. Premature artifacts decay if no one reads them.

**Suggested trigger**: when a perf-trend dashboard or CI artifact storage is introduced.

### A-30 — Reproducibility AC documented as deferred, not automated (story-007)

**Source**: map-grid story-007 `/code-review` qa-tester reproducibility section (2026-04-25).

**Issue**: Story-007 spec line 41 includes the AC: "10 consecutive full-suite runs produce p95 values within ±10% variance; measurement framework documented in test file header." The header IS extensively documented, but no automated test verifies the ±10% property. The deferral was applied inline during /code-review (test header now mirrors AC-BREAKDOWN/AC-TARGET deferral language with explicit reactivation trigger), but no follow-up infrastructure exists.

**Resolution**: When (and only when) a perf-trend dashboard is introduced (see A-29), add a CI job that runs the perf suite N times and asserts p95 variance is within ±10%. Until then, the AC remains "manually verifiable, CI-impractical" — accepted state.

**Estimated effort**: ~30 min (CI job authoring + dashboard hookup) IF dashboard exists.

**Priority**: LOWEST — depends on A-29 dashboard existing first.

**Suggested trigger**: same pass as A-29.

---

**Updated estimated remediation effort (revised — includes A-23..A-30)**: 8.5-9.5 hours total

**Suggested trigger (revised, post-story-007)**: Three-batch plan:
- **ADR-0004 errata pass**: A-16 + A-17 + A-18 + A-20 + A-21 + A-22 (6 deviations across 3 documents). Combined ~2-2.5h.
- **Map-grid advisory test pass**: A-23 + A-24 + A-25 + A-26 (story-006 follow-ups) + A-27 + A-28 (story-007 polish). Combined ~75-80 min.
- **Perf trend infrastructure (deferred until consumer exists)**: A-29 + A-30. Combined ~40 min.

**Story-007 specific links**:
- Story: `production/epics/map-grid/story-007-perf-baseline.md`
- Review: standalone `/code-review` 2026-04-25 (godot-gdscript-specialist CLEAN with suggestions + qa-tester TESTABLE WITH GAPS)
- **Real drift caught and fixed inline during code-review** (NOT deferred — validates strict-assertion pattern):
  - Initial fixture-distribution assertion expected PLAINS=720/ROAD=120; actual was 721/119. Caused by enemy-coord override at (8,22) flipping a ROAD tile to PLAINS. Assertion adjusted to reflect the deterministic post-override truth, with comment naming the override-induced count shift. The new strict assertion now functions as a CI-blocking guard against future fixture regeneration drift.
- **Spec-internal collision resolved at generator time**: Story line 56 listed (20,15) as an enemy_occupied coord; line 80 also fixed (20,15) as the player query origin. Resolution: enemy moved to (25,12); player remains (20,15).
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-007)

### A-31 — Story-008 spec AC-R3-INLINE-ASSERT type= value erratum (story-008) — **RESOLVED 2026-04-25**

**Resolution**: Applied in `chore/map-grid-td-032-adr-errata` branch:
- `production/epics/map-grid/story-008-inspector-fixture-manual-qa.md` AC-R3-INLINE-ASSERT (line 38 area) + AC-5 in §QA Test Cases — both updated to reference `[sub_resource type="Resource" id="Resource_XXX"]` form with explanatory note about `MapTileData extends Resource` per G-12 collision avoidance with built-in `TileData`.

Evidence doc (`production/qa/evidence/map-grid-inspector-v7.md`) was already correct — no change needed there.



**Source**: map-grid story-008 `/code-review` qa-tester gap 6 (2026-04-25).

**Issue**: Story-008 spec line 38 (AC-R3-INLINE-ASSERT) says verifiers should look for `[sub_resource type="TileData" ...]` blocks in plain-text inspection. Actual fixture serialization uses `type="Resource"` because `MapTileData` is a user `class_name MapTileData extends Resource` declaration, not Godot's built-in `TileData` (which would collide per G-12 — see story-001 / TD-013). The plain-text grep evidence in the evidence doc correctly shows `type="Resource"`, which matches reality. Anyone reading the story spec text and then the evidence doc would see a mismatch.

**Resolution**: Update story-008 spec line 38 + AC-5 (line 96) to read:
```
TileData entries appear as [sub_resource type="Resource" id="Resource_XXX"] blocks
within the same file (note: type="Resource" because MapTileData extends Resource;
G-12 prohibits class_name "TileData" collision with built-in)
```

Evidence doc requires NO change — already shows the correct form.

**Estimated effort**: ~5 min (single story-spec edit).

**Suggested trigger**: same pass as A-21 (story-006 spec errata) since both are spec-only edits in the map-grid epic, OR standalone whenever the map-grid epic spec receives any other update.

---

**Updated estimated remediation effort (revised — includes A-21..A-31)**: 8.5-10 hours total

**Suggested trigger (revised, post-story-008)**: Three-batch plan unchanged (A-31 added to errata-pass batch):
- **ADR-0004 + spec errata pass**: A-16 + A-17 + A-18 + A-20 + A-21 + A-22 + A-31 (7 deviations across 4 documents). Combined ~2.5-3h.
- **Map-grid advisory test pass**: A-23 + A-24 + A-25 + A-26 + A-27 + A-28 (6 follow-up tests + 1 doc fix). Combined ~75-80 min.
- **Perf trend infrastructure (deferred until consumer exists)**: A-29 + A-30. Combined ~40 min.

**Story-008 specific links**:
- Story: `production/epics/map-grid/story-008-inspector-fixture-manual-qa.md`
- Review: standalone `/code-review` 2026-04-25 (godot-gdscript-specialist CLEAN + qa-tester ACHIEVABLE WITH GAPS — 5 of 6 improvements applied inline)
- Evidence doc: `production/qa/evidence/map-grid-inspector-v7.md` (programmatic gates passing; 4 manual placeholders pending user sign-off)
- 5 evidence-doc improvements applied inline (Click→Double-click, deselect-vs-close-tab, screenshot dir alignment, AC-3 CI re-verification step, authoring-section CI validation note)
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-008)

---

## TD-033 — terrain-effect story-002 /code-review W-2: cross-doc MapGrid ordering invariant undefended

**Origin**: terrain-effect story-002 `/code-review` 2026-04-25 (qa-tester WARNING W-2)
**Category**: tests / spec-trace
**Severity**: medium (cross-doc desync risk if MapGrid terrain ordering changes; would only surface as failures in story-004+ consumers)
**Status**: deferred to story-006 Map/Grid integration

**Summary**: Story-002 AC-2 documents that the 8 terrain-type integer constants (`TerrainEffect.PLAINS=0` .. `ROAD=7`) MUST match `MapGrid.ELEVATION_RANGES` ordering per TD-032 A-16 reconciliation. The skeleton test (`test_terrain_effect_terrain_type_constants_canonical_order`) pins the 8 literal integer values, but does NOT assert any structural cross-reference to `MapGrid` constants. If `MapGrid` reorders or renumbers terrain constants in a future story, the desync would be invisible until story-004+ query consumers fail at runtime with surprising results (e.g., a tile flagged as PLAINS in MapGrid but interpreted as FOREST by TerrainEffect).

**Why deferred**: The story explicitly scopes this as out-of-bounds for story-002 (line 88: "if MapGrid changes ordering, both must update atomically (cross-doc errata — out of scope here)"). Story-006 owns the Map/Grid integration boundary and is the natural place to add the guard test.

**Proposed remediation** (story-006 scope addition):
1. Add `tests/unit/core/terrain_effect_mapgrid_invariant_test.gd` (or fold into story-006's existing test file).
2. Test: assert each `TerrainEffect.<TERRAIN>` integer matches the corresponding `MapGrid.ELEVATION_RANGES` entry's terrain-type position.
3. Failure message must clearly state "TerrainEffect/MapGrid terrain-type ordering desync — update both atomically per TD-032 A-16."
4. Cost: ~15-20 minutes.

**Codification path**: when story-006 lands, this TD entry should be marked `Status: resolved` with the test file path as evidence.

**Source files referenced**:
- `src/core/terrain_effect.gd` (lines 43-58: 8 terrain-type constants)
- `src/core/map_grid.gd` (when story-006 begins, the canonical ELEVATION_RANGES location)
- `production/epics/terrain-effect/story-002-skeleton-static-state.md` (AC-2 + edge case note)
- `production/epics/terrain-effect/story-006-cost-multiplier-mapgrid-migration.md` (where the guard test should land)
- `docs/tech-debt-register.md` TD-032 §A-16 (the reconciliation that established the canonical ordering invariant)

**Cross-references**:
- Story: `production/epics/terrain-effect/story-002-skeleton-static-state.md`
- Review: standalone `/code-review` 2026-04-25 (godot-gdscript-specialist APPROVED + qa-tester TESTABLE WITH GAPS — convergent on 4 findings; W-1 + S-1 applied inline; W-3 + S-2 confirmed false positives; W-2 deferred here)
- Completion: session extract `production/session-state/active.md` §/story-done 2026-04-25 (story-002)

---

## TD-034 — terrain-effect story-003 /code-review deferred advisories (test infrastructure hardening + advisory edge tests)

**Origin**: terrain-effect story-003 `/code-review` 2026-04-25 (godot-gdscript-specialist APPROVED WITH SUGGESTIONS + qa-tester TESTABLE WITH GAPS — 7 of 14 findings applied inline; 7 deferred here as advisory)
**Category**: tests / refactor / docs
**Severity**: low (none affect correctness or production behavior; all are testability/maintainability hardening)
**Status**: open — defer to a "test infrastructure hardening" pass when convenient

**Summary**: The /code-review surfaced multiple advisory test improvements that would harden the suite against latent regressions but are not required for story-003 correctness. The implementation passes 252/252 with 0 errors / 0 failures and meets all 8 ACs (+ AC-9 file-not-found follow-up). These advisories represent coverage ceiling improvements deferable until they accumulate enough value (or until a related epic touches the same files).

**Deferred items grouped by theme**:

### A. Validator method-length compliance (gdscript-specialist S-2)

`_validate_config()` in `src/core/terrain_effect.gd` is ~120 LoC, exceeding the 40-line per-method standard from `.claude/docs/coding-standards.md` by 3x. The linear flow is currently the readable form (each section maps to a JSON schema section), but a refactor into 5 subsection helpers would improve method-length compliance without sacrificing clarity:
- `_validate_terrain_modifiers(cfg) -> bool`
- `_validate_elevation_modifiers(cfg) -> bool`
- `_validate_caps(cfg) -> bool`
- `_validate_ai_scoring(cfg) -> bool`
- `_validate_cost_matrix(cfg) -> bool`

**Cost**: ~30 minutes. **Benefit**: each helper is independently testable in isolation; method-length flag clears.

### B. JSON fixture DRY refactor (qa-tester GAP-5 / R-5)

`tests/unit/core/terrain_effect_config_test.gd` currently has 5 inline JSON heredocs (AC-2, AC-4, AC-5, AC-6, AC-7) — each carries the full 8-terrain × 5-elevation schema. If a schema field is added to the validator, all 5 fixtures need synchronous updates or tests silently start failing the new validator.

Proposed remediation: a `_build_canonical_json(overrides: Dictionary) -> String` helper that loads `terrain_config.json` as text, parses it, applies the per-test override dict, re-serializes via `JSON.stringify()`, and returns the string. Each per-test fixture would then be a 2-line definition with only the specific override that triggers the failure under test.

**Cost**: ~45 minutes. **Benefit**: schema-evolution drift risk eliminated; each test's intent becomes immediately legible; ~60% LoC reduction in fixture sections.

### C. Advisory edge-case tests (qa-tester R-4 + EC-1, EC-2, EC-4, EC-5)

The validator correctly handles several edge cases that aren't directly tested:
- **EC-1 / R-4**: `TYPE_BOOL` passed to `_validate_int_field` (e.g., `"defense_bonus": true`). Clause 1 (`typeof != TYPE_FLOAT`) rejects correctly. Add `test_terrain_effect_config_boolean_field_falls_back`.
- **EC-2**: Extra unknown top-level keys (e.g., `"unknown_field": "foo"`). Validator silently ignores — by design (permissive). Add a test documenting this contract.
- **EC-4**: Multiple sequential loads with different paths after the guard fires. The guard short-circuits and preserves first-load state. Add `test_terrain_effect_config_no_reload_without_reset`.
- **EC-5**: `schema_version: 1` (TYPE_INT, not TYPE_FLOAT) edge — rejected by current validator. Tests don't cover this because JSON always parses as float. Add only if a non-JSON config-construction path is added in future.

**Cost**: ~20 minutes for the 3 worth-adding tests (EC-1, EC-2, EC-4). EC-5 not worth a test until a non-JSON construction path exists.

### D. Diagnostic message content gaps (qa-tester GAP-1, UP-1, UP-2)

GdUnit4 v6.1.2 provides no hook for `push_error`/`push_warning` capture. The story spec requires diagnostic messages to mention specific keywords ("MOUNTAIN" or "missing terrain_modifiers key 3" for AC-4; "non-integral" or "fractional" for AC-5; "out of range" for AC-6). The current implementation emits "missing terrain_modifiers key '3'" (the integer-string key) — a designer-facing diagnostic that conveys the missing key but does NOT include the human label "MOUNTAIN".

**Resolution paths**:
- Option A (no change): accept that designer-facing diagnostic messages are out of automated coverage; rely on manual log review.
- Option B (improvement): in `_validate_config`, build a `KEY_LABELS = {"0": "PLAINS", "1": "FOREST", ...}` lookup so missing-key errors mention both the integer key AND the human label. ~10 LoC. Improves designer experience but does not change correctness.
- Option C (framework upgrade): contribute a log-capture hook to GdUnit4 upstream. Out of scope.

**Cost (Option B)**: ~15 minutes. **Benefit**: better designer diagnostics for missing-key errors. Defer until a designer reports an actual debugging-friction incident.

### E. Cosmetic style consistency (gdscript-specialist S-4)

Missing blank line at `terrain_effect.gd:390` between `_apply_config` body and `_fall_back_to_defaults` doc comment. Pure cosmetic; no parser impact.

**Cost**: 30 seconds. **Benefit**: zero (cosmetic only). Bundle into any future edit of this file.

### F. Unknown terrain_type safety-net test (story-004 /code-review qa-tester R-3 / GAP-1)

`terrain_effect.gd` `get_terrain_modifiers()` has a safety-net branch `if entry == null: return TerrainModifiers.new()` (~line 501) that catches the case where `_terrain_table` lacks the queried `terrain_type`. AC-2 of story-004 covers terrain types 0-7, but a query with `terrain_type=99` cannot reach the test path because `_make_grid(0, 0, 99, 0)` would fail `MapGrid.load_map` validation before the query runs. The internal safety net at line 501 is therefore untested in isolation.

**Risk**: a future refactor that removes or short-circuits this branch (e.g., assuming `_terrain_table` is always complete) would not be caught by any current test.

**Proposed remediation**: a test that bypasses the natural production path:
```gdscript
func test_terrain_effect_queries_unknown_terrain_type_returns_zero_fill() -> void:
    var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
    var grid: MapGrid = _make_grid(0, 0, TerrainEffect.PLAINS, 0)
    # Force lazy-init via a probe call, then mutate _terrain_table to empty
    TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))
    script.set("_terrain_table", {})
    # Query a coord whose terrain_type is now unknown
    var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))
    assert_int(m.defense_bonus).is_equal(0)
    assert_int(m.evasion_bonus).is_equal(0)
    assert_int(m.special_rules.size()).is_equal(0)
    grid.free()
```

**Cost**: ~10 minutes. **Benefit**: closes the safety-net coverage gap; protects against silent removal of defensive code.

### G. RIVER and ROAD as defender untested in story-005 (story-005 /code-review qa-tester F8)

`tests/unit/core/terrain_effect_combat_modifiers_test.gd` covers FORTRESS_WALL, FOREST, PLAINS, BRIDGE, HILLS, MOUNTAIN as defender across the 14 ACs. RIVER (terrain_type=4) and ROAD (terrain_type=7) — both with `defense_bonus=0`, `evasion_bonus=0`, `special_rules=[]` — are never the defender tile in any combat-modifiers test.

**Risk**: low — story-004 AC-2's 8-terrain canonical sweep over the shared `_terrain_table` would catch a misimplemented RIVER/ROAD entry. A wrong RIVER/ROAD `defense_bonus` value would propagate to `defender_terrain_def` in `get_combat_modifiers` identically to PLAINS, but would also fail the story-004 sweep first. Coupled coverage, not direct.

**Proposed remediation**: extend AC-12's contract-gate sweep with RIVER and ROAD scenarios:
```gdscript
# Scenario (d): RIVER defender (terrain_type=4)
var grid_d: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.RIVER, 0)
# ... (assert defender_terrain_def == 0, _eva == 0, gate)
# Scenario (e): ROAD defender (terrain_type=7)
var grid_e: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.ROAD, 0)
# ... (assert defender_terrain_def == 0, _eva == 0, gate)
```

**Cost**: ~10 minutes. **Benefit**: direct value-assertion for the 2 currently-uncovered terrain types in `get_combat_modifiers`; closes the "transitive coverage only" gap.

### H. `_elevation_table[delta=0]` row untested directly (story-005 /code-review qa-tester F9)

The elevation table's `delta=0` row (both `attack_mod=0` and `defense_mod=0`) is never exercised by any story-005 test. delta=+1, +2, -2 are covered by AC-1/AC-2/AC-3/AC-8. delta=-1 is implicitly used in AC-3 and AC-8 (HILLS scenarios). delta=0 (atk and def at same elevation) requires both attacker and defender at the same elev, which is awkward given ELEVATION_RANGES locks most terrain types to a single elev value.

**Risk**: low — story-003 owns elevation-table population and validates schema completeness; a wrong delta=0 entry would be caught by `_validate_config` if it produced fractional values, but a wrong-but-valid value (e.g. `attack_mod: 5` instead of `0`) would slip past validation.

**Proposed remediation**: a test using `_make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.PLAINS, 0)` (both at elev=0, delta=0):
```gdscript
func test_terrain_effect_combat_modifiers_zero_elevation_delta_yields_zero_modifiers() -> void:
    var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.PLAINS, 0)
    var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(grid, Vector2i(0,0), Vector2i(1,0))
    assert_int(cm.elevation_atk_mod).is_equal(0)
    assert_int(cm.elevation_def_mod).is_equal(0)
    grid.free()
```

**Cost**: ~5 minutes. **Benefit**: direct assertion of the delta=0 row, closing the elevation-table coverage matrix.

### I. `get_terrain_score` redundant lazy-load guard (story-005 /code-review gdscript-specialist OOS-2)

`get_terrain_score` (story-004 code at `terrain_effect.gd:619-625`) calls `get_terrain_modifiers(grid, coord)` which itself has a `if not _config_loaded: load_config()` guard. The guard at the top of `get_terrain_score` is therefore redundant — it fires, then `get_terrain_modifiers` also fires its guard, but the second is a no-op since `_config_loaded` is now true.

**Risk**: zero — purely cosmetic. The redundant guard adds ~1 branch instruction per call (negligible for an AC-21 0.1ms budget with 5-10× headroom).

**Proposed remediation**: delete the redundant guard:
```gdscript
# Before:
static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float:
    if not _config_loaded:
        load_config()
    var mods: TerrainModifiers = get_terrain_modifiers(grid, coord)
    return (mods.defense_bonus + mods.evasion_bonus * _evasion_weight) / _max_possible_score

# After:
static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float:
    var mods: TerrainModifiers = get_terrain_modifiers(grid, coord)  # lazy-loads internally
    return (mods.defense_bonus + mods.evasion_bonus * _evasion_weight) / _max_possible_score
```

**Cost**: 30 seconds + re-run regression (262 → 262 expected, no behavior change). **Benefit**: removes 2 redundant lines; tightens the public API surface to "lazy-load is owned by `get_terrain_modifiers`, all other queries inherit transitively". Defer to story-004 follow-up or any edit pass that touches this file.

### J. AC-6 expected reachable tile count not pinned (story-006 /code-review qa-tester F-2)

`tests/integration/core/terrain_cost_migration_test.gd` AC-6 (`test_terrain_cost_migration_smoke_path_via_terrain_cost`) asserts `result.size() > 1` (now `assert_int(...).is_greater(1)` after inline fix) for `MapGrid.get_movement_range(unit_id, 3, 0)` on the deterministic 15×15 mixed-terrain fixture. The boundary-correctness assertions at (5,7) HILLS positive and (7,4) PLAINS negative do catch the primary regression case (cost-multiplier returning a wrong constant value through the delegate path), but an implementation that reaches *too many* tiles (e.g., HILLS treated as cost=1 instead of cost=15 due to a multiplier-vs-base-cost bug) would still pass all current assertions while being incorrect.

**Risk**: medium — the gap matters most when ADR-0009 lands and per-class cost matrix values become non-uniform. A bug like "Cavalry MOUNTAIN cost multiplier=2 not applied" could silently expand the reachable set on a Cavalry-test fixture.

**Proposed remediation**: compute the analytically-expected reachable tile count for the 15×15 PLAINS/HILLS-band/FOREST-strip layout with budget=30 and pin it as a constant. Either compute by hand (Dijkstra walk on paper) or run once with a known-good build and pin the result:
```gdscript
const AC6_EXPECTED_REACHABLE_TILES: int = 13   # placeholder — recompute and pin

assert_int(result.size()).override_failure_message(
    ("AC-6: expected %d reachable tiles for budget=30 on the AC-6 fixture; got %d. "
    + "If terrain costs changed, recompute the constant and update.")
    % [AC6_EXPECTED_REACHABLE_TILES, result.size()]
).is_equal(AC6_EXPECTED_REACHABLE_TILES)
```

**Cost**: ~15 minutes (compute count + pin + re-run). **Benefit**: deterministic regression guard against over-counting bugs that the boundary assertions miss.

**Suggested trigger**: when ADR-0009 cost-matrix population work begins — at that point per-class non-uniform values make over-counting bugs much more likely.

### K. ADR-0008 §Risks line 567 `before_each()` reference is stale (G-15) (story-006 /code-review gdscript-specialist OOS-1)

`docs/architecture/ADR-0008-terrain-effect.md` §Risks table at line 567 says: "All test suites that call any TerrainEffect method MUST call `reset_for_tests()` in `before_each()` — NOT just suites that call `load_config()`...". The implementation and tests correctly use `before_test()` (G-15-canonical hook); the `before_each()` reference in the ADR text is stale documentation from before G-15 was codified. No runtime impact — the ADR's *intent* (call reset unconditionally) is correctly observed by all test files.

**Risk**: low — documentation-only. A future engineer reading the ADR before reading the codified G-15 rule could try to add a `before_each()` and be silently-skipped per G-15.

**Proposed remediation**: a one-line edit in ADR-0008 §Risks line 567: `before_each()` → `before_test()`. Add a parenthetical "(canonical GdUnit4 v6.1.2 hook; see `.claude/rules/godot-4x-gotchas.md` G-15)".

**Cost**: 1 minute. **Benefit**: removes stale doc reference; aligns ADR text with codified rules. Safe — an ADR edit that does not change architectural decisions, only corrects a phrasing artifact.

**Suggested trigger**: bundle into the next ADR-0008 amendment (e.g., when ADR-0006 Balance/Data lands and Migration Plan triggers, or when ADR-0009 cost-matrix population requires a §Migration Plan addendum).

---

**Total estimated remediation effort**: ~2 hours 31 minutes total (across A-K).

**Suggested trigger**: at the end of the terrain-effect epic (story-008 perf baseline), bundle A (validator split), B (fixture DRY), C (advisory edge tests), F (unknown terrain_type safety-net), G (RIVER/ROAD direct), H (delta=0 direct) into a single test infrastructure hardening pass. D (diagnostic labels), E (cosmetic), I (redundant guard), J (AC-6 count pin), and K (ADR-0008 §Risks doc-fix) stay deferred until separate triggers (J trigger: ADR-0009; K trigger: next ADR-0008 amendment).

**Story-004 carry-over (RESOLVED 2026-04-26)**: qa-tester GAP-4 / R-6 was the carry-over from story-003 — fallback exact-value correctness must be a BLOCKING requirement in story-004's `get_terrain_modifiers()` tests. **CONFIRMED SATISFIED** by story-004 AC-2 (lines 183-224 of `terrain_effect_queries_test.gd`): explicit per-terrain `defense_bonus`, `evasion_bonus`, and `special_rules.size()` assertions for all 8 terrain types. A `_fall_back_to_defaults()` typo of HILLS=10 instead of 15 would fail at line 203.

**Cross-references**:
- Story (origin): `production/epics/terrain-effect/story-003-config-loading-validation.md`
- Story-004 carry-over (RESOLVED): `production/epics/terrain-effect/story-004-terrain-modifiers-score-queries.md`
- Story-005 carry-overs (§G/§H/§I): `production/epics/terrain-effect/story-005-combat-modifiers-elevation-clamp-bridge.md`
- Story-006 carry-overs (§J/§K): `production/epics/terrain-effect/story-006-cost-multiplier-mapgrid-migration.md`
- Reviews:
  - Story-003: standalone `/code-review` 2026-04-25 (gdscript APPROVED WITH SUGGESTIONS + qa-tester TESTABLE WITH GAPS — 14 findings; 7 inline-applied; 7 deferred §A-§E)
  - Story-004: standalone `/code-review` 2026-04-26 (gdscript APPROVED WITH SUGGESTIONS + qa-tester TESTABLE WITH GAPS — 7 findings; 4 inline-applied; 1 deferred §F; 2 false positives skipped)
  - Story-005: standalone `/code-review` 2026-04-26 (gdscript APPROVED WITH SUGGESTIONS + qa-tester TESTABLE WITH GAPS — 7 actionable + 4 advisory; 6 inline-applied; 3 deferred §G/§H/§I; 1 false positive skipped)
  - Story-006: standalone `/code-review` 2026-04-26 (gdscript APPROVED WITH SUGGESTIONS + qa-tester TESTABLE WITH GAPS — 11 findings; 6 inline-applied; 2 deferred §J/§K)
- Inline improvements applied across stories: 7 (story-003) + 4 (story-004) + 6 (story-005) + 6 (story-006) = 23 total
- New gotcha codified: G-15 (`before_each` phantom hook) in `.claude/rules/godot-4x-gotchas.md` (story-003)
- Completions: session extracts in `production/session-state/active.md` §/story-done 2026-04-25 (story-003), §/story-done 2026-04-26 (story-004), §/story-done 2026-04-26 (story-005), §/story-done 2026-04-26 (story-006 pending)

---

## TD-035 — `save_perf_test.gd` catastrophic-threshold flakes on shared CI runners (SKIP_PERF_BUDGETS not honored)

**Status**: Open
**Severity**: Medium (false-positive CI failures block PRs unrelated to save-perf)
**Discovered**: 2026-04-26 — terrain-effect/story-008 PR #43 first attempt
**Effort**: ~15 min for either fix
**Story (incidental discovery)**: `production/epics/terrain-effect/story-008-perf-baseline.md` (the PR that triggered the flake — save-perf flake is unrelated to terrain-effect content)

### Problem

`tests/integration/core/save_perf_test.gd::test_save_perf_full_cycle_p95_under_desktop_budget_advisory` fires a `BLOCKING` assert at line 162 when desktop p95 ≥ 100ms (catastrophic threshold). On shared GitHub Actions ubuntu-latest runners, this assertion flakes due to file-I/O long-tail variance even when steady-state mean is well under budget.

**Observed flake on PR #43 attempt 1 (2026-04-25T19:43:33Z)**:
- p95 = 133.25ms (catastrophic threshold = 100ms → FAIL)
- mean = 13.35ms (well under 20ms advisory)
- max = 237.04ms (long-tail outlier)
- per-stage breakdown ALL fast: `duplicate_deep=0.066ms ResourceSaver.save=0.206ms rename_absolute=0.076ms`
- attempt 2 (rerun, no code change) = SUCCESS

The failing iteration's outlier was a single I/O long-tail event from runner contention or disk-cache miss; nothing in the actual save-system code regressed.

### Root cause

The CI workflow sets `SKIP_PERF_BUDGETS=1` env var (verified in PR #43 CI logs at `2026-04-25T19:42:59.5803115Z` step config). However, `save_perf_test.gd:162` does NOT check this env var — it asserts unconditionally. The env var is therefore non-functional for the catastrophic-threshold path.

### Affected files

- `tests/integration/core/save_perf_test.gd:162` — catastrophic `assert_int(p95).is_less(100_000)` (or similar) — line ref from CI report; needs verification at fix time
- Possibly other `assert_*` calls in the same file that should respect `SKIP_PERF_BUDGETS=1`

### Why it matters

This blocks PRs unrelated to save-perf (PR #43 was a terrain-effect story; the failure was orthogonal to its diff). Every PR that lands while this flakes carries a 15-30min triage tax (was it a real save-perf regression? requires log inspection to rule out). At ~1 PR per day cadence and ~10% flake rate (rough estimate from 1/9 recent runs), that's ~1.5h/month of unproductive triage.

### Proposed fix (pick one)

**Option A — Honor `SKIP_PERF_BUDGETS=1` env var at line 162** (preferred; cheapest):

```gdscript
# Wrap the catastrophic assert
if OS.get_environment("SKIP_PERF_BUDGETS") != "1":
    assert_int(p95_ms).override_failure_message(
        "AC-DESKTOP catastrophic: p95=%.2fms >= 100ms — regression severe enough that mobile cannot plausibly hit V-11. Investigate immediately." % p95_ms
    ).is_less(100)
else:
    print("[save AC-DESKTOP] SKIP_PERF_BUDGETS=1 set — catastrophic assert skipped (CI/shared-runner mode). p95=%.2fms" % p95_ms)
```

The advisory `push_warning` at the 20ms threshold should remain unconditional (it's print-only; doesn't fail CI).

**Option B — Loosen the catastrophic threshold for CI**:

Bump from 100ms to 250ms so file-I/O long-tails don't cause flakes. Steady-state regression detection still works because the advisory threshold (20ms) catches mean-degradation cases via push_warning.

**Recommend Option A** — it preserves the ability to detect a true regression on local dev hardware (where the SKIP env var is not set), while killing the CI-shared-runner false-positive class entirely. Option B drops the catastrophic-detection signal for everyone, not just CI.

### Cross-system impact

- `tests/integration/core/map_grid_perf_test.gd` and `tests/integration/core/terrain_effect_perf_test.gd` use TIGHTER per-call budgets (100µs, not 100ms) and have NOT exhibited this flake — they measure CPU-bound code, not I/O. The catastrophic-threshold pattern is appropriate for them. Save-perf is the outlier because it touches disk.
- If Option A is adopted, the `SKIP_PERF_BUDGETS=1` env var becomes a project-wide convention that catastrophic asserts in I/O-bound perf tests should respect. Worth documenting in `.claude/rules/test-standards.md` so future perf tests follow the pattern.

### Workaround until fixed

When PR CI fails on this test, re-run the failing job (`gh run rerun --failed --job=<id>`). Expected to pass on retry.

### Cross-references

- PR #43 CI logs (failed attempt 1, succeeded attempt 2): https://github.com/forty4/Claude-Code-Game-Studios/actions/runs/24939085309
- Test source (line ref from CI report — verify at fix time): `tests/integration/core/save_perf_test.gd:162`
- Workflow env var setting: `.github/workflows/<test-workflow>.yml` `SKIP_PERF_BUDGETS: 1`
- Related: G-7 (GdUnit4 silent "no tests" on parse-failed scripts) — different problem, but reminds us that exit code alone is not sufficient signal for CI test runs.

