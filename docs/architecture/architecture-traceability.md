# Architecture Traceability Matrix

> **Purpose**: Map every technical requirement (TR) from GDDs to the ADR(s) that
> cover it. Required artifact for Pre-Production gate. Updated by
> `/create-architecture`, `/architecture-decision`, and `/architecture-review`.
>
> **Source of truth for TR IDs**: `docs/architecture/tr-registry.yaml`
> (IDs there are permanent; this file is derived/viewable).

## Document Status

| Field | Value |
|---|---|
| Version | 0.1 (stub) |
| Last Updated | 2026-04-18 |
| Source — architecture: | `docs/architecture/architecture.md` v0.1 |
| Source — TR registry: | `docs/architecture/tr-registry.yaml` v2 |
| Source — /architecture-review: | `docs/architecture/architecture-review-2026-04-18.md` (PASS) |
| GDDs scanned | 10 of 14 MVP (2026-04-18) |
| TRs extracted (this session) | 102 |
| TRs registered (permanent IDs) | 20 |
| ADR coverage: | 4 ADRs (3 Accepted, 1 Proposed) |

---

## Coverage summary

| Layer | TRs (est.) | ADRs existing | ADRs required | Status |
|---|---|---|---|---|
| Platform | — (infra) | 3 (ADR-0001..0003 Accepted) | 0 more | ✅ Complete |
| Foundation | ~35 | 1 (ADR-0004 Proposed) | 3 more (Input, Balance/Data, Hero DB) | ⚠️ 1/4 |
| Core | ~30 | 0 | 2+ (Turn Order signal, Save/Load schema) | ❌ 0/2 |
| Feature | ~25 | 0 | 3+ (Damage Calc, AI, Destiny Branch) | ❌ 0/3 |
| Presentation | ~10 | 0 | 1+ (Dual-focus UI pattern) | ❌ 0/1 |
| Polish | ~2 | 0 | 1 (Accessibility, if tier committed) | ❌ 0/1 |

**Net-new ADRs required before Pre-Production → Production gate**: 8–12.

---

## Registered TR-to-ADR map (source: tr-registry.yaml v2)

These 20 requirements have permanent IDs and are already covered by an Accepted ADR.

| TR ID | System | ADR | Status | Summary |
|---|---|---|---|---|
| TR-gamebus-001 | gamebus | ADR-0001 | Accepted | All cross-system signals on `/root/GameBus`; per-frame events forbidden; ≥2-field payloads must be typed Resources |
| TR-scenario-progression-001 | scenario-progression | ADR-0001 | Accepted | GameBus relay pattern ratified before Scenario impl |
| TR-scenario-progression-002 | scenario-progression | ADR-0001 | Accepted | 5 outbound signals cross scene boundaries |
| TR-scenario-progression-003 | scenario-progression | ADR-0001 | Accepted | EC-SP-5 duplicate battle-complete guard |
| TR-grid-battle-001 | grid-battle | ADR-0001 | Accepted | Tri-state `{WIN, DRAW, LOSS}` BattleOutcome signal |
| TR-turn-order-001 | turn-order | ADR-0001 | Accepted | round_started/unit_turn_started/unit_turn_ended owned by Turn Order; battle-end moved to Grid Battle |
| TR-hp-status-001 | hp-status | ADR-0001 | Accepted | `unit_died` signal ownership |
| TR-input-handling-001 | input-handling | ADR-0001 | Accepted | input_action_fired / input_state_changed / input_mode_changed exposed |
| TR-scene-manager-001 | scene-manager | ADR-0002 | Accepted | `/root/SceneManager` autoload, load order 2, 5-state FSM |
| TR-scene-manager-002 | scene-manager | ADR-0002 | Accepted | Overworld retain (not free) during battle via PROCESS_MODE_DISABLED + visibility + input guards |
| TR-scene-manager-003 | scene-manager | ADR-0002 | Accepted | BattleScene async load via ResourceLoader.load_threaded_request + Timer poll |
| TR-scene-manager-004 | scene-manager | ADR-0002 | Accepted | call_deferred free on battle_outcome_resolved |
| TR-scene-manager-005 | scene-manager | ADR-0002 | Accepted | scene_transition_failed error path |
| TR-save-load-001 | save-load | ADR-0003 | Accepted | `/root/SaveManager` autoload, load order 3 |
| TR-save-load-002 | save-load | ADR-0003 | Accepted | @export on all SaveContext + EchoMark fields |
| TR-save-load-003 | save-load | ADR-0003 | Accepted | Atomic save: duplicate_deep → ResourceSaver.save(tmp) → rename_absolute |
| TR-save-load-004 | save-load | ADR-0003 | Accepted | Load via ResourceLoader.load(path, '', CACHE_MODE_IGNORE) |
| TR-save-load-005 | save-load | ADR-0003 | Accepted | BattleOutcome.Result enum append-only; schema_version bump on reorder |
| TR-save-load-006 | save-load | ADR-0003 | Accepted | Save root `user://saves` — no SAF / external-storage paths |
| TR-save-load-007 | save-load | ADR-0003 | Accepted | Migration Callables pure — no captured state |

