# ADR-0018: Destiny Branch (DestinyBranchJudge + DestinyBranchChoice)

## Status
Accepted (2026-05-04, via `/architecture-review` delta #13 — combined session: ADR-0018 escalation Proposed → Accepted same-day fresh-session per same-session-ban discipline + structural append 15 net-new TR-destiny-branch entries; resolves 1 BLOCKING cross-ADR integration conflict via same-patch ADR-0017 line 209 instance-form widening + 1 ADVISORY C-2 residual same-patch fix per godot-specialist 16th invocation. ADR-0001 5-field PROVISIONAL → 9-field RATIFIED minor amendment landed same-patch per Evolution Rule #4. destiny-branch GDD §F-DB-1 7 wording flips landed same-patch per Migration Plan §1. **3rd consecutive same-day-fresh-session escalation pattern** after delta #11 + #12; **8th invocation of PROVISIONAL signal ratification pattern**; **1st invocation of `RefCounted pure-function class with @abstract test seam` pattern** in the project.)

## Date
2026-05-04

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (gameplay logic / formula evaluator) |
| **Knowledge Risk** | HIGH (Godot 4.6 is post-LLM-cutoff; relevant deltas verified below) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `design/gdd/destiny-branch.md` (rev 1.3.1; CR-DB-1..12, F-DB-1..4, EC-DB-1..17, AC-DB bucket-by-bucket coverage), `design/gdd/scenario-progression.md` (CR-3, CR-5, CR-6, CR-7, CR-13, CR-14, CR-15, F-SP-1, F-SP-2, F-SP-3 v2.2), `docs/architecture/ADR-0001-gamebus-autoload.md` (`destiny_branch_chosen` Scenario-domain slot — PROVISIONAL 5-field shape ratified to 9-field by this ADR), `docs/architecture/ADR-0017-scenario-progression.md` (Accepted 2026-05-04 via /architecture-review delta #12 — `_enter_beat_7_judgment` synchronous seal + 4-arg `DestinyBranchJudge.resolve()` call site), `docs/architecture/ADR-0014-grid-battle-controller.md` (`battle_outcome_resolved(BattleOutcome)` GameBus emission), `docs/architecture/ADR-0003-save-load.md` (CP-2 / CP-3 timing anchors). |
| **Post-Cutoff APIs Used** | `@abstract` annotation on `_apply_f_sp_1` test seam (GDScript 4.5+ feature per breaking-changes.md row 30 + deprecated-apis.md NOTE: prior to 4.5 abstract behavior was emulated via `assert(false, "must override")`; per godot-4x-gotchas G-22, `@abstract` is parse-time enforced on **typed references only** — reflective `load(path).new()` bypasses; verification uses the structural-source-file assertion pattern, see V-5). `Resource.duplicate_deep()` — Godot 4.5+ explicit deep-duplication API mentioned only as a consumer-side option for downstream archiving (NOT used inside DestinyBranchJudge itself; the parameterless form `duplicate_deep()` is the verified-name signature in `breaking-changes.md`; subscribers may use it via ADR-0001 §6 deep-duplication latitude). The `DEEP_DUPLICATE_ALL` deep-mode flag constant referenced in earlier ADR drafts is **NOT verified in the pinned engine-reference docs** — consumers SHOULD prefer the parameterless `duplicate_deep()` form until reference docs codify the constant set. |
| **Verification Required** | (1) `class_name DestinyBranchChoice extends Resource` with `@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS` parses and `ResourceSaver.save()`/`ResourceLoader.load()` round-trips on **all 5 export targets** (Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan) with `StringName` field-type preservation (closes destiny-branch GDD OQ-DB-6 BLOCKING-for-VS gate). (2) `@abstract` `_apply_f_sp_1` fails parse with explicit error if a concrete subclass forgets to override — verify via deliberate stub-failure test (`tests/unit/destiny_branch/destiny_branch_judge_abstract_failure_test.gd`). (3) Two simultaneous `DestinyBranchJudge.new()` instances on `WorkerThreadPool` produce field-identical payloads from identical inputs (CR-DB-11 determinism + EC-DB-17 thread safety verification). (4) CI lint `lint_destiny_branch_judge_no_static_var.sh` rejects `static var` declarations in `destiny_branch_judge.gd` AND any subclass file (EC-DB-17 architectural lock). (5) Grep lint `lint_destiny_branch_judge_no_gamebus_emit.sh` rejects any `GameBus.*\.emit` site in `destiny_branch_judge.gd` (CR-DB-4 emission ownership lock). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0017 Scenario Progression** (Accepted 2026-05-04 via /architecture-review delta #12) — defines `ChapterDefinition` typed Resource (the type passed as `chapter` parameter to `resolve()`), `ScenarioRunner._enter_beat_7_judgment()` synchronous call site (line 200, 4-arg form), F-SP-3 v2.2 first_attempt_resolved sealing invariant. **ADR-0001 GameBus** (Accepted 2026-04-18) — `destiny_branch_chosen` Scenario-domain signal slot; this ADR ratifies the 9-field payload shape per ADR-0001 §Evolution Rule #4 (minor amendment, NOT supersession). **ADR-0014 Grid Battle Controller** (Accepted) — `BattleOutcome` typed Resource emission contract on GameBus `battle_outcome_resolved(BattleOutcome)`; carries `Result` enum {WIN=0, DRAW=1, LOSS=2} consumed as input to `resolve()`. |
| **Enables** | **Beat 7 Vertical Slice** — Beat 7 ceremonial-witness reveal (Pillar 2 mechanical expression) cannot ship without `DestinyBranchJudge.resolve()` + `DestinyBranchChoice` payload. **ADR-0017 §Migration Plan §1** — ScenarioRunner `_enter_beat_7_judgment()` is callable end-to-end at sprint-7+ implementation patch. **Story Event #10 VS / Destiny State #16 VS / Save/Load #17 VS** — three downstream VS GDDs are unblocked from design start once this ADR is Accepted (each has BLOCKING gate on `DestinyBranchChoice` 9-field shape ratification + invalid-path emission contract per destiny-branch GDD §Bidirectional Updates). |
| **Blocks** | **destiny-branch implementation story** (sprint-7+ scope) — cannot open until this ADR Accepted + ADR-0001 minor amendment landed. **Story Event #10 VS design start** — destiny-branch §Bidirectional row marks this as BLOCKING for #10 VS open + Beat 8 canonical-history enforcement keys on `is_canonical_history` payload field defined here. **Destiny State #16 VS design start** — same gate (echo-archive maintenance keys on `echo_count` + `is_draw_fallback`). **Save/Load #17 VS design start** — same gate (`ChapterResult.branch_triggered` populated from `DestinyBranchChoice.branch_key`). |
| **Ordering Note** | This ADR is authored after ADR-0017 because ADR-0017 owns the F-SP-1 / F-SP-2 *formula spec* (callable signature, behavior, edge cases) and the call site (`_enter_beat_7_judgment` synchronous block at BEAT_7_JUDGMENT entry). ADR-0018 owns the *executor class* (DestinyBranchJudge) and the *typed payload* (DestinyBranchChoice). The dependency is one-way ADR-0017 → ADR-0018; ADR-0018 inherits the 4-arg `resolve(chapter, outcome, echo_count, first_attempt_resolved)` signature from ADR-0017 line 200 + scenario-progression CR-7 (the GDD §F-DB-1 3-arg form is corrected same-patch — see Migration Plan §3 GDD Sync Patch). The ADR-0001 amendment is a *minor amendment* (Evolution Rule #4), not supersession, and is co-merged in the same patch as this ADR's Acceptance. |

## Context

### Problem Statement

The Destiny Branch System (운명 분기) — designed in `design/gdd/destiny-branch.md` (rev 1.3.1, APPROVED) — is the short-lived judgment module that decides, at one moment per chapter (Beat 7 tap exit), which of the chapter's pre-authored branches the scenario takes. It is the load-bearing **mechanical expression of Pillar 2 (운명은 바꿀 수 있다)** in the MVP — the moment where the player observes that history just took a different path because of what they did, without ever seeing a branch menu.

ADR-0017 Scenario Progression (Accepted 2026-05-04) defined the call site (`ScenarioRunner._enter_beat_7_judgment` synchronous block) and delegated F-SP-1 / F-SP-2 execution to "DestinyBranchJudge per ADR-0018 boundary" (ADR-0017 line 200). This ADR closes that boundary by defining:

1. **The executor class** — what `DestinyBranchJudge` is (a `RefCounted` pure-function class, NOT a Node, NOT an autoload, NOT a static utility module).
2. **The typed payload** — the **9-field** `DestinyBranchChoice extends Resource` shape, ratifying ADR-0001's PROVISIONAL 5-field slot per Evolution Rule #4.
3. **The cross-ADR signature** — the 4-arg `resolve(chapter, outcome, echo_count, first_attempt_resolved) → DestinyBranchChoice` signature inherited from ADR-0017 line 200 + scenario-progression CR-7 (passed-as-fourth-argument invariant). The destiny-branch GDD §F-DB-1 3-arg form is corrected same-patch (Migration Plan §3 GDD Sync Patch).
4. **The test seam** — `@abstract func _apply_f_sp_1(...) -> Dictionary` (Godot 4.5+ annotation) for headless-test injection of F-SP-1 outputs without monkey-patching scenario-progression code.
5. **The invalid-path contract** — 12-entry `invariant_violation:*` `StringName` vocabulary + `static func invalid(reason: StringName) -> DestinyBranchChoice` factory; ScenarioRunner emits unconditionally (preserving AC-SP-17 exactly-one-emission contract); downstream consumers MUST gate content reads on `is_invalid == false` per BLOCKING per-field contract (destiny-branch §Bidirectional rev 1.2 D1).
6. **The cross-doc constraints** — `BattleOutcome` MUST be a top-level `class_name BattleOutcome` (NOT inner class) for `@export var outcome: BattleOutcome.Result = ...` parse-time resolution per Godot 4.6 global class registry (destiny-branch GDD rev 1.2 B-7); coordinates with grid-battle v5.0 GDD revision.

Without this ADR, the executor class and payload shape are PROVISIONAL across multiple documents (ADR-0001 §3 marks the slot PROVISIONAL; ADR-0017 line 200 declares the call site without pinning the executor class; the GDD describes the algorithm but does not bind to architecture). Three downstream VS GDDs (#10 Story Event, #16 Destiny State, #17 Save/Load) are blocked from design start by this ratification gate. ScenarioRunner's `_enter_beat_7_judgment` cannot be implemented at sprint-7+ patch without the executor class binding.

### Constraints

**Technical (engine-pinned per Godot 4.6 reference docs):**

- `RefCounted` is the correct base for a pure-function transient executor (no scene-tree presence; no `_ready` / `_exit_tree`; lifecycle is RAII via Godot's reference counting).
- `Resource` is the correct base for the typed payload (round-trips through `ResourceSaver.save` / `ResourceLoader.load` per ADR-0001 §V-3 cross-scene serialization contract).
- `@abstract` annotation requires Godot 4.5+ — verified present in pinned 4.6 (breaking-changes.md row "GDScript / `@abstract` decorator / Abstract classes and methods now enforceable" — 4.4 → 4.5 row). PRE-4.5 emulation pattern (`assert(false, "must override")`) is rejected per current-best-practices.md typed-priority.
- `BattleOutcome.Result` typed-enum `@export` default value `BattleOutcome.Result.LOSS` resolves at Resource script parse time via the Godot 4.6 global class registry. Inner-class declarations are NOT resolvable at parse time and would silently break `ResourceLoader.load()` for any saved `DestinyBranchChoice` (destiny-branch GDD rev 1.2 B-7). REQUIRES `class_name BattleOutcome` declared as top-level in its own script — coordinated with grid-battle v5.0 GDD revision (cross-doc constraint, see Migration Plan §4).
- `static var` is FORBIDDEN in `destiny_branch_judge.gd` and any subclass thereof (EC-DB-17 thread-safety guarantee). CI lint enforces.
- `OS.get_ticks_msec()` is deprecated per `deprecated-apis.md`; not used by this ADR (judge is wall-clock-independent per CR-DB-11 determinism).
- `Resource.duplicate(true)` for nested Resources is deprecated per `deprecated-apis.md` (4.5+); NOT used by judge (judge does not duplicate; consumers may duplicate for archiving via the parameterless `duplicate_deep()` form per `breaking-changes.md` 4.4→4.5 row — the `Resource.DEEP_DUPLICATE_ALL` deep-mode flag constant is **NOT verified in pinned engine-reference docs**, so consumers SHOULD prefer the parameterless form per §Engine Compatibility row reconciliation).
- Untyped `Dictionary[K, V]` typed-`@export` is NOT supported at GDScript 4.6 `@export` boundary (godot-4x-gotchas G-3 + ADR-0017 godot-specialist fix). The judge's F-SP-1 seam returns `Dictionary` (untyped) per design — its 3 required keys are validated at runtime per F-DB-1 step 3a/3b.

**Architecture-registry constraints (read from `docs/registry/architecture.yaml` v11):**

- **`scenario_runner_outcome_synthesis` forbidden_pattern (line 1859)** — ScenarioRunner MUST NOT assign or override `BattleOutcome.result`. Mirrored at this ADR: DestinyBranchJudge MUST NOT either (CR-DB-2 pure function; no external state mutation). Reaffirmed in this ADR's Decision §Determinism contract.
- **`battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern (line 1779)** — Pillar 2 architectural lock: HUD MUST NEVER subscribe to `hidden_fate_condition_progressed`. DestinyBranchJudge is the SOLE consumer per ADR-0014 line 335 + destiny-branch GDD §B. Cross-ref preserved in this ADR.
- **GameBus single-emitter rule** (per ADR-0001 + reaffirmed across `*_must_emit_only_*` patterns at lines 1606 / 1643 / 1681) — DestinyBranchJudge MUST NOT emit any GameBus signal directly (CR-DB-4 emission lives in ScenarioRunner). New forbidden_pattern proposed: `destiny_branch_judge_emits_gamebus_signal` (defense-in-depth lint).
- **ADR-0017 `scenario_runner_deferred_seal_in_beat_7_entry` forbidden_pattern (line 24 of delta #12 extract)** — F-SP-3 v2.2 invariant: synchronous seal at BEAT_7 entry. Consumed by this ADR: the `first_attempt_resolved` value passed to `resolve()` is the **already-sealed** value, NOT a value that judge may read or mutate. Reaffirmed via Decision §Determinism contract + new forbidden_pattern `destiny_branch_judge_reads_scenario_runner_state`.

**Performance budget:**

- `resolve()` is O(1) per call: one `chapter.branch_table` Dictionary lookup (F-SP-1 via seam) + a constant number of bool / String comparisons + 9 `@export` field assignments on the `DestinyBranchChoice` Resource. Total execution budget is a tiny fraction of the 16.6 ms frame budget — measured single-call execution time SHOULD be well under 0.1 ms on the reference mobile (mid-tier Android), within the destiny-branch GDD §Performance bucket §AC-DB-37 0.5 ms upper bound.
- `DestinyBranchJudge.new()` allocation cost: one `RefCounted` allocation per chapter (so ~5 allocations per scenario MVP scope). Negligible vs. typical scene-load allocation churn.
- `DestinyBranchChoice.new()` allocation cost: one `Resource` allocation per chapter, owned by ScenarioRunner via `_last_branch_choice` reference + emitted to GameBus via deferred-dispatch + lifetime extends through Beat 9 commit at minimum. Memory: ~9 × 8B (worst-case 64-bit pointer/int sizes per @export field) + Resource overhead ≈ <200B per instance. Negligible.

**Compatibility requirements:**

- `DestinyBranchChoice` `ResourceSaver`/`ResourceLoader` round-trip MUST preserve `StringName` field type for `invalid_reason` field on all 5 export targets (Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan) — closes destiny-branch GDD §F-DB-4 OQ-DB-6 (BLOCKING for VS-implementation-story open).
- `@abstract` `_apply_f_sp_1` must fail parse if a concrete subclass forgets to override — verified at parse time, NOT at runtime, per Godot 4.5+ contract (current-best-practices.md `@abstract` row).
- `BattleOutcome.Result` enum value reordering (e.g., `WIN=0` → `WIN=2` in some future Grid Battle revision) MUST trigger DestinyBranchChoice serialization compatibility check — `@export` of typed enums stores the integer value, so reordering breaks save compatibility silently. Mitigation: `BattleOutcome.Result` enum order is locked at Grid Battle v5.0 GDD revision (cross-doc); SaveMigrationRegistry per ADR-0003 covers schema evolution if reordering is ever needed.

### Requirements

- **Must execute** F-SP-1 (resolve_branch) per scenario-progression.md §F-SP-1 owner = scenario-progression / executor = DestinyBranchJudge — at BEAT_7_JUDGMENT entry (synchronous; called from `ScenarioRunner._enter_beat_7_judgment` per ADR-0017 line 209).
- **Must NOT execute** F-SP-2 (is_echo_gate_open) directly inside `resolve()` — F-SP-2 is invoked WITHIN F-SP-1 per scenario-progression's algorithm; the seam exposed by this ADR (`_apply_f_sp_1`) is the single integration point.
- **Must accept** the 4-arg form `resolve(chapter: ChapterDefinition, outcome: BattleOutcome.Result, echo_count: int, first_attempt_resolved: bool) -> DestinyBranchChoice` — matching ADR-0017 line 200 + scenario-progression CR-7 4th-argument invariant.
- **Must assemble** the 9-field `DestinyBranchChoice` payload per F-DB-4 schema (chapter_id / branch_key / outcome / echo_count / is_draw_fallback / is_canonical_history / reserved_color_treatment / is_invalid / invalid_reason).
- **Must enforce** the 7 invariants per F-DB-4 footer (`is_invalid == true` ⟹ downstream gates; `is_invalid == false` ⟺ `invalid_reason == &""`; `is_draw_fallback == true` ⟹ `outcome == DRAW`; `reserved_color_treatment == true` ⟹ branch_key != default AND not invalid AND not fallback) — at assembly time, before return.
- **Must surface** invariant violations through the 12-entry `invariant_violation:*` StringName vocabulary (F-DB-3) via `static func invalid(reason: StringName) -> DestinyBranchChoice` factory.
- **Must be deterministic** — no RNG, no wall-clock dependency, no class-level state (`static var` forbidden), no instance-level state across calls (CR-DB-2 + CR-DB-11). Identical inputs → field-identical output.
- **Must NOT emit** any GameBus signal — CR-DB-4 emission lives in ScenarioRunner. Lint-enforced.
- **Must NOT mutate** the `chapter` argument or any external state — pure function (CR-DB-2). Lint-advisory.
- **Must remain stateless** — no caching of prior calls' results; no observable state between calls (CR-DB-3 transient-per-call lifecycle).
- **Must round-trip** through `ResourceSaver`/`ResourceLoader` on all 5 export targets per ADR-0001 §V-3 cross-scene serialization contract (closes OQ-DB-6).
- **Must thread-safely** support concurrent `resolve()` calls from independent `DestinyBranchJudge.new()` instances (EC-DB-17). Achieved by construction (no class-level state) — verified by lint.
- **Must ratify** ADR-0001's PROVISIONAL `destiny_branch_chosen` 5-field shape to the 9-field shape per Evolution Rule #4 (minor amendment, same-patch).

## Decision

Define **DestinyBranchJudge** as a `RefCounted` pure-function class with a single public method `resolve(chapter, outcome, echo_count, first_attempt_resolved) -> DestinyBranchChoice` and an `@abstract` test seam `_apply_f_sp_1(chapter, outcome, echo_count, first_attempt_resolved) -> Dictionary`. Define **DestinyBranchChoice** as a `class_name DestinyBranchChoice extends Resource` with 9 typed `@export` fields and a `static func invalid(reason: StringName) -> DestinyBranchChoice` factory. ScenarioRunner constructs `DestinyBranchJudge.new()` at BEAT_7_JUDGMENT tap exit, calls `resolve()` synchronously (one call per chapter — CR-DB-5 + CR-DB-7), captures the returned `DestinyBranchChoice`, and emits `destiny_branch_chosen(choice)` on GameBus per ADR-0001. The judge is discarded immediately (RefCounted scope drop). ADR-0001 is amended same-patch to ratify the 9-field payload shape (Evolution Rule #4 minor amendment, PROVISIONAL count 4 → 3). The destiny-branch GDD §F-DB-1 algorithm is corrected same-patch from the legacy 3-arg form to the 4-arg form (Migration Plan §3 GDD Sync Patch). Grid Battle v5.0 GDD revision declares `BattleOutcome` as a top-level `class_name` (cross-doc Migration Plan §4).

### Class Form: `DestinyBranchJudge` extends `RefCounted` (pure-function transient)

`RefCounted` is the base. Justifications:

1. **No scene-tree presence required** — judge does no rendering, no input handling, no `_process` work. `Node` would be misleading and would trigger `_ready` / `_exit_tree` / signal-disconnect hygiene we do not need.
2. **No autoload required** — judge holds no persistent state (CR-DB-3 transient-per-call); autoload would introduce singleton coupling + confuse lifecycle ownership (the judge is alive for one synchronous call between `judge.resolve(...)` invocation and the next statement). Autoload form is REJECTED in §Alternatives Considered §3.
3. **`RefCounted` lifecycle is RAII** — Godot's reference counting frees the instance at scope exit when the local `var judge` reference goes out of scope. No explicit `queue_free()` / `free()` needed; no risk of leaks.
4. **`RefCounted` is the correct base for "Resource-adjacent ephemeral objects"** — matches the Godot 4.6 idiom for pure-function helpers that operate on `Resource` data without needing scene presence.
5. **Test fixture form** — GdUnit4 tests can construct `DestinyBranchJudge.new()` directly without any scene-tree / autoload setup; tests run in a single invocation per `_test_*` method per AC-DB bucket.
6. **Substitutability** — future Ch4+ may introduce alternative branch resolution (e.g., echo-gated for ALL outcomes, not just DRAW); replacing the executor is a class swap at ScenarioRunner's construction site, not a system-wide refactor.

```gdscript
# src/feature/destiny_branch/destiny_branch_judge.gd
# NO `class_name` declaration — DestinyBranchJudge IS a class_name (registered globally
# via class_name keyword below; this is NOT an autoload, so the autoload + class_name
# collision rule from godot-4x-gotchas G-3 does NOT apply). The 5 autoloads (GameBus +
# SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel) and the 6th
# (ScenarioRunner per ADR-0017) deliberately omit class_name because their global
# identifier is established by autoload registration. DestinyBranchJudge is NOT an
# autoload — it must be globally addressable via class_name to be constructable from
# ScenarioRunner without absolute-path preload.
class_name DestinyBranchJudge
extends RefCounted

@abstract
func _apply_f_sp_1(
    chapter: ChapterDefinition,
    outcome: BattleOutcome.Result,
    echo_count: int,
    first_attempt_resolved: bool,
) -> Dictionary:
    # Concrete subclass MUST override; base implementation never runs.
    pass

func resolve(
    chapter: ChapterDefinition,
    outcome: BattleOutcome.Result,
    echo_count: int,
    first_attempt_resolved: bool,
) -> DestinyBranchChoice:
    # F-DB-1 algorithm (transcribed from destiny-branch GDD §F-DB-1; same-patch GDD
    # update at Migration Plan §3 corrects the GDD's legacy 3-arg signature to the
    # 4-arg form ratified here per ADR-0017 line 200 + scenario-progression CR-7).

    # Step 1: Invariant checks (CR-DB-10) — see F-DB-3 for invalid_reason vocabulary
    if chapter == null:
        push_error("DestinyBranchJudge: chapter is null")
        return DestinyBranchChoice.invalid(&"invariant_violation:chapter_null")
    if chapter.chapter_id == "":
        push_error("DestinyBranchJudge: chapter.chapter_id empty")
        return DestinyBranchChoice.invalid(&"invariant_violation:chapter_id_missing")
    if chapter.canonical_branch_key == "":
        # Note: ADR-0017 ChapterDefinition uses `canonical_branch_key` field name;
        # destiny-branch GDD §F-DB-1 used legacy `default_branch_key` — same field,
        # name reconciled to ADR-0017 form per cross-doc resolution (this ADR is the
        # authoritative source going forward; GDD §F-DB-1 patched same-patch §Migration
        # Plan §3). Semantic: "the chapter's pre-authored DEFAULT branch key —
        # Pillar 4 canonical 演義 row when no divergence applies".
        push_error("DestinyBranchJudge: chapter.canonical_branch_key empty")
        return DestinyBranchChoice.invalid(&"invariant_violation:default_branch_key_missing")
    if chapter.branch_table == null or not (chapter.branch_table is Dictionary):
        push_error("DestinyBranchJudge: chapter.branch_table null or non-Dictionary")
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_table_null_or_malformed")
    if chapter.branch_table.is_empty():
        push_error("DestinyBranchJudge: chapter.branch_table is empty Dictionary")
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_table_empty")
    # Pillar 4 zero-canonical / multi-canonical warning (NOT is_invalid; ship proceeds)
    var canonical_row_count: int = 0
    for row_key in chapter.branch_table:
        var row: Variant = chapter.branch_table[row_key]
        if row is Dictionary and row.get("is_canonical_history", false):
            canonical_row_count += 1
    if canonical_row_count == 0:
        push_warning("DestinyBranchJudge: chapter %s has ZERO canonical rows (Pillar 4 drift)" % chapter.chapter_id)
    elif canonical_row_count > 1:
        push_warning(
            "DestinyBranchJudge: chapter %s has %d canonical rows (Pillar 4 requires exactly one)"
            % [chapter.chapter_id, canonical_row_count]
        )
    if not int(outcome) in BattleOutcome.Result.values():
        push_error("DestinyBranchJudge: outcome enum value %d invalid" % int(outcome))
        return DestinyBranchChoice.invalid(&"invariant_violation:outcome_unknown")
    if chapter.chapter_number == 1 and chapter.has_echo_threshold():
        push_error("DestinyBranchJudge: Ch1 echo_threshold violates CR-13")
        return DestinyBranchChoice.invalid(&"invariant_violation:cr13_echo_threshold_on_ch1")

    # Step 2: Warning-severity clamp (not invalidating)
    if echo_count < 0:
        push_warning("DestinyBranchJudge: echo_count clamped from %d to 0" % echo_count)
        echo_count = 0

    # Step 3: Execute F-SP-1 via overridable seam _apply_f_sp_1 (test-injection point)
    var f_sp_1: Dictionary = _apply_f_sp_1(chapter, outcome, echo_count, first_attempt_resolved)
    # 3a. Key-presence guard (required-key set is the contract with F-SP-1)
    if (
        f_sp_1.is_empty()
        or not f_sp_1.has("branch_key")
        or not f_sp_1.has("is_draw_fallback")
        or not f_sp_1.has("is_canonical_history")
    ):
        push_error("DestinyBranchJudge: F-SP-1 output missing required key(s)")
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_table_missing_outcome")
    # 3b. Type guards (defense-in-depth; parentheses MANDATORY per godot-gdscript-specialist B-5)
    if not (f_sp_1["branch_key"] is String):
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_key_type_invalid")
    if not (f_sp_1["is_draw_fallback"] is bool):
        return DestinyBranchChoice.invalid(&"invariant_violation:is_draw_fallback_type_invalid")
    if not (f_sp_1["is_canonical_history"] is bool):
        return DestinyBranchChoice.invalid(&"invariant_violation:is_canonical_history_type_invalid")
    # 3c. Cross-field invariant: is_draw_fallback == true ⟹ outcome == DRAW (F-DB-4 invariant)
    if f_sp_1["is_draw_fallback"] and outcome != BattleOutcome.Result.DRAW:
        push_error(
            "DestinyBranchJudge: is_draw_fallback=true requires outcome=DRAW; got %d"
            % int(outcome)
        )
        return DestinyBranchChoice.invalid(&"invariant_violation:is_draw_fallback_outcome_mismatch")

    # Step 4: Derive reserved_color_treatment per F-DB-2 / CR-DB-9
    var reserved_color: bool = (f_sp_1["branch_key"] != chapter.canonical_branch_key)
    # 4a. Fallback override: is_draw_fallback=true → reserved_color=false (F-DB-2 step 4a)
    if f_sp_1["is_draw_fallback"]:
        reserved_color = false

    # Step 5: Assemble payload (9 fields per F-DB-4)
    var choice := DestinyBranchChoice.new()
    choice.chapter_id = chapter.chapter_id
    choice.branch_key = f_sp_1["branch_key"]
    choice.outcome = outcome
    choice.echo_count = echo_count
    choice.is_draw_fallback = f_sp_1["is_draw_fallback"]
    choice.is_canonical_history = f_sp_1["is_canonical_history"]
    choice.reserved_color_treatment = reserved_color
    choice.is_invalid = false
    choice.invalid_reason = &""
    return choice
```

### Payload Form: `DestinyBranchChoice` extends `Resource` (typed Resource, 9 @export fields, `invalid()` factory)

```gdscript
# src/core/payloads/destiny_branch_choice.gd
class_name DestinyBranchChoice
extends Resource

@export var chapter_id: String = ""
@export var branch_key: String = ""
@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS
@export var echo_count: int = 0
@export var is_draw_fallback: bool = false
@export var is_canonical_history: bool = false
@export var reserved_color_treatment: bool = false
@export var is_invalid: bool = false
@export var invalid_reason: StringName = &""

static func invalid(reason: StringName) -> DestinyBranchChoice:
    var c := DestinyBranchChoice.new()
    c.is_invalid = true
    c.invalid_reason = reason
    return c
```

**Field schema** (per destiny-branch GDD F-DB-4):

| Field | Type | Range / Constraints | Source |
|---|---|---|---|
| `chapter_id` | String | Non-empty iff `is_invalid == false`; matches ScenarioRunner.current_chapter.chapter_id | `chapter.chapter_id` |
| `branch_key` | String | Non-empty iff `is_invalid == false`; member of `chapter.branch_table` keys | F-SP-1 output |
| `outcome` | `BattleOutcome.Result` (typed enum @export) | ∈ {WIN=0, DRAW=1, LOSS=2} | Passthrough from `BattleOutcome.result` |
| `echo_count` | int | ≥ 0 (negatives clamped to 0 with `push_warning`; clamped value propagates) | ScenarioRunner state at BEAT_7_JUDGMENT entry |
| `is_draw_fallback` | bool | true iff F-SP-1 applied DRAW → WIN fallback per scenario-progression CR-14 | F-SP-1 output |
| `is_canonical_history` | bool | true iff resolved branch upholds the canonical 演義 historical record (Pillar 4 enforcement at payload level) | F-SP-1 output (authored per branch-table row) |
| `reserved_color_treatment` | bool | Per F-DB-2; always false when `is_invalid == true` OR `is_draw_fallback == true` | CR-DB-9 + F-DB-2 step 4a |
| `is_invalid` | bool | true iff invariant violation detected | CR-DB-10 |
| `invalid_reason` | StringName | ∈ F-DB-3 vocabulary iff `is_invalid == true`; `&""` otherwise | F-DB-3 |

**Payload invariants** (asserted by tests; AC-DB-22 / AC-DB-23 / AC-DB-24):

1. `is_invalid == false` ⟺ `invalid_reason == &""`
2. `is_invalid == true` ⟹ downstream MUST NOT read `chapter_id`, `branch_key`, `outcome`, `is_canonical_history` for content selection (default values are convenience, not signal)
3. `is_draw_fallback == true` ⟹ `outcome == DRAW`
4. `reserved_color_treatment == true` ⟹ `branch_key != chapter.canonical_branch_key` AND `is_invalid == false` AND `is_draw_fallback == false`
5. `is_canonical_history` is INDEPENDENT of `reserved_color_treatment` (a default branch may or may not be canonical; a non-default branch likewise) — Beat 8 contrast keys on `is_canonical_history`, NOT on `reserved_color_treatment`

### Test Seam: `@abstract func _apply_f_sp_1(...) -> Dictionary`

Per destiny-branch GDD §F-DB-1 test-seam contract (rev 1.2 D3 + rev 1.3 `@abstract` annotation per gdscript B-3). The `_apply_f_sp_1` method is declared `@abstract` on the base class; concrete subclasses MUST override. The production judge that ScenarioRunner instantiates is itself a concrete subclass that delegates `_apply_f_sp_1` to scenario-progression's actual F-SP-1 implementation. Tests use `TestDestinyBranchJudgeWithSp1Stub` (lives in `tests/helpers/destiny_branch_judge_stub.gd`) to inject mock F-SP-1 outputs without monkey-patching scenario-progression code:

```gdscript
# tests/helpers/destiny_branch_judge_stub.gd
class_name TestDestinyBranchJudgeWithSp1Stub
extends DestinyBranchJudge

var _stub_output: Dictionary = {}

func set_sp1_output(output: Dictionary) -> void:
    _stub_output = output

func _apply_f_sp_1(
    _chapter: ChapterDefinition,
    _outcome: BattleOutcome.Result,
    _echo_count: int,
    _first_attempt_resolved: bool,
) -> Dictionary:
    return _stub_output
```

Why `@abstract` and not `virtual`-by-convention:

1. **Parse-time guard** — `@abstract` fails parse if a concrete subclass forgets to override; `virtual`-by-convention only fails at runtime when the empty base method returns an empty Dictionary, hiding the test-harness bug as `invariant_violation:branch_table_missing_outcome`.
2. **GDScript 4.5+ first-class language feature** — current-best-practices.md endorses `@abstract` for "subclass-must-override" intent; pre-4.5 emulation (`assert(false, "must override")`) is rejected.
3. **Linter clarity** — `@abstract` produces no `override-without-super` warnings (rev 1.2 wording "declared virtual" without annotation triggered such warnings in Godot 4.5+).
4. **Future maintenance** — if F-SP-1's required-key contract grows (e.g., a 4th key added in some future scenario-progression revision), the `@abstract` declaration's signature update propagates a parse-time error to every subclass, enforcing coordinated update.

### Production Subclass: `DefaultDestinyBranchJudge`

The production-time concrete subclass that delegates F-SP-1 to scenario-progression's authoritative implementation:

```gdscript
# src/feature/destiny_branch/default_destiny_branch_judge.gd
class_name DefaultDestinyBranchJudge
extends DestinyBranchJudge

func _apply_f_sp_1(
    chapter: ChapterDefinition,
    outcome: BattleOutcome.Result,
    echo_count: int,
    first_attempt_resolved: bool,
) -> Dictionary:
    # Delegate to scenario-progression's F-SP-1 authoritative implementation.
    # Per ADR-0017, F-SP-1 lives in `ScenarioFormulas` (a static GDScript with
    # @abstract = false; a class_name'd utility module). The seam exists so
    # tests can substitute mock output without touching scenario-progression.
    return ScenarioFormulas.resolve_branch(chapter, outcome, echo_count, first_attempt_resolved)
```

`ScenarioFormulas.resolve_branch(...)` is the authoritative F-SP-1 implementation owned by scenario-progression — its signature + behavior are scenario-progression's responsibility (ADR-0017 §F-SP-1 + §F-SP-2 spec ownership). This ADR ratifies only the *binding* between the executor class and the formula-spec module.

### Determinism Contract (CR-DB-11 + EC-DB-17)

DestinyBranchJudge MUST be deterministic and thread-safe-by-construction:

1. **No RNG** — no `randi()`, `randf()`, `randi_range()`, etc. inside `resolve()` or `_apply_f_sp_1()` chain.
2. **No wall-clock dependency** — no `Time.get_ticks_msec()`, `Time.get_unix_time_from_system()`, `OS.get_unix_time()`. Judge is timing-independent.
3. **No external state read** — no autoload access (`GameBus.X`, `SaveManager.X`, etc.); no scene-tree traversal (`get_tree()`); no `chapter` mutation; no static variables anywhere in the call chain.
4. **No instance-level state across calls** — judge is constructed, used once, discarded (CR-DB-3). Even if a test reuses an instance, no field is read between calls; behavior depends only on call arguments.
5. **No class-level state** — `static var` is FORBIDDEN in `destiny_branch_judge.gd` and any subclass thereof. EC-DB-17 thread safety guaranteed by construction. Lint-enforced at sprint-7+ patch.
6. **Identical inputs → field-identical output** — verified by AC-DB determinism fixtures (per-test-fixture assertion).

### Emission Ownership (CR-DB-4 — emission lives in ScenarioRunner)

DestinyBranchJudge MUST NOT emit any GameBus signal directly. Per CR-DB-4, the emission of `destiny_branch_chosen(DestinyBranchChoice)` is owned by ScenarioRunner's BEAT_7_JUDGMENT tap-exit handler:

```gdscript
# In ScenarioRunner._on_beat_7_judgment_tap_exit() (per ADR-0017 §State Machine):
func _on_beat_7_judgment_tap_exit() -> void:
    var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()
    var choice: DestinyBranchChoice = judge.resolve(
        _scenario_state.current_chapter,
        _last_battle_outcome.result,
        _scenario_state.echo_count,
        _scenario_state.first_attempt_resolved,
    )
    # CP-2 save BEFORE branch emit (AC-SP-17 ordering contract; both are emit() statements
    # which are synchronous per CR-DB-4 statement-order guarantee — emit() returns
    # immediately, deferred-dispatch to subscribers happens next idle frame, but emit()
    # call site ordering is preserved on the source thread).
    GameBus.save_checkpoint_requested.emit(_make_save_context_cp2())
    GameBus.destiny_branch_chosen.emit(choice)
    _last_branch_choice = choice
    # `judge` goes out of scope → RefCounted scope drop → memory reclaimed
    _transition_to(State.BEAT_8_REVEAL)
```

The judge is constructed and discarded WITHIN the tap-exit handler. The `DestinyBranchChoice` payload outlives the judge by reference (held by ScenarioRunner via `_last_branch_choice` + held by GameBus subscribers via deferred-dispatch).

Lint-enforced rules (proposed forbidden_patterns this ADR registers):

- `destiny_branch_judge_emits_gamebus_signal` — `grep -E 'GameBus\\..*\\.emit\\(' src/feature/destiny_branch/destiny_branch_judge.gd` AND `src/feature/destiny_branch/default_destiny_branch_judge.gd` MUST return 0 matches.
- `destiny_branch_judge_static_var` — `grep -E '^static var' src/feature/destiny_branch/destiny_branch_judge.gd` AND `src/feature/destiny_branch/default_destiny_branch_judge.gd` MUST return 0 matches.
- `destiny_branch_judge_reads_scenario_runner_state` — `grep -E 'ScenarioRunner\\.|_scenario_state\\.' src/feature/destiny_branch/destiny_branch_judge.gd` AND `default_destiny_branch_judge.gd` MUST return 0 matches (judge accesses inputs ONLY via the 4 `resolve()` parameters).

### ADR-0001 Minor Amendment: `destiny_branch_chosen` 5-field PROVISIONAL → 9-field RATIFIED

Per ADR-0001 Evolution Rule #4, this ADR ratifies the `destiny_branch_chosen` payload PROVISIONAL slot via minor amendment (NOT supersession). Same-patch changes to ADR-0001:

1. **Line 159** signal declaration: unchanged — `signal destiny_branch_chosen(choice: DestinyBranchChoice)` already typed.
2. **Line 315** Scenario-domain table row payload column: replace provisional 5-field list (`chapter_id: String, branch_key: String, revelation_cue_id: String, required_flags: Array[String], authored: bool`) with ratified 9-field list (`chapter_id: String, branch_key: String, outcome: BattleOutcome.Result, echo_count: int, is_draw_fallback: bool, is_canonical_history: bool, reserved_color_treatment: bool, is_invalid: bool, invalid_reason: StringName`); strip the `[PROVISIONAL — locked by Destiny Branch GDD #4]` marker; add ratification footnote `(RATIFIED 2026-05-04 via ADR-0018)`.
3. **Line 319** Pillar 2 note: rewrite — `revelation_cue_id` and `required_flags` and `authored` fields no longer exist; the new 9-field shape carries `is_canonical_history` for Pillar 4 contrast + `is_invalid` for invalid-path emission contract. Update note to: "Pillar 2 mechanical expression: `reserved_color_treatment` triggers V-DB-1 reserved-color reveal at Beat 7. Pillar 4 mechanical expression: `is_canonical_history` keys Beat 8 contrast (Story Event #10 VS). Invalid-path contract: `is_invalid == true` payloads ARE emitted (preserves AC-SP-17 exactly-one-emission); subscribers MUST gate content reads on `is_invalid == false`."
4. **Line 364** "shape TBD" entry: remove (shape is now ratified in ADR-0018).
5. **PROVISIONAL signal count**: ADR-0001 line 363-364 (per delta #12) currently records "3 PROVISIONAL signals" — decrement to 2 (one signal — `destiny_branch_chosen` — moves out of PROVISIONAL via this ADR's ratification). Add a new "PROVISIONAL → RATIFIED 2026-05-04 via ADR-0018" subsection mirroring delta #12's `scenario_beat_retried` ratification format.
6. **BattleOutcome top-level class_name note**: add a one-paragraph cross-doc constraint note in ADR-0001's Scenario domain section: "BattleOutcome MUST be declared as a top-level `class_name BattleOutcome` in its own script file (NOT as inner class) to satisfy DestinyBranchChoice @export parse-time resolution per ADR-0018 §Engine Compatibility row 'Verification Required'. Cross-doc constraint coordinated with grid-battle v5.0 GDD revision."

### Architecture Diagram

```
                  ┌────────────────────────────────────────────────────────────┐
                  │              GameBus (autoload, ADR-0001)                  │
                  │  destiny_branch_chosen(DestinyBranchChoice)  RATIFIED 9-fld│
                  └─────────┬──────────────────────────────────┬───────────────┘
                            │ emits (CR-DB-4)                  │ subscribes (CONNECT_DEFERRED)
                            │                                  │
        ┌───────────────────▼──────────────────┐               │
        │   ScenarioRunner (autoload, ADR-0017)│               │
        │   ┌─────────────────────────────────┐│               │
        │   │ _on_beat_7_judgment_tap_exit()  ││               │
        │   │  ├─ judge := DefaultDBJ.new()   ││               │
        │   │  ├─ choice := judge.resolve(    ││               │
        │   │  │    chapter,                  ││               │
        │   │  │    outcome,                  ││               │
        │   │  │    echo_count,               ││               │
        │   │  │    first_attempt_resolved,   ││               │
        │   │  │  )                           ││               │
        │   │  ├─ emit save_checkpoint(...)   ││──CP-2────────►│
        │   │  ├─ emit destiny_branch_chosen ─││──9-fld──────► │
        │   │  └─ judge → RefCounted drop     ││               │
        │   └─────────────────────────────────┘│               │
        └──────────────────────────────────────┘               │
                            ┌──────────────────────────────────┴────────────┐
                            │                                                │
         ┌──────────────────▼─────────────────┐    ┌────────────────────────▼────┐
         │    DestinyBranchJudge (RefCounted) │    │    Story Event #10 VS       │
         │    (this ADR — ADR-0018)           │    │    Destiny State #16 VS     │
         │  ┌──────────────────────────────┐  │    │    Save/Load #17 VS         │
         │  │ resolve(c, o, ec, far)       │  │    │    (downstream consumers;   │
         │  │  ├─ Step 1 invariant checks  │  │    │     PROVISIONAL gate on     │
         │  │  │   (CR-DB-10; 12 paths)    │  │    │     is_invalid==false)      │
         │  │  ├─ Step 2 echo_count clamp  │  │    └─────────────────────────────┘
         │  │  ├─ Step 3 _apply_f_sp_1     │  │
         │  │  │   (test seam @abstract)   │  │           ┌────────────────────────┐
         │  │  ├─ Step 3a/3b/3c guards     │  │           │  ScenarioFormulas      │
         │  │  ├─ Step 4 reserved_color    │  │           │  .resolve_branch(...)  │
         │  │  └─ Step 5 assemble payload  │  │           │  (ADR-0017 owned —     │
         │  │       (9 @export fields)     │  │           │   F-SP-1 authoritative)│
         │  └──────────────────────────────┘  │           └────────────────────────┘
         │                                    │                       ▲
         │  Concrete subclass:                │                       │
         │  DefaultDestinyBranchJudge         │                       │
         │  (overrides _apply_f_sp_1 to       │───── delegates ───────┘
         │   delegate to ScenarioFormulas)    │
         └────────────────────────────────────┘

         ┌────────────────────────────────────┐
         │  DestinyBranchChoice (Resource)    │
         │  9 @export fields:                 │
         │  • chapter_id: String              │
         │  • branch_key: String              │
         │  • outcome: BattleOutcome.Result   │
         │  • echo_count: int                 │
         │  • is_draw_fallback: bool          │
         │  • is_canonical_history: bool      │
         │  • reserved_color_treatment: bool  │
         │  • is_invalid: bool                │
         │  • invalid_reason: StringName      │
         │                                    │
         │  static func invalid(reason)       │
         │  → DestinyBranchChoice             │
         │  (12-entry F-DB-3 vocabulary)      │
         └────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# === Public API surface (this ADR) ===

# src/feature/destiny_branch/destiny_branch_judge.gd
class_name DestinyBranchJudge
extends RefCounted

@abstract
func _apply_f_sp_1(
    chapter: ChapterDefinition,
    outcome: BattleOutcome.Result,
    echo_count: int,
    first_attempt_resolved: bool,
) -> Dictionary

func resolve(
    chapter: ChapterDefinition,
    outcome: BattleOutcome.Result,
    echo_count: int,
    first_attempt_resolved: bool,
) -> DestinyBranchChoice

# src/feature/destiny_branch/default_destiny_branch_judge.gd
class_name DefaultDestinyBranchJudge
extends DestinyBranchJudge
# Concrete subclass; production-time judge.

# src/core/payloads/destiny_branch_choice.gd
class_name DestinyBranchChoice
extends Resource
# 9 @export fields per Decision §Payload Form.

static func invalid(reason: StringName) -> DestinyBranchChoice

# === Test fixture (lives under tests/) ===

# tests/helpers/destiny_branch_judge_stub.gd
class_name TestDestinyBranchJudgeWithSp1Stub
extends DestinyBranchJudge

func set_sp1_output(output: Dictionary) -> void
# Used by AC-DB-20c/20d/20e + EC-DB-16 fixtures.
```

**API decisions** (registered):

| Decision | Choice | Rejected Alternative |
|----------|--------|----------------------|
| Class form | `extends RefCounted` | `extends Node` (rejected — no scene-tree need); autoload (rejected — no persistent state, see §Alternatives §3) |
| Test seam shape | `@abstract func _apply_f_sp_1` (Godot 4.5+) | `virtual`-by-convention with empty base + `assert(false)` (rejected — pre-4.5 emulation; not parse-time enforced) |
| Resolve signature | 4-arg `(chapter, outcome, echo_count, first_attempt_resolved)` (matches ADR-0017 line 200 + scenario-progression CR-7) | 3-arg form per legacy GDD §F-DB-1 (rejected — first_attempt_resolved is ScenarioRunner state, not chapter state; would require external-state read inside judge violating CR-DB-2 purity) |
| Payload form | `Resource` with 9 typed `@export` fields | Untyped `Dictionary` payload (rejected — loses Pillar-4 `is_canonical_history` payload-level enforcement); inner-class `DestinyBranchChoice` (rejected — `BattleOutcome.Result` @export default cannot resolve at parse time per destiny-branch B-7) |
| `invalid_reason` type | `StringName` (12-entry vocabulary) | `String` (rejected — StringName is interned + faster equality; matches `&` literal idiom); `enum InvalidReason { ... }` (rejected — extending the vocabulary requires recompilation; StringName allows test-fixture additions without source-change) |
| Production subclass form | `DefaultDestinyBranchJudge` named subclass + delegation to `ScenarioFormulas.resolve_branch` | Concrete `DestinyBranchJudge` (no abstract) + monkey-patch in tests (rejected — fragile + unsupported); single-class with conditional `if Engine.is_editor_hint()` branching (rejected — tests run in same context as production; conditional pollutes hot path) |
| ADR-0001 amendment shape | Same-patch minor amendment (Evolution Rule #4) ratifying 9-field shape | Supersession (rejected — disproportionate; ratifying a PROVISIONAL slot is intended use of Evolution Rule #4) |
| Cross-ADR signature reconciliation | Path A — same-patch GDD F-DB-1 update to 4-arg form | Path B — revert ADR-0017 to 3-arg form (rejected — inverts delta #12 acceptance + violates CR-7); Path C — read first_attempt_resolved from ScenarioRunner autoload (rejected — violates CR-DB-2 purity) |

## Alternatives Considered

### Alternative 1: Inline F-SP-1 / F-SP-2 in ScenarioRunner (No DestinyBranchJudge Class)

- **Description**: ScenarioRunner directly executes F-SP-1 + F-SP-2 inside `_on_beat_7_judgment_tap_exit()`; `DestinyBranchChoice` is constructed inline; no separate `DestinyBranchJudge` class.
- **Pros**: Smaller LoC footprint; no class hierarchy; one less file.
- **Cons**: F-SP-1 logic (~100 LoC of branch-table lookup + invariant checks + payload assembly) inflates ScenarioRunner past its 13-state-machine focus; F-SP-1 unit tests would require ScenarioRunner-state setup (fixture cost ~10× higher than RefCounted construction); future executor swap (Ch4+ alternative branch resolution) would require ScenarioRunner edit, not class swap; violates Single Responsibility — ScenarioRunner becomes both state-machine + formula evaluator.
- **Rejection Reason**: Already rejected in ADR-0017 §Alternative 3 (per ADR-0017 Acceptance via delta #12). This ADR makes that boundary concrete by defining the executor class. Single Responsibility + testability + Substitutability all favor the dedicated class.

### Alternative 2: Static utility module (`DestinyBranchJudge.resolve` as a `static func`)

- **Description**: `DestinyBranchJudge` is a script with `static func resolve(...)` — no instance, no `RefCounted`, no class hierarchy. Tests inject mock F-SP-1 via a `static var _sp1_override: Callable` (set by test, restored after).
- **Pros**: No allocation per call (one fewer `new()`); no abstract-method ceremony; smallest LoC.
- **Cons**: `static var` is FORBIDDEN by destiny-branch GDD EC-DB-17 thread-safety guarantee — even a "test-only" static var introduces shared mutable state that breaks the determinism-by-construction property. Worse: `static var` SET by one test and not RESTORED leaks into the next test's run, producing order-dependent test failures. The `@abstract` + subclass pattern provides the same test-injection capability via instance-level state (TestDestinyBranchJudgeWithSp1Stub holds `_stub_output` as instance var) which is automatically released by RefCounted scope drop. No order-dependent failure mode.
- **Rejection Reason**: EC-DB-17 thread-safety + test-isolation hygiene. The cost of one RefCounted allocation per chapter (5 per scenario) is negligible vs. the cost of debugging order-dependent test failures introduced by shared mutable state.

### Alternative 3: Autoload singleton (`DestinyBranchJudge` as 7th autoload)

- **Description**: Register `DestinyBranchJudge` as a 7th autoload (after GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel + ScenarioRunner). ScenarioRunner calls `DestinyBranchJudge.resolve(...)` directly via the global identifier.
- **Pros**: No `.new()` allocation per chapter; single global instance; "feels like infrastructure".
- **Cons**: Judge holds NO persistent state (CR-DB-3 transient-per-call); autoload form misrepresents lifecycle to future maintainers ("if it's an autoload it must hold state"). Project precedent — autoloads are reserved for components that NEED cross-scene persistence (GameBus signal hub, SceneManager FSM, SaveManager JSON pipeline, etc.). Adding an autoload for a stateless pure function is anti-pattern. Also: autoload requires `extends Node` + `class_name` collision per godot-4x-gotchas G-3 (5-precedent autoload form omits class_name); but this judge needs `class_name DestinyBranchJudge` to be constructable from test fixtures — irreconcilable.
- **Rejection Reason**: GDD CR-DB-3 explicitly rejects "long-lived instance, autoload, or caching"; adopted into this ADR as the autoload-form ban. RefCounted is the correct base.

### Alternative 4: Untyped `Dictionary` payload (no `DestinyBranchChoice` Resource)

- **Description**: `resolve()` returns a `Dictionary` with stringly-keyed fields. No `Resource` type. ADR-0001's `destiny_branch_chosen` signal carries a Dictionary instead of a typed payload.
- **Pros**: Maximally permissive evolution — adding/removing fields is trivial; no `class_name` parse cost; one less file.
- **Cons**: Loses Pillar-4 payload-level enforcement (no parse-time check for `is_canonical_history` field presence/type); loses ResourceSaver/ResourceLoader round-trip type preservation (Dictionary serializes as JSON-equivalent, loses typed-enum signal for `outcome` field — would store as untyped int); breaks ADR-0001 V-3 cross-scene serialization contract; future migration becomes a manual Dictionary-walking exercise (vs. SaveMigrationRegistry-driven Resource schema migration per ADR-0003).
- **Rejection Reason**: Pillar-4 enforcement at payload level + ADR-0001 V-3 typed-Resource serialization contract + ADR-0003 SaveMigrationRegistry schema-evolution path. Typed Resource is the project's chosen pattern (see ChapterDefinition + BattlePayload + EchoMark + SaveContext precedents).

## Consequences

### Positive

- **Pillar 2 mechanical expression unblocked at sprint-7+ patch** — Beat 7 ceremonial-witness reveal is end-to-end implementable once this ADR is Accepted + ADR-0001 minor amendment lands. ScenarioRunner's `_enter_beat_7_judgment` synchronous block is callable.
- **Pillar 4 enforcement at payload level** — `is_canonical_history` field on `DestinyBranchChoice` enables Beat 8 (Story Event #10 VS) canonical-vs-rewritten contrast without maintaining a parallel content-layer lookup table. Author bug → silent collapse to always-false → caught by F-DB-1 step 1 zero-canonical-row warning.
- **Three downstream VS GDDs unblocked from design start** — Story Event #10 + Destiny State #16 + Save/Load #17 all gated on this ADR's Acceptance + 9-field payload ratification. Single ratification unblocks three parallel design-authoring tracks for sprint-7+ scope.
- **Test seam pattern stable at 2nd invocation** — `@abstract` test seam follows damage-calc rev 2.6 bypass-seam precedent (AC-DC-21/28/51) — first invocation in ADR-0012 + this ADR is the second. Pattern is now the project's canonical "inject-formula-output-without-monkey-patching" idiom.
- **Cross-ADR signature reconciliation via Path A precedent** — third invocation of "ratification widening at upstream-ADR acceptance" (after `save_checkpoint_requested` 2026-04-18 String → SaveContext + `scenario_complete` delta #12 String → ScenarioResult). Pattern is now stable at 3 invocations; codification candidate carried forward (delta #12).
- **Determinism-by-construction enforced via lint** — three new lint scripts (`destiny_branch_judge_emits_gamebus_signal` + `destiny_branch_judge_static_var` + `destiny_branch_judge_reads_scenario_runner_state`) prevent regressions. EC-DB-17 thread safety + CR-DB-2 purity + CR-DB-4 emission ownership all become CI-enforced invariants.
- **ADR-0001 PROVISIONAL slot count decreases** — 3 → 2 PROVISIONAL signals (delta #12 had 4 → 3 via `scenario_beat_retried` ratification; this ADR completes the destiny_branch_chosen ratification). Each delta gradually drains the PROVISIONAL backlog.
- **Substitutability preserved** — future Ch4+ branch resolution alternatives (e.g., echo-gated for ALL outcomes, not just DRAW) are class-swap at ScenarioRunner construction site (`var judge: DestinyBranchJudge = AlternativeJudge.new()`); no system-wide refactor needed.

### Negative

- **3 same-patch document updates required** for Acceptance: ADR-0001 minor amendment (5-field PROVISIONAL → 9-field RATIFIED + BattleOutcome top-level note + PROVISIONAL count 3 → 2) + destiny-branch GDD F-DB-1 algorithm 3-arg → 4-arg form correction + grid-battle v5.0 GDD revision (`class_name BattleOutcome` top-level note). Coordination cost: ~3 wording flips across 3 documents at this ADR's `/architecture-review` delta.
- **2 new file paths committed** — `src/core/payloads/destiny_branch_choice.gd` + `src/feature/destiny_branch/destiny_branch_judge.gd` + `src/feature/destiny_branch/default_destiny_branch_judge.gd` (3 new files; LoC ~150-200 production + ~80 test fixture in `tests/helpers/destiny_branch_judge_stub.gd`).
- **2 new lint scripts** for sprint-7+ patch — `lint_destiny_branch_judge_no_static_var.sh` + `lint_destiny_branch_judge_no_gamebus_emit.sh` + `lint_destiny_branch_judge_no_scenario_runner_read.sh` (third proposed inline above). Each <100ms CI cost; well within <5s pipeline budget.
- **Naming reconciliation cost on `chapter.canonical_branch_key`** — destiny-branch GDD §F-DB-1 used `default_branch_key`; ADR-0017 ChapterDefinition schema uses `canonical_branch_key`. This ADR adopts ADR-0017 form (canonical_branch_key) and same-patch the GDD F-DB-1 wording. Net: 1 GDD field-name flip + same-patch invalid_reason vocabulary entry rename (`invariant_violation:default_branch_key_missing` → kept verbatim per F-DB-3 vocabulary stability per "extending vocabulary requires test fixture per entry"; the StringName value is opaque to the field-name renaming).
- **`@abstract` annotation hard-gates Godot 4.5+** — pre-4.5 fallback (`assert(false, "must override")`) is rejected. The project pin is Godot 4.6 (post-cutoff HIGH risk per VERSION.md), so this is fine TODAY; if a future engine downgrade is ever considered, the test seam form would need re-evaluation. Documented for future-maintainer awareness.
- **3 forbidden_patterns added to architecture registry** — incremental registry growth + per-pattern lint cost. Mitigated: each lint is a single grep with <100ms execution; cumulative CI cost <300ms.

### Risks

- **R1: BattleOutcome class_name top-level constraint not landed in grid-battle v5.0 before destiny-branch implementation story opens** → DestinyBranchChoice `@export var outcome: BattleOutcome.Result = ...` parses at script-load but fails to resolve the default value at Resource-load-time, silently breaking `ResourceLoader.load(saved_destiny_branch_choice.tres)`. **Mitigation**: cross-doc Bidirectional Updates table flags this as BLOCKING for destiny-branch implementation story open; producer coordination required for grid-battle v5.0 GDD revision pre-sprint-7+; CI lint at sprint-7+ patch can grep `grid_battle/battle_outcome.gd` for `class_name BattleOutcome` top-level declaration.
- **R2: `StringName` field-type preservation through `ResourceSaver`/`ResourceLoader` on macOS/Windows/Android export targets is UNVERIFIED** (destiny-branch GDD OQ-DB-6 BLOCKING for VS-implementation-story open) — if the Godot 4.6 export pipeline silently coerces StringName to String on some platform, `invalid_reason` field-type drift would corrupt downstream `match` statements that key on StringName equality. **Mitigation**: Verification Required field in §Engine Compatibility flags this as BLOCKING for VS-close; AC-DB-24 multi-platform CI lane verification gate; Implementation Note IN-1 (below) documents the explicit verification protocol.
- **R3: Future scenario-progression revision changes F-SP-1's required-key contract** (e.g., adds a 4th required key for some new mechanism) — `DefaultDestinyBranchJudge` would silently miss the new key (its `_apply_f_sp_1` delegates the call through but doesn't observe the output beyond what `resolve()` reads). **Mitigation**: F-SP-1 spec ownership lives in scenario-progression (ADR-0017); any F-SP-1 contract change triggers a coordinated scenario-progression revision + this ADR amendment + same-patch GDD update + AC-DB additions. The `@abstract` declaration's signature update propagates parse-time errors to all subclasses, enforcing coordinated update.
- **R4: A future maintainer adds `static var` to a subclass of DestinyBranchJudge** thinking "it's just a cache" — silently breaks EC-DB-17 thread safety. **Mitigation**: lint script `lint_destiny_branch_judge_no_static_var.sh` greps both base AND any file declaring `extends DestinyBranchJudge`. CI-enforced.
- **R5: ADR-0001 minor amendment introduces a typo or wording drift in the 9-field list during same-patch flip** — silent contract drift if downstream code reads from the ADR-0001 prose vs. this ADR's authoritative §Decision §Payload Form. **Mitigation**: `/architecture-review` delta will catch list-prose drift via cross-ADR consistency check; godot-specialist Phase 4.5 spawn this turn is the same-patch verification pass.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `destiny-branch.md` | CR-DB-1 System boundary (named owner) | Defines `DestinyBranchJudge` class as the named owner; binds payload + judge to a single architectural artifact. |
| `destiny-branch.md` | CR-DB-2 Pure function (single public method, no instance state, no external state read, no RNG) | `resolve()` is the single public method; no autoload reads; no `static var`; no RNG; lint-enforced via 3 forbidden_patterns. |
| `destiny-branch.md` | CR-DB-3 Transient per call (RefCounted scope drop) | `extends RefCounted`; ScenarioRunner constructs + uses + scope-drops within tap-exit handler. |
| `destiny-branch.md` | CR-DB-4 Emission lives in ScenarioRunner | Lint-enforced: `destiny_branch_judge_emits_gamebus_signal` forbidden_pattern. |
| `destiny-branch.md` | CR-DB-5 One evaluation per chapter | ScenarioRunner state-machine guard at BEAT_7_JUDGMENT entry (per ADR-0017); judge does not self-detect (per CR-DB-5 EC-DB-7 escalation note). |
| `destiny-branch.md` | CR-DB-6 No intermediate state observable | Judge has no signals; no state queries; no logging that exposes internal computation. |
| `destiny-branch.md` | CR-DB-7 Signal emitted exactly once per chapter | ScenarioRunner ownership; judge's scope is one synchronous call. |
| `destiny-branch.md` | CR-DB-8 No branch structural information leaks | Judge returns the chosen branch only; no enumeration of un-taken branches; `reserved_color_treatment` is a derived bool, not a leak. |
| `destiny-branch.md` | CR-DB-9 `reserved_color_treatment` derived (not authored) | F-DB-2 derivation in algorithm step 4 + 4a. |
| `destiny-branch.md` | CR-DB-10 Invalid-input result pattern | `static func invalid(reason)` factory + 12-entry F-DB-3 vocabulary. |
| `destiny-branch.md` | CR-DB-11 Determinism invariant | No RNG / wall-clock / external-state-read / class-level-state — lint-enforced. |
| `destiny-branch.md` | CR-DB-12 Scope rejection (7 explicit non-MVP items) | Adopted by reference; this ADR does not introduce dynamic-branch / branch-preview / undo / per-difficulty / conditional-suppression / mid-chapter-re-eval / RNG-weighted patterns. |
| `destiny-branch.md` | F-DB-1 `DestinyBranchChoice` assembly algorithm | Transcribed verbatim into Decision §Class Form code block; same-patch GDD F-DB-1 update from 3-arg → 4-arg form (Migration Plan §3). |
| `destiny-branch.md` | F-DB-2 `reserved_color_treatment` derivation | Algorithm step 4 + 4a. |
| `destiny-branch.md` | F-DB-3 `invalid_reason` vocabulary (12 entries) | Decision §Payload Form invariants + algorithm Step 1 + 3a/3b/3c. |
| `destiny-branch.md` | F-DB-4 `DestinyBranchChoice` payload schema (9 fields) | Decision §Payload Form GDScript declaration + field schema table. |
| `destiny-branch.md` | EC-DB-1..16 Edge cases | All routed through `invalid()` factory + 12-entry vocabulary; no destiny-branch-specific edge skipped. |
| `destiny-branch.md` | EC-DB-17 Concurrent resolve from two RefCounted instances | Thread-safe by construction (no class-level state); lint-enforced. |
| `scenario-progression.md` | F-SP-1 owner = scenario-progression / executor = DestinyBranchJudge (rev v2.0-patch 2026-04-19) | This ADR ratifies the executor binding; F-SP-1 spec ownership remains with scenario-progression (ADR-0017). |
| `scenario-progression.md` | CR-7 first_attempt_resolved sealed at BEAT_7 entry | Judge's 4th argument is the **already-sealed** value (read-only input); judge does not access ScenarioRunner state. |
| `scenario-progression.md` | CR-3 Tri-state outcome (no synthesis or override) | Judge passes outcome through unchanged; AC-DB determinism fixtures verify no `outcome` field mutation. |
| `scenario-progression.md` | CR-15 mid-battle save / post-Beat-9 undo bans | This ADR has no save/load mechanism (judge is stateless); no undo surface (CR-DB-12 #3). |

## Performance Implications

- **CPU**: O(1) per `resolve()` call. One Dictionary lookup (F-SP-1 inside seam) + ~5 `is`-type guards + ~3 String comparisons + 9 Resource field assignments. Measured single-call execution time SHOULD be well under 0.1 ms on the reference mobile (mid-tier Android). 5 calls per scenario MVP scope (1 per chapter × 5 chapters) → cumulative <0.5 ms scenario-wide. Negligible vs. 16.6 ms frame budget.
- **Memory**: ~250B per `DestinyBranchJudge` allocation (RefCounted overhead + 0 instance fields) + ~250B per `DestinyBranchChoice` allocation (Resource overhead + 9 @export fields × 8B-equivalent). 5 chapters × 2 allocations = 10 transient allocations per scenario; judge instances are immediately freed via RefCounted scope drop; choice instances persist through Beat 9 commit then are eligible for GC if no subscriber retains. Negligible vs. typical scene-load allocation churn (multi-MB tile maps, hero portraits, etc.).
- **Load Time**: 2 new files added to `src/feature/destiny_branch/` + 1 new file in `src/core/payloads/` + 1 test helper in `tests/helpers/` + 1 production-time concrete subclass file. Script parse cost: <1 ms cumulative on engine boot. No autoload added (5 autoloads + ScenarioRunner = 6 total per ADR-0017 boot-order; this ADR adds zero).
- **Network**: N/A — single-player MVP; no networking domain.
- **Save File Size**: `DestinyBranchChoice` Resource serialization adds ~100-200B per saved chapter slot via `ChapterResult.branch_triggered` per ADR-0003 SaveContext schema. 5 chapters × ~150B = ~750B savefile growth per scenario. Negligible (<<1% of typical mobile savefile size).

## Migration Plan

This ADR's Acceptance (via `/architecture-review` in a fresh future session) coordinates 4 same-patch document updates + introduces 2 new source files + 1 production-time concrete subclass + 1 test helper file at sprint-7+ implementation patch.

### §0 Pre-Acceptance: ADR-0001 minor amendment ratifying 9-field shape

Same-patch as this ADR's Proposed → Accepted flip:

1. ADR-0001 line 315 Scenario-domain table row: replace 5-field PROVISIONAL list with 9-field RATIFIED list per Decision §ADR-0001 Minor Amendment.
2. ADR-0001 line 319 Pillar 2 note: rewrite per Decision §ADR-0001 Minor Amendment.
3. ADR-0001 line 364: remove "shape TBD" entry.
4. ADR-0001 PROVISIONAL signal count line 363-364: decrement 3 → 2; add new "PROVISIONAL → RATIFIED 2026-05-04 via ADR-0018" subsection mirroring delta #12 format.
5. ADR-0001 add cross-doc constraint paragraph: `BattleOutcome` MUST be top-level `class_name`.

### §1 Pre-Acceptance: destiny-branch GDD F-DB-1 algorithm 3-arg → 4-arg correction

Same-patch as this ADR's Acceptance:

1. destiny-branch.md §F-DB-1 algorithm pseudocode (lines 152-254): correct `func resolve(chapter, outcome, echo_count) -> DestinyBranchChoice` to `func resolve(chapter: ChapterDefinition, outcome: BattleOutcome.Result, echo_count: int, first_attempt_resolved: bool) -> DestinyBranchChoice` (4-arg form).
2. destiny-branch.md §F-DB-1 Variables table: add 4th row `first_attempt_resolved | far | bool | {true, false} | F-SP-3 v2.2 first_attempt_resolved seal value at BEAT_7_JUDGMENT entry; passed through to F-SP-1 / F-SP-2 per scenario-progression CR-7`.
3. destiny-branch.md §F-DB-1 algorithm step 3: pass `first_attempt_resolved` to `_apply_f_sp_1(chapter, outcome, echo_count, first_attempt_resolved)`.
4. destiny-branch.md §F-DB-1 worked examples (E1-E6): add 4th column for `first_attempt_resolved` value; update E2/E3 to disambiguate echo-gated vs. anti-farm-gate cases via this column.
5. destiny-branch.md §test-seam contract: update `_apply_f_sp_1` signature to 4-arg form; update TestDestinyBranchJudgeWithSp1Stub example accordingly.
6. destiny-branch.md §F-DB-1 field name: `chapter.default_branch_key` → `chapter.canonical_branch_key` (matches ADR-0017 ChapterDefinition schema).
7. destiny-branch.md §rev tag bump: 1.3.1 → 1.3.2 (or similar — narrative-director judgment) with delta-line `2026-05-04 ADR-0018 ratification: 3-arg → 4-arg form + canonical_branch_key field-name reconciliation`.

### §2 Pre-Acceptance: scenario-progression GDD §Interactions line 189 sync (silent-incompatibility close)

Per destiny-branch GDD §Bidirectional rev 1.3 systems B-3 + ux B-UX-9-1 (currently flagged BLOCKING):

1. scenario-progression.md §Interactions line 189: 6-field `DestinyBranchChoice` minimum-fields list → 9-field list (matches F-DB-4 ratified schema).
2. scenario-progression.md §Interactions line 189: add invalid-path emission contract paragraph + 12-entry F-DB-3 vocabulary cross-ref.
3. scenario-progression.md §UX.2 (Beat 7 panel spec): add Beat-7 carve-out acknowledgment paragraph referencing IP-006 + destiny-branch UI-DB-5 (closes rev 1.3 ux B-UX-9-1).
4. scenario-progression.md F-SP-1 §D worked examples + AC-SP-22: add `is_canonical_history` to F-SP-1 Dictionary output contract (3-required-key shape: branch_key + is_draw_fallback + is_canonical_history).
5. scenario-progression.md AC-SP-18: add `is_invalid: bool` + `invalid_reason: StringName` to required-field assertion list (8 fields, was 6).
6. scenario-progression.md AC-SP-17: add sentence "The emitted DestinyBranchChoice MAY have is_invalid == true in error conditions; the exactly-one-emission contract still holds."

NOTE: §2 is NOT a blocker for this ADR's Acceptance per project precedent (ADR-0014 + ADR-0015 + ADR-0017 each landed with downstream GDD sync flagged but deferred). However it IS a BLOCKER for destiny-branch implementation-story open (per destiny-branch §Pre-Implementation Gate Checklist). Scheduled for sprint-7+ pre-implementation hygiene pass.

### §3 At-Acceptance: Architecture Registry update

Same-patch as this ADR's Acceptance via `/architecture-review` delta:

- 1 net-new state_ownership entry: `destiny_branch_judge_runtime_payload` (the `DestinyBranchChoice` typed Resource as a payload — owned by this ADR; consumers may NOT mutate; ResourceSaver/ResourceLoader round-trip per ADR-0001 V-3).
- 1 net-new interface entry: `destiny_branch_judge_signal_contract` (Public API: `resolve(chapter, outcome, echo_count, first_attempt_resolved) -> DestinyBranchChoice`; test seam: `@abstract _apply_f_sp_1(...)`; payload: 9-field DestinyBranchChoice).
- 1 net-new api_decision entry: `destiny_branch_judge_module_form` (RefCounted pure-function class + @abstract test seam + DefaultDestinyBranchJudge concrete subclass + DestinyBranchChoice typed Resource; 4 alternatives documented above).
- 3 net-new forbidden_patterns: `destiny_branch_judge_emits_gamebus_signal` + `destiny_branch_judge_static_var` + `destiny_branch_judge_reads_scenario_runner_state`.
- 1 PROVISIONAL → RATIFIED: ADR-0001 `destiny_branch_chosen` 5-field PROVISIONAL → 9-field RATIFIED via Evolution Rule #4.

### §4 At-Acceptance: TR Registry update

12-15 net-new TR-destiny-branch-NNN entries appended covering this ADR's architectural decisions:
- TR-destiny-branch-001 RefCounted pure-function class form
- TR-destiny-branch-002 4-arg resolve signature
- TR-destiny-branch-003 9-field DestinyBranchChoice payload schema
- TR-destiny-branch-004 12-entry invalid_reason F-DB-3 vocabulary
- TR-destiny-branch-005 @abstract _apply_f_sp_1 test seam
- TR-destiny-branch-006 DefaultDestinyBranchJudge production subclass + delegation to ScenarioFormulas
- TR-destiny-branch-007 invalid() factory + invariant violation contract (CR-DB-10)
- TR-destiny-branch-008 reserved_color_treatment derivation (CR-DB-9 + F-DB-2)
- TR-destiny-branch-009 is_canonical_history Pillar 4 payload-level enforcement
- TR-destiny-branch-010 Determinism invariant (no RNG / wall-clock / external state) — lint-enforced
- TR-destiny-branch-011 EC-DB-17 thread safety by construction — lint-enforced
- TR-destiny-branch-012 ADR-0001 minor amendment 5-field → 9-field
- TR-destiny-branch-013 BattleOutcome top-level class_name cross-doc constraint
- TR-destiny-branch-014 Emission ownership in ScenarioRunner (CR-DB-4) — lint-enforced
- TR-destiny-branch-015 ResourceSaver/ResourceLoader round-trip on 5 export targets (closes OQ-DB-6)

### §5 Sprint-7+ Implementation Patch (single coordinated patch — not part of this ADR's Acceptance)

NOT executed at this ADR's Acceptance. Scheduled for sprint-7+ implementation story:

1. Author `src/core/payloads/destiny_branch_choice.gd` (~30 LoC GDScript class declaration + invalid factory).
2. Author `src/feature/destiny_branch/destiny_branch_judge.gd` (~120 LoC: F-DB-1 algorithm + invariant checks + step 4a derivation + abstract seam declaration).
3. Author `src/feature/destiny_branch/default_destiny_branch_judge.gd` (~10 LoC: concrete subclass + delegation to ScenarioFormulas).
4. Author `tests/helpers/destiny_branch_judge_stub.gd` (~30 LoC: TestDestinyBranchJudgeWithSp1Stub fixture).
5. Author `tests/unit/destiny_branch/destiny_branch_judge_test.gd` + `tests/unit/destiny_branch/destiny_branch_choice_serialization_test.gd` (~200-300 LoC of GdUnit4 cases covering F-DB-1 worked examples E1-E6 + 12 invalid_reason vocabulary entries + EC-DB-17 thread-safety + AC-DB-24 ResourceSaver/ResourceLoader round-trip on 5 platforms).
6. Author `tools/ci/lint_destiny_branch_judge_no_static_var.sh` + `lint_destiny_branch_judge_no_gamebus_emit.sh` + `lint_destiny_branch_judge_no_scenario_runner_read.sh` (~50 LoC each).
7. Wire 3 new lint scripts into `.github/workflows/tests.yml` after the existing battle-scene lint group, before `Run GdUnit4 tests` step (matches ADR-0016 IN-4 fallback pattern).
8. Coordinate with grid-battle v5.0 GDD revision: declare `class_name BattleOutcome` top-level (Migration Plan §6 cross-doc constraint).
9. ScenarioRunner sprint-7+ patch (per ADR-0017 §Migration Plan §1..§11 single coordinated patch): `_on_beat_7_judgment_tap_exit()` constructs `DefaultDestinyBranchJudge.new()` + calls `resolve()` + emits `save_checkpoint_requested` + `destiny_branch_chosen` per the synchronous block in this ADR's Decision §Emission Ownership.

### §6 Cross-Doc: Grid Battle v5.0 GDD revision

Cross-doc constraint flagged for grid-battle v5.0 GDD revision (which is "in revision" per destiny-branch §Bidirectional table at this ADR's authoring date):

- `BattleOutcome` MUST be a top-level `class_name BattleOutcome` declaration in its own script file (path TBD by grid-battle v5.0 — proposal: `src/feature/grid_battle/battle_outcome.gd`).
- `BattleOutcome.Result` enum order MUST be locked at v5.0 acceptance: `Result { WIN = 0, DRAW = 1, LOSS = 2 }` — reordering breaks DestinyBranchChoice serialization compatibility silently.
- Cross-reference to this ADR §Engine Compatibility row "Verification Required" item (1) for AC-DB-24 multi-platform CI lane.

## Validation Criteria

How we will know this decision was correct (testable acceptance criteria, owned by this ADR; mapped to destiny-branch GDD AC-DB buckets):

1. **V-1 (Class form correctness)** — `DestinyBranchJudge.new()` constructs without errors; `class_name DestinyBranchJudge` is globally registered (`ClassDB.class_exists("DestinyBranchJudge")` returns true at runtime); `judge instanceof RefCounted` is true; `judge instanceof Node` is false.
   - Test: `tests/unit/destiny_branch/destiny_branch_judge_test.gd::test_judge_is_refcounted_not_node`
   - GDD trace: CR-DB-2 + CR-DB-3
   - Status: pending implementation
2. **V-2 (Determinism invariant)** — invoke `judge.resolve(chapter_fixture, BattleOutcome.Result.DRAW, 1, false)` 100 times in a row; assert all 100 returned `DestinyBranchChoice` instances are field-identical (compare 9 fields each). Run again with the same fixture in a fresh test invocation; assert results identical to the first run.
   - Test: `tests/unit/destiny_branch/destiny_branch_judge_test.gd::test_resolve_deterministic_100_iterations`
   - GDD trace: CR-DB-11
   - Status: pending implementation
3. **V-3 (12-entry F-DB-3 vocabulary coverage)** — for each of the 12 `invariant_violation:*` entries, construct an input that triggers the corresponding invalid-reason; assert returned `DestinyBranchChoice.invalid_reason` matches expected StringName.
   - Test: `tests/unit/destiny_branch/destiny_branch_judge_invalid_reasons_test.gd::test_*` (12 cases)
   - GDD trace: F-DB-3 + AC-DB bucket 3
   - Status: pending implementation
4. **V-4 (F-DB-1 worked examples E1-E6 correctness)** — for each of the 6 worked examples (with the 4-arg form per same-patch GDD update), construct the input fixture, call `resolve()`, assert each of the 9 returned fields matches the documented expected value.
   - Test: `tests/unit/destiny_branch/destiny_branch_judge_worked_examples_test.gd::test_e1_through_e6` (6 cases)
   - GDD trace: F-DB-1 worked examples + AC-DB bucket 1
   - Status: pending implementation
5. **V-5 (`@abstract` annotation present in source)** — verify the production source file declares `_apply_f_sp_1` as `@abstract`. NOTE per godot-4x-gotchas G-22: `@abstract` enforcement is parse-time on **typed references only**; reflective `load(path).new()` bypasses the check and returns a live instance with the empty base body. The reliable verification is therefore a structural source-file assertion, NOT a runtime `load()` failure expectation.
   - Test: `tests/unit/destiny_branch/destiny_branch_judge_abstract_annotation_test.gd::test_apply_f_sp_1_declared_abstract`
     ```gdscript
     # Per G-22 structural-source-file assertion pattern:
     var content: String = FileAccess.get_file_as_string("res://src/feature/destiny_branch/destiny_branch_judge.gd")
     assert_bool(content.contains("@abstract")).is_true()
     assert_bool(content.contains("func _apply_f_sp_1")).is_true()
     ```
   - GDD trace: F-DB-1 test-seam contract + Decision §Test Seam
   - Status: pending implementation
6. **V-6 (ResourceSaver/ResourceLoader round-trip on 5 platforms)** — construct a `DestinyBranchChoice` with all 9 fields populated (including `invalid_reason: StringName = &"invariant_violation:branch_table_empty"`); save via `ResourceSaver.save(choice, "user://test.tres")`; load via `ResourceLoader.load("user://test.tres")`; assert all 9 fields are field-identical to the original. Run on Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan (CI matrix).
   - Test: `tests/integration/destiny_branch/destiny_branch_choice_serialization_test.gd::test_round_trip_all_platforms`
   - GDD trace: F-DB-4 + ADR-0001 V-3 + closes OQ-DB-6
   - Status: pending implementation; BLOCKING for VS close
7. **V-7 (Emission ownership lint)** — `grep -E 'GameBus\\..*\\.emit\\(' src/feature/destiny_branch/destiny_branch_judge.gd src/feature/destiny_branch/default_destiny_branch_judge.gd` returns 0 matches.
   - Test: `tools/ci/lint_destiny_branch_judge_no_gamebus_emit.sh` (CI-wired)
   - GDD trace: CR-DB-4
   - Status: pending implementation
8. **V-8 (Static var lint)** — `grep -E '^static var' [scan-set]` returns 0 matches. Scan-set MUST include the production source files **AND** the test stub helper **AND** any `extends DestinyBranchJudge` subclass file (production OR test scope). Concrete scan-set at sprint-7+ patch: `src/feature/destiny_branch/destiny_branch_judge.gd` + `src/feature/destiny_branch/default_destiny_branch_judge.gd` + `tests/helpers/destiny_branch_judge_stub.gd` + future `$(grep -rl 'extends DestinyBranchJudge' src/ tests/)` discovery. Rationale per godot-specialist Phase 4.5 review (advisory C-3): if a future test stub introduces `static var` for spying, the lint MUST catch it — class-level state in any test subclass breaks EC-DB-17 thread-safety guarantee for the whole class hierarchy.
   - Test: `tools/ci/lint_destiny_branch_judge_no_static_var.sh` (CI-wired)
   - GDD trace: EC-DB-17
   - Status: pending implementation
9. **V-9 (ScenarioRunner state-read lint)** — `grep -E 'ScenarioRunner\\.|_scenario_state\\.' src/feature/destiny_branch/destiny_branch_judge.gd src/feature/destiny_branch/default_destiny_branch_judge.gd` returns 0 matches.
   - Test: `tools/ci/lint_destiny_branch_judge_no_scenario_runner_read.sh` (CI-wired)
   - GDD trace: CR-DB-2 + scenario-progression CR-7 sealing invariant (judge does NOT read sealed value from autoload state — receives it as 4th argument)
   - Status: pending implementation
10. **V-10 (ADR-0001 minor amendment landed)** — `grep -E '5-field|revelation_cue_id|required_flags|authored: bool' docs/architecture/ADR-0001-gamebus-autoload.md` returns 0 matches in the `destiny_branch_chosen` section context (post-amendment).
    - Test: `/architecture-review` cross-ADR consistency check (manual at this ADR's Acceptance delta)
    - GDD trace: ADR-0001 Evolution Rule #4 + Decision §ADR-0001 Minor Amendment
    - Status: pending /architecture-review delta
11. **V-11 (BattleOutcome top-level class_name landed)** — `grep -E '^class_name BattleOutcome' src/feature/grid_battle/battle_outcome.gd` (path TBD by grid-battle v5.0) returns 1 match. Cross-ADR consistency check at grid-battle v5.0 acceptance.
    - Test: future grid-battle v5.0 lint or `/architecture-review` cross-ADR check
    - GDD trace: destiny-branch §Bidirectional rev 1.2 B-7 + this ADR §Engine Compatibility R1
    - Status: pending grid-battle v5.0 GDD revision
12. **V-12 (Concurrent-resolve thread safety)** — instantiate two `DestinyBranchJudge.new()` instances on separate WorkerThreadPool tasks; have each call `resolve()` 1000 times with the same fixture concurrently; assert all 2000 returned `DestinyBranchChoice` instances are field-identical to the expected baseline.
    - Test: `tests/integration/destiny_branch/destiny_branch_judge_thread_safety_test.gd::test_concurrent_resolve_field_identical_2000_iterations`
    - GDD trace: EC-DB-17
    - Status: pending implementation

## Implementation Notes

**IN-1: ResourceSaver/ResourceLoader round-trip protocol for OQ-DB-6 closure (BLOCKING for VS close).**

Per §Engine Compatibility "Verification Required" item (1), the `StringName` field-type preservation through `ResourceSaver.save()`/`ResourceLoader.load()` is UNVERIFIED on Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan export targets. The GdUnit4 integration test `tests/integration/destiny_branch/destiny_branch_choice_serialization_test.gd::test_round_trip_all_platforms` is the verification gate.

Test protocol:
```gdscript
func test_round_trip_preserves_string_name() -> void:
    var original := DestinyBranchChoice.new()
    original.chapter_id = "ch3"
    original.branch_key = "DRAW_ch3_echo"
    original.outcome = BattleOutcome.Result.DRAW
    original.echo_count = 1
    original.is_draw_fallback = false
    original.is_canonical_history = false
    original.reserved_color_treatment = true
    original.is_invalid = false
    original.invalid_reason = &""
    var path := "user://test_destiny_branch_choice_round_trip.tres"
    var save_result := ResourceSaver.save(original, path)
    assert(save_result == OK, "ResourceSaver.save returned non-OK: %d" % save_result)
    var loaded: DestinyBranchChoice = ResourceLoader.load(path) as DestinyBranchChoice
    assert(loaded != null, "ResourceLoader.load returned null")
    assert(loaded.chapter_id == original.chapter_id)
    assert(loaded.branch_key == original.branch_key)
    assert(loaded.outcome == original.outcome)  # Tests typed-enum preservation
    assert(loaded.echo_count == original.echo_count)
    assert(loaded.is_draw_fallback == original.is_draw_fallback)
    assert(loaded.is_canonical_history == original.is_canonical_history)
    assert(loaded.reserved_color_treatment == original.reserved_color_treatment)
    assert(loaded.is_invalid == original.is_invalid)
    assert(loaded.invalid_reason == original.invalid_reason)
    # CRITICAL: type-preservation check (the OQ-DB-6 question)
    assert(typeof(loaded.invalid_reason) == TYPE_STRING_NAME,
        "invalid_reason should be StringName but is %s" % typeof(loaded.invalid_reason))

    # Run with invalid_reason populated (non-empty StringName)
    original.is_invalid = true
    original.invalid_reason = &"invariant_violation:branch_table_empty"
    save_result = ResourceSaver.save(original, path)
    loaded = ResourceLoader.load(path) as DestinyBranchChoice
    assert(loaded.invalid_reason == &"invariant_violation:branch_table_empty")
    assert(typeof(loaded.invalid_reason) == TYPE_STRING_NAME)
```

CI matrix MUST run this test on all 5 export targets per AC-DB-24. If any platform shows `typeof != TYPE_STRING_NAME`, raise BLOCKER and revisit `invalid_reason` field type (fallback: keep `StringName` semantics via wrapper; do NOT downgrade to `String` lightly — match-statement equality is the consumer-side workhorse).

**IN-2: Migration Plan §1 dependency on scenario-progression GDD revision sequencing.**

Per §Migration Plan §1, the destiny-branch GDD F-DB-1 3-arg → 4-arg correction is a same-patch update at this ADR's Acceptance. However, scenario-progression GDD §Interactions line 189 sync (Migration Plan §2) is intentionally NOT a blocker for Acceptance — it is a BLOCKER only for destiny-branch implementation-story open per the GDD's §Pre-Implementation Gate Checklist.

Sequencing:
- This ADR Proposed → Accepted (via fresh-session `/architecture-review`) — same-patch with Migration Plan §0 (ADR-0001 amendment) + §1 (destiny-branch GDD F-DB-1) + §3 + §4 (architecture/TR registries).
- Sprint-7+ pre-implementation hygiene pass — Migration Plan §2 (scenario-progression line 189 + UX.2 sync) + §6 (grid-battle v5.0 BattleOutcome top-level class_name) — coordinate with /create-stories `destiny-branch` epic authoring.
- Sprint-7+ implementation story — Migration Plan §5 (source files + tests + lints + CI wiring) + ScenarioRunner per ADR-0017 §Migration Plan §1..§11.

The /create-epics workflow at sprint-7+ planning will surface §2 + §6 as "epic prerequisite gate" rather than "ADR-Acceptance gate." This matches the ADR-0014 + ADR-0015 + ADR-0017 precedent (downstream GDD sync deferred to epic-prerequisite scope).

## Related Decisions

- **ADR-0001 GameBus autoload** (Accepted 2026-04-18) — provides `destiny_branch_chosen` signal slot; ratified to 9-field shape via this ADR per Evolution Rule #4 minor amendment.
- **ADR-0002 Scene Manager** (Accepted 2026-04-18) — owns Overworld↔BattleScene transition lifecycle; ScenarioRunner (judge's caller) lives within scene lifecycle governed by ADR-0002.
- **ADR-0003 Save/Load** (Accepted 2026-04-18) — defines CP-2 / CP-3 timing anchors referenced at Beat 7 emission ordering.
- **ADR-0014 Grid Battle Controller** — provides `BattleOutcome` typed Resource emission contract; cross-doc constraint to grid-battle v5.0 GDD revision (top-level `class_name BattleOutcome`).
- **ADR-0017 Scenario Progression** (Accepted 2026-05-04 via /architecture-review delta #12) — defines `ChapterDefinition` typed Resource (input to `resolve()`), `_enter_beat_7_judgment` synchronous call site (line 200, 4-arg form), F-SP-3 v2.2 sealing invariant.
- **`design/gdd/destiny-branch.md`** (rev 1.3.1) — design source; this ADR ratifies the executor class + payload + cross-ADR signature.
- **`design/gdd/scenario-progression.md`** (v2.1+ pending) — F-SP-1 / F-SP-2 spec ownership; cross-doc sync items in §Migration Plan §2.

---

> **Authored**: 2026-05-04 by /architecture-decision skill (sprint-6 S6-11; UNBLOCKED by ADR-0017 Acceptance via delta #12).
>
> **Fresh-session escalation discipline**: Proposed → Accepted requires fresh-session `/architecture-review` per same-session-ban discipline. NEVER run `/architecture-review` in the same session as this ADR's authoring.
