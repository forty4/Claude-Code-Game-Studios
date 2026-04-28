# Architecture Review Report — Delta

> **Date**: 2026-04-28
> **Engine**: Godot 4.6
> **Mode**: Delta review — focused on ADR-0009 Unit Role Proposed → Accepted escalation (Sprint 1 S1-07)
> **Prior reports**: `architecture-review-2026-04-18.md` (PASS, 3 ADRs) + `-04-20.md` (PASS delta, ADR-0004) + `-04-25.md` (PASS delta, ADR-0008) + `-04-26.md` (PASS delta, ADR-0012)
> **GDDs Reviewed (delta)**: 1 (`unit-role.md` rev 2026-04-16, ~1037 LoC — TR registration)
> **ADRs Reviewed (delta)**: 1 (ADR-0009 Unit Role — Proposed 2026-04-28 via `/architecture-decision`, fresh-session review per skill protocol)

---

## TL;DR

- **Verdict**: **PASS** — ADR-0009 escalated Proposed → Accepted, with 1 pre-acceptance text correction applied to ADR-0009 + 1 same-patch cross-ADR amendment to ADR-0012 (godot-specialist `/architecture-review` Item 1 + Item 8).
- godot-specialist independent review-time validation: **APPROVED WITH SUGGESTIONS** (8/8 PASS-or-CONCERN; 2 corrections applied pre-acceptance + 1 advisory carried).
- unit-role.md: 12 architectural TRs extracted, 100% covered by ADR-0009; registered as TR-unit-role-001..012 in `tr-registry.yaml` v5 → v6. The 23 GDD ACs (AC-1..AC-23) map to the TR layer + ADR-0009 §GDD Requirements Addressed table.
- ADR-0001/0002/0003/0004/0006/0008/0012 cross-conflict scan: clean except for the ADR-0012 `[4][3]` dimension stale reference (corrected this pass; one-line same-patch amendment).
- 0 GDD revision flags this pass — the stale `balance_constants.json` references in `unit-role.md` were pre-emptively patched during ADR-0009 authoring (verified intact: §Formulas note + Global Constant Summary Source column + Dependencies upstream Balance/Data row).
- Project transitions from 6 Accepted ADRs to **7 Accepted ADRs** (4 Foundation + 1 Core + 1 Feature + 1 Foundation-stateless-calculator for Unit Role per ADR-0009 §Engine Compatibility "Foundation — stateless gameplay rules calculator").

---

## Scope Clarification — Why a Delta Review

ADR-0009 was authored on 2026-04-28 via `/architecture-decision unit-role` (Sprint 1 S1-06, commit `f4f1915` already PUSHED to origin/main this session per active.md line 149). Per skill protocol the unbiased review must run in a **fresh session** — this review opened post-`/clear` with TG-2 sync gate satisfied (0/0 ahead/behind, clean tree).

Same single-ADR scope as the 2026-04-20 (ADR-0004) and 2026-04-25 (ADR-0008) and 2026-04-26 (ADR-0012) delta reviews. Same delta-mode treatment: godot-specialist context-isolated subagent (review-time INDEPENDENT second opinion, separate from the 2026-04-28 design-time validation already incorporated into ADR-0009 line 15) + existing review chain as baseline.

**Mode used**: Delta (focused engine + coverage + consistency against existing 6 Accepted ADRs). Full-scope re-review of all 7 ADRs not warranted — no ADR-0001/2/3/4/6/8/12 content changed since their respective Accept dates, except the ADR-0012 line 42 stale dimension reference corrected this pass.

---

## ADR-0009 Coverage — unit-role.md (12/12 ✅)

All 12 architectural technical requirements extracted from `design/gdd/unit-role.md` (rev 2026-04-16, 1037 LoC, 23 ACs, 6 ordered Core Rules, 5 sub-formulas F-1..F-5, 17 Edge Cases EC-1..EC-17) map cleanly to ADR-0009 Decision sections + Engine Compatibility / Validation Criteria. Registered as permanent TR-unit-role-001..012 in `tr-registry.yaml` v6.

