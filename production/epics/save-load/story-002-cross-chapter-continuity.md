# Story 002: Cross-Chapter Continuity — Destiny State Populator + save_loaded GameBus Signal + Idempotent Hydration

> **Epic**: save-load (#17 Core)
> **Status**: Ready
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

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - **Story 001** (CP-1/2/3 emission contract) — required for CP-2 emission to fire for AC-SL-12 test fixture
  - save-manager epic 8/8 Complete — SaveManager.load_latest_checkpoint method + atomic write + CACHE_MODE_IGNORE load
  - destiny-branch epic 1/1 Complete — DestinyBranchChoice + branch_key (read-only consumer)
  - destiny-state node implementation — if not yet authored, this story scaffolds OR depends on parallel implementation; verify at /story-readiness
- **Unlocks**: Story 003 (Failure surfacing — depends on save_loaded signal existing for null-payload edge cases + save_load_failed contract validation)
