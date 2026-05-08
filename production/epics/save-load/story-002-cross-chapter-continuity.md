# Story 002: Cross-Chapter Continuity — Destiny State Populator + save_loaded GameBus Signal + Idempotent Hydration

> **Epic**: save-load (#17 Core)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 hours (Destiny State populator subscription + ADR-0001 minor amendment for `save_loaded` signal + idempotent hydration test); resolves OQ-SL-3 (signal-vs-method-call dispatch)
> **Manifest Version**: 2026-05-05

## Context

**GDD**: `design/gdd/save-load.md` rev 1.0 §3.5 Cross-Chapter Continuity (CR-SL-15..17) + §3.6 Hydration Contract (CR-SL-18..20) + §8.4 Cross-Chapter Continuity ACs (AC-SL-12..14) + §8.6 Determinism + Round-Trip ACs (AC-SL-18..20) + §OQ-SL-3 (signal vs method-call dispatch resolution candidate)
**Requirement**: `TR-save-load-012` + `TR-save-load-013` + `TR-save-load-014` + `TR-save-load-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — will be added to registry at first /story-readiness invocation)*

**ADR Governing Implementation**: ADR-0003 (SaveContext schema + 3.5 Cross-Chapter Continuity contract) + ADR-0001 (GameBus minor amendment per Evolution Rule #4 to add `save_loaded(SaveContext)` 4th Persistence-domain signal) + ADR-0017 (ScenarioRunner emission timing — story-001 ships)
**ADR Decision Summary**:
- ADR-0003: Cross-chapter continuity is **populator-driven**: at `save_checkpoint_requested(ctx)`, Destiny State (autoload subscriber per CR-DS-7 + CR-DS-16) populates `ctx.echo_count` + `ctx.echo_marks_archive` + `ctx.flags_to_set`. SaveManager observes the signal post-population (CONNECT_DEFERRED ordering) and writes to disk. Hydration is method-call OR signal-driven; this story implements signal-driven per OQ-SL-3 resolution.
- ADR-0001 minor amendment (Evolution Rule #4): Add `save_loaded(ctx: SaveContext)` as the 4th Persistence-domain GameBus signal (alongside existing `save_checkpoint_requested` + `save_persisted` + `save_load_failed`). Single emitter: SaveManager. Subscribers: Destiny State + ScenarioRunner.
- ADR-0017: ScenarioRunner emits the CP-1/2/3 signals (story-001) but does NOT populate the Destiny State fields — those are owned by Destiny State subscriber per CR-SL-15.

**Engine**: Godot 4.6 | **Risk**: LOW (signal addition follows existing GameBus pattern; populator subscription pattern already in-flight via Destiny State per CR-DS-7; no new post-cutoff API surface)
**Engine Notes**:
- G-27 (deferred-handler-after-state-advance race) APPLIES: ScenarioRunner emits `save_checkpoint_requested` then advances state synchronously. Destiny State's CONNECT_DEFERRED handler MUST cache its state at signal-emit time, NOT re-query ScenarioRunner via getter. Pattern from G-27: cache `_active_chapter` at `chapter_started` emit time; clear at `chapter_completed` emit time. Apply same pattern for echo/flag accumulation if Destiny State doesn't already.
- G-10 (autoload identifier binding) APPLIES: tests must emit on the REAL GameBus identifier, not on a stub mounted at `/root/GameBus` post-subscriber-_ready. See G-10 + Destiny State test pattern at `tests/unit/feature/destiny_state/destiny_state_test.gd`.
- G-28 (bulk-disconnect-all in test cleanup): tests for this story MUST NOT use bulk-disconnect-all; Destiny State autoload connects in `_ready` ONCE — bulk-disconnect would sever its production subscription and break subsequent tests. Use the cached-Callable disconnect pattern (G-28 Pattern A).

**Performance**: N/A — populator subscriber runs at 3 chapter-boundary CP emissions per chapter (not in hot loop); deferred-frame execution; field-copy operations (echo_count + Array assignment + PackedStringArray assignment) are O(N) where N = number of EchoMarks (typical N=3-10 per chapter; capped per OQ-SL-4 future decision). `save_loaded` signal emit + subscriber rehydration runs once per game-resume (not per-frame); negligible. ResourceSaver/Loader round-trip at AC-SL-13 test fixture is bounded by SaveContext payload size (~12 fields + N EchoMarks); typical <50KB per save per ADR-0003 perf gates.

**Control Manifest Rules (Core layer)**:
- Required: SaveContext populator pattern — Destiny State subscribes to `save_checkpoint_requested(ctx)` with CONNECT_DEFERRED, populates ctx.echo_count + ctx.echo_marks_archive + ctx.flags_to_set, returns. CR-SL-15 + CR-DS-16.
- Required: `scenario_path_key` field is `"::"`-delimited per F-SP-4 cross-doc bridge; `branch_path_id` regex `^[A-Za-z0-9_]+$` (CR-SL-16). Migration note: pre-rev-2.1 `"-"` delimiter migration documented but not yet shipped (no real saves exist; project pre-launch).
- Required: ADR-0001 minor amendment — `save_loaded(ctx: SaveContext)` declared in `src/core/game_bus.gd` Persistence-domain section; sole emitter SaveManager; ratified per Evolution Rule #4 (5th-precedent pattern after save_checkpoint_requested + scenario_complete + scenario_beat_retried + ADR-0017 line 209 instance-form widening + ADR-0014 §8 6th LOCAL signal additive amendment).
- Required: Hydration is **idempotent** per CR-SL-20 — calling `load_latest_checkpoint()` twice yields field-identical SaveContext (modulo Object identity); structurally guaranteed by CACHE_MODE_IGNORE re-read.
- Forbidden: Destiny State directly reading SaveManager autoload state (no `SaveManager.foo()` calls in destiny_state.gd); use the populator pattern via signal subscription.
- Forbidden: SaveManager directly distributing loaded SaveContext to subscribers via setter calls (e.g., `DestinyState.set_state(ctx)`); use signal-driven dispatch via `save_loaded.emit(ctx)`.
- Guardrail: `save_loaded` signal subscribers MUST handle `null` payload gracefully (per CR-SL-22 never-crash invariant — empty slot or load failure produces null OR `save_load_failed` instead of `save_loaded`).

---

## Acceptance Criteria

*From `design/gdd/save-load.md` §8.4 + §8.6 (verbatim AC text):*

- [ ] **AC-SL-12**: Given a complete chapter cycle with 3 EchoMarks accumulated + 1 divergence flag set in Chapter 1, when `save_checkpoint_requested(ctx)` fires at CP-2, then Destiny State populates `ctx.echo_count == 3` AND `ctx.echo_marks_archive.size() == 3` AND `ctx.flags_to_set.size() == 1` (per CR-SL-15 + CR-DS-16 contract).
- [ ] **AC-SL-13**: Given a SaveContext with full Destiny State populated, when round-tripped through ResourceSaver → ResourceLoader, then loaded ctx has bitwise-equivalent echo_marks_archive + flags_to_set + echo_count to pre-save state (per AC-DS-20 mirror).
- [ ] **AC-SL-14**: Given a SaveContext from a multi-chapter run with `scenario_path_key == "WIN_ch1_default::DRAW_ch2_fallback"`, when persisted + loaded, then loaded ctx.scenario_path_key field-equals the source string (delimiter `"::"` preserved per CR-SL-16). (Future schema_version 2 — MVP scope skips this AC for v1; ScenarioRunner persists `scenario_path_key` only at SCENARIO_END epilogue selection per scenario-progression.md F-SP-4. Implementation: leave the field as default `&""` for MVP unless scenario-progression epic has shipped this populator.)
- [ ] **AC-SL-20**: Given an idempotent hydration pattern (load → distribute → no further mutation → load again), when `load_latest_checkpoint()` is called twice in succession, then both calls return field-identical ctx (per CR-SL-20 idempotency contract).

---

## Implementation Notes

*From ADR-0003 + ADR-0001 + GDD §3.5 CR-SL-15..17 + §3.6 CR-SL-18..20 + OQ-SL-3 resolution:*

1. **Destiny State populator subscription** (in `src/feature/destiny_state/destiny_state.gd` if exists; OR scaffold the file at this story if not yet authored):
   - Connect to `GameBus.save_checkpoint_requested` with `CONNECT_DEFERRED` flag in DestinyState `_ready()` per ADR-0001 §5
   - Handler signature: `func _on_save_checkpoint_requested(ctx: SaveContext) -> void`
   - Handler body: populate `ctx.echo_count = _archive_count` + `ctx.echo_marks_archive = _echo_archive` + `ctx.flags_to_set = _flags`
   - Apply G-27 caching pattern: if Destiny State reads ScenarioRunner state in the handler (e.g., to filter echoes by chapter), cache that state at the prior `chapter_started` emit, NOT in this handler
   - Verify the handler runs BEFORE SaveManager's deferred-frame disk write — both subscribers connect with CONNECT_DEFERRED; ordering guarantee is "subscribers fire in registration order on the same deferred frame." Destiny State autoload (load order ~5 per autoload chain) registers earlier than SaveManager (load order 3) — wait, SaveManager is at load order 3 which is BEFORE Destiny State; verify this at /story-readiness time. If SaveManager's handler fires first, the populator pattern breaks. Consider explicit ordering via `Object.CONNECT_DEFERRED | Object.CONNECT_PERSIST` flags OR autoload load order adjustment.

2. **ADR-0001 minor amendment** for `save_loaded(SaveContext)` 4th Persistence-domain signal:
   - Declare in `src/core/game_bus.gd` Persistence-domain section: `signal save_loaded(ctx: SaveContext)`
   - Update ADR-0001 §5 Persistence-domain signal list: append `save_loaded(SaveContext)` as 4th signal alongside `save_checkpoint_requested` + `save_persisted(int, int)` + `save_load_failed(String, String)`
   - Update ADR-0001 §Status Evolution Rule #4 amendment log: "Persistence-domain widening: save_loaded(SaveContext) added to support OQ-SL-3 resolution (signal-driven hydration over method-call). 5th project precedent of ratification widening at upstream-ADR acceptance."
   - Update `docs/architecture/architecture-traceability.md` to reflect the amendment (manual edit OR re-run /architecture-review)

3. **SaveManager emits `save_loaded(ctx)`**:
   - In `src/core/save_manager.gd` `load_latest_checkpoint()` method (already shipped at sprint-7 save-manager epic), after the `migrate_to_current(ctx)` call returns successfully, emit `GameBus.save_loaded.emit(ctx)` BEFORE returning ctx
   - On null/error path: emit `save_load_failed` instead of `save_loaded` per CR-SL-22 never-crash invariant
   - Verify the emit fires CONNECT_DEFERRED-compatible; SaveManager itself doesn't `await` the emission, just fires-and-forgets

4. **Destiny State subscribes to `save_loaded`**:
   - In DestinyState `_ready()`, connect to `GameBus.save_loaded` with CONNECT_DEFERRED
   - Handler signature: `func _on_save_loaded(ctx: SaveContext) -> void`
   - Handler body: rehydrate Destiny State internal fields from ctx (echo_count, echo_marks_archive, flags_to_set, scenario_path_key)
   - Idempotency: handler must be re-runnable without state corruption — re-loading the same ctx produces the same internal state

5. **scenario_path_key delimiter** (CR-SL-16):
   - Source: scenario-progression F-SP-4 ScenarioResult composes `branch_path_id` values using `"::"` separator (e.g., `"WIN_ch1_default::DRAW_ch2_fallback::DRAW_ch3_echo"`)
   - SaveContext field carries this composed string verbatim (set by ScenarioRunner at SCENARIO_END per scenario-progression.md F-SP-4; OUT OF SCOPE for this story since SCENARIO_END isn't reached in MVP chapter-1 scope)
   - For MVP: leave `scenario_path_key` field at default `&""`; round-trip test (AC-SL-14) seeds the field manually in the test fixture, NOT via ScenarioRunner emission

6. **Idempotent hydration test (AC-SL-20)**:
   - Test pattern: write a SaveContext via SaveManager.save_checkpoint, call load_latest_checkpoint twice in succession, deep-equal compare the two loaded ctx instances
   - CACHE_MODE_IGNORE flag at the load site (per ADR-0003 §Decision §Atomic Write step 3) is what guarantees the second load re-reads from disk rather than returning a cached object; verify the existing save_manager.gd implementation uses CACHE_MODE_IGNORE on every load path
   - Object identity check: assert `load_1 != load_2` (distinct Object instances) AND `load_1.echo_count == load_2.echo_count` (field-equality) — proves disk round-trip + idempotency

7. **Single integration test file** at `tests/integration/save_load/cross_chapter_continuity_test.gd`:
   - Test 1 (AC-SL-12): seed Destiny State with 3 echoes + 1 flag, trigger CP-2 emission, capture SaveContext via test-side handler, assert populated fields
   - Test 2 (AC-SL-13): full ResourceSaver → ResourceLoader round-trip preserves echo_marks_archive + flags_to_set bitwise (Destiny State seeded → save → load → assert bitwise equal)
   - Test 3 (AC-SL-14): scenario_path_key `"::"`-delimiter survives round-trip (manually seed; no ScenarioRunner involvement at MVP)
   - Test 4 (AC-SL-20): load_latest_checkpoint twice, assert distinct identity but field-equality
   - Edge cases: empty echo_archive (echo_count == 0), empty flags (flags_to_set.size() == 0), mid-chapter echoes (CR-SL-15 filtering by chapter — verify Destiny State only populates current-chapter echoes if that filtering applies; verify against destiny-state.md GDD)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001** (CP-1/2/3 emission contract): ScenarioRunner emits `save_checkpoint_requested(ctx)`. Story 002 subscribes to those emissions but does not implement them.
- **Story 003** (failure surfacing tests + 3 enforcement lints): null-payload handling test at the GameBus signal layer; `save_load_failed` path for `save_loaded` emission failure.
- **scenario-progression epic** (already 1/1 Complete): scenario_path_key composition at SCENARIO_END epilogue is OUT OF SCOPE for MVP chapter-1 (only 3 chapters MVP per game-concept.md; SCENARIO_END not reached). MVP saves leave `scenario_path_key` at default `&""`.
- **destiny-state implementation**: if `src/feature/destiny_state/destiny_state.gd` is not yet authored, this story scaffolds it OR relies on a parallel destiny-state implementation epic. Verify at /story-readiness time. If destiny-state node doesn't exist, escalate to a `/architecture-decision` for destiny-state node implementation OR scaffold inline (low risk; CR-DS-* contracts are well-defined per design/gdd/destiny-state.md).
- **save-manager epic** (already 8/8 Complete): SaveManager.load_latest_checkpoint method body + atomic write + 3-slot management.
- **destiny-branch epic** (already 1/1 Complete): branch_key derivation from DestinyBranchChoice per F-DB-1; story-002 reads but does not modify branch_key field.

---

## QA Test Cases

*Lean-mode skipped QL-STORY-READY gate; test specs derived from GDD ACs verbatim.*

**Story Type: Integration — automated test specs**

- **AC-SL-12** (Destiny State populator):
  - Given: Destiny State seeded with 3 EchoMarks + 1 flag in Chapter 1; ScenarioRunner state machine reaches CP-2 trigger
  - When: ScenarioRunner emits `save_checkpoint_requested(ctx)` with default ctx fields
  - Then: deferred-frame later, test-side handler captures the same ctx; `ctx.echo_count == 3` AND `ctx.echo_marks_archive.size() == 3` AND `ctx.flags_to_set.size() == 1`
  - Edge cases: empty Destiny State (0 echoes / 0 flags) → ctx fields are default 0 / [] / PackedStringArray()

- **AC-SL-13** (Round-trip preservation):
  - Given: SaveContext fully populated (3 echoes + 1 flag + scenario_path_key seeded manually) saved via SaveManager
  - When: load_latest_checkpoint reads the same file back
  - Then: loaded ctx echo_marks_archive[i].beat_index / outcome / tag bitwise-equal to source for all 3; flags_to_set bitwise-equal; scenario_path_key string-equal
  - Edge cases: 5 EchoMarks (cap test); special characters in flag strings (PackedStringArray UTF-8 handling)

- **AC-SL-14** (scenario_path_key delimiter):
  - Given: SaveContext with scenario_path_key = `"WIN_ch1_default::DRAW_ch2_fallback"` seeded manually
  - When: ResourceSaver writes + ResourceLoader reads with CACHE_MODE_IGNORE
  - Then: loaded ctx.scenario_path_key == source string; "::" separator preserved
  - Edge cases: single segment (no separator) e.g., `"WIN_ch1_default"`; empty string default `&""`

- **AC-SL-20** (Idempotent hydration):
  - Given: SaveContext written to slot_1 via SaveManager.save_checkpoint
  - When: SaveManager.load_latest_checkpoint() called twice in succession with no intervening saves
  - Then: load_1 and load_2 are distinct Object instances (load_1 != load_2 by reference) AND field-equal (deep-compare echo_count, echo_marks_archive, flags_to_set, scenario_path_key)
  - Edge cases: empty slot (both loads return null; null == null); slot with corrupt file (both loads return null + save_load_failed fires twice)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test at `tests/integration/save_load/cross_chapter_continuity_test.gd` — must exist and pass; ~4 test functions (one per AC) + ~3-4 edge case tests; estimated 7-9 tests total

**Status**: [x] Created at `tests/integration/save_load/cross_chapter_continuity_test.gd` (9 test functions; passes 1253/1253 with 0 errors / 0 failures / 0 orphans / exit 0; 54th FFB streak preserved)

---

## Dependencies

- **Depends on**:
  - **Story 001** (CP-1/2/3 emission contract) — required for CP-2 emission to fire for AC-SL-12 test fixture
  - save-manager epic 8/8 Complete — SaveManager.load_latest_checkpoint method + atomic write + CACHE_MODE_IGNORE load
  - destiny-branch epic 1/1 Complete — DestinyBranchChoice + branch_key (read-only consumer)
  - destiny-state node implementation — if not yet authored, this story scaffolds OR depends on parallel implementation; verify at /story-readiness
- **Unlocks**: Story 003 (Failure surfacing — depends on save_loaded signal existing for null-payload edge cases + save_load_failed contract validation)

---

## Completion Notes

**Completed**: 2026-05-08
**Criteria**: 3/4 COVERED + 1/4 DEFERRED (AC-SL-14 deferred to schema_v2 per story §AC-SL-14 explicit MVP-skip — `scenario_path_key` field not yet on `SaveContext`).
**Code Review**: Complete (godot-gdscript-specialist + qa-tester, lean mode; verdict APPROVED WITH SUGGESTIONS — 2 minor suggestions applied: `_archived_chapter_counts.clear()` added to `_on_save_loaded` for full idempotency; inline comment on `echo_count > 0` guard intent.
**Test Evidence**: Integration test at `tests/integration/save_load/cross_chapter_continuity_test.gd` (9 test functions) — passes 1253/1253 / 0 errors / 0 failures / 0 orphans / exit 0 (54th FFB streak preserved).

### Files changed (final)

- `src/core/game_bus.gd` — +1 `signal save_loaded(ctx: SaveContext)` (Persistence-domain 4th signal)
- `src/core/save_manager.gd` — `load_latest_checkpoint()` emits `GameBus.save_loaded.emit(migrated)` after `migrate_to_current` succeeds; failure path unchanged (still emits `save_load_failed`)
- `src/feature/destiny_state/destiny_state.gd` — 5th GameBus subscription (`save_loaded` CONNECT_DEFERRED) + matching `_exit_tree` disconnect + new `_on_save_loaded` handler (CR-SL-19/20 idempotent rehydration: clears `_full_archive` + `_chapter_echo_counts` + `_archived_chapter_counts` + `_flags_to_set`; deep-copies EchoMarks per CR-DS-16; maps `ctx.echo_count → _chapter_echo_counts[ctx.chapter_id]` per Option A; null-payload guard per CR-SL-22)
- `tests/integration/save_load/cross_chapter_continuity_test.gd` — NEW (9 test functions covering AC-SL-12 + AC-SL-13 + AC-SL-20 + save_loaded signal contract; AC-SL-14 deferred per story spec)
- `tests/unit/core/game_bus_declaration_test.gd` — `EXPECTED_SIGNALS` 33 → 34; `EXPECTED_RESOURCE_ARG_CLASSES` +1 entry; function rename + count update
- `tests/unit/core/signal_contract_test.gd` — `EXPECTED_SIGNALS` Array entry +1 (save_loaded shape); count comments 27 → 31
- `tests/unit/core/game_bus_diagnostics_test.gd` — `_route_to_domain` regression map +1 entry; function rename
- `docs/architecture/ADR-0001-gamebus-autoload.md` — §9 Persistence-domain table +1 row; inline GameBus snippet +1 line; total signal count 30 → 31; changelog +1 row 2026-05-08

### ACs covered (mapped to test functions)

- **AC-SL-12**: `test_ac_sl12_populator_fills_echo_count_archive_and_flags_when_state_seeded` + `test_ac_sl12_populator_with_empty_destiny_state_yields_zero_count_and_empty_arrays`
- **AC-SL-13**: `test_ac_sl13_round_trip_preserves_echo_marks_archive_and_flags_to_set_bitwise` + `test_ac_sl13_round_trip_with_empty_collections`
- **AC-SL-14**: DEFERRED to schema_v2 (story §AC-SL-14 + §Implementation Notes #5 explicit MVP-skip; `SaveContext` has no `scenario_path_key` field)
- **AC-SL-20**: `test_ac_sl20_load_latest_checkpoint_twice_yields_distinct_objects_with_field_equality` + `test_ac_sl20_load_twice_on_empty_slot_both_return_null`
- **save_loaded signal contract**: `test_save_loaded_signal_emits_after_load_and_rehydrates_destiny_state` + `test_save_loaded_handler_null_payload_guard_is_noop` + `test_save_loaded_handler_idempotent_on_repeat_invocation`

### Deviations (4 ADVISORY; 0 BLOCKING)

1. **AC-SL-14 DEFERRED** — `SaveContext` has no `scenario_path_key` field; story §AC-SL-14 + §Implementation Notes #5 explicit MVP-skip pending scenario-progression epic SCENARIO_END epilogue populator (future schema_version 2). Test file header documents the deferral citing both the story Out of Scope section and the missing field. NOT a coverage gap — author's explicit deferral.
2. **TR-save-load-012..015 not registered** in `docs/architecture/tr-registry.yaml` (Gap 2 carryover from /story-readiness 2026-05-08; resolution path: `/architecture-review` Phase 8 batch). Inherited from story-001 close (story-001 also documented this).
3. **ADR-0003 + GDD §CR-SL-5 wording divergence** on CP-3 timing inherited from story-001 (story-001 Completion Notes already document; story-002 does not change CP-3 timing — implementation is the rehydration symmetric to populator, not an emit-site change). Resolution candidate: `/propagate-design-change` OR `/architecture-review` Phase 8 batch.
4. **5 pre-existing tests count-bumped** (`signal_contract_test.gd` +1 entry / `game_bus_diagnostics_test.gd` +1 routing entry / `game_bus_declaration_test.gd` +1 expected signal) — mechanical hygiene patches required by signal-list keeper tests on every GameBus signal addition; no logic change. Structurally required by the test suite design (these are signal-list keepers, not arbitrary test edits).

### Advisory edge case gaps (qa-tester ADVISORY; deferred to follow-up)

1. AC-SL-13 5-EchoMark cap test (boundary)
2. AC-SL-13 UTF-8 flag-string round-trip (encoding)
3. AC-SL-20 corrupt-file double-null + `save_load_failed` × 2 (story-003 territory per story author's scoping)

### Gotchas applied

- **G-3**: no `class_name` in test file
- **G-4**: `var captures: Array = []` + `captures.append(...)` lambda capture pattern
- **G-10**: emit on REAL `GameBus` autoload identifier (not GameBusStub)
- **G-14**: `godot --headless --import --path .` between file creation and first test run
- **G-15**: `before_test()` / `after_test()` lifecycle (not `before_each`)
- **G-27**: cache state at signal-emit time when querying autoload getters in deferred handlers (not needed here — payload IS the state)
- **G-28**: per-callable disconnect ONLY; pre-existing anti-pattern in `scenario_runner_signal_contract_test.gd` NOT propagated into new file
