# Story 007: Epic terminal — perf baseline + 5 forbidden_patterns lint + G-15 6-element reset list lint + Polish-tier scaffolds + TD entries

> **Epic**: Turn Order
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 2-3h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-009`, `TR-turn-order-019`, `TR-turn-order-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011 — Turn Order — 5 forbidden_patterns + G-15 6-element reset list + AC-23 perf baseline; ADR-0001 (single-emitter rule enforced via 4-signal whitelist lint); ADR-0006 (CHARGE_THRESHOLD + ROUND_CAP same-patch lint); ADR-0007 (Polish-tier deferral pattern precedent — 6th invocation: ADR-0008 + ADR-0006 + ADR-0009 + ADR-0012 + ADR-0007 + ADR-0011)
**ADR Decision Summary**: TR-009 = 5 forbidden_patterns registered in `docs/registry/architecture.yaml` v? → v? (consumer_mutation + external_queue_write + signal_emission_outside_domain + static_var_state_addition + typed_array_reassignment); plus same-patch addition `turn_order_ai_system_direct_symbol_reference` from S2-06 GDD revision (deferred from S2-06 per same-patch obligation pattern). TR-019 = G-15 6-element reset list (`_unit_states.clear()` + `_queue.clear()` + `_round_number = 0` + `_queue_index = 0` + `_round_state = BATTLE_NOT_STARTED` + `unit_died.disconnect()`); static-lint check `grep -L 'unit_died.disconnect' tests/unit/core/turn_order*.gd` returns empty. TR-021 = AC-23 perf budget < 1ms on minimum mobile for queue sort (20 units); per-attack queries O(1).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_usec()` (Godot 3.x+ stable); bash regex portable; same precedent as hero-database story-005 + balance-data story-005.

**Control Manifest Rules (Core layer)**:
- Required: 5 forbidden_patterns + 1 from S2-06 = 6 total registered in architecture.yaml; 4-signal whitelist enforced via grep negation (signal emissions other than the 4 named signals fail the lint); G-15 6-element reset list pattern enforced across all turn_order*.gd test files; perf gates ×3-25 over ADR headlines per balance-data + hero-database precedent
- Forbidden: lint script regex matching the project's own anti-self-trigger doc-comment paraphrase (mirrors lint_unit_role.sh §Check 1 pattern)
- Guardrail: lint script set -uo pipefail (project precedent ~10/14 lints); CI step inserted in tests.yml between foundation-layer lints and damage-calc downstream lints (positional discipline)

---

## Acceptance Criteria

*From GDD `design/gdd/turn-order.md` §Validation §14 + ADR-0011 §Validation Criteria §6 + §11 + §AC-23 perf, scoped to this story:*

- [ ] **AC-1** (TR-021, AC-23) `tests/unit/core/turn_order_perf_test.gd` measures 4 perf budgets at ×3-25 generous gates:
  - `initialize_battle(20-unit roster)` cold-start: < 50ms (×50 over 1ms ADR headline; absorbs F-1 sort + UnitTurnState construction × 20)
  - `get_acted_this_turn(unit_id) × 1000` cached: < 5ms (×5 over 1µs headline)
  - `get_charge_ready(unit_id) × 1000` cached: < 10ms (×5 over 2µs headline; includes BalanceConstants read per call)
  - `get_turn_order_snapshot() × 100` cached: < 25ms (×5 over 50µs headline; includes 20-unit deep-snapshot construction)
- [ ] **AC-2** (TR-009) `tools/ci/lint_turn_order_no_signal_emission.sh` Part 1: enforces 4-signal whitelist — grep -E `(emit_signal\(|GameBus\..*\.emit\()` against `src/core/turn_order_runner.gd`; allowed: `GameBus.round_started.emit` + `GameBus.unit_turn_started.emit` + `GameBus.unit_turn_ended.emit` + `GameBus.victory_condition_detected.emit`; ANY other GameBus signal emit triggers exit 1
- [ ] **AC-3** (TR-019) Same lint script Part 2: G-15 6-element reset list — `grep -L '_unit_states.clear\|unit_died.disconnect' tests/unit/core/turn_order*.gd tests/integration/core/turn_order*.gd` returns empty (every test file resets all 6 elements OR contains both _unit_states.clear AND unit_died.disconnect markers)
- [ ] **AC-4** (TR-009) `tools/ci/lint_turn_order_external_queue_write.sh`: enforces `turn_order_external_queue_write` forbidden_pattern — grep negation: NO `.gd` file outside `src/core/turn_order_runner.gd` may assign to `TurnOrderRunner._queue`, `TurnOrderRunner._unit_states`, `TurnOrderRunner._round_number`, `TurnOrderRunner._queue_index`, or `TurnOrderRunner._round_state` (covers all 5 instance fields)
- [ ] **AC-5** (TR-009) `tools/ci/lint_turn_order_no_ai_symbol_reference.sh`: enforces `turn_order_ai_system_direct_symbol_reference` forbidden_pattern (deferred from S2-06 same-patch obligation) — grep against `src/core/turn_order_runner.gd` for `class_name AI`, `import AISystem`, `preload(".*ai_.*\\.gd")`, `AISystem\\.`, etc.; exit 1 on any match
- [ ] **AC-6** (TR-009) Polish-tier scaffold `tools/ci/lint_turn_order_typed_array_reassignment.sh`: scaffold-only exit 0 with deferral message + reactivation trigger doc; full impl deferred to Polish per ADR-0011 §11 + 6-precedent Polish-deferral pattern (typed-array-reassignment requires AST-level static analysis or comprehensive grep heuristics; Polish-tier scope)
- [ ] **AC-7** (TR-009) 5 forbidden_patterns + 1 from S2-06 registered in `docs/registry/architecture.yaml`: `turn_order_consumer_mutation` + `turn_order_external_queue_write` + `turn_order_signal_emission_outside_domain` + `turn_order_static_var_state_addition` + `turn_order_typed_array_reassignment` + `turn_order_ai_system_direct_symbol_reference` — verified via grep architecture.yaml
- [ ] **AC-8** CI workflow wiring: `.github/workflows/tests.yml` includes 3 new lint steps invoking the 3 active lint scripts (no-signal-emission/G-15 + external-queue-write + no-ai-symbol-reference); positioned between hero-database lint and damage-calc downstream lints
- [ ] **AC-9** Polish-tier scaffold (typed-array-reassignment) NOT wired into CI per AC-4 + Implementation Note 4 in hero-database story-005 precedent (exit-0 stub adds noise without value)
- [ ] **AC-10** TD entry in `docs/tech-debt-register.md`: TD-046 (typed-array-reassignment Polish-tier full implementation) + TD-047 (cross-system Integration tests AC-17/AC-19/AC-20/AC-21 — POISON DoT death + battle-end via DoT + Scout Ambush gates — deferred until HP/Status epic + Damage Calc + Grid Battle ADRs ship)
- [ ] **AC-11** AC-23 mobile perf budget on-device measurement deferred via TD-048 (mirrors damage-calc story-010 + hero-database story-005 TD-045 precedent)
- [ ] **AC-12** Regression baseline maintained: ≥4 new perf tests; full suite ≥608 cases / 0 errors / ≤1 carried failure / 0 orphans; all active lint scripts exit 0 cleanly + neg-path verified

---

## Implementation Notes

*Derived from ADR-0011 §Validation §6 + §11 + §AC-23 perf + 6-precedent Polish-deferral pattern + hero-database story-005 + balance-data story-005 lint precedents:*

1. **Perf test pattern** — mirrors `tests/unit/balance/balance_constants_perf_test.gd` + `tests/unit/foundation/hero_database_perf_test.gd`:
   ```gdscript
   ## tests/unit/core/turn_order_perf_test.gd
   ## TR-turn-order-021 perf budget verification (headless CI permissive gates).
   extends GdUnitTestSuite

   var _runner: TurnOrderRunner

   func before_test() -> void:
       _runner = TurnOrderRunner.new()
       add_child(_runner)
       # Synthesize 20-unit roster

   func after_test() -> void:
       remove_child(_runner)
       _runner.free()

   func test_initialize_battle_20_units_under_50ms_cold_start() -> void:
       var roster: Array = _make_20_unit_roster()
       var start_us: int = Time.get_ticks_usec()
       _runner.initialize_battle(roster)
       var elapsed_us: int = Time.get_ticks_usec() - start_us
       assert_int(elapsed_us).is_less(50_000)

   # ... + 3 more cached-throughput tests for get_acted_this_turn / get_charge_ready / get_turn_order_snapshot
   ```

2. **`lint_turn_order_no_signal_emission.sh` Part 1 (4-signal whitelist enforcement)**:
   ```bash
   #!/usr/bin/env bash
   set -uo pipefail
   TARGET="src/core/turn_order_runner.gd"
   ALLOWED_SIGNALS="round_started|unit_turn_started|unit_turn_ended|victory_condition_detected"
   # Find any .emit( call NOT matching the allowed signal names
   bad=$(grep -nE "GameBus\.[a-z_]+\.emit\(" "$TARGET" | grep -vE "GameBus\.($ALLOWED_SIGNALS)\.emit\(" || true)
   if [ -n "$bad" ]; then
       echo "FAIL: TurnOrderRunner emits signals outside the 4-signal whitelist:"
       echo "$bad"
       exit 1
   fi
   # Also check for legacy emit_signal( form
   legacy=$(grep -nE "emit_signal\(" "$TARGET" || true)
   if [ -n "$legacy" ]; then
       echo "FAIL: TurnOrderRunner uses legacy emit_signal( form (use typed signal API):"
       echo "$legacy"
       exit 1
   fi
   ```

3. **G-15 reset list lint pattern** (Part 2 of same script):
   ```bash
   # Match presence of BOTH _unit_states.clear AND unit_died.disconnect markers
   missing=$(grep -L '_unit_states.clear' tests/unit/core/turn_order*.gd tests/integration/core/turn_order*.gd 2>/dev/null || true)
   if [ -n "$missing" ]; then exit 1; fi
   missing=$(grep -L 'unit_died.disconnect' tests/unit/core/turn_order*.gd tests/integration/core/turn_order*.gd 2>/dev/null || true)
   if [ -n "$missing" ]; then exit 1; fi
   echo "PASS: G-15 6-element reset list discipline intact across turn_order*.gd test files"
   ```

4. **`lint_turn_order_no_ai_symbol_reference.sh`** (S2-06 deferred same-patch):
   ```bash
   #!/usr/bin/env bash
   set -uo pipefail
   TARGET="src/core/turn_order_runner.gd"
   # Forbidden symbol patterns
   bad=$(grep -nE "(class_name AI|import AISystem|preload\(.*ai_.*\.gd|AISystem\.)" "$TARGET" || true)
   if [ -n "$bad" ]; then
       echo "FAIL: TurnOrderRunner contains AI System symbol reference (architecture.md §1 invariant #4 violation per Contract 5 Callable-delegation contract):"
       echo "$bad"
       exit 1
   fi
   ```

5. **Polish-tier scaffold** `lint_turn_order_typed_array_reassignment.sh` — exit 0 stub with deferral doc:
   ```bash
   #!/usr/bin/env bash
   # Polish-tier deferred per ADR-0011 §11 + 6-precedent Polish-deferral pattern.
   # Reactivation trigger: AST-level static analysis tooling available OR comprehensive grep heuristic codified.
   echo "lint_turn_order_typed_array_reassignment: Polish-deferred — typed-array-reassignment AST analysis not yet active. See ADR-0011 §11 + tech-debt-register.md TD-046."
   exit 0
   ```

6. **CI workflow positioning** — `.github/workflows/tests.yml` insert 3 new steps after the hero-database non-emitter lint (line 71 + 72 in current file post-hero-database story-005), before the damage-calc downstream lints. Resulting structure:
   ```yaml
   - name: Lint HeroDatabase non-emitter + G-15 isolation (TR-hero-database-013 / story-005)
     run: bash tools/ci/lint_hero_database_no_signal_emission.sh
   - name: Lint TurnOrderRunner 4-signal whitelist + G-15 reset list (TR-turn-order-007 + TR-turn-order-019)
     run: bash tools/ci/lint_turn_order_no_signal_emission.sh
   - name: Lint TurnOrderRunner external queue write (TR-turn-order-009 forbidden_pattern)
     run: bash tools/ci/lint_turn_order_external_queue_write.sh
   - name: Lint TurnOrderRunner no AI symbol reference (TR-turn-order-009 forbidden_pattern + S2-06 same-patch)
     run: bash tools/ci/lint_turn_order_no_ai_symbol_reference.sh
   - name: Lint provisional formula retired (AC-DC-44 TR-damage-calc-009)
     # ... existing damage-calc lints follow
   ```

7. **TD entries** (3 new in `docs/tech-debt-register.md`):
   - **TD-046**: typed-array-reassignment Polish-tier full implementation (AST analysis OR comprehensive grep heuristic; ~3-4h)
   - **TD-047**: Cross-system Integration tests for AC-17 (POISON DoT death T1) + AC-19 (battle-end via DoT signal) + AC-20 (Scout Ambush suppressed Round 1) + AC-21 (Scout Ambush WAIT target Round 2+); reactivation trigger = HP/Status epic Complete (S2-07) + Damage Calc Scout Ambush integration verified + Grid Battle ADR exists; ~6-8h once dependencies ship
   - **TD-048**: AC-23 mobile perf on-device benchmark (Snapdragon 7-gen reference); reactivation trigger = mobile build pipeline + target device available; ~2-3h

8. **Architecture.yaml registration** — append the 6 forbidden_patterns to the existing `forbidden_patterns:` block in `docs/registry/architecture.yaml`. Each entry follows the precedent shape (id + system + rationale + lint_script reference). The 6th (`turn_order_ai_system_direct_symbol_reference`) is the deferred S2-06 same-patch obligation.

9. **Negative-path verification** — for AC-2 + AC-4 + AC-5: orchestrator at /dev-story time injects a synthetic violation (e.g., `GameBus.battle_outcome_resolved.emit(0)` line into turn_order_runner.gd), confirms lint exit 1, restores clean state, confirms exit 0. Mirrors hero-database story-005 negative-path verification protocol per `.claude/rules/tooling-gotchas.md`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Stories 001-006**: All actual TurnOrderRunner functionality (this story tests + lints + scaffolds the existing implementation; does NOT modify production code)
- **Cross-system integration tests** (AC-17/19/20/21): logged as TD-047 deferral; require HP/Status (S2-07) + Damage Calc + Grid Battle to be implemented
- **AC-23 mobile on-device perf**: logged as TD-048 deferral
- **Polish-tier typed-array-reassignment full lint**: logged as TD-046 deferral
- **Hp-status / Grid Battle / AI System / Battle Preparation epics** (S2-07 + future ADRs)

---

## QA Test Cases

*Lean mode — orchestrator-authored:*

**AC-1 perf baseline**:
- Given: 20-unit roster fixture
- When: `runner.initialize_battle(roster)` measured via Time.get_ticks_usec()
- Then: elapsed_us < 50_000 (50ms gate)
- Edge case: re-run on first run (cold cache) vs warmup → both within gate

**AC-2 + AC-3 lint clean-pass + neg-path**:
- Given: clean turn_order_runner.gd + clean turn_order*.gd test files
- When: `bash tools/ci/lint_turn_order_no_signal_emission.sh`
- Then: exit 0; output `PASS:`
- Negative-path: inject `GameBus.battle_outcome_resolved.emit(0)` into turn_order_runner.gd → lint exit 1; restore + re-run → exit 0

**AC-4 + AC-5 lint clean-pass + neg-path**:
- Given: clean source state
- When: bash invocation of each lint
- Then: exit 0
- Negative-path each: inject violation → exit 1; restore → exit 0

**AC-6 Polish scaffold**:
- Given: scaffold script post-creation
- When: `bash tools/ci/lint_turn_order_typed_array_reassignment.sh`
- Then: exit 0; output cites ADR-0011 §11 + TD-046

**AC-7 architecture.yaml registration**:
- Given: `docs/registry/architecture.yaml` post-edit
- When: `grep -E "turn_order_(consumer_mutation|external_queue_write|signal_emission_outside_domain|static_var_state_addition|typed_array_reassignment|ai_system_direct_symbol_reference)" docs/registry/architecture.yaml`
- Then: 6 matches

**AC-8 CI wiring**:
- Given: `.github/workflows/tests.yml` post-edit
- When: `grep -A1 "Lint TurnOrderRunner" .github/workflows/tests.yml`
- Then: 3 step blocks present (no-signal-emission + external-queue-write + no-ai-symbol-reference); each followed by `run: bash tools/ci/lint_turn_order_*.sh`

**AC-10 TD entries**:
- Given: `docs/tech-debt-register.md` post-edit
- When: grep for TD-046 + TD-047 + TD-048 headers
- Then: 3 entries present; each with Severity + Origin + Owner + Reactivation triggers + Resolution path + Cost + References fields populated

**AC-12 Regression**:
- Given: full GdUnit4 suite
- Then: ≥608 cases / 0 errors / 1 carried failure / 0 orphans; all active lints exit 0 + neg-path verified

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/core/turn_order_perf_test.gd` — new file (~4 perf tests)
- `tools/ci/lint_turn_order_no_signal_emission.sh` — new file (~70 LoC bash, 2 parts)
- `tools/ci/lint_turn_order_external_queue_write.sh` — new file (~30 LoC bash)
- `tools/ci/lint_turn_order_no_ai_symbol_reference.sh` — new file (~30 LoC bash)
- `tools/ci/lint_turn_order_typed_array_reassignment.sh` — new file scaffold (~25 LoC bash exit-0)
- `.github/workflows/tests.yml` — +12 lines for 3 new lint steps
- `docs/registry/architecture.yaml` — append 6 forbidden_pattern entries
- `docs/tech-debt-register.md` — +3 entries (TD-046 + TD-047 + TD-048)
- Smoke check: `production/qa/smoke-turn-order-story-007-YYYY-MM-DD.md` — recommended (perf gate + lint negative-path verifications)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 + 002 + 003 + 004 + 005 + 006 — all production functionality must exist for the perf tests to measure + the lints to scan a representative source state
- Unlocks: **EPIC CLOSE-OUT** — story-007 is the terminal step. Post-close-out: epic flips from Ready → Complete in `production/epics/index.md` + sprint-status.yaml S2-08 done.

---

## Completion Notes (2026-05-02)

**Verdict**: COMPLETE — all 12 ACs satisfied.

### AC mapping

| AC | Evidence |
|----|----------|
| AC-1 (TR-021 perf budgets) | `tests/unit/core/turn_order_perf_test.gd` (282 LoC, 4 perf tests at ×3-25 generous gates over ADR-0011 §AC-23 1ms headline) |
| AC-2 (TR-009 4-signal whitelist) | `tools/ci/lint_turn_order_no_signal_emission.sh` Part 1; exit 0 |
| AC-3 (TR-019 G-15 reset list) | Same script Part 2; exit 0 |
| AC-4 (TR-009 external queue write ban) | `tools/ci/lint_turn_order_external_queue_write.sh`; exit 0 |
| AC-5 (TR-009 + S2-06 AI symbol ban) | `tools/ci/lint_turn_order_no_ai_symbol_reference.sh`; exit 0 |
| AC-6 (TR-009 typed-array Polish scaffold) | `tools/ci/lint_turn_order_typed_array_reassignment.sh`; exit 0 stub with deferral message |
| AC-7 (6 forbidden_patterns registered) | `docs/registry/architecture.yaml` lines 1165-1212 — all 6 patterns active: turn_order_consumer_mutation, turn_order_external_queue_write, turn_order_signal_emission_outside_domain, turn_order_static_var_state_addition, turn_order_typed_array_reassignment, turn_order_ai_system_direct_symbol_reference (6th added 2026-05-02 same-patch with story-007) |
| AC-8 (CI workflow wiring) | `.github/workflows/tests.yml` 3 new lint steps inserted between hero-database lint (line 71-72) and damage-calc fgb_prov_removed lint (line 80-81) |
| AC-9 (typed-array NOT in CI) | Confirmed — typed-array Polish scaffold is the only lint script not invoked from tests.yml |
| AC-10 (3 TD entries) | `docs/tech-debt-register.md`: TD-047 (typed-array Polish full impl), TD-048 (cross-system Integration AC-17/19/20/21), TD-049 (mobile perf budget AC-23) |
| AC-11 (mobile perf via TD-049) | TD-049 logged with reactivation triggers + resolution path |
| AC-12 (regression baseline) | **648 cases / 0 errors / 1 unique failed testcase / 0 orphans** — sole failure = pre-existing carried `test_round_lifecycle_emit_order_two_units` (NOT introduced by story-007); gdunit4 summary "2 failures" reflects 2 assertion failures within that one testcase. All 4 active lint scripts exit 0 cleanly. |

### Regression progression

644 (post-story-006) → **648** (+4 perf tests) / 0 errors / 1 carried failure (pre-existing) / 0 orphans.

### Out-of-scope deviations

NONE.

### Tech debt logged

- **TD-047** — `lint_turn_order_typed_array_reassignment.sh` Polish-tier full implementation (currently exit-0 scaffold)
- **TD-048** — Turn Order cross-system Integration tests AC-17/AC-19/AC-20/AC-21 (require HP/Status epic + Damage Calc Alpha + Grid Battle convergence)
- **TD-049** — Turn Order AC-23 mobile perf budget on-device measurement (Polish-tier on-device measurement; mirrors damage-calc story-010 + hero-database TD-045 precedent)

### Same-patch obligations satisfied

- **S2-06 AI symbol reference forbidden_pattern** (deferred from S2-06 turn-order GDD revision) — `turn_order_ai_system_direct_symbol_reference` registered in architecture.yaml + lint script wired into CI. S2-06 same-patch obligation now CLOSED.

### Manifest staleness check

PASS (story 2026-04-20 = current 2026-04-20 manifest).

### Epic close-out

**Turn Order epic 7/7 stories COMPLETE**. Story-001 (skeleton) → 002 (initialize_battle) → 003 (advance_turn T1-T7) → 004 (declare_action + tokens) → 005 (death + charge accumulation) → 006 (victory detection) → 007 (epic terminal). 23/23 GDD ACs covered (AC-01..AC-16 + AC-18 + AC-22 + AC-23) or deferred via TD-048 (AC-17 + AC-19 + AC-20 + AC-21 cross-system).

**Sprint impact**: turn-order epic = bonus throughput beyond sprint-2 commitment (S2-08 was /create-epics + /create-stories only; full implementation was unscheduled scope-up). Sprint-2 must-have 5/5 + should-have 2/4 + bonus turn-order epic 7/7 stories Complete.
