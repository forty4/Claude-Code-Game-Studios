# Story 007: max_defense_reduction + max_evasion shared accessors

> **Epic**: terrain-effect
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 1-1.5 hours (2 trivial accessors + 4 unit tests covering defaults / config-override / lazy-load / config-driven cap propagation)
> **Actual**: ~1.5 hours (implementation 30min — first fully clean dev-story in epic, no mid-implementation fixes; /code-review with 4 inline enhancements 30min; /story-done bookkeeping 30min)

## Context

**GDD**: `design/gdd/terrain-effect.md` §CR-3a/b (cap ownership) + §Tuning Knobs TK-1, TK-2 + `damage-calc.md` §F (cross-system contract) + `formation-bonus.md` §F-FB-1 (shared cap consumer)
**Requirement**: `TR-terrain-effect-017` (single source of truth for shared cap)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: `MAX_DEFENSE_REDUCTION = 30` and `MAX_EVASION = 30` are owned by Terrain Effect per GDD line 267-271. Two static accessors `max_defense_reduction()` and `max_evasion()` give Formation Bonus + Damage Calc a single source of truth — cap value lives in `terrain_config.json` and propagates to all consumers via these methods. Compile-time defaults in const + runtime overrides from config (ADR-0008 §Decision 7 lines 336-359).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Two trivial getters with lazy-load triggers. No allocation, no Resource construction, no MapGrid interaction. ~1µs per call. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: `max_defense_reduction()` and `max_evasion()` are the ONLY way Formation Bonus + Damage Calc may obtain the cap value — no hardcoded `30` allowed in consumer code (this rule is enforced by code review at consumer-epic time, not by this epic; here we provide the accessors)
- Required: both accessors lazy-trigger `load_config()` if `_config_loaded == false` — Formation Bonus / Damage Calc may call before any other Terrain Effect query has run
- Forbidden: returning the compile-time const directly bypassing the runtime-loaded value — `MAX_DEFENSE_REDUCTION_DEFAULT` is the fallback when no config loaded; `_max_defense_reduction` is the runtime-effective value

---

## Acceptance Criteria

*From ADR-0008 §Decision 7 + §GDD Requirements TR-017 + cross-system contracts in damage-calc.md §F + formation-bonus.md §F-FB-1:*

- [ ] `static func max_defense_reduction() -> int` declared on `TerrainEffect`; lazy-triggers `load_config()` if `_config_loaded == false`; returns `_max_defense_reduction`
- [ ] `static func max_evasion() -> int` declared on `TerrainEffect`; lazy-triggers `load_config()` if `_config_loaded == false`; returns `_max_evasion`
- [ ] After default config load: `max_defense_reduction() == 30`, `max_evasion() == 30`
- [ ] After tuned config load (e.g., `caps.max_defense_reduction: 25`, `caps.max_evasion: 35`): accessors return the tuned values
- [ ] Both accessors trigger lazy load INDEPENDENTLY — calling `max_defense_reduction()` first then `max_evasion()` results in only ONE `load_config()` call total (idempotent guard pinned in story-002)
- [ ] Compile-time consts `MAX_DEFENSE_REDUCTION_DEFAULT` and `MAX_EVASION_DEFAULT` accessible without triggering load_config (they are class-scope constants, not query-time values) — used by Formation Bonus when bootstrapping ahead of any Terrain Effect activity
- [ ] Source-file header doc-comment for `terrain_effect.gd` updated to reference the cross-system shared-cap contract: "Formation Bonus and Damage Calc MUST call `TerrainEffect.max_defense_reduction()` for the shared cap. The compile-time const is the bootstrap fallback; the runtime value (after `load_config`) is authoritative."

---

## Implementation Notes

*Derived from ADR-0008 §Decision 7 (lines 336-359):*

- **The reference implementation (verbatim from ADR §Decision 7)**:
  ```gdscript
  static func max_defense_reduction() -> int:
      if not _config_loaded:
          load_config()
      return _max_defense_reduction

  static func max_evasion() -> int:
      if not _config_loaded:
          load_config()
      return _max_evasion
  ```
