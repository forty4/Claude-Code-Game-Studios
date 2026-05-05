# Chapter-1 (장판파) Integration Run Evidence

> **Sprint**: sprint-8 S8-11 (final should-have closure)
> **Date**: 2026-05-05
> **Verdict**: PASS — 8 e2e integration tests + 1015/1015 full regression baseline
> **Test fixture**: `tests/integration/chapter_1_e2e/chapter_1_full_arc_test.gd`
> **Scenario**: `assets/data/scenarios/mvp_shu.json` (chapter-1 ch01_changbanpo)

## Scope

S8-11 validates that the architecture chain shipped across sprint-7 + sprint-8 coordinates correctly when driven through a complete chapter-1 traversal:

```
ScenarioRunner (state machine + 9-beat sequence + signal emit)
  → DestinyBranchJudge (branch_key resolution at Beat 7 entry)
  → Story Event #10 (Beat 1 anchor + Beat 8 revelation + Beat 9 transition + invalid-path UI carve-out)
  → Destiny State #16 (echo archive + flag effects + SaveContext population + cross-chapter snapshot)
```

## Test inventory (8 cases)

| # | Test | AC coverage |
|---|------|-------------|
| 1 | `test_chapter_1_canonical_win_full_arc` | Beat 8 + Beat 9 emits fire during full arc; ScenarioRunner reaches SCENARIO_END |
| 2 | `test_chapter_1_win_resolves_canonical_win_variant` | Variant key `canonical_win` + correct `text_key` per chapter authoring |
| 3 | `test_chapter_1_loss_resolves_defeat_variant` | LOSS path resolves `defeat` variant + `loss_changbanpo_retreat` text |
| 4 | `test_chapter_1_canonical_win_revelation_register_solemn` | Revelation register tag `solemn` (canonical → not Marked Hand) |
| 5 | `test_chapter_1_save_checkpoint_emits_during_arc` | CP-1 fires at Beat 1 with correct chapter_id |
| 6 | `test_chapter_1_completes_without_destiny_state_errors` | No DestinyState invalid-payload guards trip; archive empty (no retries) |
| 7 | `test_chapter_1_invalid_destiny_branch_choice_routes_to_invalid_path_ui` | F-SE-3 D1 BLOCKING: `is_invalid` checked first; no Beat 8 emit on corrupt path |
| 8 | `test_chapter_1_completion_triggers_destiny_state_handler` | DestinyState chapter_completed handler fires; `get_echo_count` returns 0 default |

## Production-bug fix surfaced + closed in same patch

**Bug**: StoryEvent's `_on_chapter_completed` deferred handler (CONNECT_DEFERRED) fires AFTER ScenarioRunner has transitioned to LOADING (next chapter) or SCENARIO_END. By that point `get_current_chapter()` returns the NEXT chapter or null — wrong for Beat 9 reveal of the JUST-completed chapter.

**Fix**: Cache active chapter on `chapter_started` into `_active_chapter: ChapterDefinition`; Beat 8 + Beat 9 handlers prefer cache over `_current_chapter_or_null()` live lookup. Cache cleared on Beat 9 emit so the next chapter_started can re-prime.

**Genuineness**: this is a production-correctness fix, not a test-only workaround. In a multi-chapter scenario, without the cache, Beat 9 would emit chapter N+1's text instead of chapter N's text on transition. Surfaced by the e2e integration test driving the full state machine.

## Test isolation pattern stable

The S8-10 lesson (`scenario_runner_signal_contract_test.gd` bulk-disconnect interference) extends here: e2e tests call `reset_for_tests()` on **3 autoloads** (StoryEvent + DestinyState + ScenarioRunner) in `before_test`/`after_test` to (a) re-establish autoload subscriptions severed by other test cleanups, and (b) restore production /root/ScenarioRunner to clean LOADING state for downstream tests (e.g. battle_scene_smoke).

