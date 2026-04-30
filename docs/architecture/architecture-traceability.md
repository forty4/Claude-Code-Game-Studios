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
| Version | 0.8 |
| Last Updated | 2026-04-30 |
| Source — architecture: | `docs/architecture/architecture.md` v0.5 (refreshed 2026-04-30 — Core 1/2 layer gap closing this delta) |
| Source — TR registry: | `docs/architecture/tr-registry.yaml` v9 |
| Source — /architecture-review: | `docs/architecture/architecture-review-2026-04-18.md` (PASS) + `architecture-review-2026-04-20.md` (PASS delta, ADR-0004 accepted) + `architecture-review-2026-04-25.md` (PASS delta, ADR-0008 accepted) + `architecture-review-2026-04-26.md` (PASS delta, ADR-0012 accepted) + `architecture-review-2026-04-28.md` (PASS delta, ADR-0009 accepted) + `architecture-review-2026-04-30.md` (PASS delta, ADR-0007 accepted) + `architecture-review-2026-04-30b.md` (PASS delta, ADR-0005 accepted — Foundation 5/5 Complete) + **`architecture-review-2026-04-30c.md` (PASS delta, ADR-0010 accepted — first Core-layer stateful battle-scoped Node ADR; closes ADR-0012 `get_modified_stat`/`apply_damage` upstream Core soft-dep)** |
| GDDs scanned | 10 of 14 MVP (2026-04-18) + map-grid.md re-scan (2026-04-20) + terrain-effect.md re-scan (2026-04-25) + damage-calc.md re-scan (2026-04-26) + unit-role.md re-scan (2026-04-28) + hero-database.md re-scan (2026-04-30) + input-handling.md re-scan (2026-04-30 delta #6) + **hp-status.md re-scan (2026-04-30 delta #7)** |
| TRs extracted (this session) | 180 |
| TRs registered (permanent IDs) | 121 |
| ADR coverage: | 11 ADRs (all Accepted — **5 Foundation Complete** + 2 Core (ADR-0008 + ADR-0010) + 1 Feature + first HIGH engine-risk ADR for Input Handling Foundation + **first stateful battle-scoped Node ADR for HP/Status Core**) |

---

## Coverage summary

| Layer | TRs (est.) | ADRs existing | ADRs required | Status |
|---|---|---|---|---|
| Platform | — (infra) | 3 (ADR-0001..0003 Accepted) | 0 more | ✅ Complete |
| Foundation | ~66 | 5 (ADR-0004 + ADR-0006 + ADR-0009 + ADR-0007 + ADR-0005 Accepted) | 0 more | ✅ **5/5 Complete** |
| Core | ~47 | **2** (ADR-0008 + **ADR-0010** Accepted) | 1+ more (Turn Order signal) | ⚠️ **2/2** with HP/Status closed; ADR-0011 Turn Order still gap |
| Feature | ~25 | 1 (ADR-0012 Accepted) | 2+ (AI, Grid Battle, Destiny Branch) | ⚠️ 1/3 |
| Presentation | ~10 | 0 | 1+ (Dual-focus UI pattern) | ❌ 0/1 |
| Polish | ~2 | 0 | 1 (Accessibility, if tier committed) | ❌ 0/1 |

**Net-new ADRs required before Pre-Production → Production gate**: 2–6 (ADR-0010 landed this pass; closes ADR-0012 Damage Calc's `get_modified_stat` + `apply_damage` upstream Core soft-dep; first stateful battle-scoped Node ADR — pattern boundary precedent extended). Next critical path is ADR-0011 Turn Order (closes ADR-0012's remaining `get_acted_this_turn` soft-dep + resolves Turn Order → AI signal-inversion contract per `architecture.md` blocker §1).

---

## Registered TR-to-ADR map (source: tr-registry.yaml v9)

These 121 requirements have permanent IDs and are already covered by an Accepted ADR.

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
| TR-unit-role-001 | unit-role | ADR-0009 | Accepted | §1 Module form — `class_name UnitRole extends RefCounted` + `@abstract` (runtime-error guard on `.new()`) + all-static + lazy-init JSON config; 4-precedent stateless-calculator pattern (ADR-0008→0006→0012→0009) |
| TR-unit-role-002 | unit-role | ADR-0009 | Accepted | §2 UnitClass typed enum — `enum UnitClass { CAVALRY=0..SCOUT=5 }`; typed parameter binding `unit_class: UnitRole.UnitClass` improves on ADR-0008's raw int terrain_type pattern |
| TR-unit-role-003 | unit-role | ADR-0009 | Accepted | §3 Public API — 8 static methods (5 derived stats + move_range + cost_table + direction_mult) + 1 const PASSIVE_TAG_BY_CLASS Dictionary; orthogonal per-stat (NOT bundled UnitStats Resource) |
| TR-unit-role-004 | unit-role | ADR-0009 | Accepted | §4 Per-class config — `assets/data/config/unit_roles.json` 6×12 schema; lazy-init JSON.new().parse() + safe-default fallback; session-persistent cache |
| TR-unit-role-005 | unit-role | ADR-0009 | Accepted | §4 + Engine Compat — Global caps via BalanceConstants.get_const(key) per ADR-0006; G-15 _cache_loaded reset obligation in every UnitRole test suite |
| TR-unit-role-006 | unit-role | ADR-0009 | Accepted | §5 Cost-matrix unit-class dim — 6×6 per CR-4; `get_class_cost_table(UnitClass) -> PackedFloat32Array` 6-entry; ratifies ADR-0008's deferred placeholder per §Context item 5 |
| TR-unit-role-007 | unit-role | ADR-0009 | Accepted | §6 Class direction mult — 6×3 CLASS_DIRECTION_MULT per CR-6a + EC-7 + entities.yaml; runtime read via unit_roles.json (per-class data locality), NOT BalanceConstants; STRATEGIST/COMMANDER all-1.0 no-op rows by design |
| TR-unit-role-008 | unit-role | ADR-0009 | Accepted | §5 R-1 mitigation — PackedFloat32Array per-call copy COW semantics; forbidden_pattern unit_role_returned_array_mutation + caller-mutation regression test mandatory |
| TR-unit-role-009 | unit-role | ADR-0009 | Accepted | §7 Passive tag canonicalization — 6 StringName tags locked (&"passive_charge"..&"passive_ambush"); Array[StringName] mandatory per ADR-0012 damage_calc_dictionary_payload |
| TR-unit-role-010 | unit-role | ADR-0009 | Accepted | Non-emitter invariant per ADR-0001 line 375; forbidden_pattern unit_role_signal_emission; static-lint enforcement zero `signal `/`connect(`/`emit_signal(` matches |
| TR-unit-role-011 | unit-role | ADR-0009 | Accepted | F-1..F-5 stat derivation — clamp ranges [1,ATK_CAP], [1,DEF_CAP], [HP_FLOOR+1,HP_CAP], [1,INIT_CAP], [MOVE_RANGE_MIN,MOVE_RANGE_MAX]; 100% test coverage required per technical-preferences |
| TR-unit-role-012 | unit-role | ADR-0009 | Accepted | Performance — derived-stat <0.05ms / cost_table <0.01ms / direction_mult <0.01ms / per-battle init <0.6ms total; headless CI baseline + on-device deferred per damage-calc story-010 Polish-deferral pattern |
| TR-hero-database-001 | hero-database | ADR-0007 | Accepted | §1 Module form — `class_name HeroDatabase extends RefCounted` + `@abstract` (G-22 typed-reference parse-time block) + all-static + lazy-init `Dictionary[StringName, HeroData]` (Godot 4.4+); 5th-precedent stateless-static pattern (ADR-0008→0006→0012→0009→0007) |
| TR-hero-database-002 | hero-database | ADR-0007 | Accepted | §2 HeroData Resource — 26 @export fields (7 identity + 4 core stats + 2 derived seeds + 1 movement + 2 role + 4 growth + 2 skill parallel arrays + 3 scenario + 1 relationships) + nested HeroFaction enum; Resource overhead trade-off acknowledged (Item 8 2026-04-30) |
| TR-hero-database-003 | hero-database | ADR-0007 | Accepted | §3 Storage — single `assets/data/heroes/heroes.json`; lazy-init `JSON.new().parse()` line/col diagnostics; mirrors ADR-0006/0008/0009 4-precedent JSON pattern |
| TR-hero-database-004 | hero-database | ADR-0007 | Accepted | §4 Public API — 6 static query methods (get_hero / get_heroes_by_faction / get_heroes_by_class / get_all_hero_ids / get_mvp_roster / get_relationships); G-2 typed-array construction MANDATORY for return values |
| TR-hero-database-005 | hero-database | ADR-0007 | Accepted | Read-only contract — consumers MUST NOT mutate returned HeroData fields; forbidden_pattern hero_data_consumer_mutation; R-1 mitigation regression test asserts mutation IS visible (proving convention is sole defense) |
| TR-hero-database-006 | hero-database | ADR-0007 | Accepted | CR-1 + AC-01 — hero_id format `^[a-z]+_\d{3}_[a-z_]+$` regex; FATAL severity full-load reject on violation |
| TR-hero-database-007 | hero-database | ADR-0007 | Accepted | CR-2 + AC-02..AC-05 — schema range checks per-record FATAL: stats [1,100], seeds [1,100], move_range [2,6], growth [0.5,2.0]; pre-cache validation |
| TR-hero-database-008 | hero-database | ADR-0007 | Accepted | EC-1 + AC-12 — duplicate hero_id FATAL full-load reject (no partial state); silent overwrite forbidden |
| TR-hero-database-009 | hero-database | ADR-0007 | Accepted | EC-2 + EC-3 + AC-07 + AC-13 — skill parallel-array integrity per-record FATAL on length mismatch; both length 0 ACCEPTED (no innate skills valid) |
| TR-hero-database-010 | hero-database | ADR-0007 | Accepted | EC-4 + EC-5 + EC-6 + AC-14 — relationship WARNING tier (self-ref / orphan FK / asymmetric conflict); load continues; offending entries dropped or both kept (Formation Bonus ADR adjudicates) |
| TR-hero-database-011 | hero-database | ADR-0007 | Accepted | F-1..F-4 + AC-08..AC-11 — stat balance validation DEFERRED to Polish-tier `tools/ci/lint_hero_database_validation.sh`; thresholds via BalanceConstants per ADR-0006 (forward-compat only); Polish-deferral pattern stable at 5+ invocations |
| TR-hero-database-012 | hero-database | ADR-0007 | Accepted | CR-4 default_class — int storage with cross-doc convention 1:1 alignment with UnitRole.UnitClass enum 0..5; inspector-authoring instability rationale (Item 3 corrected wording 2026-04-30) |
| TR-hero-database-013 | hero-database | ADR-0007 | Accepted | Non-emitter invariant per ADR-0001 line 372; forbidden_pattern hero_database_signal_emission; 4-precedent stateless-non-emitter discipline (mirrors ADR-0006/0009/0012) |
| TR-hero-database-014 | hero-database | ADR-0007 | Accepted | §1 Lazy-init + G-15 test isolation — `_heroes_loaded = false` reset in `before_test()` mandatory; 3-precedent G-15 mirror (ADR-0006/0009/0007) |
| TR-hero-database-015 | hero-database | ADR-0007 | Accepted | Performance — get_hero <0.001ms / scans <0.05ms for 10-hero MVP / load <100ms target for 100-hero Alpha (AC-15 forward-compat); ~50KB cache 10-hero, ~500KB Alpha; headless CI baseline + on-device deferred |
| TR-input-handling-002 | input-handling | ADR-0005 | Accepted | §1 Module form — InputRouter Autoload Node /root/InputRouter load order 4; class_name InputRouter extends Node + 6 mutable fields (_state/_active_mode/_pre_menu_state/_undo_windows/_input_blocked_reasons/_bindings); 5-precedent stateless-static pattern EXPLICITLY REJECTED as Alternative 4 (engine-level structural incompatibility — Node lifecycle callbacks cannot fire on RefCounted) |
| TR-input-handling-003 | input-handling | ADR-0005 | Accepted | §4 + CR-1 22 StringName actions in ACTIONS_BY_CATEGORY const Dictionary (10 grid + 4 camera + 5 menu + 3 meta); CR-1a hover-only ban; CR-1c grid_hover PC-only; ACTIONS_BY_CATEGORY ↔ default_bindings.json parity validation at _ready (R-5 mitigation FATAL push_error on mismatch) |
| TR-input-handling-004 | input-handling | ADR-0005 | Accepted | §4 + CR-1b external default_bindings.json (FileAccess+JSON.new().parse 4-precedent JSON pattern); InputMap.add_action+action_add_event for runtime population (corrected pre-Write per godot-specialist Item 8 — Input.parse_input_event was factual misuse); InputEvent matches by keycode/button-index NOT pressed state (delta #6 Item 3 verification §7); set_binding(action, event) Settings/Options sole caller |
| TR-input-handling-005 | input-handling | ADR-0005 | Accepted | §3 + CR-2 Last-device-wins mode by most-recent-event-class rule; engine-validated PASS Item 1 — Godot 4.6 dual-focus split affects Control-layer visual focus but NOT event-class identity; InputRouter operates BELOW Control focus layer via _unhandled_input; CR-2c state preservation across mode switch; HUD hint update on next frame via input_mode_changed signal |
| TR-input-handling-006 | input-handling | ADR-0005 | Accepted | §5 7-state inline match-dispatch FSM (S0..S6 int wire-format); single dispatch path _handle_action(action, ctx); GameBus.input_state_changed + input_action_fired emission at end of dispatch; ST-2 demotion S2/S4 → S1 on menu exit (line 126 inline comment refresh per delta #6 Item 10c Advisory E); re-entrancy hazard for non-deferred subscribers per Advisory D mitigated by ADR-0001 §5 deferred-connect mandate |
| TR-input-handling-007 | input-handling | ADR-0005 | Accepted | §5 + CR-4 Touch protocol — TPP (CR-4a preview bubble S0+TOUCH; second tap → S1); Magnifier Panel (CR-4c F-2 trigger DISAMBIG_EDGE_PX < 8 OR DISAMBIG_TILE_PX < 55); Pan-vs-tap classifier (CR-4f F-3 PAN_ACTIVATION_PX > 12 OR MIN_TOUCH_DURATION_MS < 80 reject); Two-finger gestures camera-only (CR-4g cancel pending first-finger selection); Persistent action panel anti-occlusion repositioning (CR-4h) |
| TR-input-handling-008 | input-handling | ADR-0005 | Accepted | §7 + F-1 camera_zoom_min = 44/64 = 0.6875 → 0.70 derivation via DisplayServer.screen_get_size; flagged for §Verification §5a (logical DPI-aware pixels on Android — godot-specialist Item 5 plausible but not explicitly confirmed); Camera (provisional §9) enforces clamp [camera_zoom_min, camera_zoom_max] |
| TR-input-handling-009 | input-handling | ADR-0005 | Accepted | §1 + §5 + CR-5 Per-unit undo Dictionary[int, UndoEntry] keyed by unit_id (depth 1 per unit); window opens S2 confirm → S0; closes on attack/end_unit_turn/end_player_turn; pruned at battle-end (~2KB heap); restores coord+facing+has_moved=false+state→S1 (CR-5d); does NOT restore damage/status (CR-5e); blocked if pre-move tile occupied (EC-5/CR-5f); button always visible dims unavailable (CR-5c) |
| TR-input-handling-010 | input-handling | ADR-0005 | Accepted | §1 + Implementation Notes Advisory C + ADR-0002 ratification — InputRouter consumes ui_input_block/unblock_requested for S5 entry/exit; _input_blocked_reasons stack supports nested S5; SceneManager directly calls set_process_input(false)+set_process_unhandled_input(false) (godot-specialist PASS Item 4 both required for autoload Nodes); INPUT_BLOCKED arm calls get_viewport().set_input_as_handled() before silent-drop (forbidden_pattern input_router_input_blocked_drop_without_set_input_as_handled) |
| TR-input-handling-011 | input-handling | ADR-0005 | Accepted | §6 SDL3 gamepad pass-through KEYBOARD_MOUSE for MVP (no GAMEPAD mode); OQ-1 partially resolved (full GAMEPAD mode deferred to post-MVP additive enum int=2); SDL3 button index remapping advisory godot-specialist Item 3 (not affecting ADR-0005 routing; post-MVP GAMEPAD ADR must verify per-controller); Bluetooth hot-plug 1-2 frame detection latency R-2 hardware-layer concern out of MVP scope |
| TR-input-handling-012 | input-handling | ADR-0005 | Accepted | §7 Android edge-to-edge / safe-area — 3-candidate API list per /architecture-review delta #6: (1) DisplayServer.window_get_safe_title_margins() plural; (2) DisplayServer.get_display_safe_area() (review-time candidate Item 5 surfaced by independent validation); (3) fallback DisplayServer.window_get_position_with_decorations() (desktop-windowing API likely insufficient); §Verification Required §5b mandatory before first story; export-preset 16KB-page out of scope |
| TR-input-handling-013 | input-handling | ADR-0005 | Accepted | §8 DI test seam InputRouter._handle_event(event: InputEvent) — sole synthetic event injection seam for GdUnit4 v6.1.2; before_test() reset of _state + _active_mode + _pre_menu_state + _undo_windows.clear() + _input_blocked_reasons.clear() + _bindings.clear() then repopulate from JSON fixture (G-15 mirror obligation; _bindings.clear() addition per delta #6 godot-specialist Item 7); mirrors damage-calc story-006 RNG-injection pattern (proven 11 stories); reusable for Camera + Battle HUD |
| TR-input-handling-014 | input-handling | ADR-0005 | Accepted | §9 Cross-system provisional contracts (4-precedent strategy ADR-0008→0006 / ADR-0012→0009/0010/0011 / ADR-0009→0007 / ADR-0007→Formation Bonus) — 5 unwritten downstream ADRs commit verbatim from GDD: Camera (screen_to_grid + camera_zoom_min enforcement + drag state OQ-2); Grid Battle (is_tile_in_move/attack_range); Battle HUD (show_unit_info/show_tile_info + read get_active_input_mode); Settings/Options (set_binding); Tutorial (subscribe input_action_fired); each downstream ADR can WIDEN never NARROW |
| TR-input-handling-015 | input-handling | ADR-0005 | Accepted | §Verification + CR-2e + R-3 emulate_mouse_from_touch=false in [input_devices.pointing] of project.godot for ALL builds; CI lint script tools/ci/lint_emulate_mouse_from_touch.sh (forbidden_pattern emulate_mouse_from_touch_enabled); 6 mandatory verification items before InputRouter epic ships first story (1 dual-focus E2E / 2 SDL3 detection / 3 emulate setting / 4 recursive Control disable / 5a screen_get_size DPI / 5b safe-area API / 6 touch index physical hardware) |
| TR-input-handling-016 | input-handling | ADR-0005 | Accepted | §Performance + Validation §8/§10 — CPU per-event dispatch <0.05ms minimum-spec mobile; _handle_event <0.05ms / _handle_action <0.02ms; total InputRouter heap footprint <10KB << 512MB ceiling; _ready() JSON parse <5ms single-shot at autoload init; cross-platform determinism (no float-point math); on-device measurement deferred per damage-calc story-010 Polish-deferral pattern (stable at 6+ invocations) |
| TR-input-handling-017 | input-handling | ADR-0005 | Accepted | §4 + Validation §3/§4 — Non-emitter for non-Input GameBus signals; sole emitter of 3 Input-domain signals per ADR-0001 §7 lines 329-335 (NOT on lines 370-377 non-emitter list — factual correction per delta #6 Item 9); non-emitter by behavior for OTHER 21 signals across 8 domains per forbidden_pattern input_router_signal_emission_outside_input_domain; static lints `grep -c 'GameBus\\.input_'` returns 3 + `grep -c 'GameBus\\.' | grep -v '^GameBus\\.input_'` returns 0; carried advisory for next ADR-0001 amendment line 168 String → StringName (delta #6 Item 10a) |
| TR-hp-status-002 | hp-status | ADR-0010 | Accepted | §1 Battle-scoped Node child of BattleScene (lifecycle alignment with ADR-0004); 5-precedent stateless-static rejected as Alt 3 (engine-incompatible — stateful + signal-listening per ADR-0005 §Alt 4 pattern boundary); Autoload rejected as Alt 1 (CR-1b non-persistence); Component Node rejected as Alt 2 (cross-unit query overhead); ECS rejected as Alt 4 (non-Godot-idiomatic); pattern boundary precedent extended for future stateful battle-scoped Node ADRs (Grid Battle, AI System candidates) |
| TR-hp-status-003 | hp-status | ADR-0010 | Accepted | §3 UnitHPState RefCounted 6-field schema (unit_id int / max_hp int / current_hp int / status_effects Array[StatusEffect] / hero HeroData ref / unit_class int); RefCounted NOT Resource per battle-scoped non-serialized + matches ADR-0012 4-RefCounted-wrapper precedent |
| TR-hp-status-004 | hp-status | ADR-0010 | Accepted | §4 StatusEffect typed Resource 7 @export fields + separate TickEffect Resource for DoT formula reuse; 5 .tres templates in assets/data/status_effects/; shallow `.duplicate()` intentional per delta-#7 Item 2 (read-only sub-Resource pattern + hot-reload behavior note added) |
| TR-hp-status-005 | hp-status | ADR-0010 | Accepted | §5 Public API 8 methods + 1 emitted signal `unit_died(int)` per ADR-0001 line 155 + 1 consumed signal `unit_turn_started(int)` per ADR-0011 provisional; non-emitter for 21 OTHER signals (Validation §4 grep gate) |
| TR-hp-status-006 | hp-status | ADR-0010 | Accepted | §6 + F-1 + EC-03 Damage intake 4-step pipeline with EC-03 DEFEND_STANCE-first bind-order; explicit `int(floor(...))` cast per delta-#7 Item 9; MIN_DAMAGE dual-enforcement with Damage Calc per ADR-0012 line 92; unit_died emit AFTER mutation per Verification §5; CR-8c Commander auto-trigger DEMORALIZED radius |
| TR-hp-status-007 | hp-status | ADR-0010 | Accepted | §7 + F-2 + CR-4a/b Healing 4-step pipeline; CR-4b dead-units-cannot-be-healed early-return; CR-4a no-overheal min cap; explicit int cast convention per delta-#7 Item 9 applied to Step 2 EXHAUSTED multiplier |
| TR-hp-status-008 | hp-status | ADR-0010 | Accepted | §8 Status effect lifecycle — CR-7 mutex / CR-5c refresh / CR-5d coexist / CR-5e MAX 3 slots `pop_front()` eviction; reverse-index `while i >= 0` removal pattern per delta-#7 Item 7 PASS; DoT-then-decrement order per GDD §States and Transitions line 243-245 |
| TR-hp-status-009 | hp-status | ADR-0010 | Accepted | §9 + F-4 Modifier application — base_stat dispatch via stat_name match to UnitRole accessors; F-4 sum + clamp [MODIFIER_FLOOR, MODIFIER_CEILING] + `max(1, int(floor(base × (1 + total/100.0))))` per delta-#7 Item 9; EXHAUSTED move-range special-case branch (flat -1 not percent); DEFEND_STANCE_ATK_PENALTY pre-folded via modifier_targets per ADR-0012 line 89-93 contract |
| TR-hp-status-010 | hp-status | ADR-0010 | Accepted | §10 + CR-7 DEFEND_STANCE+EXHAUSTED mutex enforcement woven into apply_status: EXHAUSTED→DEFEND_STANCE attempt returns false (UI: "피로로 태세 유지 불가" per AC-15); DEFEND_STANCE→EXHAUSTED apply force-removes BEFORE append per AC-16 |
| TR-hp-status-011 | hp-status | ADR-0010 | Accepted | §11 + CR-8 + R-6 Death + DEMORALIZED propagation; unit_died emit AFTER current_hp=0 per Verification §5; Commander auto-trigger MapGrid radius scan via `_propagate_demoralized_radius`; is_morale_anchor branch DEFERRED post-MVP per OQ-2 (HeroData schema gap); MapGrid DI via `_map_grid: MapGrid` field with R-3 assert; R-6 mitigation: radius scan invoked from BOTH apply_damage + DoT-kill branch (Validation §11) |
| TR-hp-status-012 | hp-status | ADR-0010 | Accepted | §12 27 BalanceConstants entries — story-level same-patch obligation (mirrors ADR-0007 §Migration §4 + ADR-0009 §Migration §From provisional 5-precedent); CI lint `tools/ci/lint_balance_entities_hp_status.sh`; ATK_CAP/DEF_CAP ownership transferred from ADR-0012 line 297-299; DEFEND_STANCE_ATK_PENALTY=-40 documented as INERT per grid-battle v5.0 CR-13 rule 4 |
| TR-hp-status-013 | hp-status | ADR-0010 | Accepted | §13 + Validation §5 DI test seam `_apply_turn_start_tick(unit_id)` direct call bypass GameBus subscription; `_map_grid` constructor-injected MapGridStub in tests; G-15 reset (BalanceConstants._cache_loaded = false) + fresh HPStatusController.new() per test; static-lint `grep -c '^static var' src/core/hp_status_controller.gd` returns 0 (R-4 forbidden_pattern hp_status_static_var_state_addition) |
| TR-hp-status-014 | hp-status | ADR-0010 | Accepted | §1 + R-1 Re-entrant unit_died emission during DEMORALIZED propagation: ADR-0001 §5 CONNECT_DEFERRED mandate eliminates cross-scene synchronous re-entrancy; `_state_by_unit.keys()` Array snapshot semantics safe per delta-#7 Item 6 PASS; same-scene forbidden_pattern hp_status_re_entrant_emit_without_deferred; unit test fixture asserts re-entrancy safe-or-explicitly-forbidden |
| TR-hp-status-015 | hp-status | ADR-0010 | Accepted | R-5 + Validation §12 Consumer mutation forbidden_pattern hp_status_consumer_mutation; `get_status_effects` returns shallow copy with shared StatusEffect references; documented test asserts mutation IS visible cross-call (proving convention is sole defense) — fail-state regression test, not protective |
| TR-hp-status-016 | hp-status | ADR-0010 | Accepted | §Performance + Validation §8 — apply_damage <0.05ms / get_modified_stat <0.05ms / apply_status <0.10ms / `_apply_turn_start_tick` <0.20ms minimum-spec mobile; heap footprint <10KB << 512MB ceiling; on-device measurement deferred per damage-calc story-010 Polish-deferral pattern (stable at 6+ invocations) |
| TR-hp-status-017 | hp-status | ADR-0010 | Accepted | §Verification §1 + §9 + Validation §9 Cross-platform determinism: same call sequence produces identical `current_hp` + `status_effects[]` final state on macOS Metal + Linux Vulkan + Windows D3D12; integer arithmetic + deterministic `floor()` semantics; headless CI deterministic-fixture test mandatory before Polish |
| TR-hp-status-018 | hp-status | ADR-0010 | Accepted | Cross-doc unit_id type advisory (delta-#7 Phase 4 Pair ADR-0010↔ADR-0012); ADR-0010 LOCKS `unit_id: int` to match ADR-0001 line 155 signal-contract source-of-truth; ADR-0012 lines 89/260/352-353 use StringName — carried advisory for next ADR-0012 amendment; queues with delta #6 Item 10a (ADR-0001 line 168 String→StringName) + delta #5 ADR-0007 carry (ADR-0001 line 372 prose drift) |

---

## Pending TR baseline (73 extracted 2026-04-18, not yet registered)

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

### design/gdd/hero-database.md (15 TRs — REGISTERED 2026-04-30)

Registered as TR-hero-database-001..015 in tr-registry.yaml v7. See "Registered TR-to-ADR map" section above for the full table. The 15 GDD ACs (AC-01..AC-15) map to the TR layer 1:1 — hero-database's GDD is content-shaped (rather than the unit-role 23-ACs / 12-TRs sub-test ratio); most ACs are 1:1 with TR-level architectural commitments. AC-08..AC-11 (F-1..F-4 validation forms) are all deferred per ADR-0007 §5 to Polish-tier tooling and tracked by TR-hero-database-011.

### design/gdd/hp-status.md (17 TRs — REGISTERED 2026-04-30 delta #7)

Registered as TR-hp-status-002..018 in tr-registry.yaml v9. See "Registered TR-to-ADR map" section above for the full table. The original 11-candidate seed list (damage intake pipeline, healing pipeline, 5 MVP status effects, slot mgmt, POISON DoT formula, DEMORALIZED propagation, DEFEND_STANCE/EXHAUSTED mutual exclusion, stat modifier clamps, unit_died signal emission, morale-anchor field expansion, death mid-round handling) expanded to 17 net-new TRs covering R-1..R-7 risks + cross-ADR consumer contracts + cross-doc unit_id type advisory. TR-hp-status-001 (signal exposure via ADR-0001) was already registered 2026-04-18; total per-system TR count now 18 (1 ADR-0001-adjacent + 17 ADR-0010-specific). Core layer 1/2 → **2/2** upon this delta's acceptance (HP/Status closed; ADR-0011 Turn Order still gap).

### design/gdd/input-handling.md (16 TRs — REGISTERED 2026-04-30 delta #6)

Registered as TR-input-handling-002..017 in tr-registry.yaml v8. See "Registered TR-to-ADR map" section above for the full table. The original 11-candidate seed list (22-action vocabulary, auto-detect mode, 7 input states, 2-beat confirmation, TPP, magnifier, pan-vs-tap, per-unit undo, JSON bindings, camera_zoom_min=0.70, HUD mode hints) expanded to 16 net-new TRs covering R-1..R-6 risks + cross-ADR consumer contracts + Item 9 non-emitter clarification. TR-input-handling-001 (signal exposure via ADR-0001) was already registered 2026-04-18; total per-system TR count now 17 (1 ADR-0001-adjacent + 16 ADR-0005-specific). Foundation layer 4/5 → **5/5 Complete** upon this delta's acceptance.

### design/gdd/map-grid.md (10 TRs — REGISTERED 2026-04-20)

Registered as TR-map-grid-001..010 in tr-registry.yaml v3. See "Registered TR-to-ADR map" section above for the full table.

### design/gdd/scenario-progression.md (5 candidate TRs — v2.0 re-review pending)

_Large broadcast surface (23 signals × 8 domains in ADR-0001 contract). Five candidate TRs: chapter progression state, hero join condition tags, destiny branch tree, 34-signal set, Save/Load persistence contract. Target ADRs: ⏳ Scenario Progression ADR + ⏳ Destiny Branch ADR (separate ownership)._

### design/gdd/terrain-effect.md (12 candidate TRs)

_Full rows deferred. Seed: terrain modifiers caps, elevation modifiers ±2 asymmetric, defense stacking clamp, evasion stacking clamp, bridge chokepoint FLANK→FRONT, AI terrain scoring, damage formula, Tactical Read passive, High Ground Shot passive, HUD stack-cap display, terrain overlay toggle, evasion dodge animation. Target ADR: ⏳ ADR-0008 Terrain Effect (depends on ADR-0004)._

### design/gdd/turn-order.md (13 candidate TRs)

_Full rows deferred. Seed: interleaved queue, round lifecycle R1/R2/R3/RE1–3, per-unit turn T1–T7, action tokens, `acted_this_turn` semantics, tie-breaking, static initiative, death-mid-round, charge budget, round cap 30, signal ownership (per TR-turn-order-001 already registered), TurnOrderSnapshot. Target ADRs: covered partially by ADR-0001 signal ownership + ⏳ Turn Order finalization ADR._

### design/gdd/unit-role.md (12 TRs — REGISTERED 2026-04-28)

Registered as TR-unit-role-001..012 in tr-registry.yaml v6. See "Registered TR-to-ADR map" section above for the full table. The 23 GDD ACs (AC-1..AC-23) are a finer granularity than the architectural TR layer — they map to ADR-0009 via the §GDD Requirements Addressed table.

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
| 2026-04-28 | 0.5 | Delta review: ADR-0009 (Unit Role) escalated Proposed → Accepted. 12 new TR-unit-role-* entries registered (registry v5→v6). Foundation layer 2/5 → 3/5. Ratifies ADR-0008's cost-matrix unit-class dimension placeholder + ADR-0012's CLASS_DIRECTION_MULT (corrected [4][3]→[6][3] in same patch). godot-specialist independent review-time validation: APPROVED WITH SUGGESTIONS (8/8 PASS-or-CONCERN); 2 corrections applied pre-acceptance (§1 line 130 parse-time→runtime; ADR-0012 line 42 dim amendment). Sprint-1 S1-07 closure. Source: `docs/architecture/architecture-review-2026-04-28.md`. |
| 2026-04-30 | 0.6 | Delta review: ADR-0007 (Hero Database) escalated Proposed → Accepted. 15 new TR-hero-database-* entries registered (registry v6→v7). Foundation layer 3/5 → **4/5** (only Input Handling ADR-0005 remaining; HIGH engine risk). Closes ADR-0009's only outstanding upstream soft-dep (provisional HeroData → ratified 26-field shape). godot-specialist independent review-time validation: APPROVED WITH SUGGESTIONS (8/8 PASS-or-CONCERN); 2 wording-only corrections applied pre-acceptance (§2 default_class wording — Item 3; §2 Resource overhead acknowledgement — Item 8). 1 advisory carried for next ADR-0001 amendment (line 372 prose API name drift `hero_database.get(unit_id)` → `HeroDatabase.get_hero(hero_id: StringName)`). 5-precedent fresh-session /architecture-review pattern stable (avg 2 wording corrections / delta). Source: `docs/architecture/architecture-review-2026-04-30.md`. |
| 2026-04-30 | 0.7 | Delta review #6: ADR-0005 (Input Handling) escalated Proposed → Accepted. **First HIGH engine-risk ADR for this project**. 16 new TR-input-handling-002..017 entries registered (registry v7→v8); total registered TRs 88 → 104. Foundation layer 4/5 → **5/5 Complete** (LAST Foundation-layer ADR — entire layer now coherent with Accepted ADR coverage). godot-specialist independent review-time validation: APPROVED WITH SUGGESTIONS (8/8 + Item 10 multi-sub-finding); **6 pre-acceptance precision-gap corrections applied same-patch** (Item 3 InputMap pressed-state matching note; Item 5 §7 safe-area 3-candidate list — added DisplayServer.get_display_safe_area review-time candidate; Item 7 `_bindings.clear()` G-15 reset addition at §8 + Validation §5; Item 9 ADR-0005 line 476 + registry/architecture.yaml line 425 factually-wrong "MUST update to remove input-handling" claim — InputRouter was never on ADR-0001 non-emitter list). 2 advisories codified as Implementation Notes D + E (re-entrancy hazard for non-deferred subscribers; `_pre_menu_state` ST-2 demotion inline comment refresh). 1 advisory carried for next ADR-0001 amendment: line 168 `action: String` → `action: StringName` (Item 10a). 6-invocation /architecture-review pattern: above-average correction count (6 vs ~2 prior avg) attributed to HIGH engine risk + longer ADR + first-of-its-kind module-form pattern boundary. Source: `docs/architecture/architecture-review-2026-04-30b.md`. |
| 2026-04-30 | 0.8 | Delta review #7: ADR-0010 (HP/Status) escalated Proposed → Accepted. **First Core-layer ADR + first stateful battle-scoped Node form** (vs. 5 prior stateless-static + 1 stateful Autoload). 17 new TR-hp-status-002..018 entries registered (registry v8→v9); total registered TRs 104 → 121. Core layer 1/2 → **2/2** with HP/Status closed (ADR-0011 Turn Order still gap). Closes ADR-0012 Damage Calc's outstanding upstream Core-layer soft-dep — `get_modified_stat` (lines 89-93/340-352) + `apply_damage` (line 260) + MIN_DAMAGE / ATK_CAP / DEF_CAP / DEFEND_STANCE_ATK_PENALTY ownership transferred to ADR-0010 §12. godot-specialist independent review-time validation: APPROVED WITH SUGGESTIONS (10/10 items addressed; 5 PASS + 3 CONCERN→corrected + 2 advisories carried). **3 pre-acceptance precision-gap corrections applied same-patch** (Item 1 §1 typed Dictionary[int, UnitHPState] declaration consistency between code block and architecture diagram; Item 2 §4 footnote extension with hot-reload behavior note + deprecated-apis.md scope clarification — read-only sub-Resource sharing is correct pattern, NOT subject to duplicate_deep mandate; Item 9 §6 line 250 + §9 line 397 explicit `int(floor(...))` cast for `-> int` return-type honesty + editor SAFE-mode warning elimination). 2 advisories carried as Implementation Notes (Item 5 emit_signal deprecation form runtime behavior; Item 8 lazy load vs battle-init pre-warm — acceptable for MVP turn-based cadence). 1 cross-doc precision-gap advisory queued for next ADR-0012 amendment: lines 89/260/352-353 `unit_id: StringName` → `unit_id: int` (TR-hp-status-018; ADR-0010 LOCKS int per ADR-0001 line 155 signal-contract source-of-truth; queues with delta #6 Item 10a + delta #5 ADR-0007 carry). Pattern boundary precedent extended: stateless-static for systems CALLED; Node-based form for systems that LISTEN AND/OR hold mutable state — battle-scoped Node form vs. autoload Node form codified for future stateful Core/Feature ADRs (Grid Battle, AI System likely candidates). 7-invocation /architecture-review pattern stable (avg ~2.7 corrections/delta; this delta = 3 corrections, slightly above mean for first stateful battle-scoped Node form needing wording precision around typed Dictionary + numeric coercion). Source: `docs/architecture/architecture-review-2026-04-30c.md`. |
