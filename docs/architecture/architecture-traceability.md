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
| Version | 0.4 |
| Last Updated | 2026-04-26 |
| Source — architecture: | `docs/architecture/architecture.md` v0.1 |
| Source — TR registry: | `docs/architecture/tr-registry.yaml` v5 |
| Source — /architecture-review: | `docs/architecture/architecture-review-2026-04-18.md` (PASS) + `architecture-review-2026-04-20.md` (PASS delta, ADR-0004 accepted) + `architecture-review-2026-04-25.md` (PASS delta, ADR-0008 accepted) + `architecture-review-2026-04-26.md` (PASS delta, ADR-0012 accepted) |
| GDDs scanned | 10 of 14 MVP (2026-04-18) + map-grid.md re-scan (2026-04-20) + terrain-effect.md re-scan (2026-04-25) + damage-calc.md re-scan (2026-04-26) |
| TRs extracted (this session) | 120 |
| TRs registered (permanent IDs) | 61 |
| ADR coverage: | 6 ADRs (all Accepted — 4 Foundation + 1 Core + 1 Feature) |

---

## Coverage summary

| Layer | TRs (est.) | ADRs existing | ADRs required | Status |
|---|---|---|---|---|
| Platform | — (infra) | 3 (ADR-0001..0003 Accepted) | 0 more | ✅ Complete |
| Foundation | ~35 | 2 (ADR-0004 Accepted) | 3 more (Input, Balance/Data, Hero DB) | ⚠️ 2/5 |
| Core | ~30 | 1 (ADR-0008 Accepted) | 1+ more (Turn Order signal, HP/Status) | ⚠️ 1/2 |
| Feature | ~25 | 1 (ADR-0012 Accepted) | 2+ (AI, Grid Battle, Destiny Branch) | ⚠️ 1/3 |
| Presentation | ~10 | 0 | 1+ (Dual-focus UI pattern) | ❌ 0/1 |
| Polish | ~2 | 0 | 1 (Accessibility, if tier committed) | ❌ 0/1 |

