# Story 002: initialize_battle BI-1..BI-6 sequence + F-1 tie-break cascade + queue construction

> **Epic**: Turn Order
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-005`, `TR-turn-order-010`, `TR-turn-order-014`, `TR-turn-order-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011 — Turn Order — initialize_battle mutator + F-1 cascade + CR-9 BI-1..BI-6 sequence; ADR-0007 (HeroData stat_agility tie-break); ADR-0009 (UnitRole.get_initiative)
**ADR Decision Summary**: TR-005 = `initialize_battle(unit_roster: Array[BattleUnit]) -> void` executes BI-1 through BI-5 (collect units, compute initiative via UnitRole.get_initiative, init per-unit flags, init counters, apply battle-start effects); BI-6 transitions `_round_state` to ROUND_STARTING + triggers `_begin_round.call_deferred()` Callable method-reference form (NOT string-based per godot-specialist Item 6); subscribes to GameBus.unit_died on first call only (idempotent connect; deferred to story-005). TR-010 = F-1 tie-break cascade (initiative DESC + stat_agility DESC + is_player_controlled DESC + unit_id ASC). TR-014 = CR-6 static initiative MVP rule (cached at BI-2, NOT recomputed at R3). TR-016 = BI-1..BI-6 sequence with hero_id↔unit_id mapping established at BI-1.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Callable.call_deferred()` method-reference form (godot-specialist 2026-04-30 Item 6; stable since 4.0; NOT `call_deferred("method_name")` string-based form which is deprecated-apis pattern). Array sort with custom Callable comparator (`Array.sort_custom(Callable)` — Godot 4.x stable).

**Control Manifest Rules (Core layer)**:
- Required: BalanceConstants reads via `BalanceConstants.get_const(key)` accessor (no direct file reads); UnitRole.get_initiative call respects ADR-0009 §3 parameter binding (`hero: HeroData, unit_class: UnitRole.UnitClass`); `_begin_round.call_deferred()` Callable method-reference form
- Forbidden: string-based `call_deferred("method_name")` per project deprecated-apis pattern; recomputing initiative at R3 (CR-6 violates) — initiative cached at BI-2 only; sorting by `is_player_controlled` BEFORE initiative (F-1 cascade order is fixed)
- Guardrail: queue sort O(N log N) with N ≤ 20 units; AC-23 budget < 1ms on minimum target hardware (story-007 verifies)

---

## Acceptance Criteria

*From GDD `design/gdd/turn-order.md` §CR-9 + §CR-5 + §CR-6 + §F-1 + ADR-0011 §Decision §Public mutator API + §F-1 cascade, scoped to this story:*

- [ ] **AC-1** (TR-005, BI-1) `initialize_battle(unit_roster: Array[BattleUnit]) -> void` accepts roster; BI-1 establishes hero_id (StringName) → unit_id (int) mapping internally; rejects empty roster via `push_error` + early return
- [ ] **AC-2** (TR-016, BI-2) initiative computed via `UnitRole.get_initiative(hero, unit_class)` for each unit; results cached in per-unit UnitTurnState (NOT recomputed at R3 per CR-6)
- [ ] **AC-3** (TR-016, BI-3) `_unit_states` populated with one UnitTurnState per unit_id: `move_token_spent=false`, `action_token_spent=false`, `accumulated_move_cost=0`, `acted_this_turn=false`, `turn_state=IDLE`
- [ ] **AC-4** (TR-016, BI-4) counters initialized: `_round_number=0`, `_queue_index=0`, `_round_state=BATTLE_INITIALIZING`
- [ ] **AC-5** (TR-016, BI-5) battle-start effects deferred to Grid Battle / Formation Bonus per orchestrator hand-off (no-op in this implementation; documented exit-deferral)
- [ ] **AC-6** (TR-016, BI-6) `_round_state` transitions to ROUND_STARTING; `_begin_round.call_deferred()` invoked using Callable method-reference form (NOT string-based)
- [ ] **AC-7** **GDD AC-12 Battle Initialization Clean State** — after BI-1..BI-5 execution, all units have `acted_this_turn = false`, `turn_state = IDLE`, `current_round_number = 0`, no DEFEND_STANCE present
- [ ] **AC-8** **GDD AC-01 Interleaved Queue No Phase Alternation** — given 3 player units (init 120/90/60) + 3 enemy units (init 110/80/50), queue order is [P:120, E:110, P:90, E:80, P:60, E:50] — no player-phase or enemy-phase grouping
- [ ] **AC-9** **GDD AC-07 Tie-Breaking stat_agility Resolution** — Unit A (init=120, agi=85, player, id=2) and Unit B (init=120, agi=60, AI, id=5) → A precedes B (resolved at F-1 Step 1: stat_agility 85 > 60)
- [ ] **AC-10** **GDD AC-08 Tie-Breaking Player-Controlled Resolution** — Unit A (init=108, agi=70, player, id=3) and Unit B (init=108, agi=70, AI, id=7) → A precedes B (resolved at F-1 Step 2: is_player_controlled 1 > 0)
- [ ] **AC-11** **GDD AC-13 F-1 Deterministic Total Order** — given 20 units where some share initiative + stat_agility, R3 executes 100 times with same input → identical output every time; no two units share position
- [ ] **AC-12** **GDD AC-09 Static Initiative No Mid-Battle Recalculation** — given a battle in Round 3 where a status effect is applied, next R3 queue build → affected unit's queue position identical to Round 2 (initiative values from BI-2 snapshot, never recomputed)
- [ ] **AC-13** Regression baseline maintained: ≥6 new tests; full suite ≥574 cases / 0 errors / ≤1 carried failure / 0 orphans

---

## Implementation Notes

*Derived from ADR-0011 §Decision §Public mutator API + §F-1 cascade + godot-specialist 2026-04-30 Items 6 + 8:*

1. **F-1 cascade implementation** — use `Array.sort_custom(Callable)` with comparator that returns true if `a` should come before `b`:
   ```gdscript
   _queue.sort_custom(func(a: int, b: int) -> bool:
       var sa: UnitTurnState = _unit_states[a]
       var sb: UnitTurnState = _unit_states[b]
       # ... access cached initiative + stat_agility + is_player_controlled
       if sa.initiative != sb.initiative: return sa.initiative > sb.initiative   # DESC
       if sa.stat_agility != sb.stat_agility: return sa.stat_agility > sb.stat_agility   # DESC
       if sa.is_player_controlled != sb.is_player_controlled: return sa.is_player_controlled   # DESC (true > false)
       return a < b   # unit_id ASC final guarantee
   )
   ```
   NOTE: `initiative`, `stat_agility`, `is_player_controlled` need to be cached on UnitTurnState per BI-2/BI-3 step; if not on UnitTurnState by current schema, read via Battle Preparation roster snapshot held in a parallel `_unit_metadata: Dictionary[int, BattleUnitMetadata]` instance field. **Decision deferral**: orchestrator at /dev-story time will choose between (a) extend UnitTurnState with 3 metadata fields, or (b) add `_unit_metadata` 6th instance field (would require ADR amendment — instance field count exceeds ADR-0011 §State Ownership 5-field lock). Recommend (a).

2. **BI-2 initiative computation** — `UnitRole.get_initiative(hero: HeroData, unit_class: UnitRole.UnitClass) -> int` per ADR-0009 §3. `hero` is read from `HeroDatabase.get_hero(hero_id)` per ADR-0007 (hero_id from BI-1 mapping). One-time per-unit per-battle cadence — value cached on UnitTurnState/metadata.

3. **BI-6 _begin_round Callable method-reference form** (godot-specialist Item 6):
   ```gdscript
   # CORRECT
   _begin_round.call_deferred()

   # FORBIDDEN — string-based form is deprecated-apis pattern
   call_deferred("_begin_round")
   ```

4. **Test seam consideration**: `initialize_battle` is the public mutator entry point; tests directly call it with synthetic BattleUnit roster fixtures. NO `_advance_turn` test seam invocation in this story (story-003 scope).

5. **GameBus.unit_died subscription DEFERRED to story-005** — `initialize_battle` does NOT call `GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)` in this story (the story-005 scope adds the subscription; this story's BI-1..BI-6 leaves the connect call commented out with a `# TODO story-005` marker).

