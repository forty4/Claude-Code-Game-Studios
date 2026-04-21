# Story 004: payload_serialization_test — ResourceSaver round-trip

> **Epic**: gamebus
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3h — actual ~2h (specialist single-pass with upfront spec deviation flag)

## Context

**GDD**: — (infrastructure; payload serializability contract per ADR-0001)
**Requirement**: `TR-gamebus-001`

**ADR Governing Implementation**: ADR-0001 — §Implementation Guidelines §4 (Serialization contract) + §Validation Criteria V-3
**ADR Decision Summary**: "Every payload `Resource` class must be serializable via `ResourceSaver.save(payload, tmp_path)` → `ResourceLoader.load(tmp_path)` with identical data. Save/Load (#17) will depend on this."

**Engine**: Godot 4.6 | **Risk**: MEDIUM — typed-signal strictness tightened 4.5; `ResourceSaver`/`Loader` stable since 4.0 but verify Resource subclass round-trip preserves `class_name` + enum values + typed arrays
**Engine Notes**: Use `user://tmp/` (or `res://tests/fixtures/tmp/`) for test artifacts — `user://` is guaranteed writable on all platforms. Clean up in `after_test`.

**Control Manifest Rules (Platform layer)**:
- Required: Every payload Resource round-trips via ResourceSaver/Loader with identical data
- Required: Tests must be isolated — setup/teardown per test; no execution-order dependency
- Required: No hardcoded test data (use factory functions / boundary values only where the number IS the point)

## Acceptance Criteria

*Derived from ADR-0001 §Validation Criteria V-3 + §Migration Plan §2 (payload serialization unit tests):*

- [ ] `tests/unit/core/payload_serialization_test.gd` — GdUnit4 test class
- [ ] One test per non-provisional payload Resource class (6 classes from Story 001):
  - `test_battle_outcome_roundtrip`
  - `test_battle_payload_roundtrip`
  - `test_chapter_result_roundtrip`
  - `test_input_context_roundtrip`
  - `test_victory_conditions_roundtrip`
  - `test_battle_start_effect_roundtrip`
- [ ] Each test: populate all `@export` fields with distinct non-default values → `ResourceSaver.save(payload, tmp_path)` → assert `err == OK` → `ResourceLoader.load(tmp_path, "", ResourceLoader.CACHE_MODE_IGNORE)` → assert loaded instance is-a correct class → assert every field equals original
- [ ] Boundary values covered: empty `PackedInt64Array`, populated `PackedInt64Array` (≥3 elements), empty `String`, non-empty `String` with Korean chars (Unicode round-trip), `Dictionary` with mixed-type values (for `BattlePayload.deployment_positions`), `Array[BattleStartEffect]` with ≥2 elements (nested-Resource serialization)
- [ ] `BattleOutcome.Result` enum serialization: all three values (WIN=0, DRAW=1, LOSS=2) round-trip correctly (integer representation preserved per TR-save-load-005 append-only invariant)
- [ ] Tests use `before_test`/`after_test` for tmp file cleanup — no test leaves artifacts in `user://tmp/` after completion
- [ ] Tests use `CACHE_MODE_IGNORE` on load (mirrors ADR-0003 discipline; prevents cached-Resource false-positives when tests run in sequence)
- [ ] Tests are deterministic — no random seeds, no time-based fields populated unless the test explicitly asserts time preservation
- [ ] Failure message on mismatch: field-level diff, not just "not equal" — helps debugging

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §4 + ADR-0003 (schema-stability patterns reused here):*

1. **tmp path strategy**: Use a per-test random suffix to avoid cross-test interference:
   ```gdscript
   var tmp_path = "user://tmp/payload_test_%d.tres" % Time.get_ticks_usec()
   ```
   Or use GdUnit4's `TempDir` pattern if available. After test, `DirAccess.remove_absolute(tmp_path)`.

2. **Factory functions** — not inline hardcoded values. Example:
   ```gdscript
   static func _make_populated_battle_outcome() -> BattleOutcome:
       var bo = BattleOutcome.new()
       bo.result = BattleOutcome.Result.WIN
       bo.chapter_id = "ch_03_리푸쉬"  # Korean for Unicode coverage
       bo.final_round = 17
       bo.surviving_units = PackedInt64Array([101, 102, 103])
       bo.defeated_units = PackedInt64Array([201, 202])
       bo.is_abandon = false
       return bo
   ```

3. **Field-level diff on failure** — instead of `assert_that(original).is_equal(loaded)` (which produces terse messages), iterate fields and use `assert_that(loaded.chapter_id).is_equal("ch_03_리푸쉬")` for each — GdUnit4 shows the specific field that diverged.

