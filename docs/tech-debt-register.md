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