6. **BattleUnit type** — soft-dep on Battle Preparation ADR (unwritten). For tests, use a minimal stub:
   ```gdscript
   class_name BattleUnit extends RefCounted
   var unit_id: int
   var hero_id: StringName
   var unit_class: int   # UnitRole.UnitClass int per CR-4 + ADR-0009
   var is_player_controlled: bool
   ```
   When Battle Preparation ADR ships, this stub will be replaced; the contract is parameter-stable per ADR-0011 §Decision §Public mutator API.

7. **G-14 obligation**: if BattleUnit class_name is new, run `godot --headless --import --path .` post-write before first test run.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Module skeleton + 5 instance fields + 3 RefCounted wrappers (already done — gates this story)
- **Story 003**: `_advance_turn(unit_id)` T1..T7 sequence (this story stops at BI-6 + first `_begin_round.call_deferred()` invocation; the actual T1..T7 lifecycle is story-003)
- **Story 005**: GameBus.unit_died subscription + CONNECT_DEFERRED + R-1 mitigation (this story leaves the connect call as `# TODO story-005` marker)
- **Story 006**: Victory detection T7 / RE2 (this story does NOT emit `victory_condition_detected`; story-006 owns it)

---

## QA Test Cases

*Lean mode — orchestrator-authored:*

