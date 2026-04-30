# Architecture Review Report — Delta

> **Date**: 2026-04-30
> **Engine**: Godot 4.6
> **Mode**: Delta review — focused on ADR-0007 Hero Database Proposed → Accepted escalation (closes ADR-0009 only outstanding upstream soft-dep; Foundation 3/5 → 4/5)
> **Prior reports**: `architecture-review-2026-04-18.md` (PASS, 3 ADRs) + `-04-20.md` (PASS delta, ADR-0004) + `-04-25.md` (PASS delta, ADR-0008) + `-04-26.md` (PASS delta, ADR-0012) + `-04-28.md` (PASS delta, ADR-0009)
> **GDDs Reviewed (delta)**: 1 (`hero-database.md` rev 2026-04-29 Status flip — same-patch with ADR-0007 Write — 561 LoC, 4 Core Rules CR-1..CR-4, 4 Formulas F-1..F-4, 10 Edge Cases EC-1..EC-10, 12 Tuning Knobs, 15 Acceptance Criteria AC-01..AC-15)
> **ADRs Reviewed (delta)**: 1 (ADR-0007 Hero Database — Proposed 2026-04-29 via `/architecture-decision`, fresh-session review per skill protocol)

---

## TL;DR

- **Verdict**: **PASS** — ADR-0007 escalated Proposed → Accepted with 2 pre-acceptance wording corrections applied to ADR-0007 §2 (godot-specialist Item 3 + Item 8).
- godot-specialist independent review-time validation: **APPROVED WITH SUGGESTIONS** (8/8 PASS-or-CONCERN; 2 corrections applied pre-acceptance, 0 advisories carried).
- hero-database.md: **15 architectural TRs extracted, 100% covered by ADR-0007**; registered as TR-hero-database-001..015 in `tr-registry.yaml` v6 → v7. The 15 GDD ACs (AC-01..AC-15) map to the TR layer + ADR-0007 §GDD Requirements Addressed table.
- ADR-0001/0002/0003/0004/0006/0008/0009/0012 cross-conflict scan: clean except for the ADR-0001 line 372 prose API name drift (`hero_database.get(unit_id)` → ratified API is 6-method `HeroDatabase.get_hero(hero_id: StringName)` etc.) — **non-blocking**, advisory carried for next ADR-0001 amendment.
- 0 GDD revision flags this pass — hero-database.md Status pre-emptively flipped to "Accepted via ADR-0007" during ADR-0007 Write (commit `49fb0f1`); structural consistency verified.
- Project transitions from **8 → 9 Accepted ADRs** (4 Foundation + 1 Core + 1 Feature + 2 Foundation-stateless-calculator for Unit Role / Hero DB + 1 architecture-pattern Foundation for Balance/Data; pattern is now stable at **5 invocations** of the stateless-static utility class form: ADR-0008 → 0006 → 0012 → 0009 → 0007).
- **Foundation layer transitions 3/5 → 4/5 Complete**. Only Input Handling ADR-0005 remaining (HIGH engine risk — dual-focus 4.6 + SDL3 + Android edge-to-edge).

---

## Scope Clarification — Why a Delta Review

ADR-0007 was authored on 2026-04-29 via `/architecture-decision hero-database` (commit `49fb0f1` already PUSHED to origin/main per active.md). Per skill protocol the unbiased review must run in a **fresh session** — this review opened post-`/clear` with TG-2 sync gate satisfied (0/0 ahead/behind, clean tree).

Same single-ADR scope as the 2026-04-20 (ADR-0004), 2026-04-25 (ADR-0008), 2026-04-26 (ADR-0012), and 2026-04-28 (ADR-0009) delta reviews. Same delta-mode treatment: godot-specialist context-isolated subagent (review-time INDEPENDENT second opinion, separate from the 2026-04-29 design-time validation already incorporated into ADR-0007 line 19) + existing review chain as baseline.

**Mode used**: Delta (focused engine + coverage + consistency against existing 8 Accepted ADRs). Full-scope re-review of all 8 prior ADRs not warranted — no ADR-0001/2/3/4/6/8/9/12 content changed since their respective Accept dates, except the ADR-0001 line 372 prose drift advisory (carried forward; not blocking ADR-0007).

