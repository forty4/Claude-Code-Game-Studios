# Architecture Review Report

> **Date**: 2026-04-18 (post-fix re-run — supersedes earlier same-date CONCERNS report)
> **Engine**: Godot 4.6
> **Mode**: Full review (Phases 1–8)
> **GDDs Reviewed**: 12 (10 system GDDs + game-concept + systems-index)
> **ADRs Reviewed**: 3 (all Accepted)

---

## TL;DR

- **Verdict**: **PASS** (upgraded from CONCERNS)
- All 4 blocking issues from the earlier 2026-04-18 run are resolved
- All 3 Foundation-layer ADRs (ADR-0001, ADR-0002, ADR-0003) are **Accepted**
  and internally consistent
- Engine compatibility audit clean
- 20/20 registered TRs backed by Accepted ADRs
- 8 MVP-system coverage gaps remain as **advisory** (expected pre-production
  pipeline — Map/Grid, Input, Balance/Data, Hero DB, Terrain, and 3 deferred
  dependents)

---

## Traceability Summary

| Status | Count |
|---|---|
| ✅ Covered by Accepted ADR | **20 TRs** |
| ⚠️ Partial | 1 TR (Turn Order `battle_ended` ownership moved to Grid Battle — GDD v-next revision still pending, carried) |
| ❌ Gap | 8 MVP systems without ADR coverage |

## Traceability Matrix

| TR-ID | GDD | Requirement | ADR | Status |
|---|---|---|---|---|
| TR-gamebus-001 | (ADR-meta) | All cross-system signals on `/root/GameBus`; payloads ≥2 fields = typed Resource | ADR-0001 | ✅ |
| TR-scenario-progression-001 | scenario-progression.md | OQ-SP-01: ratify GameBus pattern before implementation | ADR-0001 | ✅ |
| TR-scenario-progression-002 | scenario-progression.md | Five outbound signals need cross-scene relay | ADR-0001 | ✅ |
| TR-scenario-progression-003 | scenario-progression.md | EC-SP-5: duplicate `battle_outcome_resolved` emission guard | ADR-0001 | ✅ |
| TR-grid-battle-001 | grid-battle.md | §CLEANUP: emit `battle_outcome_resolved` with typed `BattleOutcome` | ADR-0001 | ✅ |
| TR-turn-order-001 | turn-order.md | `round_started`, `unit_turn_started`, `unit_turn_ended` | ADR-0001 | ⚠️ (first 3 covered; `battle_ended` moved to Grid Battle — GDD v-next pending) |
| TR-hp-status-001 | hp-status.md | `unit_died` signal | ADR-0001 | ✅ |
| TR-input-handling-001 | input-handling.md | `input_action_fired`, `input_state_changed`, `input_mode_changed` | ADR-0001 | ✅ |
| TR-scene-manager-001 | scenario-progression.md (UI-7) | Autoload `/root/SceneManager`; 5-state machine | ADR-0002 | ✅ |
| TR-scene-manager-002 | scenario-progression.md (F-SP-3) | Overworld retained (PROCESS_MODE_DISABLED + recursive Control disable) | ADR-0002 | ✅ |
| TR-scene-manager-003 | grid-battle.md (§CLEANUP) | BattleScene async via `ResourceLoader.load_threaded_request`; Timer-polled 100 ms | ADR-0002 | ✅ |
| TR-scene-manager-004 | scenario-progression.md (Beat 5→6) | Deferred free preserves co-subscriber handler node refs | ADR-0002 | ✅ |
| TR-scene-manager-005 | scenario-progression.md (EC-SP) | Async-load failure emits `scene_transition_failed` + ERROR state | ADR-0002 | ✅ |
| TR-save-load-001 | scenario-progression.md (CP policy) | SaveManager autoload `/root/SaveManager`, load order 3 | ADR-0003 | ✅ |
| TR-save-load-002 | scenario-progression.md (SaveContext) | All SaveContext + EchoMark fields `@export`-annotated | ADR-0003 | ✅ |
| TR-save-load-003 | scenario-progression.md (3-CP) | `save_checkpoint()` = `duplicate_deep` → `ResourceSaver.save(tmp)` → `rename_absolute` atomic | ADR-0003 | ✅ |
| TR-save-load-004 | scenario-progression.md | All loads use `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` | ADR-0003 | ✅ |
| TR-save-load-005 | grid-battle.md | `BattleOutcome.Result` append-only; reorder requires migration + schema_version bump | ADR-0003 | ✅ |
| TR-save-load-006 | scenario-progression.md | Save root `user://saves`; no SAF/external-storage paths | ADR-0003 | ✅ |
| TR-save-load-007 | scenario-progression.md (CP-3) | `SaveMigrationRegistry` Callables are pure functions | ADR-0003 | ✅ |

---

## Coverage Gaps (advisory — pre-production pipeline)

