# Story 002: Validation pipeline FATAL severity (CR-1 + CR-2 + EC-1 + EC-2)

> **Epic**: Hero Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4h (4 validation severity branches × ~8 ACs × boundary-value test cases)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hero-database.md`
**Requirement**: `TR-hero-database-006`, `TR-hero-database-007`, `TR-hero-database-008`, `TR-hero-database-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 — Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope)
**ADR Decision Summary**: 3-tier severity validation pipeline runs at load time (pre-cache): (1) load-reject FATAL — full `_heroes` cleared (hero_id format `^[a-z]+_\d{3}_[a-z_]+$`, duplicate hero_id, parallel-array length mismatch); (2) per-record FATAL — offending record dropped, others continue (stat ranges [1,100] / seed ranges / move_range [2,6] / growth [0.5,2.0]); (3) WARNING tier (handled in story 004). `push_error` on FATAL lists hero_id + offending field name + offending value + expected range.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript regex via `RegEx.new() + compile() + search()` — pre-Godot-4.0 stable; `Dictionary.has(key)` for duplicate detection — pre-cutoff stable; `push_error` formatting via `%`-operator interpolation — pre-cutoff stable.

**Control Manifest Rules (Foundation layer)**:
- Required: validation runs pre-cache — a rejected record MUST NOT be inserted into `_heroes`
- Required: FATAL load-reject clears `_heroes` entirely (no partial state) and leaves `_heroes_loaded = false`
- Forbidden: silent rejection — every drop emits `push_error` with hero_id + field/value/range
- Forbidden: padding/truncation of skill parallel arrays (always authoring error per ADR-0007 §5)
- Guardrail: `_load_heroes()` validation overhead negligible vs ~5-15ms total cost for 10-hero MVP per ADR-0007 §Performance

---

## Acceptance Criteria

*From ADR-0007 §5 (Validation Pipeline) + GDD §Acceptance Criteria AC-01..AC-05 + AC-07 + AC-12 + AC-13, scoped to this story:*

- [ ] **AC-1** (TR-006 / GDD AC-01 — hero_id regex FATAL load-reject): a record with hero_id `WEI_001_zhang_liao` (uppercase faction) OR `wei_1_zhang_liao` (1-digit sequence) OR `wei_001_` (empty slug) → entire load rejected, `_heroes` cleared, `_heroes_loaded` stays false, `push_error` lists offending hero_id + cited regex `^[a-z]+_\d{3}_[a-z_]+$`. Boundary: `wei_007_zhang_liao` ACCEPTED.
- [ ] **AC-2** (TR-007 / GDD AC-02 — core stat range per-record FATAL): record with `stat_might=0` OR `stat_intellect=101` → record dropped, other records continue, `push_error` lists hero_id + field name + value + expected `[1,100]`. Boundary: 1 and 100 ACCEPTED.
- [ ] **AC-3** (TR-007 / GDD AC-03 — derived seed range per-record FATAL): record with `base_hp_seed=0` OR `base_initiative_seed=101` → record dropped, `push_error` cites field + value + range `[1,100]`. Boundary: 1 and 100 ACCEPTED.
- [ ] **AC-4** (TR-007 / GDD AC-04 — move_range boundary per-record FATAL): record with `move_range=1` OR `move_range=7` → record dropped, `push_error` cites field + value + range `[2,6]`. Boundary: 2 and 6 ACCEPTED.
- [ ] **AC-5** (TR-007 / GDD AC-05 — growth rate boundary per-record FATAL): record with `growth_might=0.4` OR `growth_agility=2.1` → record dropped, `push_error` cites field + value + range `[0.5, 2.0]`. Boundary: 0.5 and 2.0 ACCEPTED. Verify all 4 growth fields (might/intellect/command/agility) traverse the same validator path.
- [ ] **AC-6** (TR-009 / GDD AC-07 + AC-13 — skill parallel array integrity per-record FATAL): record with `innate_skill_ids.size() == 3` and `skill_unlock_levels.size() == 2` → record dropped, `push_error` cites hero_id + both array sizes + both field names. Boundary: both length 0 ACCEPTED (per EC-3).
- [ ] **AC-7** (TR-008 / GDD AC-12 — EC-1 duplicate hero_id load-reject FATAL): two records both with `hero_id == &"shu_001_liu_bei"` → entire load rejected (NOT just the second), `_heroes` cleared (no partial state), `_heroes_loaded` stays false, `push_error` lists the duplicated hero_id explicitly.
- [ ] **AC-8** (severity ordering): regex (AC-1) and duplicate (AC-7) checks BOTH gate full-load reject; range checks (AC-2..AC-5) and skill array (AC-6) gate per-record reject only. Verified by mixed-error fixture: 1 invalid hero_id + 1 valid record + 1 invalid stat → only AC-1 trips full reject; without an AC-1 violation, only the invalid stat record drops.
- [ ] **AC-9** (test isolation reset): `tests/unit/foundation/hero_database_validation_test.gd` `before_test()` resets BOTH `HeroDatabase._heroes_loaded = false` AND `HeroDatabase._heroes = {}` per G-15 obligation.
- [ ] **AC-10** (regression PASS): full GdUnit4 regression maintains story-001's baseline post-story; 0 errors / ≤1 carried failure / 0 orphans (G-7 verified)