| TR-ID | GDD Source | ADR-0009 § | Status |
|-------|-----------|------------|--------|
| TR-unit-role-001 | §States and Transitions ("stateless rule definition layer") | §1 | ✅ |
| TR-unit-role-002 | CR-1 (6 classes) | §2 | ✅ |
| TR-unit-role-003 | AC-22 + AC-23 (cross-system contracts: Damage Calc, Grid Battle) | §3 | ✅ |
| TR-unit-role-004 | AC-20 + AC-21 (data-driven, hot-reload limitation) | §4 | ✅ |
| TR-unit-role-005 | AC-1..AC-5 (clamp ranges reference caps) + AC-20 + Engine Compat | §4 + Engine Compat verification 1 | ✅ |
| TR-unit-role-006 | AC-12..AC-15 (terrain movement) + CR-4 + EC-3..EC-5 | §5 | ✅ |
| TR-unit-role-007 | AC-16 + AC-17 (direction multipliers) + CR-6a + EC-7 | §6 | ✅ |
| TR-unit-role-008 | (architectural decision — R-1 mitigation, no direct AC) | §5 R-1 | ✅ |
| TR-unit-role-009 | AC-6..AC-11 (passive activation gates use the tags) + CR-2 | §7 | ✅ |
| TR-unit-role-010 | (cross-ADR: ADR-0001 line 375 non-emitter list) | Engine Compat verification 4 + Validation §4 | ✅ |
| TR-unit-role-011 | AC-1, AC-2, AC-3, AC-4, AC-5 (5 formulas) + EC-1, EC-2, EC-13, EC-14 | §3 + Validation §2 | ✅ |
| TR-unit-role-012 | (NFR — Performance Implications section) | Performance Implications + Engine Compat verification 3 | ✅ |

**Coverage**: 12/12 ✅. All architectural commitments locked by the GDD have explicit ADR-0009 ratification.

The 23 GDD ACs are a finer granularity than the architectural TR layer — they map to ADR-0009 via the §GDD Requirements Addressed table (Stat Derivation 5 + Class Passives 6 + Terrain Movement 4 + Attack Direction 2 + Skill Slots 2 + Data-Driven 2 + Cross-System Contracts 2). The TR layer captures the architectural shape; the AC layer captures the per-test detail. Both are ratified.

---

## Engine Compatibility Audit — ADR-0009

### godot-specialist Context-Isolated Validation (Review-Time INDEPENDENT Second Opinion)

Spawned as parallel subagent with focused 8-item scope, briefed to NOT defer to the prior 2026-04-28 design-time validation (re-derive from first principles against Godot 4.6 reference + ADR-0009 text). Verdict: **APPROVED WITH SUGGESTIONS** (8/8 PASS-or-CONCERN; 2 corrections applied + 1 advisory carried).

