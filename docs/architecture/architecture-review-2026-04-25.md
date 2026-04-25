# Architecture Review Report — Delta

> **Date**: 2026-04-25
> **Engine**: Godot 4.6
> **Mode**: Delta review — focused on ADR-0008 Proposed → Accepted escalation
> **Prior reports**: `architecture-review-2026-04-18.md` (PASS, 3 ADRs) + `architecture-review-2026-04-20.md` (PASS delta, ADR-0004 accepted)
> **GDDs Reviewed (delta)**: 1 (terrain-effect.md — TR registration)
> **ADRs Reviewed (delta)**: 1 (ADR-0008 — Proposed on 2026-04-25, not in prior reviews) + concurrent erratum amendment to ADR-0004

---

## TL;DR

- **Verdict**: **PASS** — ADR-0008 escalated Proposed → Accepted, with concurrent ADR-0004 erratum amendment (TD-032 A-21 resolved this pass).
- godot-specialist context-isolated validation: **APPROVED WITH SUGGESTIONS** (12/13 PASS, 1 CONCERN resolved this pass via the ADR-0004 amendment).
- terrain-effect.md 18 technical requirements 100% covered by ADR-0008; registered as TR-terrain-effect-001..018 in `tr-registry.yaml` v3 → v4.
- ADR-0001/0002/0003 consistency clean. Future ADR-0001 amendment requirement documented in ADR-0008 §4 Caching for the deferred `terrain_changed(coord)` signal.
- 1 GDD revision flag (terrain-effect.md OQ-7 close-as-resolved — no actual inconsistency).
- Project Core layer transitions from 0 ADRs to 1 ADR Accepted. Total Accepted ADRs: 4 → 5.

---

## Scope Clarification — Why a Delta Review

The 2026-04-20 delta review covered ADR-0004 (Map/Grid). ADR-0008 Terrain Effect was authored on 2026-04-25 and committed in Proposed status. Same single-ADR scope as the 2026-04-20 review; same delta-mode treatment (godot-specialist subagent + existing review chain as baseline).

**Mode used**: Delta (focused engine + coverage + consistency against existing 4 Accepted ADRs). Full-scope re-review of all 5 ADRs not warranted — no ADR-0001/2/3 content changed since 2026-04-18 PASS; ADR-0004 received a concurrent erratum amendment this pass (documented below).

---

## ADR-0008 Coverage — terrain-effect.md (18/18 ✅)

All 18 technical requirements extracted from `design/gdd/terrain-effect.md` map cleanly to ADR-0008 sections. Registered as permanent TR-terrain-effect-001..018 in `tr-registry.yaml` v4.

| TR-ID | Requirement (abbrev) | ADR-0008 Section | Status |
|-------|---------------------|-------------------|--------|
| TR-terrain-effect-001 | CR-1: 8 terrain types × {def_bonus, eva_bonus, special_rules} | §Decision 2 (JSON) + §Decision 6 (TerrainModifiers) | ✅ |
| TR-terrain-effect-002 | CR-1d: Modifiers uniform across unit types MVP | §Constraints + §Decision 5 cost_multiplier MVP=1 | ✅ |
| TR-terrain-effect-003 | CR-2: Asymmetric elevation modifiers (sub-linear) | §Decision 2 elevation_modifiers JSON | ✅ |
| TR-terrain-effect-004 | F-1: Symmetric clamp [-30, +30] | §Decision 6 + §Performance | ✅ |
| TR-terrain-effect-005 | CR-3a/b: MAX_DEFENSE_REDUCTION/MAX_EVASION = 30 | §Decision 7 cap accessors + JSON | ✅ |
| TR-terrain-effect-006 | CR-3d: Min damage = 1 (Damage Calc enforces) | §GDD Reqs Addressed (correctly delegated) | ✅ |
| TR-terrain-effect-007 | CR-3e + EC-1: Symmetric clamp authoritative | §GDD Reqs Addressed | ✅ |
| TR-terrain-effect-008 | CR-4: 3 query methods | §Decision 5 Public API | ✅ |
| TR-terrain-effect-009 | CR-5: Bridge FLANK→FRONT via flag; orchestrated by Damage Calc | §Decision 3 + ADR-0004 §5b (this-pass) | ✅ |
| TR-terrain-effect-010 | Stateless RefCounted+static; lazy-init; reset_for_tests() | §Decision 1 | ✅ |
| TR-terrain-effect-011 | damage-calc.md §F opaque clamped contract | §Constraints + §Decision 6 | ✅ |
| TR-terrain-effect-012 | Config at assets/data/terrain/terrain_config.json | §Decision 2 + Notes for Implementation | ✅ |
| TR-terrain-effect-013 | AC-21: <0.1ms per call (mid-range Android) | §Performance + §Verification §1 | ✅ |
| TR-terrain-effect-014 | AC-19/20: Schema validation + safe defaults | §Decision 2 validation rules | ✅ |
| TR-terrain-effect-015 | EC-14: Elevation delta clamped [-2,+2] | §GDD Reqs Addressed | ✅ |
| TR-terrain-effect-016 | AC-14: OOB coord → zero modifiers | §Decision 5 + §GDD Reqs | ✅ |
| TR-terrain-effect-017 | Shared cap accessor (Formation Bonus + Damage Calc) | §Decision 7 | ✅ |
| TR-terrain-effect-018 | cost_multiplier matrix structure (replaces terrain_cost.gd:32) | §Decision 5 + §Migration Plan | ✅ |

