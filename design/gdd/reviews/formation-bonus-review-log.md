# Formation Bonus System — Design Review Log

Target: `design/gdd/formation-bonus.md`
Owner: game-designer + systems-designer (parallel specialist authoring)

---

## Review — 2026-04-20 — Verdict: NEEDS REVISION (pass-1, first review of v1.0)
Scope signal: M leaning L (10+ blockers; cross-doc obligations to multiple specs)
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist (5-spec lean — no creative-director synthesis since convergent findings are mechanical/clear)
Blocking items: ~10 (3 convergent, 7 specialist-unique) | Recommended: 5+ | Cross-doc obligations: 5+
Prior verdict resolved: First review.

### Specialist verdicts

| Specialist | Verdict | Top items |
|---|---|---|
| game-designer | CONCERNS | BLK-1 Vignette 1 misleading at Cavalry+Charge+Rally apex (Formation absorbed by P_MULT_COMBINED_CAP); BLK-2 ceiling-absorption "matters for non-apex" framing dishonest; BLK-3 AC-FB-04 stale 0.02 (should be 0.04 per rev 2.9.1); 5 RECs (MENTOR_STUDENT XP forward-ref, OQ-FB-01 facing decision, relationship magnitudes audit, RIVAL AI awareness, OQ-FB-03 promote to v1.0 contract) |
| systems-designer | CONCERNS | BLK-1 `grid.get_unit_at()` fabricated API (Map/Grid only has `get_adjacent_units`); BLK-2 F-FB-2 asymmetric record miss bug (only queries A's relationships, misses B-held records); BLK-3 AC-FB-04 stale; BLK-4 `set_formation_bonuses()` not formal CR in grid-battle.md |
| ux-designer | NEEDS REVISION | 4 BLOCKERS: forecast Passives line contract gap (UI-GB-04 §4.1 §6 obligation); pattern visualization missing (UI-GB-14 needed even as minimum fallback); relationship bond icon unspecified; WCAG R-2 tile-info panel formation state token gap |
| qa-lead | NEEDS REVISION | 6 ECs unattested (EC-FB-3 dual-pattern stack; EC-FB-5 mid-round completion; EC-FB-6 conflicting records; EC-FB-10 zero-case; EC-FB-11 empty array; EC-FB-12 same-faction RIVAL); formation_def_bonus consumer path unattested cross-doc (BLOCKER); sub-apex formation_atk_bonus path unattested; AC-FB-15 distance-1 boundary half-tested; AC-FB-14 log substring unanchored to spec; fixture schema undocumented (sprint risk HIGH) |
| godot-specialist | CONCERNS | BLOCKER-1 `get_unit_at` fabricated (convergent with systems); BLOCKER-2 `set_formation_bonuses()` not specified (convergent with systems); BLOCKER-3 PatternDef/BonusVal type gap (no class_name spec); CONCERN `manhattan()` not Godot built-in; CONCERN round_started signal source ambiguous |

### Convergent findings (caught by ≥2 specialists)

1. **`grid.get_unit_at()` fabricated API** (systems-designer + godot-specialist) — BLOCKER. Map/Grid exposes only `get_adjacent_units(coord, faction) → Array[int]`. F-FB-1 invented `get_unit_at`. Two resolution paths: (a) add to map-grid.md API; (b) Formation Bonus caches `coord→unit_id` from `units` array internally. Per godot-specialist: option (b) preferred (Formation Bonus self-contained, no new Map/Grid API).
2. **`set_formation_bonuses()` Grid Battle method not formal** (systems-designer + godot-specialist) — BLOCKER. Currently scaffolding-only at grid-battle.md line 905. Needs new CR in grid-battle.md (analogous to CR-15 Rally orchestration).
3. **AC-FB-04 stale `def_bonus += 0.02`** (game-designer + systems-designer) — BLOCKER. Per rev 2.9.1 fix, 방진 def_bonus is 0.04. AC was not updated when CR-FB-10 + Tuning Knob were updated.

### Specialist-unique critical findings

- **F-FB-2 asymmetric record miss bug** (systems-designer) — BLOCKER. Iteration `i < j` only queries A's relationships; if B holds the record (B→A LORD_VASSAL with `is_symmetric=false`), the bonus is silently skipped. Fix: also query `get_relationships(unit_b.hero_id)` symmetrically.
- **6 EC coverage gaps** (qa-lead) — BLOCKER. EC-FB-3 (dual-pattern stack), EC-FB-5 (mid-round completion boundary), EC-FB-6 (conflicting records SWORN_BROTHER + RIVAL), EC-FB-10 (zero-case), EC-FB-11 (empty relationships array), EC-FB-12 (same-faction RIVAL). Gate Summary "all 12 ECs covered" claim is false.
- **formation_def_bonus consumer-side AC missing** (qa-lead) — BLOCKER. Cross-doc Logic path with zero test evidence in either formation-bonus.md or damage-calc.md. AC-FB-11 tests ATK only.
- **Sub-apex formation_atk_bonus path unattested** (qa-lead) — BLOCKER. AC-FB-10 / AC-FB-11 test cap-firing path; no AC tests P_mult < 1.31 (Formation visible, cap not firing).
- **Vignette 1 misleading at Cavalry apex** (game-designer) — Pillar 1 honesty gap. 관우 (Cavalry) at Rally cap sees zero ATK benefit from any formation.
- **4 UX/accessibility BLOCKERS** (ux-designer) — Pillar 1 readability gaps on forecast panel + pattern viz + bond icon + WCAG R-2.
- **PatternDef/BonusVal type gap** (godot-specialist) — pseudocode dot-access (`anchor_bonus.atk`) requires class_name RefCounted; not specified.

### Recommended for v1.1 sweep

User design adjudications likely needed:
- Resolution of `get_unit_at` (option a Map/Grid API vs option b Formation Bonus self-cache)
- Vignette 1 framing (qualify class or rewrite to show non-Cavalry case)
- OQ-FB-01 facing direction (promote or defer with explicit rationale)
- OQ-FB-03 forecast/visual contract (promote minimum fallback to v1.0 vs defer)
- Relationship bonus magnitude audit (+2% felt or invisible at typical DEF)

Mechanical fixes:
- F-FB-1 rewrite without fabricated API
- F-FB-2 query both directions for asymmetric records
- AC-FB-04 0.02 → 0.04
- 6 new ACs for unattested ECs
- formation_def_bonus consumer-side AC (cross-doc damage-calc.md)
- Sub-apex formation_atk_bonus AC
- AC-FB-15 distance-1 companion test
- AC-FB-14 log string spec anchor (update EC-FB-7 with required substring)
- PatternDef + BonusVal class_name RefCounted definitions
- Fixture schema document (`tests/fixtures/formation_bonus/schema.md`)

Cross-doc obligations to apply in v1.1:
- grid-battle.md: new CR for Formation Bonus orchestration (set_formation_bonuses signature + CR-5 step 4 read path) — analogous to CR-15
- battle-hud.md: UI-GB-14 (Formation Aura visual minimum spec), UI-GB-04 §4.1 §6 Formation Passives line, R-2 tile-info panel formation state token
- map-grid.md: either add `get_unit_at()` API OR document that Formation Bonus uses local caching
- accessibility-requirements.md: WCAG R-2 obligation note for Formation state in tile-info

### Next action

Per CD precedent (Grid Battle pass-1 had 16 blockers → STOP; Scenario Progression v1.0 had 30 → STOP for v2.0), Formation Bonus pass-1 with 10+ blockers warrants **STOP for v1.1 fresh session**. Same-session-after-fresh-review is high-risk historically. Bundle for v1.1 session:
- Read this review log entry for full blocker list + adjudication options
- Read `design/gdd/formation-bonus.md` v1.0 + `design/gdd/damage-calc.md` rev 2.9.1 + `design/gdd/grid-battle.md` Dependencies row
- Surface 5 design decisions via AskUserQuestion (get_unit_at resolution, OQ-FB-01 + 03 promotions, relationship magnitudes audit, vignette honesty)
- Spawn 2-3 specialists to author v1.1 fix language
- Apply + narrow re-review