ScenarioRunner gained a `reset_for_tests()` method this commit, mirroring the established pattern across BalanceConstants + DestinyState + StoryEvent. Pattern is now stable at **4 autoloads with reset_for_tests test seams**.

## Coordination evidence

The e2e tests verify all 4 system contracts coordinate correctly:

- **ScenarioRunner**: emits `chapter_started` (Beat 1 entry) + `save_checkpoint_requested` (CP-1) + `destiny_branch_chosen` (Beat 7) + `chapter_completed` (Beat 9) + `scenario_complete` (LOADING → SCENARIO_END for last chapter)
- **DestinyBranchJudge**: resolves `DestinyBranchChoice` at Beat 7 with chapter-1 branch_table; populates `branch_key` + `is_canonical_history` + `outcome` per F-DB-1
- **StoryEvent**: receives `destiny_branch_chosen`, applies F-SE-1 variant resolution, looks up Beat 8 revelation entry, emits `story_event_resolved(8, variant_key, text_key, cue_tag)` + `story_event_revelation_committed(chapter_id, branch_key, register)`
- **DestinyState**: receives `chapter_completed`, archives prior chapter's echo count, no errors on a no-retry traversal

## What is NOT validated by S8-11

The acceptance criterion is "validates the sprint-7 architecture chain end-to-end" — meaning **system signal coordination** is verified. Out of scope for S8-11:

- **AISystem** archetype pressure during Beat 5 battle simulation: chapter-1 runs through `BEAT_5_BATTLE` via `runner._on_battle_outcome_resolved(outcome)` direct injection — actual unit-vs-unit AI decision-making is exercised in `tests/unit/ai/` archetype-specific tests, not here. AISystem coordination via `ai_action_requested` LOCAL signal is the GridBattleController's per-turn responsibility, separate from the chapter-arc seam this test validates.
- **CP-2 / CP-3 save checkpoint timing**: the SceneManager `RETURNING_FROM_BATTLE → IDLE` boundary that triggers CP-2 (per ADR-0003 + scenario-progression.md) is not exercised in isolated runner mode. Only CP-1 (Beat 1 entry) fires in the test setup.
- **Multi-chapter scenarios**: chapter-1 is the only chapter in mvp_shu.json. Cross-chapter Pillar 4 echo/flag continuity (Destiny State `_archived_chapter_counts` snapshot at chapter advance) is structurally covered but not exercised with 2+ chapters.

These gaps are accepted scope for S8-11. Multi-chapter + save-load + AI-driven Beat 5 are sprint-9+ vertical-slice integration targets.

## Regression baseline

| Run | Total | Errors | Failures | Suites |
|-----|-------|--------|----------|--------|
| Pre-S8-11 baseline | 1007 | 0 | 0 | 110 |
| Post-S8-11 (this commit) | **1015** | 0 | 0 | 111 |

**+8 net-new tests** (chapter_1_full_arc_test.gd). 29th consecutive failure-free baseline.

G-7 silent-skip detection grep: 0 matches in `tests/`.

All 4 Pillar 2 architectural lock lints + 2 Story Event lints PASS.

## Cross-references

- **Sprint plan**: `production/sprints/sprint-8.md` §S8-11
- **GDDs validated end-to-end**: `design/gdd/scenario-progression.md` (rev 2.2) + `design/gdd/destiny-branch.md` (rev 1.3.2) + `design/gdd/story-event.md` (rev 1.0) + `design/gdd/destiny-state.md` (rev 1.0)
- **ADRs validated end-to-end**: ADR-0001 GameBus + ADR-0003 SaveContext + ADR-0017 ScenarioRunner + ADR-0018 DestinyBranch + ADR-0019 AISystem
- **Test code**: `tests/integration/chapter_1_e2e/chapter_1_full_arc_test.gd`
- **Scenario data**: `assets/data/scenarios/mvp_shu.json`
- **Production-bug fix codified**: this commit's StoryEvent `_active_chapter` cache + ScenarioRunner `reset_for_tests` test seam