---

## Implementation Notes

*Derived from ADR-0007 §5 (Validation Pipeline) + GDD §Edge Cases EC-1, EC-2, EC-3:*

1. **Validation pipeline shape** — extend story-001's `_load_heroes()` placeholder body with severity-tiered validation:
   ```gdscript
   static func _load_heroes() -> void:
       if _heroes_loaded:
           return
       var raw_text := FileAccess.get_file_as_string(_HEROES_JSON_PATH)
       if raw_text.is_empty():
           push_error("HeroDatabase: failed to read heroes.json at %s" % _HEROES_JSON_PATH)
           return
       var json := JSON.new()
       var parse_err := json.parse(raw_text)
       if parse_err != OK:
           push_error("HeroDatabase: JSON parse error at line %d col %d: %s" % [json.get_error_line(), json.get_error_message(), json.get_error_message()])
           return
       var raw_records: Dictionary = json.data
       # ─── Pass 1: FATAL load-reject (regex + duplicate) ──────────────────
       var seen_ids: Dictionary[StringName, bool] = {}
       for hero_id_str in raw_records:
           if not _validate_hero_id_format(hero_id_str):
               push_error("HeroDatabase: hero_id '%s' violates regex ^[a-z]+_\\d{3}_[a-z_]+$ — entire load rejected" % hero_id_str)
               _heroes.clear()
               return
           var hero_id_sn := StringName(hero_id_str)
           if seen_ids.has(hero_id_sn):
               push_error("HeroDatabase: duplicate hero_id '%s' — entire load rejected" % hero_id_sn)
               _heroes.clear()
               return
           seen_ids[hero_id_sn] = true
       # ─── Pass 2: per-record FATAL (range + skill array) ─────────────────
       for hero_id_str in raw_records:
           var record: Dictionary = raw_records[hero_id_str]
           var hero := _build_hero_data(StringName(hero_id_str), record)
           if hero == null:
               continue  # per-record drop already push_error'd by validators
           _heroes[StringName(hero_id_str)] = hero
       _heroes_loaded = true
   ```

2. **Per-record validators (private helpers)** — one per AC, each returns `bool` + emits `push_error` on failure. Recommended structure:
   ```gdscript
   static func _validate_hero_id_format(id: String) -> bool:
       var rx := RegEx.new()
       rx.compile("^[a-z]+_\\d{3}_[a-z_]+$")
       return rx.search(id) != null

   static func _validate_stat_range(hero_id: StringName, field: String, value: int, min_v: int, max_v: int) -> bool:
       if value < min_v or value > max_v:
           push_error("HeroDatabase: %s field '%s'=%d out of range [%d, %d]" % [hero_id, field, value, min_v, max_v])
           return false
       return true

   static func _validate_skill_arrays(hero_id: StringName, ids: Array, levels: Array) -> bool:
       if ids.size() != levels.size():
           push_error("HeroDatabase: %s skill array length mismatch — innate_skill_ids=%d, skill_unlock_levels=%d" % [hero_id, ids.size(), levels.size()])
           return false
       return true
   ```

3. **`_build_hero_data(hero_id, record)` builder** — instantiates `HeroData.new()` + field-by-field assignment from the JSON record + sequential per-record validator calls. Returns null on any per-record FATAL (validator already emitted push_error). Stat fields validated [1,100]; seeds [1,100]; move_range [2,6]; growth_might/intellect/command/agility [0.5, 2.0]; skill arrays length-equal.

4. **No constants in code** — validation thresholds (1, 100, 2, 6, 0.5, 2.0) are inline literal values for MVP, NOT BalanceConstants reads. ADR-0007 §11 + N2 explicitly defers F-1..F-4 BalanceConstants threshold reads to the Polish-tier `lint_hero_database_validation.sh` (story 005). The runtime pipeline does NOT consume BalanceConstants — story 005 documents this in the lint script header.

5. **Test fixtures** — synthesize via `JSON.stringify(Dictionary)` written to a temp file under `tests/fixtures/foundation/heroes/`, OR (preferred for unit tests) bypass file I/O by directly populating a `Dictionary` and feeding it to a test-only seam. Recommend a private static `_load_heroes_from_dict(records: Dictionary)` helper that the production `_load_heroes()` calls after `FileAccess.get_file_as_string + JSON.parse` — matches the 4-precedent test-seam pattern (ADR-0005/0010/0011/0012 `_advance_turn` / `_apply_turn_start_tick` / etc.). This enables unit tests to exercise the validation pipeline without touching the filesystem.