**Gap**: ADR-0004 (Map/Grid) has TR requirements flowing in the ADR body but no tr-registry entries yet. Next `/architecture-review` pass will append `TR-map-grid-*` entries.

---

## Pending TR baseline (102 extracted 2026-04-18, not yet registered)

Full extraction in the `/create-architecture` Phase 0 session log. To be folded into `tr-registry.yaml` by a future `/architecture-review` run. Grouped by GDD below. Each row links to the GDD location and the candidate covering ADR (⏳ = ADR not yet written).

> **Mapping convention**: when `/architecture-review` next runs, it appends new
> rows to tr-registry.yaml and replaces ⏳ here with the registered ID. Do not
> renumber existing registry entries.

### design/gdd/game-concept.md (5 candidate TRs)

| Candidate | Requirement | Target ADR |
|---|---|---|
| game-concept.1 | Godot 4.6 single-player turn-based tactical RPG | (no ADR; engine choice in CLAUDE.md) |
| game-concept.2 | Cross-platform PC + Mobile, 30min–2hr sessions | ⏳ Pre-Production platform budget ADR |
| game-concept.3 | 40–50 handcrafted maps (no procedural) | ⏳ Map authoring pipeline (covered partial by ADR-0004 §Authoring) |
| game-concept.4 | 80–100 heroes (MVP 8–10), persistent base stats + growth | ⏳ ADR-0007 Hero DB Resource schema |
| game-concept.5 | 15–20 destiny branch conditions with cascading impact | ⏳ Destiny Branch ADR |

### design/gdd/balance-data.md (9 candidate TRs)

| Candidate | Requirement | Target ADR |
|---|---|---|
| balance-data.1 | JSON envelope `{schema_version, category, data}` + validator | ⏳ ADR-0006 Balance/Data pipeline |
| balance-data.2 | 4-phase pipeline: Discovery → Parse → Validate → Build | ⏳ ADR-0006 |
| balance-data.3 | DataRegistry singleton, read-only, no runtime mutation | ⏳ ADR-0006 |
| balance-data.4 | 16 balance constants in `balance_constants.json` | ⏳ ADR-0006 |
| balance-data.5 | MINIMUM_SCHEMA_VERSION gate → FATAL on mismatch | ⏳ ADR-0006 |
| balance-data.6 | Validation Coverage Rate (VCR) ≥ 1.0 CI gate | ⏳ ADR-0006 |
| balance-data.7 | Hot reload (dev mode only) — manual trigger | ⏳ ADR-0006 |
| balance-data.8 | REQUIRED_CATEGORIES: heroes, maps, unit_roles, growth, balance_constants, skills, scenarios, formations | ⏳ ADR-0006 |
| balance-data.9 | PIPELINE_TIMEOUT_MS = 5000ms on 512MB mobile | ⏳ ADR-0006 |

### design/gdd/grid-battle.md (9 candidate TRs — GDD in MAJOR REVISION, re-scan after v5.0)

### design/gdd/hero-database.md (9 candidate TRs)

| Candidate | Requirement | Target ADR |
|---|---|---|
| hero-db.1 | ID format `{faction}_{seq}_{slug}` immutable | ⏳ ADR-0007 Hero DB |
| hero-db.2 | Hero record schema (Identity/Stats/HP/Init/Movement/Role/Growth/Skills/Relationships/Join) | ⏳ ADR-0007 |
| hero-db.3 | Stat total validation 180 ≤ total ≤ 280; SPI ≥ 0.5; range ≥ 30 | ⏳ ADR-0007 |
| hero-db.4 | 6 unit roles + equipment slot override | ⏳ ADR-0007 |
| hero-db.5 | growth_rate ∈ [0.5, 2.0], clamped to 100 at L_cap=30 | ⏳ ADR-0007 |
| hero-db.6 | Relationships schema (hero_b_id FK, relation_type, effect_tag, is_symmetric) | ⏳ ADR-0007 |
| hero-db.7 | 0–3 innate skills; arrays must equal length | ⏳ ADR-0007 |
| hero-db.8 | Missing FK = WARNING; orphaned record = WARNING | ⏳ ADR-0007 |
| hero-db.9 | Duplicate hero_id / JSON key = FATAL | ⏳ ADR-0007 |

