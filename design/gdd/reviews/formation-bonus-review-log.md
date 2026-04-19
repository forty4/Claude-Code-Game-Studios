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

---

## Review — 2026-04-20 — v1.1 close-out (pass-1 NEEDS REVISION resolution; pre-narrow-re-review)
Scope signal: M (resolves all 10+ pass-1 blockers; 4 user design adjudications applied; cross-doc to 4 files + 1 new file)

### User design adjudications (all Recommended, applied)

1. **`get_unit_at` resolution**: Self-cache in Formation Bonus (Option A). F-FB-1 rewritten to build local `coord_to_unit_id: Dictionary[Vector2i, int]` from `units` array. No new Map/Grid API. map-grid.md gets advisory note only.
2. **Vignette 1 framing**: Rewrite with non-Cavalry anchor (Option A). 관우 Cavalry replaced with nameless 창병 (spear infantry) at ATK 70 / DEF 30 REAR. Damage arithmetic `floori(40 × 1.65 × 1.03) = 68` vs baseline `floori(40 × 1.65) = 66` — +2 clearly visible. Pillar-1 honesty preserved.
3. **OQ promotions**: OQ-FB-03 (HUD visualization) PROMOTED to v1.0 contract (ux-designer cross-doc to battle-hud.md + accessibility-requirements.md). OQ-FB-01 (facing direction) KEPT as OQ with explicit defer-with-rationale (O(P×4) cost + player-readability risk + absolute-coordinate MVP position).
4. **Relationship magnitudes**: LORD_VASSAL vassal DEF 0.02 → 0.04 (Option A). Mirrors 방진 rev 2.9.1 floori-visibility precedent. Other magnitudes unchanged (ATK path visible at 0.02 via P_mult multiplier).

### Specialist-authored drafts applied (4 parallel specialists)

**systems-designer (11 drafts)** applied to `design/gdd/formation-bonus.md`:
- F-FB-1 rewrite with `coord_to_unit_id` self-cache (removes fabricated `grid.get_unit_at()`)
- F-FB-2 bidirectional query + symmetric-pair dedup via `seen_symmetric_pairs` keyed on `"minId_maxId_tag"` (fixes asymmetric record miss)
- F-FB-3a new section — PatternDef + BonusVal `class_name RefCounted` specs (split across 2 files per GDScript 4.6 one-class-per-file rule)
- AC-FB-04 0.02 → 0.04 (stale fix)
- AC-FB-06 0.02 → 0.04 (consistency patch — synthesizer-added)
- 9 new ACs (AC-FB-17–25) covering EC-FB-3/5/6/10/11/12 + sub-apex P_mult + formation_def consumer + distance-1 positive boundary
- Tuning Knob LORD_VASSAL row update (0.04 + floori math)
- EC-FB-7 log substring promotion to explicit spec-anchor ("EC-FB-7: formations.json")
- Dependencies Map/Grid row rewrite (removes `get_unit_at`)
- CR-FB-1 rule 7 + CR-FB-6 rule 5 cross-refs to grid-battle CR-16
- map-grid.md advisory note (self-cache path)

**game-designer (5 drafts)** applied to `design/gdd/formation-bonus.md`:
- Vignette 1 rewrite (non-Cavalry 창병 anchor)
- CR-FB-12 LORD_VASSAL DEF 0.04 + rationale
- New Tuning Note "Relationship DEF floori-visibility"
- OQ-FB-03 RESOLVED
- OQ-FB-01 defer-with-rationale expansion