6. **`push_error` message format** — every FATAL emits a structured message including (a) module name `HeroDatabase:`, (b) hero_id (or `<unknown>` for full-load FATAL pre-validation), (c) offending field/value, (d) expected range or constraint. Tests assert message format via `assert_error_pushed(matching: "HeroDatabase: shu_001_liu_bei field 'stat_might'=0 out of range")` if GdUnit4 v6.1.2 supports `push_error` capture; otherwise tests assert state (record absent from `_heroes` post-load).

7. **G-15 isolation enforcement** — the new `hero_database_validation_test.gd` file MUST include `_heroes_loaded = false` + `_heroes = {}` reset in `before_test()`. Story 005's `lint_hero_database_no_signal_emission.sh` will be extended with a G-15 grep gate as part of that story.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: `assets/data/heroes/heroes.json` MVP roster authoring + happy-path integration
- **Story 004**: WARNING tier (EC-4 self-ref, EC-5 orphan FK, EC-6 asymmetric conflict) + R-1 consumer-mutation regression
- **Story 005**: Perf baseline + non-emitter lint + Polish-tier validation lint scaffold (F-1..F-4)

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1** (hero_id regex FATAL):
- Given: in-memory fixture Dictionary with one record keyed `WEI_001_zhang_liao` (uppercase faction)
- When: `_load_heroes_from_dict(fixture)` invoked
- Then: `_heroes` is empty, `_heroes_loaded == false`, `push_error` emitted citing the regex pattern + offending hero_id
- Edge case: 1-digit sequence (`wei_1_zhang_liao`) and empty slug (`wei_001_`) both reject; valid form (`wei_007_zhang_liao`) accepted

**AC-2..AC-5** (per-record FATAL range checks): use a parameterized test pattern — one fixture record per (field × boundary) tuple:
- stat_might = 0 → drop; stat_might = 1 → keep; stat_might = 100 → keep; stat_might = 101 → drop
- repeat for stat_intellect / stat_command / stat_agility / base_hp_seed / base_initiative_seed (range [1,100])
- move_range = 1 → drop; 2 → keep; 6 → keep; 7 → drop
- growth_might = 0.4 → drop; 0.5 → keep; 2.0 → keep; 2.1 → drop (× 4 growth fields)
- Edge case: floating-point boundary 0.4999... behavior — accept GDScript native float comparison; do not introduce epsilon

**AC-6** (skill parallel array integrity per-record FATAL):
- Given: fixture record with `innate_skill_ids` length 3 + `skill_unlock_levels` length 2
- When: `_load_heroes_from_dict(fixture)` invoked with this record + 1 valid record
- Then: only the invalid record dropped (other valid record loads normally), `push_error` cites hero_id + both sizes
- Edge case: both length 0 → ACCEPTED (no skills authored is a valid hero state per EC-3)

**AC-7** (EC-1 duplicate FATAL load-reject):
- Given: fixture Dictionary with two records both keyed `&"shu_001_liu_bei"` (which is impossible in a real Dictionary — use a list-of-pairs fixture form for this specific test)
- When: pipeline iterates and detects collision
- Then: `_heroes` empty + `_heroes_loaded == false` + push_error names the duplicated id
- Edge case: per-record FATAL violations BEFORE the duplicate check don't matter — duplicate check happens in pass 1; range checks in pass 2

**AC-8** (severity ordering):
- Given: 3-record fixture: 1 with invalid hero_id format (e.g. `WEI_001_x`), 1 valid, 1 with `stat_might=0`
- When: pipeline runs
- Then: full-load FATAL trips on the regex violation; `_heroes` empty + the stat violation is never reported (pass 2 skipped)
- Edge case: if regex is fixed in fixture, only the stat-violating record drops

**AC-9** (test isolation reset):
- Given: new test file `hero_database_validation_test.gd` post-creation
- When: grep for `before_test` body
- Then: contains BOTH `_heroes_loaded = false` AND `_heroes = {}` lines

**AC-10** (regression PASS):
- Given: full regression run post-implementation
- Then: 506 + (story-001 skeleton tests) + (this story's ~15 validation tests) pass; ≤1 carried failure; 0 orphans; exit ≤1

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/foundation/hero_database_validation_test.gd` — new file covering AC-1..AC-9 (~15 tests targeting boundary values + severity ordering)
- Existing `tests/unit/foundation/hero_database_test.gd` (story-001 skeleton suite) continues to pass with no edits

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`hero_database.gd` module exists; `_load_heroes()` placeholder body to be replaced; `_load_heroes_from_dict` test seam to be introduced)
- Unlocks: Story 003 (heroes.json MVP roster authoring requires the validation pipeline to gate FATAL violations on real records); Story 004 (WARNING tier validators extend the same `_load_heroes()` pipeline)
