# Story 003: signal_contract_test — ADR table → code drift gate

> **Epic**: gamebus
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3h — actual ~1h (specialist single-pass + /code-review Option A fix-up round)

## Context

**GDD**: — (infrastructure; regression gate for ADR-0001 §Signal Contract Schema)
**Requirement**: `TR-gamebus-001`

**ADR Governing Implementation**: ADR-0001 — §Migration Plan §5, §Validation Criteria V-2
**ADR Decision Summary**: "Implement `signal_contract_test.gd` in CI — parses this ADR's schema table and asserts GameBus declares every listed signal with matching typed signature. Blocks merges on drift."

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Uses `Node.get_signal_list() -> Array[Dictionary]` (pre-cutoff stable API). Each dict contains `name`, `args` (array of `{name, type, usage}`).

**Control Manifest Rules (Platform layer)**:
- Required: Every signal in ADR-0001 §Signal Contract Schema table declared on GameBus with matching typed signature
- Required: Test deterministic, no random seeds, no time-dependent assertions
- Required: CI blocks merge on test failure

## Acceptance Criteria

*Derived from ADR-0001 §Validation Criteria V-2 + §Migration Plan §5 + §Risks mitigation (signal-contract drift):*

- [ ] `tests/unit/core/signal_contract_test.gd` — GdUnit4 test class
- [ ] Test maintains a **hardcoded reference list** of the 27 signals matching ADR-0001 §Signal Contract Schema (rationale: parsing the ADR markdown table at test time introduces markdown-format coupling — a hardcoded reference list is simpler and forces any ADR change to be reflected in both the ADR + the test, providing dual-gate discipline)
- [ ] Test asserts: every signal in reference list exists on `/root/GameBus` with matching name
- [ ] Test asserts: each signal's arg types match the reference list (including Resource subclass types for typed payloads)
- [ ] Test asserts: no EXTRA signals exist on GameBus beyond the 27 (prevents silent additions bypassing ADR)
- [ ] Reference list includes comment linking each signal to ADR-0001 §Signal Contract Schema domain heading + table row
- [ ] Test-file header docstring explains dual-gate discipline: "changes to ADR-0001 signal schema MUST be reflected here in the same PR"
- [ ] Test runs as part of CI (`godot --headless --script tests/gdunit4_runner.gd`); FAIL blocks merge

## Implementation Notes

*From ADR-0001 §Migration Plan + §Evolution Rule §1 amendment discipline:*

1. **Reference list format** — Array of Dictionary entries:
   ```gdscript
   const EXPECTED_SIGNALS: Array[Dictionary] = [
       { "name": "chapter_started", "args": [{"name": "chapter_id", "type": TYPE_STRING}, {"name": "chapter_number", "type": TYPE_INT}] },
       { "name": "battle_outcome_resolved", "args": [{"name": "outcome", "type": TYPE_OBJECT, "class_name": "BattleOutcome"}] },
       # ... 27 entries
   ]
   ```
2. **Type checking**: Godot's `get_signal_list()` returns arg type info. For primitives, check `TYPE_STRING` / `TYPE_INT` / `TYPE_VECTOR2I` etc. For Resource types, the class_name comparison requires additional inspection via `arg.class_name` field (introduced 4.2+).
3. **No markdown parsing** — do NOT attempt to read `docs/architecture/ADR-0001-gamebus-autoload.md` and parse the table. Brittle against ADR formatting changes. The hardcoded list is intentional.
4. **Error messages must be actionable** — on drift: "Signal `X` declared in ADR but missing on GameBus" OR "Signal `Y` on GameBus not in ADR reference list — either add to ADR or remove from GameBus". Guides developer to the correct resolution path.
5. **ADR evolution sync rule** — per ADR-0001 §Evolution Rule §1: "Add a new signal" is a minor amendment (no supersession); author must (a) edit ADR-0001 schema table, (b) add signal to GameBus, (c) update this test's reference list. All three in one PR. The test is the forcing function for discipline (c).

## Out of Scope