### design/gdd/hp-status.md (11 candidate TRs)

_Full rows deferred to next Phase 0 writeup. Seed: damage intake pipeline, healing pipeline, 5 MVP status effects, slot mgmt, POISON DoT formula, DEMORALIZED propagation, DEFEND_STANCE/EXHAUSTED mutual exclusion, stat modifier clamps, unit_died signal emission, morale-anchor field expansion, death mid-round handling. Target ADR: ⏳ Core-layer HP/Status ADR (or covered implicitly by formula ownership)._

### design/gdd/input-handling.md (11 candidate TRs)

_Full rows deferred. Seed: 22-action vocabulary, auto-detect mode (KB/mouse vs touch), 7 input states, 2-beat confirmation, Touch Tap Preview Protocol, Magnifier disambiguation, pan-vs-tap classification, per-unit undo, JSON bindings at res path, camera_zoom_min=0.70, HUD mode hints. Target ADR: ⏳ ADR-0005 Input Handling (HIGH engine risk: dual-focus 4.6, SDL3, Android edge-to-edge)._

### design/gdd/map-grid.md (10 candidate TRs)

_Covered by ADR-0004 (Proposed). Registration pending `/architecture-review` re-run. Seed: 15–40×15–30 bounds, flat-array index, tile data schema, 8 terrain types, tile state machine, Dijkstra contract, LoS via Bresenham, 4-cardinal facing, tile_destroyed signal, elevation↔terrain validation. Target ADR: ADR-0004._

### design/gdd/scenario-progression.md (5 candidate TRs — v2.0 re-review pending)

_Large broadcast surface (23 signals × 8 domains in ADR-0001 contract). Five candidate TRs: chapter progression state, hero join condition tags, destiny branch tree, 34-signal set, Save/Load persistence contract. Target ADRs: ⏳ Scenario Progression ADR + ⏳ Destiny Branch ADR (separate ownership)._

### design/gdd/terrain-effect.md (12 candidate TRs)

_Full rows deferred. Seed: terrain modifiers caps, elevation modifiers ±2 asymmetric, defense stacking clamp, evasion stacking clamp, bridge chokepoint FLANK→FRONT, AI terrain scoring, damage formula, Tactical Read passive, High Ground Shot passive, HUD stack-cap display, terrain overlay toggle, evasion dodge animation. Target ADR: ⏳ ADR-0008 Terrain Effect (depends on ADR-0004)._

### design/gdd/turn-order.md (13 candidate TRs)

_Full rows deferred. Seed: interleaved queue, round lifecycle R1/R2/R3/RE1–3, per-unit turn T1–T7, action tokens, `acted_this_turn` semantics, tie-breaking, static initiative, death-mid-round, charge budget, round cap 30, signal ownership (per TR-turn-order-001 already registered), TurnOrderSnapshot. Target ADRs: covered partially by ADR-0001 signal ownership + ⏳ Turn Order finalization ADR._

### design/gdd/unit-role.md (20 candidate TRs)

_Full rows deferred. Seed: 6 classes with ATK/DEF profiles, formulas F-1..F-5, terrain cost multipliers, passives (Charge, Shield Wall, Tactical Read, Rally, Ambush, High Ground Shot), direction multipliers, Shield Wall PHYSICAL-only, skill slot management, class identities, JSON config locations, silhouette rendering. Target ADR: ⏳ Unit Role formula ownership ADR (may share with Damage Calc)._

---

## Next registry writes (when /architecture-review next runs)

1. Register ~20 new permanent TR IDs for ADR-0004 Map/Grid coverage (tile schema, pathfinding contract, duplicate_deep constraint, cache-sync rules)
2. Assign permanent IDs for the net-new ~40–60 TRs once their covering ADRs exist
3. Flip ADR-0004 from Proposed → Accepted and re-version `tr-registry.yaml` (2 → 3)

---

## Changelog

| Date | Version | Change |
|---|---|---|
| 2026-04-18 | 0.1 | Stub created during `/create-architecture` Phase 0. 20 registered TRs carried forward; 102-TR baseline previewed per-GDD. Full registration deferred to next `/architecture-review`. |
