# Story 005: Perf baseline + non-emitter lint + Polish-tier validation lint scaffold

> **Epic**: Hero Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2-3h (perf test + 2 lint scripts + CI step + tech-debt entry)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hero-database.md`
**Requirement**: `TR-hero-database-011`, `TR-hero-database-013`, `TR-hero-database-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 — Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope), ADR-0001 — GameBus Autoload (non-emitter invariant per line 372), ADR-0006 — Balance/Data (BalanceConstants forward-compat for F-1..F-4 thresholds — Polish-tier only)
**ADR Decision Summary**: TR-013 non-emitter invariant — zero `signal` declarations + zero `connect()`/`emit_signal()` calls in `hero_database.gd` + `hero_data.gd`; mirrors ADR-0012 + ADR-0009 + ADR-0006 4-precedent stateless-non-emitter discipline. TR-015 perf budgets — `get_hero` <0.001ms (Dictionary[StringName, HeroData] hash lookup); `_load_heroes()` <100ms target for 100-hero Alpha (10-hero MVP measured; AC-15 100-hero benchmark Polish-deferred via 5-precedent extrapolation pattern). TR-011 F-1..F-4 stat-balance + SPI + growth-ceiling + MVP-roster validation Polish-deferred to `tools/ci/lint_hero_database_validation.sh` per ADR-0007 §11 + N2 (5-precedent Polish-deferral pattern: ADR-0008 + ADR-0006 + ADR-0009 + ADR-0012 + ADR-0007).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_usec()` for microsecond timing — Godot 3.x+ stable; bash `grep -E` regex for lint scripts portable; CI step insertion follows balance-data story-003 (lint template) + story-004 (orphan grep gate) precedent — both already shipped in `.github/workflows/tests.yml`.

**Control Manifest Rules (Foundation layer)**:
- Required: non-emitter invariant enforced via grep-based static lint (4-precedent: damage-calc + unit-role + balance-data + hero-database)
- Required: G-15 test isolation grep gate — every test that touches HeroDatabase must reset `_heroes_loaded = false` in `before_test()`
- Required: tech-debt register entries cite ADR section + reactivation trigger
- Forbidden: `signal `/`connect(`/`emit_signal(` matches in `src/foundation/hero_database.gd` or `src/foundation/hero_data.gd`
- Forbidden: hardcoded validation thresholds in `lint_hero_database_validation.sh` — must read via `BalanceConstants.get_const(key)` per ADR-0006 forward-compat (when the lint actually runs in Polish phase)
- Guardrail: perf test gate `get_hero` <0.001ms headless; `_load_heroes()` <2ms for 10-hero MVP fixture (benchmark only — extrapolation gate deferred per AC-15 100-hero/100ms forward-compat)

---

## Acceptance Criteria

*From ADR-0007 §Performance + §Validation Criteria §6 + §11 + N2 + GDD AC-08..AC-11 (Polish-deferred), scoped to this story:*

- [ ] **AC-1** (TR-015 perf baseline test): `tests/unit/foundation/hero_database_perf_test.gd` measures:
  - `get_hero(&"<known_id>")` × 1000 iterations: median <0.001ms (1µs); p99 <0.01ms (10µs)
  - `_load_heroes()` cold-start cost on a 10-hero MVP fixture: <2ms median
  - `get_mvp_roster()` × 100 iterations: <0.05ms median (linear scan over 10 heroes)
  - `get_heroes_by_faction(0)` × 100 iterations: <0.05ms median
  Results captured in evidence doc (next AC); test gates are headless-CI permissive (×3-5 over budget acceptable to absorb noise).
- [ ] **AC-2** (TR-013 non-emitter lint script): `tools/ci/lint_hero_database_no_signal_emission.sh` exists; runs `grep -E '(signal\s|connect\(|emit_signal\()' src/foundation/hero_database.gd src/foundation/hero_data.gd`; exits 0 on zero matches, exit 1 on any match. Mirrors `tools/ci/lint_unit_role.sh` pattern (or `lint_damage_calc_*.sh` pattern — choose the closer-fit precedent at implementation time).
- [ ] **AC-3** (G-15 isolation grep gate as part of AC-2 lint script OR a separate one-liner in CI): `grep -L '_heroes_loaded = false' tests/unit/foundation/hero_database*.gd tests/integration/foundation/hero_database*.gd` returns empty (every HeroDatabase test file resets isolation). Acceptable to implement as a second invocation within the same lint script.
- [ ] **AC-4** (TR-011 Polish-tier validation lint scaffold): `tools/ci/lint_hero_database_validation.sh` exists in **scaffold-only form** with:
  - Header doc comment citing ADR-0007 §11 + N2 (Polish-deferral rationale)
  - Stub bash that exits 0 with `echo "Polish-deferred: F-1..F-4 stat-balance lint not yet active. See ADR-0007 §11 + tech-debt-register TD-XXX."`
  - List of expected validation gates as comments (F-1 stat_total ∈ [180,280], F-2 SPI < 0.5, F-3 stat_projected ≤ 100, F-4 MVP roster 4-dominant-stat coverage)
  - Note: full implementation requires `BalanceConstants.get_const("STAT_TOTAL_MIN" / "STAT_TOTAL_MAX" / "SPI_WARNING_THRESHOLD" / "STAT_HARD_CAP" / "MVP_FLOOR_OFFSET" / "MVP_CEILING_OFFSET")` — these threshold appends to `balance_entities.json` are part of the Polish-phase reactivation, NOT this story
- [ ] **AC-5** (CI wiring for AC-2 lint): `.github/workflows/tests.yml` includes a new step invoking `bash tools/ci/lint_hero_database_no_signal_emission.sh` between an existing lint step and the gdunit4-job — mirrors balance-data story-003/004 CI integration precedent
- [ ] **AC-6** (CI wiring for AC-3 isolation gate): if implemented as a separate script, also wired into `.github/workflows/tests.yml`; if combined with AC-2, no separate step needed
- [ ] **AC-7** (tech-debt entry — Polish-tier validation lint): new entry in `docs/tech-debt-register.md`:
  - **TD-#**: `lint_hero_database_validation.sh` Polish-tier full implementation
  - **Owner**: Polish phase
  - **Reactivation trigger**: BalanceConstants threshold append (`balance_entities.json` gains 6 keys: `STAT_TOTAL_MIN`, `STAT_TOTAL_MAX`, `SPI_WARNING_THRESHOLD`, `STAT_HARD_CAP`, `MVP_FLOOR_OFFSET`, `MVP_CEILING_OFFSET`) AND ≥30 hero records authored
  - **Cross-refs**: ADR-0007 §11 + N2; ADR-0006 forward-compat; this story's scaffold path
  - **Estimate**: 2-3h (write the 4 validation passes + integrate with `BalanceConstants.get_const`)
- [ ] **AC-8** (tech-debt entry — AC-15 100-hero/100ms benchmark): new entry in `docs/tech-debt-register.md`:
  - **TD-#**: `_load_heroes` 100-hero benchmark test (Polish-tier on-device measurement)
  - **Owner**: Polish phase
  - **Reactivation trigger**: ≥30 hero records authored OR target-device available for measurement (mirrors damage-calc story-010 Polish-deferral precedent)
  - **Cross-refs**: ADR-0007 §Performance + GDD AC-15
- [ ] **AC-9** (perf test does NOT block CI on slow hardware): perf test asserts use generous gates (×3-5 over headline budget); test failure = perf regression signal, NOT a CI blocker for normal noise
- [ ] **AC-10** (regression PASS): full GdUnit4 regression maintains story-004's baseline post-story; 0 errors / ≤1 carried failure / 0 orphans; both new lint scripts exit 0 cleanly

---

## Implementation Notes

*Derived from ADR-0007 §Performance + §Validation Criteria §6 + §11 + N2 + ADR-0001 line 372 + ADR-0006 forward-compat + 5-precedent Polish-deferral pattern:*

1. **Perf test pattern** (mirrors `tests/unit/balance/balance_constants_perf_test.gd` from balance-data story-005 + `tests/unit/foundation/unit_role_perf_test.gd` from unit-role epic):
   ```gdscript
   ## hero_database_perf_test.gd
   ## TR-hero-database-015 perf budget verification (headless CI permissive gates).

   class_name HeroDatabasePerfTest extends GdUnitTestSuite

   func before_test() -> void:
       HeroDatabase._heroes_loaded = false
       HeroDatabase._heroes = {}

   func test_get_hero_perf_under_1us_median() -> void:
       # Load fixture
       _populate_test_fixture()
       var times: PackedFloat64Array = []
       for i in 1000:
           var t0 := Time.get_ticks_usec()
           var _h := HeroDatabase.get_hero(&"shu_001_liu_bei")
           times.append(Time.get_ticks_usec() - t0)
       var median := _percentile(times, 50)
       assert_float(median).is_less(5.0)  # 5µs gate (headless permissive)

   # ... similar tests for _load_heroes, get_mvp_roster, get_heroes_by_faction
   ```

2. **Non-emitter lint script** (mirrors `tools/ci/lint_unit_role.sh` shape):
   ```bash
   #!/usr/bin/env bash
   # lint_hero_database_no_signal_emission.sh
   # TR-hero-database-013 — enforces ADR-0001 line 372 non-emitter invariant.
   # Mirrors damage-calc + unit-role + balance-data 4-precedent.
   set -euo pipefail

   target_files=(
       "src/foundation/hero_database.gd"
       "src/foundation/hero_data.gd"
   )

   violations=$(grep -nE '(signal\s|connect\(|emit_signal\()' "${target_files[@]}" || true)
   if [[ -n "$violations" ]]; then
       echo "FAIL: HeroDatabase non-emitter invariant violated (ADR-0001 line 372):"
       echo "$violations"
       exit 1
   fi

   # G-15 test isolation grep gate (AC-3)
   missing_isolation=$(grep -L '_heroes_loaded = false' \
       tests/unit/foundation/hero_database*.gd \
       tests/integration/foundation/hero_database*.gd 2>/dev/null || true)
   if [[ -n "$missing_isolation" ]]; then
       echo "FAIL: HeroDatabase test files missing G-15 isolation reset (_heroes_loaded = false in before_test):"
       echo "$missing_isolation"
       exit 1
   fi

   echo "PASS: HeroDatabase non-emitter + G-15 isolation invariants intact"
   exit 0
   ```

3. **Polish-tier validation lint scaffold** — exit 0 stub with informative message:
   ```bash
   #!/usr/bin/env bash
   # lint_hero_database_validation.sh
   # TR-hero-database-011 — F-1..F-4 stat-balance + SPI + growth-ceiling + MVP-roster validation.
   #
   # POLISH-TIER DEFERRED per ADR-0007 §11 + N2 (5-precedent Polish-deferral pattern:
   #   ADR-0008 + ADR-0006 + ADR-0009 + ADR-0012 + ADR-0007 = pattern is now load-bearing project discipline).
   #
   # Reactivation trigger:
   #   - BalanceConstants threshold append (balance_entities.json gains 6 keys:
   #     STAT_TOTAL_MIN, STAT_TOTAL_MAX, SPI_WARNING_THRESHOLD, STAT_HARD_CAP,
   #     MVP_FLOOR_OFFSET, MVP_CEILING_OFFSET) per ADR-0006 forward-compat
   #   - AND ≥30 hero records authored (Alpha-tier roster milestone)
   #
   # Validation passes (when reactivated):
   #   F-1: stat_total ∈ [STAT_TOTAL_MIN=180, STAT_TOTAL_MAX=280] (boundary inclusive)
   #   F-2: SPI = (stat_max - stat_min) / stat_avg < SPI_WARNING_THRESHOLD=0.5
   #   F-3: stat_projected(L) ≤ STAT_HARD_CAP=100 at L=L_cap
   #   F-4: MVP roster: stat_total ∈ [190, 260] AND 4-distinct-dominant_stat coverage
   #
   # Cross-refs: docs/architecture/ADR-0007-hero-database.md §11 + N2
   #             docs/architecture/ADR-0006-balance-data.md (forward-compat threshold reads)
   #             docs/tech-debt-register.md TD-### (Polish-tier full implementation)
   set -euo pipefail
   echo "Polish-deferred: F-1..F-4 stat-balance lint not yet active. See ADR-0007 §11 + tech-debt-register."
   exit 0
   ```

4. **CI step insertion** — `.github/workflows/tests.yml`, mirroring balance-data story-003/004 precedent:
   ```yaml
   - name: Lint — HeroDatabase non-emitter + G-15 isolation
     run: bash tools/ci/lint_hero_database_no_signal_emission.sh
   ```
   Insert between an existing lint step (likely the balance-data orphan grep gate) and the gdunit4-job. Polish-tier validation lint NOT wired into CI yet (the scaffold exits 0; wiring it would just print the deferral message — wait until reactivation).

5. **Tech-debt entries** — append to `docs/tech-debt-register.md` following the TD-041 + TD-### precedent shape used by balance-data story-005. Use the next available TD number (check `docs/tech-debt-register.md` head for the latest TD-NNN at implementation time).

6. **AC-1 perf gates rationale** — generous gates absorb headless CI noise:
   - `get_hero` budget per ADR-0007 = <0.001ms (1µs); test gate at <5µs (×5)
   - `_load_heroes` budget per ADR-0007 = ~5-15ms for 10-hero MVP; test gate at <50ms (×3-5)
   - `get_mvp_roster` budget = <0.01ms (10µs); test gate at <50µs (×5)
   - `get_heroes_by_faction` budget = <0.05ms (50µs) for 10-hero MVP; test gate at <250µs (×5)

7. **Documentation cross-link** — story-005 close-out should update `production/epics/hero-database/EPIC.md` Stories table to flip status flags + reference TD entries by number.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: FATAL validation pipeline (CR-1 + CR-2 + EC-1 + EC-2)
- **Story 003**: MVP roster authoring + happy-path integration test
- **Story 004**: WARNING tier + R-1 mitigation regression
- **Polish phase**: full implementation of `lint_hero_database_validation.sh` + on-device 100-hero/100ms benchmark + BalanceConstants threshold append (driven by tech-debt entries from this story)

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1** (perf baseline):
- Given: `tests/unit/foundation/hero_database_perf_test.gd` post-implementation, real `heroes.json` from story-003
- When: `godot --headless ... -a tests/unit/foundation/hero_database_perf_test.gd` runs
- Then: all perf tests pass with median values within budget
- Edge case: any perf test failure on first run → triage CI runner load, NOT immediate code change (re-run before flagging)

**AC-2** (non-emitter lint):
- Given: clean `hero_database.gd` + `hero_data.gd` post-story-004
- When: `bash tools/ci/lint_hero_database_no_signal_emission.sh` runs
- Then: exit 0, output `PASS:`
- Negative-path test: inject literal `signal test_signal` line into hero_database.gd, re-run, expect exit 1; remove line, re-run, expect exit 0 (mirrors balance-data story-004 negative-path verification per `.claude/rules/tooling-gotchas.md`)

**AC-3** (G-15 isolation gate):
- Given: all `tests/unit/foundation/hero_database*.gd` + `tests/integration/foundation/hero_database*.gd` post-story-004
- When: lint script runs (combined OR separate)
- Then: zero "missing isolation" matches; exit 0
- Negative-path test: temporarily remove `_heroes_loaded = false` from one test file, re-run, expect exit 1; restore, re-run, expect exit 0

**AC-4** (Polish-tier scaffold):
- Given: scaffold script post-creation
- When: `bash tools/ci/lint_hero_database_validation.sh` runs
- Then: exit 0 + prints "Polish-deferred" message + cites ADR-0007 §11

**AC-5** (CI wiring AC-2):
- Given: `.github/workflows/tests.yml` post-edit
- When: `grep -A 1 'Lint — HeroDatabase' .github/workflows/tests.yml`
- Then: matches the new step name + run command; step is positioned per-precedent

**AC-7 + AC-8** (tech-debt entries):
- Given: `docs/tech-debt-register.md` post-edit
- When: `grep -E "TD-### lint_hero_database_validation|TD-### _load_heroes 100-hero" docs/tech-debt-register.md` (substituting actual TD-N at implementation time)
- Then: both entries present with reactivation trigger + cross-refs + estimate fields populated

**AC-10** (regression PASS):
- Given: full regression run
- Then: ≥ story-004's baseline + this story's perf tests; 0 errors; ≤1 carried failure; 0 orphans
- Both lint scripts exit 0 in their CI invocations

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/foundation/hero_database_perf_test.gd` — new file (4-5 perf tests)
- `tools/ci/lint_hero_database_no_signal_emission.sh` — new file (~50 LoC bash)
- `tools/ci/lint_hero_database_validation.sh` — new file scaffold-only (~30 LoC bash)
- `.github/workflows/tests.yml` — +3-5 lines for the new lint step
- `docs/tech-debt-register.md` — +2 entries (Polish-tier validation lint + 100-hero benchmark)
- Smoke check: `production/qa/smoke-hero-database-story-005-YYYY-MM-DD.md` — recommended (perf gate passes + lint negative-path verification + CI step verification)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (module + test isolation) + Story 002 (validation pipeline) + Story 003 (MVP roster for perf measurement) + Story 004 (test files exist for the G-15 grep gate to scan)
- Unlocks: **EPIC CLOSE-OUT** — story 005 is the terminal step per implementation order `001 → 002 → 003 → {004, 005 parallel}`. Post-close-out: epic flips from Ready → Complete in `production/epics/index.md` + sprint-status.yaml S2-04 done.

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 10/10 passing — 9 auto-verified + 1 ADVISORY (smoke check deferred to sprint-level `/smoke-check sprint`)
**Regression**: 560 → **564 / 0 errors / 1 carried failure / 0 orphans** ✅ (sole failure = pre-existing carried orthogonal `unit_role_skeleton_test::test_hero_data_doc_comment_contains_required_strings`; not introduced by story-005)
**Test Evidence**:
- `tests/unit/foundation/hero_database_perf_test.gd` (143 LoC, 4 tests, all PASS) — TR-015 perf gates verified at canonical path
- `tools/ci/lint_hero_database_no_signal_emission.sh` (NEW, exec, 56 LoC) — TR-013 non-emitter + G-15 isolation, both clean-pass + negative-path verified
- `tools/ci/lint_hero_database_validation.sh` (NEW, exec, 32 LoC) — Polish-tier scaffold exit-0 stub with §11+N2 + 6-key reactivation triggers
- `.github/workflows/tests.yml:71` — non-emitter lint wired into CI pipeline
- `docs/tech-debt-register.md` — TD-044 (Polish validation lint full implementation) + TD-045 (100-hero/100ms on-device benchmark); register count 43 → 45
**Code Review**: APPROVED WITH SUGGESTIONS (lean mode, orchestrator-direct review against ADR-0007 §11+N2 + ADR-0001 line 372 + ADR-0006 forward-compat + godot-4x-gotchas G-2/G-9/G-15/G-22/G-23 + test-standards). 5 forward-looking suggestions captured (none blocking):
- **S-1** (cosmetic): lint script uses `set -uo pipefail` matching dominant precedent (~10/14 lints) where spec text wrote `-euo`
- **S-2** (cosmetic): perf test name embeds "median" but uses single-call cold-start measurement; consider rename to `..._under_50ms_cold_start` on next cleanup pass
- **S-3** (forward-looking): when TD-044 fires, add comment near AC-2 lint step indicating where to insert validation lint step
- **S-4** (forward-looking): TD-045 cites `ADR-0001 mobile baseline` — verify ADR text current at benchmark time
- **S-5** (forward-looking): lint glob `tests/integration/foundation/hero_database*.gd` will silently match nothing if file rename ever decouples the prefix; consider widening to `*hero_database*.gd`
**Deviations**:
- ADVISORY: lint shell flags `-uo` vs spec's `-euo` (precedent-following; no impact)
- ADVISORY: perf test sum-based assertions vs spec's "median" wording (mirrors `balance_constants_perf_test.gd` precedent)
- ADVISORY: 5 forward-looking code-review suggestions captured above
**Sprint impact**: S2-04 epic-level done flag flips with this close-out (5/5 stories Complete). Sprint-2 must-have advances 3/5 → 4/5. EPIC.md status flip + index.md refresh handled by S2-05 admin task.
**Tech debt logged**: 0 new (TD-044 + TD-045 added during /dev-story per AC-7 + AC-8 — already committed; no additional debt from code-review suggestions).