**Coverage**: 18/18 ✅ — TR-009 was conditional on ADR-0004 §5b which was added concurrently this pass; now structurally satisfied.

---

## Engine Compatibility Audit — ADR-0008

### godot-specialist Context-Isolated Validation

Spawned as parallel subagent with scope: Godot 4.6 engine-correctness of ADR-0008. Verdict: **APPROVED WITH SUGGESTIONS** (12/13 claims PASS, 1 CONCERN resolved this pass).

| # | Claim | Result | Notes |
|---|-------|--------|-------|
| 1 | `class_name X extends RefCounted` + all-static is idiomatic 4.6 | ✅ PASS | Lightweight, no lifecycle overhead, never-instantiated |
| 2 | `static var` with lazy-init + idempotent guard | ✅ PASS | Stable across 4.x; main-thread safe |
| 3 | `JSON.parse_string()` static method + diagnostic limitation | ✅ PASS | Notes §2 firm-recommends instance form for line/col diagnostics |
| 4 | JSON integer/float coercion + defensive guard | ✅ PASS | All JSON numbers are `float`; guard `typeof != TYPE_FLOAT or value != int(value)` is correctly defensive (rejects non-numerics AND fractionals). godot-specialist's suggested simplification was misread of boolean logic — keep ADR text as written. |
| 5 | `@export Array[StringName]` on Resource subclass | ✅ PASS | Stable since 4.0; ResourceSaver round-trip clean |
| 6 | `class_name TerrainEffect` non-collision | ✅ PASS | No Godot 4.6 built-in by this name; TerrainModifiers/CombatModifiers also clean |
| 7 | G-3 autoload+class_name collision avoidance | ✅ PASS | Static-utility pattern sidesteps G-3 entirely; rationale matches `.claude/rules/godot-4x-gotchas.md` |
| 8 | MapGrid integration (`get_tile`, `get_attack_direction`, `ATK_DIR_*`) | ⚠️→✅ | Initial CONCERN: 3-arg signature + `ATK_DIR_*` constants not in any Accepted ADR. Resolved this pass via concurrent ADR-0004 erratum (§5b Direction Constants + 3-arg signature update). |
| 9 | Bridge FLANK override placement (Damage Calc orchestrator) | ✅ PASS | Foundation-layer purity preserved; flag-pattern idiomatic |
| 10 | Static-state cross-suite leakage in GdUnit4 | ✅ PASS | RefCounted (not Node) sidesteps G-6 orphan timing; before_each() reset_for_tests() discipline + multi-suite regression test sufficient |
| 11 | <0.1ms per get_combat_modifiers (AC-21 budget) | ✅ PASS | Two O(1) Dict lookups + arithmetic = <10µs credible; 10× headroom realistic |
| 12 | Nested-Dict typing (G-1 workaround) | ✅ PASS | Godot 4.6 still lacks generic-Dict syntax in static var; `save_migration_registry.gd` precedent applies |
| 13 | @export Resource defensive copy at AC-21 budget | ✅ PASS | RefCounted alloc ~5-10µs per call; no GC pause |

