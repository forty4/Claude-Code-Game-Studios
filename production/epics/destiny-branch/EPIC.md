# Epic: Destiny Branch (destiny-branch)

> **Layer**: Core
> **GDD**: `design/gdd/destiny-branch.md` (rev 1.3.2 — Designed; F-DB-1 4-arg signature + canonical_branch_key + worked-examples E1-E6 4th column + test-seam contract per delta #13 same-patch GDD sync)
> **Architecture Module**: `DestinyBranchJudge` — `class_name DestinyBranchJudge extends RefCounted` pure-function transient class; one instance per chapter constructed at BEAT_7_JUDGMENT tap-exit by ScenarioRunner; discarded via RefCounted scope drop after `resolve()` returns; **1st @abstract test-seam pattern in the project** (Godot 4.5+ G-22 parse-time enforcement on typed references); production subclass `DefaultDestinyBranchJudge` delegates to `ScenarioFormulas.resolve_branch(...)` per ADR-0017 owned F-SP-1 authoritative implementation; test stub `TestDestinyBranchJudgeWithSp1Stub` lives in `tests/helpers/destiny_branch_judge_stub.gd` with instance-level `_stub_output` Dictionary (NO static var per `destiny_branch_judge_static_var` forbidden_pattern — lint scan-set explicitly covers test stub).
> **Status**: Complete (1/1 stories shipped 2026-05-05 — single coordinated patch; epic-terminal close)
> **Stories**: 1 epic-terminal story — see Stories table below
> **Created**: 2026-05-05 (Sprint 7 — post-S7-01 ADR-0019 acceptance unblocks the 3-epic scaffold batch)
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md` — refreshed via gate-check pre-prod-to-prod-2026-05-04 path-to-PASS item #3)

## Overview

The Destiny Branch epic implements `DestinyBranchJudge` — the **pure-function transient executor** that resolves Beat 7 destiny-branch judgment per F-SP-1 algorithm (chapter, outcome, echo_count, first_attempt_resolved → DestinyBranchChoice 9-field typed Resource). The epic ships 3 source files (`src/core/payloads/destiny_branch_choice.gd` ~30 LoC + `src/feature/destiny_branch/destiny_branch_judge.gd` ~120 LoC + `src/feature/destiny_branch/default_destiny_branch_judge.gd` ~10 LoC), 1 test helper (`tests/helpers/destiny_branch_judge_stub.gd` ~30 LoC), 2 unit test files covering F-DB-1 worked examples E1-E6 + 12-entry F-DB-3 invariant_violation:* StringName vocabulary + EC-DB-17 thread-safety + AC-DB-24 ResourceSaver/ResourceLoader 5-platform round-trip, 3 CI lint scripts (`lint_destiny_branch_judge_no_static_var.sh` + `lint_destiny_branch_judge_no_gamebus_emit.sh` + `lint_destiny_branch_judge_no_scenario_runner_read.sh` — Pillar 2 architectural lock 3rd precedent), and 1 integration test for thread-safety on WorkerThreadPool.

This is the **1st invocation of `RefCounted pure-function class with @abstract test seam` pattern in the project** — establishes pattern boundary for future formula-evaluator ADRs in the destiny-branch / scenario-progression / save-load chain. Closes Pillar 2 (운명은 바꿀 수 있다) + Pillar 4 (삼국지의 숨결) architectural narrative-pillar substrate (alongside ScenarioRunner ADR-0017 delta #12). The 9-field DestinyBranchChoice payload ratifies ADR-0001 PROVISIONAL 5-field slot via Evolution Rule #4 minor amendment delta #13 (NOT supersession).

## Pattern Boundary Precedent

**1st invocation of `RefCounted pure-function class with @abstract test seam` pattern** + **3rd invocation of pillar-anchored lint pattern** (Pillar 2 architectural lock) + **3rd project precedent of "ratification widening at upstream-ADR acceptance"** + **1st invocation of direct_call interface contract** (vs prior signal-pattern interface contracts):

| Pattern Aspect | Invocation # | Predecessor (where applicable) | Form |
|---|---|---|---|
| RefCounted pure-function class with @abstract test seam | **1st** | (no precedent — establishes pattern boundary for future formula-evaluator ADRs) | `class_name DestinyBranchJudge extends RefCounted` + `@abstract func _apply_f_sp_1(chapter, outcome, echo_count, first_attempt_resolved) -> Dictionary` test seam (Godot 4.5+ G-22 parse-time enforcement) + production subclass `DefaultDestinyBranchJudge extends DestinyBranchJudge` delegating to ScenarioFormulas.resolve_branch + test stub `TestDestinyBranchJudgeWithSp1Stub extends DestinyBranchJudge` with instance-level `_stub_output` Dictionary set via `set_sp1_output()` |
| Pillar-anchored lint pattern (Pillar 2 architectural lock) | **3rd** | `battle_hud_subscribes_to_hidden_fate_signal` (ADR-0015 1st) + `scenario_runner_deferred_seal_in_beat_7_entry` (ADR-0017 2nd) | `destiny_branch_judge_reads_scenario_runner_state` — judge MUST receive `first_attempt_resolved` as 4th argument (ALREADY-SEALED value passed BY ScenarioRunner per F-SP-3 v2.2 + scenario_runner_deferred_seal_in_beat_7_entry); judge MUST NOT read from `ScenarioRunner._scenario_state.first_attempt_resolved` |
| Ratification widening at upstream-ADR acceptance | **3rd** | save_checkpoint_requested 2026-04-18 String → SaveContext + scenario_complete delta #12 String → ScenarioResult | 4-arg resolve() signature inherited from ADR-0017 line 200 + scenario-progression CR-7 4th-argument invariant; 3-arg legacy form rejected (Path A user decision); judge receives sealed value as function parameter, NOT autoload state read |
| direct_call interface contract | **1st** | (no precedent — prior interface contracts were all signal-pattern) | `destiny_branch_judge_signal_contract` pattern: **direct_call** (judge IS called by ScenarioRunner not via GameBus); ScenarioRunner constructs the judge + calls resolve() directly; the judge does NOT emit signals (CR-DB-4 emission ownership lives in ScenarioRunner — lint-enforced via destiny_branch_judge_emits_gamebus_signal forbidden_pattern); establishes pattern boundary for future executor-class interface contracts |

3-layer enforcement triad codified per control-manifest.md §Pillar 2 Architectural Locks (2026-05-04 path-to-PASS item #3): (1) source-grep lint; (2) ADR inline annotation; (3) integration test asserting isolation by construction.

## MVP Scope (per ADR-0018 §Migration Plan §5 — single coordinated patch)

This epic implements the MVP subset for sprint-7 S7-03 (single coordinated patch):

- ✅ **3 source files** at `src/core/payloads/` + `src/feature/destiny_branch/`:
  - `destiny_branch_choice.gd` (~30 LoC) — `class_name DestinyBranchChoice extends Resource` with **9 typed @export fields** per F-DB-4 (chapter_id / branch_key / outcome: BattleOutcome.Result / echo_count / is_draw_fallback / is_canonical_history / reserved_color_treatment / is_invalid / invalid_reason: StringName) + `static func invalid(reason: StringName) -> DestinyBranchChoice` factory
  - `destiny_branch_judge.gd` (~120 LoC) — `class_name DestinyBranchJudge extends RefCounted` base class with `@abstract func _apply_f_sp_1(...)` test seam + 4-arg `resolve(chapter, outcome, echo_count, first_attempt_resolved) -> DestinyBranchChoice` public API + 12-entry F-DB-3 invariant_violation:* StringName vocabulary as constants + 9-field assembly pipeline + F-DB-2 reserved_color_treatment derivation rule (per CR-DB-9 + canonical_branch_key field-name reconciliation)
  - `default_destiny_branch_judge.gd` (~10 LoC) — `class_name DefaultDestinyBranchJudge extends DestinyBranchJudge` overrides `_apply_f_sp_1` to delegate to `ScenarioFormulas.resolve_branch(chapter, outcome, echo_count, first_attempt_resolved)` (ADR-0017-owned F-SP-1 authoritative implementation)
- ✅ **1 test helper** at `tests/helpers/destiny_branch_judge_stub.gd` (~30 LoC) — `class_name TestDestinyBranchJudgeWithSp1Stub extends DestinyBranchJudge` overrides `_apply_f_sp_1` to return instance-level `_stub_output` Dictionary set via `set_sp1_output()`; instance-level state ONLY (NO static var per `destiny_branch_judge_static_var` forbidden_pattern)
- ✅ **2 unit test files** (~200-300 LoC GdUnit4) covering F-DB-1 worked examples E1-E6 (canonical-WIN / REWRITTEN / PARTIAL / HISTORICAL / DEFEAT path coverage) + 12-entry F-DB-3 invariant_violation:* StringName vocabulary (chapter_null + chapter_id_missing + default_branch_key_missing + branch_table_null_or_malformed + branch_table_empty + branch_table_missing_outcome + is_draw_fallback_outcome_mismatch + branch_key_type_invalid + is_draw_fallback_type_invalid + is_canonical_history_type_invalid + outcome_unknown + cr13_echo_threshold_on_ch1) + EC-DB-17 thread-safety BY CONSTRUCTION + AC-DB-24 ResourceSaver/ResourceLoader round-trip protocol (initial implementation on Linux Editor + Windows D3D12 lanes; macOS / iOS / Android lanes manual-fallback per sprint-7 R-3 mitigation, full 5-platform deferred to release-prep sprint per CI lane gap)
- ✅ **3 CI lint scripts** at `tools/ci/`:
  - `lint_destiny_branch_judge_no_gamebus_emit.sh` — judge MUST NOT emit GameBus signals (CR-DB-4 emission ownership in ScenarioRunner); scan-set covers production source + test stub + future `extends DestinyBranchJudge` discovery
  - `lint_destiny_branch_judge_no_static_var.sh` — `static var` FORBIDDEN in entire DestinyBranchJudge class hierarchy (production + test stub + future subclass discovery per godot-specialist 15th-invocation advisory C-3 scan-set expansion); EC-DB-17 thread-safety guarantee
  - `lint_destiny_branch_judge_no_scenario_runner_read.sh` — judge MUST receive `first_attempt_resolved` as 4th argument (ALREADY-SEALED value) NOT read from autoload state (CR-DB-2 purity + scenario-progression CR-7 sealed-value pass-through invariant); **Pillar 2 architectural lock 3rd precedent**
- ✅ **1 integration test** at `tests/integration/destiny_branch/destiny_branch_judge_thread_safety_test.gd` — V-12: 2 simultaneous DestinyBranchJudge.new() instances on WorkerThreadPool tasks × 1000 concurrent calls each = 2000 returned DestinyBranchChoice objects field-identical to baseline (closes EC-DB-17 thread-safety BY CONSTRUCTION)
- ✅ **9-field DestinyBranchChoice round-trip on ≥2 platforms** (closes ADR-0018 OQ-DB-6 BLOCKING-for-VS gate per sprint-7 R-3 mitigation; full 5-platform deferred per CI lane gap)
- ✅ **@abstract test seam parse-fail verification** per V-5 — `FileAccess.get_file_as_string()` + `assert_bool(content.contains("@abstract")).is_true()` + `func _apply_f_sp_1` containment check (G-22 structural source-file assertion pattern)

**Explicit deferrals**:

- ❌ **Full 5-platform CI lane verification** (Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan) — Linux Editor + Windows D3D12 lanes are CI-active per existing GdUnit4 setup; macOS / iOS / Android lanes are manual-test fallback for sprint-7 (document as ADR-0018 OQ-DB-6 partial closure with CI lane gap noted per sprint-7 R-3); full 5-platform CI deferred to release-prep sprint
- ❌ **destiny-branch GDD hygiene pass** for sections OUTSIDE §F-DB-1 (CR-DB-9 + F-DB-4 + EC-DB-2 + AC-DB tests retain `default_branch_key`/`ChapterResource` references) — deferred to future GDD hygiene pass per ADR-0014/0015/0017 precedent (NOT BLOCKING for ADR-0018 acceptance)
- ❌ **Story Event #10 + Destiny State #16 VS GDD authoring** — sprint-7 should-have S7-06 + S7-07 design authoring (separate /design-system invocations); each consumes DestinyBranchChoice 9-field payload contract (UNBLOCKED by delta #13 ADR-0018 ratification)
- ❌ **Save/Load #17 VS GDD authoring** — CUT from sprint-7 per Producer pressure-cut decision

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0018 Destiny Branch** (Accepted 2026-05-04 via /architecture-review delta #13) | RefCounted pure-function transient class + @abstract test seam (1st @abstract pattern in project) + 4-arg resolve() signature (3rd ratification widening at upstream-ADR acceptance) + 9-field DestinyBranchChoice typed Resource (ratifies ADR-0001 5-field PROVISIONAL via Evolution Rule #4) + 12-entry F-DB-3 invariant_violation:* StringName vocabulary + DefaultDestinyBranchJudge production subclass + invalid() factory + F-DB-2 reserved_color_treatment derivation + Pillar 4 is_canonical_history payload-level enforcement + determinism invariant (lint-enforced via 3 forbidden_patterns) + EC-DB-17 thread safety BY CONSTRUCTION (lint scan-set covers production + test stub + future subclass discovery) + ADR-0001 minor amendment 5-field → 9-field same-patch + BattleOutcome top-level class_name cross-doc constraint (SATISFIED in shipped src/core/payloads/battle_outcome.gd:10) + emission ownership in ScenarioRunner + ResourceSaver/ResourceLoader round-trip on 5 export targets | **HIGH** (Godot 4.5+ @abstract annotation per breaking-changes.md 4.4→4.5 + Resource.duplicate_deep() per breaking-changes.md 4.4→4.5 + typed-Resource @export of typed enum values + StringName field-type preservation through ResourceSaver/ResourceLoader on 5 export targets per AC-DB-24 + IN-1 — last item flagged as BLOCKING for VS close per OQ-DB-6) |
| ADR-0017 Scenario Progression (depends-on) | ScenarioRunner constructs `DefaultDestinyBranchJudge.new()` + calls `judge.resolve(...)` at BEAT_7_JUDGMENT entry (post-seal) per ADR-0017 §F-SP-1/F-SP-2 Execution; emits `destiny_branch_chosen(choice)` on tap-advance (CR-DB-4 emission ownership lives in ScenarioRunner); ScenarioRunner is sole caller of judge.resolve(...) per `destiny_branch_judge_signal_contract` direct_call interface | LOW |
| ADR-0001 GameBus (depends-on) | `destiny_branch_chosen(DestinyBranchChoice)` signal — ratified 9-field shape via Evolution Rule #4 minor amendment delta #13; ScenarioRunner is sole emitter (NOT DestinyBranchJudge) per CR-DB-4 emission ownership + AC-SP-17 exactly-one-emission contract; subscribers MUST gate content reads on `choice.is_invalid == false` | LOW |
| ADR-0014 GridBattleController (depends-on) | `BattleOutcome.Result` enum consumed as `resolve()` 2nd argument; `BattleOutcome` MUST be top-level `class_name` per cross-doc constraint (SATISFIED in shipped `src/core/payloads/battle_outcome.gd:10` per godot-specialist 16th-invocation N-4 verification) | LOW |
| ADR-0003 Save/Load (depends-on) | `ChapterResult.branch_triggered` persists `DestinyBranchChoice.branch_key` per SaveContext schema; SaveMigrationRegistry covers future schema evolution | LOW |

**Highest Engine Risk among governing ADRs**: **HIGH** (ADR-0018 itself — Godot 4.5+ @abstract + parameterless duplicate_deep + StringName field-type preservation through ResourceSaver/ResourceLoader on 5 export targets). The HIGH-risk surface is verified at this epic's stories (V-3 + V-4 cross-platform serialization tests + V-5 @abstract structural assertion).

## GDD / TR Requirements

15 net-new TRs registered as TR-destiny-branch-001..015 in `tr-registry.yaml` v14 (delta #13).

| TR-ID | Requirement (summary) | ADR Coverage |
|-------|----------------------|--------------|
| TR-destiny-branch-001 | DestinyBranchJudge `class_name DestinyBranchJudge extends RefCounted` pure-function transient class; one instance per chapter; RefCounted scope drop; Node form + autoload form + static-utility form all REJECTED per Alternatives §1/§2/§3 (1st @abstract test-seam pattern in project) | ADR-0018 ✅ |
| TR-destiny-branch-002 | 4-arg `resolve(chapter: ChapterDefinition, outcome: BattleOutcome.Result, echo_count: int, first_attempt_resolved: bool) -> DestinyBranchChoice` — inherited from ADR-0017 line 200 + scenario-progression CR-7; 3-arg legacy form rejected (Path A user decision); 3rd project precedent of ratification widening at upstream-ADR acceptance | ADR-0018 ✅ |
| TR-destiny-branch-003 | DestinyBranchChoice `class_name extends Resource` with **9 typed @export fields** (chapter_id/branch_key/outcome/echo_count/is_draw_fallback/is_canonical_history/reserved_color_treatment/is_invalid/invalid_reason) — ratifies ADR-0001 5-field PROVISIONAL slot via Evolution Rule #4 minor amendment delta #13 | ADR-0018 ✅ |
| TR-destiny-branch-004 | 12-entry `invariant_violation:*` StringName F-DB-3 vocabulary + `static func invalid(reason: StringName) -> DestinyBranchChoice` factory; invalid payloads ARE emitted (preserves AC-SP-17); subscribers gate content on is_invalid==false | ADR-0018 ✅ |
| TR-destiny-branch-005 | `@abstract func _apply_f_sp_1(...) -> Dictionary` test seam (Godot 4.5+); concrete subclasses MUST override; G-22 parse-time enforcement; structural source-file assertion verification per V-5 | ADR-0018 ✅ |
| TR-destiny-branch-006 | `class_name DefaultDestinyBranchJudge extends DestinyBranchJudge` production subclass + delegation to `ScenarioFormulas.resolve_branch(...)` (ADR-0017 owned F-SP-1 authoritative impl); test stub at tests/helpers/destiny_branch_judge_stub.gd uses instance-level state ONLY | ADR-0018 ✅ |
| TR-destiny-branch-007 | `invalid()` factory + invariant-violation contract (CR-DB-10); ScenarioRunner emits unconditionally; downstream MUST gate content reads on is_invalid==false; warning-severity recoveries do NOT set is_invalid (use push_warning + is_draw_fallback field) | ADR-0018 ✅ |
| TR-destiny-branch-008 | `reserved_color_treatment` derivation per F-DB-2 + CR-DB-9 (NOT authored): `(branch_key != chapter.canonical_branch_key) AND (NOT is_draw_fallback)`; field-name reconciled to canonical_branch_key per ADR-0017 ChapterDefinition schema | ADR-0018 ✅ |
| TR-destiny-branch-009 | `is_canonical_history` Pillar 4 payload-level enforcement; Beat 8 (Story Event #10 VS) keys canonical-vs-rewritten contrast on this field; load-bearing reason for 5-field → 9-field widening | ADR-0018 ✅ |
| TR-destiny-branch-010 | Determinism invariant (CR-DB-11): NO RNG / NO wall-clock / NO external state read / NO instance-level state across calls / NO class-level state — lint-enforced via 3 forbidden_patterns (no_gamebus_emit + no_static_var + no_scenario_runner_state_read) | ADR-0018 ✅ |
| TR-destiny-branch-011 | EC-DB-17 thread safety BY CONSTRUCTION; lint scan-set explicitly covers production source + test stub + future `extends DestinyBranchJudge` discovery (godot-specialist 15th-invocation advisory C-3); V-12 integration test 2×1000 concurrent calls field-identical | ADR-0018 ✅ |
| TR-destiny-branch-012 | ADR-0001 minor amendment 5-field PROVISIONAL → 9-field RATIFIED via Evolution Rule #4; PROVISIONAL signal count 3→2; Pillar 2/4 mechanical-expression note rewritten; cross-doc BattleOutcome top-level constraint added | ADR-0018 ✅ |
| TR-destiny-branch-013 | BattleOutcome top-level class_name cross-doc constraint — SATISFIED in shipped code (src/core/payloads/battle_outcome.gd:10); Result enum order locked at grid-battle v5.0 (Migration Plan §6) | ADR-0018 ✅ |
| TR-destiny-branch-014 | Emission ownership in ScenarioRunner (CR-DB-4 + AC-SP-17); judge MUST NOT emit GameBus signal — lint-enforced via destiny_branch_judge_emits_gamebus_signal forbidden_pattern | ADR-0018 ✅ |
| TR-destiny-branch-015 | ResourceSaver/ResourceLoader round-trip on 5 export targets (Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan); StringName invalid_reason field-type preservation closes destiny-branch GDD OQ-DB-6 (BLOCKING for VS close); IN-1 verification protocol | ADR-0018 ✅ |

**Untraced Requirements**: None (15/15 covered by ADR-0018).

## Same-Patch Obligations from ADR-0018 §Migration Plan §5

These obligations land at the implementation story (S7-03) and ship together — single coordinated patch atomicity:

1. **3 source files** at `src/core/payloads/` + `src/feature/destiny_branch/` (DestinyBranchChoice + DestinyBranchJudge + DefaultDestinyBranchJudge per MVP Scope above)
2. **1 test helper** at `tests/helpers/destiny_branch_judge_stub.gd` (TestDestinyBranchJudgeWithSp1Stub with instance-level `_stub_output` Dictionary)
3. **2 unit test files** at `tests/unit/feature/destiny_branch/destiny_branch_judge_*_test.gd` covering F-DB-1 worked examples E1-E6 + 12-entry F-DB-3 vocabulary + EC-DB-17 thread-safety + AC-DB-24 round-trip
4. **3 CI lint scripts** at `tools/ci/` (no_gamebus_emit + no_static_var + no_scenario_runner_read — Pillar 2 architectural lock 3rd precedent) wired into `.github/workflows/tests.yml`
5. **1 integration test** at `tests/integration/destiny_branch/destiny_branch_judge_thread_safety_test.gd` (V-12: 2 instances × 1000 concurrent calls field-identical)
6. **5-platform serialization test scaffold** at `tests/integration/destiny_branch/destiny_branch_choice_serialization_test.gd::test_round_trip_all_platforms` per IN-1 verification protocol (initial implementation on Linux Editor + Windows D3D12; macOS / iOS / Android manual-fallback per sprint-7 R-3)
7. **Verification summary doc** at `production/qa/evidence/destiny_branch_verification_summary.md` covering all 15 TR satisfaction proofs

## Pillar 2 + Pillar 4 Architectural Lock Closure

ADR-0018 closes the **Pillar 2 + Pillar 4 architectural narrative-pillar substrate**:

- **Pillar 2 (운명은 바꿀 수 있다 — Destiny Can Be Rewritten)** — `reserved_color_treatment` field (F-DB-2 derivation) is the mechanical expression of Pillar 2 visual contract; lint-enforced via `destiny_branch_judge_reads_scenario_runner_state` (3rd-precedent pillar-anchored lint pattern); Beat 8 reveal scene visual contract bound to this field per art-bible §4.7 reserved_color_treatment addendum (added 2026-05-04 per gate-check path-to-PASS item #5)
- **Pillar 4 (삼국지의 숨결 — Romance of the Three Kingdoms Breath)** — `is_canonical_history` field is the payload-level enforcement of Pillar 4 (canonical 演義 historical record alignment); Beat 8 (Story Event #10 VS) keys canonical-vs-rewritten contrast on this field; load-bearing reason for ADR-0001 5-field → 9-field widening via Evolution Rule #4

## Stories

| # | Story | Type | Status | TR-IDs | Estimate |
|---|-------|------|--------|--------|----------|
| [001](story-001-destiny-branch-judge-impl-and-lints.md) | DestinyBranchJudge full F-DB-1 implementation + 3 lints + V-12 thread-safety + 5-platform serialization scaffold (epic-terminal) | Logic + Integration | **Complete** (S7-03 sprint-7 close 2026-05-05; 943/943 tests + 3/3 lints PASS; Stories table row backfill via S11-02 2026-05-07 — 3rd activation of sprint-10 retro AI #3) | TR-destiny-branch-001..015 (all 15) + AC-LINT-1..3 + V-5/V-7/V-12 | ~4-5h (0.5d nominal per sprint-7 plan; multi-spawn-on-scale less likely than scenario-progression story-001 — ~12-15 tests + 3 lints fits cleanly in 1 /dev-story spawn with possibly 1 SendMessage continuation) |

**Decision applied (per `/create-stories destiny-branch` 2026-05-05)**: **Option A — single epic-terminal story**. Rationale:
- ADR-0018 §Migration Plan §5 explicit single coordinated patch atomicity
- Sprint-7 plan S7-03 framing: "DestinyBranchJudge implementation per ADR-0018 §Migration Plan §5"
- Smaller scope than scenario-progression story-001 (~14 files vs ~22-26; 12-15 tests vs 25-30)
- 6 pre-resolved coordination decisions A-F embedded in story file (Decision A REPLACE stub bodies coordination + Decision B ScenarioFormulas dependency + Decision C 5-platform CI lane scope + Decision D §F-DB-1-only GDD wording sync + Decision E push_error stdout-redirect helper + Decision F BattleOutcome class_name SATISFIED) reduce SendMessage round-trip count
- Logic + Integration test ratio: most ACs are pure-function Logic (F-DB-1 algorithm + F-DB-3 vocabulary + F-DB-2 derivation); only V-12 thread-safety + AC-DB-24 serialization + 3 lints are Integration-typed

**Total estimate**: ~4-5h = ~0.5-0.6 working days (within sprint-7 S7-03 0.5d nominal budget; per 4th-consecutive AI #1 ratchet baseline of 5× velocity multiplier from sprint-5/6, projected actual ~0.1-0.12 calendar day = ~1h wall-clock).

**Implementation order**: Depends on scenario-progression story-001 completion (S7-02 must close first per Decision A). Once unblocked: story-001 (single epic-terminal) → `/code-review` (lean-mode orchestrator-direct per 13-precedent project default) → `/story-done` (closes epic at 1/1 Complete).

**Sprint allocation**: epic preview (this artifact) at S7-01 post-acceptance scaffold batch; implementation at S7-03 (sprint-7 critical path; 0.5d nominal per sprint-7 plan; depends on S7-02 per Decision A coordination).

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All 15 TR-destiny-branch-* requirements are satisfied (verified against `docs/architecture/tr-registry.yaml`)
- The 7 same-patch obligations above are shipped (3 source files + 1 test helper + 2 unit tests + 3 lints + 1 integration test + 5-platform scaffold + verification summary)
- `DestinyBranchJudge.resolve(...)` callable + `DefaultDestinyBranchJudge` subclass tested
- 9-field DestinyBranchChoice round-trip on ≥2 platforms (Linux Editor + Windows D3D12 confirmed; macOS / iOS / Android manual-fallback per sprint-7 R-3) — closes OQ-DB-6 BLOCKING-for-VS gate per sprint-7 plan
- @abstract test seam parse-fail verified via V-5 structural source-file assertion (G-22 pattern)
- 3 lint scripts pass in CI (Pillar 2 architectural lock 3rd-precedent enforcement triad: source-grep lint + ADR annotation + integration test)
- V-12 integration test passes (2 instances × 1000 concurrent calls field-identical to baseline — closes EC-DB-17 thread-safety BY CONSTRUCTION)
- The full regression baseline remains failure-free (target: ~950 PASS at sprint-7 close per sprint-7 plan; +12-15 from this epic alone)

## Next Step

Run `/create-stories destiny-branch` to break this epic into implementable stories. Decision pending: 1 epic-terminal story (Option A — matches "single coordinated patch" framing) vs 2-story decomposition (Option B — code-review checkpoint between source files and CI hardening). Sprint-7 S7-03 is the critical path; depends on S7-02 ScenarioRunner. Once stories created, run `/dev-story [story-path]` per implementation order.

**Unblocks**: chapter-1 (장판파) Beat 7 destiny-branch judgment + Beat 8 reveal (consumes DestinyBranchChoice.reserved_color_treatment per art-bible §4.7); Story Event #10 + Destiny State #16 VS GDD authoring (sprint-7 S7-06 + S7-07 — each consumes DestinyBranchChoice 9-field payload contract; UNBLOCKED by ADR-0018 acceptance via delta #13 already, but the executor must ship for runtime usage).
