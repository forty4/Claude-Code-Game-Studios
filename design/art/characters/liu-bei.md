# Character Visual Profile: 유비 (Liu Bei) — Stub

> **Status**: Stub (sprint-11 S11-09 — descoped from 3 stubs to 1 per S10-07 carryover absorption decision; closes AD-C5 ADVISORY to "first-stub-shipped" partial state)
> **Hero ID**: `shu_001_liu_bei` (per `assets/data/heroes/heroes.json`)
> **Tier**: Sections 1-3 minimum (silhouette + costume + role-anchor); Sections 4-N deferred to character-art production sprint
> **Author**: claude (sprint-11 S11-09; art-director consulted via `design/art/art-bible.md` §3-2 hero-silhouette philosophy)
> **Last Updated**: 2026-05-08
> **Cross-refs**: `design/gdd/hero-database.md` §COMMANDER role + record `shu_001_liu_bei`; `design/art/art-bible.md` §1 Visual Identity + §3-2 Hero Silhouette + §3 reserved-color discipline; `assets/data/heroes/heroes.json` `shu_001_liu_bei` stat block

---

## Canonical Anchors (from hero-database.md + heroes.json)

| Field | Value | Visual implication |
|---|---|---|
| Korean name | 유비 (Liu Bei) | Three-Kingdoms 蜀 (Shu) founder — primary virtue archetype |
| Chinese name | 劉備 | — |
| Courtesy name (字) | 玄德 (Xuande) — "profound virtue" | Visual must read as virtuous leader, not warrior |
| Faction | Shu (faction 0) | Shu palette anchor: 황토 (ochre) dominant in armor accents — earth-virtue association |
| Class | COMMANDER (default_class=4 → 지휘관 per `hero-database.md` §COMMANDER row) | Silhouette anchored on leadership posture, not strike pose |
| Stat profile | Might 70 / Intellect 75 / **Command 90** / Agility 65 | Command is the dominant stat — silhouette + props must read as commander first, fighter second |
| Innate skills | `skill_inspire` (rally buff) + `skill_benevolence` (defensive/team-support) | Visual signals must support both rally + benevolence — open posture, raised hand or sword-pointed-skyward, NOT lowered-blade strike pose |
| Sworn-brother bond | Guan Yu + Zhang Fei (Peach Garden Oath; `bond_oath_peach_garden` symmetric) | Silhouette must hold its own at the **center** of the 3-brother triangle composition; supports the canonical Peach Garden tableau |
| Join chapter | 1 (`join_chapter=1` + `story_ch1_intro` tag) | First-impression role — silhouette sets the project's overall hero-silhouette legibility benchmark |

---

## Section 1 — Silhouette

**Anchor pose**: open commander stance — feet shoulder-width, weight balanced, **right arm extended forward or upward** (rallying gesture; reads as inspire / call-to-arms even in static frame). Left arm relaxed at side OR resting on sword pommel (NOT mid-strike). Head slightly raised — looks **at** rather than **down**, conveys leader-among-equals (not commander-from-above).