**Net-new ADRs required before Pre-Production → Production gate**: 6–10 (ADR-0012 landed this pass; first Feature-layer ADR).

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
| TR-map-grid-001 | map-grid | ADR-0004 | Accepted | CR-2 flat array `tiles[row*cols+col]` authoritative; packed caches read-optimization only |
| TR-map-grid-002 | map-grid | ADR-0004 | Accepted | CR-6 custom Dijkstra only; AStarGrid2D/NavServer2D forbidden (per-cell scalar cannot carry unit×terrain matrix) |
| TR-map-grid-003 | map-grid | ADR-0004 | Accepted | 9 public read-only query methods (get_tile, get_movement_range, get_path, get_attack_range, get_attack_direction, get_adjacent_units, get_occupied_tiles, has_line_of_sight, get_map_dimensions) |
| TR-map-grid-004 | map-grid | ADR-0004 | Accepted | Mutation API (set_occupant, clear_occupant, apply_tile_damage) — Grid Battle only by convention; write-through to packed caches |
| TR-map-grid-005 | map-grid | ADR-0004 | Accepted | `tile_destroyed(coord: Vector2i)` single-primitive GameBus signal; Environment domain amendment to ADR-0001 (27 signals / 8 domains) |
| TR-map-grid-006 | map-grid | ADR-0004 | Accepted | AC-PERF-2 <16ms get_movement_range on 40×30 move_range=10; packed caches + early-termination Dijkstra |
| TR-map-grid-007 | map-grid | ADR-0004 | Accepted | Battle-scoped Node; freed with BattleScene; zero cross-battle state |
| TR-map-grid-008 | map-grid | ADR-0004 | Accepted | Elevation 0/1/2 + integer Bresenham LoS; destroyed walls unblock; endpoints never self-block |
| TR-map-grid-009 | map-grid | ADR-0004 | Accepted | `.tres` authoring at `res://data/maps/[map_id].tres`; CACHE_MODE_IGNORE load; OQ#2 resolved |
| TR-map-grid-010 | map-grid | ADR-0004 | Accepted | TileData inline-only (no external UID) — hard constraint from duplicate_deep() edge case; superseding ADR required for shared presets |
| TR-terrain-effect-001 | terrain-effect | ADR-0008 | Accepted | CR-1: 8 terrain types × {defense_bonus, evasion_bonus, special_rules} table |
| TR-terrain-effect-002 | terrain-effect | ADR-0008 | Accepted | CR-1d: Modifiers uniform across unit types for MVP; class differentiation via Map/Grid cost matrix |
| TR-terrain-effect-003 | terrain-effect | ADR-0008 | Accepted | CR-2: Asymmetric elevation modifiers (delta ±1 → ±8%, ±2 → ±15%, sub-linear) |
| TR-terrain-effect-004 | terrain-effect | ADR-0008 | Accepted | F-1: Symmetric clamp [-30, +30] for total_defense; negative defense amplifies damage |
| TR-terrain-effect-005 | terrain-effect | ADR-0008 | Accepted | MAX_DEFENSE_REDUCTION = 30, MAX_EVASION = 30 (CR-3a/b); cap-display [MAX] (CR-3c) |
| TR-terrain-effect-006 | terrain-effect | ADR-0008 | Accepted | CR-3d: Min damage = 1 — Damage Calc enforces; Terrain Effect supplies modifier only |
| TR-terrain-effect-007 | terrain-effect | ADR-0008 | Accepted | CR-3e + EC-1: Symmetric clamp authoritative for negative defense |
| TR-terrain-effect-008 | terrain-effect | ADR-0008 | Accepted | CR-4: 3 query methods — get_terrain_modifiers, get_combat_modifiers, get_terrain_score |
| TR-terrain-effect-009 | terrain-effect | ADR-0008 | Accepted | CR-5: Bridge FLANK→FRONT via flag; Damage Calc orchestrates with ADR-0004 §5b ATK_DIR_* constants |
| TR-terrain-effect-010 | terrain-effect | ADR-0008 | Accepted | Stateless RefCounted+static; lazy-init; reset_for_tests() discipline for GdUnit4 isolation |
| TR-terrain-effect-011 | terrain-effect | ADR-0008 | Accepted | Cross-system contract (damage-calc.md §F): opaque clamped terrain_def [-30,+30] / terrain_evasion [0,30] |
| TR-terrain-effect-012 | terrain-effect | ADR-0008 | Accepted | Config at assets/data/terrain/terrain_config.json; FileAccess + JSON.new().parse() instance form |
| TR-terrain-effect-013 | terrain-effect | ADR-0008 | Accepted | AC-21: get_combat_modifiers() <0.1ms per call (mid-range Android, 100 calls/frame budget) |
| TR-terrain-effect-014 | terrain-effect | ADR-0008 | Accepted | AC-19/20: Schema validation + safe-default fallback; fractional-value rejection via value != int(value) |
| TR-terrain-effect-015 | terrain-effect | ADR-0008 | Accepted | EC-14: Elevation delta clamped to [-2, +2] before table lookup |
| TR-terrain-effect-016 | terrain-effect | ADR-0008 | Accepted | AC-14: OOB coord → zero modifiers; no error path |
| TR-terrain-effect-017 | terrain-effect | ADR-0008 | Accepted | Shared cap accessor max_defense_reduction()/max_evasion() — single source of truth for Formation Bonus + Damage Calc |
| TR-terrain-effect-018 | terrain-effect | ADR-0008 | Accepted | cost_multiplier(unit_type, terrain_type) matrix structure; MVP=1 uniform; replaces terrain_cost.gd:32 placeholder |

All Foundation-layer ADRs (ADR-0001..0004), the first Core-layer ADR (ADR-0008), and the first Feature-layer ADR (ADR-0012) now have permanent TR IDs registered.

