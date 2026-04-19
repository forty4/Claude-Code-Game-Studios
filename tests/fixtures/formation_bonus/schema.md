# Formation Bonus Test Fixture Schema

**File:** `tests/fixtures/formation_bonus/schema.md`
**Owner:** qa-lead
**Last Updated:** 2026-04-20
**Source of Truth:** `design/gdd/formation-bonus.md` §8 Acceptance Criteria (v1.0 AC-FB-01 through AC-FB-16; v1.1 additions AC-FB-17 through AC-FB-25)
**Review Log:** `design/gdd/reviews/formation-bonus-review-log.md` — fixture schema gap flagged as HIGH sprint risk in pass-1 verdict

---

## Purpose

This document specifies the YAML schema for all formation bonus test fixtures, enumerates every fixture file required by the v1.1 AC set (AC-FB-01 through AC-FB-25), and defines the GdUnit4 loader contract that test authors must follow. No test that references a `tests/fixtures/formation_bonus/*.yaml` path may be merged until the referenced file exists and validates against this schema.

---

## 1. YAML Schema Reference

### Top-Level Fields

| Field | Type | Required | Constraints | Description |
|---|---|---|---|---|
| `fixture_id` | StringName | Yes | Must match the file's stem (e.g., `"wedge_3unit"` for `wedge_3unit.yaml`) | Unique fixture identifier; validated by loader |
| `test_description` | String | Yes | Non-empty | Human-readable summary of what scenario the fixture sets up |
| `pattern_under_test` | StringName | No | Must be one of: `"wedge"`, `"crane_wing"`, `"diamond"`, `"square"`, or omitted | Pattern ID under test; omit for pure-relationship fixtures |
| `relationship_under_test` | StringName | No | Must be one of: `"SWORN_BROTHER"`, `"LORD_VASSAL"`, `"RIVAL"`, `"MENTOR_STUDENT"`, or omitted | Relationship type under test; omit for pure-pattern fixtures |
| `round_number` | int | No | Default: `1`; range 1–999 | Round number passed to `compute_and_publish_snapshot`; required for snapshot-persistence fixtures (AC-FB-12, AC-FB-18) |
| `units` | Array[UnitFixture] | Yes | Minimum 1 element | All units on the grid at snapshot time |
| `relationships` | Array[RelationshipFixture] | No | Omit or empty array if no relationships | Hero relationship records; mirrors Hero Database Relationships Block schema |
| `expected_anchors` | Dictionary | No | Keys: unit_id (int); Values: Array[StringName] of pattern ids | Pattern anchor results expected from `detect_patterns` |
| `expected_members` | Dictionary | No | Keys: unit_id (int); Values: Array[StringName] of pattern ids | Pattern member results expected from `detect_patterns` |
| `expected_bonuses` | Dictionary | Yes | Keys: unit_id (int); Values: `{atk_bonus: float, def_bonus: float}` | Per-unit final capped bonus expected from `aggregate_formation_bonuses` |
| `expected_log_substrings` | Array[String] | No | Omit unless fixture tests log output (EC-FB-7 path) | Strings that must appear as substrings in the WARNING log output |

### UnitFixture (nested under `units`)

| Field | Type | Required | Constraints | Description |
|---|---|---|---|---|
| `unit_id` | int | Yes | Unique within fixture | Runtime unit identifier; used as key in expected_anchors / expected_bonuses |
| `hero_id` | StringName | Yes | Must match a hero_id in the `relationships` list if relationships are asserted | Hero database identifier (e.g., `"shu_002_guan_yu"`) |
| `faction` | StringName | Yes | One of: `"PLAYER"`, `"ENEMY"`, `"NEUTRAL"` | Faction used for same-faction pattern and relationship checks |
| `coord` | Mapping | Yes | `{c: int, r: int}` — c = column (x), r = row (y); both non-negative | Grid position at snapshot time; maps to `Vector2i(c, r)` in GDScript |
| `is_alive` | bool | No | Default: `true` | Set to `false` for dead-unit edge-case fixtures (EC-FB-1) |
| `role` | StringName | No | One of: `"anchor"`, `"member"`, `"observer"` | Informational label only; does not affect detection logic; aids fixture readability |

**Coordinate convention:** `c` increases rightward (col), `r` increases downward (row). Origin `(c:0, r:0)` is top-left. This mirrors `map-grid.md` CR-1 (`Vector2i(col, row)`) exactly. The YAML map form `{c: int, r: int}` is used instead of an inline sequence to prevent `[col, row]` vs `[row, col]` ambiguity.