- **Story 002**: Autoload declaration itself (tested by this story's results)
- **Story 004**: Payload serialization round-trip (different concern — this story tests signal *shape* not payload *serializability*)
- **Future**: adding the 4 PROVISIONAL signals' payloads — this story's reference list already includes them (with placeholder class_name), and PROVISIONAL → locked transitions are covered by ADR amendment process, not a new test

## QA Test Cases

*Inline QA specification.*

**Test file**: `tests/unit/core/signal_contract_test.gd`

- **AC-1** (signal count):
  - Given: GameBus loaded at `/root/GameBus`
  - When: `var user_signals = _get_user_signals(GameBus)` (helper filters out inherited Node signals)
  - Then: `user_signals.size() == EXPECTED_SIGNALS.size()` (== 27)
  - Edge: if mismatch, fail with message listing extras and missing

- **AC-2** (signal name coverage):
  - Given: user-declared signals on GameBus + EXPECTED_SIGNALS reference list
  - When: for each entry in EXPECTED_SIGNALS, search GameBus signal list for matching name
  - Then: every expected signal found; every GameBus signal accounted for in expected list
  - Edge: fail message: "Missing: [name1, name2]" or "Extra: [name3]"

- **AC-3** (signal arg type matching):
  - Given: matched signal pair (expected vs actual)
  - When: iterate args in both and compare `type` (int enum) + arg count
  - Then: arg count matches; each arg's `type` matches expected
  - Edge: for `TYPE_OBJECT` args, compare `class_name` strings (e.g. `"BattleOutcome"` for `battle_outcome_resolved`)

- **AC-4** (no silent additions):
  - Given: developer adds `signal rogue_signal(x: int)` to GameBus without updating EXPECTED_SIGNALS
  - When: test runs in CI
  - Then: FAIL with "Extra signal on GameBus not in reference list: rogue_signal"
  - Edge: CI build blocked from merge

- **AC-5** (drift detection on rename):
  - Given: someone renames `battle_outcome_resolved` → `combat_outcome_resolved` in GameBus only
  - When: test runs
  - Then: FAIL with "Missing: battle_outcome_resolved; Extra: combat_outcome_resolved"
  - Guide: developer must either revert GameBus OR update ADR-0001 per §Evolution Rule §2 (rename = breaking change, supersession required)

- **AC-6** (deterministic):
  - Given: 10 consecutive runs
  - Then: identical pass/fail result each time; no flakiness

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/core/signal_contract_test.gd` — must exist and pass in CI
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 002 (GameBus autoload must exist); Story 001 (payload class_names must exist for type assertions)
- **Unlocks**: dual-gate discipline for all future ADR-0001 amendments (new signals, payload shape locks)

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 8/8 story ACs passing + 6/6 QA test cases passing (24/24 full unit suite green in ~236ms)
**Verdict**: COMPLETE WITH NOTES

**Test Evidence**: `tests/unit/core/signal_contract_test.gd` — 6 GdUnit4 test functions (AC-1..AC-6), 540 LOC, Integration gate BLOCKING satisfied

**Code Review**: Complete — `/code-review` initial verdict **APPROVED WITH SUGGESTIONS** (2 WARNINGS: W-1 Array typing demotion via `.duplicate()`, W-2 loop-var `name` shadowing `Node.name`). Option A fixes applied (W-1 → `.assign()`; W-2 → rename to `sig_name` at 7 sites). Final verdict: **APPROVED**.

**Files delivered** (all in-scope, zero src/ changes):
- `tests/unit/core/signal_contract_test.gd` (+ `.uid` sidecar) — 27-entry EXPECTED_SIGNALS hardcoded reference list × 10 domain banners + 2 helpers + 6 test functions
- Dual-gate discipline docstring (lines 3-37) explains PURPOSE / DUAL-GATE DISCIPLINE / HOW TO ADD A SIGNAL / load()-vs-autoload tradeoff

**Mid-flight corrections** (in-session, user-approved via Option A):
1. **W-1 static typing preservation** — `first_names = names.duplicate()` demotes `Array[String]` to untyped `Array` in Godot 4.6 (typed-array annotation is not propagated through `duplicate()`). Replaced with `first_names.assign(names)` to preserve the static type.
2. **W-2 loop variable shadowing** — 7 occurrences of `for name: String in ...` shadowed `Node.name` (GdUnitTestSuite extends Node). Renamed to `sig_name` throughout — avoids `unsafe_shadowing` lint noise.

**Deviations**: None (all 8 ACs on-spec; no out-of-scope changes; manifest version match; all ADR-0001 cross-references verified).

**Advisory follow-ups** (logged to `docs/tech-debt-register.md`):
- **TD-008** — EXPECTED_SIGNALS transcription risk: no automated second gate on ADR↔EXPECTED_SIGNALS↔game_bus.gd three-way correspondence. If a signal is transcribed incorrectly and the same error lands in both EXPECTED_SIGNALS and game_bus.gd, all tests pass while both files diverge from the ADR. Mitigation: add PR checklist item requiring three-way sign-off.
- **TD-009** — Autoload boot path not exercised: both this test and story-002's use `load()` + `script.new()`. A malformed `project.godot` autoload registration would pass all tests while `/root/GameBus` fails to mount at runtime. Mitigation: dedicated live-tree smoke test in a future story using `get_tree().root.get_node_or_null("GameBus")`.

**Gates skipped** (review-mode=lean): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates. Standalone `/code-review` ran with full gdscript-specialist + qa-tester — findings captured above, Option A fix cycle applied and verified green.
