# Story 003: Stage 0 — invariant guards + evasion roll (F-DC-2)

> **Epic**: damage-calc
> **Status**: Complete (2026-04-26)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (DamageCalc class declaration + invariant guards + Stage-0 evasion roll + 7 ACs)
> **Actual**: ~3 hours (initial impl ~2h + 1 CI iteration on TestResolveModifiersBypass parse failure + closure paperwork)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-005`, `TR-damage-calc-012` (source_flags error vocab)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: Stateless `class_name DamageCalc extends RefCounted` with single `static func resolve()` entry point. Per-call seeded RNG injection via `ResolveModifiers.rng`; 1 `randi_range` call per non-counter, 0 per counter, 0 per skill-stub. Invariant guards (rng_null / bad_attack_type / unknown_direction / unknown_class) return flagged MISS via `ResolveResult.miss([&"invariant_violation:reason"])` per ADR-0012 §Implementation Guidelines #4 + AC-DC-19/22/28.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `randi_range(from, to)` is inclusive on both ends — pinned via AC-DC-49 in story-008, but used here for the evasion roll. `RandomNumberGenerator` is typed and deterministic (per godot-specialist Item 7). Skill stub early return must be the FIRST guard (per F-DC-1 line ordering) so RNG is not consumed for skill paths (AC-DC-18 RNG call count = 0).

**Control Manifest Rules (Feature layer)**:
- Required: All `static func` methods on RefCounted; no instance state, no signals
- Required: StringName literals (`&"FRONT"`, `&"invariant_violation:rng_null"`, etc.) — never plain `String` for flag/direction/passive comparisons
- Forbidden: `signal` declarations or `connect()` calls in `damage_calc.gd` (per ADR-0001 non-emitter list line 375 + AC-DC-34 static lint in story-006)
- Forbidden: Mutating caller's `modifiers.source_flags` array — error guards must construct new `Array[StringName]` per ADR-0012 §12 (covered in story-006 in full but the pattern starts here)

---

## Acceptance Criteria

*From `damage-calc.md` §F-DC-1 + §F-DC-2 + invariant guard ACs:*

- [ ] `src/feature/damage_calc/damage_calc.gd` declares `class_name DamageCalc extends RefCounted` with single `static func resolve(attacker: AttackerContext, defender: DefenderContext, modifiers: ResolveModifiers) -> ResolveResult` public method
- [ ] **AC-DC-18 (EC-DC-11)**: `modifiers.skill_id != ""` — returns MISS immediately, `source_flags.has(&"skill_unresolved")`, RNG.randi_range call count = 0, vfx_tags empty
- [ ] **AC-DC-19 (EC-DC-13)**: `modifiers.rng == null` — `push_error("...")` fires; returns MISS with `source_flags.has(&"invariant_violation:rng_null")`
- [ ] **AC-DC-22 (EC-DC-16)**: `modifiers.direction_rel ∈ {null, &"DIAGONAL"}` — `push_error()` fires; returns MISS with `source_flags.has(&"invariant_violation:unknown_direction")`
- [ ] **AC-DC-28 (EC-DC-12)**: `modifiers.attack_type` outside `{PHYSICAL, MAGICAL}` — returns MISS with `source_flags.has(&"invariant_violation:bad_attack_type")` (test via `TestResolveModifiersBypass` subclass per ADR-0012 §Implementation Guidelines + AC-DC-21 pattern)
- [ ] **AC-DC-10 (D-10 evasion MISS)**: `terrain_evasion=30, seeded rng returning 25, is_counter=false` — returns MISS, hp_status mock NOT called
- [ ] **AC-DC-14 (EC-DC-4)**: terrain_evasion=30, roll=30 → MISS (inclusive `<=` boundary); roll=31 → HIT (passes Stage 0)
- [ ] **AC-DC-26 (EC-DC-5)**: terrain_evasion=0 → always HIT; RNG still consumed exactly once (replay determinism)
- [ ] Stage-0 returns HIT-eligible `null` (caller proceeds to Stage 1) — actual Stage 1+ logic implemented in stories 004-006; this story has Stage 0 return either MISS-with-flag or proceed-token
- [ ] Skeleton private helpers stubbed: `_evasion_check`, `_invariant_guard_rng_null`, `_invariant_guard_unknown_direction`, `_invariant_guard_bad_attack_type`, `_invariant_guard_skill_stub`. Empty bodies allowed for stages 1-4 stubs (return `0` placeholders), but Stage 0 fully implemented.

---

## Implementation Notes

*Derived from ADR-0012 §1 + §5 + §12 + Implementation Guidelines #4 + damage-calc.md §F-DC-1/F-DC-2:*

- **Order of guard checks** (per F-DC-1 line ordering, MUST NOT reorder — affects AC-DC-18 RNG call count = 0):
  1. Skill stub: `if modifiers.skill_id != "": return ResolveResult.miss([&"skill_unresolved"])`
  2. RNG null: `if modifiers.rng == null: push_error("..."); return ResolveResult.miss([&"invariant_violation:rng_null"])`
  3. attack_type: `if modifiers.attack_type not in [PHYSICAL, MAGICAL]: push_error("..."); return ResolveResult.miss([&"invariant_violation:bad_attack_type"])`
  4. direction_rel: `if not (modifiers.direction_rel in [&"FRONT", &"FLANK", &"REAR"]): push_error("..."); return ResolveResult.miss([&"invariant_violation:unknown_direction"])`
  5. unknown_class guard (AC-DC-21): deferred to story-005 (Stage-2 direction multiplier needs the unit_class lookup, so unknown_class fires there)
  6. Evasion roll (Stage 0): F-DC-2 — `if not modifiers.is_counter: var roll := modifiers.rng.randi_range(1, 100); if roll <= clampi(defender.terrain_evasion, 0, 30): return ResolveResult.miss([&"evasion"])`
- **`push_error()` fires for all invariant violations**: error log surfaces the defect for developers; the testable surface is the flag in `source_flags`, NOT `Engine.get_error_count()` (which is a fabricated API per damage-calc.md AC-DC-19 commentary).
- **Error-flag vocabulary** (per ADR-0012 §Implementation Guidelines #4): `rng_null`, `bad_attack_type`, `unknown_direction`, `unknown_class`. Tests assert via `result.source_flags.has(&"invariant_violation:rng_null")` etc.
- **Stage 1+ stubs**: subsequent stories (004-006) replace the placeholders. To keep this story's tests passable, Stage 0 returning HIT-eligible (i.e., not returning early MISS) should produce a `ResolveResult.hit(0, modifiers.attack_type, [], [])` placeholder — story-004 will replace this with the real Stage 1 base damage. Document this with a `# TODO(story-004): replace Stage-0-passes placeholder with real Stage 1 call` comment.
- **AC-DC-26 RNG consumption invariant**: even with `terrain_evasion = 0`, the `randi_range(1, 100)` call still fires (consumed once per non-counter path). The check `roll <= 0` is always false (since roll ≥ 1 from inclusive range), so HIT proceeds. This is intentional per F-DC-2 — replay determinism requires the RNG advance to be call-count-stable per path (1 per non-counter regardless of evasion value).
- **Counter path**: `if modifiers.is_counter: # skip evasion entirely per CR-2`. RNG call count = 0 on counter path (AC-DC-20 in story-006 verifies).
- **`TestResolveModifiersBypass`** for AC-DC-28: subclass declared in `tests/helpers/test_resolve_modifiers_bypass.gd` per ADR-0012 §Implementation Guidelines + AC-DC-21 pattern. Subclass shadows `attack_type` as `var attack_type: int = 0` (untyped int), allowing `attack_type = 99` to bypass enum binding. Production-exclusion grep lint: `TestResolveModifiersBypass` must NOT appear in any `src/` file.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: Stage 1 base damage (CR-3..CR-6, F-DC-3) — replaces the Stage-0-passes placeholder
- Story 005: Stage 2 direction × passive multiplier (F-DC-4 + F-DC-5) + AC-DC-21 unknown_class guard (lookup-site triggered)
- Story 006: Stage 3-4 raw damage + counter halve + final cap + ResolveResult construction + source_flags semantics + AC-DC-20 RNG call counts