- **Why static accessors and not direct const access**: Damage Calc + Formation Bonus need the RUNTIME-EFFECTIVE cap, which may differ from compile-time defaults if the config tunes them. The const `MAX_DEFENSE_REDUCTION_DEFAULT` is a bootstrap fallback for cases where Terrain Effect cannot be loaded (extreme failure), but the canonical accessor is the static method.
- **Cross-system convention**: Formation Bonus + Damage Calc call these accessors at use-time (per stack-frame, not cached). The cost is ~1µs (Dictionary lookup of static var) — well within any consumer's budget. If a future profile shows hot-path significance, the accessor result can be cached at the consumer side per battle round (after `round_started`).
- **No setter accessors** — the cap values are loaded from config only; consumers cannot mutate them at runtime. Tests that need different cap values must use `reset_for_tests()` + `load_config(custom_path)` per the established discipline.
- **Both accessors trigger the SAME `load_config` call**: the idempotent guard in story-002 means the second accessor (called after the first) finds `_config_loaded == true` and skips. Only one parse happens per session.
- **Header doc-comment update is part of this story** — Formation Bonus + Damage Calc readers need to know the shared-cap contract pattern; centralize it in the source file's header rather than scattering across consumer epics.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001-006: Resource classes + skeleton + config loading + queries + cost_multiplier
- Story 008: AC-21 perf benchmark
- Formation Bonus consumer-side adoption of `max_defense_reduction()` — owned by Formation Bonus epic when it lands; this story provides the accessor only
- Damage Calc consumer-side adoption — owned by Damage Calc Feature epic
- The runtime cap clamp itself (applied inside `get_combat_modifiers`) — owned by story-005

---

## QA Test Cases

*Authored from ADR-0008 §Decision 7 + cross-system contracts directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Default config load yields cap = 30 from both accessors
  - Given: `reset_for_tests`; `load_config()` (default fixture)
  - When: `TerrainEffect.max_defense_reduction()` and `TerrainEffect.max_evasion()`
  - Then: both return `30`
  - Edge cases: this is the canonical-defaults baseline; other tests verify the data-driven override path

- **AC-2** (TR-017): Tuned config caps propagate through accessors
  - Given: a test fixture with `caps.max_defense_reduction: 25`, `caps.max_evasion: 35`; reset + load_config(test_path)
  - When: both accessors called
  - Then: `max_defense_reduction() == 25`, `max_evasion() == 35`
  - Edge cases: verifies AC-19 data-driven promise at the cap level + the runtime-vs-compile-time distinction in ADR-0008 §Decision 7

- **AC-3**: Lazy-init triggers load_config on first accessor call
  - Given: `reset_for_tests` (so `_config_loaded == false`); no other queries called
  - When: `max_defense_reduction()` called
  - Then: `_config_loaded == true` after; returns `30` (default config)
  - Edge cases: parallel of stories 004/005/006 lazy-init tests; both accessors must independently trigger