**ux-designer (4 drafts)** applied to `design/ux/battle-hud.md` + `design/ux/accessibility-requirements.md`:
- UI-GB-14 table row + §3.1 detailed spec (청록 #3A7D6E, 1.2 Hz pulse, octagonal outline, MVP fallback 陣 corner glyph + tile tint, 緣 bond glyph, 6 Tuning Knobs)
- UI-GB-04 §4.1 Section 6 Passives list `Form +X%` entry (KO/EN i18n keys; multi-pattern summed scalar; panel-width analysis)
- §6.1 Palette 청록 entry
- §7 UX-EC-08/09 edge case rows
- R-2 Formation State Token subsection (FORMATION + BOND tokens; multi-state semicolon separator; KO relation labels)
- §9 v1.2 revision row + Formation contrast obligation advisory

**qa-lead**: new file `tests/fixtures/formation_bonus/schema.md` (295 lines). YAML schema with 7 top-level fields + UnitFixture + RelationshipFixture nested types. 15-fixture inventory covering AC-FB-01–22 (non-inline ACs). 2 full YAML examples (wedge_3unit, sworn_brother_pair). GdUnit4 loader contract with FATAL-on-failure error semantics. Cross-refs to hero-database + map-grid.

**godot-specialist (4 drafts)** applied to `design/gdd/grid-battle.md`:
- CR-16 Formation Bonus — Grid Battle Orchestration (8 rules + Purpose line; architectural twin of CR-15 Rally)
- Dependencies table Formation Bonus row v1.1 status
- Battle-state dict scaffolding line 905 → full CR-16 contract pointer
- Downstream overview table Formation Bonus row (was "not yet designed")

### Cross-doc propagation status

| Target file | Obligation | Status |
|---|---|---|
| `design/gdd/formation-bonus.md` | Primary v1.1 spec | ✅ Applied |
| `design/gdd/grid-battle.md` | New CR-16 + 3 table updates | ✅ Applied |
| `design/ux/battle-hud.md` | UI-GB-14 + UI-GB-04 §6 + §6.1 palette + §7 UX-EC-08/09 | ✅ Applied |
| `design/ux/accessibility-requirements.md` | R-2 Formation token + §9 revision + contrast advisory | ✅ Applied |
| `design/gdd/map-grid.md` | Self-cache advisory bullet | ✅ Applied |
| `tests/fixtures/formation_bonus/schema.md` | New file — fixture schema + loader contract | ✅ Created |
| `design/gdd/damage-calc.md` | F-FB-5 / F-DC-5 / F-DC-3 integration | ✅ Already applied (rev 2.9 / 2.9.1 prior commits) |

### Design-weight items surfaced by specialists (tracked for art-director signoff)

1. **청록 #3A7D6E** — provisional Formation palette hex. Contrast ratio measurement TBD (cross-doc obligation in accessibility-requirements.md §4 advisory).
2. **緣 bond glyph** — chosen for semantic fit; needs font-set verification. Fallback candidates: 絆 or ∞ style.
3. **`Form` token** (4 chars) — chosen over `Frm` / `F` / `陣` for forecast Passives line. Locked at v1.1.
4. **Signal name `formation_bonuses_updated`** — ratified in grid-battle.md CR-16 rule 3/6. Consistent across formation-bonus.md CR-FB-6, battle-hud.md §3.1, grid-battle.md CR-16.

### Pass-1 blocker resolution matrix

| Pass-1 blocker | Resolution | Location |
|---|---|---|
| `grid.get_unit_at()` fabricated API | F-FB-1 self-cache + Deps row rewrite | formation-bonus.md F-FB-1, Deps §6; map-grid.md advisory |
| `set_formation_bonuses()` not formal CR | CR-16 authored | grid-battle.md CR-16 rule 3 |
| AC-FB-04 stale 0.02 | Updated to 0.04 | formation-bonus.md AC-FB-04 |
| F-FB-2 asymmetric record miss | Bidirectional query + symmetric-pair dedup | formation-bonus.md F-FB-2 |
| 6 EC coverage gaps (EC-FB-3/5/6/10/11/12) | AC-FB-17 through AC-FB-22 authored | formation-bonus.md §8 |
| formation_def_bonus consumer unattested | AC-FB-24 cross-doc F-DC-3 path | formation-bonus.md AC-FB-24 |
| Sub-apex formation_atk_bonus unattested | AC-FB-23 (P_mult=1.26 sub-cap) | formation-bonus.md AC-FB-23 |
| Vignette 1 Pillar-1 honesty gap | Non-Cavalry rewrite | formation-bonus.md §2 Vignette 1 |
| UX BLOCKER — forecast Passives line | UI-GB-04 §4.1 §6 `Form +X%` entry | battle-hud.md §4.1 |
| UX BLOCKER — pattern visualization | §3.1 UI-GB-14 full + fallback spec | battle-hud.md §3.1 |
| UX BLOCKER — bond icon unspec | 緣 glyph at midpoint, 10px 80% opacity | battle-hud.md §3.1 |
| UX BLOCKER — R-2 tile-info formation | R-2 Formation Token subsection | accessibility-requirements.md §4 |
| PatternDef/BonusVal type gap | F-FB-3a class_name RefCounted spec | formation-bonus.md F-FB-3a |
| AC-FB-14 log string unanchored | EC-FB-7 rewrite promotes substring | formation-bonus.md EC-FB-7 |
| AC-FB-15 distance-1 companion | AC-FB-25 positive-boundary test | formation-bonus.md AC-FB-25 |
| Fixture schema undocumented (HIGH sprint risk) | New file + 15-fixture inventory + loader contract | tests/fixtures/formation_bonus/schema.md |

**Verdict proposal**: pass-1 → v1.1 resolved. Narrow re-review (systems-designer + ux-designer + qa-lead, 3 specialists) to verify draft application quality and surface any v1.1-introduced issues.

---

## Narrow Re-Review — 2026-04-20 — v1.1 post-application (3 specialists)

| Specialist | Verdict | Summary |
|---|---|---|
| systems-designer | **APPROVED** | All 4 pass-1 BLOCKERs resolved. F-FB-1 self-cache correct; F-FB-2 bidirectional + dedup correct; F-FB-3a class_name spec complete; AC-FB-04/06 stale values fixed; 9 new ACs (AC-FB-17–25) arithmetically correct; CR-16 formal 8-rule spec matches. Surfaced one non-blocking prose note: §6 "cross-doc obligations not yet propagated" parenthetical was stale. Fixed this editorial pass. |
| ux-designer | **APPROVED (with advisories)** | All 4 pass-1 UX BLOCKERs resolved. UI-GB-14 full spec + fallback + signal + accessibility complete; UI-GB-04 §6 Formation Passives entry with i18n; §6.1 청록 palette entry; §7 UX-EC-08/09 rows; R-2 Formation State Token subsection complete. Signal name `formation_bonuses_updated` ratified in CR-16. 3 non-blocking advisories surfaced: (a) 청록/청회 cool-family overlap on fallback-mode tiles (art-director palette check scope note); (b) 緣 glyph font-set availability (verify at impl kickoff); (c) R-2 multi-state string length vs tile-info panel width (ui-programmer flag). All 3 are implementation-phase concerns, not spec gaps. |
| qa-lead | **APPROVED WITH CONCERNS (non-blocking)** | All HIGH-risk gaps closed. Schema doc complete; all 9 new ACs (AC-FB-17–25) present with arithmetic verified; EC-FB-7 bidirectional anchor correct; math checked: AC-FB-23 `floori(83 × 1.64 × 1.26) = 171` (+8 delta) correct, AC-FB-24 `eff_def=52 → base=30` correct against damage-calc rev 2.9.1 F-DC-3. Sprint risk reduced from HIGH to LOW. 4 editorial advisories surfaced and addressed this pass: (a) Gate Summary miscount "7+18" → "10+15" fixed; (b) AC-FB-17 cross-ref to AC-FB-09 added; (c) AC-FB-23 base-derivation step made explicit; (d) AC-FB-19 fixture `expected_bonuses` requirement spelled out. |

### Editorial fixes applied this pass (synthesizer — per narrow re-review advisories)

1. Gate Summary: "7 fixture-independent + 18 deferred-fixture" → "10 fixture-independent + 15 deferred-fixture" (accurate count).
2. AC-FB-17: appended "(Cap-firing boundary tested separately in AC-FB-09; this AC proves the cross-field stacking path.)"
3. AC-FB-23: added F-DC-3 base-derivation note `eff_atk=200, eff_def=10 → base = mini(83, max(1, 190)) = 83` + corrected intermediate from 171.8 to 171.5.
4. AC-FB-19: added fixture requirement `expected_bonuses` entries for both unit A and unit B.
5. §6 Cross-doc obligations: stale "not yet propagated — pending implementation pass" parenthetical replaced with explicit v1.1 propagation status table (7 of 10 obligations applied; 3 pending as future implementation-phase work — balance-data.md, entities.yaml, hero-database.md confirmation).

### Final verdict

**Formation Bonus #3 v1.1 — APPROVED.**

Pass-1 NEEDS REVISION is resolved. All 10+ pass-1 blockers closed. No new blockers introduced by v1.1. Advisory items (3 ux implementation-phase notes + 0 residual qa concerns after editorial fixes) are appropriate for pre-implementation tracking, not for spec re-revision.

System transitions from "In Review (v1.0 NEEDS REVISION)" to **"Designed (APPROVED)"** — consistent with Grid Battle #1 and Scenario Progression #6 post-revision patterns. Ready for systems-index status update + commit.