| # | Claim | Result | Notes |
|---|-------|--------|-------|
| 1 | §1 Module form: `class_name UnitRole extends RefCounted` + `@abstract` + all-static | ✅ PASS w/ correction | 4-precedent pattern (ADR-0008→0006→0012→0009); `@abstract` is 4.5+ confirmed via `breaking-changes.md`. **Correction**: §1 line 130 "parse-time error" → "runtime error" — `@abstract` blocks `.new()` at call time, NOT parse time. Distinction matters for test authoring (must assert runtime rejection, NOT parse rejection). Applied this pass. |
| 2 | §2 UnitClass typed enum parameter binding | ✅ PASS | Stable Godot 4.0→4.6; cross-script qualified reference `UnitRole.UnitClass.CAVALRY` correct in 4.6; "stricter than raw int" defensible (type-checker warnings at call sites, promoted to errors in strict-mode/lint) |
| 3 | §3 `const PASSIVE_TAG_BY_CLASS: Dictionary` enum-int keys + StringName values | ✅ PASS | `const` Dictionary with enum-int keys + `&"foo"` StringName values valid in 4.6; no hashing surprises (enum int = int64); unparameterized `Dictionary` annotation correct (4.x does not support parameterized `const Dictionary[K, V]`) |
| 4 | §4 Lazy-init JSON.new().parse() + safe-default fallback | ✅ PASS w/ advisory | Mirrors ADR-0008 accepted pattern. **Advisory** (low-priority polish): "Thread-safe for read access" claim should be scoped to "single-threaded game logic" to avoid misleading future readers. Single-threaded TOCTOU gap is zero risk for MVP (no `await` inside `_load_coefficients()`). Carried as ADV-2 below. |
| 5 | §5 PackedFloat32Array per-call copy semantics (R-1) | ✅ PASS | Godot 4.x COW confirmed; per-call copy at call boundary; R-1 mitigation shape correct (forbidden_pattern + caller-mutation regression test). Precision note: COW defers actual memory copy until mutation, so a buggy cached-and-returned shared backing WOULD share memory until first mutation — exactly the silent-corruption risk the regression test catches. Mitigation is right as written. |
| 6 | §6 `get_class_direction_mult` reads from `unit_roles.json` not BalanceConstants | ✅ PASS | Design-side / runtime asymmetry explicitly documented + justified (per-class data locality); `entities.yaml` registration is reference-tracking only. Sync risk addressed by `/propagate-design-change` mandate at §Migration Plan §From locked direction multipliers. No gap. |
| 7 | §7 StringName interning reliability | ✅ PASS | Process-global StringName interning in Godot 4.x; `&"passive_charge" == &"passive_charge"` reliable across all call sites. G-20 in project gotchas confirms structural typed-array boundary is correct enforcement point (`==` operator alone is insufficient: `StringName == String` returns true). |
| 8 | CROSS-ADR DIMENSION DISCREPANCY: ADR-0012 `[4][3]` vs ADR-0009 `[6][3]` | ⚠️ CONCERN → corrected | ADR-0012 line 42 (Dependencies field) declares `CLASS_DIRECTION_MULT[4][3]` — stale documentation artifact from before ADR-0009 was written. Authoritative shape is **6×3** (entities.yaml + ADR-0009 §6 + GDD CR-6a all agree on 6 classes; STRATEGIST + COMMANDER are all-1.0 no-op rows by design). One-line same-patch amendment applied to ADR-0012 this pass: ratifies `[6][3]` + acknowledges Status flip Proposed→Accepted of ADR-0009 + documents the 4-vs-6 nuance (4 non-trivial classes, 2 no-op rows). No behavioral change in production code; documentation precision only. |

### Corrections Applied This Pass (1 ADR-0009 + 1 ADR-0012)

| Correction | Applied where |
|---|---|
| **Item 1**: §1 line 130 `parse-time error` → `runtime error` for `UnitRole.new()` under `@abstract`, with test-authoring note added | ADR-0009 line 130 (Decision §1 "Optional `@abstract` decoration" paragraph) |
| **Item 8**: ADR-0012 line 42 (Dependencies field) `CLASS_DIRECTION_MULT[4][3]` → `[6][3]` + Status update from "NOT YET WRITTEN — soft / provisional" → "Accepted 2026-04-28 via /architecture-review delta" + 6-class enumeration + STRATEGIST/COMMANDER no-op explanation | ADR-0012 line 42 (ADR Dependencies → Depends On row, ADR-0009 entry) |

These are **wording corrections, not architectural changes**. The Decision body of both ADRs is otherwise untouched. Pattern matches the 2026-04-26 review's ADR-0012 §Consequences AF-1 + Implementation Guidelines #8 corrections (also wording-only) and the 2026-04-25 review's ADR-0008 §Verification §2/§3 close-out edits.

### Advisory Carried (non-blocking)

- **ADV-1**: §4 "Thread-safe for read access" claim should be scoped to "single-threaded game logic" in ADR-0009 prose to avoid misleading future readers. Low-priority polish; carry to next ADR-0009 amendment OR /create-stories unit-role epic creation pass. Identified by godot-specialist Item 4.

