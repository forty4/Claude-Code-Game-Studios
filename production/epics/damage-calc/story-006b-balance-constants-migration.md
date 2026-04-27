# Story 006b: BalanceConstants wrapper + entities.yaml scaffolding + migrate hardcoded constants from stories 004/005/006 + AC-DC-48 grep gate

> **Epic**: damage-calc
> **Status**: Complete (2026-04-27)
> **Layer**: Feature
> **Type**: Logic (with Config/Data scope for entities.yaml authoring)
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (BalanceConstants wrapper + entities.yaml authoring + migrate 12 constants from stories 004/005/006 + AC-DC-48 grep gate + live-registry-read mock test + 6 ACs — focused tech-debt-discharge story)
> **Origin**: split from original story-006 via /story-readiness 2026-04-26. Original story-006 bundled Stage 3-4 implementation with the BalanceConstants migration; the migration was extracted to its own story for cleaner review surface and faster vertical-slice unblock. Story 006 (Stage 3-4 + N-1 fix + AC-DC-51) ships first; this story discharges the deferred-constants tech debt accumulated across stories 004/005/006.

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-006` (tuning constants in `entities.yaml` only)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc (§6 Tuning Constants — `entities.yaml` Only) + ADR-0008 Terrain Effect (provisional-wrapper precedent — `terrain_config.json` + thin `TerrainConfig` wrapper)
**ADR Decision Summary**: Per ADR-0012 §6, all 11+ damage-calc tuning constants live in `entities.yaml` (post-ADR-0006 ratification) or are read via a thin provisional `BalanceConstants` wrapper (until ADR-0006 lands). Stories 004/005/006 hardcoded these constants under `TODO(story-006/006b)` blocks because the wrapper and yaml file did not yet exist. This story builds them — mirroring ADR-0008's `TerrainConfig` precedent (PR #38, terrain-effect epic story-001).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `FileAccess.get_file_as_string(path)` (Godot 4.x stable) for yaml read; YAML parsing via Godot's `JSON.parse_string()` — wait, YAML is NOT JSON. **Pre-resolved decision**: per ADR-0008's terrain_config.json precedent, the actual file format is **JSON, not YAML**, despite the historical name "entities.yaml" used throughout damage-calc.md and ADR-0012. Two options:
  1. Author the file as `assets/data/balance/entities.json` (matches Godot-native JSON parser; matches ADR-0008 pattern)
  2. Author as `entities.yaml` and add a YAML parser dependency (rejected — adds a dependency for a single use case; ADR-0008 chose JSON for the same reason)

Recommended: **Option 1** — file is `entities.json`. Update damage-calc.md GDD references in a follow-up cleanup PR or as part of this story's PR description. The `BalanceConstants` wrapper exposes `get_const(key: String) -> Variant` (typed by caller); internal load path is `JSON.parse_string()`.

**Control Manifest Rules (Feature layer)**:
- Required: `BalanceConstants` is `class_name BalanceConstants extends RefCounted` (stateless static class, mirrors `DamageCalc` shape per ADR-0012 §1)
- Required: All damage_calc.gd constant references migrated from `const X: TYPE = literal` to `BalanceConstants.get_const("X")` calls — either at static-init time (cached) or per-resolve (re-read each call)
- Required: AC-DC-48 grep gate enforced in CI: `damage_calc.gd` contains 0 hardcoded literal matches for the 12 constants
- Forbidden: Hardcoded literal floats `1.20`, `1.15`, `1.31`, `0.40`, `0.5`, or hardcoded ints `83`, `200`, `105`, `180`, `1` (in const-RHS position) anywhere in `damage_calc.gd`
- Forbidden: New `signal` declarations or `connect()` calls in `damage_calc.gd` (AC-DC-34 already enforced from story-006)

---

## Acceptance Criteria

*From `damage-calc.md` §Tuning Knobs + ADR-0012 §6 + AC-DC-48:*

- [ ] **AC-DC-48 (TUNING knobs from registry)**: `grep` for any of {`1\.20`, `1\.15`, `1\.31`, `0\.40`, `0\.5`, ` 83`, ` 200`, ` 105`, ` 180`} in `damage_calc.gd` const-RHS position returns 0 matches; integrated as CI lint step in `.github/workflows/tests.yml`
- [ ] **AC-1 (BalanceConstants wrapper exists)**: `src/feature/balance/balance_constants.gd` declares `class_name BalanceConstants extends RefCounted` with public static method `get_const(key: String) -> Variant`. Public surface ≤ 2 functions (`get_const` + optional `_load_cache` private helper).
- [ ] **AC-2 (entities.json scaffolded with all 12 constants)**: `assets/data/balance/entities.json` contains keys for all hardcoded constants currently in damage_calc.gd: `BASE_CEILING=83`, `MIN_DAMAGE=1`, `ATK_CAP=200`, `DEF_CAP=105`, `DEFEND_STANCE_ATK_PENALTY=0.40`, `P_MULT_COMBINED_CAP=1.31`, `CHARGE_BONUS=1.20`, `AMBUSH_BONUS=1.15`, `DAMAGE_CEILING=180`, `COUNTER_ATTACK_MODIFIER=0.5`, plus the `BASE_DIRECTION_MULT` and `CLASS_DIRECTION_MULT` tables (as nested JSON dicts).
- [ ] **AC-3 (damage_calc.gd migrated)**: every `const X: TYPE = literal` for the 12 constants in `damage_calc.gd` is replaced with a `BalanceConstants.get_const("X")` call (or a one-time cached read at module-load time via `static var` populated from a `_static_init()`-style pattern). The static const declarations are removed; the `TODO(story-006)` and `TODO(story-006b)` comments are deleted; the literal values exist only in `entities.json`.
- [ ] **AC-4 (live-registry-read test)**: unit test mocks `BalanceConstants.get_const("CHARGE_BONUS")` to return `1.30` (instead of the entities.json value `1.20`); runs the D-3 fixture (Cavalry REAR Charge ATK=80 DEF=50); asserts `result.resolved_damage` differs from the no-mock baseline by exactly the expected delta (`floori(30×1.64×1.30) − floori(30×1.64×1.20) = 63 − 59 = 4` more damage; or whatever the direct calculation yields when the live mock fires). This proves the `damage_calc.gd` reads through the wrapper at runtime — not a parse-time literal cache.
- [ ] **AC-5 (no regressions)**: full damage_calc unit suite (post-story-006 = ~46+ tests) PASSES unchanged after migration. Every existing AC value (D-1 through D-9 + apex 178 + AC-DC-N1 + AC-DC-51 + all evasion/invariant guards) produces identical output. This is the canonical regression check that the migration is byte-equivalent.
- [ ] **AC-6 (grep test for `int(` literal still passes)**: no `int(` substring introduced anywhere in `damage_calc.gd` or `balance_constants.gd` doc-comments / code (F-1 grep-policy Option 1 — parity with stories 004/005/006).

---

## Implementation Notes

*Derived from ADR-0008 TerrainConfig precedent + ADR-0012 §6 + ADR-0012 §8 provisional-wrapper pattern:*

- **`BalanceConstants` wrapper shape** (mirror ADR-0008 `TerrainConfig`):
  ```gdscript
  ## Provisional balance-data wrapper. Reads constants from
  ## `assets/data/balance/entities.json` until ADR-0006 ratifies the registry pattern.
  ## Migration trigger: ADR-0006 Accepted → swap _load_cache() to call
  ## DataRegistry.get_const() with same call-site signature.
  class_name BalanceConstants extends RefCounted

  const _ENTITIES_JSON_PATH: String = "res://assets/data/balance/entities.json"
  static var _cache: Dictionary = {}
  static var _cache_loaded: bool = false

  static func get_const(key: String) -> Variant:
      if not _cache_loaded:
          _load_cache()
      if not _cache.has(key):
          push_error("BalanceConstants.get_const: unknown key '%s' (entities.json missing this entry?)" % key)
          return null
      return _cache[key]

  static func _load_cache() -> void:
      var raw: String = FileAccess.get_file_as_string(_ENTITIES_JSON_PATH)
      var parsed: Variant = JSON.parse_string(raw)
      if parsed is Dictionary:
          _cache = parsed
      else:
          push_error("BalanceConstants._load_cache: parse failed for %s" % _ENTITIES_JSON_PATH)
      _cache_loaded = true
  ```
  Test-mock pattern: per AC-4, tests stub `_cache_loaded = true` + `_cache = {custom mock dict}` directly via `(load(PATH) as GDScript).set("_cache", ...)` (autoload-stub-style override).

- **`entities.json` initial content**:
  ```json
  {
      "BASE_CEILING": 83,
      "MIN_DAMAGE": 1,
      "ATK_CAP": 200,
      "DEF_CAP": 105,
      "DEFEND_STANCE_ATK_PENALTY": 0.40,
      "P_MULT_COMBINED_CAP": 1.31,
      "CHARGE_BONUS": 1.20,
      "AMBUSH_BONUS": 1.15,
      "DAMAGE_CEILING": 180,
      "COUNTER_ATTACK_MODIFIER": 0.5,
      "BASE_DIRECTION_MULT": {"FRONT": 1.00, "FLANK": 1.20, "REAR": 1.50},
      "CLASS_DIRECTION_MULT": {
          "0": {"FRONT": 1.00, "FLANK": 1.05, "REAR": 1.09},
          "1": {"FRONT": 1.00, "FLANK": 1.00, "REAR": 1.00},
          "2": {"FRONT": 0.90, "FLANK": 1.00, "REAR": 1.00},
          "3": {"FRONT": 1.00, "FLANK": 1.375, "REAR": 1.00}
      }
  }
  ```
  Note: JSON object keys are strings, so `CLASS_DIRECTION_MULT` outer keys become string-keyed `"0"`/`"1"`/etc. The wrapper or the call site must handle the string→int coercion (or change `CLASS_DIRECTION_MULT` lookup in `damage_calc.gd` to use string keys). Recommended: change `damage_calc.gd` to use `str(unit_class)` at the lookup site — the conversion is one extra step but keeps the JSON file readable and avoids a wrapper-internal int-key remapping.

- **`damage_calc.gd` migration shape**:
  ```gdscript
  # Before (current state, post-story-005/006):
  const CHARGE_BONUS: float = 1.20
  ...
  func _charge_factor(...) -> float:
      ...
      return CHARGE_BONUS

  # After:
  static func _charge_factor(...) -> float:
      ...
      return BalanceConstants.get_const("CHARGE_BONUS") as float
  ```
  Or, if per-call lookup is too verbose, cache once at module-init (acceptable but be careful — `static var` initialization order in GDScript can be fragile across hot-reloads). Per-call read is simpler and the perf cost is negligible (Dictionary lookup + cast = nanoseconds; resolve() runs <1ms per ADR-0012 §Performance Implications).

- **Test cleanup**: existing test files (`damage_calc_test.gd`, `wrapper_classes_test.gd`) need NO test logic changes — they test the resolve() output values, which stay byte-identical. The only test-file impact is potentially adding `before_test()` calls to `BalanceConstants._load_cache()` if explicit cache priming is needed (it shouldn't be; the lazy-load on first `get_const()` call should fire transparently).

- **AC-DC-48 grep gate** integrated as CI lint step in `.github/workflows/tests.yml`:
  ```yaml
  - name: Lint - no hardcoded balance constants in damage_calc.gd (AC-DC-48)
    run: |
      ! grep -nE "const (BASE_CEILING|MIN_DAMAGE|ATK_CAP|DEF_CAP|DEFEND_STANCE_ATK_PENALTY|P_MULT_COMBINED_CAP|CHARGE_BONUS|AMBUSH_BONUS|DAMAGE_CEILING|COUNTER_ATTACK_MODIFIER|BASE_DIRECTION_MULT|CLASS_DIRECTION_MULT) " src/feature/damage_calc/damage_calc.gd
  ```

- **`int(` grep policy carryover (F-1 Option 1)**: this story adds a new file (`balance_constants.gd`) and modifies an existing one (`damage_calc.gd`). The AC-10 grep test from story-004 only checks `damage_calc.gd`. **Decision pending qa-lead at story-007 readiness**: should AC-10 grep extend to the entire `src/feature/damage_calc/` and `src/feature/balance/` trees, or remain scoped to `damage_calc.gd`? For this story: avoid the literal `int(` substring in both files as a defensive measure.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006 (Stage 3-4 implementation) — must complete BEFORE this story (006b depends on 006)
- Story 007: F-GB-PROV retirement + entities.json damage_resolve registration + Grid Battle integration (story-007 will ADD the `damage_resolve` schema entry to the same `entities.json` file this story creates)
- Story 008: AC-DC-39/41/49/50 — RNG replay determinism, Dictionary-alloc lint, engine-pin tests
- Story 009: AC-DC-45/46/47 accessibility UI tests
- Story 010: AC-DC-40(a)/(b) performance baseline (perf will benchmark against the migrated wrapper-read constants — small per-call overhead is acceptable per ADR-0012 §Performance Implications)
- ADR-0006 (Balance/Data) ratification — backlog Nice-to-Have S1-09; the provisional wrapper pattern is API-stable for future ADR-0006 swap

---

## QA Test Cases

*Authored from ADR-0012 §6 + AC-DC-48 + the migration-as-byte-equivalent contract.*

- **AC-1 (AC-DC-48 grep gate)**:
  - Given: completed damage_calc.gd post-migration
  - When: CI runs `grep -E "const (BASE_CEILING|MIN_DAMAGE|...) " damage_calc.gd`
  - Then: 0 matches; CI step fails the build if matches found

- **AC-2 (BalanceConstants wrapper construction)**:
  - Given: fresh test environment, BalanceConstants module loaded
  - When: `BalanceConstants.get_const("CHARGE_BONUS")` called
  - Then: returns `1.20` (typed `float`); subsequent calls return cached value (no re-parse)

- **AC-3 (entities.json schema)**:
  - Given: `assets/data/balance/entities.json` exists
  - When: parsed via `JSON.parse_string`
  - Then: returns `Dictionary` with all 12 keys present; values match the literals from stories 004/005/006

- **AC-4 (live-registry-read mock test)**:
  - Given: BalanceConstants._cache mocked to return 1.30 for "CHARGE_BONUS" (instead of 1.20); D-3 fixture (Cavalry REAR Charge ATK=80 DEF=50, charge_active=true, passive_charge, no rally, no formation, no defend_stance, FRONT direction → wait, D-3 is REAR). Re-confirm D-3: Cavalry REAR Charge ATK=80 DEF=50.
  - When: `DamageCalc.resolve(atk, def, mod)` runs
  - Then: result.resolved_damage = `floori(30 × 1.64 × 1.30) = floori(63.96) = 63` (vs unmocked = 59). Delta = +4. Pins live-registry-read contract (proves no parse-time literal caching).

- **AC-5 (full regression)**:
  - Given: all 46+ damage_calc unit tests + wrapper_classes tests
  - When: full test suite runs post-migration
  - Then: 0 errors / 0 failures / 0 orphans / exit 0; every test value byte-identical to the pre-migration baseline

- **AC-6 (no `int(` substring)**:
  - Given: post-migration `damage_calc.gd` AND new `balance_constants.gd`
  - When: `grep "int(" src/feature/damage_calc/damage_calc.gd src/feature/balance/balance_constants.gd`
  - Then: 0 matches in both files

- **AC-7 (CLASS_DIRECTION_MULT JSON-string-key handling)**:
  - Given: entities.json loaded with `"CLASS_DIRECTION_MULT": {"0": {...}, "1": {...}, ...}`
  - When: `_direction_multiplier(unit_class=0, direction_rel=&"FRONT")` called
  - Then: returns `1.00` (the string-key `"0"` lookup resolves to the inner dict; the wrapper or the lookup site converts `unit_class` int → `str(unit_class)`); regression test ensures all 4 classes still produce expected D_mult values across all 3 directions

---

## Test Evidence

**Story Type**: Logic (with Config/Data scope for entities.json)
**Required evidence**:
- `tests/unit/damage_calc/damage_calc_test.gd` — full regression must pass (no test logic changes; existing 46+ tests continue)
- `tests/unit/balance/balance_constants_test.gd` — NEW test file for wrapper unit tests (AC-1, AC-2, AC-3 above)
- `assets/data/balance/entities.json` — NEW data file (Config/Data evidence)
- CI workflow includes AC-DC-48 grep gate as a blocking lint step

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (Stage 3-4 must complete first; 006b migrates the constants from a stable `damage_calc.gd` post-Stage-3-4)
- Unlocks: Story 007 (Grid Battle integration shares `entities.json` for `damage_resolve` schema entry — story-007 ADDS to the file 006b creates) + Story 010 (perf baseline benchmarks against migrated wrapper-read overhead) + ADR-0006 ratification (when ADR-0006 lands, BalanceConstants internals swap to DataRegistry.get_const() — call sites unchanged)

---

## Completion Notes

**Completed**: 2026-04-27
**PR**: [#65](https://github.com/forty4/Claude-Code-Game-Studios/pull/65) (commit `f40e709` on main)
**Verdict**: COMPLETE WITH NOTES
**Effort**: ~3.5h actual vs 3-4h estimate (within range)
**Criteria**: 8/8 PASS (AC-DC-48, AC-1..AC-7), 0 deferred, 0 failed

### Files delivered (10)

| File | Change | Description |
|---|---|---|
| `src/feature/balance/balance_constants.gd` | NEW (~91 LoC) | `class_name BalanceConstants extends RefCounted`. Lazy-loaded static cache, public `get_const(key) -> Variant`, push_error on missing key + parse failure |
| `src/feature/balance/balance_constants.gd.uid` | NEW (auto) | Godot 4.x stable resource ID |
| `assets/data/balance/entities.json` | NEW (621 bytes) | All 12 tuning constants (10 scalars + 2 dict tables; CLASS_DIRECTION_MULT outer keys stringified per JSON requirement) |
| `tests/unit/balance/balance_constants_test.gd` | NEW (~245 LoC, 7 functions) | Wrapper unit tests: lazy-load, cache stability, all 12 keys, dict-key handling, unknown-key null return, **GAP-1 stable-empty-cache contract** (added inline during /code-review), AC-7 string-key handling |
| `tests/unit/balance/balance_constants_test.gd.uid` | NEW (auto) | |
| `tools/ci/lint_damage_calc_no_hardcoded_constants.sh` | NEW | AC-DC-48 grep lint script (mirrors existing 3 lint script shapes) |
| `src/feature/damage_calc/damage_calc.gd` | M (-105/+22 net) | All 12 const declarations removed; per-call `BalanceConstants.get_const("X") as TYPE` reads at every call site; PASSIVE_CHARGE/PASSIVE_AMBUSH preserved as const StringName; `str(unit_class)` at CLASS_DIRECTION_MULT lookup |
| `tests/unit/damage_calc/damage_calc_test.gd` | M (+115/-2) | before_test/after_test BalanceConstants cache reset; AC-4 mock test (`test_ac4_live_registry_read_mock_charge_bonus_returns_63` — mocked CHARGE_BONUS=1.30 → resolved=63 vs unmocked 59 = +4 delta); AC-4b unmocked baseline (after-mock bleed-through canary; cross-reference comment to `test_stage_2_cavalry_rear_charge_primary_returns_59` per /code-review GAP-2) |
| `.github/workflows/tests.yml` | M (+3) | AC-DC-48 lint step after the 3 existing damage-calc lint steps |
| `design/gdd/damage-calc.md` | M (38 line changes) | Find/replace `entities.yaml` → `entities.json` (doc-drift cleanup) |

### AC coverage (8/8)

| AC | Evidence |
|---|---|
| AC-DC-48 | `tools/ci/lint_damage_calc_no_hardcoded_constants.sh` (exit 0) + CI step |
| AC-1 | `balance_constants.gd` — class_name + 1 public function (`get_const`) |
| AC-2 | `balance_constants_test.gd::test_get_const_all_scalar_keys_return_expected_values` (10 scalars) + `test_get_const_direction_mult_keys_return_dictionaries` (BASE/CLASS dicts) |
| AC-3 | All 12 const declarations removed; AC-DC-48 grep returns 0 |
| AC-4 | `damage_calc_test.gd::test_ac4_live_registry_read_mock_charge_bonus_returns_63` + `test_ac4b_unmocked_baseline_cavalry_rear_charge_returns_59` |
| AC-5 | Full suite **361/361 PASS**, 0 errors / 0 failures / 0 flaky / 0 orphans, exit 0 |
| AC-6 | grep `int(` = 0 in both `damage_calc.gd` and `balance_constants.gd` |
| AC-7 | `balance_constants_test.gd::test_get_const_class_direction_mult_all_classes_all_directions` (4 classes × 3 directions = 12 cases) |

### Code review (lean dual)

- **godot-gdscript-specialist**: APPROVED WITH SUGGESTIONS (3 suggestions + 3 nits, 0 blockers)
- **qa-tester**: TESTABLE WITH GAPS (3 GAPs + 4 suggestions, 0 blockers)
- **4 inline fixes applied before commit**:
  1. GAP-1: stable-empty-cache contract test added (`balance_constants_test.gd::test_get_const_stable_empty_cache_after_failure_returns_null_no_reparse`)
  2. GAP-2: AC-4b cross-reference comment added (intentional duplicate of `test_stage_2_cavalry_rear_charge_primary_returns_59`; do not consolidate)
  3. N-2: `balance_constants.gd` push_error message includes `type_string(typeof(parsed))` for diagnostics
  4. balance_constants_test.gd:96-98: misleading "Tolerance=0 for int-typed values" comment corrected

### Deviations (advisory; none blocking)

1. **Perf optimization deferred** — gdscript S-1 + S-2: per-call dict-fetch redundancy (CLASS_DIRECTION_MULT 2× per `resolve()`; MIN_DAMAGE 3× per counter path). Defer to story-010 perf baseline. Within ADR-0012 §Performance budget (Dictionary lookup is nanoseconds; story spec acknowledges <1ms per resolve()).
2. **`entities.json` key naming DRIFT** — keys use UPPER_SNAKE_CASE matching GDScript const names (`BASE_CEILING`, `CHARGE_BONUS`, etc.); conflicts with `.claude/rules/data-files.md:12` (mandates camelCase). Naming choice is intentional (1:1 mirror of GDScript constants for grep + cognitive mapping at every call site). Recommendation: rule-file exception over implementation change. Track for resolution alongside ADR-0006 ratification or follow-up rule update.
3. **Filename DRIFT** — `entities.json` doesn't match `[system]_[name]` pattern from `data-files.md:8` (would be `balance_entities.json`). Per ADR-0012 §6 + GDD wording mandate. Same reconciliation path as #2.

### Verification (final, all green)

- Full GdUnit4 suite: **361/361 PASS** (was 360 + 1 new GAP-1 test), 0 errors / 0 failures / 0 flaky / 0 orphans, exit 0
- 4 CI lints (AC-DC-33/34/35 existing + AC-DC-48 new): all exit 0
- F-1 grep `int(` in damage_calc.gd / balance_constants.gd: 0 / 0
- AC-DC-N1 grep `as ResolveResult.AttackType`: 0 (story-006 still clean)
- GDD `entities.yaml` substring: 0 (doc cleanup verified)
- CI on PR #65: GdUnit4 (Godot 4.6) SUCCESS, macOS Metal SUCCESS, gdunit4-report SUCCESS

### Tech debt logged

None new. Two ADVISORY items above (perf + naming DRIFT) are tracked in this section for visibility but not registered separately in `docs/tech-debt-register.md` — they're best resolved as part of the natural ADR-0006 ratification cycle (when DataRegistry lands) and a `data-files.md` rule update (which would naturally cover both #2 and #3).

### Vertical-slice progress

**6.5/7 done** (was 6/7). Story-007 (F-GB-PROV retirement + Grid Battle integration) is the final story for first-playable damage roll demo.

### Cumulative damage-calc epic progress

7/11 stories complete on origin/main: 001 ✓ PR #52, 002 ✓ PR #54, 003 ✓ PR #56, 004 ✓ PR #59, 005 ✓ PR #61, 006 ✓ PR #64, **006b ✓ PR #65 (this story)**.