---

## QA Test Cases

*Authored from damage-calc.md §F-DC-2 + AC-DC-10/14/18/19/22/26/28 directly. Developer implements against these.*

- **AC-1 (AC-DC-18)**: skill stub early return
  - Given: `var mod := ResolveModifiers.make(PHYSICAL, rng, &"FRONT", 1, false, "fireball")`
  - When: `DamageCalc.resolve(atk, def, mod)`
  - Then: `result.kind == MISS`, `result.source_flags.has(&"skill_unresolved") == true`, `result.vfx_tags.is_empty()`, RNG.randi_range call count = 0
  - Edge cases: `skill_id == ""` (default) does NOT trigger skill-stub path; `skill_id == " "` (whitespace) DOES trigger (string non-empty check)

- **AC-2 (AC-DC-19)**: rng_null guard
  - Given: `var mod := ResolveModifiers.make(...)` with `mod.rng = null` set after construction
  - When: `DamageCalc.resolve(atk, def, mod)`
  - Then: `push_error()` log entry observed (manual visual log check; not asserted in code); `result.kind == MISS`, `result.source_flags.has(&"invariant_violation:rng_null") == true`; hp_status mock NOT called
  - Edge cases: rng = freshly-constructed `RandomNumberGenerator.new()` (with default seed 0) does NOT trigger guard; only `null` does