**AC-1..AC-6 BI-1..BI-6 sequence** (via state-after assertions):
- Given: a 4-unit BattleUnit roster (2 player + 2 enemy)
- When: `runner.initialize_battle(roster)`
- Then: `_unit_states.size() == 4`, all entries have IDLE turn_state + acted_this_turn=false + accumulated_move_cost=0; `_round_number == 0`; `_queue_index == 0`; `_round_state == ROUND_STARTING` (post-BI-6)
- Edge cases: empty roster → push_error + early return + `_round_state` stays BATTLE_NOT_STARTED; single-unit roster → BI-1..BI-6 succeed with 1-element _queue

**AC-7 GDD AC-12 Clean State**:
- Given: post-`initialize_battle(roster)` for 4-unit roster
- When: assert each `_unit_states[unit_id]` field
- Then: all 4 units have move_token_spent=false, action_token_spent=false, accumulated_move_cost=0, acted_this_turn=false, turn_state=IDLE; `_round_number == 0`; no DEFEND_STANCE field references (DEFEND_STANCE lives in HP/Status — out of scope)

**AC-8 GDD AC-01 Interleaved Queue**:
- Given: 6-unit roster (3 player init 120/90/60 + 3 enemy init 110/80/50)
- When: `runner.initialize_battle(roster)` AND assert `runner._queue` ordered by initiative DESC
- Then: `_queue == [P:120, E:110, P:90, E:80, P:60, E:50]` exact order — no phase grouping

**AC-9 GDD AC-07 stat_agility tie-break**:
- Given: 2-unit roster (A: init=120 agi=85 player id=2; B: init=120 agi=60 AI id=5)
- When: `runner.initialize_battle(roster)`
- Then: `_queue == [2, 5]` (A precedes B because stat_agility 85 > 60)

**AC-10 GDD AC-08 player_controlled tie-break**:
- Given: 2-unit roster (A: init=108 agi=70 player id=3; B: init=108 agi=70 AI id=7)
- When: `runner.initialize_battle(roster)`
- Then: `_queue == [3, 7]` (A precedes B because is_player_controlled true > false)

**AC-11 GDD AC-13 Determinism (100 iterations)**:
- Given: 20-unit roster with intentional initiative + stat_agility ties (e.g., 5 pairs of identical (init, agi) values)
- When: 100 iterations of fresh `runner.initialize_battle(roster)` (G-15 reset between each)
- Then: all 100 `_queue` results are identical (use `.hash()` comparison or element-by-element equality)
- Edge case: shuffle input roster order → output `_queue` still identical (sort eliminates input-order dependency)

**AC-12 GDD AC-09 Static Initiative No Mid-Battle Recalc**:
- Given: post-`initialize_battle(roster)` with 3 units; mutate one unit's metadata via reflective set (e.g., simulate status effect raising initiative)
- When: re-trigger queue rebuild (calling internal `_rebuild_queue()` directly via TEST SEAM OR re-invoke `initialize_battle` should be guarded since this is one-time)
- Then: queue order unchanged (initiative cached at BI-2; not re-read from mutated source)
- NOTE: pure unit test — no actual round execution required; story-003 covers R3 lifecycle integration.