### RelationshipFixture (nested under `relationships`)

Mirrors the Hero Database Relationships Block (`design/gdd/hero-database.md` CR-2):

| Field | Type | Required | Constraints | Description |
|---|---|---|---|---|
| `hero_a_id` | StringName | Yes | Must match a `hero_id` in `units` | The hero holding this relationship record |
| `hero_b_id` | StringName | Yes | Must match a `hero_id` in `units` (or be a known absent hero for EC-FB-11) | The relationship target hero |
| `relation_type` | StringName | Yes | One of: `"SWORN_BROTHER"`, `"LORD_VASSAL"`, `"RIVAL"`, `"MENTOR_STUDENT"` | Relationship type enum |
| `effect_tag` | StringName | Yes | One of: `"sworn_atk_boost"`, `"lord_vassal_def_boost_vassal"`, `"rival_atk_boost"`, `"mentor_student_atk_boost_student"` | Key into the rel_effect_table |
| `is_symmetric` | bool | Yes | `true` for SWORN_BROTHER and RIVAL; `false` for LORD_VASSAL and MENTOR_STUDENT | Controls whether both units receive the bonus |

---

## 2. Fixture Inventory

All fixtures in this table must exist on disk before the implementing sprint closes. Fixtures marked **[v1.1-new]** correspond to ACs added in v1.1 for the six previously-unattested edge cases and the cross-doc consumer paths.

| AC | Fixture Filename | Story Type | Purpose |
|---|---|---|---|
| AC-FB-01 | `wedge_3unit.yaml` | Logic | 어진형 (wedge) pattern detection: anchor at (2,2), members at (1,3) and (3,3) |
| AC-FB-02 | `crane_wing_3unit.yaml` | Logic | 학익진 (crane wing) detection: anchor at (2,2), wingmen at (1,2) and (3,2); anchor-only bonus |
| AC-FB-03 | `diamond_4unit.yaml` | Logic | 마름진 (diamond) detection: all four cardinal members receive atk+def bonus |
| AC-FB-04 | `square_4unit.yaml` | Logic | 방진 (square) detection: 2x2 block; all four receive def_bonus=0.04 (rev 2.9.1 value) |
| AC-FB-05 | `sworn_brother_pair.yaml` | Logic | SWORN_BROTHER symmetric pair at Manhattan distance 1; both receive atk_bonus=0.02 |
| AC-FB-06 | `lord_vassal_pair.yaml` | Logic | LORD_VASSAL asymmetric; only vassal (record-holder) receives def_bonus=0.04 (v1.1 value) |
| AC-FB-07 | `rival_cross_faction_pair.yaml` | Logic | RIVAL cross-faction pair; both receive atk_bonus=0.02 regardless of faction (CR-FB-4) |
| AC-FB-08 | `mentor_student_pair.yaml` | Logic | MENTOR_STUDENT asymmetric; only student (record-holder) receives atk_bonus=0.02 |
| AC-FB-12 | `snapshot_persistence.yaml` | Logic | Unit in crane_wing at round_started; verify snapshot value unchanged after simulated mid-round move |
| AC-FB-17 | `dual_pattern_stack.yaml` | Logic | **[v1.1-new]** EC-FB-3: unit simultaneously anchor of wedge AND member of square; raw_atk=0.03, raw_def=0.04 |
| AC-FB-18 | `mid_round_completion.yaml` | Logic | **[v1.1-new]** EC-FB-5: pattern incomplete at round_started; verify no bonus granted; second snapshot confirms bonus after round_started fires again with complete formation |
| AC-FB-19 | `conflicting_records.yaml` | Logic | **[v1.1-new]** EC-FB-6: hero_a holds SWORN_BROTHER (is_symmetric=true) to hero_b; hero_b holds RIVAL (is_symmetric=true) to hero_a; both records processed independently; bonuses sum subject to cap |
| AC-FB-20 | `zero_bonus_unit.yaml` | Logic | **[v1.1-new]** EC-FB-10: unit with no pattern participation and no adjacent relationship; expected_bonuses entry is {atk_bonus: 0.0, def_bonus: 0.0} — entry still present in snapshot dict |
| AC-FB-21 | `empty_relationships.yaml` | Logic | **[v1.1-new]** EC-FB-11: hero with no relationship records; get_relationships returns empty array; no error; relationship contribution = 0.0 |
| AC-FB-22 | `same_faction_rival.yaml` | Logic | **[v1.1-new]** EC-FB-12: RIVAL between two PLAYER-faction units; bonus fires normally (CR-FB-4: faction check does not block same-faction RIVAL) |