4. **Nested Resource serialization** — `Array[BattleStartEffect]` tests the hardest case: each element is a `Resource` subclass, and Godot's ResourceSaver must serialize them inline (not by UID). Verify loaded array length == original, and each element's fields round-trip.

5. **Enum serialization** — `BattleOutcome.Result` is an `int` under the hood. ResourceSaver writes the integer value. On load, the enum constant is reconstructed by comparison. Verify `loaded.result == BattleOutcome.Result.WIN` NOT just `loaded.result == 0` (though they are equal; the comparison validates enum identity, not just integer equality).

6. **CACHE_MODE_IGNORE discipline** (from ADR-0003 TR-save-load-004) — mirrored here to establish the pattern. Cached loads return stale objects after overwrite — catastrophic for Save/Load. Always pass `CACHE_MODE_IGNORE` for any Resource that might be re-saved in the same session.

7. **String `Dictionary` keys** — Godot's Resource serialization supports Dictionary with primitive keys. For `BattlePayload.deployment_positions: Dictionary`, test with Vector2i keys mapping to int values (e.g., `{Vector2i(3, 4): 101, Vector2i(5, 6): 102}`). Verify round-trip preserves both keys and values.

## Out of Scope

- **Story 001**: Payload class schemas themselves (referenced here, implemented there)
- **save-manager epic Story 001**: SaveContext + EchoMark serialization tests (added to this test file later OR placed in save-manager's own test file — coordinate with save-manager Story 004 when it lands)
- **4 PROVISIONAL payloads**: Their tests land when Destiny State / Destiny Branch / Story Event epics materialize them

## QA Test Cases

*Inline QA specification.*

**Test file**: `tests/unit/core/payload_serialization_test.gd`

- **AC-1** (BattleOutcome round-trip):
  - Given: factory-constructed BattleOutcome with all 6 fields populated with non-default values; Korean chapter_id
  - When: save to tmp path → load with CACHE_MODE_IGNORE → field-by-field compare
  - Then: loaded instance `is BattleOutcome`; `.result == BattleOutcome.Result.WIN`; `.chapter_id == "ch_03_리푸쉬"`; `.final_round == 17`; `surviving_units == PackedInt64Array([101,102,103])`; `.defeated_units == PackedInt64Array([201,202])`; `.is_abandon == false`
  - Edge: assert loaded.result is still an enum value (identity check)

- **AC-2** (BattlePayload with Dictionary + Array[Resource]):
  - Given: BattlePayload with `deployment_positions: Dictionary` containing 3 `int (unit_id)` keys → `Vector2i (grid coord)` values (corrected 2026-04-21 to match BattlePayload class docstring + ADR-0001 §Signal Contract Schema §1); `battle_start_effects: Array[BattleStartEffect]` with 2 populated elements
  - When: round-trip
  - Then: `loaded.deployment_positions.size() == 3`; each int key preserved; each Vector2i value preserved; `loaded.battle_start_effects.size() == 2`; each element is `BattleStartEffect`; each element's fields round-trip

- **AC-3** (ChapterResult with enum):
  - Given: ChapterResult with `outcome = BattleOutcome.Result.DRAW`, `flags_to_set = ["saved_liu_bei", "met_zhang_fei"]`
  - When: round-trip
  - Then: `loaded.outcome == BattleOutcome.Result.DRAW` (integer value 1); `loaded.flags_to_set` equals original Array[String] with both flags

- **AC-4** (InputContext primitives):
  - Given: InputContext with `target_coord = Vector2i(5, 7)`, `target_unit_id = 42`, `source_device = 2`
  - When: round-trip
  - Then: all 3 fields byte-identical

- **AC-5** (Enum ordering preservation — TR-save-load-005 append-only):
  - Given: three BattleOutcome instances with results WIN, DRAW, LOSS
  - When: each saved then loaded
  - Then: `loaded_win.result == 0`, `loaded_draw.result == 1`, `loaded_loss.result == 2`
  - Edge: this is a persistence-contract regression test — fails if BattleOutcome.Result enum is ever reordered without a migration

- **AC-6** (empty boundary):
  - Given: BattleOutcome with `surviving_units = PackedInt64Array()` (empty), `defeated_units = PackedInt64Array()`, `chapter_id = ""`
  - When: round-trip
  - Then: all fields preserve empty state; no null-vs-empty-array drift

- **AC-7** (cleanup):
  - Given: `before_test` creates tmp dir; `after_test` removes tmp files
  - When: all tests finish
  - Then: `user://tmp/` contains no leftover payload files
  - Edge: test failure does not prevent cleanup (use `DirAccess.remove_absolute` in `after_test` unconditionally)

- **AC-8** (deterministic):
  - Given: 10 consecutive test runs
  - Then: identical pass results; no flakiness

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/core/payload_serialization_test.gd` — must exist and pass in CI
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (payload classes must exist)
- **Unlocks**: Save/Load implementation (ADR-0003 depends on this contract); SaveManager Story 001 + 002 (reuses the pattern for SaveContext + EchoMark)

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 8/8 story ACs passing (6 explicit test functions + 2 structural disciplines); 32/32 full unit suite green in ~289ms
**Verdict**: COMPLETE WITH NOTES

**Test Evidence**: `tests/unit/core/payload_serialization_test.gd` — 8 GdUnit4 test functions, 522 LOC, Integration gate BLOCKING satisfied

**Code Review**: Complete — `/code-review` initial verdict **APPROVED WITH SUGGESTIONS** (0 BLOCKING, 0 WARNING, 5 SUGGESTIONS). Option A accepted as-is: top 2 suggestions logged as tech debt, remainder as style/speculative. No code changes.

**Files delivered** (all in-scope, zero src/ changes):
- `tests/unit/core/payload_serialization_test.gd` (+ `.uid` sidecar) — 8 test functions + 6 `_make_populated_*` factory functions + `_save_and_load` helper + `before_test`/`after_test` cleanup discipline + `_tmp_paths` registry
- Korean Unicode coverage on `BattleOutcome.chapter_id` (`"ch_03_리푸쉬"`) + `ChapterResult.chapter_id` (`"ch_02_관도"`)
- AC-5 enum ordering regression test explicitly pins WIN=0/DRAW=1/LOSS=2 per TR-save-load-005 append-only invariant
- AC-6 empty boundary test explicitly asserts non-null + type-preserved + size-0 for empty PackedInt64Array, empty String

**Deviations**:
- **Story AC-2 spec-wording correction applied in-place**: story originally said `deployment_positions: "Vector2i keys → int values"`. Correct direction per `BattlePayload` class docstring + ADR-0001 §Signal Contract Schema §1 is `int (unit_id) → Vector2i (grid coord)`. Test implementation uses correct direction; story text corrected during this closure.
- No other deviations. Manifest version match. ADR-0001 §Implementation Guidelines §4 + §Validation Criteria V-3 satisfied. ADR-0003 TR-save-load-004 (CACHE_MODE_IGNORE) + TR-save-load-005 (append-only enum ordering) mirrored.

**Engine-API notes codified** (relevant for future serialization tests — save-manager epic):
1. `PackedInt64Array` element-wise equality via `a == b`; no `.is_equal()` GdUnit4 idiom for packed arrays — use `assert_bool(a == b).is_true()`
2. `Array[BattleStartEffect]` may lose typed-array wrapper on round-trip — always verify elements via `is BattleStartEffect` at element level, not outer Array typing
3. Dictionary with `int → Vector2i` round-trips correctly in Godot 4.6 `.tres` format
4. `DirAccess.remove_absolute` on macOS/iOS accepts either `user://` paths directly or globalized paths — globalize call is redundant but harmless
5. `_save_and_load` helper pattern (centralise save+assert+load, return null on failure, caller early-returns) prevents cascading null-deref noise

**Advisory follow-ups** (logged to `docs/tech-debt-register.md`):
- **TD-010** — `after_test` discards `DirAccess.remove_absolute` return value; silent cleanup failures accumulate in `user://tmp/` across repeated local runs. Recommend `push_warning` on non-OK.
- **TD-011** — Per-factory field-count maintenance guard missing. If a developer adds an `@export` field to a payload class but forgets to update the corresponding `_make_populated_*` factory, the new field carries type-default through round-trip and passes vacuously.

**Deferred in-situ** (not logged as tech debt):
- S-1 style nit (`== false).is_true()` → `.is_false()`) — 1 LoC
- S-2 unnecessary `ProjectSettings.globalize_path()` calls — 3 locations, style noise
- S-4 parallel-execution collision proofing — speculative future concern (GdUnit4 v6.1.2 is serial-only)
- qa-tester test-naming convention query (`test_[class]_roundtrip` vs `test_[system]_[scenario]_[expected]`) — defer to qa-lead if project enforces strict naming

**Gates skipped** (review-mode=lean): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates. Standalone `/code-review` ran with full gdscript-specialist + qa-tester — findings captured above.