| # | System (MVP) | Domain | Suggested ADR | Engine Risk |
|---|---|---|---|---|
| 1 | Map/Grid (#2) | Gameplay foundation | `/architecture-decision "Map/Grid data model"` | LOW |
| 2 | Input Handling (#29) | Platform | `/architecture-decision "Input system — touch + KBM"` | MEDIUM (4.5 InputMap) |
| 3 | Balance/Data (#26) | Data-driven config | `/architecture-decision "Balance data resources"` | LOW |
| 4 | Hero DB (#27) | Data model | `/architecture-decision "Hero database schema"` | LOW |
| 5 | Terrain Effect (#28) | Gameplay | `/architecture-decision "Terrain effect evaluation"` | LOW |
| 6 | Formation Bonus (#30) | Gameplay | deferred — depends on Grid/Turn Order | LOW |
| 7 | Destiny Branch (#4) | Narrative | deferred — depends on Scenario Progression v2.1 | MEDIUM |
| 8 | Destiny State (#16) | Save-bound | deferred — depends on Save/Load (now Accepted — unblocked) | LOW |

---

## Cross-ADR Conflicts — All Resolved

| ID | Issue | Resolution (this session) |
|---|---|---|
| **F-1** | Duplicate `save_checkpoint_requested` row (ADR-0001 Scenario + Persistence tables) | Deleted stale Scenario-domain row; Persistence-domain row is canonical |
| **F-2** | ADR-0001 code block missing 3 amendment-added signals | Added `scene_transition_failed`, `save_persisted`, `save_load_failed` with Persistence banner; code block now 26 signals / 7 banners (matches `Total signal count: 26` on line 348) |
| **F-3** | Broken citation to non-existent ADR-0001 "§5 primitive-only rule" | Replaced with `TR-gamebus-001` (payloads ≥2 fields = typed Resource); reframed as canonical form, not exception |
| **C-1** | `save_checkpoint_requested` emitter list conflict (ADR-0003 said "ScenarioRunner, SceneManager"; ADR-0002 forbids SceneManager state) | SceneManager dropped from emitter list in both ADR-0001 line 344 and ADR-0003 line 417; ScenarioRunner is sole emitter; SceneManager retained as CP-2 timing boundary only |

No new conflicts detected.

---

## ADR Dependency Order

```
Foundation (all Accepted 2026-04-18):
  1. ADR-0001 ✅  GameBus Autoload
  2. ADR-0002 ✅  Scene Manager   (requires ADR-0001)
  3. ADR-0003 ✅  Save/Load        (requires ADR-0001 + ADR-0002)
```

No dependency cycles. No unresolved Proposed-status references.

---

## GDD Revision Flags

No new flags. Carried forward from prior reviews (unchanged):

| GDD | Flag | Source | Action |
|---|---|---|---|
| `turn-order.md` | `battle_ended` emitter ownership moved to Grid Battle | ADR-0001 | GDD v-next required |
| `grid-battle.md` | `battle_complete` → `battle_outcome_resolved` rename | ADR-0001 | GDD v5.0 pending |

---

## Engine Compatibility Audit

| Check | Result |
|---|---|
| Engine Compatibility sections present | 3 / 3 ADRs ✅ |
| Version consistency | All target 4.6 ✅ |
| Deprecated APIs referenced | None ✅ |
| Post-cutoff API declarations | `duplicate_deep` (4.5+), `ResourceLoader.load_threaded_request`, recursive Control disable (4.5+), `DirAccess.get_files_at` (4.6), atomic `rename_absolute` — all declared + consistent ✅ |
| Post-cutoff API conflicts | None ✅ |
| Specialist second opinion | Not re-spawned — no engine-related changes since prior-run specialist review; status/citation edits do not affect engine assumptions |

**Engine audit clean.**

---

## New Advisory Findings (non-blocking)

- **M-2 — Code block vs tables domain asymmetry** (pre-existing, not this review's scope):
  Code block has 7 banners; tables split into 9 domains (Grid Battle / Turn
  Order / HP-Status lumped under one code-block banner). Consider a future
  ADR-0001 amendment to split the code block to match the tables. Does not
  break signal contract tests.
- **M-1** (stale `(Proposed 2026-04-18)` refs in ADR-0001 §Related lines 521–522) — **FIXED in this run.**

---

## Architecture Document Coverage

`docs/architecture/architecture.md` does not exist yet. With 3 ADRs, consolidation is premature. Re-evaluate at ≥6 ADRs.

---

## Verdict: **PASS**

All 4 prior blocking issues resolved. All 3 Foundation-layer ADRs Accepted
and internally consistent. Engine audit clean. Coverage gaps remain but
are pre-production pipeline items (advisory — expected at this stage).

### Required ADRs (prioritized, Foundation-first)

1. **ADR-0004** — Map/Grid data model (unblocks Formation Bonus ADR)
2. **ADR-0005** — Input System (Godot 4.5 InputMap changes = MEDIUM risk)
3. **ADR-0006** — Balance Data resources (blocks Hero DB + Terrain Effect)
4. **ADR-0007** — Hero Database schema (depends on ADR-0006)
5. **ADR-0008** — Terrain Effect evaluation (depends on ADR-0004 + ADR-0006)

### Gate Guidance

When all MVP-system ADRs are landed, run `/gate-check pre-production` to
advance. Current Foundation layer is ready to support Pre-Production.

---

## Phase 8 — Writes

- ✅ This report — `docs/architecture/architecture-review-2026-04-18.md` (supersedes prior same-date CONCERNS report)
- ✅ `docs/architecture/ADR-0001-gamebus-autoload.md` — M-1 fixup (lines 521–522 stale `(Proposed)` → `(Accepted)`)
- ✅ Session state updated — `production/session-state/active.md` (PASS extract appended)
- ⏭ `docs/consistency-failures.md` append — skipped (file does not exist; no CONFLICT entries to log since C-1 was resolved rather than recorded as a pattern failure)
- ⏭ tr-registry — no changes (no new TRs this run)
