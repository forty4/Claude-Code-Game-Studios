# Story 007: Unit-role global caps balance_entities.json append (8 keys) + cross-doc obligation closure

> **Epic**: unit-role
> **Status**: Complete (2026-04-28) ✅ — 9/9 tests passing (`tests/unit/foundation/balance_constants_unit_role_caps_test.gd`)
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20
> **Estimate**: 1 hour (XS) — actual ~30min orchestrator (re-scoped from "MOVE_BUDGET_PER_RANGE only" to "8 unit-role-related caps" after story-003 readiness probe surfaced 7 missing keys; original ADR-0009 §4 wording assumed all 10 caps were already in balance_entities.json — they weren't)
> **Implementation commit**: TBD (this commit)

## Re-scope note (2026-04-28)

Original story-007 scope was narrow: append `MOVE_BUDGET_PER_RANGE = 10` to `balance_entities.json` per ADR-0009 §Migration Plan §4 (the only key explicitly called out in the §Migration Plan).

During /story-readiness story-003 (F-1..F-5 stat derivation), context probe surfaced that **7 additional unit-role-related caps were missing from balance_entities.json** despite ADR-0009 §4 line 221 declaring them as canonical: HP_CAP, HP_SCALE, HP_FLOOR, INIT_CAP, INIT_SCALE, MOVE_RANGE_MIN, MOVE_RANGE_MAX. Without these, story-003's `BalanceConstants.get_const("HP_CAP")` etc. would return null + push_error → silent test failures.

Story-007 was re-scoped to cover all 8 unit-role-related caps and execute BEFORE story-003 (rather than the original "anytime after story-001"). The Implementation Order in EPIC.md was updated to reflect the revised dependency.

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-005` (cross-doc obligation portion)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§4 + §Migration Plan §4) + ADR-0006 — Balance/Data (BalanceConstants accessor + balance_entities.json schema)
**ADR Decision Summary**: 8 unit-role-related global caps appended to `assets/data/balance/balance_entities.json` per ADR-0009 §4 line 221 declaration: HP_CAP=300, HP_SCALE=2.0, HP_FLOOR=50, INIT_CAP=200, INIT_SCALE=2.0, MOVE_RANGE_MIN=2, MOVE_RANGE_MAX=6, MOVE_BUDGET_PER_RANGE=10. Values per GDD §Global Constant Summary + ADR-0009 §4. Consumers: stories 003 (F-1..F-5 formulas read all 8 except MOVE_BUDGET_PER_RANGE), 005 (no balance reads — direction multiplier comes from unit_roles.json per ADR-0009 §6 design-vs-runtime asymmetry), and future Grid Battle (consumes MOVE_BUDGET_PER_RANGE for `move_budget = effective_move_range × MOVE_BUDGET_PER_RANGE` consumer-side compute). All read via `BalanceConstants.get_const(key) -> Variant` per ADR-0006.

**Engine**: Godot 4.6 | **Risk**: LOW (single-line JSON append; BalanceConstants accessor stable since ADR-0006 acceptance 2026-04-26)
**Engine Notes**: JSON append is simple text edit; no parse-side concerns. BalanceConstants `_cache_loaded` reset obligation per G-15 applies to any test reading the new constant.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0006): All global constants live in `assets/data/balance/balance_entities.json` per ADR-0006 ratified pipeline; consumers read via `BalanceConstants.get_const(key) -> Variant`
- Required (direct, ADR-0009 §Migration Plan §4): single-line append `"MOVE_BUDGET_PER_RANGE": 10`; lint-script reference unchanged
- Required (direct, .claude/rules/godot-4x-gotchas.md G-15): test suites reading `MOVE_BUDGET_PER_RANGE` via BalanceConstants must reset `_cache_loaded = false` in `before_test()`
- Required (direct, ADR-0009 §3 + §Requirements): `move_budget = effective_move_range × MOVE_BUDGET_PER_RANGE` is a **consumer-side** compute (Grid Battle), NOT a UnitRole method. UnitRole exposes `get_effective_move_range`; consumer multiplies by `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")`
- Forbidden (direct, ADR-0006): hardcoding `MOVE_BUDGET_PER_RANGE = 10` literal anywhere in `src/` — must come through BalanceConstants accessor
- Forbidden (direct, ADR-0009): adding a UnitRole method like `get_move_budget()` — out of scope per the consumer-side compute decision

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-20 + ADR-0009 §Migration Plan §4 cross-doc obligation:*

- [x] **AC-1 (8 caps appended)**: 8 keys added to `assets/data/balance/balance_entities.json`: HP_CAP=300, HP_SCALE=2.0, HP_FLOOR=50, INIT_CAP=200, INIT_SCALE=2.0, MOVE_RANGE_MIN=2, MOVE_RANGE_MAX=6, MOVE_BUDGET_PER_RANGE=10. NOT hardcoded anywhere in `src/`
- [x] **AC-1 (per-cap accessor verified)**: each of the 8 keys returns expected value via `BalanceConstants.get_const(key)` (8 test functions in `tests/unit/foundation/balance_constants_unit_role_caps_test.gd`)
- [x] **AC-2 (no regression on pre-existing caps)**: 4 spot-checked pre-existing scalar caps (ATK_CAP=200, DEF_CAP=105, BASE_CEILING=83, DAMAGE_CEILING=180) still return expected values after the 8-key append. Existing `tests/unit/balance/balance_constants_test.gd` continues to pass (12 pre-existing keys covered there in detail; not duplicated here)
- [x] **AC-3 (data-driven per coding-standards.md)**: BalanceConstants is the single read path for all 8 caps; no hardcoded literals matching cap values exist in `src/foundation/`. Story 010 will add a CI lint script formalizing this; this story includes a smoke check
- [x] CI lint pass: existing lint scripts reading balance_entities.json schema accept the new keys (no schema validator changes needed; balance_entities.json remains a flat constants-registry per `.claude/rules/data-files.md` Constants Registry Exception)
- [x] Pre-registered GDD reference is intact: `design/gdd/unit-role.md` Global Constant Summary table (lines 451-462) references `BalanceConstants.get_const(...)` for all 10 caps per ADR-0006 + ADR-0009 §Migration Plan

### Original AC list (pre-2026-04-28 re-scope)

The original AC list was scoped to MOVE_BUDGET_PER_RANGE only. Re-scoped 2026-04-28 to cover the full 8-cap unit-role obligation per ADR-0009 §4 line 221 (which declared all 10 caps as canonical but the §Migration Plan only called out MOVE_BUDGET_PER_RANGE explicitly — the gap was discovered during story-003 readiness probe).

---

## Implementation Notes

*From ADR-0009 §Migration Plan §4, ADR-0006 BalanceConstants pipeline:*

1. Single-line append to `assets/data/balance/balance_entities.json`:
   ```json
   {
     "ATK_CAP": 200,
     "DEF_CAP": 100,
     ...existing 9 keys...,
     "MOVE_BUDGET_PER_RANGE": 10
   }
   ```
   Exact placement (alphabetical order, last-key, etc.) follows the existing file convention — read the file before editing to confirm style. Must be a valid JSON edit (trailing comma rules etc.).
2. **Do not** add `MOVE_BUDGET_PER_RANGE` to `unit_roles.json` — global caps live in `balance_entities.json` exclusively per ADR-0006 §1 + ADR-0009 §4.
3. **Do not** add a `get_move_budget(hero, unit_class)` method on UnitRole — `move_budget = effective_move_range × MOVE_BUDGET_PER_RANGE` is a consumer-side compute per ADR-0009 §3.
4. The smoke test can be a one-liner GdUnit4 test OR an entry in `production/qa/smoke-2026-04-XX.md` confirming the constant is reachable. Either satisfies the Config/Data evidence requirement per `.claude/docs/coding-standards.md` Test Evidence by Story Type.
5. G-15 obligation applies to any test reading the new constant: `BalanceConstants._cache_loaded = false` in `before_test()`.

---

## Out of Scope

*Handled by neighbouring stories or consumer epics:*

- UnitRole `get_effective_move_range` method (Story 003 — already returns the range value; multiplication by MOVE_BUDGET_PER_RANGE is consumer-side)
- Grid Battle `move_budget` consumption (in future Grid Battle ADR + epic — out of scope this sprint)
- Map/Grid `get_movement_range` Dijkstra budget enforcement (existing per map-grid epic Complete; consumes effective_move_range × MOVE_BUDGET_PER_RANGE indirectly via the consumer)
- Any other balance constant additions (out of scope; this story is exactly one constant)

---

## QA Test Cases

*Config/Data story — smoke-check evidence required.*

- **AC-1 (BalanceConstants accessor returns 10)**:
  - Setup: `BalanceConstants._cache_loaded = false` in `before_test`; `assets/data/balance/balance_entities.json` is shipped with the new key
  - Verify: `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")` returns `10` (int)
  - Pass condition: exact `int 10` returned (NOT 10.0 float, NOT "10" String)

- **AC-2 (No regression on existing 9 constants)**:
  - Setup: same as AC-1
  - Verify: each of the 9 pre-existing constants returns its expected value:
    - `ATK_CAP == 200`
    - `DEF_CAP == 100`
    - `HP_CAP == 300`
    - `HP_SCALE == 2.0`
    - `HP_FLOOR == 50`
    - `INIT_CAP == 200`
    - `INIT_SCALE == 2.0`
    - `MOVE_RANGE_MIN == 2`
    - `MOVE_RANGE_MAX == 6`
  - Pass condition: all 9 unchanged

- **AC-3 (Smoke-check evidence document)**:
  - Setup: smoke-check pass after the append
  - Verify: `production/qa/smoke-2026-04-XX.md` (date as actual smoke run) lists the new constant + the 9 existing constants + their values
  - Pass condition: smoke-check doc exists, signed off by the implementer

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `tests/unit/foundation/balance_constants_unit_role_caps_test.gd` — exists and passes (9 test functions: 8 per-cap value assertions + 1 regression spot-check on 4 pre-existing scalar caps). Re-scoped from the original "smoke-check OR optional automated test" to a mandatory automated test since the 8-cap append is more substantive than the original 1-cap append.
**Status**: [x] Created 2026-04-28; **9 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED** (foundation test suite total: 32/32 green = 8 story-001 + 15 story-002 + 9 story-007)

---

## Dependencies

- Depends on: Story 001 (epic kickoff; conceptually paired with the unit-role implementation start)
- Unlocks: Future Grid Battle epic `move_budget` consumer (out of scope this sprint); ADR-0006 §Migration Plan obligation closure (this is the FIRST cross-doc obligation triggered by ADR-0006 ratification)
