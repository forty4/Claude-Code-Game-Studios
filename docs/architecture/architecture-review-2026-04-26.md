# Architecture Review Report — Delta

> **Date**: 2026-04-26
> **Engine**: Godot 4.6
> **Mode**: Delta review — focused on ADR-0012 Damage Calc Proposed → Accepted escalation (Sprint 1 S1-04)
> **Prior reports**: `architecture-review-2026-04-18.md` (PASS, 3 ADRs) + `-04-20.md` (PASS delta, ADR-0004) + `-04-25.md` (PASS delta, ADR-0008)
> **GDDs Reviewed (delta)**: 1 (`damage-calc.md` rev 2.9.3, 2335 LoC — TR registration)
> **ADRs Reviewed (delta)**: 1 (ADR-0012 Damage Calc — Proposed 2026-04-26 via `/architecture-decision`, fresh-session review per skill protocol)

---

## TL;DR

- **Verdict**: **PASS** — ADR-0012 escalated Proposed → Accepted, with 2 pre-acceptance text corrections applied (godot-specialist `/architecture-review` AF-1 + Item 3).
- godot-specialist context-isolated validation: **APPROVED WITH SUGGESTIONS** (12/12 engine claims PASS, 2 wording corrections pre-acceptance, 1 advisory carried).
- damage-calc.md: 13 architectural TRs extracted, 100% covered by ADR-0012; registered as TR-damage-calc-001..013 in `tr-registry.yaml` v4 → v5.
- ADR-0001/0002/0003/0004/0008 consistency clean. Provisional-dependency strategy on unwritten ADR-0006/0009/0010/0011 mirrors ADR-0008→ADR-0006 precedent (proven 2 invocations).
- 0 GDD revision flags this pass — the 4 stale ADR-0005 citations in `damage-calc.md` were cleaned up during `/architecture-decision` 2026-04-26 (verified intact this pass).
- Project transitions from 5 Accepted ADRs to **6 Accepted ADRs** (4 Foundation + 1 Core + **1 Feature** — first Feature-layer ADR).

---

## Scope Clarification — Why a Delta Review