**Pattern stable at 5 invocations** of "fresh-session /architecture-review for single ADR escalation": this skill protocol consistently catches precision gaps that design-time validation misses (4-precedent track record: ADR-0008 §Verification close-outs; ADR-0012 AF-1 + Implementation Guidelines #8; ADR-0009 §1 line 130 parse-time→runtime + ADR-0012 [4][3]→[6][3]; ADR-0007 §2 default_class wording + Resource overhead acknowledgement).

---

## ADR-0007 Coverage — hero-database.md (15/15 ✅)

All 15 architectural technical requirements extracted from `design/gdd/hero-database.md` (rev 2026-04-29, 561 LoC, 15 ACs, 4 Core Rules CR-1..CR-4, 4 Formulas F-1..F-4, 10 Edge Cases EC-1..EC-10, 12 Tuning Knobs) map cleanly to ADR-0007 Decision sections + Engine Compatibility / Validation Criteria / Performance Implications. Registered as permanent TR-hero-database-001..015 in `tr-registry.yaml` v7.

| TR-ID | GDD Source | ADR-0007 § | Status |
|-------|-----------|------------|--------|
| TR-hero-database-001 | §Detailed Rules ("central registry"; module form architecturally unspecified by GDD — locked by ADR) | §1 | ✅ |
| TR-hero-database-002 | CR-2 (9 record blocks; 26 ratified fields) + AC-06 (relationship struct) | §2 | ✅ |
| TR-hero-database-003 | (architectural decision — storage form unspecified by GDD; rejected Alternatives 2/3/4) | §3 | ✅ |
| TR-hero-database-004 | §Interactions ("Hero DB가 외부에 노출하는 쿼리 인터페이스" 6-row table) + AC-15 query coverage | §4 | ✅ |
| TR-hero-database-005 | §Interactions "읽기 전용 계약" + Cross-system contract ("base + modifier") | §6 + §7 | ✅ |
| TR-hero-database-006 | CR-1 (hero_id format regex) + AC-01 + EC-1 partial (FATAL severity classification) | §5 | ✅ |
| TR-hero-database-007 | CR-2 (range guarantees: stats [1,100] / seeds [1,100] / move_range [2,6] / growth [0.5,2.0]) + AC-02..AC-05 | §5 | ✅ |
| TR-hero-database-008 | EC-1 + AC-12 (duplicate hero_id full-load reject) | §5 | ✅ |
| TR-hero-database-009 | EC-2 + EC-3 + AC-07 + AC-13 (parallel array integrity per-record reject; 0+0 accepted) | §5 | ✅ |
| TR-hero-database-010 | EC-4 + EC-5 + EC-6 + AC-14 (relationship WARNING tier; load continues) | §5 | ✅ |
| TR-hero-database-011 | F-1..F-4 + AC-08..AC-11 (validation deferred to Polish-tier build-time lint per ADR-0006 BalanceConstants thresholds) | §5 (DEFERRED block) | ✅ |
| TR-hero-database-012 | CR-4 (6-class enum 1:1 with UnitRole.UnitClass) + cross-doc convention | §2 (Item 3 corrected wording) | ✅ |
| TR-hero-database-013 | (cross-ADR: ADR-0001 line 372 non-emitter list) | §7 + Validation Criteria §6 | ✅ |
| TR-hero-database-014 | (architectural decision — lazy-init + G-15 mirror per ADR-0006/0009 precedent) | §1 + §R-2 + Validation §5 | ✅ |
| TR-hero-database-015 | AC-15 (100-hero / 100ms forward-compat) + §Performance Implications | §Performance Implications | ✅ |

**Coverage**: 15/15 ✅. All architectural commitments locked by the GDD have explicit ADR-0007 ratification.

The 15 GDD ACs are the same granularity as the architectural TR layer for hero-database (in contrast to unit-role's 23 ACs / 12 TRs ratio, where ACs were sub-test-case granularity). hero-database's GDD is content-shaped — most ACs are 1:1 with TR-level architectural commitments (severity-tier validation, query API surface, schema range checks). The remaining ACs (AC-08..AC-11) are F-1..F-4 validation forms, all deferred per ADR-0007 §5 to Polish-tier tooling and tracked by TR-hero-database-011.

---

## Engine Compatibility Audit — ADR-0007

### godot-specialist Context-Isolated Validation (Review-Time INDEPENDENT Second Opinion)

Spawned as parallel subagent with focused 8-item scope, briefed to NOT defer to the prior 2026-04-29 design-time validation (re-derive from first principles against Godot 4.6 reference + ADR-0007 text + cross-ADR consistency). Verdict: **APPROVED WITH SUGGESTIONS** (8/8 PASS-or-CONCERN; 2 corrections applied pre-acceptance + 0 advisories carried).

| # | Claim | Result | Notes |
|---|-------|--------|-------|
| 1 | §1 Module form: `class_name HeroDatabase extends RefCounted` + `@abstract` + all-static + `static var _heroes_loaded` + `static var _heroes: Dictionary[StringName, HeroData]` | ✅ PASS | 5-precedent pattern (ADR-0008→0006→0012→0009→0007); `@abstract` typed-reference parse-time block confirmed via G-22 empirical correction; `Dictionary[K, V]` typed Dictionary stable at Godot 4.4+ (project pinned 4.6). No correction needed. |
| 2 | §2 HeroData Resource shape: 26 @export fields incl. `Array[Dictionary]` for relationships + `duplicate_deep()` 4.5+ note | ✅ PASS | `duplicate_deep()` 4.5+ verified via current-best-practices.md §Resources + breaking-changes.md §4.4→4.5. Warning correctly placed on `relationships: Array[Dictionary]` field (the only field where inner-element non-deep-copy is a concern); correctly NOT placed on `Array[StringName]` / `Array[int]` scalar-element typed arrays. |
| 3 | §2 `default_class: int` cross-script typed-enum rejection rationale | ⚠️ CONCERN → corrected | ADR-0007 §2 line 210 originally read "silent fallback to int storage when the typed-enum reference fails to resolve" — partially correct but imprecisely characterized. Storage IS always int at the binary level regardless of @export type hint resolution. The actual Godot 4.x risk is **inspector-authoring instability**: when `hero_data.gd` loads before `unit_role.gd` resolves its `class_name`, the cross-script enum type cannot resolve and the editor may display the field as a bare integer rather than an enum dropdown. **Correction applied pre-acceptance**: ADR-0007 §2 wording amended to "inspector-authoring instability when the cross-script enum type fails to resolve during editor load — the editor may show a bare integer field instead of an enum dropdown." Practical choice (store as `int`) is correct and defensible: (a) load-order risk is real in Godot 4.x, (b) avoids hard dependency between two sibling foundation files, (c) type safety enforced at UnitRole's parameter boundary. Wording fix prevents future implementer from incorrectly thinking data-migration is needed if they switch to typed-enum storage. |
| 4 | §3 JSON loading via `JSON.new().parse()` + `FileAccess.get_file_as_string()` | ✅ PASS | `FileAccess.get_file_as_string(path)` is a static read method — unaffected by Godot 4.4 breaking change which only added `bool` returns to `store_*` WRITE methods. `JSON.new().parse()` instance form for line/col diagnostics confirmed stable; consistent with ADR-0009 §4 precedent. |
| 5 | §4 typed-array construction pattern (G-2 prevention) | ✅ PASS | `var result: Array[HeroData] = []` + `result.append(hero)` + `return result` correctly preserves typed annotation. G-2 codifies that `Array[T].duplicate()` silently demotes to untyped Array; ADR-0007's claim that `.assign()` is unnecessary at the return site (when local is pre-declared with typed annotation) is correct — `.assign()` is only needed when copying FROM an existing typed array. |
| 6 | §5 Validation severity model + `push_error` / `push_warning` semantics | ✅ PASS | Godot's `push_error()` does NOT halt execution — logs to debugger + sets error flag, but processing continues unless caller explicitly returns. ADR-0007's 3-tier model (load-reject FATAL via push_error + early return; per-record-reject FATAL via push_error + skip record; WARNING via push_warning + continue) is entirely consistent with Godot's semantics. Engine does not provide "throw and halt" for GDScript; explicit early return after push_error is the only available pattern and the architecturally correct one. |
| 7 | §Validation Criteria §5 + §R-2 G-15 test isolation (`_heroes_loaded` reset in `before_test()`) | ✅ PASS | G-15 fully verified: correct lifecycle hook in GdUnit4 v6.1.2 is `before_test()` (NOT `before_each()`). Static-var leakage characterization accurate: `_heroes_loaded` is class-level static, so `_load_heroes()` cached state persists across all tests in same GdUnit4 runner process unless explicitly reset. Pattern proven stable across project (ADR-0006 `_cache_loaded`, ADR-0009 `_coefficients_loaded`, now ADR-0007 `_heroes_loaded` — 3-precedent G-15 mirror). |
| 8 | HeroData `Resource` vs `RefCounted` asymmetry with ADR-0012 wrappers | ⚠️ CONCERN → addressed | ADR-0007 §2 originally justified `extends Resource` on (a) Inspector authoring round-trip + (b) ResourceSaver serialization compatibility. The asymmetry with ADR-0012's `RefCounted` choice for typed wrappers is architecturally justified (HeroData is content data with Inspector + ResourceSaver use cases; ADR-0012 wrappers are transient per-call computation contexts) but the original ADR-0007 §2 did not explicitly acknowledge the trade-off. `Resource` carries overhead over `RefCounted`: registers with Godot resource management subsystem, carries `resource_path` + `resource_name`, participates in `ResourceLoader` cache, larger base memory footprint. For 10-100 HeroData cache, overhead is negligible (~5KB/record × 100 = 500KB << 512MB mobile ceiling). **Correction applied pre-acceptance**: ADR-0007 §2 amended with one sentence: "Resource base-class overhead (resource_path, resource_name, ResourceLoader cache participation) is accepted for the 10-100 MVP/Alpha cache size at ~5KB/record; negligible against the 512MB mobile ceiling." Plus explicit asymmetry-with-ADR-0012-wrappers acknowledgement. |

### Corrections Applied This Pass (2 ADR-0007 §2 wording fixes)

| Correction | Applied where |
|---|---|
| **Item 3**: §2 `default_class: int` paragraph — "silent fallback to int storage" → "inspector-authoring instability when the cross-script enum type fails to resolve during editor load — the editor may show a bare integer field instead of an enum dropdown" + acknowledgement that binary storage is always int regardless | ADR-0007 §2 (Decision §2 "default_class: int" paragraph) |
| **Item 8**: §2 — added one sentence acknowledging Resource base-class overhead (resource_path, resource_name, ResourceLoader cache participation) accepted for ~5KB/record × 100 cache size against 512MB mobile ceiling + explicit asymmetry rationale with ADR-0012 RefCounted typed wrappers | ADR-0007 §2 (after `HeroFaction enum locally scoped` paragraph, before `Field set deferrals`) |

These are **wording corrections, not architectural changes**. The Decision body of ADR-0007 is otherwise untouched. Pattern matches the 2026-04-28 review's ADR-0009 §1 line 130 + ADR-0012 [6][3] dimension corrections (also wording-only) and the 2026-04-26 review's ADR-0012 §Consequences AF-1 + Implementation Guidelines #8 corrections (also wording-only).

### Advisories Carried (non-blocking)

None. The 2 surfaced concerns (Item 3 + Item 8) were both addressed in-flight as wording-only pre-acceptance corrections. No deferred follow-ups.

### Independent Review Confirmed/Challenged Prior 2026-04-29 Design-Time Validation

The prior design-time validation (incorporated into ADR-0007 line 19) was largely sound — the 3 design-time amendments (V-3 `duplicate_deep()` doc-comment, V-4 G-2 typed-array construction note, V-5 `Dictionary[StringName, HeroData]` typed upgrade) are all correctly identified and adequately addressed in the ADR text.

The independent review caught two precision gaps the design-time validation missed: (a) the `default_class: int` "silent fallback to int storage" wording was imprecise — the storage is always int regardless; the risk is editor-time UX, not data corruption (Item 3); (b) the `Resource` vs `RefCounted` asymmetry with ADR-0012 wrappers was not explicitly acknowledged with an overhead trade-off note (Item 8). **Neither is a design-time failure** — they are exactly the kind of precision gaps that cross-session independent review exists to catch. The pattern validates the skill's "fresh session for /architecture-review" protocol at its 5th invocation in this project.

### Post-Cutoff API Inventory (project-wide, delta)

ADR-0007 introduces zero post-cutoff APIs (per §Engine Compatibility table). Inventory unchanged from 2026-04-28 except for the explicit registration of `Dictionary[StringName, HeroData]` typed Dictionary syntax (4.4+) which was declared by ADR-0007 but was not previously on the project inventory:

| API | Version | ADR | Status |
|-----|---------|-----|--------|
| Typed signals with Resource payloads | 4.2+ (strictness 4.5) | ADR-0001 | declared + verified |
| `ResourceLoader.load_threaded_request` | 4.2+ stable | ADR-0002 | declared + verified |
| Recursive Control disable | 4.5+ | ADR-0002 | declared, verification deferred to Polish |
| `Resource.duplicate_deep(DEEP_DUPLICATE_ALL)` | 4.5+ | ADR-0001 + ADR-0003 + ADR-0004 + ADR-0007 | declared + verified |
| `DirAccess.get_files_at` | 4.6-idiomatic | ADR-0003 | declared |
| `ResourceSaver.FLAG_COMPRESS` | pre-cutoff | ADR-0003 | declared |
| `class_name X extends RefCounted` + static methods | pre-4.4 stable | ADR-0008 + ADR-0012 + ADR-0009 + ADR-0007 | declared + verified |
| `@abstract` (4.5+) | 4.5+ | ADR-0012 + ADR-0009 + ADR-0007 | declared + verified (typed-reference parse-time block per G-22) |
| `enum UnitClass` typed parameter binding | pre-4.4 stable | ADR-0009 | declared + verified |
| `PackedFloat32Array` COW return semantics | pre-cutoff | ADR-0009 | declared + verified |
| `BalanceConstants.get_const(key)` accessor | (project pattern, ADR-0006 ratified) | ADR-0009 + ADR-0007 (forward-compat) | declared + verified |
| `&"foo"` StringName literal interning | pre-cutoff | ADR-0012 + ADR-0009 + ADR-0007 | declared + verified |
| **`Dictionary[K, V]` typed Dictionary syntax** | **4.4+** | **ADR-0007** | **declared + verified (NEW THIS PASS)** |
| `JSON.new().parse()` instance form (line/col diagnostics) | pre-cutoff | ADR-0008 + ADR-0009 + ADR-0007 | declared + verified |
| `FileAccess.get_file_as_string()` (read path; unaffected by 4.4 store_* bool change) | pre-cutoff | ADR-0006 + ADR-0008 + ADR-0009 + ADR-0007 | declared + verified |

ADR-0007 declared APIs: all pre-4.6-stable, no deprecated API references.

---

## Cross-ADR Conflict Detection (Delta)

Scanned ADR-0007 against ADR-0001/0002/0003/0004/0006/0008/0009/0012:

### ADR-0001 (GameBus) — ✅ CONSISTENT (1 advisory carried for next ADR-0001 amendment)

ADR-0001 line 372 already enumerates Hero Database (#25) on the non-emitter list: *"**Hero Database (#25)** — read-only data registry. `hero_database.get(unit_id)` is a direct call."*

ADR-0007 §4 ratifies the actual API as 6 static methods (`HeroDatabase.get_hero(hero_id: StringName)`, `get_heroes_by_faction`, `get_heroes_by_class`, `get_all_hero_ids`, `get_mvp_roster`, `get_relationships`). The ADR-0001 line 372 prose example (`hero_database.get(unit_id)`) is a non-binding illustrative reference, not a contract — but it is **stale documentation** relative to the ratified ADR-0007 API. **Advisory**: next ADR-0001 amendment (e.g., when ADR-0005 Input Handling lands or when a new signal is added) should refresh line 372 to reference `HeroDatabase.get_hero(hero_id: StringName)` (the actual API name + signature).

This is **non-blocking for ADR-0007 acceptance** — the conflict is surface-prose drift, not architectural disagreement. ADR-0007's non-emitter discipline (§7 forbidden_pattern `hero_database_signal_emission`) is fully consistent with ADR-0001's non-emitter list.

### ADR-0002 (Scene Manager) — ✅ CLEAN

No Hero DB interaction. Scene Manager retains BattleScene during overworld; Hero DB is session-persistent and survives scene transitions naturally per ADR-0007 §1 (cross-scene consumer pattern). No conflict.

### ADR-0003 (Save/Load) — ✅ CONSISTENT

TR-save-load-002 @export discipline: ADR-0007 §2 line 208 cites this for HeroData all-@export discipline (forward-compat for ResourceSaver round-trip via the rejected Alternative 2 per-hero `.tres` pipeline). HeroData is content data, not save data — but @export is mandatory per Save/Load conventions to enable future authoring tooling. No conflict.

### ADR-0004 (Map/Grid) — ✅ CLEAN

Map/Grid does not consume HeroData directly per ADR-0004 §Public API (9 query methods read tile / unit_id / coord — no hero record access). The Map/Grid ↔ Hero DB integration is mediated by Grid Battle / UnitRole. No conflict.

### ADR-0006 (Balance/Data) — ✅ CONSISTENT

ADR-0007 §1 BalanceConstants.get_const(key) for forward-compat validation thresholds (STAT_TOTAL_MIN/MAX, SPI_WARNING_THRESHOLD, MVP_FLOOR_OFFSET, MVP_CEILING_OFFSET). MVP runtime does NOT consume these — validation deferred to Polish-tier `tools/ci/lint_hero_database_validation.sh` story. ADR-0007 inherits ADR-0006's lazy-init JSON pattern + `_cache_loaded` test-isolation pattern (ADR-0007's `_heroes_loaded` is the same shape). 5-precedent pattern stable.

### ADR-0008 (Terrain Effect) — ✅ CLEAN

No direct Hero DB interaction. Terrain Effect's cost matrix consumes UnitRole's `get_class_cost_table(unit_class)` which transitively consumes HeroData via UnitRole.get_atk(hero, unit_class) etc. Indirect dependency. No conflict.

### ADR-0009 (Unit Role) — ✅ CONSISTENT (same-patch updates already applied)

Verified per `git show 49fb0f1`:
- ADR-0009 §Dependencies "Soft / Provisional" line 35: ~~struck-through~~ + replaced with retrospective note "**CLOSED 2026-04-29**: ADR-0007 (Hero Database, Proposed 2026-04-29) ratifies the `HeroData` Resource shape...". ✓
- ADR-0009 §Migration Plan §"From provisional `HeroData` to ADR-0007-ratified shape": ~~struck-through~~ + marked "**COMPLETE 2026-04-29**" with retrospective prose enumerating field-set expansion (10 → 26), cross-doc int convention for default_class, and parameter-stable migration confirmation. ✓
- ADR-0009 §3 Public API line 162-170: 6 method signatures binding `HeroData` parameter — preserved verbatim, all 7 read-fields (`stat_might`, `stat_intellect`, `stat_command`, `stat_agility`, `base_hp_seed`, `base_initiative_seed`, `move_range`) ratified by ADR-0007 §2 without rename. ✓

ADR-0007 §2 default_class:int cross-doc convention with UnitRole.UnitClass enum 0..5 alignment is documented in both ADR-0007 §2 (Item 3 corrected wording) + ADR-0009 §Migration Plan retrospective. **Drift risk monitored** by §6 forbidden_pattern scope-note + future ADR-0009 amendment will cross-reference.

### ADR-0012 (Damage Calc) — ✅ CLEAN

DamageCalc consumes HeroData via UnitRole.get_atk(hero, unit_class) etc. — never reads HeroData fields directly. The HeroData parameter shape is bound at the UnitRole boundary, not the DamageCalc boundary. ADR-0012 §3 4 typed RefCounted wrappers (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`) are unaffected by ADR-0007 ratification. **Item 8 trade-off acknowledgement** (HeroData `Resource` vs ADR-0012 wrapper `RefCounted` asymmetry) is now explicit in ADR-0007 §2 — no architectural conflict.

### Summary

**0 blocking conflicts**. **1 advisory** (ADR-0001 line 372 prose API name drift; non-blocking; defer to next ADR-0001 amendment). **0 dependency cycles**. **0 unresolved soft-deps** — ADR-0007 acceptance closes ADR-0009's only outstanding upstream soft-dep clause.

---

## ADR Dependency Order (Post-ADR-0007 Acceptance)

Topologically sorted:

**Foundation layer** (no upstream deps):
1. ADR-0001 (GameBus) — Accepted 2026-04-18
2. ADR-0002 (Scene Manager) — Accepted 2026-04-18 (depends on ADR-0001)
3. ADR-0003 (Save/Load) — Accepted 2026-04-18 (depends on ADR-0001 + ADR-0002)
4. ADR-0004 (Map/Grid) — Accepted 2026-04-20 (depends on ADR-0001)
5. ADR-0006 (Balance/Data) — Accepted 2026-04-26 (Foundation data infra)
6. **ADR-0007 (Hero Database) — Accepted 2026-04-30 (depends on ADR-0001 + ADR-0006 + ADR-0009; closes ADR-0009 soft-dep)**

**Foundation/Core-bridge layer**:
7. ADR-0009 (Unit Role) — Accepted 2026-04-28 (depends on ADR-0001 + ADR-0006; soft-dep on ADR-0007 NOW CLOSED)

**Core layer**:
8. ADR-0008 (Terrain Effect) — Accepted 2026-04-25 (depends on ADR-0001 + ADR-0004; consumed UnitRole cost-table dimension placeholder ratified by ADR-0009)

**Feature layer**:
9. ADR-0012 (Damage Calc) — Accepted 2026-04-26 (depends on ADR-0001 + ADR-0008 + ADR-0009; CLASS_DIRECTION_MULT [6][3] ratified per ADR-0009; HeroData parameter shape now ratified per ADR-0007)

No cycles. No unresolved upstream Proposed ADRs. All 9 Accepted.

---

## GDD Revision Flags

**None.** `design/gdd/hero-database.md` Status was pre-emptively flipped to "Accepted via ADR-0007 (Proposed 2026-04-29)" during ADR-0007 Write (commit `49fb0f1`); structural consistency verified this pass. After this `/architecture-review` Acceptance, the Status reference can be tightened to "Accepted via ADR-0007 (Accepted 2026-04-30)" but this is documentation-hygiene only, non-blocking.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v0.1, 2026-04-18) is now **5 ADRs out of date** (ADR-0007 is the 5th ADR added since the v0.1 sweep at ≤4 ADRs). The pending `/create-architecture` partial-update sweep flagged in the prior session's next-session-candidates is now overdue by 5 ADRs (ADR-0006 + 0007 + 0008 + 0009 + 0012). Recommend `/create-architecture` partial-update before the next /architecture-review (ADR-0005 input-handling is the next likely candidate for ADR authoring; the architecture.md sweep should run before or concurrent with that).

---

## Verdict: PASS

ADR-0007 escalated **Proposed → Accepted** with 2 wording-only corrections applied pre-acceptance. 15 TRs registered. Foundation layer 3/5 → 4/5. ADR-0009's only outstanding upstream soft-dep CLOSED. 9 Accepted ADRs project-wide.

### Blocking Issues (must resolve before PASS)

None. All Phase 5 (Engine Compatibility) Item 3 + Item 8 concerns addressed in-flight as wording fixes pre-acceptance. No carried advisories require resolution before merge.

### Required ADRs (priority order, post-ADR-0007 Acceptance)

1. **ADR-0005 (Input Handling)** — HIGH engine risk (dual-focus 4.6 + SDL3 + Android edge-to-edge). Last Foundation-layer ADR remaining; unblocks input-handling Foundation epic. Foundation layer 4/5 → 5/5 on Acceptance.
2. **Core layer — HP/Status ADR (ADR-0010)** + **Turn Order ADR (ADR-0011)** — currently soft-deps in ADR-0012 §Dependencies line 42. Depend on ADR-0007 (HeroData base_hp_seed / base_initiative_seed consumer paths now ratified).
3. **Feature layer — Grid Battle / Formation Bonus / AI ADRs** — Grid Battle owns the BattleController + cross-system orchestration; Formation Bonus owns the typed `Array[HeroRelationship]` migration that ADR-0007 §2 line 215 marked as soft-deferred.
4. **`/create-architecture` partial-update** — overdue by 5 ADRs; should precede next ADR creation pass.

---

## Architecture Layer Coverage Summary (post-ADR-0007 Acceptance)

| Layer | TRs (est.) | ADRs existing | ADRs required | Status |
|---|---|---|---|---|
| Platform | — (infra) | 3 (ADR-0001..0003 Accepted) | 0 more | ✅ Complete |
| Foundation | ~50 | 4 (ADR-0004 + ADR-0006 + ADR-0009 + **ADR-0007** Accepted) | 1 more (Input ADR-0005) | ⚠️ **4/5** |
| Core | ~30 | 1 (ADR-0008 Accepted) | 1+ more (Turn Order signal, HP/Status) | ⚠️ 1/2 |
| Feature | ~25 | 1 (ADR-0012 Accepted) | 2+ (AI, Grid Battle, Destiny Branch) | ⚠️ 1/3 |
| Presentation | ~10 | 0 | 1+ (Dual-focus UI pattern) | ❌ 0/1 |
| Polish | ~2 | 0 | 1 (Accessibility, if tier committed) | ❌ 0/1 |

**Net-new ADRs required before Pre-Production → Production gate**: 4–8 (ADR-0007 landed this pass; ratifies HeroData parameter shape consumed transitively by ADR-0009 + ADR-0012).

---

## Reflexion Log

No 🔴 CONFLICT entries this pass — all cross-ADR detections were either CLEAN or CONSISTENT (with 1 prose-drift advisory carried).

`docs/consistency-failures.md` — no append needed.

---

## Changelog

This is the 5th delta `/architecture-review` in the project. Pattern stable at 5 invocations:

| Date | Pass | ADR Escalated | Wording Corrections | godot-specialist Verdict |
|------|------|----------------|----------------------|--------------------------|
| 2026-04-18 | Initial | ADR-0001/0002/0003 | — | (in-line during initial review) |
| 2026-04-20 | Delta 1 | ADR-0004 | 0 | (in-line; ADR-0004 pre-Accepted) |
| 2026-04-25 | Delta 2 | ADR-0008 | 2 (§Verification §2/§3 close-out) | APPROVED |
| 2026-04-26 | Delta 3 | ADR-0012 | 2 (AF-1 + Implementation Guidelines #8) | APPROVED WITH SUGGESTIONS |
| 2026-04-28 | Delta 4 | ADR-0009 | 2 (§1 line 130 parse-time→runtime + ADR-0012 [4][3]→[6][3] cross-ADR) | APPROVED WITH SUGGESTIONS |
| **2026-04-30** | **Delta 5** | **ADR-0007** | **2 (§2 default_class wording + Resource overhead acknowledgement)** | **APPROVED WITH SUGGESTIONS** |

The 5-invocation track record validates the skill's "fresh session for /architecture-review" protocol consistently catches precision gaps that design-time validation misses, all addressable as wording-only pre-acceptance corrections — no architectural rework. Average ratio: ~2 wording corrections per delta review.

---

## Handoff

**Immediate actions** (priority order):

1. **`/architecture-decision input-handling`** (ADR-0005) — HIGH engine risk; last Foundation-layer ADR; unblocks Input Handling Foundation epic. Bring Foundation 4/5 → 5/5 Complete.
2. **`/create-architecture` partial-update** — sweep overdue by 5 ADRs (since v0.1 baseline at ≤4 ADRs). Recommend before next /architecture-decision pass to avoid further drift.
3. **`/sprint-plan` sprint-2** — formalize scope with input-handling Foundation epic + 2 Core epics (hp-status / turn-order; ADR-0010/0011 also pending).

**Gate guidance**: When all blocking ADRs are resolved (ADR-0005 + Core ADRs at minimum), run `/gate-check pre-production` to advance.

**Rerun trigger**: Re-run `/architecture-review` after each new ADR is written (5-precedent fresh-session protocol).