- **AC-4**: Idempotent — second accessor call after first does NOT re-parse
  - Given: `reset_for_tests`; `max_defense_reduction()` called once (triggers load)
  - When: `max_evasion()` called second
  - Then: returns correctly (`30`); `_config_loaded` remains `true`; no second parse occurs (verify via parse-count counter or by mutating `_max_defense_reduction = 99` between calls and confirming the second accessor doesn't reset it)
  - Edge cases: this confirms the idempotent guard from story-002 AC-6 holds when accessors interact

- **AC-5**: Compile-time consts accessible without triggering load_config
  - Given: `reset_for_tests` (so `_config_loaded == false`); fresh state
  - When: `var d := TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT`; `var e := TerrainEffect.MAX_EVASION_DEFAULT`
  - Then: both return `30`; `_config_loaded == false` STILL (const access doesn't trigger lazy load)
  - Edge cases: this is the bootstrap-fallback path — Formation Bonus may need the compile-time default before any battle / config load has happened

- **AC-6** (Cross-system contract documentation): Source file header documents the shared-cap convention
  - Given: `src/core/terrain_effect.gd` opened
  - When: header doc-comment read
  - Then: contains references to (a) Formation Bonus + Damage Calc as consumers, (b) the static-accessor convention, (c) the compile-time-vs-runtime distinction
  - Edge cases: doc-level — manual verification at `/code-review` time; this is the convention's centralized landing point

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/terrain_effect_caps_test.gd` — must exist and pass (6 tests covering AC-1..6; AC-6 doc-level)
- This story's tests also implicitly re-verify the multi-suite isolation discipline established in story-002 (AC-2 is exactly the kind of state mutation that would fail isolation regression if `before_each()` `reset_for_tests` is not honored)

**Status**: [x] Created and passing — `tests/unit/core/terrain_effect_caps_test.gd` (~265 LoC, **7 test functions** — original 6 covering AC-1..AC-6 plus 1 added during /code-review for symmetric `max_evasion` lazy-trigger coverage); full regression 289/289 PASS, 0 errors / 0 failures / 0 orphans, godot exit 0 (was 282 baseline → +7 new = exact expected delta)

---

## Dependencies

- Depends on: Story 003 (`_max_defense_reduction` + `_max_evasion` populated from config), Story 002 (lazy-init guard contract + compile-time const declarations)
- Unlocks: Formation Bonus Feature epic + Damage Calc Feature epic (consumers of the shared-cap accessors via cross-system contracts in formation-bonus.md §F-FB-1 + damage-calc.md §F)

---

## Completion Notes

**Completed**: 2026-04-26
**Verdict**: COMPLETE (no deviations, no forced engine constraints, no advisory carry-overs — first fully-clean implementation in this epic)
**Criteria**: 7/7 PASS (all 7 §AC checkboxes covered by 7 named test functions; 100% test-criterion traceability; 0 deferred; 0 untested)
**Tests**: 7 test functions in `terrain_effect_caps_test.gd` (~265 LoC after /code-review enhancements). Full regression **289/289 PASS** (was 282 baseline → +7 new = exact expected delta), 0 errors / 0 failures / 0 flaky / 0 orphans, godot exit 0.

**Files delivered** (2 in scope):
- `src/core/terrain_effect.gd` (MODIFY, 656 → 716 LoC; +60 LoC = +12 LoC header doc-block "## CROSS-SYSTEM SHARED CAP CONTRACT" inserted between G-1 LIMITATION end at original line 21 and `class_name TerrainEffect` at original line 22 + 2 blank-line separators + 46 LoC for 2 static accessors with full BBCode-tagged doc-comments) — `max_defense_reduction()` at lines 685-688 and `max_evasion()` at lines 706-709 are character-for-character verbatim from ADR-0008 §Decision 7 reference impl. Header doc-block names Formation Bonus + Damage Calc as consumers, mandates accessor pattern over hardcoded literal 30, distinguishes compile-time bootstrap vs. runtime authoritative.
- `tests/unit/core/terrain_effect_caps_test.gd` (NEW, ~265 LoC, 7 test functions) — `before_test()` discipline (G-15) + `reset_for_tests()` + user:// fixture pattern (AC-2) with `_write_caps_fixture(max_def, max_eva)` helper + `(load(PATH) as GDScript).get(...)` static-var inspection (AC-3, AC-3b, AC-4, AC-5) + sentinel-99 mutation pattern (AC-4) + substring-grep header verification (AC-6).

**Code-review verdicts** (lean mode standalone convergent — 2 specialists in parallel):
- **godot-gdscript-specialist**: APPROVED WITH SUGGESTIONS — verbatim ADR-0008 §Decision 7 reference impl reproduction confirmed character-for-character at lines 685-688 / 706-709; insertion position correct per §Decision 5 ordering; full G-1..G-15 audit completed. 4 SUGGESTIONS + 4 PASS-info + 1 OOS-1 (informational ADR-0008 push_warning behavior in story-002/003 territory).
- **qa-tester**: TESTABLE WITH GAPS → resolved inline. Per-AC mapping table 6/6 faithful; per-§AC checkbox table 7/7 covered post-fix. 1 GAP (F-1: max_evasion as first lazy-trigger untested) + 3 RECOMMENDATIONs (F-2 explicit `_config_loaded` assertion in AC-4; F-3 AC-1 deviation comment; F-4 AC-6 doc-coupling intent comment) + 2 PASS-info.
- **4 inline improvements applied**:
  1. **qa F-1 GAP**: added new `test_terrain_effect_caps_max_evasion_triggers_lazy_load` symmetric to AC-3 — closes the asymmetric coverage hole where only `max_defense_reduction()` was verified as first lazy-trigger caller. The AC-5 §AC checkbox "both accessors must independently trigger" is now provably enforced.
  2. **qa F-2 RECOMMENDATION**: added explicit `assert_bool(script.get("_config_loaded") as bool).is_true()` at end of AC-4 idempotency test — makes the post-guard state visible rather than implicit via sentinel survival.
  3. **qa F-3 RECOMMENDATION**: added doc-comment to AC-1 test explaining intentional lazy-load-via-accessor deviation from spec's explicit-load_config Given clause.
  4. **qa F-4 RECOMMENDATION**: added doc-comment to AC-6 test explaining intentional file-read coupling — instructs future reviewers to update header content (not relax test) on refactor.
- **2 cosmetic gdscript suggestions skipped** with rationale: 1-A informal paren-intent comment on `_write_caps_fixture` triple-quoted block (pattern self-explanatory after G-9 awareness); 2-A `[member _config_loaded]` BBCode reference (matches sibling style across get_terrain_modifiers / cost_multiplier / etc.; fixing only this story's accessors would be inconsistent).
- **0 advisories deferred to TD-034** — all findings either applied inline or rationalized as non-actionable.
- **0 false positives** in either specialist verdict — all 11 findings legitimate.

**Process insights**:
- **First fully-clean dev-story in this epic** — pattern observation: trivial Logic stories with verbatim ADR reference impls are the lowest-defect-rate story type. Stories 002 (skeleton) and 007 (cap accessors) both fit this mold; 003-006 all required at least one mid-implementation fix or forced deviation.
- **Existing infrastructure leverage** — story-002 + story-003 had already declared `MAX_DEFENSE_REDUCTION_DEFAULT` / `MAX_EVASION_DEFAULT` consts + `_max_defense_reduction` / `_max_evasion` static vars + `reset_for_tests()` reset logic + `_apply_config` config-population. Story-007 only needed 2 public accessors (~10 LoC of meaningful code) + doc-comment header update. The data-driven cap path (AC-2) works because story-003's `_apply_config` already populates the runtime vars from `caps.max_defense_reduction` / `caps.max_evasion` JSON fields. This is the ADR-0008 §Migration Plan paying off: foundational infrastructure landed in earlier stories enables cheap consumer-facing API additions.
- **Convergent /code-review pattern (lean mode)** validated 6th time in this epic — minimum-safe-unit confirmed. Both specialists returned in parallel; 4 inline applications took ~5 min; total cycle <10min.
- **G-6 / G-9 / G-14 / G-15 codifications** continue to pay dividends — clean test lifecycle on first run; G-9 paren-wrapping applied correctly throughout; G-15 `before_test()` from start.
- **Sub-agent Bash blocking pattern** continues — 6th time in this epic; orchestrator-direct verification chain stable. Pattern is now load-bearing — should be documented as workflow standard.
- **AC-7 doc-coupling test pattern** is novel and useful — substring-grep on file header for required contract terms is a lightweight way to assert documentation invariants without coupling to exact wording. Applicable to any cross-system contract that must remain prose-discoverable. Worth codifying as a reusable QA pattern in the test-standards.md rule file.

**Tech debt logged**: 0 new (all clean — no carry-overs to TD-034).

**No new gotcha codified this story** — all gotchas applied correctly from prior work (G-1 N/A / G-6 N/A / G-9 / G-14 N/A / G-15).

**Terrain-effect epic status**: **7/8 Complete** 🎉 — only story-008 (perf baseline + epic-end TD-034 §A-K hardening pass) remains. Critical-path unlock for Formation Bonus Feature epic + Damage Calc Feature epic (both consume the new shared-cap accessors via their respective cross-system contracts).
