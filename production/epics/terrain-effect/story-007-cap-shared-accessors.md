# Story 007: max_defense_reduction + max_evasion shared accessors

> **Epic**: terrain-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 1-1.5 hours (2 trivial accessors + 4 unit tests covering defaults / config-override / lazy-load / config-driven cap propagation)

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (`_max_defense_reduction` + `_max_evasion` populated from config), Story 002 (lazy-init guard contract + compile-time const declarations)
- Unlocks: Formation Bonus Feature epic + Damage Calc Feature epic (consumers of the shared-cap accessors via cross-system contracts in formation-bonus.md §F-FB-1 + damage-calc.md §F)
