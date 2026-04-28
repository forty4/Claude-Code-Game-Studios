# Story 003: F-1..F-5 stat derivation static methods + clamp discipline + G-15 test isolation

> **Epic**: unit-role
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (M)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-005`, `TR-unit-role-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§3 Public API + §Validation Criteria + §GDD Requirements Addressed AC-1..AC-5) + ADR-0006 — Balance/Data (BalanceConstants.get_const accessor)
**ADR Decision Summary**: 5 derived-stat static methods (`get_atk`, `get_phys_def`, `get_mag_def`, `get_max_hp`, `get_initiative`) implementing GDD F-1..F-4 with full clamp discipline + 1 method (`get_effective_move_range`) for F-5. Per-class coefficients from `_coefficients` cache (Story 002); global caps via `BalanceConstants.get_const(key)` per ADR-0006. G-15 test isolation obligation: every test suite calling these methods MUST reset `_cache_loaded = false` in `before_test()`.

**Engine**: Godot 4.6 | **Risk**: LOW (`clamp`, `clampi`, `floori`, `static func` all pre-cutoff stable; typed enum parameter binding stable since 4.0)
**Engine Notes**: Use `clampi(value, min, max)` for integer clamps (returns int directly, avoids `clamp(...) as int` cast). Use `floori(value)` for float-to-int floor (Godot 4.x idiomatic; avoids `int(floor(...))` two-call pattern). All formulas are deterministic — no random sampling, no time-dependent reads — thread-safe for read access in single-threaded game logic.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0006): All global caps (`ATK_CAP`, `DEF_CAP`, `HP_CAP`, `HP_SCALE`, `HP_FLOOR`, `INIT_CAP`, `INIT_SCALE`, `MOVE_RANGE_MIN`, `MOVE_RANGE_MAX`) read via `BalanceConstants.get_const(key)` — zero direct reads of `balance_entities.json`
- Required (direct, ADR-0009 §Validation Criteria §2): 100% test coverage on F-1..F-5 formulas per technical-preferences.md "balance formulas 100%"
- Required (direct, .claude/rules/godot-4x-gotchas.md G-15): Every test suite calling any UnitRole method that transitively reads BalanceConstants MUST reset `_cache_loaded = false` in `before_test()`. Static-lint enforcement: `grep -L "_cache_loaded = false" tests/unit/foundation/unit_role*.gd` returns empty
- Required (direct, ADR-0009 §3): Orthogonal per-stat methods (NOT bundled UnitStats Resource) — Damage Calc reads `get_atk` independently of `get_phys_def`; HP/Status reads `get_max_hp` independently
- Forbidden (direct, ADR-0009 §Validation Criteria §5): Hardcoded global cap values (200, 100, 300, 2.0, 50, etc.) in `src/foundation/unit_role.gd` matching cap names — static lint flags any literal that matches a cap value without going through `BalanceConstants.get_const`
- Forbidden (direct, ADR-0001 + ADR-0009 §1): Method bodies that introduce signal emissions, signal subscriptions, or instance state (already enforced by §1 module form invariants)
- Guardrail (direct, ADR-0009 §Performance): Each derived-stat method <0.05ms on minimum-spec mobile (60 calls per battle init = <3ms total, well inside 16.6ms one-time budget)

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-1..AC-5 + EC-1, EC-2, EC-13, EC-14:*