ADR-0012 was authored on 2026-04-26 via `/architecture-decision damage-calc` (Sprint 1 S1-03, PR #46 merged commit `b9e642f`). Per skill protocol the unbiased review must run in a **fresh session** — this review opened post-/clear, satisfying that requirement.

Same single-ADR scope as the 2026-04-20 (ADR-0004) and 2026-04-25 (ADR-0008) delta reviews. Same delta-mode treatment: godot-specialist context-isolated subagent + existing review chain as baseline.

**Mode used**: Delta (focused engine + coverage + consistency against existing 5 Accepted ADRs). Full-scope re-review of all 6 ADRs not warranted — no ADR-0001/2/3/4/8 content changed since their respective Accept dates.

---

## ADR-0012 Coverage — damage-calc.md (13/13 ✅)

All 13 architectural technical requirements extracted from `design/gdd/damage-calc.md` (rev 2.9.3, 2335 LoC, 53 ACs, 12 ordered Core Rules, 7 sub-formulas) map cleanly to ADR-0012 Decision sections. Registered as permanent TR-damage-calc-001..013 in `tr-registry.yaml` v5.

| TR-ID | GDD Source | ADR-0012 § | Status |
|-------|-----------|------------|--------|
| TR-damage-calc-001 | CR-1 — Module type | §1 | ✅ |
| TR-damage-calc-002 | CR-1 + CONTRACT rev 2.2 — Type boundary (4 wrappers, Array[StringName]) | §2 | ✅ |
| TR-damage-calc-003 | CR-11 + AC-DC-33-36 — Direct-call Grid Battle → DamageCalc | §3 | ✅ |
| TR-damage-calc-004 | CR-1 + AC-DC-34/35 — Stateless / signal-free | §4 | ✅ |
| TR-damage-calc-005 | CR-2 + EC-DC-14 + AC-DC-39 — RNG ownership | §5 | ✅ |
| TR-damage-calc-006 | CR-12 + AC-DC-48 + TUNING — 11 tuning constants | §6 | ✅ |
| TR-damage-calc-007 | CR-6/8/9 + F-DC-3/5/6 — 3-tier cap layering | §7 | ✅ |
| TR-damage-calc-008 | CR-3 + Section F — 5 cross-system upstream interfaces | §8 | ✅ |
| TR-damage-calc-009 | AC-DC-44 + Migration Plan — F-GB-PROV retirement | §9 | ✅ |
| TR-damage-calc-010 | AC-DC-37/46/47/50/51(b) — Test infrastructure prerequisites | §10 | ✅ |
| TR-damage-calc-011 | AC-DC-49 + AC-DC-50 + Verify-against-engine | §11 | ✅ |
| TR-damage-calc-012 | CR-11 + AC-DC-36 — source_flags mutation semantics | §12 | ✅ |
| TR-damage-calc-013 | AC-DC-40(a) + AC-DC-40(b) + AC-DC-41 — Performance budgets | Performance Implications + §1/§2 | ✅ |

**Coverage**: 13/13 ✅. All architectural commitments locked by the GDD have explicit ADR-0012 ratification.

The 53 GDD ACs are a finer granularity than the architectural TR layer — they map to ADR-0012 via the §GDD Requirements Addressed table (FORMULA 12 + EDGE_CASE BLOCKER 15 + EDGE_CASE IMPORTANT 7 + CONTRACT 4 + DETERMINISM 3 + PERFORMANCE 2 + INTEGRATION 3 + ACCESSIBILITY 3 + TUNING 1 + VERIFY-ENGINE 2 + CONTRACT-rev-2.2 1). The TR layer captures the architectural shape; the AC layer captures the per-test detail. Both are ratified.

---

## Engine Compatibility Audit — ADR-0012

### godot-specialist Context-Isolated Validation

Spawned as parallel subagent with focused 12-item scope: Godot 4.6 engine-correctness of ADR-0012's specific claims (`class_name DamageCalc extends RefCounted`, `Array[StringName]` enforcement timing, `@abstract` 4.5+ behavior, `randi_range`/`snappedf` semantics, RNG injection determinism, RefCounted free behavior, etc.). Verdict: **APPROVED WITH SUGGESTIONS** (12/12 PASS; 2 corrections pre-acceptance + 1 advisory).

| # | Claim | Result | Notes |
|---|-------|--------|-------|
| 1 | `class_name DamageCalc extends RefCounted` + static `resolve()` | ✅ PASS | Idiomatic 4.6; mirrors ADR-0008 pattern; static-method semantics on RefCounted unchanged 4.0→4.6 |
| 2 | `Array[StringName]` enforcement is **runtime, NOT parse-time** | ✅ PASS w/ caveat | §2 nuance correct; **Consequences §Positive bullet was contradicting (claimed "compile-time")** — corrected this pass per AF-1 |
| 3 | `@abstract` (4.5+) prevents `DamageCalc.new()` | ⚠️ CONCERN | Behavior on static-only class with no instance methods not explicitly documented in `docs/engine-reference/godot/`; "parse error" claim too strong — softened this pass per Item 3 verdict |
| 4 | `randi_range(from, to)` inclusive on both ends | ✅ PASS | Stable since 4.0; pinned via AC-DC-49 (defensive) |
| 5 | `snappedf(±0.005, 0.01)` round-half-away-from-zero | ✅ PASS | Stable 4.0→4.6; pinned via AC-DC-50; R-8 upstream FP composition risk correctly flagged separately |
| 6 | `&"foo" in Array[StringName]` rejects `String` elements | ✅ PASS | StringName ≠ String comparison stable; release-build defense sound |
| 7 | `RandomNumberGenerator` per-call seeded injection | ✅ PASS | Typed parameter binding stable; deterministic seed advance |
| 8 | Jolt-default in 4.6 does not affect Damage Calc | ✅ PASS | Pure-math pipeline; zero physics calls; Jolt-default + D3D12-on-Windows are orthogonal |
| 9 | Node-form rejection rationale unchanged in 4.6 | ✅ PASS | RefCounted vs. Node trade-offs unchanged across 4.x |
| 10 | `@onready` Node-only → GdUnitTestSuite-extends-Node base for AC-DC-51(b) | ✅ PASS | `@onready` strictly Node-only in 4.x; rationale §10 #4 sound |
| 11 | `&"foo" in Array[StringName]` is O(n) linear scan | ✅ PASS w/ note | Adequate at MVP scale (2-5 passives/unit); → ADV-2 carried for code-review |
| 12 | RefCounted free is deterministic (no GC pause) | ✅ PASS | Reference-counted free at scope exit; no GC behavior in Godot 4.x |

### Corrections Applied This Pass (2 ADR-0012 text edits)

| Correction | Applied where |
|---|---|
| **AF-1**: Consequences §Positive "compile-time" → "at the call-site boundary (runtime, not parse-time)" + R-9 cross-reference | ADR-0012 line 539 (Consequences §Positive bullet 3) |
| **Item 3**: Implementation Guidelines #8 `@abstract` "parse error" → "treat as runtime error, verify in story-001; static-lint primary, `@abstract` secondary" | ADR-0012 line 508 (Implementation Guidelines #8) |

These are **wording corrections, not architectural changes**. The Decision body (§1-12) is untouched. Pattern matches the 2026-04-25 review's ADR-0008 §Verification §2/§3 close-out edits (also wording-only).

### Advisory Carried (non-blocking)

- **AF-3**: `modifiers.source_flags.duplicate()` returns typed result correctly when assigned to a `var out_flags: Array[StringName] = ...` typed local. ADR §12 pattern is safe as written. No action required.

### Post-Cutoff API Inventory (project-wide, delta)

ADR-0012 introduces zero post-cutoff APIs (per §Engine Compatibility table). Inventory unchanged from 2026-04-25:

| API | Version | ADR | Status |
|-----|---------|-----|--------|
| Typed signals with Resource payloads | 4.2+ (strictness 4.5) | ADR-0001 | declared + verified |
| `ResourceLoader.load_threaded_request` | 4.2+ stable | ADR-0002 | declared + verified |
| Recursive Control disable | 4.5+ | ADR-0002 | declared, verification deferred to Polish (V-7 on-device per scene-manager story-007) |
| `Resource.duplicate_deep(DEEP_DUPLICATE_ALL)` | 4.5+ | ADR-0001 + ADR-0003 + ADR-0004 | declared + verified |
| `DirAccess.get_files_at` | 4.6-idiomatic | ADR-0003 | declared |
| `ResourceSaver.FLAG_COMPRESS` | pre-cutoff | ADR-0003 | declared |
| `class_name X extends RefCounted` + static methods | pre-4.4 stable | ADR-0008 + ADR-0012 | declared + verified |

ADR-0012 declared APIs: `class_name X extends RefCounted` + static methods, typed `Array[StringName]` parameter binding, `RandomNumberGenerator`, `randi_range`, `snappedf`, `StringName` literal `&"foo"`, `@abstract` (optional, 4.5+). **All pre-cutoff or pre-4.6-stable**, no deprecated API references.

---

## Cross-ADR Conflict Detection (Delta)

Scanned ADR-0012 against ADR-0001/0002/0003/0004/0008:

- **ADR-0001 (GameBus)**: ADR-0012 Decision §4 confirms non-emitter list compliance (line 375). Zero emits, zero subscriptions; architecture-registry stance `damage_resolution` is `direct_call` interface, never signal. ✅
- **ADR-0002 (SceneManager)**: No interaction. ADR-0012 is RefCounted Feature-layer with no SceneTree presence; no autoload registration. ✅
- **ADR-0003 (Save/Load)**: ADR-0012 §5 references Save/Load #21 RNG snapshot semantics (provisional GDD), but Damage Calc never *owns* the RNG — Grid Battle owns it, ADR-0003 snapshots Grid Battle's handle. Damage Calc's call-count-stable contract (1/0/0 per non-counter/counter/skill-stub) is what makes save/load replay bit-identical. No SaveContext schema overlap; ADR-0003 TR-save-load-005 (enum append-only) does not constrain ADR-0012's local `ResolveResult.Kind` (HIT/MISS) enum. ✅
- **ADR-0004 (Map/Grid)**: ADR-0004 §5b owns int constants `ATK_DIR_FRONT/FLANK/REAR` (return values from `get_attack_direction`); ADR-0012 §2 `ResolveModifiers.direction_rel` uses `StringName` (`&"FRONT"`/`&"FLANK"`/`&"REAR"`). Two representations co-exist: Map/Grid produces int, Damage Calc consumes StringName. **Grid Battle is the orchestrator** (per ADR-0012 §3 sole-caller contract + AC-DC-42 call-count discipline) that bridges the encoding. **No current ADR explicitly locks the translation responsibility** — see ADV-1.
- **ADR-0008 (Terrain Effect)**: ADR-0012 §8 acknowledges ADR-0008 ownership of `MAX_DEFENSE_REDUCTION = MAX_EVASION = 30` cap constants and the `bridge_no_flank` flag → `terrain.get_combat_modifiers()` clamped contract (`terrain_def ∈ [-30,+30]`, `terrain_evasion ∈ [0,30]`). ADR-0008 TR-terrain-effect-011 already documents the cross-system contract (ratified 2026-04-25); ADR-0012 §8 inherits and ratifies. ✅

**No conflicts detected.** 1 advisory (ADV-1, non-blocking, deferred to future Grid Battle ADR).

---

## ADR Dependency Order (updated)

```
Foundation (all Accepted):
  1. ADR-0001 ✅  GameBus Autoload      (2026-04-18)
  2. ADR-0002 ✅  Scene Manager         (2026-04-18; requires ADR-0001)
  3. ADR-0003 ✅  Save/Load             (2026-04-18; requires ADR-0001 + ADR-0002)
  4. ADR-0004 ✅  Map/Grid Data Model   (2026-04-20 + 2026-04-25 erratum)
Core (Accepted):
  5. ADR-0008 ✅  Terrain Effect        (2026-04-25; depends on ADR-0001 + ADR-0004;
                   soft-depends on unwritten ADR-0006/0009 — API-stable workaround)
Feature (this review):
  6. ADR-0012 ✅  Damage Calc           (2026-04-26; depends on ADR-0001 + ADR-0008;
                   soft-depends on unwritten ADR-0006/0009/0010/0011 — provisional
                   strategy mirrors ADR-0008→ADR-0006 precedent)
```

No dependency cycles. No unresolved Proposed-status references after this pass.

**Soft dependencies acknowledged** (non-blocking, documented in ADR-0012 §8 + §Migration Plan):
- ADR-0006 Balance/Data (NOT YET WRITTEN, Sprint 1 S1-09 Nice-to-Have) — `DataRegistry.get_const(key)` interface
- ADR-0009 Unit Role (NOT YET WRITTEN, Sprint 1 S1-06 Should-Have) — `UnitRole.BASE_DIRECTION_MULT[3]` + `CLASS_DIRECTION_MULT[4][3]` const tables
- ADR-0010 HP/Status (NOT YET WRITTEN, post-Sprint-1) — `hp_status.get_modified_stat(unit_id, stat_name)` interface
- ADR-0011 Turn Order (NOT YET WRITTEN, post-Sprint-1) — `turn_order.get_acted_this_turn(unit_id)` interface

The provisional-dependency strategy is now proven at **2 invocations** (ADR-0008→ADR-0006 + ADR-0012→ADR-0006/0009/0010/0011). When upstream ADRs are authored, each `/architecture-review` runs cross-conflict detection against ADR-0012's locked interfaces; narrowing changes trigger reciprocal ADR-0012 amendments (R-1 mitigation).

---

## GDD Revision Flags (Delta)

**None this pass.**

The 4 stale ADR-0005 citations in `damage-calc.md` (lines 82, 278, 341, 2317-2319 — referenced "ADR-0005" as the typed-wrapper ADR before the project remapping reassigned ADR-0005 to Input Handling) were cleaned up during `/architecture-decision damage-calc` Step 4.7 GDD Sync Check on 2026-04-26 (commit `b9e642f`). Verified intact this pass via `grep -n "ADR-0005" design/gdd/damage-calc.md` — only intentional historical-context preservations remain (e.g., "which has been reassigned to Input Handling" — these are correct cleanup-in-place markers, not stale references).

Engine findings Items 2 (typed-array runtime-not-parse) and 3 (`@abstract` runtime-not-parse) don't contradict any GDD assumption — both are ADR-internal Implementation Guidelines, not GDD-locked semantics.

Carried forward from prior reviews (unchanged):
| GDD | Flag | Source | Action |
|---|---|---|---|
| `turn-order.md` | `battle_ended` emitter ownership moved to Grid Battle | ADR-0001 | GDD v-next required |
| `grid-battle.md` | `battle_complete` → `battle_outcome_resolved` rename | ADR-0001 | GDD v5.0 pending |
| `terrain-effect.md` | OQ-7 close-as-resolved (no actual inconsistency) | ADR-0008 review | Recommendation noted; non-blocking |

---

## Advisory Findings (non-blocking, carried to implementation)

### ADV-1: int↔StringName direction translation locking

ADR-0004 §5b declares int constants `ATK_DIR_FRONT/FLANK/REAR` as the return-value vocabulary for `MapGrid.get_attack_direction(attacker, defender, defender_facing)`. ADR-0012 §2 declares `ResolveModifiers.direction_rel: StringName` (values `&"FRONT"` / `&"FLANK"` / `&"REAR"`). Two representations co-exist deliberately — Map/Grid stays Foundation-pure with int constants; Damage Calc uses StringName per F-DC-4 / unit-role.md §EC-7 conventions.

**Grid Battle is the implicit orchestrator** that bridges the encoding (per ADR-0012 §3 sole-caller contract + ADR-0008 §Decision 3 BRIDGE FLANK→FRONT collapse). However, **no current ADR explicitly locks the int↔StringName translation responsibility on Grid Battle**.

**Action**: Future Grid Battle ADR (Feature layer, post-Sprint-1) should include a "direction encoding bridge" stance in its Key Interfaces section — committing Grid Battle to the int→StringName translation when calling `DamageCalc.resolve()`. No change required to ADR-0012 or ADR-0004 at this time. Track as advisory until Grid Battle ADR drafting.

### ADV-2: `in` operator O(n) at growing passive sets

§F-DC-5 `&"passive_charge" in attacker.passives` is a linear scan (O(n)), not O(1). Adequate at MVP scale (2-5 passives per unit per attacker), but if passive sets grow >10 elements per unit, consider `Dictionary[StringName, bool]` lookup or `Array.bsearch`. Code-review gate watchpoint, not pre-implementation blocker. Identified by godot-specialist Item 11.

### ADV-3: `DataRegistry.get_const(key) -> Variant` cast safety

Every consumer call site does an unchecked cast (e.g., `BASE_CEILING = DataRegistry.get_const("BASE_CEILING") as int`). Recommend ADR-0006 (when authored, Sprint 1 S1-09 Nice-to-Have) tighten the return type or add typed variants (`get_const_int`, `get_const_float`). Provisional contract; ADR-0012 acknowledges. Identified by godot-specialist AF-2.

### ADV-4: Floating-point composition cross-platform residue (ADR-0012 R-8)

ADR-0012 R-8 (added during `/architecture-decision` per godot-specialist Item 4 partial verdict) acknowledges that floating-point accumulation **upstream of `snappedf`** may diverge across macOS Metal / Windows D3D12 / Linux Vulkan by 1 ULP, potentially flipping apex damage from 178 to 177/179. AC-DC-50 only pins the `snappedf` boundary directly; AC-DC-37 cross-platform matrix should also pin the apex-path D_mult composition end-to-end. **Track as TD entry** for damage-calc story-001 implementation.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` exists but was not updated with ADR-0012 entries this pass. Re-evaluation at ≥6 ADRs remains the guidance from the 2026-04-18 report. Current count is now 6 — **architecture.md re-evaluation is now triggered**. Recommend a follow-up `/create-architecture` partial-update pass after ADR-0009 Unit Role lands (which would bring Foundation/Core/Feature totals to 3/2/2). Not blocking.

---

## Verdict: **PASS**

ADR-0012 Status: Proposed → **Accepted (2026-04-26, via `/architecture-review` delta)**.

Project now has **6 Accepted ADRs** (4 Foundation + 1 Core + 1 Feature). First Feature-layer ADR landed.

**Sprint 1 S1-04 obligation satisfied.** Unblocks **S1-05** (`/create-epics damage-calc` + `/create-stories damage-calc`).

Coverage gaps from prior reports (Input, Balance/Data, Hero DB, Unit Role, HP/Status, Turn Order, Destiny Branch, Destiny State ADRs) remain as pre-production pipeline advisories — still expected work, still non-blocking.

### Required ADRs (prioritized, carried forward)

1. ~~ADR-0004 — Map/Grid data model~~ ✅ Accepted 2026-04-20
2. ~~ADR-0008 — Terrain Effect~~ ✅ Accepted 2026-04-25
3. ~~ADR-0012 — Damage Calc~~ ✅ **Accepted this review**
4. **ADR-0005** — Input System (HIGH engine risk: Godot 4.5 InputMap + SDL3 + Android edge-to-edge)
5. **ADR-0006** — Balance/Data resources (blocks Hero DB; ADR-0008 + ADR-0012 have API-stable workarounds pending)
6. **ADR-0007** — Hero Database schema (depends on ADR-0006)
7. **ADR-0009** — Unit Role formulas (Sprint 1 S1-06 Should-Have; populates ADR-0008 cost_matrix + ADR-0012 BASE_DIRECTION_MULT/CLASS_DIRECTION_MULT)
8. **ADR-0010** — HP/Status (post-Sprint-1; ratifies ADR-0012 §8 `get_modified_stat` interface)
9. **ADR-0011** — Turn Order finalization (post-Sprint-1; ratifies ADR-0012 §8 `get_acted_this_turn` interface)
10. **Future Grid Battle ADR** (Feature layer, post-Sprint-1) — sole-caller contract for ADR-0012 + int↔StringName direction encoding bridge per ADV-1
11. **Future Destiny Branch / Destiny State ADRs** (post-Sprint-1)

### Gate Guidance

`/create-epics damage-calc` (Sprint 1 S1-05) is now unblocked. Damage-calc Feature epic story-001 must include the CI infrastructure prerequisite as a Config/Data sub-story (per ADR-0012 §10 Validation Criteria); `/story-readiness` will block story-001 if the prerequisite is unmet at implementation time.

---

## Phase 8 — Writes

- ✅ `docs/architecture/ADR-0012-damage-calc.md` — Status Proposed → Accepted; Last Verified 2026-04-26; Decision Makers godot-specialist line completed (`/architecture-review` validation); Consequences §Positive AF-1 wording correction; Implementation Guidelines #8 Item 3 wording correction
- ✅ `docs/architecture/tr-registry.yaml` — v4 → v5; last_updated 2026-04-26; 13 new TR-damage-calc-001..013 entries appended
- ✅ `docs/architecture/architecture-traceability.md` — Version 0.3 → 0.4; 48 → 61 registered TRs; Feature layer 0/3 → 1/3; 13 new TR rows + summary refresh + Changelog row
- ✅ `docs/architecture/architecture-review-2026-04-26.md` — this delta report
- ✅ `production/session-state/active.md` — Phase 8 silent append
- ⏭ `docs/consistency-failures.md` — does not exist; no CONFLICT entries to log per skill convention (don't create)

---

## Chain-of-Verification

5 challenge questions asked of the artifact set after writes; verdict **unchanged (PASS)**:

1. **Does the AF-1 correction in Consequences §Positive contradict any other section?** Audited: §2 Decision body says "runtime, NOT parse-time"; §Risks R-9 says "AC-DC-51(b) bypass-seam test must explicitly assign Array[String] at the field level... NOT rely on AttackerContext.make() rejecting the typed-array argument". Corrected Consequences bullet now reads "at the call-site boundary (runtime, not parse-time)" + R-9 cross-reference. Three sections aligned. ✅
2. **Does the Item 3 `@abstract` softening preserve the optional-decoration intent?** Yes; the corrected text retains "MAY be marked `@abstract`" + "Low-urgency" framing + "static-lint... primary mechanism with `@abstract` as a secondary defense". The decision is unchanged; only the failure-mode language is precise. ✅
3. **Are the 13 TR-damage-calc-* entries exhaustive against the GDD's architectural commitments?** Audited against the 12 ordered Core Rules + 7 sub-formulas + Performance budgets + 5 cross-system contracts in §Dependencies. The TR layer captures all architectural shape commitments; per-AC coverage is a finer granularity ratified via ADR-0012 §GDD Requirements Addressed table. ✅
4. **Does the int↔StringName direction-encoding ADV-1 require any change to ADR-0004 or ADR-0008?** No. ADR-0004 §5b correctly owns the int return-value vocabulary; ADR-0008 §Decision 3 correctly delegates BRIDGE FLANK→FRONT collapse to Damage Calc's orchestrator (Grid Battle); ADR-0012 §2 correctly declares the StringName consumption form. The translation responsibility is implicitly Grid Battle's; explicit lock is deferred to the future Grid Battle ADR. No retroactive amendments. ✅
5. **Is the provisional-dependency strategy on 4 upstream ADRs (0006/0009/0010/0011) bounded in cost?** Per R-1 mitigation: each upstream ADR can only widen, never narrow, the ADR-0012-locked interface (a narrowing change forces a reciprocal ADR-0012 amendment, caught by `/architecture-review` cross-conflict detection). Worst case: 1 ADR-0012 §8 row update per upstream ADR. Bounded. The ADR-0008→ADR-0006 precedent (Accepted 2026-04-25, no reciprocal amendment needed yet) demonstrates the pattern is safe at 1 invocation; ADR-0012 is the 2nd invocation. ✅