**Fixtures NOT requiring a YAML file** (inline parameters sufficient per the AC spec):

- AC-FB-09 — boundary value test on aggregation cap constant (inline constants)
- AC-FB-10 — inline ResolveModifiers.make() call (exact integers are the assertion)
- AC-FB-11 — inline boundary value (Cavalry apex arithmetic)
- AC-FB-13 — inline state mutation (dead-unit snapshot retention)
- AC-FB-14 — mock FileAccess injection (expected_log_substrings: `["EC-FB-7: formations.json"]`)
- AC-FB-15 — inline coord setup (distance-2 negative boundary)
- AC-FB-16 — inline coord setup (partial square — no YAML fixture needed)
- AC-FB-23 — inline ResolveModifiers.make() (sub-apex P_mult arithmetic)
- AC-FB-24 — inline ResolveModifiers.make() (formation_def consumer F-DC-3 path)
- AC-FB-25 — inline coord setup (distance-1 positive boundary)

---

## 3. Full YAML Body Examples

### Example 1: `wedge_3unit.yaml` (simplest pattern fixture)

```yaml
# Formation Bonus fixture — 어진형 (wedge) pattern detection
# Used by: AC-FB-01
# Pattern: wedge (어진형), 3 units
# Anchor at (2,2) facing north; flankers at (1,3) and (3,3)

fixture_id: "wedge_3unit"
test_description: >
  Three same-faction alive units arranged in a V-shape (어진형 template).
  Unit 1 is the anchor at tip (2,2); units 2 and 3 are flankers diagonally
  back-left (1,3) and back-right (3,3). Expects unit 1 as anchor with
  pattern_atk=0.03; units 2 and 3 as members with pattern_atk=0.01 each.

pattern_under_test: "wedge"
round_number: 1

units:
  - unit_id: 1
    hero_id: "shu_002_guan_yu"
    faction: "PLAYER"
    coord: {c: 2, r: 2}
    is_alive: true
    role: "anchor"
  - unit_id: 2
    hero_id: "shu_003_zhang_fei"
    faction: "PLAYER"
    coord: {c: 1, r: 3}
    is_alive: true
    role: "member"
  - unit_id: 3
    hero_id: "shu_004_zhao_yun"
    faction: "PLAYER"
    coord: {c: 3, r: 3}
    is_alive: true
    role: "member"

relationships: []

expected_anchors:
  1: ["wedge"]

expected_members:
  2: ["wedge"]
  3: ["wedge"]

expected_bonuses:
  1: {atk_bonus: 0.03, def_bonus: 0.0}
  2: {atk_bonus: 0.01, def_bonus: 0.0}
  3: {atk_bonus: 0.01, def_bonus: 0.0}
```

### Example 2: `sworn_brother_pair.yaml` (relationship fixture)

```yaml
# Formation Bonus fixture — SWORN_BROTHER relationship adjacency
# Used by: AC-FB-05
# Relationship: SWORN_BROTHER (is_symmetric=true), Manhattan distance=1 (orthogonal)
# Both heroes receive atk_bonus=0.02 per CR-FB-11

fixture_id: "sworn_brother_pair"
test_description: >
  Two same-faction alive heroes with a SWORN_BROTHER relationship occupy
  orthogonally adjacent tiles (Manhattan distance=1). Both are expected to
  receive atk_bonus=0.02 from the symmetric relationship. No pattern
  formation is present.

relationship_under_test: "SWORN_BROTHER"
round_number: 1

units:
  - unit_id: 1
    hero_id: "shu_001_liu_bei"
    faction: "PLAYER"
    coord: {c: 3, r: 3}
    is_alive: true
  - unit_id: 2
    hero_id: "shu_002_guan_yu"
    faction: "PLAYER"
    coord: {c: 3, r: 4}
    is_alive: true

relationships:
  - hero_a_id: "shu_001_liu_bei"
    hero_b_id: "shu_002_guan_yu"
    relation_type: "SWORN_BROTHER"
    effect_tag: "sworn_atk_boost"
    is_symmetric: true

expected_anchors: {}
expected_members: {}

expected_bonuses:
  1: {atk_bonus: 0.02, def_bonus: 0.0}
  2: {atk_bonus: 0.02, def_bonus: 0.0}
```

---

## 4. Test Loader Contract

All tests that consume formation bonus fixtures must use the following GdUnit4 helper. The helper must be implemented in `tests/unit/formation_bonus/formation_bonus_fixture_loader.gd` before the first fixture-dependent test is written.

### Signature

