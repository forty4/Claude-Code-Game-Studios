# Architecture Review — 2026-04-30 (delta #9, ADR-0006 Balance/Data close-out)

> **Mode**: lean delta-mode (single-ADR Proposed → Accepted escalation)
> **Date**: 2026-04-30 (4th /architecture-review of the day; suffix `e` to disambiguate from `2026-04-30.md` / `b.md` / `c.md` / `d.md`)
> **Pattern stability**: 9 invocations of fresh-session /architecture-review skill
> **Significance**: closes the LAST Proposed ADR — all 12 ADRs now Accepted; ZERO Proposed remaining

---

## Verdict: **PASS — APPROVED WITH SUGGESTIONS**

| Metric | Value |
|---|---|
| Cross-ADR conflicts (BLOCKING) | 0 |
| Same-patch source-code corrections | 1 (godot-gdscript-specialist Item 3) |
| Same-patch cross-doc wording fixes | 24 (across 6 ADRs) |
| Advisories carried as Implementation Notes | 2 |
| New TR-IDs registered | 20 (TR-balance-data-001..020) |
| TR registry version bump | v10 → v11 (registry total 142 → 162) |
| Traceability version bump | v0.9 → v0.10 |
| Architecture.md version bump | v0.6 → v0.7 |
| Registry/architecture.yaml version bump | v6 → v7 (+4 entries) |
| Files written | 14 |

---

## Phase 1 — Inputs Loaded