### Suggestions Applied This Pass (3 ADR-0008 text edits)

| Suggestion | Applied where |
|---|---|
| Close Verification Required §2 (JSON integer coercion) — already pre-answered | ADR-0008 Engine Compatibility table — §2/§3 marked CLOSED 2026-04-25 |
| Add explicit ADR-0001 amendment-requirement note for future `terrain_changed` signal | ADR-0008 §4 Caching Strategy — paragraph appended after future-caching pseudocode |
| Add Verification §4: confirm story-006 implementation matches ADR-0004 §5b | ADR-0008 Engine Compatibility table — §4 added |

### Concurrent ADR-0004 Erratum (TD-032 A-21 Resolution)

This pass landed an erratum amendment to ADR-0004 to satisfy the godot-specialist CONCERN above. Pattern matches the 2026-04-20 review's ADR-0001 Environment-domain-banner concurrent amendment.

Changes to ADR-0004:
- Last Verified bumped 2026-04-20 → 2026-04-25
- Decision §5: `get_attack_direction` signature 2-arg → 3-arg form `(attacker, defender, defender_facing)` with explanatory comments
- New **§5b Direction Constants (Erratum 2026-04-25)** section added: `ATK_DIR_FRONT/FLANK/REAR` (return values) + `FACING_NORTH/EAST/SOUTH/WEST` (defender_facing input) declared as int constants
- Key Interfaces gdscript block: signature update + 7-constant block prepended above Lifecycle divider
- Changelog row appended

### Post-Cutoff API Inventory (project-wide, delta)

No new post-cutoff APIs introduced by ADR-0008. Inventory unchanged from 2026-04-20:

| API | Version | ADR | Status |
|-----|---------|-----|--------|
| Typed signals with Resource payloads | 4.2+ (strictness 4.5) | ADR-0001 | declared + verified |
| `ResourceLoader.load_threaded_request` | 4.2+ stable | ADR-0002 | declared + verified |
| Recursive Control disable | 4.5+ | ADR-0002 | declared, verification pending |
| `Resource.duplicate_deep(DEEP_DUPLICATE_ALL)` | 4.5+ | ADR-0001 + ADR-0003 + ADR-0004 | declared + verified |
| `DirAccess.get_files_at` | 4.6-idiomatic | ADR-0003 | declared |
| `ResourceSaver.FLAG_COMPRESS` | pre-cutoff | ADR-0003 | declared |

ADR-0008 declared APIs: `class_name X extends RefCounted` + static methods, `static var`, `Dictionary` (untyped per G-1), `JSON.parse_string` / `JSON.new().parse()`, `FileAccess.get_file_as_string`, `Vector2i`, `@export Resource`, `clampi`. **All pre-cutoff and stable in 4.6.** No conflicts. No deprecated API references.

---

## Cross-ADR Conflict Detection (Delta)

Scanned ADR-0008 against ADR-0001/0002/0003/0004:

- **ADR-0001 (GameBus)**: ADR-0008 mentions emitting `terrain_changed(coord: Vector2i)` deferred to caching impl. Signal not yet in ADR-0001's contract. ✅ no conflict at MVP. Future ADR-0001 amendment requirement now documented in ADR-0008 §4 (this pass).
- **ADR-0002 (SceneManager)**: No interaction. ✅
- **ADR-0003 (Save/Load)**: No interaction. ✅
- **ADR-0004 (Map/Grid)**: ADR-0008 references `MapGrid.get_tile(coord)`, `get_attack_direction(atk, def, facing)`, `ATK_DIR_FRONT/FLANK/REAR`. Resolved this pass via concurrent ADR-0004 §5b erratum amendment + 3-arg signature update. ✅ now consistent.
- **damage-calc.md cross-system contract** (ratified 2026-04-18): ADR-0008 honors opaque clamped contract (`terrain_def ∈ [-30, +30]` / `terrain_evasion ∈ [0, 30]`). ✅
- **formation-bonus.md shared cap**: ADR-0008 owns `MAX_DEFENSE_REDUCTION = 30` and exposes `max_defense_reduction()` static accessor — single source of truth. ✅

