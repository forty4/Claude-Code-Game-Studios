# Story 001: DestinyBranchJudge full F-DB-1 implementation + 3 lints + V-12 thread-safety + 5-platform serialization scaffold

> **Epic**: destiny-branch
> **Status**: Complete (2026-05-05 — single coordinated patch; 943/943 tests + 3/3 lints PASS; REPLACE stub bodies per Decision A)
> **Layer**: Core
> **Type**: Logic (F-DB-1 algorithm + F-DB-3 invariant_violation vocabulary + F-DB-2 derivation are pure-function logic) + Integration (V-12 thread-safety + 5-platform serialization round-trip + 3 lint scripts)
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md`)
> **Sprint Slot**: S7-03 (sprint-7 critical path; 0.5d nominal estimate per sprint-7 plan; depends on S7-02)
> **Epic-terminal**: Yes — closes destiny-branch epic at story completion

## Context

**GDD**: `design/gdd/destiny-branch.md` rev 1.3.2 (43 ACs total per v1.3 rollup; story scoped to ~13 ACs covering F-DB-1 worked examples E1-E6 + F-DB-3 12-entry invariant_violation vocabulary + F-DB-2 derivation + V-12 thread-safety + AC-DB-24 serialization scaffold)

**Requirements**: `TR-destiny-branch-001..015` (all 15 — per epic terminal scope; tr-registry.yaml v15)

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0018 Destiny Branch (Accepted 2026-05-04 via /architecture-review delta #13)

**ADR Decision Summary**: DestinyBranchJudge RefCounted pure-function transient class + @abstract test seam (1st @abstract pattern in project) + 4-arg resolve() signature (3rd ratification widening at upstream-ADR acceptance) + 9-field DestinyBranchChoice typed Resource (ratifies ADR-0001 5-field PROVISIONAL via Evolution Rule #4 minor amendment delta #13) + 12-entry F-DB-3 invariant_violation:* StringName vocabulary + DefaultDestinyBranchJudge production subclass + invalid() factory + F-DB-2 reserved_color_treatment derivation (CR-DB-9 + canonical_branch_key field-name reconciliation) + Pillar 4 is_canonical_history payload-level enforcement + determinism invariant (lint-enforced via 3 forbidden_patterns) + EC-DB-17 thread-safety BY CONSTRUCTION + 5-platform ResourceSaver/ResourceLoader round-trip per OQ-DB-6.

**Engine**: Godot 4.6 | **Risk**: HIGH (Godot 4.5+ @abstract annotation + parameterless `Resource.duplicate_deep()` per breaking-changes.md 4.4→4.5 + typed-Resource @export of typed enum values + StringName field-type preservation through ResourceSaver/ResourceLoader on 5 export targets per AC-DB-24 + IN-1 — last item flagged as BLOCKING for VS close per OQ-DB-6)

**Engine Notes**: `@abstract func _apply_f_sp_1(...)` annotation per Godot 4.5+ G-22 parse-time enforcement on typed references; verification uses structural source-file assertion pattern per V-5 (`FileAccess.get_file_as_string()` + `assert_bool(content.contains("@abstract")).is_true()` + `func _apply_f_sp_1` containment check; reflective `load(path).new()` runtime-failure expectation REJECTED per G-22 — bypasses parse-time check). Pre-4.5 emulation pattern (`assert(false, "must override")`) REJECTED per current-best-practices.md typed-priority. Parameterless `Resource.duplicate_deep()` form per breaking-changes.md 4.4→4.5 (NOT `Resource.duplicate(true)` per deprecated-apis.md). `BattleOutcome` MUST be top-level `class_name` per cross-doc constraint (SATISFIED in shipped `src/core/payloads/battle_outcome.gd:10` per godot-specialist 16th-invocation N-4 verification). 5-platform CI matrix (Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan) — Linux Editor + Windows D3D12 lanes are CI-active per existing GdUnit4 setup; macOS / iOS / Android lanes are manual-test fallback for sprint-7 per R-3 mitigation; full 5-platform CI deferred to release-prep sprint.

**Control Manifest Rules (Core layer + Destiny Branch domain)**:
- **Required**: `class_name DestinyBranchJudge extends RefCounted` per Alternative §1/§2/§3 rejection (Autoload + Node + static utility forms all rejected). `@abstract func _apply_f_sp_1` test seam declared on base class. `class_name DefaultDestinyBranchJudge extends DestinyBranchJudge` production subclass overrides `_apply_f_sp_1` to delegate to `ScenarioFormulas.resolve_branch(...)` (ADR-0017 owned F-SP-1 authoritative implementation). Test stub `class_name TestDestinyBranchJudgeWithSp1Stub extends DestinyBranchJudge` lives in `tests/helpers/destiny_branch_judge_stub.gd` with instance-level `_stub_output` Dictionary (NO static var per `destiny_branch_judge_static_var` forbidden_pattern — lint scan-set explicitly covers test stub per godot-specialist 15th-invocation advisory C-3).
- **Forbidden**: `static var` ANYWHERE in DestinyBranchJudge class hierarchy (production + test stub + future subclass discovery; lint-enforced via `destiny_branch_judge_static_var`). GameBus signal emission from DestinyBranchJudge (lint-enforced via `destiny_branch_judge_emits_gamebus_signal`; emission ownership lives in ScenarioRunner per CR-DB-4). Reading ScenarioRunner state (`ScenarioRunner.<member>` / `_scenario_state.<field>` / autoload state-read patterns; lint-enforced via `destiny_branch_judge_reads_scenario_runner_state` **Pillar 2 architectural lock 3rd precedent** — judge MUST receive `first_attempt_resolved` as 4th argument, NOT read from autoload).
- **Guardrail**: Determinism BY CONSTRUCTION — identical `(chapter, outcome, echo_count, first_attempt_resolved)` inputs MUST produce field-identical 9-field DestinyBranchChoice output across (a) repeated calls on same instance; (b) calls on independently-constructed instances; (c) concurrent calls on separate WorkerThreadPool tasks per V-12. NO RNG / NO wall-clock dependency / NO external state read / NO instance-level state across calls / NO class-level state.

---

## Acceptance Criteria

*From GDD `design/gdd/destiny-branch.md` §AC-DB-01..AC-DB-43; story scoped to ~13 ACs covering F-DB-1 worked examples + F-DB-3 vocabulary + F-DB-2 derivation + V-12 thread-safety + AC-DB-24 serialization. ADVISORY ACs deferred per Out of Scope below.*

### F-DB-1 worked examples (AC-DB-01..06)

- [ ] **AC-DB-01** (E1 Ch1 WIN default) — Given a Ch1 chapter fixture with `chapter_id="ch1"`, `default_branch_key="WIN_ch1_default"`, no `echo_threshold`, and a valid `branch_table`, when `DestinyBranchJudge.new().resolve(chapter, WIN, 0, true)` is called, then the returned `DestinyBranchChoice` has `chapter_id="ch1"`, `branch_key="WIN_ch1_default"`, `outcome=WIN`, `echo_count=0`, `is_draw_fallback=false`, `reserved_color_treatment=false`, `is_invalid=false`, `invalid_reason=&""`. (NOTE: 4th arg `first_attempt_resolved` per ADR-0017 line 200 + delta #13 ratification — Ch1 first-attempt scenarios use `true`)
- [ ] **AC-DB-02** (E2 Ch3 DRAW default) — Given a Ch3 chapter fixture with `author_draw_branch=true`, `echo_threshold=1`, `default_branch_key="WIN_ch3_default"`, and a DRAW branch row `"DRAW_ch3_default"`, when `resolve(chapter, DRAW, 0, true)` is called, then the returned `DestinyBranchChoice` has `branch_key="DRAW_ch3_default"`, `is_draw_fallback=false`, `reserved_color_treatment=true`, `is_invalid=false`.
- [ ] **AC-DB-03** (E3 Ch3 DRAW echo-gated — Pillar 2 observable) — Given the same Ch3 fixture as AC-DB-02, when `resolve(chapter, DRAW, 1, false)` is called (echo_count=1 + first_attempt_resolved=false because retried), then the returned `DestinyBranchChoice.branch_key == "DRAW_ch3_echo"` — DISTINCT from AC-DB-02's `"DRAW_ch3_default"` branch_key. Additionally `reserved_color_treatment=true`, `is_invalid=false`.
- [ ] **AC-DB-04** (E4 Ch2 DRAW fallback) — Given a Ch2 chapter fixture with `author_draw_branch=false`, `default_branch_key="WIN_ch2_default"`, when `resolve(chapter, DRAW, 0, true)` is called, then the returned `DestinyBranchChoice` has `branch_key="WIN_ch2_default"`, `is_draw_fallback=true`, `reserved_color_treatment=false`, `outcome=DRAW`, `is_invalid=false`.
- [ ] **AC-DB-05** (E5 null chapter) — Given `chapter=null`, when `resolve(null, WIN, 0, true)` is called, then the returned `DestinyBranchChoice` has `is_invalid=true`, `invalid_reason=&"invariant_violation:chapter_null"`, `reserved_color_treatment=false`, all narrative fields (chapter_id, branch_key) at default empty values.
- [ ] **AC-DB-06** (E6 CR-13 runtime violation) — Given a Ch1 chapter fixture that has `echo_threshold=1` set (authoring-validator bug), when `resolve(chapter, DRAW, 1, false)` is called, then the returned `DestinyBranchChoice` has `is_invalid=true`, `invalid_reason=&"invariant_violation:cr13_echo_threshold_on_ch1"` AND `push_error` is emitted with a message containing the literal substring `"cr13_echo_threshold_on_ch1"` per AC-DB-20.

### CR-DB-2 / CR-DB-11 determinism (AC-DB-07)

- [ ] **AC-DB-07** (determinism) — Given a valid `ChapterDefinition` fixture and identical `(outcome, echo_count, first_attempt_resolved)` inputs, when `resolve()` is called twice (once on a first `DefaultDestinyBranchJudge` instance, once on a second independently-constructed instance), then the two returned `DestinyBranchChoice` objects are field-equal across all **9 `@export` fields**. Additionally, the judge source must contain no `Time.get_ticks_msec`, `Time.get_ticks_usec`, `randi`, `randf`, `randf_range`, `randi_range`, `Engine.get_*_frames`, `DisplayServer.window_*`, `OS.get_processor_count`, or `/root/*` autoload state-read patterns (verified via FileAccess source-scan).

### CR-DB-3 transient lifecycle (AC-DB-08)

- [ ] **AC-DB-08** (transient lifecycle) — Given a local-scope variable `var judge := DefaultDestinyBranchJudge.new()` and a `WeakRef` to it, when `judge.resolve(...)` is called and the local variable goes out of scope, then the `WeakRef.get_ref()` returns `null` on the next idle frame (no lingering reference from a signal connection, callable binding, or autoload).

### F-DB-2 derivation (AC-DB-14, 15)

- [ ] **AC-DB-14** (CR-DB-9 reserved_color_treatment positive case) — Given a `TestDestinyBranchJudgeWithSp1Stub` + a chapter fixture with `default_branch_key="WIN_ch3_default"` and stub configured `set_sp1_output({"branch_key": "DRAW_ch3_echo", "is_draw_fallback": false, "is_canonical_history": false})`, when `resolve(chapter, DRAW, 1, false)` is called, then `DestinyBranchChoice.reserved_color_treatment == true` AND `DestinyBranchChoice.is_invalid == false`.
- [ ] **AC-DB-15** (CR-DB-9 + F-DB-2 negative case when branch == default) — Given a `TestDestinyBranchJudgeWithSp1Stub` + a chapter fixture with `default_branch_key="WIN_ch2_default"` and stub configured `set_sp1_output({"branch_key": "WIN_ch2_default", "is_draw_fallback": false, "is_canonical_history": true})` (branch_key equals default), when `resolve(chapter, WIN, 0, true)` is called, then `DestinyBranchChoice.reserved_color_treatment == false`. Parameterized second row: stub `set_sp1_output({"branch_key": "WIN_ch2_default", "is_draw_fallback": true, "is_canonical_history": true})` with `resolve(chapter, DRAW, 0, true)` → same expected result (F-DB-2 step 4a fallback override).

### F-DB-3 12-entry invariant_violation vocabulary (AC-DB-16..20g)

- [ ] **AC-DB-16** (chapter_null) — `resolve(null, WIN, 0, true)` → `invalid_reason == &"invariant_violation:chapter_null"` (covered by AC-DB-05; explicit guard test)
- [ ] **AC-DB-17** (default_branch_key empty) — `chapter.default_branch_key=""` → `invalid_reason == &"invariant_violation:default_branch_key_missing"`
- [ ] **AC-DB-18** (branch_table missing outcome row) — chapter fixture whose `branch_table` is missing a row for the supplied outcome → `invalid_reason == &"invariant_violation:branch_table_missing_outcome"`
- [ ] **AC-DB-19** (outcome_unknown) — `outcome` integer value not ∈ {0, 1, 2} → `invalid_reason == &"invariant_violation:outcome_unknown"`
- [ ] **AC-DB-20** (cr13_echo_threshold_on_ch1) — covered by AC-DB-06; assert push_error literal substring `"cr13_echo_threshold_on_ch1"` per stdout-redirect helper (rev 1.3 D2 decision)
- [ ] **AC-DB-20a** (chapter_id empty) — `chapter.chapter_id=""` → `invalid_reason == &"invariant_violation:chapter_id_missing"`
- [ ] **AC-DB-20b** (branch_table null/malformed) — `chapter.branch_table = null` (or non-Dictionary type) → `invalid_reason == &"invariant_violation:branch_table_null_or_malformed"` AND the call does NOT crash into `_apply_f_sp_1` with a null-deref
- [ ] **AC-DB-20c** (branch_key non-String type via stub) — `TestDestinyBranchJudgeWithSp1Stub.set_sp1_output({"branch_key": 42, ...})` → `invalid_reason == &"invariant_violation:branch_key_type_invalid"`
- [ ] **AC-DB-20d** (is_draw_fallback non-bool type) — stub `{"is_draw_fallback": "false", ...}` (String "false" instead of bool false) → `invalid_reason == &"invariant_violation:is_draw_fallback_type_invalid"`. Parameterized with {null, 0, 1, "false", "true", []}
- [ ] **AC-DB-20e** (is_canonical_history non-bool type) — stub `{"is_canonical_history": "true", ...}` (String "true" instead of bool true) → `invalid_reason == &"invariant_violation:is_canonical_history_type_invalid"`. Parameterized matrix same as AC-DB-20d
- [ ] **AC-DB-20f** (empty-Dictionary branch_table) — `chapter.branch_table = {}` (empty Dictionary, passes null + Dictionary-type checks at F-DB-1 step 1) → `invalid_reason == &"invariant_violation:branch_table_empty"` AND the call does NOT reach `_apply_f_sp_1`. Distinguishes empty-table authoring error from F-SP-1-missing-row path of AC-DB-18.
- [ ] **AC-DB-20g** (is_draw_fallback + outcome mismatch) — stub `{"is_draw_fallback": true, ...}` AND parameterized outcome ∈ {WIN, LOSS} (NOT DRAW) → `invalid_reason == &"invariant_violation:is_draw_fallback_outcome_mismatch"`. Cross-field invariant; complementary positive case (`is_draw_fallback: true` with `outcome == DRAW`) produces valid payload (AC-DB-04).

### F-DB-4 invariants + closed vocabulary (AC-DB-21, 22, 23)

- [ ] **AC-DB-21** (F-DB-2 extended — reserved_color_treatment false when is_invalid=true) — Given any input that triggers `is_invalid=true` (all 12 vocabulary paths per F-DB-3 rev 1.3), when the returned `DestinyBranchChoice` is inspected, then `reserved_color_treatment == false` regardless of whether `branch_key` would satisfy the inequality.
- [ ] **AC-DB-22** (F-DB-4 invariant — is_draw_fallback ⟹ DRAW) — GdUnit4 parameterized test with explicit fixture set covering (a) Ch2 with `author_draw_branch=false` × outcome ∈ {WIN, DRAW, LOSS} × echo_count ∈ {0, 1}, and (b) Ch3 with `author_draw_branch=true` × outcome ∈ {WIN, DRAW, LOSS} × echo_count ∈ {0, 1} — 12 rows total; for every row where `is_draw_fallback == true`, the implication `outcome == DRAW` holds (never WIN, never LOSS). Additionally, lint via `lint_destiny_branch_judge_no_static_var.sh` extension OR new lint verifies no code path in `destiny_branch_judge.gd` sets `choice.is_draw_fallback = true` without `outcome == DRAW` in same function.
- [ ] **AC-DB-23** (F-DB-3 closed vocabulary) — Given a `DestinyBranchChoice` with `is_invalid=true`, when `invalid_reason` is inspected, then its StringName value is a member of the exact 12-element set: {chapter_null, chapter_id_missing, default_branch_key_missing, branch_table_null_or_malformed, branch_table_empty, branch_table_missing_outcome, branch_key_type_invalid, is_draw_fallback_type_invalid, is_canonical_history_type_invalid, is_draw_fallback_outcome_mismatch, outcome_unknown, cr13_echo_threshold_on_ch1}. Verify via parameterized test asserting StringName membership.

### V-12 thread-safety (EC-DB-17 BY CONSTRUCTION)

- [ ] **V-12 thread-safety integration test** — 2 simultaneous `DefaultDestinyBranchJudge.new()` instances on `WorkerThreadPool.add_task()` × 1000 concurrent calls each = 2000 returned `DestinyBranchChoice` objects field-identical to baseline. Closes EC-DB-17 thread-safety BY CONSTRUCTION via no-static-var + no-instance-state-across-calls + no-external-state-read invariants. Test at `tests/integration/destiny_branch/destiny_branch_judge_thread_safety_test.gd`.

### AC-DB-24 5-platform serialization scaffold (per IN-1 verification protocol)

- [ ] **AC-DB-24** (DestinyBranchChoice ResourceSaver/ResourceLoader round-trip) — Construct all-9-field-populated `DestinyBranchChoice` (including non-empty StringName invalid_reason like `&"invariant_violation:branch_table_empty"`), save via `ResourceSaver.save(choice, "user://test.tres")`, load via `ResourceLoader.load(...) as DestinyBranchChoice`, assert all 9 fields field-identical + `typeof(loaded.invalid_reason) == TYPE_STRING_NAME` (the OQ-DB-6 critical assertion). Test at `tests/integration/destiny_branch/destiny_branch_choice_serialization_test.gd::test_round_trip_all_platforms`. **Sprint-7 scope per R-3**: Linux Editor + Windows D3D12 lanes only (CI-active); macOS / iOS / Android manual-fallback (full 5-platform CI deferred to release-prep sprint per CI lane gap noted in sprint-7 plan).

### 3 forbidden_pattern lints (per ADR-0018 §Migration Plan §5)

- [ ] **AC-LINT-1** (`lint_destiny_branch_judge_no_gamebus_emit.sh`) — `grep -E 'GameBus\..*\.emit\(' src/feature/destiny_branch/destiny_branch_judge.gd src/feature/destiny_branch/default_destiny_branch_judge.gd tests/helpers/destiny_branch_judge_stub.gd` returns 0 matches. Scan-set forward-compat per godot-specialist 15th-invocation C-3: future `$(grep -rl 'extends DestinyBranchJudge' src/ tests/)` discovery.
- [ ] **AC-LINT-2** (`lint_destiny_branch_judge_no_static_var.sh`) — `grep -E '^static var' src/feature/destiny_branch/destiny_branch_judge.gd src/feature/destiny_branch/default_destiny_branch_judge.gd tests/helpers/destiny_branch_judge_stub.gd` returns 0 matches. Same scan-set expansion.
- [ ] **AC-LINT-3** (`lint_destiny_branch_judge_no_scenario_runner_read.sh`) — `grep -E 'ScenarioRunner\.|_scenario_state\.' src/feature/destiny_branch/destiny_branch_judge.gd src/feature/destiny_branch/default_destiny_branch_judge.gd` returns 0 matches. **Pillar 2 architectural lock 3rd precedent** — judge MUST receive `first_attempt_resolved` as 4th argument (ALREADY-SEALED value passed BY ScenarioRunner per F-SP-3 v2.2 + scenario_runner_deferred_seal_in_beat_7_entry forbidden_pattern); judge MUST NOT read from `ScenarioRunner._scenario_state.first_attempt_resolved`.

### Validation Criteria from ADR-0018 §Validation Criteria (V-1..V-12 — sprint-7 scope subset)

- [ ] **V-5** (@abstract test seam structural assertion) — `FileAccess.get_file_as_string()` on `src/feature/destiny_branch/destiny_branch_judge.gd` + assert content contains `"@abstract"` + `"func _apply_f_sp_1"` + `"-> Dictionary"` substrings (G-22 structural source-file assertion verification per delta #13)
- [ ] **V-7** (3 forbidden_pattern lints green) — covered by AC-LINT-1/2/3 above
- [ ] **V-12** (thread-safety integration test) — covered above

---

## Implementation Notes

*Derived from ADR-0018 §Migration Plan §5 + delta #13 same-patch wording flips + Decision A coordination from scenario-progression story-001:*

### File Layout (3 source replacements + 1 test helper extension + 5 test files + 3 lints + 1 verification summary)

**Source files — REPLACE stub bodies from scenario-progression story-001 per Decision A**:

1. `src/feature/destiny_branch/destiny_branch_judge.gd` (~120 LoC; REPLACE stub with authoritative impl) — Full F-DB-1 algorithm body in `resolve(chapter: ChapterDefinition, outcome: BattleOutcome.Result, echo_count: int, first_attempt_resolved: bool) -> DestinyBranchChoice`:
   - Step 1: Pre-call invariant guards (null chapter / chapter_id empty / default_branch_key empty / branch_table null/malformed/empty / outcome out of {0,1,2} / Ch1-echo_threshold CR-13 violation) — return `invalid()` factory short-circuit per F-DB-3 12-entry vocabulary
   - Step 2: Call `_apply_f_sp_1(chapter, outcome, echo_count, first_attempt_resolved)` (delegates to override per @abstract test seam)
   - Step 3: Post-call invariant guards on F-SP-1 output Dictionary (required keys present: branch_key + is_draw_fallback + is_canonical_history; type-checks on each value; cross-field invariant `is_draw_fallback ⟹ DRAW`) — return `invalid()` factory if violated
   - Step 4: F-DB-2 reserved_color_treatment derivation rule: `(branch_key != chapter.canonical_branch_key) AND (NOT is_draw_fallback)`
   - Step 4a: Fallback override: `is_draw_fallback == true` ⟹ `reserved_color_treatment = false` regardless of branch_key (F-DB-2 step 4a per CR-DB-9)
   - Step 5: Construct + return populated 9-field `DestinyBranchChoice` Resource
   - 12-entry F-DB-3 invariant_violation:* StringName constants declared as class-level const (NOT static var per `destiny_branch_judge_static_var` forbidden_pattern)
   - `@abstract func _apply_f_sp_1(chapter: ChapterDefinition, outcome: BattleOutcome.Result, echo_count: int, first_attempt_resolved: bool) -> Dictionary` test seam declaration (Godot 4.5+ G-22 parse-time enforcement)
   - Optional zero-canonical-row runtime warning path per F-DB-1 step 1b runtime guard (push_warning on detected authoring drift; does NOT set is_invalid)

2. `src/feature/destiny_branch/default_destiny_branch_judge.gd` (~10 LoC; REPLACE stub with authoritative delegation) — `class_name DefaultDestinyBranchJudge extends DestinyBranchJudge` overrides `_apply_f_sp_1` to delegate to `ScenarioFormulas.resolve_branch(chapter, outcome, echo_count, first_attempt_resolved)` (ADR-0017 owned F-SP-1 authoritative implementation; ScenarioFormulas is owned by scenario-progression epic — coordinate with scenario-progression story-001 author to ensure ScenarioFormulas.resolve_branch exists and exposes the 4-arg signature). NOTE: `DefaultDestinyBranchJudge.new()` is the production constructor invoked by ScenarioRunner per CR-DB-4 (scenario-progression story-001 ships the call site with the stub; this story REPLACES the stub body with the real F-SP-1 delegation).

3. `src/core/payloads/destiny_branch_choice.gd` (~30 LoC; REPLACE stub with full 9-field shape) — `class_name DestinyBranchChoice extends Resource` with 9 typed @export fields per F-DB-4: `chapter_id: String` + `branch_key: String` + `outcome: BattleOutcome.Result` (typed enum @export; default LOSS) + `echo_count: int` + `is_draw_fallback: bool` + `is_canonical_history: bool` (Pillar 4 payload-level enforcement) + `reserved_color_treatment: bool` (Pillar 2 derivation per F-DB-2) + `is_invalid: bool` + `invalid_reason: StringName` (∈ 12-entry F-DB-3 vocabulary) + `static func invalid(reason: StringName) -> DestinyBranchChoice` factory. **BattleOutcome MUST be top-level class_name per cross-doc constraint** (SATISFIED in shipped `src/core/payloads/battle_outcome.gd:10`).

**Test helper — extend stub from scenario-progression story-001 per Decision A**:

4. `tests/helpers/destiny_branch_judge_stub.gd` (~30 LoC; EXTEND stub with full set_sp1_output API) — `class_name TestDestinyBranchJudgeWithSp1Stub extends DestinyBranchJudge` overrides `_apply_f_sp_1` to return instance-level `_stub_output` Dictionary set via `set_sp1_output(output: Dictionary)`. Instance-level state ONLY (NO static var per `destiny_branch_judge_static_var` forbidden_pattern; lint scan-set explicitly covers this file). NOTE: scenario-progression story-001 may have shipped a minimal stub; this story extends it with the full set_sp1_output API for AC-DB-14/15/20c/20d/20e/20g parameterized test usage.

**New test files** (~12-15 net-new tests across 2-3 unit + 2 integration files per sprint-7 plan):

5. `tests/unit/feature/destiny_branch/destiny_branch_judge_worked_examples_test.gd` (~150-200 LoC) — AC-DB-01 + AC-DB-02 + AC-DB-03 + AC-DB-04 + AC-DB-05 + AC-DB-06 (worked examples E1-E6); 6 tests
6. `tests/unit/feature/destiny_branch/destiny_branch_judge_invariants_test.gd` (~200-300 LoC) — AC-DB-16 + AC-DB-17 + AC-DB-18 + AC-DB-19 + AC-DB-20 + AC-DB-20a + AC-DB-20b + AC-DB-20c + AC-DB-20d + AC-DB-20e + AC-DB-20f + AC-DB-20g (12-entry F-DB-3 vocabulary) + AC-DB-21 + AC-DB-22 + AC-DB-23 (F-DB-4 invariants + closed vocabulary); ~13-15 tests
7. `tests/unit/feature/destiny_branch/destiny_branch_judge_derivation_test.gd` (~100 LoC) — AC-DB-14 + AC-DB-15 (F-DB-2 reserved_color_treatment derivation positive + negative + step 4a fallback); 2 tests + parameterized rows
8. `tests/unit/feature/destiny_branch/destiny_branch_judge_determinism_test.gd` (~100 LoC) — AC-DB-07 (determinism) + AC-DB-08 (transient lifecycle WeakRef); 2 tests + source-scan via FileAccess for forbidden API patterns
9. `tests/integration/destiny_branch/destiny_branch_judge_thread_safety_test.gd` (~80 LoC) — V-12 thread-safety (2 instances × 1000 concurrent calls field-identical to baseline)
10. `tests/integration/destiny_branch/destiny_branch_choice_serialization_test.gd` (~100 LoC) — AC-DB-24 ResourceSaver/ResourceLoader round-trip on Linux Editor + Windows D3D12 (CI-active lanes); manual-fallback for macOS / iOS / Android per sprint-7 R-3

**3 new lint scripts** at `tools/ci/` (per ADR-0018 §Validation Criteria V-7 + Migration Plan §5):

11. `tools/ci/lint_destiny_branch_judge_no_gamebus_emit.sh` — AC-LINT-1; scan-set covers production source + test stub + future `extends DestinyBranchJudge` discovery
12. `tools/ci/lint_destiny_branch_judge_no_static_var.sh` — AC-LINT-2; same scan-set expansion per godot-specialist 15th-invocation advisory C-3
13. `tools/ci/lint_destiny_branch_judge_no_scenario_runner_read.sh` — AC-LINT-3; **Pillar 2 architectural lock 3rd precedent** enforcement; scan-set covers production source files only (test stub allowed to reference ScenarioRunner if needed for stub setup, though no current need)

All 3 lints wired into `.github/workflows/tests.yml` after the existing 5 hp-status lint group + 5 scenario-progression lint group (from scenario-progression story-001 same-sprint).

**Verification summary** (epic terminal):

14. `production/qa/evidence/destiny_branch_verification_summary.md` — covers all 15 TR-destiny-branch-* satisfaction proofs + lifecycle ownership map (scenario-progression story-001 stub → this story authoritative impl per Decision A coordination)

### Pre-resolved coordination decisions (per dev-story spawn prompt)

- **Decision A (REPLACE stub bodies — coordinate with scenario-progression story-001)**: scenario-progression story-001 shipped MINIMAL DestinyBranchJudge scaffolding (3 source files + minimal test helper) with stubbed `_apply_f_sp_1` body. This story REPLACES (NOT extends) the stub bodies with authoritative F-DB-1 algorithm + 12-entry F-DB-3 vocabulary + F-DB-2 derivation. Verification: this story's destiny_branch_judge.gd diff against scenario-progression story-001's destiny_branch_judge.gd should show stub body removed + full F-DB-1 algorithm replacing it.

- **Decision B (ScenarioFormulas.resolve_branch dependency)**: `DefaultDestinyBranchJudge._apply_f_sp_1` delegates to `ScenarioFormulas.resolve_branch(chapter, outcome, echo_count, first_attempt_resolved)`. ScenarioFormulas is owned by scenario-progression epic per ADR-0017 §F-SP-1/F-SP-2 Execution. Coordinate: scenario-progression story-001 must ship `ScenarioFormulas.resolve_branch(...)` with the 4-arg signature returning a Dictionary `{branch_key: String, is_draw_fallback: bool, is_canonical_history: bool}`. If scenario-progression story-001 ships ScenarioFormulas as a separate file at `src/core/scenario_formulas.gd` (recommended) OR embeds it inline in scenario_runner.gd — either form is acceptable; this story's `DefaultDestinyBranchJudge._apply_f_sp_1` calls the public method by class_name reference.

- **Decision C (5-platform serialization CI lane scope)**: Sprint-7 R-3 mitigation — Linux Editor + Windows D3D12 lanes are CI-active per existing GdUnit4 setup; macOS / iOS / Android lanes are manual-test fallback for sprint-7. Full 5-platform CI deferred to release-prep sprint per CI lane gap noted in sprint-7 plan. Document partial closure of OQ-DB-6 in this story's verification summary; AC-DB-24 satisfied via Linux + Windows lanes for sprint-7 close.

- **Decision D (rev 1.3.2 GDD §F-DB-1 wording sync vs sections OUTSIDE §F-DB-1)**: per /architecture-review delta #13 minor advisory observation, destiny-branch GDD sections OUTSIDE §F-DB-1 (CR-DB-9 in §Detailed Rules + F-DB-4 invariants in §Formulas + EC-DB-2 prose in §Edge Cases + AC-DB tests in §Acceptance Criteria) retain `default_branch_key` and `ChapterResource` references. ADR-0018 Migration Plan §1 explicitly scoped to §F-DB-1 only ("1 GDD field-name flip" — singular). Cross-section field-name updates are deferred to future GDD hygiene pass — NOT BLOCKING for this story's implementation. Story-internal note: ChapterDefinition.canonical_branch_key (NOT default_branch_key) is the authoritative field name per ADR-0017 ChapterDefinition schema; tests in this story use canonical_branch_key terminology even though some GDD prose sections retain default_branch_key.

- **Decision E (push_error helper for AC-DB-20 stdout-redirect)**: per rev 1.3 D2 decision, AC-DB-20 helper locked to Godot stdout/stderr redirect + grep buffer implementation. Use GdUnit4 `monitor_errors()` per project precedent (ADR-0014 stories shipped this pattern). Story implementer: invoke `monitor_errors()` at test setup + call `assert_error_monitor()` post-resolve() to verify push_error message containing literal substring `"cr13_echo_threshold_on_ch1"` per AC-DB-06 / AC-DB-20.

- **Decision F (BattleOutcome class_name verification)**: AC-DB-24 ResourceSaver/Loader round-trip depends on `BattleOutcome` being declared as top-level `class_name` per cross-doc constraint. SATISFIED in shipped `src/core/payloads/battle_outcome.gd:10` per godot-specialist 16th-invocation N-4 verification (delta #13). This story does NOT need to verify or amend BattleOutcome; existing shipped code satisfies the constraint.

---

## Out of Scope

*Handled by neighbouring stories or future sprints — do not implement here:*

- **DestinyBranchJudge stub scaffolding** — already shipped by scenario-progression story-001 per Decision A; this story REPLACES the stub bodies with authoritative impl
- **ScenarioFormulas.resolve_branch implementation** — owned by scenario-progression epic per ADR-0017 §F-SP-1/F-SP-2 Execution; this story's DefaultDestinyBranchJudge delegates to ScenarioFormulas.resolve_branch (which scenario-progression story-001 ships)
- **ScenarioRunner BEAT_7_JUDGMENT entry handler** — owned by scenario-progression story-001; this story does NOT modify scenario_runner.gd
- **destiny_branch_chosen GameBus signal emission** — owned by ScenarioRunner per CR-DB-4 emission ownership; this story does NOT emit GameBus signals (lint-enforced via AC-LINT-1)
- **Full 5-platform CI lane verification** (macOS Metal + iOS Metal + Android Vulkan) — deferred per Decision C / sprint-7 R-3; manual-fallback for sprint-7; full 5-platform CI deferred to release-prep sprint
- **destiny-branch GDD hygiene pass for sections OUTSIDE §F-DB-1** — deferred per Decision D + delta #13 minor advisory observation (CR-DB-9 + F-DB-4 + EC-DB-2 + AC-DB tests retain default_branch_key/ChapterResource refs); future GDD hygiene pass scope
- **AC-DB-09 (judge emits nothing GdUnit4 monitor_signals)** — covered indirectly by AC-LINT-1 source-grep + V-12 thread-safety test pattern; if GdUnit4 monitor_signals API is available in pinned v6.1.2, this story may add the AC-DB-09 test as bonus coverage; otherwise deferred (rev 1.3 GdUnit4 version-pin contract — implementation-story prerequisite per AC-DB-09 spec)
- **AC-DB-10 (CR-DB-5 ScenarioRunner state-machine guard)** — covered by scenario-progression story-001's state machine forward-only invariant tests (AC-SP-13)
- **AC-DB-11 (CR-DB-6 no intermediate state observable via GdUnit4 monitor_signals)** — same GdUnit4 version-pin caveat as AC-DB-09; deferred to bonus coverage
- **AC-DB-12 (CR-DB-7 destiny_branch_chosen exactly-once via ScenarioRunner)** — owned by scenario-progression story-001's signal contract test (AC-SP-17 5+1 confirmed signal emission)
- **AC-DB-13 (CR-DB-8 no branch structural leak)** — covered indirectly by AC-DB-23 closed vocabulary check + 9-field allowlist verification (DestinyBranchChoice has exactly 9 typed @export fields per F-DB-4 schema)
- **AC-DB-25..AC-DB-43 (~19 ACs)** — out of sprint-7 scope; covered by future destiny-branch follow-up stories OR Story Event #10 / Destiny State #16 VS GDDs (sprint-7 S7-06 + S7-07 — each consumes DestinyBranchChoice 9-field payload contract)
- **ADVISORY ACs** (AC-DB-21+ ADVISORY paths, AC-DB-31 chapter-argument-immutability fixture beyond MVP, AC-DB-38 accessibility R-1..R-5 dialog scope, AC-DB-39 affordance-onset timing sync, AC-DB-40+ cross-system V-DB items) — deferred to art-team / accessibility-specialist verification + future destiny-branch follow-up stories
- **OQ-DB-6 release-prep CI hardening** — full 5-platform CI matrix including GitHub Actions runners for macOS/iOS/Android requires CI infrastructure investment; deferred per sprint-7 plan R-3 mitigation

---

## QA Test Cases

*Authored at story creation per skill Step 4b — QA Lead gate skipped in lean mode; orchestrator-direct authoring per project precedent. The developer implements against these test specs — do not invent new test cases during implementation.*

### Logic test specs (F-DB-1 worked examples — automated)

**AC-DB-01** (E1 Ch1 WIN default):
- Given: Ch1 ChapterDefinition fixture with `chapter_id="ch1"`, `default_branch_key="WIN_ch1_default"`, `canonical_branch_key="WIN_ch1_default"` (canonical aligns with default), no echo_threshold field set, valid `branch_table = {"WIN": "WIN_ch1_default", "LOSS": "LOSS_ch1_default", "DRAW": "DRAW_ch1_default"}` Dictionary; `DefaultDestinyBranchJudge.new()` instance
- When: `judge.resolve(chapter, BattleOutcome.Result.WIN, 0, true)` is called
- Then: Returned DestinyBranchChoice has `chapter_id == "ch1"` + `branch_key == "WIN_ch1_default"` + `outcome == BattleOutcome.Result.WIN` + `echo_count == 0` + `is_draw_fallback == false` + `reserved_color_treatment == false` (branch_key matches canonical_branch_key per F-DB-2) + `is_canonical_history == true` (this is the canonical row) + `is_invalid == false` + `invalid_reason == &""`
- Edge cases: WIN with echo_count > 0 + first_attempt_resolved=false (verify still produces WIN_ch1_default since WIN doesn't trigger echo gate) + WIN with malformed branch_table missing WIN row (verify invalid_reason=branch_table_missing_outcome per AC-DB-18)

**AC-DB-02** (E2 Ch3 DRAW default):
- Given: Ch3 ChapterDefinition fixture with `author_draw_branch=true`, `echo_threshold=1`, `default_branch_key="WIN_ch3_default"`, `canonical_branch_key="WIN_ch3_default"`, branch_table contains DRAW row `"DRAW_ch3_default"`; first attempt (echo_count=0)
- When: `judge.resolve(chapter, DRAW, 0, true)` called
- Then: branch_key == "DRAW_ch3_default" + is_draw_fallback == false (because author_draw_branch=true) + reserved_color_treatment == true (DRAW_ch3_default ≠ WIN_ch3_default canonical) + is_invalid == false
- Edge cases: Same fixture with first_attempt_resolved=true forced from outside despite echo_count=0 (verify still produces DRAW_ch3_default; first_attempt_resolved seal doesn't unlock echo-gated unless echo_count >= echo_threshold)

**AC-DB-03** (E3 Ch3 DRAW echo-gated — Pillar 2 observable):
- Given: Same Ch3 fixture as AC-DB-02 + branch_table also contains `"DRAW_ch3_echo"` row keyed on echo-gated condition; echo_count=1 + first_attempt_resolved=false (player retried and got DRAW)
- When: `judge.resolve(chapter, DRAW, 1, false)` called
- Then: branch_key == "DRAW_ch3_echo" (DISTINCT from DRAW_ch3_default per CR-6 echo-gate predicate) + reserved_color_treatment == true + is_invalid == false
- Edge cases: echo_count=1 + first_attempt_resolved=true (verify F-SP-2 echo-gate stays CLOSED — first attempt sealed despite echo_count > 0 implies echo-gate uses sealed value; should produce DRAW_ch3_default per CR-6) + echo_count=0 (echo-gate never opens; produces DRAW_ch3_default)

**AC-DB-04** (E4 Ch2 DRAW fallback):
- Given: Ch2 ChapterDefinition fixture with `author_draw_branch=false`, `default_branch_key="WIN_ch2_default"`, `canonical_branch_key="WIN_ch2_default"`, branch_table does NOT contain DRAW row (author_draw_branch=false signals no-DRAW-branch-authored)
- When: `judge.resolve(chapter, DRAW, 0, true)` called
- Then: branch_key == "WIN_ch2_default" (DRAW falls through to WIN default per CR-5 fallback rule) + is_draw_fallback == true (signals fallback occurred) + reserved_color_treatment == false (F-DB-2 step 4a fallback override: is_draw_fallback==true ⟹ reserved_color_treatment=false regardless) + outcome == DRAW (preserved per CR-3) + is_invalid == false
- Edge cases: Same fixture with WIN outcome (verify normal WIN path; is_draw_fallback=false) + Ch2 fixture with author_draw_branch=true but branch_table missing DRAW row (verify invalid_reason=branch_table_missing_outcome — different code path from author_draw_branch=false fallback)

**AC-DB-05** (E5 null chapter):
- Given: chapter parameter is null
- When: `judge.resolve(null, WIN, 0, true)` called
- Then: DestinyBranchChoice.is_invalid == true + invalid_reason == &"invariant_violation:chapter_null" + reserved_color_treatment == false (per AC-DB-21 invariant) + chapter_id == "" (default empty) + branch_key == "" (default empty)
- Edge cases: All 4 outcomes (WIN/DRAW/LOSS) with null chapter (verify same invalid_reason regardless of outcome) + null chapter on bizarre echo_count=999 (verify still produces invalid_reason=chapter_null; F-DB-1 step 1 chapter null guard fires before any echo evaluation)

**AC-DB-06** (E6 CR-13 runtime violation):
- Given: Ch1 ChapterDefinition fixture with `echo_threshold=1` set (authoring-validator should have rejected this; runtime guard catches it per CR-13)
- When: `judge.resolve(chapter, DRAW, 1, false)` called (DRAW + echo + first_attempt_resolved=false simulates retry path that would normally trigger echo-gate)
- Then: DestinyBranchChoice.is_invalid == true + invalid_reason == &"invariant_violation:cr13_echo_threshold_on_ch1" + push_error emitted with message containing literal substring "cr13_echo_threshold_on_ch1" (verified via GdUnit4 monitor_errors() + assert_error_monitor() per Decision E stdout-redirect helper)
- Edge cases: Ch2/Ch3/etc. with same echo_threshold=1 (verify NOT flagged — CR-13 violation is Ch1-specific; only ch1's echo_threshold field is forbidden) + Ch1 with echo_threshold=0 (verify NOT flagged — explicit 0 is fine, only non-zero echo_threshold on Ch1 violates CR-13)

### Logic test specs (CR-DB-2 / CR-DB-11 determinism + CR-DB-3 transient lifecycle — automated)

**AC-DB-07** (determinism):
- Given: Valid ChapterDefinition fixture; identical (outcome, echo_count, first_attempt_resolved) inputs across two calls
- When: `judge1 := DefaultDestinyBranchJudge.new()`; `result1 := judge1.resolve(chapter, WIN, 0, true)`; `judge2 := DefaultDestinyBranchJudge.new()` (independently constructed); `result2 := judge2.resolve(chapter, WIN, 0, true)`
- Then: `result1` and `result2` are field-equal across all 9 typed @export fields (assert each field equality individually); FileAccess source-scan on `src/feature/destiny_branch/destiny_branch_judge.gd` + `src/feature/destiny_branch/default_destiny_branch_judge.gd` returns 0 matches for forbidden API patterns: `Time.get_ticks_msec`, `Time.get_ticks_usec`, `randi`, `randf`, `randf_range`, `randi_range`, `Engine.get_*_frames`, `DisplayServer.window_*`, `OS.get_processor_count`, `/root/`
- Edge cases: 100-call repetition on same instance (verify no state leakage across calls — instance-level state forbidden per CR-DB-2) + concurrent execution simulated via sequential alternating calls (verify deterministic regardless of call order)

**AC-DB-08** (transient lifecycle):
- Given: Local-scope variable `var judge := DefaultDestinyBranchJudge.new()` + `var weak := weakref(judge)`
- When: `judge.resolve(chapter, WIN, 0, true)` is called; then `judge` goes out of scope (test function returns to outer test scope where local was declared, OR test explicitly assigns `judge = null`)
- Then: After waiting 1 idle frame (`await get_tree().process_frame`), `weak.get_ref() == null` (no lingering reference from signal connection, callable binding, or autoload — proves RefCounted scope-drop semantics work correctly + judge is truly transient per CR-DB-3)
- Edge cases: judge held by signal connection (verify weak still cleared if signal disconnect happens before scope drop) + judge held by Callable binding (verify same)

### Logic test specs (F-DB-2 derivation — automated)

**AC-DB-14** (CR-DB-9 reserved_color_treatment positive case):
- Given: TestDestinyBranchJudgeWithSp1Stub instance + Ch3 fixture with `default_branch_key="WIN_ch3_default"` + stub configured `set_sp1_output({"branch_key": "DRAW_ch3_echo", "is_draw_fallback": false, "is_canonical_history": false})`
- When: `stub.resolve(chapter, DRAW, 1, false)` called
- Then: DestinyBranchChoice.reserved_color_treatment == true (because branch_key="DRAW_ch3_echo" != canonical_branch_key="WIN_ch3_default" AND is_draw_fallback=false per F-DB-2 derivation rule) + DestinyBranchChoice.is_invalid == false
- Edge cases: Parameterized over Ch1..Ch5 default_branch_key fixtures × stubbed non-default branch_key values (verify F-DB-2 rule fires consistently)

**AC-DB-15** (CR-DB-9 + F-DB-2 negative case):
- Given (row 1): TestDestinyBranchJudgeWithSp1Stub + Ch2 fixture with `default_branch_key="WIN_ch2_default"` + stub configured `set_sp1_output({"branch_key": "WIN_ch2_default", "is_draw_fallback": false, "is_canonical_history": true})` (branch_key equals default)
- When (row 1): `stub.resolve(chapter, WIN, 0, true)` called
- Then (row 1): DestinyBranchChoice.reserved_color_treatment == false (branch_key matches canonical_branch_key per F-DB-2)
- Given (row 2): Same fixture + stub `set_sp1_output({"branch_key": "WIN_ch2_default", "is_draw_fallback": true, "is_canonical_history": true})`
- When (row 2): `stub.resolve(chapter, DRAW, 0, true)` called
- Then (row 2): DestinyBranchChoice.reserved_color_treatment == false (F-DB-2 step 4a fallback override: is_draw_fallback==true ⟹ false regardless of branch_key)
- Edge cases: Stub with `is_canonical_history: false` + branch_key matching canonical (verify reserved_color_treatment=false; canonical alignment supersedes is_canonical_history value per F-DB-2 derivation rule) + Stub with branch_key empty string (verify still false because empty doesn't differ from canonical_branch_key in the != comparison if both are empty)

### Logic test specs (F-DB-3 12-entry invariant_violation vocabulary — automated)

**AC-DB-16..AC-DB-20g** (12 invariant guards): Each AC-DB-16 / AC-DB-17 / AC-DB-18 / AC-DB-19 / AC-DB-20 / AC-DB-20a..g produces a parameterized test row. Pattern:
- Given: Fixture configured to trigger specific invariant violation (per AC text above)
- When: `judge.resolve(...)` called
- Then: Returned DestinyBranchChoice has `is_invalid == true` + `invalid_reason == &"invariant_violation:<specific_token>"` (matches the F-DB-3 vocabulary entry for that violation) + `reserved_color_treatment == false` per AC-DB-21 invariant
- Edge cases (per AC): null/0/1/"false"/"true"/[] type matrix for AC-DB-20d/20e (parameterized 6 rows each); is_draw_fallback + outcome ∈ {WIN, LOSS} parameterized for AC-DB-20g (2 rows); branch_table empty Dictionary for AC-DB-20f (1 row, distinct from AC-DB-18 missing-row path)

### Logic test specs (F-DB-4 invariants + closed vocabulary — automated)

**AC-DB-21** (reserved_color_treatment false when is_invalid=true):
- Given: All 12 F-DB-3 vocabulary entries (one fixture per entry triggering that specific invariant_violation)
- When: `judge.resolve(...)` called for each
- Then: Returned DestinyBranchChoice always has `reserved_color_treatment == false` AND `is_invalid == true` AND `invalid_reason in <12-entry F-DB-3 set>` regardless of whether the underlying branch_key would satisfy `(branch_key != chapter.canonical_branch_key)` inequality

**AC-DB-22** (F-DB-4 invariant — is_draw_fallback ⟹ DRAW):
- Given: Parameterized test with 12 fixture rows: (a) Ch2 author_draw_branch=false × outcome ∈ {WIN, DRAW, LOSS} × echo_count ∈ {0, 1} = 6 rows; (b) Ch3 author_draw_branch=true × outcome ∈ {WIN, DRAW, LOSS} × echo_count ∈ {0, 1} = 6 rows
- When: `judge.resolve(chapter, outcome, echo_count, true)` called for each row
- Then: For every row where DestinyBranchChoice.is_draw_fallback == true, the implication `outcome == DRAW` holds (never WIN, never LOSS); CI grep lint rule additionally verifies no code path in destiny_branch_judge.gd sets `choice.is_draw_fallback = true` without `outcome == DRAW` in same function (verify via source-scan)

**AC-DB-23** (closed vocabulary):
- Given: All 12 F-DB-3 vocabulary entries trigger conditions
- When: `judge.resolve(...)` called for each + invalid_reason inspected
- Then: invalid_reason StringName value is a member of exact 12-element set: {chapter_null, chapter_id_missing, default_branch_key_missing, branch_table_null_or_malformed, branch_table_empty, branch_table_missing_outcome, branch_key_type_invalid, is_draw_fallback_type_invalid, is_canonical_history_type_invalid, is_draw_fallback_outcome_mismatch, outcome_unknown, cr13_echo_threshold_on_ch1}; assert via parameterized loop checking StringName membership

### Integration test specs (V-12 thread-safety + AC-DB-24 serialization — automated)

**V-12 thread-safety integration test**:
- Given: 2 separately-constructed `DefaultDestinyBranchJudge` instances + 1000 concurrent invocations of `resolve()` per instance dispatched via `WorkerThreadPool.add_task()` (2000 total invocations); each invocation uses identical inputs (same chapter fixture + outcome + echo_count + first_attempt_resolved)
- When: All 2000 tasks complete (await `WorkerThreadPool.wait_for_all_tasks()`)
- Then: All 2000 returned DestinyBranchChoice objects are field-identical to a baseline computed once before threading (assert across all 9 @export fields); proves EC-DB-17 thread-safety BY CONSTRUCTION via no-static-var + no-instance-state-across-calls invariants
- Edge cases: Different inputs per task (verify field-different but per-input deterministic — i.e., same input always produces same output even when racing) + invalid input paths concurrent (verify invalid() factory thread-safe — no static var via `destiny_branch_judge_static_var` lint enforcement)

**AC-DB-24** (5-platform serialization round-trip):
- Given: Construct all-9-field-populated DestinyBranchChoice with non-empty StringName invalid_reason like `&"invariant_violation:branch_table_empty"` + non-default outcome (e.g., DRAW) + non-default branch_key
- When: `ResourceSaver.save(choice, "user://test_destiny_branch_choice.tres")` called; `var loaded := ResourceLoader.load("user://test_destiny_branch_choice.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as DestinyBranchChoice`
- Then: `loaded` is non-null + all 9 fields field-identical to original + `typeof(loaded.invalid_reason) == TYPE_STRING_NAME` (the OQ-DB-6 critical assertion — verifies StringName field-type preservation through ResourceSaver/ResourceLoader; prior versions of Godot have silently downgraded StringName to String on round-trip)
- Edge cases: Empty StringName invalid_reason (`&""`) round-trip + outcome enum value preservation (Result.WIN=0 vs Result.DRAW=1 vs Result.LOSS=2 typed-enum int storage) + 9th field is_canonical_history bool round-trip (verify NOT silently coerced to int)
- Sprint-7 scope per Decision C: Linux Editor + Windows D3D12 lanes only (CI-active); macOS / iOS / Android manual-fallback documented in verification summary

### Lint test specs (3 forbidden_patterns — automated)

**AC-LINT-1** (no_gamebus_emit):
- Given: `tools/ci/lint_destiny_branch_judge_no_gamebus_emit.sh` exists + chmod +x
- When: Script invoked from project root
- Then: Exits 0 (PASS); scan-set covers 3 production/helper files + future `extends DestinyBranchJudge` discovery
- Negative test: Inject `GameBus.destiny_branch_chosen.emit(some_choice)` into destiny_branch_judge.gd → verify lint FAILS with descriptive error message; revert injection

**AC-LINT-2** (no_static_var):
- Given: `tools/ci/lint_destiny_branch_judge_no_static_var.sh` exists + chmod +x
- When: Script invoked
- Then: Exits 0 PASS
- Negative test: Inject `static var _cache: Dictionary = {}` into destiny_branch_judge.gd → verify lint FAILS; revert

**AC-LINT-3** (no_scenario_runner_read — Pillar 2 architectural lock 3rd precedent):
- Given: `tools/ci/lint_destiny_branch_judge_no_scenario_runner_read.sh` exists + chmod +x
- When: Script invoked
- Then: Exits 0 PASS
- Negative test: Inject `var foo = ScenarioRunner._scenario_state.first_attempt_resolved` into destiny_branch_judge.gd → verify lint FAILS with Pillar 2 architectural lock 3rd-precedent error message; revert

---

## Test Evidence

**Story Type**: Logic + Integration (Logic for F-DB-1 algorithm + F-DB-3 vocabulary + F-DB-2 derivation pure-function tests; Integration for V-12 thread-safety + AC-DB-24 serialization round-trip + 3 lint scripts)

**Required evidence**:
- **Unit tests** (BLOCKING gate per Logic story-type): `tests/unit/feature/destiny_branch/destiny_branch_judge_*_test.gd` (4 files: worked_examples + invariants + derivation + determinism)
- **Integration tests** (BLOCKING gate per Integration story-type): `tests/integration/destiny_branch/destiny_branch_judge_thread_safety_test.gd` + `tests/integration/destiny_branch/destiny_branch_choice_serialization_test.gd`
- **Lint scripts** (BLOCKING gate per ADR-0018 §V-7): 3 lint scripts at `tools/ci/lint_destiny_branch_judge_*.sh` all exit 0 PASS
- **Verification summary** (epic terminal): `production/qa/evidence/destiny_branch_verification_summary.md` covering all 15 TR-destiny-branch-* satisfaction proofs + lifecycle ownership map (scenario-progression story-001 stub → this story authoritative impl per Decision A coordination)
- **Full regression**: target ~950 PASS at sprint-7 close per sprint-7 plan (+12-15 from this story alone)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: **scenario-progression story-001** (S7-02 sprint-7 critical path) — DestinyBranchJudge stub scaffolding (3 source files + minimal test helper) MUST exist before this story can REPLACE the stub bodies with authoritative impl per Decision A coordination. Also depends on `ScenarioFormulas.resolve_branch(...)` shipped by scenario-progression story-001 per Decision B (DefaultDestinyBranchJudge._apply_f_sp_1 delegates to it).
- **Unlocks**:
  - **chapter-1 (장판파) Beat 7 destiny-branch judgment + Beat 8 reveal** (consumes DestinyBranchChoice.reserved_color_treatment per art-bible §4.7 reserved_color_treatment addendum 2026-05-04)
  - **Story Event #10 VS GDD authoring** (S7-06 sprint-7 should-have) — Beat 8 narrative content keys on `(chapter_id, branch_key, is_canonical_history, is_draw_fallback, reserved_color_treatment)` payload fields per F-DB-4
  - **Destiny State #16 VS GDD authoring** (S7-07 sprint-7 should-have) — echo-archive maintenance + cross-chapter destiny-state propagation depends on ChapterResult + DestinyBranchChoice payload contracts being functional
  - **AISystem implementation** (S7-04 sprint-7 critical path) — AISystem MUST NOT reference DestinyBranchChoice / destiny_branch_chosen / hidden_fate_condition_progressed tokens per Pillar 2 architectural lock 4th precedent (`ai_system_reads_destiny_branch_state`); this story's lint precedent (Pillar 2 lock 3rd precedent) provides the template for S7-04's lint
  - **Pre-Production → Production gate upgrade** — gate-check 2026-05-04 path-to-PASS item #6 (sprint-7 plan execution); after S7-01..S7-07 close + S7-11 user attestation captured, expect upgrade CONCERNS → PASS