- **AC-3 (AC-DC-22)**: unknown_direction guard
  - Given: `var mod := ResolveModifiers.make(PHYSICAL, rng, &"DIAGONAL", 1)` (or `direction_rel = null`)
  - When: `DamageCalc.resolve(atk, def, mod)`
  - Then: `push_error()` fires (visual); `result.source_flags.has(&"invariant_violation:unknown_direction") == true`
  - Edge cases: each of `&"FRONT"`, `&"FLANK"`, `&"REAR"` passes the guard; case-sensitivity matters (`&"front"` lowercase fails)

- **AC-4 (AC-DC-28)**: bad_attack_type guard
  - Given: `var mod := TestResolveModifiersBypass.new()` with `mod.attack_type = 99` (subclass-bypassed enum)
  - When: `DamageCalc.resolve(atk, def, mod)`
  - Then: `result.source_flags.has(&"invariant_violation:bad_attack_type") == true`
  - Edge cases: enum values 0 (PHYSICAL) and 1 (MAGICAL) both pass; future enum 2+ fails until enum widened

- **AC-5 (AC-DC-10 D-10 evasion MISS)**: seeded MISS
  - Given: `defender.terrain_evasion = 30`, RNG seeded to produce 25 on next `randi_range(1, 100)`, `modifiers.is_counter = false`
  - When: `DamageCalc.resolve(...)`
  - Then: `result.kind == MISS`, `result.source_flags.has(&"evasion")`, hp_status mock call count = 0
  - Edge cases: same scenario with `is_counter = true` SKIPS evasion (counter-path RNG call count = 0); proceeds to Stage 1

- **AC-6 (AC-DC-14)**: evasion boundary inclusive
  - Given: terrain_evasion=30, two test runs — RNG seeded for roll=30 then roll=31
  - When: each resolve()
  - Then: roll=30 → MISS; roll=31 → proceeds to Stage 1 (HIT-eligible)
  - Edge cases: terrain_evasion=29 with roll=30 → HIT (`30 <= 29` is false); confirms `<=` not `<`