**Head shape**: rounded crown with **prominent ears** (Three-Kingdoms canonical visual marker — 大耳 / "big ears" associated with nobility in Chinese folklore; also serves as a silhouette-distinguishing trait at small zoom levels). Beard: full but trim, NOT bushy (distinguish from Zhang Fei's wild beard); reads as scholar-tempered virtue, not warrior wildness.

**Body proportions** (per art-bible §3-2 영웅 vs. 일반 병사):
- Hero scale = 1.25× same-class soldier per art-bible §3-2 line 158
- Outline irregularity: brush-stroke variability on the silhouette edge (per art-bible §3-2 line 159) — concentrated on robe hem + cloak edge to read as wind-caught fabric, NOT armor edges (those stay clean to read as disciplined commander)

**Equipment protrusions** (per art-bible §3-2 line 160 — heroes get asymmetric protrusions for silhouette individuation):
- **Right side**: paired swords (双股劍 / 자웅쌍고검) at hip — TWO scabbards, NOT one. The double-scabbard is Liu Bei's canonical Three-Kingdoms attribute and provides the asymmetric silhouette protrusion against the otherwise-symmetric COMMANDER class shape. At reading distance, the silhouette reads as "commander with twin blades" — distinguishes immediately from Cao Cao (typically single sword) and Sun Quan (no visible weapon).
- **Left side**: NO ceremonial fan, NO scroll, NO mace. The void on the left is intentional — frames the rally gesture when the right arm is raised.
- **Cloak**: long cloak trailing behind, brush-stroke outline. The cloak's asymmetric drift (catching wind from behind-right) reinforces the forward-leaning rally posture without shifting the figure's center of gravity.

**Silhouette read at three zoom levels** (per art-bible §3-2 실루엣 읽힘 층위 lines 138-145):
- Battlefield zoom (small): "human silhouette with raised arm + paired-blade hip protrusion" — distinct from common COMMANDER silhouettes (e.g., Cao Cao single-blade, Sun Quan no-blade)
- Mid zoom (forecast / unit-info panel): "rounded-head + full-beard + double-scabbard" — confirms identity
- Portrait zoom: full canonical Liu Bei face per portrait spec (deferred to portrait sprint; this stub does NOT specify face details beyond "prominent ears + full-trim beard + virtuous expression")

---

## Section 2 — Costume

**Palette restraint** (per art-bible §1 + §3 reserved-color discipline):

| Layer | Color (project token) | Justification |
|---|---|---|
| Base robe | 묵 (ink, deep indigo-black) | Pillar 4 ink-wash anchor; Liu Bei's robe is the canonical ink-tone silhouette base |
| Robe trim + cuff | 황토 (ochre) | Shu faction visual signature; subtle gold-adjacent without crossing into reserved 금색 |
| Sash / belt | 청회 (blue-grey) | Tertiary palette tone; provides waist-level horizontal break for silhouette legibility |
| Sword scabbards | 묵 lacquered black + 황토 ochre fittings | Reads as understated, virtue-anchored — NOT ostentatious like a tyrant's weapon |
| **Cloak (outer layer)** | 황토 with deep 묵 lining | Visible only when wind-caught; the ochre-on-ink interior reveal is Liu Bei's canonical color signature without invoking reserved colors |

**Reserved-color discipline** (per art-bible §1 + accessibility-requirements.md R-1):
- 주홍 (vermillion) — **NOT used** on Liu Bei in any baseline frame. Vermillion is reserved for 운명 분기 (destiny branch) tragedy beats only.
- 금색 (gold) — **NOT used** on Liu Bei in any baseline frame. Gold is reserved for triumph/accession 운명 분기 beats only. Even the Han-imperial accession (proclamation as emperor of Shu Han) does NOT introduce gold to Liu Bei's costume — that moment uses 금색 in the *environmental treatment* (banner, light, throne), not on the character.
- Implication: Liu Bei's baseline costume must be readable as **virtuous-but-not-yet-emperor**. The ascension to emperor-status is a narrative beat handled by environment + lighting, not character costume.

**Era markers**:
- **Pre-CH-1 narrative state** (chapter 1 introduction): commoner-rank robe + travel cloak. Sash reads as practical, not ceremonial. Visual reads "wandering virtuous leader" not "established sovereign."
- **Post-Peach-Garden / Late-game progression** (deferred to character-art production sprint; this stub specifies pre-ch-1 only): scholarly-imperial robe variants are **future-stub work**. Note for the future spec: never add gold (reserved) to costume; instead, robe pattern complexity increases (more layered trim, longer cloak, ceremonial collar) while staying within the 묵 + 황토 + 청회 palette.

**Anti-pattern checklist** (what Liu Bei's costume must NOT do):
- ❌ Heavy plate armor — Liu Bei is COMMANDER class (command 90 > might 70), not WARRIOR class. Plate armor would mislead the silhouette read toward warrior identity.
- ❌ Gold/vermillion accents — violates reserved-color discipline.
- ❌ Bare-armed / battle-stripped — Liu Bei is a virtue-ruler archetype; bare-armed would mislead toward warrior/peasant reading. Even in defeat scenes, the cloak stays.
- ❌ Single sword — collapses silhouette distinguishability against single-sword COMMANDER profiles. Paired swords are non-negotiable.
- ❌ Horse-mounted baseline — battle-sprite is foot-soldier scale per `battle_sprite_id: sprite_shu_liu_bei`; mounted variants are deferred to event-art sprint (Peach Garden Oath, Imperial Procession).

---

## Section 3 — Role-Anchor

**Class identity reinforcement** (COMMANDER per `hero-database.md` §COMMANDER):
- Silhouette pose + raised-arm rally gesture + open stance reinforces command/leadership. Foreign players unfamiliar with Three Kingdoms canon should still read "leader" at first sight without needing to know the source material. Pillar 3 (모든 무장에게 자리가 있다 / Every Hero Has a Role) is satisfied at the silhouette layer.
- Paired-swords protrusion provides individual identification without pose-swapping; Liu Bei is recognizable in any frame regardless of animation state.

**Pillar 4 anchoring** (삼국지의 숨결 / Spirit of Three Kingdoms):
- Prominent-ears + full-trim-beard + paired-swords is the **minimum canonical Liu Bei recognition triplet**. Three Kingdoms-literate players should immediately recognize "Liu Bei" at portrait zoom; non-literate players see a clear COMMANDER identity. Both audiences are served.
- The Peach Garden Oath bond (`bond_oath_peach_garden` with Guan Yu + Zhang Fei) **shapes the Liu Bei-Guan Yu-Zhang Fei triangle composition** when those three are co-deployed:
  - Liu Bei occupies the **center** position; his open-arm rally posture frames the trio.
  - Guan Yu (right-side, when present in same frame) carries his green dragon crescent blade — the silhouette's vertical rise to the right of Liu Bei.
  - Zhang Fei (left-side, when present in same frame) carries his serpent spear (蛇矛) — the silhouette's vertical rise to the left of Liu Bei.
  - Together: Liu Bei's open arms span between the two upright weapons of his sworn brothers. The triangle composition is **the** canonical Three Kingdoms tableau.

**Pillar 2 narrative-pillar interaction** (운명은 바꿀 수 있다 / Destiny Can Be Rewritten):
- Liu Bei is a **canonical-history-defying** archetype within Pillar 2 framing. Visual cues at neutral state must NOT pre-spoil future destiny-branch outcomes. The baseline costume is era-1 (pre-Peach-Garden); destiny-branch divergences (e.g., a "Liu Bei dies young" branch) get **separate sprite variants**, not baseline costume changes.
- Reserved-color discipline (no 주홍/금색 on baseline costume) is what allows destiny-branch moments to land — when Liu Bei's death-treatment frame uses vermillion outline or his accession-frame uses gold environmental light, the player reads it as destiny-rewrite signal because the baseline is restraint.

**Pillar 3 cross-class boundary**: Liu Bei MUST NOT be confused for any other COMMANDER hero on the roster. Comparison:

| Hero | Class | Distinguishing silhouette features |
|---|---|---|
| 유비 (Liu Bei) | COMMANDER | Paired swords (right hip); rounded crown + prominent ears; rally posture |
| 조조 (Cao Cao) | COMMANDER (per hero-database row 165) | TBD in future stub — must NOT use paired swords; must NOT use rally posture (defer to Cao Cao spec; presumed: single tactical sword + scroll, calculating posture) |
| 손권 (Sun Quan) | TBD | TBD — must NOT collide with Liu Bei silhouette |

The "paired swords + rounded-crown + rally-posture" triplet is reserved for Liu Bei within the COMMANDER class. Future COMMANDER hero stubs must avoid collision.

---

## Sections 4-N — DEFERRED

The following sections are **NOT** authored in this stub; they belong to the character-art production sprint (post-character-art prerequisites met):

- Section 4 — Animation key poses (idle / walk / attack / cast / hit / death cycles)
- Section 5 — Portrait spec (face details, eye treatment, expression sheet)
- Section 6 — Variant sprites (chapter-specific costume changes; destiny-branch outcome variants)
- Section 7 — VFX integration (rally aura, benevolence buff visualization)
- Section 8 — Audio cue alignment (voice-over direction, foley pairing)
- Section 9 — Localization considerations (Korean / Chinese / English nameplate font sizing)
- Section 10 — Cross-promo art (key art appearances, Peach Garden Oath set piece, Han accession set piece)

Each deferred section requires inputs that are **not yet decided** (animation system commitments, portrait pipeline, VFX system, localization scope). Authoring them now would require speculative decisions that risk mid-sprint churn.

---

## Acceptance Criteria (this stub)

| ID | Criterion | Verification |
|---|---|---|
| AC-LB-01 | Hero ID + Korean name + Chinese name + courtesy name match `assets/data/heroes/heroes.json` `shu_001_liu_bei` exactly | grep cross-check |
| AC-LB-02 | Class identity (COMMANDER) matches `hero-database.md` §COMMANDER row + `default_class=4` mapping | doc cross-check |
| AC-LB-03 | All palette references use only `묵 / 황토 / 청회` baseline tokens; reserved 주홍 / 금색 are explicitly excluded from baseline | doc grep `주홍\|금색`; expect occurrences only in §2 anti-pattern + §3 Pillar 2 explanatory text |
| AC-LB-04 | Paired-swords (双股劍) silhouette protrusion is non-negotiable (named in §1 + reinforced in §3 Pillar 3 cross-class boundary) | doc cross-check |
| AC-LB-05 | Pillar 4 minimum recognition triplet (prominent-ears + full-trim-beard + paired-swords) is named explicitly in §3 | doc cross-check |
| AC-LB-06 | Peach Garden Oath triangle composition (Liu Bei center, Guan Yu right, Zhang Fei left) is documented as the canonical tableau | doc cross-check |
| AC-LB-07 | Sections 4-N are explicitly deferred (not silently omitted) so future authors know the stub boundary | §Sections 4-N — DEFERRED block present |
| AC-LB-08 | Stub closes AD-C5 to "first-stub-shipped" partial state — verified at next gate-check pass | gate-check rerating from "AD-C5 ADVISORY: 0 stubs shipped" → "AD-C5: 1 of 3 originally-planned stubs shipped (first-stub partial state)" |

---

## Open Questions

| ID | Question | Owner | When to resolve |
|---|---|---|---|
| OQ-LB-01 | Is the paired-swords Three-Kingdoms canon visual translation acceptable per current Korean translation/localization style guide? | localization-lead + art-director | First localization pass |
| OQ-LB-02 | Cao Cao + Sun Quan + remaining COMMANDER stubs need silhouette-collision verification against this Liu Bei stub before authoring | art-director | At each future COMMANDER hero stub authoring time |
| OQ-LB-03 | Should the "rally posture" be a one-frame static pose for portrait/forecast contexts, OR is it the idle-loop's rest-frame? | animation-lead (TBD) | Animation pipeline kickoff |
| OQ-LB-04 | Late-game robe progression (post-accession imperial variant) — should this stub reserve a §6 "Variant sprites" hook now to prevent late-game variant scope-creep into baseline? | art-director + narrative-director | Character-art production sprint planning |
| OQ-LB-05 | Battle sprite scale (1.25× per art-bible §3-2) and viewport pixel target — confirm before pixel-art commission | art-director | Before any pixel-art production starts |

---

## Cross-references

- Hero data: `assets/data/heroes/heroes.json` `shu_001_liu_bei` (canonical stat + relationship + skill data)
- Hero database GDD: `design/gdd/hero-database.md` §COMMANDER row + record schema
- Art bible: `design/art/art-bible.md` §1 Visual Identity, §3-2 hero silhouette philosophy (line 156-160 hero proportion + protrusion rules), §3 reserved-color discipline
- Game concept Pillars: `design/gdd/game-concept.md` §Pillar 2 + §Pillar 3 + §Pillar 4
- Accessibility binding: `design/ux/accessibility-requirements.md` §4 R-1 reserved-color alternate encoding (this stub satisfies by NOT using reserved colors at baseline)
- Sprint task: sprint-11 S11-09 (this stub creation; descoped from 3 stubs to 1 per S10-07 carryover absorption)
- AD-C5 source: `production/gate-checks/pre-prod-to-prod-2026-05-05.md` (ADVISORY: character visual profile stubs — author for first 2-3 characters before sprint-8 art tasks)
- Carryover chain: sprint-7 (AD-C5 first surfaced) → sprint-8 (deferred) → sprint-9 (deferred) → sprint-10 S10-07 (3-stub original) → sprint-11 S11-09 (descoped to 1 stub; first-stub-shipped partial-state closure)

---

## Status & Next Step

**Stub-level visual profile.** Sections 1-3 (silhouette + costume + role-anchor) are committed at the structural level only; full visual design + animation + portrait + variant work falls to the character-art production sprint (currently unscheduled; gated by character-art pipeline prerequisites which include localization style guide + animation system commitments).

Next checkpoint: at the next `/gate-check` pass, AD-C5 should re-rate from "ADVISORY: 0 of planned 3 stubs shipped" to "ADVISORY: 1 of originally-planned 3 stubs shipped (first-stub partial-state per sprint-10 retro AI #5 descoping decision)." 관우 (Guan Yu) + 장비 (Zhang Fei) stubs remain DESCOPED — they are explicitly carried as future Polish-tier candidates and do NOT appear in any sprint-11 backlog row.