No conflicts detected after concurrent ADR-0004 erratum applied this pass.

---

## ADR Dependency Order (updated)

```
Foundation (all Accepted):
  1. ADR-0001 ✅  GameBus Autoload (2026-04-18)
  2. ADR-0002 ✅  Scene Manager   (2026-04-18; requires ADR-0001)
  3. ADR-0003 ✅  Save/Load        (2026-04-18; requires ADR-0001 + ADR-0002)
  4. ADR-0004 ✅  Map/Grid Data Model (2026-04-20; concurrent ADR-0001 amendment;
                   2026-04-25 erratum: §5b Direction Constants + 3-arg get_attack_direction)
Core (this review):
  5. ADR-0008 ✅  Terrain Effect (2026-04-25; depends on ADR-0001 + ADR-0004;
                   soft-depends on unwritten ADR-0006/0009 — API-stable workaround documented)
```

No dependency cycles. No unresolved Proposed-status references.

**Soft dependencies acknowledged** (non-blocking, documented in ADR-0008 §Migration Plan):
- ADR-0006 Balance/Data (NOT YET WRITTEN) — config-loading pipeline migration is API-stable
- ADR-0009 Unit Role (NOT YET WRITTEN) — populates cost_matrix values; structure already defined

---

## GDD Revision Flags (Delta)

### terrain-effect.md OQ-7 — close-as-resolved (no actual inconsistency)

**OQ-7** (line 732 of terrain-effect.md) flags an "elevation percentage inconsistency" between the CR-2 table and AC-3 — but on careful read, the OQ wording is itself confused:

- **CR-2 table** (lines 108–112): delta=+2 → +15% attack
- **AC-3** (line 692): "Attacker at elevation 2 vs. defender at elevation 0 deals 15% more damage" — this IS delta=+2 → +15%

The OQ falsely claims AC-3 corresponds to "delta=+1 row, not +2" — but elevation 2 vs elevation 0 is unambiguously delta=+2. CR-2 and AC-3 are internally consistent.

**Action**: Recommend systems-designer close OQ-7 in `terrain-effect.md` Open Questions table as resolved with no GDD revision required. ADR-0008 already encodes the correct CR-2 values per its `_elevation_table` JSON schema.

Carried forward from prior reviews (unchanged):
| GDD | Flag | Source | Action |
|---|---|---|---|
| `turn-order.md` | `battle_ended` emitter ownership moved to Grid Battle | ADR-0001 | GDD v-next required |
| `grid-battle.md` | `battle_complete` → `battle_outcome_resolved` rename | ADR-0001 | GDD v5.0 pending |

---

## Advisory Findings (non-blocking, carried to implementation)

### ADV-1: ADR-0001 amendment when caching lands

When the future-caching implementation in ADR-0008 §4 lands, adding `terrain_changed(coord: Vector2i)` to GameBus's signal contract requires a formal ADR-0001 amendment — not informal addition. Documented in ADR-0008 §4 (this pass). Pattern reference: ADR-0004's Environment-domain-banner amendment.

### ADV-2: ADR-0004 §5b implementation drift watchpoint

ADR-0004 §5b (Erratum 2026-04-25) declares `ATK_DIR_FRONT/FLANK/REAR` and `FACING_NORTH/EAST/SOUTH/WEST` as int constants on MapGrid. Story-006 (when authored) must implement these names and the 3-arg `get_attack_direction` signature exactly. If implementation drift occurs, treat as ADR-0004 follow-up amendment, not ADR-0008 revision (per ADR-0008 Verification Required §4 added this pass).

---

## Architecture Document Coverage

`docs/architecture/architecture.md` exists but was not updated with ADR-0008 entries this pass. Re-evaluation at ≥6 ADRs remains the guidance from 2026-04-18 report. Current count is 5.

---

## Verdict: **PASS**

ADR-0008 Status: Proposed → **Accepted (2026-04-25)**.
ADR-0004 Status: Accepted (unchanged) — concurrent erratum amendment applied (TD-032 A-21 resolved).