```gdscript
## Loads a formation bonus YAML fixture by ID.
## Returns the parsed fixture as a Dictionary on success.
## Calls assert_fail() (FATAL) if the file does not exist or fixture_id
## does not match the file stem — test execution halts immediately.
static func load_formation_fixture(fixture_id: StringName) -> Dictionary
```

### Path Resolution

```
tests/fixtures/formation_bonus/{fixture_id}.yaml
```

The `fixture_id` argument must exactly match the filename stem. The loader must validate this at load time: if `fixture["fixture_id"] != fixture_id`, call `assert_fail()` with a message identifying both the argument and the stored value.

### Return Shape

On success, returns a Dictionary with keys matching the top-level schema fields. All optional fields that were absent in the YAML file are populated with their defaults before the Dictionary is returned:

| Key | Default when absent |
|---|---|
| `pattern_under_test` | `""` (empty StringName) |
| `relationship_under_test` | `""` |
| `round_number` | `1` |
| `relationships` | `[]` |
| `expected_anchors` | `{}` |
| `expected_members` | `{}` |
| `expected_log_substrings` | `[]` |

The `units` array is returned as-is; each entry is a Dictionary. `coord` values are converted from `{c, r}` maps to `Vector2i(c, r)` by the loader so tests receive native Godot types.

### Error Behavior

| Condition | Behavior |
|---|---|
| File does not exist | `assert_fail("Fixture not found: tests/fixtures/formation_bonus/{fixture_id}.yaml")` — FATAL, test halts |
| File exists but `fixture_id` key mismatch | `assert_fail("fixture_id mismatch: expected '{fixture_id}', got '{stored}'")` — FATAL |
| YAML parse error | `assert_fail("YAML parse error in fixture '{fixture_id}': {error}")` — FATAL |
| Missing required field (`units`, `expected_bonuses`, `test_description`) | `assert_fail("Required field '{field}' missing in fixture '{fixture_id}'")` — FATAL |

The loader must never silently return a partial dictionary. Any structural fault is a test authoring error and must halt execution immediately so it cannot produce a false-passing test.

### Usage Pattern in GdUnit4

```gdscript
func test_wedge_pattern_detection_anchor_bonus() -> void:
    # Arrange
    var fixture := FormationBonusFixtureLoader.load_formation_fixture(&"wedge_3unit")
    var units := fixture["units"]
    var expected_bonuses: Dictionary = fixture["expected_bonuses"]

    # Act
    var result := FormationBonusSystem.compute_and_publish_snapshot(units, fixture["round_number"])

    # Assert
    for unit_id in expected_bonuses:
        var exp: Dictionary = expected_bonuses[unit_id]
        assert_float(result[unit_id]["atk_bonus"]).is_equal_approx(exp["atk_bonus"], 0.001)
        assert_float(result[unit_id]["def_bonus"]).is_equal_approx(exp["def_bonus"], 0.001)
```

---

## 5. Cross-References

| Document | Relevant Section | What it governs |
|---|---|---|
| `design/gdd/formation-bonus.md` §8 | AC-FB-01 through AC-FB-16 (v1.0); AC-FB-17 through AC-FB-25 (v1.1 additions) | Authoritative AC set this fixture inventory maps to |
| `design/gdd/formation-bonus.md` §5 | EC-FB-1 through EC-FB-12 | Edge cases; v1.1 fixtures cover the six previously-unattested ECs |
| `design/gdd/hero-database.md` CR-2 Relationships Block | — | `relation_type`, `effect_tag`, `is_symmetric` field definitions mirrored in RelationshipFixture |
| `design/gdd/map-grid.md` CR-1 | Coordinate convention | `(col, row)` origin top-left, col rightward, row downward — `{c, r}` YAML form maps to `Vector2i(col, row)` |
| `design/gdd/map-grid.md` F-1 | Manhattan Distance | Adjacency threshold (distance ≤ 1, orthogonal only) for relationship fixtures |
| `design/gdd/reviews/formation-bonus-review-log.md` | qa-lead section | Full BLOCKER list that motivated this document; fixture schema gap was rated HIGH sprint risk |

---

## QA Gate Note

Per the project Test Standards, no Logic-type story referencing a fixture file in `tests/fixtures/formation_bonus/` is considered Done until:

1. The corresponding `*.yaml` file exists and validates against this schema.
2. The `load_formation_fixture` helper is implemented and its own unit test passes.
3. The consuming test passes in CI (`godot --headless --script tests/gdunit4_runner.gd`).

This is a BLOCKING gate. Fixture files are test evidence, not optional documentation.