- [ ] **AC-1 (F-1 ATK)**: `static func get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int` returns `clampi(floori((primary × w_primary + secondary × w_secondary) × class_atk_mult), 1, ATK_CAP)`. Verified for all 6 classes with min stats (all=1), max stats (all=100), and median stats (all=50)
- [ ] **AC-2 (F-2 DEF split)**: `get_phys_def(hero, unit_class) -> int` and `get_mag_def(hero, unit_class) -> int` each return values in `[1, DEF_CAP]`. PHYSICAL attacks read `phys_def`; MAGICAL attacks read `mag_def` — Damage Calc owns the routing per CR-1a, NOT this story. Infantry at max stats has highest `phys_def`; Strategist at max stats has highest `mag_def`
- [ ] **AC-3 (F-3 HP)**: `get_max_hp(hero, unit_class) -> int` returns `clampi(floori(base_hp_seed × class_hp_mult × HP_SCALE) + HP_FLOOR, HP_FLOOR, HP_CAP)`. No unit has exactly 50 HP (per EC-14: minimum is `HP_FLOOR + 1 = 51`). Infantry seed=70 → ~232 HP; Strategist seed=40 → ~106 HP
- [ ] **AC-4 (F-4 Init)**: `get_initiative(hero, unit_class) -> int` returns `clampi(floori(base_initiative_seed × class_init_mult × INIT_SCALE), 1, INIT_CAP)`. Scout seed=80 → 192 (highest of any class with same seed)
- [ ] **AC-5 (F-5 Move Range)**: `get_effective_move_range(hero, unit_class) -> int` returns `clampi(hero.move_range + class_move_delta, MOVE_RANGE_MIN, MOVE_RANGE_MAX)`. Strategist hero_move_range=2 → 2 (NOT 1, per EC-1); Cavalry hero_move_range=6 → 6 (NOT 7, per EC-2)
- [ ] All 5 methods route global cap reads through `BalanceConstants.get_const(key)` — zero direct file reads
- [ ] All 5 methods are **stateless** — no instance state, no `static var` mutation beyond the lazy-init flag set in Story 002
- [ ] G-15 test isolation: every test in `tests/unit/foundation/unit_role_*.gd` (this story's test file + Story 002's + future) resets `BalanceConstants._cache_loaded = false` AND `UnitRole._coefficients_loaded = false` in `before_test()`
- [ ] **EC-1 (Strategist Move Range Floor)**: `get_effective_move_range(hero{move_range=2}, STRATEGIST)` returns 2 (the `-1` class delta is absorbed by `MOVE_RANGE_MIN` clamp)
- [ ] **EC-2 (Cavalry Move Range Cap Absorption)**: `get_effective_move_range(hero{move_range=6}, CAVALRY)` returns 6 (the `+1` class delta is wasted at `MOVE_RANGE_MAX` clamp); identical to `move_range=5` cavalry
- [ ] **EC-13 (phys_def reaching DEF_CAP)**: `get_phys_def(hero{stat_might=100, stat_command=100}, INFANTRY)` returns 100 (clamp at `DEF_CAP`); independent clamp from `mag_def`
- [ ] **EC-14 (HP Floor minimum 51)**: `get_max_hp(hero{base_hp_seed=1}, STRATEGIST)` returns 51 (minimum possible `max_hp` is `HP_FLOOR + 1 = 51`, NOT exactly 50)

---

## Implementation Notes

*From ADR-0009 §3, §4, §Validation Criteria + GDD §Formulas + ADR-0006:*

1. Method shape per F-1 (similar pattern for F-2, F-3, F-4):
   ```gdscript
   static func get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
       _load_coefficients()  # idempotent; populates cache on first call
       var class_key := _class_to_key(unit_class)  # int → "cavalry" / "infantry" / etc.
       var entry: Dictionary = _coefficients[class_key]
       var primary_value := _read_hero_stat(hero, entry["primary_stat"])
       var secondary_value := _read_hero_stat(hero, entry["secondary_stat"]) if entry["secondary_stat"] != null else 0
       var raw := floori((primary_value * entry["w_primary"] + secondary_value * entry["w_secondary"]) * entry["class_atk_mult"])
       var atk_cap: int = BalanceConstants.get_const("ATK_CAP")
       return clampi(raw, 1, atk_cap)
   ```
