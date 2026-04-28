# Story 007: MOVE_BUDGET_PER_RANGE balance_entities.json append + cross-doc obligation closure

> **Epic**: unit-role
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20
> **Estimate**: 1 hour (XS)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-005` (cross-doc obligation portion)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§Migration Plan §4) + ADR-0006 — Balance/Data (BalanceConstants accessor + balance_entities.json schema)
**ADR Decision Summary**: `MOVE_BUDGET_PER_RANGE = 10` constant single-line append to `assets/data/balance/balance_entities.json` per ADR-0009 §Migration Plan §4. Pre-registered in `unit-role.md` GDD Global Constant Summary table (lines 451-462) at ADR-0009 authoring. Consumers (Grid Battle, when implemented) read via `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")`. UnitRole's own `get_effective_move_range` does NOT need this constant — `move_budget = effective_move_range × MOVE_BUDGET_PER_RANGE` is a consumer-side compute per ADR-0009 §3 + §Requirements.

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

- [ ] **AC-20 (Data-driven, no hardcoded gameplay values)**: `MOVE_BUDGET_PER_RANGE = 10` is added to `assets/data/balance/balance_entities.json` (NOT hardcoded anywhere in `src/`)
- [ ] `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")` returns `10` (int)
- [ ] Smoke test: a test (or smoke-check doc) confirms `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE") == 10`
- [ ] No regression: existing 9 BalanceConstants entries (ATK_CAP, DEF_CAP, HP_CAP, HP_SCALE, HP_FLOOR, INIT_CAP, INIT_SCALE, MOVE_RANGE_MIN, MOVE_RANGE_MAX) still return their expected values after the append
- [ ] CI lint pass: any existing lint scripts reading balance_entities.json schema accept the new key (no schema validator changes needed per ADR-0009 §Migration Plan §4 "lint-script reference unchanged")
- [ ] Pre-registered GDD reference is intact: `design/gdd/unit-role.md` Global Constant Summary table lines 451-462 reference `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")` (ADR-0006, ADR-0009 §Migration Plan)

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
**Required evidence**: `production/qa/smoke-2026-04-XX.md` (smoke-check pass entry confirming MOVE_BUDGET_PER_RANGE == 10 + 9 existing constants intact). Optional: `tests/unit/foundation/balance_constants_move_budget_test.gd` for an automated assertion (preferred — converts the smoke-check into a regression test that runs on every push)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (epic kickoff; conceptually paired with the unit-role implementation start)
- Unlocks: Future Grid Battle epic `move_budget` consumer (out of scope this sprint); ADR-0006 §Migration Plan obligation closure (this is the FIRST cross-doc obligation triggered by ADR-0006 ratification)