- **AC-7 (AC-DC-26)**: zero evasion always HIT, RNG advances once
  - Given: `defender.terrain_evasion = 0`; RNG snapshot before; 100 calls in loop
  - When: each `resolve(...)` with `is_counter = false`
  - Then: 0 MISS results out of 100; RNG state advanced exactly 100 times (1 call per resolve)
  - Edge cases: counter path with terrain_evasion=0 advances RNG zero times across 100 calls

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage_calc/damage_calc_test.gd` — Stage 0 + invariant test functions; must exist and pass on headless CI

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (wrappers exist) + Story 001 (CI infrastructure)
- Unlocks: Story 004 (Stage 1 base damage replaces Stage-0-passes placeholder)

---

## Completion Notes

**Completed**: 2026-04-26
**Verdict**: COMPLETE WITH NOTES
**Criteria**: 7/7 passing — covered by 13 test functions on Linux headless gdUnit4 CI (PR #56 run, "13 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 63ms")
**Code Review**: Skipped — lean mode + orchestrator-direct (story-002's pattern). CI was the authoritative gate; caught the TestResolveModifiersBypass parse error on first run.
**Test Evidence**: `tests/unit/damage_calc/damage_calc_test.gd` — 13 test functions covering 7 ACs with sub-cases:
- AC-1 (skill stub): 1a (RNG calls=0) + 1b (default empty skill_id passes through)
- AC-2 (rng null guard): 1
- AC-3 (unknown direction): 3a (DIAGONAL) + 3b (empty StringName) + 3c (FRONT/FLANK/REAR all pass)
- AC-4 (bad attack_type): 1 (direct int-to-enum assignment, see deviation below)
- AC-5 (seeded MISS): 5a (seed 266 → roll 25 MISS) + 5b (counter skips evasion, RNG unchanged)
- AC-6 (boundary inclusive): 6a (seed 84 → roll 30 MISS) + 6b (seed 53 → roll 31 HIT)
- AC-7 (zero evasion): 7a (RNG advances 100 times across 100 calls) + 7b (counter never advances)

**Deviations (advisory)**:

1. **TestResolveModifiersBypass subclass abandoned** — Story §QA Test Cases AC-4 + §Implementation Notes called for `class_name TestResolveModifiersBypass extends ResolveModifiers` shadowing `attack_type` as untyped int. **Godot 4.6 parser rejected** at parse time: "Parse Error: Could not resolve external class member 'attack_type'". The shadowing pattern (`var attack_type: int = 0` in subclass when parent declares `var attack_type: AttackType`) is not supported by Godot 4.6 GDScript even with `@warning_ignore("shadowed_variable_base_class")`.
   - **Replacement**: direct `mod.attack_type = 99` assignment on the parent `ResolveModifiers` class with `@warning_ignore("int_as_enum_without_cast")` decorator. GDScript enums are runtime ints, so out-of-range int values pass parse-time and trigger the runtime guard via `not in [PHYSICAL, MAGICAL]`.
   - **Same AC coverage** (AC-4 / AC-DC-28); simpler mechanism; no helper file needed (`tests/helpers/test_resolve_modifiers_bypass.gd` deleted in fix commit `c2aa5d4`).
   - **Codify candidate (G-16)**: "Subclass var-shadowing of parent's enum-typed field with `var foo: int` fails Godot 4.6 parse — assign out-of-range int directly to enum-typed parent field for bypass-seam tests instead." Pair with story-002's `Engine.has_class()` slip (story-002 = `Engine` vs `ClassDB` API split for collision check); both are training-data gaps for Godot 4.6 specifics caught by CI.

2. **Stub helpers retained** (`_evasion_check`, `_invariant_guard_*`) — return `false` placeholders per story §Implementation Notes "Empty bodies allowed for stages 1-4 stubs"; logic inlined in `resolve()` for story-003. Story-004 will inline-or-extract per Stage 1 needs. No action.

**PRs landed**: #56 (story-003 implementation, 2 commits — initial + bypass-subclass fix). Predecessor PR #55 (story-002 closure paperwork) merged immediately before.

**Damage-calc epic progress**: **3/10 stories complete** (vertical-slice 3/7). Stories 004-007 remain on first-playable damage roll demo core path (target ~5/24 end of Sprint 2).

**Unlocks**: damage-calc story-004 (Stage 1 base damage + BASE_CEILING) — replaces the Stage-0-passes placeholder. First actual damage formula in the project.
