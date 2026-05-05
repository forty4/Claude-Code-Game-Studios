# ScenarioRunner MVP Smoke Evidence — 2026-05-05 (Sprint 7 S7-02)

**Story**: production/epics/scenario-progression/story-001-scenario-runner-implementation-and-mock-encoder-deletion.md
**ADR**: ADR-0017 (Accepted 2026-05-04 via /architecture-review delta #12)
**Validation Criterion**: V-2 (JSON parse perf <50ms cold load) + V-3 (Resource.duplicate_deep semantics)
**Scope**: chapter-1 (장판파) stub fixture only — chapter-2..N coverage deferred to S7-05+

---

## Single-chapter MVP traversal

The mvp_shu.json scenario fixture ships a single chapter scaffold (`ch01_changbanpo`) sufficient for ScenarioRunner integration tests. Multi-chapter (chapter-2..N) authoring is sprint-7+ S7-05 should-have content scope.

### Scenario data (mvp_shu.json)

```json
{
  "scenario_id": "mvp_shu",
  "chapters": [
    {
      "chapter_id": "ch01_changbanpo",
      "chapter_number": 1,
      "map_id": "mvp_chapter_01",
      "author_draw_branch": false,
      "echo_threshold": 0,
      "branch_table": {
        "WIN_default":  "WIN_changbanpo_default",
        "LOSS_default": "LOSS_changbanpo_default"
      },
      "canonical_branch_key": "WIN_changbanpo_default",
      "player_unit_ids": [0, 1],
      "enemy_roster": [
        {"unit_id": 2, "hero_id": "wei_001_cao_cao",    "archetype": "coordinator"},
        {"unit_id": 3, "hero_id": "wei_005_xiahou_dun", "archetype": "aggressor"}
      ]
    }
  ]
}
```

### Traversal verification

`tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` (4 tests, all PASS):

1. **`test_chapter_1_full_traversal_fires_9_beats_in_order`** — drives runner from `load_scenario` through 9 beat states + lands at SCENARIO_END (since chapter-1 is the only chapter). Verifies forward-only invariant + canonical 9-beat rhythm.
2. **`test_chapter_index_advances_through_chapter_1`** — chapter_index transitions from 0 (the only chapter) to terminal SCENARIO_END.
3. **`test_scenario_complete_emitted_at_last_chapter`** — scenario_complete(ScenarioResult) fires once with chapter_outcomes.size() == 1 and scenario_path_key contains "WIN_changbanpo_default".
4. **`test_chapter_completed_emitted_per_chapter`** — chapter_completed(ChapterResult) fires once with extended fields (branch_path_id + echo_count_at_completion + back-compat branch_triggered).

---

## V-2: JSON parse performance

**Target**: <50ms cold load on Snapdragon 7-gen reference (per ADR-0017 §Performance Implications).

**Measured**: chapter-1 stub fixture (single chapter, ~1KB JSON) parses in <5ms on macOS Apple Silicon dev machine. Snapdragon 7-gen device measurement deferred to V-2 5-platform CI lane gap (per sprint-7 R-3 — Linux Editor + Windows D3D12 lanes only at sprint-7 close).

**Production caveat**: full 5-chapter MVP scenario (per ADR-0017 §Migration Plan §5 target) will be authored in S7-05+ chapter-1 narrative content sprint. Re-measurement at that point is recommended for V-2 closure.

---

## V-3: Resource.duplicate_deep semantics

ScenarioRunner uses `.duplicate(true)` on `chapter.branch_table` + `chapter.deployment_positions_default` + `chapter.beat_2_fragment` during JSON hydration to produce per-chapter independent copies. Per breaking-changes 4.4→4.5 (`Resource.duplicate_deep()` parameterless form), this preserves nested Dictionary contents without reference sharing.

**Verification**: chapter_definition_validation_test.gd (8 tests) round-trips ChapterDefinition through validation pipeline + the integration test traverses chapter-1 fixture cleanly without branch_table mutation between BEAT_4 → BEAT_7 (verified via `lint_scenario_runner_branch_table_immutable.sh`).

---

## Beat 7 reserved-color treatment binding (art-bible §4.7)

**F-DB-2 binding**: `DestinyBranchChoice.reserved_color_treatment = (branch_key != canonical_branch_key) AND outcome == WIN AND NOT is_draw_fallback`

For chapter-1 stub fixture (`canonical_branch_key = "WIN_changbanpo_default"`), the reserved-color treatment fires only on a WIN outcome that resolves to a non-canonical branch — which the stub `default_destiny_branch_judge.gd` does NOT produce (the stub always routes WIN to canonical). Full F-DB-1 algorithm (S7-03 destiny-branch story-001) will exercise the non-canonical WIN path; chapter-1's single canonical branch_table makes the reserved-color treatment a no-op for sprint-7 demo.

Beat 8 reveal art per art-bible §4.7 §1.지지 원칙 2 (운명의 색은 한번만 빛난다) is gated on this flag; chapter-1 demo sees only the canonical 결정적 single-step transition (no 주홍→금색 flash).

---

## Cross-references

- ADR-0017 §Performance Implications (V-2 + V-3 source)
- design/gdd/scenario-progression.md §F-SP-3 v2.2 + §EC-SP-8
- design/art-bible.md §4.7 reserved_color_treatment binding
- tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd (this evidence's primary test)
- assets/data/scenarios/mvp_shu.json (chapter-1 stub fixture)
- production/epics/scenario-progression/story-001 (this story)
