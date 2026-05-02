# Story 008: Epic terminal — perf baseline + 5 forbidden_patterns lints + CI wiring + cross-platform determinism + AC-20 + 3 TD entries

> **Epic**: HP/Status
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: 2-3h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hp-status.md`
**Requirement**: `TR-hp-status-015` (consumer mutation forbidden_pattern + R-5 mitigation), `TR-hp-status-016` (performance baseline; on-device deferred), `TR-hp-status-017` (cross-platform determinism via integer arithmetic + headless CI deterministic-fixture mandatory before Polish)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 — HP/Status §Performance + Verification + Validation Criteria 1-13
**ADR Decision Summary**: §Performance — `apply_damage` < 0.05ms, `get_modified_stat` < 0.05ms, `apply_status` < 0.10ms, `_apply_turn_start_tick` < 0.20ms; ~10KB heap footprint; headless CI baseline mandatory; on-device measurement deferred per damage-calc story-010 Polish-deferral pattern (stable at 6+ invocations as of ADR-0007). Validation §1-13 enumerates 13 verification gates including: §3 single-emitter `unit_died` grep gate; §4 non-emitter for OTHER 21 GameBus signals grep gate; §5 DI seam test isolation; §6 27 BalanceConstants lint gate (story-001 already shipped); §10 unit_died emission ordering; §11 DoT-killed Commander triggers radius (story-007 already covers); §12 consumer mutation forbidden_pattern documented FAIL-STATE regression; §13 CR-7 mutex enforcement (story-005 already covers). 5 forbidden_patterns: `hp_status_static_var_state_addition` (R-4), `hp_status_consumer_mutation` (R-5), `hp_status_re_entrant_emit_without_deferred` (R-1), `hp_status_signal_emission_outside_domain` (Validation §3 + §4), `hp_status_external_state_mutation` (R-5 extension — external code must not mutate UnitHPState fields directly).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_usec()` for perf measurement (4.0+ stable; replaces deprecated OS.get_ticks_msec). GdUnit4 v6.1.2 perf test pattern from turn-order story-007 + hero-database story-005 (4 perf tests at ×3-25 generous gates over headline budget). Bash lint scripts via `grep` / `awk` (POSIX-portable; CI runs on Linux). `architecture.yaml` forbidden_patterns block append (existing 12-pattern list per architecture-traceability.md v0.4 — adds 5 hp-status patterns to bring total to 17).

**Control Manifest Rules (Core layer + Global)**:
- Required: perf baseline test at `tests/unit/core/hp_status_perf_test.gd` mirroring turn-order story-007 + hero-database story-005 4-test ×3-25 gate pattern; 5 lint scripts at `tools/ci/lint_hp_status_*.sh` exit 0 standalone; `architecture.yaml` forbidden_patterns block append; `.github/workflows/tests.yml` 5 new lint steps inserted in proper positional order (per turn-order story-007 precedent — between hero-database lints and damage-calc fgb_prov_removed lint)
- Forbidden: hardcoded perf budget values in test (read from constants); broken/disabled tests to make CI pass (test-evidence regression)
- Guardrail: all 4 perf tests must pass at the ×3-25 generous gates (3× = 0.15ms for apply_damage; 25× = 1.25ms for get_modified_stat; 10× = 1.0ms for apply_status; 5× = 1.0ms for _apply_turn_start_tick) — these are headless CI gates only; on-device 1ms headline budget per ADR-0010 §Performance is deferred to Polish

---

## Acceptance Criteria

*From GDD AC-20 + ADR-0010 §Performance + Verification + Validation §3/§4/§7/§8/§9/§12 + 5 forbidden_patterns from ADR-0010 R-1/R-4/R-5 + delta-#7 Item 11:*