2. `_class_to_key(unit_class: UnitRole.UnitClass) -> String` is a private helper mapping enum int to lowercase JSON key (e.g., `CAVALRY → "cavalry"`). Implementation can be a `match` statement or a `const` Dictionary lookup. Same pattern reused across all 5 methods.
3. `_read_hero_stat(hero: HeroData, stat_name: String) -> int` is a private helper using `hero.get(stat_name)` reflection OR a typed match statement. The String-keyed approach avoids hardcoding the 4 stat names in 5 methods.
4. F-2 DEF split: 2 separate methods (`get_phys_def`, `get_mag_def`) each implementing their own base derivation per GDD F-2 (not a shared helper — orthogonal per ADR-0009 §3 + §Alternatives Considered Alt 4 rejection rationale).
5. F-3 HP: clamp range is `[HP_FLOOR, HP_CAP]` not `[HP_FLOOR + 1, HP_CAP]` — the `+ HP_FLOOR` additive INSIDE the expression makes the *practical* minimum 51 (per EC-14), but the clamp upper bound is HP_CAP and lower bound is HP_FLOOR so a pathological negative `floori(...)` result still floors to 50. Test the EC-14 case explicitly with seed=1 to confirm 51, NOT 50.
6. F-4 Initiative + F-5 Move Range follow the same shape as F-1 with their own coefficient fields.
7. **Do not** introduce any AI/Damage Calc/HP-Status routing logic in this story — those consumers call these methods externally per ADR-0012 / future ADR-0010 / future ADR-0011.
8. **Do not** call BalanceConstants.get_const in the cached path — read once per method call (the cap values won't change within a battle session per ADR-0006 §6 cache semantics; the per-call cost is acceptable for one-time-per-unit-per-battle methods per ADR-0009 §Performance).
9. G-15 obligation MUST be honored in `tests/unit/foundation/unit_role_stat_derivation_test.gd::before_test()`:
   ```gdscript
   func before_test() -> void:
       BalanceConstants._cache_loaded = false  # G-15 mandatory; per ADR-0006 §6
       UnitRole._coefficients_loaded = false   # mirrors G-15 for UnitRole's cache
   ```

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: `get_class_cost_table` (NOT a stat-derivation method; cost matrix is a separate concern per ADR-0009 §5)
- Story 005: `get_class_direction_mult` (NOT a stat-derivation method)
- Story 006: `PASSIVE_TAG_BY_CLASS` const declaration
- Story 010: perf baseline test for the 5 methods (this story focuses on correctness)
- Damage Calc PHYSICAL/MAGICAL attack-type routing (CR-1a — owned by Damage Calc per ADR-0012 + future Battle Preparation epic)
- HP/Status `max_hp` consumption (owned by future ADR-0010)
- Turn Order `initiative` consumption (owned by future ADR-0011)
- Grid Battle `move_budget` computation (`effective_move_range × MOVE_BUDGET_PER_RANGE` is consumer-side per ADR-0009 §3 + Story 007 obligation; NOT a method on UnitRole)

---

## QA Test Cases

*Logic story — automated unit test specs. 100% coverage required on F-1..F-5 per technical-preferences.*

- **AC-1 (F-1 ATK — 6 classes × 3 fixtures = 18 cases minimum)**:
  - Given: `_coefficients_loaded` reset in `before_test`; HeroData fixtures for min/max/median stats
  - When: `UnitRole.get_atk(hero, CAVALRY)` etc. for each of 6 classes × 3 stat profiles
  - Then: per ADR-0009 example, Cavalry stat_might=75 → `floori(82.5) = 82`; results in `[1, 200]`; each class produces the expected per-formula value
  - Edge cases: stat_might=1 floor → result ≥ 1 (lower clamp); stat_might=100 max → result ≤ 200 (upper clamp); secondary_stat=null on single-stat classes does not crash (returns 0 contribution)

- **AC-2 (F-2 DEF split)**:
  - Given: HeroData fixtures with stat_might + stat_command + stat_intellect spread
  - When: `get_phys_def(hero, INFANTRY)` and `get_mag_def(hero, INFANTRY)` are called
  - Then: per GDD example, Infantry stat_might=60 + stat_command=50 + stat_intellect=30 → `phys_def=68`, `mag_def=28`; both in `[1, 100]`; clamps independent
  - Edge cases: AC-2 EC-13 boundary — both stats at 100 → phys_def_base=100 → clamp to 100 (DEF_CAP); Strategist with same stats produces `phys_def < mag_def` (mag-tank identity preserved)

- **AC-3 (F-3 HP — EC-14 boundary)**:
  - Given: HeroData fixtures with `base_hp_seed` ∈ {1, 40, 70, 100}
  - When: `get_max_hp(hero, class)` for each combination
  - Then: per GDD examples, Infantry seed=70 → 232; Strategist seed=40 → 106; **EC-14: Strategist seed=1 → 51 (NOT 50)**; all values in `[51, 300]`
  - Edge cases: seed=0 (out-of-range per HeroData) → result still ≥ 51 due to `HP_FLOOR + 1` floor; seed=100 + Infantry → potentially clamped to 300 (HP_CAP); test that the additive `+ HP_FLOOR` is INSIDE the expression, not outside the clamp

- **AC-4 (F-4 Initiative)**:
  - Given: HeroData fixtures with `base_initiative_seed` spread
  - When: `get_initiative(hero, class)` per class
  - Then: per GDD example, Scout seed=80 → 192; Scout seed=80 produces a higher initiative than any other class with same seed; all values in `[1, 200]`
  - Edge cases: seed=1 → result ≥ 1 (lower clamp); seed=100 + Scout → clamp to 200 (INIT_CAP); class_init_mult typo in JSON → fallback to default per Story 002

- **AC-5 (F-5 Move Range — EC-1 + EC-2 boundaries)**:
  - Given: HeroData fixtures with `move_range` ∈ {2, 3, 4, 5, 6}
  - When: `get_effective_move_range(hero, class)` per class × move_range combination
  - Then: per GDD examples, Cavalry hero_move_range=4 → 5; Strategist hero_move_range=3 → 2; **EC-1: Strategist hero_move_range=2 → 2 (clamp absorbs -1 delta); EC-2: Cavalry hero_move_range=6 → 6 (clamp absorbs +1 delta)**
  - Edge cases: move_range=2 + class_move_delta=-1 (Strategist) → result=2 (clamp); move_range=6 + class_move_delta=+1 (Cavalry/Scout) → result=6 (clamp); INFANTRY/ARCHER/COMMANDER (delta=0) → result=move_range unchanged

- **AC-6 (G-15 test isolation invariant)**:
  - Given: this test file is `tests/unit/foundation/unit_role_stat_derivation_test.gd`
  - When: a CI lint step runs `grep -L "_cache_loaded = false" tests/unit/foundation/unit_role*.gd`
  - Then: empty output (every test file has the reset)
  - Edge cases: this is a meta-test enforced by CI, not a unit test in this file; the fixture file IS where the obligation is honored — verify by inspection of `before_test()`

- **AC-7 (No hardcoded cap values)**:
  - Given: `src/foundation/unit_role.gd` is written
  - When: a CI lint step runs `grep -E '\b(200|100|300|2\.0|50|6|2)\b' src/foundation/unit_role.gd | grep -v "BalanceConstants.get_const"`
  - Then: zero matches except for known-safe contexts (e.g., array indices `[0]` to `[5]`, enum int values, comments)
  - Edge cases: false-positive list maintained in `tools/ci/`; allow inline `# G-15` style comments containing numbers

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/unit_role_stat_derivation_test.gd` — must exist and pass (7 ACs above; ~250-350 LoC test file with HeroData fixture builders + 18+ per-formula cases + EC-1/EC-2/EC-13/EC-14 boundary tests + G-15 reset in `before_test`)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (needs `_coefficients` cache populated by `_load_coefficients`)
- Unlocks: Story 010 (perf baseline test depends on these methods existing); Damage Calc consumer (out of scope; Story 009 verifies the cross-system contract)