| TR ID | System | ADR | Status | Summary |
|---|---|---|---|---|
| TR-damage-calc-001 | damage-calc | ADR-0012 | Accepted | CR-1: stateless `class_name DamageCalc extends RefCounted` + static `resolve()` sole entry point; autoload/Node forms rejected |
| TR-damage-calc-002 | damage-calc | ADR-0012 | Accepted | 4 typed RefCounted wrappers replace Dictionary payload; `Array[StringName]` discipline (runtime enforcement) + StringName literal release-build defense |
| TR-damage-calc-003 | damage-calc | ADR-0012 | Accepted | Direct-call interface Grid Battle → DamageCalc.resolve(); apply_damage invoked by Grid Battle, never DamageCalc |
| TR-damage-calc-004 | damage-calc | ADR-0012 | Accepted | Stateless / signal-free invariant per ADR-0001 non-emitter list line 375 |
| TR-damage-calc-005 | damage-calc | ADR-0012 | Accepted | Per-call seeded RNG injection; call-count-stable contract (1/0/0 per non-counter/counter/skill-stub) |
| TR-damage-calc-006 | damage-calc | ADR-0012 | Accepted | 11 tuning constants in entities.yaml via DataRegistry.get_const(); hardcoding banned |
| TR-damage-calc-007 | damage-calc | ADR-0012 | Accepted | 3-tier cap layering BASE_CEILING=83 / P_MULT_COMBINED_CAP=1.31 / DAMAGE_CEILING=180 in non-negotiable order |
| TR-damage-calc-008 | damage-calc | ADR-0012 | Accepted | 5 cross-system READ-ONLY upstream interfaces (HP/Status, Terrain Effect, Unit Role, Turn Order, Balance/Data); provisional-dependency strategy on ADR-0006/0009/0010/0011 |
| TR-damage-calc-009 | damage-calc | ADR-0012 | Accepted | F-GB-PROV retirement same-patch obligation with entities.yaml damage_resolve registration; AC-DC-44 CI grep gate |
| TR-damage-calc-010 | damage-calc | ADR-0012 | Accepted | Test infrastructure: headless+headed CI matrix, GdUnitTestSuite extends Node for AC-DC-51(b), gdUnit4 addon pinning |
| TR-damage-calc-011 | damage-calc | ADR-0012 | Accepted | AC-DC-49 (randi_range inclusive both ends) + AC-DC-50 (snappedf round-half-away-from-zero) mandatory engine pin tests |
| TR-damage-calc-012 | damage-calc | ADR-0012 | Accepted | source_flags always-new-Array semantics; never mutate caller; error-flag vocabulary via .has(&"invariant_violation:reason") |
| TR-damage-calc-013 | damage-calc | ADR-0012 | Accepted | Performance: 50µs avg headless / <1ms p99 mobile / zero Dictionary alloc inside resolve() body except build_vfx_tags |

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

### design/gdd/map-grid.md (10 TRs — REGISTERED 2026-04-20)

Registered as TR-map-grid-001..010 in tr-registry.yaml v3. See "Registered TR-to-ADR map" section above for the full table.

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

1. ~~Register ~20 new permanent TR IDs for ADR-0004 Map/Grid coverage~~ ✅ **Done 2026-04-20** — 10 TRs registered (TR-map-grid-001..010)
2. ~~Flip ADR-0004 from Proposed → Accepted and re-version `tr-registry.yaml` (2 → 3)~~ ✅ **Done 2026-04-20**
3. Assign permanent IDs for the net-new ~40–60 TRs once their covering ADRs exist (Input Handling, Balance/Data, Hero DB, Terrain Effect, Formation Bonus, Destiny Branch, Destiny State, Unit Role formulas)

---

## Changelog

| Date | Version | Change |
|---|---|---|
| 2026-04-18 | 0.1 | Stub created during `/create-architecture` Phase 0. 20 registered TRs carried forward; 102-TR baseline previewed per-GDD. Full registration deferred to next `/architecture-review`. |
| 2026-04-20 | 0.2 | Delta review: ADR-0004 escalated Proposed → Accepted. 10 new TR-map-grid-* entries registered (registry v2→v3). Foundation layer 1/4 → 2/5 complete. Source: `docs/architecture/architecture-review-2026-04-20.md`. |
| 2026-04-25 | 0.3 | Delta review: ADR-0008 escalated Proposed → Accepted. 18 new TR-terrain-effect-* entries registered (registry v3→v4). Core layer 0/2 → 1/2 complete. Concurrent ADR-0004 §5b erratum amendment. Source: `docs/architecture/architecture-review-2026-04-25.md`. |
| 2026-04-26 | 0.4 | Delta review: ADR-0012 (Damage Calc) escalated Proposed → Accepted. 13 new TR-damage-calc-* entries registered (registry v4→v5). First Feature-layer ADR. Provisional-dependency strategy on ADR-0006/0009/0010/0011 mirrors ADR-0008→ADR-0006 precedent (proven 2 invocations). 2 godot-specialist text corrections applied (AF-1 + Item 3). Source: `docs/architecture/architecture-review-2026-04-26.md`. |