- [ ] **AC-1** Perf baseline test `tests/unit/core/hp_status_perf_test.gd` ships 4 perf tests measuring `apply_damage` (gate <0.15ms = 3× over 0.05ms headline), `get_modified_stat` (gate <1.25ms = 25× over 0.05ms — generous to absorb GdUnit4 instrumentation overhead per turn-order precedent), `apply_status` (gate <1.0ms = 10× over 0.10ms), `_apply_turn_start_tick` (gate <1.0ms = 5× over 0.20ms). Each test runs 1000 iterations and asserts mean per-iteration time below the gate
- [ ] **AC-2** Lint script `tools/ci/lint_hp_status_static_var_state_addition.sh` enforces R-4: `grep -c '^static var' src/core/hp_status_controller.gd` returns 0; exit 0 only when no static vars exist
- [ ] **AC-3** Lint script `tools/ci/lint_hp_status_consumer_mutation.sh` (R-5 mitigation): scans test files for the documented FAIL-STATE regression pattern (`tests/unit/core/hp_status_consumer_mutation_test.gd` — created in this story). The lint validates the regression test EXISTS as a documented fail-state (NOT a passing protective test); script exit 0 when the documented test is present + has the `# DOCUMENTED FAIL-STATE — convention is sole defense per R-5` header comment
- [ ] **AC-4** Lint script `tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh` enforces R-1: scans `src/core/hp_status_controller.gd` to confirm `GameBus.unit_died.emit(` is NOT followed by synchronous re-entry into `apply_damage` (i.e., no recursive call within the emit call frame). Implementation: AST-style grep for emit followed by within-N-lines apply_damage call; flags as warning (production code is correct; the R-1 constraint is enforced via subscriber-side CONNECT_DEFERRED requirement, not emitter-side mutation prevention). Script exit 0 if no synchronous re-entry pattern detected
- [ ] **AC-5** Lint script `tools/ci/lint_hp_status_signal_emission_outside_domain.sh` enforces Validation §3 + §4: `grep -c 'GameBus\.[a-z_]*\.emit(' src/core/hp_status_controller.gd` finds emit call sites; for each, asserts the signal name is `unit_died` (the only HP/Status emitter signal per ADR-0001 line 155). Any emit site for OTHER signal name (e.g., `GameBus.unit_turn_started.emit` would be wrong — Turn Order owns that) → script exit 1 with line number + signal name. Script exit 0 when only `unit_died` emits exist (≥2 expected: apply_damage Step 4 + DoT-kill branch in `_apply_turn_start_tick`)
- [ ] **AC-6** Lint script `tools/ci/lint_hp_status_external_state_mutation.sh` enforces R-5 extension: scans non-test files in `src/` (excluding `src/core/hp_status_controller.gd` itself) for any pattern accessing `_state_by_unit` field directly (e.g., `controller._state_by_unit[uid].current_hp = X` from a non-test caller). External code MUST go through `apply_damage` / `apply_heal` / `apply_status` mutators only. Script exit 0 when no external `_state_by_unit` access found
- [ ] **AC-7** `architecture.yaml` forbidden_patterns block appended with 5 new entries (`hp_status_static_var_state_addition`, `hp_status_consumer_mutation`, `hp_status_re_entrant_emit_without_deferred`, `hp_status_signal_emission_outside_domain`, `hp_status_external_state_mutation`). Each entry includes pattern name + brief description + source ADR reference (ADR-0010 R-N) + lint script path. Pattern count grows from 17 (turn-order's 6 + others) to 22
- [ ] **AC-8** `.github/workflows/tests.yml` 5 new lint steps inserted between hero-database lints and damage-calc fgb_prov_removed lint per turn-order story-007 positional convention. Each step name: `Lint: hp_status [pattern_short_name]`. Each step runs the corresponding `tools/ci/lint_hp_status_*.sh` script; failure exits CI with non-zero
- [ ] **AC-9** Mirrors GDD AC-20 (counter-attack interaction stub): Validation that DEFEND_STANCE-active unit, when receiving damage, does NOT trigger any HP/Status-side counter-attack signal. AC-20 is mostly a Grid Battle / Damage Calc concern (CR-13 rule 4 enforced there); HP/Status side asserts: source-file scan confirms no `counter_attack_triggered` emit OR call site in `hp_status_controller.gd`; integration test (extends story-003 apply_damage test) verifies that DEFEND_STANCE-active unit receives -50% damage AND no counter-attack code path is activated from HP/Status
- [ ] **AC-10** `tests/unit/core/hp_status_consumer_mutation_test.gd` documented FAIL-STATE regression: test demonstrates that mutating returned `Array[StatusEffect]` from `get_status_effects(unit_id)` IS visible cross-call (proving convention is sole defense per R-5). Test is NOT a passing protective test — it documents the failure mode. Header comment: `# DOCUMENTED FAIL-STATE — convention is sole defense per R-5`. Test asserts: `var effects = _controller.get_status_effects(1); effects[0].remaining_turns = 999; var effects_v2 = _controller.get_status_effects(1); assert effects_v2[0].remaining_turns == 999` — proving the corruption (the 999 mutation persists into the next call). Source comment on `get_status_effects` reinforces "DO NOT MUTATE returned StatusEffect refs"
- [ ] **AC-11** Cross-platform determinism deterministic-fixture test `tests/unit/core/hp_status_determinism_test.gd` ships 1 test that runs a 50-step synthetic battle scenario (init → apply_damage × 10 + apply_heal × 5 + apply_status × 8 + _apply_turn_start_tick × 27 sequence) and asserts the final `current_hp` + `status_effects[]` final state matches a hardcoded macOS-Metal known-good baseline. F-1 / F-2 / F-3 / F-4 use only integer arithmetic + `floor()` + `clamp()` (no float-point math in HP intake — F-2 uses `ceil(max_hp × HEAL_HP_RATIO)` integer-result; F-3 uses `floor(max_hp × DOT_HP_RATIO)` integer-result). Cross-platform identical by construction; test serves as regression guard for any future floating-point introduction
- [ ] **AC-12** 3 TD entries logged in `docs/tech-debt-register.md` per turn-order story-007 precedent: (a) **TD-NNN** — coord_to_unit reverse cache optimization deferred to Polish-tier (per ADR-0010 §11 commentary; reactivation trigger: 32+ unit battles or perf budget exceeded); (b) **TD-NNN+1** — is_morale_anchor field migration to HeroData schema (post-MVP per OQ-2 + ADR-0010 §ADR Dependencies Soft / Provisional (2); reactivation trigger: ADR-0007 amendment OR Battle Preparation ADR landing OR ADR-0014 Scenario Progression authoring); (c) **TD-NNN+2** — on-device perf benchmark (`apply_damage` < 0.05ms, `get_modified_stat` < 0.05ms, `apply_status` < 0.10ms, `_apply_turn_start_tick` < 0.20ms — minimum-spec mobile Adreno 610 / Mali-G57 class; reactivation trigger: first Android export build green AND on-device profiler available; estimated effort 2-3h)
- [ ] **AC-13** Regression baseline maintained: full GdUnit4 suite passes ≥740 cases (story-007 baseline ~730 + ≥10 new; perf tests + consumer-mutation regression + determinism fixture = ~10 new tests) / 0 errors / 0 carried failures / 0 orphans

---

## Implementation Notes

*Derived from ADR-0010 §Performance + Verification + Validation §1-13 + delta-#7 Item 11 + 5 forbidden_patterns from R-1/R-4/R-5 + turn-order story-007 + hero-database story-005 epic terminal precedents:*

1. **Perf test file** `tests/unit/core/hp_status_perf_test.gd`:
   ```gdscript
   class_name HPStatusPerfTest extends GdUnitTestSuite

   const PERF_ITERATIONS := 1000
   const APPLY_DAMAGE_GATE_MS := 0.15  # 3× over 0.05ms headline
   const GET_MODIFIED_STAT_GATE_MS := 1.25  # 25× generous
   const APPLY_STATUS_GATE_MS := 1.0  # 10×
   const TURN_START_TICK_GATE_MS := 1.0  # 5×

   var _controller: HPStatusController
   var _map_grid_stub: MapGridStub

   func before_test() -> void:
       BalanceConstants._cache_loaded = false
       _controller = HPStatusController.new()
       _map_grid_stub = MapGridStub.new()
       _controller._map_grid = _map_grid_stub
       add_child(_controller)
       _controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)

   func test_apply_damage_perf_under_gate() -> void:
       var start := Time.get_ticks_usec()
       for _i in range(PERF_ITERATIONS):
           _controller._state_by_unit[1].current_hp = _controller._state_by_unit[1].max_hp  # reset
           _controller.apply_damage(1, 10, 0, [])
       var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0
       var per_call_ms := elapsed_ms / PERF_ITERATIONS
       assert_float(per_call_ms).is_less(APPLY_DAMAGE_GATE_MS)

   # ... 3 more tests for get_modified_stat, apply_status, _apply_turn_start_tick ...
   ```

2. **Lint script `tools/ci/lint_hp_status_static_var_state_addition.sh`** (R-4):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   COUNT=$(grep -c '^static var' src/core/hp_status_controller.gd || echo 0)
   if [ "$COUNT" != "0" ]; then
       echo "ERROR: hp_status_controller.gd has $COUNT static var declarations; R-4 mitigation forbids static state"
       exit 1
   fi
   echo "PASS: 0 static vars in hp_status_controller.gd"
   ```

3. **Lint script `tools/ci/lint_hp_status_signal_emission_outside_domain.sh`** (Validation §3 + §4):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # Find all GameBus.*.emit( call sites in hp_status_controller.gd
   EMIT_SITES=$(grep -nE 'GameBus\.[a-z_]+\.emit\(' src/core/hp_status_controller.gd || true)
   if [ -z "$EMIT_SITES" ]; then
       echo "ERROR: hp_status_controller.gd has 0 emit call sites; ADR-0010 Validation §3 requires ≥2 (apply_damage Step 4 + DoT-kill branch)"
       exit 1
   fi

   # Verify all emit sites are unit_died (the only HP/Status emitter signal)
   NON_UNIT_DIED=$(echo "$EMIT_SITES" | grep -vE 'GameBus\.unit_died\.emit\(' || true)
   if [ -n "$NON_UNIT_DIED" ]; then
       echo "ERROR: hp_status_controller.gd emits signals OTHER than unit_died:"
       echo "$NON_UNIT_DIED"
       exit 1
   fi

   COUNT=$(echo "$EMIT_SITES" | wc -l | tr -d ' ')
   if [ "$COUNT" -lt 2 ]; then
       echo "ERROR: hp_status_controller.gd has only $COUNT unit_died emit sites; ADR-0010 Validation §3 requires ≥2"
       exit 1
   fi

   echo "PASS: $COUNT unit_died emit sites; no foreign-domain emits"
   ```

4. **Lint script `tools/ci/lint_hp_status_consumer_mutation.sh`** (R-5):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   if [ ! -f "tests/unit/core/hp_status_consumer_mutation_test.gd" ]; then
       echo "ERROR: documented FAIL-STATE regression test missing at tests/unit/core/hp_status_consumer_mutation_test.gd"
       exit 1
   fi

   if ! grep -q '# DOCUMENTED FAIL-STATE' tests/unit/core/hp_status_consumer_mutation_test.gd; then
       echo "ERROR: hp_status_consumer_mutation_test.gd missing required '# DOCUMENTED FAIL-STATE' header comment"
       exit 1
   fi

   echo "PASS: documented FAIL-STATE regression test present"
   ```

5. **Lint script `tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh`** (R-1):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # R-1 is enforced subscriber-side via CONNECT_DEFERRED, not emitter-side. This lint
   # validates that the ADR-0001 §5 mandate documentation is present in the source as
   # a comment header where unit_died.emit is called.
   if ! grep -q 'CONNECT_DEFERRED' src/core/hp_status_controller.gd; then
       echo "WARNING: hp_status_controller.gd missing CONNECT_DEFERRED reference (R-1 mitigation documentation)"
       # Soft-warning only — production code is correct via ADR-0001 mandate; no exit 1
   fi

   # Hard-check: production code must NOT call apply_damage from within unit_died.emit call frame.
   # Heuristic: scan for apply_damage call within 5 lines after unit_died.emit (synchronous re-entry pattern).
   AWK_RESULT=$(awk '/GameBus\.unit_died\.emit\(/{flag=1; line_count=0; next} flag && /apply_damage\(/{print NR": potential synchronous re-entry"; flag=0} flag {line_count++; if(line_count>=5) flag=0}' src/core/hp_status_controller.gd)
   if [ -n "$AWK_RESULT" ]; then
       echo "ERROR: synchronous apply_damage re-entry within unit_died.emit call frame:"
       echo "$AWK_RESULT"
       exit 1
   fi

   echo "PASS: no synchronous re-entry pattern detected"
   ```

6. **Lint script `tools/ci/lint_hp_status_external_state_mutation.sh`** (R-5 extension):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # Find any .gd file in src/ that accesses _state_by_unit, EXCEPT hp_status_controller.gd itself
   VIOLATIONS=$(grep -rEn '_state_by_unit\b' src/ --include='*.gd' | grep -v 'src/core/hp_status_controller.gd' || true)
   if [ -n "$VIOLATIONS" ]; then
       echo "ERROR: external code accesses _state_by_unit directly (R-5 violation):"
       echo "$VIOLATIONS"
       echo "External code MUST use apply_damage / apply_heal / apply_status mutators only."
       exit 1
   fi

   echo "PASS: no external _state_by_unit access"
   ```

7. **`architecture.yaml` forbidden_patterns block append** — 5 new entries:
   ```yaml
     - pattern: hp_status_static_var_state_addition
       description: HPStatusController must not declare `static var` (R-4 mitigation; per-instance state isolation; static-lint check returns 0)
       source_adr: ADR-0010 R-4
       lint_script: tools/ci/lint_hp_status_static_var_state_addition.sh
     - pattern: hp_status_consumer_mutation
       description: Consumer mutation of returned Array[StatusEffect] documented as fail-state per R-5; tests/unit/core/hp_status_consumer_mutation_test.gd present as documented FAIL-STATE regression
       source_adr: ADR-0010 R-5
       lint_script: tools/ci/lint_hp_status_consumer_mutation.sh
     - pattern: hp_status_re_entrant_emit_without_deferred
       description: unit_died emit call frame must not synchronously re-enter apply_damage; subscribers must use Object.CONNECT_DEFERRED per ADR-0001 §5
       source_adr: ADR-0010 R-1
       lint_script: tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh
     - pattern: hp_status_signal_emission_outside_domain
       description: HPStatusController emits ONLY unit_died (ADR-0001 line 155); non-emitter for all OTHER 21 GameBus signals
       source_adr: ADR-0010 Validation §3 + §4
       lint_script: tools/ci/lint_hp_status_signal_emission_outside_domain.sh
     - pattern: hp_status_external_state_mutation
       description: External code must not access HPStatusController._state_by_unit directly; mutators apply_damage / apply_heal / apply_status only (R-5 extension)
       source_adr: ADR-0010 R-5
       lint_script: tools/ci/lint_hp_status_external_state_mutation.sh
   ```

8. **`.github/workflows/tests.yml` 5 new lint steps** — inserted in proper positional order per turn-order story-007 precedent:
   ```yaml
       - name: 'Lint: hp_status no_static_var_state_addition'
         run: bash tools/ci/lint_hp_status_static_var_state_addition.sh
       - name: 'Lint: hp_status consumer_mutation'
         run: bash tools/ci/lint_hp_status_consumer_mutation.sh
       - name: 'Lint: hp_status re_entrant_emit_without_deferred'
         run: bash tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh
       - name: 'Lint: hp_status signal_emission_outside_domain'
         run: bash tools/ci/lint_hp_status_signal_emission_outside_domain.sh
       - name: 'Lint: hp_status external_state_mutation'
         run: bash tools/ci/lint_hp_status_external_state_mutation.sh
   ```
   Insertion point: between hero-database lint steps and damage-calc fgb_prov_removed lint step. Alphabetical/dependency order matches the architectural layer flow.

9. **AC-9 counter-attack interaction stub**: HP/Status side has nothing to implement — ADR-0010 §9 line 410 explicitly states "CR-13 grid-battle.md rule 4 separately enforces 'DEFEND_STANCE units do NOT counter-attack' which is Grid Battle's responsibility, NOT HP/Status's." Story-008's AC-9 verification:
   - source-file scan asserts `grep -c 'counter_attack' src/core/hp_status_controller.gd == 0` (zero references)
   - integration test extends story-003's apply_damage test to verify DEFEND_STANCE-active unit receives -50% damage AND no counter-attack signal/method is invoked from hp_status_controller.gd

10. **Consumer mutation FAIL-STATE regression test** `tests/unit/core/hp_status_consumer_mutation_test.gd`:
    ```gdscript
    # DOCUMENTED FAIL-STATE — convention is sole defense per R-5
    # This test demonstrates that mutating returned Array[StatusEffect] IS visible cross-call.
    # `get_status_effects` returns a shallow Array copy; the StatusEffect Resources INSIDE
    # are SHARED references. Consumer mutation of `effect.remaining_turns` corrupts authoritative state.
    # Mitigation: forbidden_pattern hp_status_consumer_mutation; source comment "DO NOT MUTATE".
    # This test serves as regression guard — if the API is changed to fully duplicate the
    # StatusEffect Resources (deep copy), this test would start failing AND should be UPDATED
    # to assert the new immutability contract.

    class_name HPStatusConsumerMutationTest extends GdUnitTestSuite
    # ... test body proving cross-call corruption ...
    ```

11. **Cross-platform determinism fixture** `tests/unit/core/hp_status_determinism_test.gd`:
    ```gdscript
    class_name HPStatusDeterminismTest extends GdUnitTestSuite

    func test_50_step_synthetic_battle_deterministic() -> void:
        var controller := HPStatusController.new()
        # ... 50-step sequence ...
        # Hardcoded macOS-Metal known-good baseline:
        var expected_unit1_hp: int = 47
        var expected_unit1_status_count: int = 2
        # ... full final-state assertions ...
        assert_int(controller.get_current_hp(1)).is_equal(expected_unit1_hp)
        assert_array(controller.get_status_effects(1)).has_size(expected_unit1_status_count)
    ```
    Baseline values determined empirically by running the test once on macOS-Metal stable; CI verifies bit-identical match across platforms.

12. **3 TD entries** appended to `docs/tech-debt-register.md`:
    ```markdown
    ## TD-NNN: HPStatusController coord_to_unit reverse cache (Polish-tier)
    **Severity**: Low
    **Origin**: hp-status story-007 (`_propagate_demoralized_radius` MapGrid coord scan O(W*H))
    **Owner**: godot-gdscript-specialist at Polish phase
    **Reactivation**: 32+ unit battles OR perf budget exceeded (`_propagate_demoralized_radius` >0.30ms on minimum-spec mobile)
    **Resolution**: cache `coord_to_unit_id: Dictionary[Vector2i, int]` in HPStatusController; rebuild on `unit_turn_started` or via Battle Preparation hook; replaces O(W*H) tile scan with O(1) lookup
    **Cost**: 2-3h
    **References**: ADR-0010 §11 + §Performance; turn-order epic Complete (similar coord-cache pattern)

    ## TD-NNN+1: is_morale_anchor field migration (post-MVP)
    **Severity**: Medium
    **Origin**: ADR-0010 §ADR Dependencies Soft / Provisional (2); GDD CR-6 SE-2 condition (b)
    **Owner**: narrative-director + ai-programmer (Battle Preparation ADR or ADR-0007 amendment)
    **Reactivation**: ADR-0007 amendment OR Battle Preparation ADR OR ADR-0014 Scenario Progression authoring
    **Resolution**: add `is_morale_anchor: bool` field to HeroData (26 → 27 fields); update `_propagate_demoralized_radius` to branch on `state.hero.is_morale_anchor` for condition (b) named-hero death propagation; story migration single-line addition (per ADR-0010 Migration Plan)
    **Cost**: 4-6h (cross-doc impact: HeroData schema + tr-registry update + migration test)
    **References**: ADR-0010 OQ-2; design/gdd/hp-status.md CR-6 SE-2 condition (b); design/gdd/hp-status.md OQ-4 is_morale_anchor criteria

    ## TD-NNN+2: HP/Status on-device perf baseline
    **Severity**: Medium
    **Origin**: hp-status story-008 + ADR-0010 §Performance Polish-deferral pattern (stable at 6+ invocations)
    **Owner**: performance-analyst at Polish phase
    **Reactivation**: first Android export build green AND on-device profiler available
    **Resolution**: measure `apply_damage` / `get_modified_stat` / `apply_status` / `_apply_turn_start_tick` on minimum-spec Adreno 610 / Mali-G57 mobile; assert <0.05ms / <0.05ms / <0.10ms / <0.20ms per ADR-0010 §Performance headline budget; on-device baseline replaces headless CI gate
    **Cost**: 2-3h
    **References**: ADR-0010 §Performance + Validation §8; damage-calc story-010 + hero-database story-005 + turn-order story-007 Polish-deferral precedent
    ```

13. **Test files**:
    - `tests/unit/core/hp_status_perf_test.gd` — 4 perf tests (AC-1)
    - `tests/unit/core/hp_status_consumer_mutation_test.gd` — 1 documented FAIL-STATE regression test (AC-3 + AC-10)
    - `tests/unit/core/hp_status_determinism_test.gd` — 1 cross-platform determinism fixture (AC-11)
    - `tests/unit/core/hp_status_no_counter_attack_test.gd` — 1 integration test for AC-9 counter-attack stub
    Total: ~7 new test functions across 4 files

14. **Lint scripts** (5 files in `tools/ci/`):
    - `lint_hp_status_static_var_state_addition.sh`
    - `lint_hp_status_consumer_mutation.sh`
    - `lint_hp_status_re_entrant_emit_without_deferred.sh`
    - `lint_hp_status_signal_emission_outside_domain.sh`
    - `lint_hp_status_external_state_mutation.sh`

15. **Same-patch obligations to verify resolved**: per ADR-0010 Migration Plan + EPIC.md Same-Patch Obligations:
    - 27 BalanceConstants entries (story-001 ✅)
    - 5 .tres status-effect templates (story-001 ✅)
    - 5+ forbidden_patterns registered (this story ships 5 — verify lint script + architecture.yaml registration + CI wiring)
    - lint_balance_entities_hp_status.sh validation script (story-001 ✅; verify CI wired here)

---

## Out of Scope

*This is the epic terminal — no further hp-status stories follow.*

- Battle Preparation ADR ratification work (`initialize_battle(unit_roster: Array[BattleUnit])` typed-array signature — currently untyped Array per ADR-0010 §From `[no current implementation]`); deferred to Battle Preparation ADR landing
- ADR-0007 `is_morale_anchor` field amendment + `_propagate_demoralized_radius` condition (b) branch (logged as TD-NNN+1)
- On-device perf benchmarking (logged as TD-NNN+2)
- Coord_to_unit reverse cache optimization (logged as TD-NNN)
- AC-20 full counter-attack interaction (Grid Battle / Damage Calc owns; HP/Status side stub verified here)

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1 — 4 perf tests at gates**:
- Given: `tests/unit/core/hp_status_perf_test.gd` exists with 4 perf test functions
- When: each runs 1000 iterations of the target method
- Then: per-call mean time below ×3-25 generous gate (0.15ms / 1.25ms / 1.0ms / 1.0ms respectively); test asserts `is_less(GATE)` against measured ms

**AC-2 — Static-var lint**:
- Given: `tools/ci/lint_hp_status_static_var_state_addition.sh` exists
- When: `bash tools/ci/lint_hp_status_static_var_state_addition.sh` from project root
- Then: exit 0; stdout reports "PASS: 0 static vars in hp_status_controller.gd"
- Edge case: deliberately add `static var foo: int = 0` → script exits 1 with count

**AC-3 — Consumer-mutation regression lint**:
- Given: `tools/ci/lint_hp_status_consumer_mutation.sh` + `tests/unit/core/hp_status_consumer_mutation_test.gd` (with required header comment)
- When: lint script invoked
- Then: exit 0; "PASS: documented FAIL-STATE regression test present"
- Edge case: delete header comment → exit 1; delete test file → exit 1

**AC-4 — Re-entrant emit lint**:
- Given: `tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh` + production hp_status_controller.gd
- When: lint script invoked
- Then: exit 0; no synchronous re-entry pattern detected
- Edge case: deliberately add `apply_damage(2, ...)` 3 lines after `GameBus.unit_died.emit(...)` → script exits 1 with line number

**AC-5 — Signal emission domain lint**:
- Given: `tools/ci/lint_hp_status_signal_emission_outside_domain.sh`
- When: lint invoked
- Then: exit 0; ≥2 unit_died emit sites; no foreign-domain emits
- Edge case: deliberately add `GameBus.unit_turn_started.emit(...)` → script exits 1 with line + signal name

**AC-6 — External state mutation lint**:
- Given: `tools/ci/lint_hp_status_external_state_mutation.sh`
- When: lint invoked
- Then: exit 0; no external `_state_by_unit` access in any non-test src/ file
- Edge case: deliberately add `controller._state_by_unit[1].current_hp = 100` in some other src/ file → script exits 1 with file:line

**AC-7 — architecture.yaml forbidden_patterns growth**:
- Given: `docs/registry/architecture.yaml` post-append
- When: `grep -cE '^  - pattern: hp_status_' docs/registry/architecture.yaml`
- Then: returns 5 (5 hp_status patterns)
- Total pattern count: previous 17 + 5 = 22 (verifiable via `grep -cE '^  - pattern: ' docs/registry/architecture.yaml`)

**AC-8 — CI workflow wiring**:
- Given: `.github/workflows/tests.yml` post-edit
- When: `grep -c "lint_hp_status_" .github/workflows/tests.yml`
- Then: returns 5 (one per lint step)
- Edge case: positional discipline — lint_hp_status_* steps appear AFTER hero-database lint steps and BEFORE damage-calc fgb_prov_removed lint; verifiable via line-number ordering

**AC-9 — No counter-attack code path**:
- Given: hp_status_controller.gd
- When: `grep -c "counter_attack" src/core/hp_status_controller.gd`
- Then: returns 0
- Integration test: DEFEND_STANCE-active unit + apply_damage → verify -50% reduction applied; no counter_attack_triggered signal emitted from HP/Status side; counter-attack interaction is Grid Battle / Damage Calc concern (CR-13 rule 4)

**AC-10 — Documented FAIL-STATE regression test**:
- Given: `tests/unit/core/hp_status_consumer_mutation_test.gd` exists with required header
- When: test runs (it's a passing test that asserts the failure mode IS observable)
- Then: assertions pass — `effects[0].remaining_turns = 999; effects_v2[0].remaining_turns == 999` proves cross-call corruption visible
- Edge case: if `get_status_effects` is changed to deep-copy in the future, this test FAILS → updates the contract assertion

**AC-11 — Cross-platform determinism fixture**:
- Given: 50-step synthetic battle scenario with hardcoded macOS-Metal baseline
- When: deterministic-fixture test runs on any platform (macOS / Linux / Windows headless)
- Then: final state matches baseline bit-identically; integer arithmetic + floor/clamp guarantees cross-platform invariance

**AC-12 — 3 TD entries**:
- Given: `docs/tech-debt-register.md` post-append
- When: `grep -cE '^## TD-' docs/tech-debt-register.md`
- Then: count grew by 3 from prior baseline (e.g., 49 → 52 if prior count was 49 per turn-order story-007's TD-047/048/049)

**AC-13 — Regression baseline**:
- Given: full GdUnit4 suite post-implementation
- When: full-suite headless run
- Then: ≥740 cases / 0 errors / 0 failures / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/core/hp_status_perf_test.gd` — 4 perf tests
- `tests/unit/core/hp_status_consumer_mutation_test.gd` — 1 documented FAIL-STATE regression
- `tests/unit/core/hp_status_determinism_test.gd` — 1 cross-platform determinism fixture
- `tests/unit/core/hp_status_no_counter_attack_test.gd` — 1 AC-20 stub verification
- `tools/ci/lint_hp_status_static_var_state_addition.sh`
- `tools/ci/lint_hp_status_consumer_mutation.sh`
- `tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh`
- `tools/ci/lint_hp_status_signal_emission_outside_domain.sh`
- `tools/ci/lint_hp_status_external_state_mutation.sh`
- `docs/registry/architecture.yaml` (5 forbidden_patterns appended)
- `.github/workflows/tests.yml` (5 lint steps inserted)
- `docs/tech-debt-register.md` (3 TD entries appended)

**Status**: [x] Created 2026-05-02 — 4 test files + 5 lint scripts + 3 doc edits all shipped; full regression 743/0/0/0/0/0 Exit 0; 8th consecutive failure-free baseline

---

## Dependencies

- Depends on: ALL prior stories (001-007). Stories 001-007 must be Complete before this terminal step (lint scripts depend on full production code shape; perf tests require all 8 method bodies; consumer-mutation regression depends on `get_status_effects` returning the documented mutable shape)
- Unlocks: Epic close-out — `production/epics/hp-status/EPIC.md` Status flips to Complete; sprint-3 S3-02 done; Foundation+Core layer count Core 2/4 → 3/4 (only grid-battle remaining among Core slots, but grid-battle is currently classified as Feature in some prose; verify at epic close-out time)
- Note: This story's CI wiring + perf baseline + 5 lint scripts establish the production-readiness gate for the HP/Status epic. Without story-008, the epic ships untested for cross-platform determinism + has no static-analysis enforcement of the 5 R-mitigations.

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 13/13 passing (100% — all auto-verified via test functions, lint script exit codes, and full-suite regression)
**Test Evidence**: Config/Data ADVISORY gate satisfied via OVER-MINIMUM coverage:
  - 4 test files at `tests/unit/core/hp_status_*_test.gd` (perf=8412B / consumer_mutation=5364B / determinism=9204B / no_counter_attack=5782B; total **8 test functions** across 4 files)
  - 5 lint scripts at `tools/ci/lint_hp_status_*.sh` with `chmod +x` (all exit 0 standalone)
  - Full regression **735 → 743 cases / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** ✅ (**8th consecutive failure-free baseline**; entire hp-status chain — stories 1, 2, 3, 4, 5, 6, 7, 8 — ALL green)
**Manifest staleness check**: PASS (story 2026-04-20 = current 2026-04-20)
**Files created (12, ~44 KB total)**:
- 4 test files at `tests/unit/core/hp_status_*_test.gd` (perf + consumer_mutation + determinism + no_counter_attack)
- 5 lint scripts at `tools/ci/lint_hp_status_*.sh` with `chmod +x` (static_var_state_addition + consumer_mutation + re_entrant_emit_without_deferred + signal_emission_outside_unit_died + external_current_hp_write)
**Files edited (3)**:
- `docs/registry/architecture.yaml` — 4 lint_script field appends to existing entries (lines 1143/1151/1159/1167) + 1 new entry `hp_status_re_entrant_emit_without_deferred` at line 1169 (canonical names preserved per Decision A — registry source of truth from ADR-0010 acceptance)
- `.github/workflows/tests.yml` — 5 lint steps inserted at lines 84-92 (between turn-order lints and lint_fgb_prov_removed.sh per Decision C positional convention)
- `docs/tech-debt-register.md` — TD-050 (coord_to_unit cache) + TD-051 (is_morale_anchor migration) + TD-052 (on-device perf baseline) appended (count 49 → 52)
**Deviations**:
- **MINOR (verified BENIGN — strengthening)**: `lint_hp_status_external_current_hp_write.sh` performs TWO scans (1) `_state_by_unit` access in non-controller src/ files per story §6 spec, AND (2) `\.current_hp\s*=` direct-write pattern per arch.yaml line 1147 description. The 2nd scan exceeds story §6 spec but matches canonical arch.yaml entry verbatim — defense-in-depth strengthening that catches `state.current_hp = X` writes even if `_state_by_unit` isn't accessed. Not a violation; a benefit.
- **NAMING DEVIATION (verified canonical)**: 2 of 5 lint script names use canonical arch.yaml pattern names rather than story-008 §AC-7 prose names (`signal_emission_outside_unit_died` not `outside_domain`; `external_current_hp_write` not `external_state_mutation`). Decision A pre-resolved by orchestrator: registry is source of truth (sourced from ADR-0010 acceptance 2026-04-30). Lint scripts and arch.yaml entries are name-aligned; story prose names were aspirational.
**Code review**: APPROVED WITH SUGGESTIONS (lean-mode orchestrator-direct, **13th occurrence**) — 0 required changes; 4 forward-look advisory items captured (S-1 test-factory hoisting STRONGLY ESCALATING at 10 files → eligible for TD-053; S-2 determinism dead-end branch precondition assertion; S-3 re_entrant_emit heuristic boundary codification if false positive ever surfaces; S-6 already addressed via TD-052). 3 prior-story carryovers (S-4 is_morale_anchor, S-5 coord_to_unit cache, plus on-device perf baseline) all RESOLVED via this story's TD-050/051/052.
**Tech debt logged this story**: 3 TD entries appended (TD-050 + TD-051 + TD-052) per AC-12; net new this close-out per S-1 escalation: **TD-053 — test-factory hoisting for hp_status_*_test.gd suite** (10 files now duplicate the `_make_hero` factory; consolidation to `tests/unit/core/hp_status_test_helpers.gd` recommended; ~30min effort; reactivation trigger: any future hp_status test addition pushing to 11 files OR any other Core-layer test suite with similar duplication pressure)
**Engine gotchas applied**: G-9 (paren-wrap concat in `%` strings — every `override_failure_message` formatter), G-15 (canonical `before_test`/`after_test` doubled cache reset across all 4 new test files), G-22 (FileAccess source-scan in `no_counter_attack_test.gd` for AC-9 + indirect via consumer-mutation lint validation), G-24 (paren-wrap `as Type` casts in `==` expressions — applied where applicable). NONE encountered new — all proactive applications from established patterns.
**Pattern reinforcement codified this story**:
- **Lean-mode review precedent firmly stable at 13 occurrences** — orchestrator-direct /code-review without specialist Task spawn; no quality regressions detected across 13 occurrences. Pattern is the project default.
- **Multi-spawn-on-scale precedent established for Config/Data stories**: story-008's 12-file deliverable bundle exceeded single-agent-context threshold; agent ran for ~680s total across 3 invocations (initial spawn → 2 SendMessage continuations). Codify: ≤5 file deliverables = 1 spawn; 6-12 file deliverables = 1-2 SendMessage continuations expected; >12 files = pre-plan multi-spawn split.
- **Pre-resolved coordination decisions stable at 4+ occurrences** — Decision A (canonical-name preservation when story prose differs from registry), Decision B (TD-NNN sequential numbering), Decision C (positional CI step insertion), Decision D-F (style/path/factory). Codify as standing /dev-story prompt-construction discipline for any story whose deliverables touch a pre-registered registry (architecture.yaml, tr-registry.yaml, etc.) — orchestrator must explicitly resolve canonical-vs-story-prose conflicts in the spawn prompt.
**Sprint impact**: hp-status epic **8/8 stories Complete** ✅ — **EPIC TERMINAL CLOSED**. S3-02 must-have done. Sprint-3 day ~0-1 of 7. 735 → 743 baseline (+8). **8th consecutive failure-free baseline** since story-001.