**AC-13 Regression**:
- Given: full GdUnit4 suite
- Then: ≥574 cases / 0 errors / 1 carried failure / 0 orphans

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/turn_order_initialize_battle_test.gd` — new file (~10-12 tests covering AC-1..AC-12)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (module skeleton + 5 instance fields + 3 RefCounted wrappers) ✅ gates this story
- Unlocks: Story 003 (_advance_turn needs initialized state from this story)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 13/13 passing (100% covered — 11 ACs map to direct test functions + AC-2 implicit via real-hero initiative compute + AC-5 documented no-op deferral + AC-13 verified via full-suite regression)
**Test Evidence**: `tests/unit/core/turn_order_initialize_battle_test.gd` — 12 test functions + 2 helpers; standalone **12/12 PASS** (181ms); full regression 573→**585 / 0 errors / 1 carried failure / 0 orphans** (carried failure = pre-existing orthogonal `test_hero_data_doc_comment_contains_required_strings`; not introduced); story-001 regression check **9/9 PASS** (UnitTurnState 6→9 expansion non-breaking)
**Code Review**: APPROVED WITH SUGGESTIONS (4 advisory items — all forward-looking or cosmetic; none blocking)

### Files Modified (4)

- `src/core/turn_order_runner.gd` (194 → 344 LoC, +150) — `initialize_battle()` full BI-1..BI-6 implementation; double-init guard (`_round_state != BATTLE_NOT_STARTED`) + empty-roster guard correctly ordered; per-unit HeroData caching (avoiding double `HeroDatabase.get_hero()` call across BI-2/BI-3); 4 private helpers (`_rebuild_queue` + `_compare_units_for_queue` F-1 cascade + `_begin_round` stub + `_on_unit_died` stub); 1 public test seam (`_seed_unit_state_for_test` — 5-precedent extension of DI seam pattern); `# TODO story-005` marker for GameBus.unit_died subscription. Orchestrator-fixed G-9 paren-binding violation in `_seed_unit_state_for_test` push_error message post-agent-write.
- `src/core/unit_turn_state.gd` (64 → 94 LoC, +30) — 6 → 9 fields (`initiative: int = 0`, `stat_agility: int = 0`, `is_player_controlled: bool = false`); `snapshot()` extended to copy all 9 fields field-by-field; header doc-comment notes 9-field count + same-patch amendment date 2026-05-01 + cross-link to ADR-0011 §Decision amendment.
- `docs/architecture/ADR-0011-turn-order.md` (+8 lines) — 3-line code-block update inside §Decision §Typed Resource UnitTurnState block (added 3 new field declarations + snapshot() body extension to copy all 9 fields) + 1-paragraph dated prose amendment block (2026-05-01) citing story-002 trigger + CR-6 storage-location enforcement rationale + perf budget alignment with §AC-23 < 1ms 20-unit sort.
- `docs/architecture/tr-registry.yaml` — TR-turn-order-004 requirement text revised "with 6 fields" → "with 9 fields" with field-list extension citing BI-2/BI-3 caching cadence + F-1 cascade Step 1/Step 2 read-by; `revised: "2026-05-01"` annotation added.

### Files Created (2)

- `src/core/battle_unit.gd` (41 LoC) — `class_name BattleUnit extends RefCounted` stub with 4 fields (`unit_id: int`, `hero_id: StringName`, `unit_class: int`, `is_player_controlled: bool`) per ADR-0011 §Migration Plan §3 parameter-stable contract. Replaced when Battle Preparation ADR ships.
- `tests/unit/core/turn_order_initialize_battle_test.gd` (667 LoC, 12 tests + 2 helpers) — covers AC-1..AC-12 with 2-tier strategy: AC-1..AC-7 use real MVP heroes from `HeroDatabase` (assert structural state, not specific numeric values); AC-8..AC-12 use `_seed_unit_state_for_test()` synthetic-injection seam to override cached metadata + call `_rebuild_queue()` directly. AC-11 deterministic-queue test runs 100 iterations × 20 units (~31ms actual; well within budget). AC-12 mutates `_unit_states[id].initiative` directly post-init to prove `_rebuild_queue()` reads from cache (not re-queries HeroDatabase).

### Same-Patch Amendments Landed

- **ADR-0011 §Decision §Typed Resource / wrapper definitions**: UnitTurnState 6 → 9 fields code-block update + dated 2026-05-01 prose paragraph citing story-002 trigger + CR-6 storage-location enforcement + perf budget alignment
- **TR-turn-order-004**: requirement text revised + `revised: "2026-05-01"` annotation
- These amendments resolved the orchestrator-deferred design decision per Implementation Note 1 option (a). ADR amendment process precedent established by ADR-0011 §Migration Plan §0 (which itself amended ADR-0001 same-patch with `victory_condition_detected` signal addition).

### Code Review Suggestions Captured (forward-looking; non-blocking)