### Independent Review Confirmed/Challenged Prior 2026-04-28 Design-Time Validation

The prior design-time validation (incorporated into ADR-0009 line 15) was largely sound — the 4 design-time notes (typed enum parameter binding improvement, G-15 test isolation, R-1 mutation regression test, static lint for non-emitter invariant) are all correctly identified and adequately addressed in the ADR text.

The independent review caught two precision gaps the design-time validation missed: (a) the `@abstract` "parse-time error" characterization is imprecise (it's a runtime block — Item 1); (b) the ADR-0012 `[4][3]` vs ADR-0009 `[6][3]` discrepancy was not flagged despite ADR-0012 being listed as a reference (Item 8). **Neither is a design-time failure** — they are exactly the kind of precision gaps that cross-session independent review exists to catch. The pattern validates the skill's "fresh session for /architecture-review" protocol at its 4th invocation in this project.

### Post-Cutoff API Inventory (project-wide, delta)

ADR-0009 introduces zero post-cutoff APIs (per §Engine Compatibility table). Inventory unchanged from 2026-04-26 except for the optional `@abstract` decoration which was already declared by ADR-0012:

| API | Version | ADR | Status |
|-----|---------|-----|--------|
| Typed signals with Resource payloads | 4.2+ (strictness 4.5) | ADR-0001 | declared + verified |
| `ResourceLoader.load_threaded_request` | 4.2+ stable | ADR-0002 | declared + verified |
| Recursive Control disable | 4.5+ | ADR-0002 | declared, verification deferred to Polish (V-7 on-device per scene-manager story-007) |
| `Resource.duplicate_deep(DEEP_DUPLICATE_ALL)` | 4.5+ | ADR-0001 + ADR-0003 + ADR-0004 | declared + verified |
| `DirAccess.get_files_at` | 4.6-idiomatic | ADR-0003 | declared |
| `ResourceSaver.FLAG_COMPRESS` | pre-cutoff | ADR-0003 | declared |
| `class_name X extends RefCounted` + static methods | pre-4.4 stable | ADR-0008 + ADR-0012 + ADR-0009 | declared + verified |
| `@abstract` (4.5+) | 4.5+ | ADR-0012 + ADR-0009 | declared + verified (runtime-error semantics, NOT parse-time per Item 1) |
| `enum UnitClass` typed parameter binding | pre-4.4 stable | ADR-0009 | declared + verified |
| `PackedFloat32Array` COW return semantics | pre-cutoff | ADR-0009 | declared + verified |
| `BalanceConstants.get_const(key)` accessor | (project pattern, ADR-0006 ratified) | ADR-0009 | declared + verified |
| `&"foo"` StringName literal interning | pre-cutoff | ADR-0012 + ADR-0009 | declared + verified |

ADR-0009 declared APIs: all pre-4.6-stable, no deprecated API references.

---

## Cross-ADR Conflict Detection (Delta)

Scanned ADR-0009 against ADR-0001/0002/0003/0004/0006/0008/0012:

- **ADR-0001 (GameBus)**: ADR-0009 §Engine Compatibility verification 4 + §Validation Criteria §4 confirm non-emitter list compliance. ADR-0001 line 375 explicitly lists "Unit Role (#5)... pure data/calculation layers... no state events." ✅
- **ADR-0002 (SceneManager)**: No interaction. ADR-0009 is RefCounted Foundation-layer with no SceneTree presence; no autoload registration. ✅
- **ADR-0003 (Save/Load)**: No interaction. ADR-0009 is stateless; nothing in ADR-0009 touches SaveContext schema or RNG snapshot semantics. ✅
- **ADR-0004 (Map/Grid)**: ADR-0009 §3 `get_class_direction_mult(unit_class, direction: int)` parameter `direction: int` matches ADR-0004 §5b ATK_DIR_FRONT/FLANK/REAR int constants. Direction encoding is int-side at the boundary (Map/Grid produces, UnitRole consumes), consistent with ADV-1 from the 2026-04-26 review (the int↔StringName translation is Grid Battle's responsibility for Damage Calc consumption — does NOT affect UnitRole's int parameter). ✅
- **ADR-0006 (Balance/Data)**: ADR-0009 §4 + §Engine Compatibility verification 1 conform to `BalanceConstants.get_const(key)` accessor for all 10 global caps; G-15 test-isolation obligation explicitly inherited per ADR-0009 line 79. ✅
- **ADR-0008 (Terrain Effect)**: ADR-0009 §5 ratifies the cost-matrix unit-class dimension placeholder per ADR-0008 §Context item 5 deferral ("This ADR must define the matrix structure even if it ships with placeholder values pending ADR-0009 Unit Role"). 6×6 matrix shape; PackedFloat32Array return; per-call copy COW semantics. ✅
- **ADR-0012 (Damage Calc)**: ADR-0009 §6 ratifies the 6×3 `CLASS_DIRECTION_MULT` table consumed by ADR-0012 §F-DC-3. **One stale dimension reference corrected this pass** (Item 8 above): ADR-0012 line 42 `[4][3]` → `[6][3]`. No other inconsistency. ✅

**No remaining conflicts.** 1 dimension stale reference corrected inline (Item 8); 1 advisory (ADV-1, low-priority polish on §4 thread-safety phrasing).

---

## ADR Dependency Order (updated)

```
Foundation (Accepted):
  1. ADR-0001 ✅  GameBus Autoload      (2026-04-18)
  2. ADR-0002 ✅  Scene Manager         (2026-04-18; requires ADR-0001)
  3. ADR-0003 ✅  Save/Load             (2026-04-18; requires ADR-0001 + ADR-0002)
  4. ADR-0004 ✅  Map/Grid Data Model   (2026-04-20 + 2026-04-25 erratum)
  5. ADR-0006 ✅  Balance/Data          (2026-04-26)
  6. ADR-0009 ✅  Unit Role             (this review — depends on ADR-0001 + ADR-0006 + ADR-0008;
                   soft-depends on unwritten ADR-0007 — provisional HeroData wrapper, parameter-stable migration)
Core (Accepted):
  7. ADR-0008 ✅  Terrain Effect        (2026-04-25; ADR-0009 §5 ratifies cost-matrix unit-class dim)
Feature (Accepted):
  8. ADR-0012 ✅  Damage Calc           (2026-04-26; ADR-0009 §6 ratifies CLASS_DIRECTION_MULT[6][3];
                   line 42 stale [4][3] reference corrected this pass)
```

No dependency cycles. No unresolved Proposed-status references after this pass.

**ADR-0009 acceptance ratifies two prior soft-dep callouts:**
- ADR-0008's `cost_matrix` unit-class dimension placeholder (Accepted 2026-04-25 with the placeholder; ratified now)
- ADR-0012's `CLASS_DIRECTION_MULT[6][3]` table (Accepted 2026-04-26 with the soft-dep + corrected dim reference; ratified now)

**Soft dependencies still acknowledged** (non-blocking, documented in ADR-0009 §Dependencies + §Migration Plan §From provisional HeroData):
- ADR-0007 Hero DB (NOT YET WRITTEN, post-Sprint-1) — `HeroData` typed Resource shape; provisional `src/foundation/hero_data.gd` ships with @export-annotated fields per `hero-database.md` §Detailed Rules; migration parameter-stable when ADR-0007 ratifies.

The provisional-dependency strategy is now proven at **3 invocations** (ADR-0008→ADR-0006 + ADR-0012→ADR-0006/0009/0010/0011 + ADR-0009→ADR-0007). Pattern is stable.

---

## GDD Revision Flags (Delta)

**None this pass.**

The stale `balance_constants.json` references in `unit-role.md` rev 2026-04-16 (8+ touch points across §Formulas, Tuning Knobs, Global Constant Summary) were pre-emptively patched during ADR-0009 authoring (2026-04-28). Verified intact this pass:
- §Formulas note added (lines 248-254): "References below to `balance_constants.json` reflect this GDD's pre-ADR-0006 authoring (rev 2026-04-16). At runtime, every such reference resolves to `BalanceConstants.get_const(KEY)`."
- Global Constant Summary table Source column updated (lines 451-462): all 10 cap rows now reference `BalanceConstants.get_const("...")` (ADR-0006); MOVE_BUDGET_PER_RANGE row added with cross-reference to ADR-0009 §Migration Plan §4
- Dependencies upstream Balance/Data row updated (line 616): added `BalanceConstants.get_const(...) per ADR-0006` + 10 cap names + MOVE_BUDGET_PER_RANGE; backed by `assets/data/balance/balance_entities.json` per ADR-0006

Engine findings Items 1 (`@abstract` runtime-not-parse) and 8 (ADR-0012 dimension stale reference) don't contradict any GDD assumption — both are ADR-internal precision corrections, not GDD-locked semantics.

Carried forward from prior reviews (unchanged):

| GDD | Flag | Source | Action |
|---|---|---|---|
| `turn-order.md` | `battle_ended` emitter ownership moved to Grid Battle | ADR-0001 | GDD v-next required |
| `grid-battle.md` | `battle_complete` → `battle_outcome_resolved` rename | ADR-0001 | GDD v5.0 pending |
| `terrain-effect.md` | OQ-7 close-as-resolved (no actual inconsistency) | ADR-0008 review | Recommendation noted; non-blocking |

---

## Advisory Findings (non-blocking, carried to implementation)

### ADV-1 (carried from 2026-04-26 review): int↔StringName direction translation locking

ADR-0004 §5b declares int constants `ATK_DIR_FRONT/FLANK/REAR` as the return-value vocabulary for `MapGrid.get_attack_direction(...)`. ADR-0012 §2 declares `ResolveModifiers.direction_rel: StringName`. ADR-0009 §3 `get_class_direction_mult(unit_class, direction: int)` accepts the int form (matches ADR-0004's return type). Two representations co-exist deliberately: Map/Grid + UnitRole stay int; Damage Calc consumes StringName via Grid Battle as the implicit orchestrator. **No current ADR explicitly locks the int↔StringName translation responsibility on Grid Battle.**

**Action**: Future Grid Battle ADR (Feature layer, post-Sprint-1) should include a "direction encoding bridge" stance. No change required to ADR-0004, ADR-0009, or ADR-0012 at this time. Track as advisory until Grid Battle ADR drafting.

### ADV-2 (NEW): §4 "Thread-safe for read access" phrasing scope

ADR-0009 §Requirements Non-functional reads "Thread-safe for read access (Godot single-threaded game logic; documented for future-proofing)". The parenthetical correctly scopes the claim, but the unqualified "Thread-safe for read access" lead-in could mislead a future reader skim-reading the section. **Action**: Tighten phrasing on next ADR-0009 amendment OR during /create-stories unit-role epic story-001 implementation note. Single-threaded TOCTOU gap is zero risk for MVP (no `await` inside `_load_coefficients()`). Identified by godot-specialist Item 4. Low-priority polish; non-blocking.

### ADV-3 (carried from 2026-04-26 review): `BalanceConstants.get_const(key) -> Variant` cast safety

ADR-0009's reads via `BalanceConstants.get_const("ATK_CAP")` etc. inherit ADR-0006's accessor signature. Recommend ADR-0006 (when amended) tighten the return type or add typed variants (`get_const_int`, `get_const_float`) for compile-time safety. Provisional contract accepted. Identified by godot-specialist 2026-04-26 AF-2.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` exists but was not updated with ADR-0009 entries this pass. Re-evaluation at ≥6 ADRs was triggered by ADR-0012 acceptance per the 2026-04-26 review — that re-evaluation has NOT yet been done; ADR-0009 acceptance brings count to 7. **architecture.md re-evaluation is now overdue by 2 ADRs**. Recommend a follow-up `/create-architecture` partial-update pass (not blocking S1-07 closure or unit-role epic creation, but should be scheduled before the next 2 ADRs land — ADR-0007 Hero DB + ADR-0010 HP/Status would push to 9 ADRs).

---

## Verdict: **PASS**

ADR-0009 Status: Proposed → **Accepted (2026-04-28, via `/architecture-review` delta)**.

Project now has **7 Accepted ADRs** (4 Foundation + 1 Core + 1 Feature + 1 Foundation-stateless-calculator for Unit Role per ADR-0009 §Engine Compatibility "Foundation — stateless gameplay rules calculator"; the layer naming reuses ADR-0008's "Foundation" precedent for stateless calculators serving multiple downstream consumers).

**Sprint 1 S1-07 obligation satisfied.** Unblocks **`/create-epics unit-role`** (Foundation epic ratification) — the Migration Plan §1-§6 runbook is the canonical authoring guide for the projected 8-10 stories: F-1..F-5 formula tests + cost matrix test + direction multiplier test + passive tag set test + R-1 caller-mutation isolation test + JSON config schema validation + integration test against Damage Calc consumer.

Coverage gaps from prior reports (Input, Hero DB, HP/Status, Turn Order, Destiny Branch, Destiny State ADRs + future Grid Battle ADR) remain as pre-production pipeline advisories — still expected work, still non-blocking.

### Required ADRs (prioritized, carried forward)

1. ~~ADR-0004 — Map/Grid data model~~ ✅ Accepted 2026-04-20
2. ~~ADR-0008 — Terrain Effect~~ ✅ Accepted 2026-04-25
3. ~~ADR-0012 — Damage Calc~~ ✅ Accepted 2026-04-26
4. ~~ADR-0006 — Balance/Data~~ ✅ Accepted 2026-04-26
5. ~~ADR-0009 — Unit Role~~ ✅ **Accepted this review**
6. **ADR-0005** — Input System (HIGH engine risk: Godot 4.5 InputMap + SDL3 + Android edge-to-edge)
7. **ADR-0007** — Hero Database schema (depends on ADR-0006; ADR-0009 has provisional HeroData wrapper pending)
8. **ADR-0010** — HP/Status (post-Sprint-1; ratifies ADR-0012 §8 `get_modified_stat` interface; consumes ADR-0009 `get_max_hp`)
9. **ADR-0011** — Turn Order finalization (post-Sprint-1; ratifies ADR-0012 §8 `get_acted_this_turn` interface; consumes ADR-0009 `get_initiative`)
10. **Future Grid Battle ADR** (Feature layer, post-Sprint-1) — sole-caller contract for ADR-0012 + int↔StringName direction encoding bridge per ADV-1
11. **Future Destiny Branch / Destiny State ADRs** (post-Sprint-1)

### Gate Guidance

`/create-epics unit-role` (Sprint-1 closer) is now unblocked. The unit-role Foundation epic story-001 should establish the `src/foundation/unit_role.gd` skeleton + `assets/data/config/unit_roles.json` initial values + the `MOVE_BUDGET_PER_RANGE = 10` constant append to `assets/data/balance/balance_entities.json` (single-line per ADR-0009 §Migration Plan §4) + the provisional `src/foundation/hero_data.gd` wrapper. `/story-readiness` will block any story that fails the embedded TR-unit-role-* coverage check or omits the G-15 `_cache_loaded` reset obligation in test scaffolding.

Sprint-1 DoD now sits at 12/12 (per the 2026-04-28 qa-signoff close-out) PLUS S1-07 ADR-0009 acceptance — sprint reconciliation complete.

---

## Phase 8 — Writes

- ✅ `docs/architecture/ADR-0009-unit-role.md` — Status Proposed → Accepted; Decision Makers /architecture-review row added; §1 line 130 parse-time → runtime correction (Item 1)
- ✅ `docs/architecture/ADR-0012-damage-calc.md` — line 42 (Dependencies field) ADR-0009 entry: `[4][3]` → `[6][3]` + Status flip Proposed→Accepted + 6-class enumeration + STRATEGIST/COMMANDER no-op explanation (Item 8 same-patch amendment)
- ✅ `docs/architecture/tr-registry.yaml` — v5 → v6; last_updated 2026-04-28; 12 new TR-unit-role-001..012 entries appended
- ✅ `docs/architecture/architecture-traceability.md` — Version 0.4 → 0.5; 61 → 73 registered TRs; Foundation layer 2/5 → 3/5; 12 new TR rows + summary refresh + Changelog row
- ✅ `docs/architecture/architecture-review-2026-04-28.md` — this delta report
- ✅ `production/session-state/active.md` — Phase 8 silent append + S1-07 status block flip
- ⏭ `docs/consistency-failures.md` — does not exist; no CONFLICT entries to log per skill convention (don't create)

---

## Chain-of-Verification

5 challenge questions asked of the artifact set after writes; verdict **unchanged (PASS)**:

1. **Does the Item 1 line 130 correction in ADR-0009 §1 conflict with §Validation Criteria §6 (R-1 mitigation test)?** No — §6 mitigation test asserts caller-mutation isolation on the returned PackedFloat32Array; the `@abstract` runtime-rejection assertion is a separate test (e.g., `test_unit_role_new_blocked` in unit_role_test.gd asserting `expect_runtime_error()` not parse rejection). Two orthogonal tests; no conflict. ✅
2. **Does the Item 8 ADR-0012 line 42 amendment introduce any regression in ADR-0012's §Decision body or §Validation Criteria?** No — the amendment is in the §ADR Dependencies table (Depends On row, ADR-0009 entry), which is Context-tier prose. The §Decision body §F-DC-3 reference to `CLASS_DIRECTION_MULT` continues to read the table by `[unit_class][direction_rel]` indexing form, which works identically for [4][3] or [6][3] shapes (the indexing is data-driven, not shape-asserted). No code-path change. The 53 ADR-0012 ACs remain unaffected. ✅
3. **Are the 12 TR-unit-role-* entries exhaustive against the GDD's architectural commitments?** Audited against the 6 ordered Core Rules + 5 sub-formulas F-1..F-5 + Performance budgets + Skill Slot Rules + Visual/Audio + UI Requirements. The TR layer captures all architectural shape commitments (module form, type representation, API surface, config schema, cap accessor pattern, cost matrix shape, direction mult shape, R-1 mitigation, passive tag canonicalization, non-emitter invariant, formula clamp ranges, performance budgets). Visual/Audio/UI sections do NOT generate architectural TRs (they generate art/audio/UI specs that are downstream consumers). Skill Slot Rules CR-5a..5d generate downstream Battle Preparation epic obligations (not architectural shape). Coverage is exhaustive at the architectural-shape granularity; per-AC coverage is a finer granularity ratified via ADR-0009 §GDD Requirements Addressed table. ✅
4. **Does the `[4][3] → [6][3]` correction cascade through any test fixture or data file outside ADR-0012?** Verified `entities.yaml` line 239 (`CLASS_DIRECTION_MULT — locked table from unit-role.md EC-7`) and the ADR-0009 §6 6×3 ratified table — both consistent with the 6×3 corrected shape. No test fixtures exist yet (unit-role epic not yet implemented). The Damage Calc story-001..010 implementation (PR #74 merged 2026-04-27) used the shape `CLASS_DIRECTION_MULT[unit_class][direction_rel]` with data-driven indexing, NOT a hardcoded `[4][3]` array allocation — so the correction is purely documentation-side. ✅
5. **Is the godot-specialist independent review-time validation independent enough?** The subagent was briefed to NOT defer to the prior 2026-04-28 design-time validation (re-derive from first principles). It was given the ADR text, the Godot 4.6 reference docs, the prior accepted ADRs as precedent, and the project gotchas file — but NOT the prior 2026-04-28 design-time validation findings. It produced 8 fresh assessments, of which 6 confirmed the design-time read (PASS) and 2 caught precision gaps the design-time read missed (Items 1 and 8). The independence is real; the cost is justified by the 2 caught gaps. Pattern validates the skill's "fresh session for /architecture-review" protocol at its 4th invocation. ✅