Project now has 5 Accepted ADRs (4 Foundation + 1 Core). Coverage gaps from 2026-04-18 / 2026-04-20 reports (Input, Balance/Data, Hero DB, Formation Bonus, Damage Calc, Destiny Branch, Destiny State ADRs) remain as pre-production pipeline advisories — still expected work, still non-blocking.

### Required ADRs (prioritized, carried forward)

1. ~~ADR-0004 — Map/Grid data model~~ ✅ Accepted 2026-04-20 (+ erratum 2026-04-25)
2. ~~ADR-0008 — Terrain Effect evaluation~~ ✅ **Accepted this review**
3. **ADR-0005** — Input System (Godot 4.5 InputMap changes = MEDIUM engine risk)
4. **ADR-0006** — Balance Data resources (blocks Hero DB; ADR-0008 has API-stable workaround pending)
5. **ADR-0007** — Hero Database schema (depends on ADR-0006)
6. **ADR-0009** — Unit Role / Formation Bonus (depends on ADR-0004; populates ADR-0008 cost_matrix)
7. **ADR-0010** — Destiny Branch
8. **ADR-0011** — Destiny State (depends on ADR-0003)

### Gate Guidance

`/create-epics layer: core` is now unblocked for the terrain-effect epic. Optional sequencing question for the user: should terrain-effect epic creation wait for ADR-0006 (Balance/Data) so the JSON-vs-`.tres` config migration question is settled before epic stories enumerate test fixtures? ADR-0008's API-stable migration plan makes either ordering safe.

---

## Phase 8 — Writes

- ✅ `docs/architecture/ADR-0008-terrain-effect.md` — Status Proposed → Accepted; Last Verified added; Decision Makers updated; Verification §2/§3 closed, §4 added; §4 ADR-0001 amendment-requirement note appended
- ✅ `docs/architecture/ADR-0004-map-grid-data-model.md` — Last Verified bumped; Decision §5 + Key Interfaces 3-arg signature; new §5b Direction Constants section; 7-constant block in Key Interfaces; Changelog row
- ✅ `docs/architecture/tr-registry.yaml` — v3 → v4; last_updated 2026-04-25; 18 new TR-terrain-effect-001..018 entries appended
- ✅ `docs/architecture/architecture-traceability.md` — Version 0.2 → 0.3; 30 → 48 registered TRs; Core layer 0/2 → 1/2; 18 new TR rows appended
- ✅ `docs/architecture/architecture-review-2026-04-25.md` — this delta report
- ✅ `production/session-state/active.md` — Phase 8 silent append + Status Line Block update
- ⏭ `docs/consistency-failures.md` — does not exist; no CONFLICT entries to log per skill convention (don't create)

---

## Chain-of-Verification

5 challenge questions asked of the artifact set after writes; verdict **unchanged (PASS)**:

1. Does the ADR-0004 erratum break any existing 2-arg call site in ADR-0004 itself? — Audited: no other references to `get_attack_direction` exist in ADR-0004 except the two updated lines. ✅
2. Does ADR-0008 §Decision 3 still compile against the post-erratum ADR-0004 §5b? — Yes; constants `ATK_DIR_FLANK`/`ATK_DIR_FRONT` referenced by ADR-0008 are now defined. ✅
3. Does the godot-specialist Item 4 disagreement note hold up under boolean truth-table check? — Verified manually: ADR's `typeof(value) != TYPE_FLOAT or value != int(value)` correctly accepts `30.0` (typeof IS TYPE_FLOAT → first false; 30.0 == 30 → second false; pass), correctly rejects `15.9` (second clause fires), correctly rejects `"foo"` (first clause fires). Specialist's simplification would weaken non-numeric defense. ✅
4. Does the OQ-7 close-as-resolved hold? — Re-checked terrain-effect.md lines 109/111 (CR-2 delta=−1/+1 rows = ±8%) and AC-3 line 692 ("elevation 2 vs elevation 0" = delta=+2 = +15%). OQ-7's premise that AC-3 corresponds to delta=+1 is unambiguously wrong. ✅
5. Are TR-terrain-effect-006 (CR-3d "min damage = 1") and TR-terrain-effect-011 (damage-calc cross-system contract) consistent with damage-calc.md §F? — Yes: ADR-0008 explicitly delegates min-damage enforcement to Damage Calc, matching the 2026-04-18 ratified contract. ✅