- **S-1 (cosmetic)**: Test file header comment (lines 11-13) lists wrong TR-IDs (`TR-turn-order-011/012/013/014/015` — none of those refer to this story). Story actually traces to TR-005/010/014/016. Documentation-only; no functional impact. Worth a one-line fix in a future cleanup pass.
- **S-2 (cosmetic)**: `src/core/turn_order_runner.gd` lines 144-147 has duplicate BI-5 deferral comment (same content repeated immediately). Cosmetic; remove redundant line in future cleanup.
- **S-3 (minor logic)**: AC-12 test (line 662-667) sanity guard `assert_bool(_runner._queue[0] != initial_first)` fires unconditionally. Comment acknowledges the degenerate edge case where `initial_first == last_unit_id` would falsely fail. With 3 real heroes producing distinct initiative values, currently safe. Could gate with `if last_unit_id != initial_first:` or remove (primary AC-12 assertion at line 651-657 is sufficient).
- **S-4 (forward-look, no action)**: Story-001's "AC-3 — UnitTurnState `class_name UnitTurnState extends RefCounted` with exactly 6 fields" wording is now stale (file has 9). Story-001's tests still pass via `content.contains()`. Acceptable historical record — story-001 was correct AT THE TIME. No correction required; just noted for future story-author awareness when retroactive ADR amendments expand schema.

### Engineering Discipline

- **G-2** typed-array preservation throughout (`ids.assign(_unit_states.keys())` for Dictionary-key extraction; `_queue.clear() + .append_array()` per `turn_order_typed_array_reassignment` forbidden_pattern; never `_queue = ids`)
- **G-7** verified Overall Summary count grew (573 → 585, +12 new tests; 0 silent skips)
- **G-9** paren-wrap multi-line `%` format strings throughout test file + 1 violation caught in source (`_seed_unit_state_for_test` push_error) and orchestrator-fixed post-agent-write
- **G-12** `BattleUnit` not a Godot built-in — verified safe (LoadDB / dimensional check)
- **G-14** import refresh post-write (regenerates `.uid` files for new `battle_unit.gd` + class cache for 9-field UnitTurnState)
- **G-15** `before_test()` (canonical hook); `auto_free()` per `game_bus_declaration_test.gd` precedent for Runner cleanup; per-iteration in-test reset for AC-11 100-iteration determinism check
- **G-16** typed-array of Dictionary for AC-11 seeds (`Array[Dictionary]`)
- **G-23** safe assertions only (no `is_not_equal_approx`)
- **G-24** paren-wrap `as int` casts in `==` comparisons throughout test file

### Out-of-Scope Deviations

NONE. No method bodies for `_advance_turn` / `declare_action` / `_on_unit_died` / 5 query methods (all stay as story-001 stubs); no signal connect/emit; no GameBus references (TODO comment marker only); no ActionType/VictoryResult enums; no story-001 test file modifications; no other src/ or tests/ files modified outside the listed set.

### Multi-Agent Flow Note

This story required 2 sub-agent spawns due to mid-task termination on the first agent:
- **Agent #1** completed full check-in plan + wrote 3 src files + ADR-0011 inline 3-line code-block update, then terminated mid-task with "Now let me update the ADR and TR registry" (output prematurely truncated). Did NOT write the prose amendment paragraph or TR-004 revision or test file.
- **Orchestrator** finished docs directly: TR-turn-order-004 revision via Edit tool + ADR-0011 prose amendment paragraph appended via Edit tool + caught + fixed G-9 paren violation in `_seed_unit_state_for_test` push_error.
- **Agent #2** spawned with NARROWED scope (test file only, no source/doc edits) — completed cleanly with 12/12 standalone PASS + 9/9 story-001 verification + 585/0/1/0 full regression.

**Pattern logged**: when an agent terminates mid-task with a substantive output, orchestrator picks up doc/yaml edits directly + spawns a NARROW-SCOPE follow-up agent for any remaining file writes (tests, source). Avoid re-spawning broad-scope agents which risk re-termination on the same context complexity.

### Sprint Impact

Turn-order epic story 2/7 Complete. Sprint-2 day ~2 of 13; this is the second Core-layer feature implementation work of sprint-2 (after story-001 skeleton). Sprint-2 must-have 5/5 still done; should-have 2/4 still done; turn-order impl is bonus throughput beyond sprint-2 commitment. Unblocks story-003 (`_advance_turn` T1..T7 sequence + state machine + 3 emitted signals — Logic, 3-4h, blocks on story-001 + story-002).
