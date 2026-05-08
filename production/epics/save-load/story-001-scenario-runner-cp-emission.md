# Story 001: ScenarioRunner CP-1/2/3 Emission Contract

> **Epic**: save-load (#17 Core)
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 hours (3 emission call sites in scenario_runner.gd + 1 integration test; ScenarioRunner state machine is already shipped at sprint-7 S7-02 ba02e02 — this story adds emit-call additions, NOT new state machine logic)
> **Manifest Version**: 2026-05-05

## Context

**GDD**: `design/gdd/save-load.md` rev 1.0 §3.2 Three-Checkpoint Policy (CR-SL-5..8) + §8.1 Three-Checkpoint Emission ACs (AC-SL-1..4)
**Requirement**: `TR-save-load-008` + `TR-save-load-009` + `TR-save-load-010` + `TR-save-load-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — will be added to registry at first /story-readiness invocation per registry update protocol)*

**ADR Governing Implementation**: ADR-0017 (ScenarioRunner — emission source) + ADR-0003 (SaveContext schema + 3-CP policy) + ADR-0002 (SceneManager — CP-2 timing boundary)
**ADR Decision Summary**:
- ADR-0017: ScenarioRunner is the autoload Node at boot order 6 with a 13-state machine + 9-beat per-chapter rhythm; emits scenario-domain GameBus signals + invokes 3 save-checkpoint emissions per chapter at the BEAT_1_INTRO entry + RETURNING_FROM_BATTLE→IDLE post-Beat-7 transition + next-chapter BEAT_1_INTRO entry boundaries.
- ADR-0003: `save_checkpoint_requested(SaveContext)` is a GameBus Persistence-domain signal; ScenarioRunner is the sole emitter (per CR-SL-8); subscribers (Destiny State, etc.) populate the SaveContext via subscription pattern; SaveManager performs the disk write after CONNECT_DEFERRED ordering guarantees deferred-frame serialization.
- ADR-0002: SceneManager owns the RETURNING_FROM_BATTLE → IDLE transition that gates CP-2 timing; ScenarioRunner observes via `battle_outcome_resolved` handler and emits `save_checkpoint_requested` on that transition.

**Engine**: Godot 4.6 | **Risk**: LOW (no new post-cutoff API surface; uses existing GameBus signal pattern + existing ScenarioRunner state machine; all primitives already validated by save-manager epic green tests)
**Engine Notes**: GameBus signal CONNECT_DEFERRED ordering is mandatory per ADR-0001 §5 + ADR-0003 §Decision §3-CP policy. The deferred-handler-after-state-advance race documented in `.claude/rules/godot-4x-gotchas.md` G-27 applies — emit-then-state-advance pattern in ScenarioRunner means subscribers reading source-autoload state via getter MUST cache at signal-emit time, NOT re-query in the deferred handler. This story emits the signal; consumer-side caching is story-002's responsibility.

**Performance**: N/A — signal emission at chapter-boundary state transitions (3 per chapter), not in `_process` / `_physics_process` hot loop. No frame-budget impact expected. Per `.claude/rules/engine-code.md`: emit cost is constant-time signal dispatch + deferred-frame subscriber handler invocation; total across a chapter is O(3) emissions = negligible.

**Control Manifest Rules (Core layer)**:
- Required: ScenarioRunner is the **sole emitter** of `save_checkpoint_requested(ctx)` per CR-SL-8 + ADR-0001 sole-emitter discipline. No other system may emit this signal.
- Required: All ScenarioRunner GameBus emissions use the existing autoload pattern (`GameBus.signal.emit(payload)`); no new signal-routing infrastructure needed.
- Required: SaveContext populated at emission time captures ScenarioRunner's owned fields ONLY (chapter_id, chapter_number, last_cp, outcome, branch_key); cross-system fields (echo_count, echo_marks_archive, flags_to_set, scenario_path_key) populated by subscribers per CR-SL-15 + CR-SL-16. Story-002 ships those.
- Forbidden: ScenarioRunner reading `SaveManager` autoload state directly (no `SaveManager.foo()` calls in scenario_runner.gd); save persistence is a downstream consumer of the emitted signal, not an upstream caller.
- Forbidden: Synchronous `ResourceSaver.save()` calls in ScenarioRunner; SaveManager handles disk write on its deferred-frame turn.
- Guardrail: Three-CP-emission contract MUST fire EXACTLY ONCE per CP boundary per chapter (AC-SL-1..4). Idempotency: if ScenarioRunner re-enters BEAT_1_INTRO without a chapter transition (e.g., a state machine loop bug), the CP emission MUST NOT fire twice. Defensive guard: emission gated on `_state_just_entered` flag OR equivalent state-transition-detect.

---

## Acceptance Criteria

*From `design/gdd/save-load.md` §8.1 (verbatim AC text):*

- [ ] **AC-SL-1**: Given a fresh chapter (chapter_id = `&"ch01_changbanpo"`) starting at BEAT_1_INTRO, when ScenarioRunner enters BEAT_1, then `save_checkpoint_requested(ctx)` is emitted exactly once with `ctx.chapter_id == &"ch01_changbanpo"` AND `ctx.last_cp == 1` AND `ctx.chapter_number == 1`.
- [ ] **AC-SL-2**: Given a chapter resolved at Beat 7 with outcome WIN + branch_key `&"WIN_changbanpo_default"`, when SceneManager transitions RETURNING_FROM_BATTLE → IDLE, then `save_checkpoint_requested(ctx)` is emitted exactly once with `ctx.last_cp == 2` AND `ctx.outcome == BattleOutcome.WIN_AS_INT` AND `ctx.branch_key == &"WIN_changbanpo_default"`.
- [ ] **AC-SL-3**: Given Chapter 1 just resolved + Chapter 2 enters at BEAT_1_INTRO, when ScenarioRunner enters BEAT_1 of Chapter 2, then `save_checkpoint_requested(ctx)` is emitted with `ctx.last_cp == 3` AND `ctx.chapter_number == 2`. (CP-3 marks "previous chapter completed + transitioned" per CR-SL-5.)
- [ ] **AC-SL-4**: Given a chapter complete cycle (CP-1 → battle → CP-2 → next chapter CP-1 (= prior chapter's CP-3)), when all three CPs fire, then 3 distinct files exist in `user://saves/slot_X/`: `ch_01_cp_1.res` + `ch_01_cp_2.res` + `ch_02_cp_1.res`. (Note: ch_01's CP-3 == ch_02's CP-1 by ScenarioRunner emission sequence.)

---

## Implementation Notes

*From ADR-0017 + ADR-0003 + GDD §3.2 CR-SL-5..8:*

1. **3 emission call sites in `src/core/scenario_runner.gd`** (file currently exists; story shipped at sprint-7 S7-02 ba02e02). Locate the state machine entry handlers:
   - Site 1 — BEAT_1_INTRO entry handler (CP-1): emits with `last_cp=1`, `chapter_id=current_chapter.id`, `chapter_number=current_chapter.number`, `outcome=0` (no resolution yet), `branch_key=&""` (no branch yet)
   - Site 2 — `_on_battle_outcome_resolved(...)` post-Beat-7 SceneManager RETURNING_FROM_BATTLE→IDLE observer (CP-2): emits with `last_cp=2`, `outcome=BattleOutcome.{WIN|DRAW|LOSS}_AS_INT` per resolution, `branch_key=resolved.branch_key` per F-DB-1, `chapter_id` + `chapter_number` carried from current_chapter.
   - Site 3 — Next-chapter BEAT_1_INTRO entry handler (CP-3): same payload as Site 1 BUT `last_cp=3` AND `chapter_number=N+1`. Distinguishes "fresh chapter start" from "first save after a successful transition" per CR-SL-5. ScenarioRunner emits CP-3 of Chapter N at the same timing as CP-1 of Chapter N+1 — see CR-SL-5 + AC-SL-4 note.

2. **SaveContext payload construction** (per CR-SL-1 + ADR-0003 §Key Interfaces):
   - Build via `SaveContext.new()` then assign all 12 @export fields. Cross-system fields (echo_count + echo_marks_archive + flags_to_set + scenario_path_key + saved_at_unix + play_time_seconds) are populated by Destiny State subscriber in story-002 — ScenarioRunner sets these to default values (0 / [] / PackedStringArray() / &"" / Time.get_unix_time_from_system() / 0) at emission time.
   - `slot_id` field: read from `SaveManager.get_active_slot()` if available; otherwise default to 1. (SaveManager autoload is at boot order 3, ScenarioRunner at 6 — ordering guarantees SaveManager is available.)

3. **CONNECT_DEFERRED ordering** (per ADR-0001 §5 + CR-SL-8):
   - The signal is emitted with default `Object.CONNECT_DEFERRED` flag (handled at the GameBus subscription layer, NOT at the emit call site). ScenarioRunner uses standard `GameBus.save_checkpoint_requested.emit(ctx)` — no special flag passed.
   - Subscribers (Destiny State in story-002, SaveManager already-shipped) handle deferred-frame execution.

4. **Idempotency guard** (per AC-SL-1 + AC-SL-3 "exactly once"):
   - Each state-machine-entry handler has access to a state-transition flag (the `_state` field's prior-vs-current value). The CP emission fires ONLY on the boundary transition into BEAT_1_INTRO — re-entering the same state without leaving (illegal but defensive) MUST NOT re-fire. Use the existing state-transition-detect logic in scenario_runner.gd (whatever pattern is already there at S7-02 ba02e02).

5. **Testing pattern** — single integration test file with 4 test functions (one per AC), each setting up the relevant state machine state + asserting emission count + payload fields via Array-capture lambda pattern (G-4 from godot-4x-gotchas.md):
   ```gdscript
   var captures: Array = []
   GameBus.save_checkpoint_requested.connect(func(ctx: SaveContext) -> void:
       captures.append({
           "chapter_id": ctx.chapter_id,
           "chapter_number": ctx.chapter_number,
           "last_cp": ctx.last_cp,
           "outcome": ctx.outcome,
           "branch_key": ctx.branch_key,
       })
   )
   # trigger state transition
   await get_tree().process_frame
   assert_int(captures.size()).is_equal(1)
   assert_str(captures[0].chapter_id as String).is_equal("ch01_changbanpo")
   ```

6. **Test fixture for CP-2 (RETURNING_FROM_BATTLE→IDLE simulation)**:
   - Use existing SceneManager test seam pattern (e.g., `SceneManagerStub.swap_in()` if available, OR call `SceneManager._transition_to(IDLE)` directly via test helper). Reference precedent: `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` already exercises this transition for sprint-7 S7-02 acceptance.

7. **AC-SL-4 file-existence assertion**:
   - Test helper writes 3 SaveContext instances via SaveManager (already shipped) at the 3 emission timings; integration test asserts `FileAccess.file_exists("user://saves/slot_1/ch_01_cp_1.res")` etc. Use `user://` test-mode override to avoid polluting dev-machine save directory.

---

## Out of Scope

*Handled by neighbouring stories or already shipped — do not implement here:*

- **Story 002** Cross-chapter continuity: Destiny State populator populates `echo_count` + `echo_marks_archive` + `flags_to_set` + `scenario_path_key` BEFORE SaveManager fires the deferred-frame disk write. Story 001 emits with these fields at default values; story 002 fills them via subscriber.
- **Story 002** `save_loaded(ctx)` GameBus signal (4th Persistence-domain signal); story 001 emits the existing `save_checkpoint_requested` signal only.
- **Story 003** Failure surfacing tests + 3 enforcement lints (CACHE_MODE_IGNORE + migration purity + @export discipline).
- **save-manager epic** (already 8/8 Complete): SaveContext class definition + SaveManager autoload + atomic write protocol + `_find_latest_cp_file` + slot management + migration registry scaffold.
- **scenario-progression epic** (already 1/1 Complete): ScenarioRunner state machine + 9-beat per-chapter rhythm + ChapterDefinition Resource + 7-signal contract.
- **destiny-branch epic** (already 1/1 Complete): DestinyBranchChoice Resource + branch_key emission via F-DB-1.
- **SceneManager** (already 7/7 Complete): RETURNING_FROM_BATTLE → IDLE state transition.

---

## QA Test Cases

*Lean-mode skipped QL-STORY-READY gate; test specs derived from GDD ACs verbatim. /story-readiness will validate test-spec adequacy at story implementation kick-off.*

**Story Type: Integration — automated test specs**

- **AC-SL-1** (CP-1 Beat 1 entry):
  - Given: ScenarioRunner is in IDLE state; chapter_id = `&"ch01_changbanpo"`, chapter_number = 1
  - When: ScenarioRunner transitions to BEAT_1_INTRO state (via test helper trigger)
  - Then: `GameBus.save_checkpoint_requested` signal captures exactly 1 emission with `ctx.chapter_id == &"ch01_changbanpo"` AND `ctx.last_cp == 1` AND `ctx.chapter_number == 1`
  - Edge cases: re-entering BEAT_1_INTRO without leaving (idempotency guard fires); chapter_id `&""` (empty StringName fallback)

- **AC-SL-2** (CP-2 RETURNING_FROM_BATTLE → IDLE):
  - Given: ScenarioRunner observed Beat 7 resolution with outcome=WIN + branch_key=`&"WIN_changbanpo_default"`
  - When: SceneManager transitions RETURNING_FROM_BATTLE → IDLE (via test helper)
  - Then: `GameBus.save_checkpoint_requested` captures 1 emission with `ctx.last_cp == 2` AND `ctx.outcome == BattleOutcome.WIN_AS_INT` AND `ctx.branch_key == &"WIN_changbanpo_default"`
  - Edge cases: outcome=DRAW + outcome=LOSS each emit correctly; branch_key=`&""` (no canonical-branch resolution) is acceptable for non-canonical paths

- **AC-SL-3** (CP-3 next-chapter Beat 1):
  - Given: Chapter 1 has just resolved (CP-2 fired); ScenarioRunner advances to Chapter 2 BEAT_1_INTRO
  - When: ScenarioRunner enters BEAT_1_INTRO of Chapter 2
  - Then: `GameBus.save_checkpoint_requested` captures 1 emission with `ctx.last_cp == 3` AND `ctx.chapter_number == 2`
  - Edge cases: Chapter 2 has no Chapter 1 predecessor in test fixture (CP-3 should still fire because state machine entered BEAT_1_INTRO; but `last_cp` distinguishes vs CP-1 at Chapter 2 — the test fixture ensures CP-3 fires by simulating the post-resolution transition)

- **AC-SL-4** (3 distinct files in slot directory):
  - Given: Chapter 1 + Chapter 2 traversal with CP-1 → CP-2 → CP-3 (= Chapter 2 CP-1) emissions; SaveManager writes each to disk
  - When: All three CPs fire in sequence + SaveManager deferred-frame writes complete
  - Then: `user://saves/slot_1/ch_01_cp_1.res` + `ch_01_cp_2.res` + `ch_02_cp_1.res` exist on disk; each is a valid SaveContext per ResourceLoader.load
  - Edge cases: slot_id ≠ 1 (slot 2 + slot 3 produce identical file accumulation in their respective directories per CR-SL-7 multi-slot independence)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration test at `tests/integration/scenario_runner/save_checkpoint_emission_test.gd` — must exist and pass; ~4 test functions (one per AC) + ~2-4 edge case tests; estimated 6-8 tests total

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - save-manager epic 8/8 Complete (2026-04-24) — Platform substrate provides SaveContext class + SaveManager autoload + atomic write
  - scenario-progression epic 1/1 Complete (2026-05-07) — ScenarioRunner state machine
  - scene-manager epic 7/7 Complete — RETURNING_FROM_BATTLE → IDLE transition
- **Unlocks**: Story 002 (Cross-chapter continuity — depends on the 3-CP emission firing for Destiny State subscriber to receive)