- **Target ADR**: `docs/architecture/ADR-0006-balance-data.md` (Proposed 2026-04-27, ratifies SHIPPED PR #65 2026-04-27 + terrain-effect story-003 PR #43)
- **Target GDD**: `design/gdd/balance-data.md` (Designed 2026-04-16; 10 Core Rules CR-1..CR-10, 13 Edge Cases, 16 Tuning Knobs, 15 ACs)
- **Source code under review**: `src/feature/balance/balance_constants.gd` (90 LoC, shipped 2026-04-27, exercised by 388/388 GdUnit4 regression across 10+ stories)
- **Test code**: `tests/unit/balance/balance_constants_test.gd` (6 functions, all PASS; G-15 reset pattern canonical)
- **Data file**: `assets/data/balance/balance_entities.json` (22 keys; will grow to 51 keys post-ADR-0010 27-key + ADR-0011 2-key same-patch story-level appends)
- **Engine reference**: Godot 4.6 (pinned 2026-04-16); `breaking-changes.md` + `deprecated-apis.md` consulted
- **Cross-ADR scan**: 12 Accepted ADRs (Platform 3 + Foundation 5 + Core 3 + 1 Feature) + ADR-0006 itself
- **Registries**: `tr-registry.yaml` v10; `architecture-traceability.md` v0.9; `architecture.md` v0.6; `docs/registry/architecture.yaml` v6
- **Reference rules**: `.claude/rules/godot-4x-gotchas.md` G-15 (already codified); `.claude/rules/data-files.md` Constants Registry Exception subsection (already in place per ADR-0006 §Migration Plan §4)

---

## Phase 2 — Technical Requirements Extracted (15 GDD ACs + 5 ADR-specific)

### From `design/gdd/balance-data.md`

| AC | Description | MVP/Alpha | TR ID |
|---|---|---|---|
| AC-01 | READY-prior consumer access blocked | Alpha-deferred | TR-balance-data-001 |
| AC-02 | 9-category Discovery scan | Alpha-deferred | TR-balance-data-002 |
| AC-03 | JSON envelope FATAL on missing fields | Alpha-deferred | TR-balance-data-003 |
| AC-04 | Phase 4 Build FATAL-free completion gates init | Alpha-deferred | TR-balance-data-004 |
| AC-05 | ERROR-level partial rejection | Alpha-deferred | TR-balance-data-005 |
| AC-06 | 3 access patterns | Alpha-deferred (only constant_access for MVP) | TR-balance-data-006 |
| AC-07 | All registered keys accessible via get_const | **MVP COVERED** | TR-balance-data-007 |
| AC-08 | schema_version below MINIMUM rejected | Alpha-deferred | TR-balance-data-008 |
| AC-09 | Hot Reload disabled in release | Alpha-deferred | TR-balance-data-009 |
| AC-10 | Hardcoding ban verification | **MVP COVERED** (AC-DC-48 lint) | TR-balance-data-010 |
| AC-F1 | F-1 Schema Compatibility 4-case correctness | Alpha-deferred | TR-balance-data-011 |
| AC-F2 | F-2 VCR CI gate | Alpha-deferred | TR-balance-data-012 |
| AC-EC1 | Empty file → severity-3 FATAL | Alpha-deferred | TR-balance-data-013 |
| AC-EC9 | Circular cross-reference rejection | Alpha-deferred | TR-balance-data-014 |
| AC-PERF | initialize() ≤ 5000ms on minimum-spec mobile | Alpha-deferred | TR-balance-data-015 |

### ADR-specific TRs (5 net-new from ADR-0006 architectural decisions)

| Decision | Coverage | TR ID |
|---|---|---|
| §1 Module Form: stateless-static utility class | **COVERED** (5-precedent pattern) | TR-balance-data-016 |
| §3-5 File rename + flat format + UPPER_SNAKE_CASE | **COVERED** (rename done; data-files.md exception in place) | TR-balance-data-017 |
| §4 + .claude/rules/data-files.md Constants Registry Exception | **COVERED** | TR-balance-data-018 |
| §6 Lazy on-first-call loading + idempotent guard | **COVERED** (shipped balance_constants.gd) | TR-balance-data-019 |
| §6 G-15 test-isolation discipline | **COVERED** (godot-4x-gotchas.md G-15 codified) | TR-balance-data-020 |

**Coverage breakdown**: 7 of 20 COVERED for MVP; 13 marked PARTIAL — Alpha-deferred per ADR-0006 §7 explicit MVP/Alpha scope split. The 13 PARTIAL TRs are **by design**, not architectural gaps. ADR-0006 §7 explicitly defers them to a future Alpha-tier "DataRegistry Pipeline" ADR (no calendar commitment).

---

## Phase 4 — Cross-ADR Conflict Detection

**0 BLOCKING conflicts found.**

### 24 same-patch wording corrections required (mechanical; all stale-reference cleanup)

#### Group A — "ADR-0006 NOT YET WRITTEN / Soft / provisional" (CRITICAL — 17 lines)

These ADRs contain text that becomes factually wrong the moment ADR-0006 is Accepted:

| File | Lines | Pattern | Resolution |
|---|---|---|---|
| ADR-0008 | 35, 44, 210, 212, 563, 622, 651, 666 (8 lines) | "Soft-depends" / "NOT YET WRITTEN" / "If ADR-0006 chooses .tres" / "When ADR-0006 lands" | Flip to "Accepted 2026-04-30 / Ratified" with forward-compat clarifications |
| ADR-0012 | 42, 344, 346, 438, 552, 559, 645, 675, 679 (9 lines) | "NOT YET WRITTEN — soft / provisional" / "ADR-0006 lands" / "4 future ADRs" / "future" | Flip to "Accepted 2026-04-30 via delta #9 — RATIFIED"; ADR-0012 line 42 also has factual drift `assets/data/balance/entities.yaml` → `balance_entities.json` (file format AND post-rename name) |

#### Group B — "ADR-0006 Accepted 2026-04-26" date drift (6 lines across 4 ADRs)

These ADRs were authored on or after 2026-04-30 and assumed ADR-0006 had been Accepted on 2026-04-26 (the day damage-calc was Accepted). The factually correct date is **2026-04-30** (today, this delta):

| File | Lines | Resolution |
|---|---|---|
| ADR-0007 | 42 | "Accepted 2026-04-26" → "Accepted 2026-04-30 via /architecture-review delta #9" |
| ADR-0009 | 26, 34 | Same flip |
| ADR-0010 | 41, 774 | Same flip |
| ADR-0011 | 30 | Same flip |

#### Group C — Same-patch primary

- **ADR-0006** itself: Status `Proposed` → `Accepted` 2026-04-30; Last Verified 2026-04-27 → 2026-04-30
- **`design/gdd/balance-data.md`**: Status header `Designed` → `✅ Accepted via ADR-0006 (Proposed 2026-04-27 → Accepted 2026-04-30 via /architecture-review delta #9)` + Last Updated annotation

#### Group D — Source-code correction (godot-gdscript-specialist Item 3)

- **`src/feature/balance/balance_constants.gd` lines 1-12** doc-comment block: replaced "Provisional balance-data wrapper" + "until ADR-0006 ratifies the DataRegistry pattern" + "Migration trigger: ADR-0006 Accepted → swap _load_cache() body" with ratified-status text (the actual Alpha migration trigger is a **future Alpha-pipeline DataRegistry ADR**, NOT ADR-0006 itself; ADR-0006 §Migration Path Forward is explicit on this).

#### Group E — Registry/traceability updates

- **`docs/architecture/tr-registry.yaml`** v10 → v11 + 20 TR-balance-data-001..020 entries appended (~3-4 LoC each, ~80 LoC total)
- **`docs/architecture/architecture-traceability.md`** v0.9 → v0.10:
  - Document Status table refresh (Source — architecture v0.6→v0.7; Source — TR registry v10→v11; Source — /architecture-review +e.md; GDDs scanned +balance-data.md re-scan; TRs registered 142→162; ADR coverage clarified to "ZERO Proposed ADRs remaining")
  - Coverage Summary line 31 named-list correction same-patch (was naming "ADR-0006" instead of "ADR-0008" in Foundation Accepted enumeration; count was correct, named list now correct)
  - Registered TR-to-ADR map +20 rows (TR-balance-data-001..020)
  - Pending TR baseline: balance-data candidate list (9 candidates) collapsed → REGISTERED 2026-04-30 delta #9 with prose summary
  - Changelog row v0.10 appended
- **`docs/architecture/architecture.md`** v0.6 → v0.7:
  - Document Status: Version + ADRs Referenced rewritten (was "ADR-0006/0012 (2026-04-26)" — corrects long-standing factual drift; ADR-0006 was actually Proposed since 2026-04-27, not Accepted; v0.4/0.5/0.6 had this stale value)
  - System Layer Map line 154 (Balance/Data row): "ADR-0006 ✅ 2026-04-26" → "ADR-0006 ✅ 2026-04-30 via delta #9"
  - Systems Requiring Additional ADRs (line 204): "✅ Accepted 2026-04-26" → "✅ Accepted 2026-04-30 via /architecture-review delta #9 ... LAST Proposed ADR closed"
  - Module Ownership Balance/Data row (line 248): same date flip
  - Phase 5 ADR Audit row for ADR-0006 (line 322): expanded with delta #9 specifics
  - Phase 6 mandatory ADR list: 0 → 0 (unchanged from v0.6)
  - Changelog row v0.7 appended
- **`docs/registry/architecture.yaml`** v6 → v7:
  - Header changelog comment block refreshed with delta #9 entry
  - 4 net-new entries codifying ADR-0006 ratified MVP form (Proposed-time author had not added registry entries; this delta backfills): `state_ownership: balance_constants_runtime_cache` + `interfaces: balance_constants_const_dispatch` + `api_decisions: balance_constants_module_form` + 2 `forbidden_patterns` (`balance_constants_signal_emission` + `balance_constants_consumer_mutation`)
- **NEW** `docs/architecture/architecture-review-2026-04-30e.md` (this report)

---

## Phase 5 — Engine Compatibility Audit

**Verdict: LOW engine risk** (matches ADR-0006 §Engine Compatibility self-assessment).

### Audit findings

- `FileAccess.get_file_as_string()` — pre-Godot-4.4 stable; no behavioral change in 4.4/4.5/4.6 (the only 4.4 FileAccess change is `store_*` methods returning `bool`, which is the WRITE path; this ADR uses READ path only)
- `JSON.parse_string()` — pre-Godot-4.0 stable; no breaking change across 4.4/4.5/4.6
- `class_name X extends RefCounted` + `static var` + all-static methods — pre-cutoff stable; no behavioral change in 4.4/4.5/4.6
- `push_error()` — pre-cutoff stable
- ADR-0006 §Engine Compatibility "Post-Cutoff APIs Used: None" — verified accurate

### godot-gdscript-specialist consultation (independent review-time validation)

Spawned via Task with focused 5-item brief. Returned **APPROVED WITH SUGGESTIONS**:

| Item | Topic | Verdict | Action |
|---|---|---|---|
| 1 | FileAccess + JSON.parse_string API stability vs Godot 4.6 | PASS | NO ACTION |
| 2 | Static-var lifecycle in `class_name BalanceConstants extends RefCounted` | PASS | NO ACTION |
| 3 | Source-comment accuracy in `balance_constants.gd` lines 1-12 | **CONCERN** | **SAME-PATCH FIX** (replaced "Provisional / until ADR-0006 ratifies" + "Migration trigger: ADR-0006 Accepted" with ratified-status text) |
| 4 | `raw.is_empty()` conflation of file-not-found vs empty-file | CONCERN (advisory only) | ADVISORY — consider `FileAccess.file_exists()` precheck for diagnostic separation |
| 5 | Untyped `static var _cache: Dictionary` rationale | PASS (advisory note) | ADVISORY — G-1 attribution at lines 32-33 is misleading (G-1 is about Node signal-list filtering, not Dictionary typing); future TD candidate to verify if Godot 4.6 permits `static var _cache: Dictionary[String, Variant]` and tighten in same pass as Alpha DataRegistry migration |

**Overall**: 1 same-patch correction (Item 3) + 2 carried advisories (Items 4 + 5). Slightly above the 8-delta mean correction count of 2.7, fitting normal range.

---

## Advisories Carried as Implementation Notes (NOT same-patch)

1. **(godot-gdscript-specialist Item 4)** Consider adding `FileAccess.file_exists()` precheck in `_load_cache()` to separate "file not found" vs "empty file" diagnostic messages. Quality-of-life only; 388/388 regression validates current behavior. Defer to a future maintenance pass — not blocking.

2. **(godot-gdscript-specialist Item 5)** `balance_constants.gd` lines 32-33 cite "G-1" as rationale for untyped `Dictionary` — but G-1 is about Node signal-list filtering, not Dictionary typing. Consider correcting the citation OR removing it. Also: TD-NEW candidate to verify whether Godot 4.6 permits `static var _cache: Dictionary[String, Variant]` (typed Dictionary in static var declaration) — if confirmed, tighten in same pass as Alpha DataRegistry migration. Defer — not blocking.

---

## Layer Status Post-Acceptance

| Layer | Before delta #9 | After delta #9 | Notes |
|---|---|---|---|
| Platform | 3/3 Complete (ADR-0001/0002/0003) | 3/3 Complete | unchanged |
| Foundation | 5/5 Complete (named-list drift: ADR-0006 listed instead of ADR-0008) | 5/5 Complete (named list corrected; ADR-0006 status now matches the listed-as-Accepted state) | line 31 named-list correction same-patch |
| Core | 3/3 Complete (ADR-0008 + ADR-0010 + ADR-0011) | 3/3 Complete | unchanged |
| Feature | 1/3 (ADR-0012 Accepted) | 1/3 | unchanged — Vertical-Slice candidates next |
| Presentation | 0/1 | 0/1 | unchanged |
| Polish | 0/1 | 0/1 | unchanged |

**Significant project transitions**:

- **11 → 12 Accepted ADRs**
- **Proposed ADRs: 1 → 0** (ADR-0006 was the LAST Proposed)
- **Mandatory ADR list before Pre-Prod gate: 0 → 0** (unchanged from delta #8; delta #9 is a clean close-out, NOT a mandatory-list reduction)
- **Pre-Production → Production gate now technically eligible** (mandatory ADR list = 0); strongly recommended to land 1-2 Vertical-Slice Feature ADRs (AI + Grid Battle) before invoking `/gate-check pre-production`

---

## Pattern Observations from Delta #9

1. **24-correction count is a one-time backfill anomaly**, not a regression in the /architecture-review pattern. Driver: ADR-0006 had 9 downstream Accepted ADRs accumulating "ADR-0006 NOT YET WRITTEN / Soft / provisional / Accepted 2026-04-26" stale references over 5 prior /architecture-review deltas (#5/#6/#7/#8) that didn't proactively backfill. Delta #9 inherits the cumulative bill from all interim reviews.

   **Codification candidate**: when the LAST Proposed ADR closes, the close-out delta inherits the stale-ref backfill bill from all interim referencing ADRs. Future projects should backfill stale-ref qualifiers each delta to keep the close-out bill linear (~3 corrections per delta) rather than cumulative (~24 in a single close-out).

2. **godot-gdscript-specialist correctly flagged source-comment drift** that no other delta phase would catch. The source comment `Migration trigger: ADR-0006 Accepted → swap _load_cache() body` was a misreading of ADR-0006's actual semantics — ADR-0006 RATIFIES the MVP form, doesn't trigger migration; the actual Alpha migration trigger is a separate future Alpha-pipeline ADR. 9-invocation track record reinforces specialist consultation value beyond engine-API verification.

3. **TR MVP-vs-Alpha split as PARTIAL with rationale** is a clean accounting pattern — registers 13 TRs that are by-design Alpha-deferred without polluting the GAP count. Reusable for future MVP-scoped ADRs that ratify a smaller surface than their GDD specifies (e.g., if a future ADR ratifies a partial implementation of a feature spec).

4. **Registry backfill at close-out** — ADR-0006's Proposed-time author had not added registry entries (state_ownership / interfaces / api_decisions / forbidden_patterns). Delta #9 added 4 entries to honor the spirit of ADR-0006 §Migration Plan §3. Future ADR authors should add registry entries at Proposed-time per the established ADR-0009/0010/0011 pattern (each added 5-8 entries during their Proposed-time architecture.yaml bumps).

5. **5-precedent stateless-static pattern is now load-bearing project discipline** for Foundation/Core data-layer ADRs. Pattern stable at 5 invocations (ADR-0008 → 0006 → 0012 → 0009 → 0007). Future Foundation/Core data-layer ADRs (Skill / Formation / Equipment / Character Growth) inherit the pattern unless a domain-specific reason justifies divergence.

---

## Carried Cross-Doc Advisories (DEFERRED to next ADR substantive edit)

Unchanged from delta #8 — no new ADR-0001 advisories surfaced this delta:

1. **ADR-0001 line 168** `action: String` → `action: StringName` (delta #6 carry; queues with next ADR-0001 substantive edit)
2. **ADR-0001 line 372** prose drift `hero_database.get(unit_id)` → `HeroDatabase.get_hero(hero_id: StringName)` (delta #5 carry; queues with next ADR-0001 substantive edit)
3. **ADR-0012 internal ContextResource unit_id type** (lines 186/192/197/201 + call sites 260/352-353) propagate `int` through AttackerContext/DefenderContext factory signatures (delta #8 carry; queues with next ADR-0012 substantive amendment)

---

## Next-Session Candidates (priority order)

1. **`/sprint-plan sprint-2`** — formalize scope with 5 epic-eligible candidates (hp-status + input-handling + hero-database + turn-order + balance-data) + Vertical-Slice candidates (AI + Grid Battle ADRs). Foundation 5/5 + Core 3/3 Complete + ZERO Proposed ADRs = clean slate for Sprint 2 planning.

2. **`/create-epics balance-data`** — eligible immediately post-delta-#9. ADR-0006 §Validation Criteria + §Migration Plan form the runbook. Estimated 1-2 stories: file_exists() precheck refinement (godot-gdscript-specialist Item 4 advisory) + G-1 attribution correction (Item 5 advisory) + TD-NEW typed-Dictionary verification. Most ADR-0006 implementation is already shipped (PR #65), so this epic is small.

3. **`/create-epics turn-order` / `hp-status` / `input-handling` / `hero-database`** — each eligible since their respective deltas (5/6/7/8) closed. Bigger epic surface than balance-data; prioritize per Sprint 2 scoping.

4. **AI System ADR + Grid Battle ADR** — first Vertical-Slice candidates; consume `unit_turn_started` per ADR-0011 + `request_action` direct delegation per ADR-0011 Contract 5; required for Grid Battle Vertical Slice readiness.

5. **`/gate-check pre-production`** — technically eligible since delta #8 (mandatory ADR list = 0); strongly recommended to land 1-2 Vertical-Slice Feature ADRs (AI + Grid Battle) BEFORE invoking the gate check. Pre-emptive invocation now would PASS but signal premature confidence.

6. **Batched ADR-0001 amendment** — when next ADR-0001 substantive edit occurs (e.g., signal addition for AI/Grid Battle ADRs), batch the 2 carried advisories (line 168 + line 372 prose drift).

7. **Future ADR-0012 amendment** — propagate `unit_id: int` through internal ContextResource factory signatures (5th carried advisory from delta #8); not blocking Vertical-Slice work.

---

## Files Written (14 total)

| # | File | Action | LoC delta (est.) |
|---|---|---|---|
| 1 | `docs/architecture/ADR-0006-balance-data.md` | Status flip + Last Verified | ±2 |
| 2 | `docs/architecture/ADR-0008-terrain-effect.md` | 8 wording flips | ±20 |
| 3 | `docs/architecture/ADR-0012-damage-calc.md` | 9 wording flips + line 42 yaml→json | ±15 |
| 4 | `docs/architecture/ADR-0007-hero-database.md` | 1 date drift flip | ±1 |
| 5 | `docs/architecture/ADR-0009-unit-role.md` | 2 date drift flips | ±2 |
| 6 | `docs/architecture/ADR-0010-hp-status.md` | 2 date drift flips | ±2 |
| 7 | `docs/architecture/ADR-0011-turn-order.md` | 1 date drift flip | ±1 |
| 8 | `design/gdd/balance-data.md` | Status header refresh | ±2 |
| 9 | `src/feature/balance/balance_constants.gd` | Doc-comment block lines 1-12 | ±15 |
| 10 | `docs/architecture/tr-registry.yaml` | v10 → v11 + 20 entries | +160 |
| 11 | `docs/architecture/architecture-traceability.md` | v0.9 → v0.10 | +30 |
| 12 | `docs/architecture/architecture.md` | v0.6 → v0.7 | +25 |
| 13 | `docs/registry/architecture.yaml` | v6 → v7 + 4 entries | +60 |
| 14 | `docs/architecture/architecture-review-2026-04-30e.md` | NEW (this report) | +400 |

**Total estimated diff: ~735 insertions / ~110 deletions** across 14 files.

Plus a silent append to `production/session-state/active.md` (gitignored).

---

**End of delta #9 verdict report.**
