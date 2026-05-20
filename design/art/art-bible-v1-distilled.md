# Art Bible v1 — Distilled
## 천명역전 / Defying Destiny

*Distilled from `design/art/art-bible.md` (70KB, 2026-05-04) against game-as-built (S66, 25 chapters, 5-hero cascade, 4-tier ending, ProgressArchive). For Godot Theme authoring and AI image-generation prompts. Do NOT modify the source bible — this is a working extract.*

---

## §1 Palette

Six named tones. Everything in the game derives from these.

| Token | Hex | Role |
|---|---|---|
| **묵** (Ink) | `#1C1A17` | Outlines, history's weight, defeat. Never use as sole background fill. |
| **지백** (Paper White) | `#F2E8D4` | Negative space, undecided fate. Never use for warnings. |
| **황토** (Ochre Earth) | `#C8874A` | The land of the Central Plains. Backgrounds, UI panels, Shu faction accents. |
| **청회** (Blue-Grey) | `#5C7A8A` | Cold armour, tactical UI, player control. Never use for destiny-branch moments. |
| **주홍** (Vermillion) | `#C0392B` | **Destiny-branch ONLY.** The colour of irreversible choice. Appears nowhere else. |
| **금색** (Gold) | `#D4A017` | **Legendary / destiny-reversed ONLY.** Five-star cascade dawn. The legendary SFX and gold ColorRect tween are this colour's only current in-engine expressions. |

Faction reads: Shu = `#2E5F7A` (deep blue, justice); Wei = `#4A4A4A` (iron grey, dominance); Wu = `#2D6B4A` (deep green, adaptive). Faction colours are identity markers — never substitute for 주홍 or 금색.

---

## §2 Line & Rendering

Target style in one phrase: **ink-wash painterly, silhouette-first, late-Ming woodblock / Yokoyama Mitsuteru linework tradition — NOT anime, NOT photoreal, NOT Western fantasy.**

Specific properties for AI prompts: variable-weight ink outlines (thicker at silhouette edge, thinner for interior detail), monochrome wash underpainting before limited flat colour, deliberate brush-drag irregularity on hero outlines only (common soldiers have uniform line weight), generous negative space, paper-texture ground.

Brush feel keyword cluster: `sumi-e ink wash`, `Chinese ink painting`, `woodblock print linework`, `Romance of Three Kingdoms historical illustration`, `muted limited palette`, `ink silhouette first`, `no cell shading`, `no gradient glow`.

---

## §3 Lighting & Atmosphere — 5-Phase Map

The bible's 7-state emotional map collapses to the game's actual chapter structure:

| Phase | Chapters | Setting | Lighting | Dominant feel |
|---|---|---|---|---|
| **A — 서주/형주 진입** | ch01–ch05 | Jizhou plains, early Shu | Neutral daylight, ochre-warm | Wandering virtue — history not yet written |
| **B — 형주** | ch06–ch13 | Jing Province (Fancheng / Changsha / Chibi zone) | Blue-grey cold daylight, fog over water | Strategic tension — factions converging |
| **C — 익주** | ch14–ch17 | Sichuan mountains (inc. Luofengpo ch16) | Dusk amber → deep shadow | Danger and sacrifice — the price of the west |
| **D — 한중·이릉** | ch18–ch22 | Han River highlands, Yiling fire | Sunset red-orange haze (non-reserved: use `#E07020` orange, NOT 주홍) | Grief and near-loss — history pushing back |
| **E — 남만·오장원·영걸전 finale** | ch23–ch25 | Southern wilderness → Wuzhang Plain | New dawn, blue-grey lifting into gold on legendary trigger | Transcendence — destiny rewritten or destiny sealed |

**Cross-phase rule:** 주홍 (`#C0392B`) only enters the screen during destiny-branch judgment moments (the `reserved_color_treatment` vignette). 금색 (`#D4A017`) only enters on the legendary cascade ending. These two colours are the game's emotional punctuation — their absence in Phases A–D is what makes Phase E land.

---

## §4 Character Anatomy — Cascade Hero Archetypes

Five heroes, five silhouette reads. Each line is the minimum prompt seed; expand with §2 line style and §1 palette.

**위연 — Opportunist Strategist (ch14 cascade join):** Asymmetric mercenary posture, hand resting on hilt rather than raised, calculating downward gaze. Armour practical not ceremonial. Silhouette reads "blade waiting for the right moment" not "loyal soldier." Ochre-earth palette base with iron-grey accents. He entered last among the generals — his look holds that ambivalence.

**방통 — Hidden Phoenix (ch17 cascade join):** Strategist archetype (謀士): wide-sleeve triangular silhouette, fan as sole asymmetric prop. Shorter and rounder than Zhuge Liang — the unglamorous genius. Ink-heavy robes, paper-white fan. Posture: centred vertical calm that reads as "the quietest person in the room controls it." The Luofengpo arrow he dodged is what makes him stand differently from Zhuge Liang — a subtle tension in the shoulders.

**관우 — Pillar of Loyalty (ch21 cascade join):** Heavy cavalry archetype (猛將): Green battle robe (historical exception — deeper than Shu blue, near `#2D6B4A`), Green Dragon Crescent Blade (青龍偃月刀) as upper-right silhouette protrusion, long beard forming chest asymmetry. Scale: largest of the five. He came back from Fancheng alive — his stance should read "immovable."

**장비 — Raw Force (ch22 cascade join):** Assault cavalry archetype: wedge-shaped silhouette, serpent spear (丈八蛇矛) vertical protrusion above the helmet, wild curled beard spilling past armour edges, leopard-ring eyes. High contrast — darkest character on the screen. He put down the cup that would have gotten him killed — the discipline is in the eyes, but barely.

**유비 — Virtue-King (ch23 cascade join, ch25 legendary centre):** Commander archetype: balanced open-arm rally posture, paired twin swords (双股劍) at right hip as silhouette protrusion, prominent ears, full-trim beard (NOT bushy — distinguish from Zhang Fei). Ink-base robe with ochre trim. He is the only hero who looks *at* rather than *down or away*. In the legendary finale, he stands at the gate — his silhouette is the one the other four frame.

---

## §5 Anti-Reference

This game is **not**:

1. **NOT Dynasty Warriors / 무쌍 genre** — no muscle-bound baroque armour, no glowing weapon trails, no power-fantasy scale. Restraint is the entire aesthetic.
2. **NOT modern anime SRPG** (no Fire Emblem Engage visual language) — no gradient hair highlights, no cel-shaded clean fills, no hypersaturated palette.
3. **NOT JRPG fantasy** (no Final Fantasy illustration vocabulary) — no fantasy creatures, no magitech, no Western armour silhouettes.
4. **NOT photoreal historical drama** (no Red Cliff film aesthetic) — we are in illustrated history, not cinematographic realism. Ink line always reads over photographic texture.
5. **NOT decorative chinoiserie** (no pattern-heavy, ornate surface design as aesthetic goal) — the visual restraint comes from the ink-wash tradition, not from Orientalist decoration.

---

## §6 Grid Character Sprite Style (개정 2026-05-20)

art-bible.md §5.7 의 압축판. **sumi-e + chibi 융합** — LOD 1 (grid, 32-63px) 에서 character 표현 허용 (LOD 0 portrait 은 formal sumi-e 그대로).

- **비례**: 3-head chibi (머리:몸:다리 = 1:1:1)
- **해상도**: native 128×128, 표시 64×64 (2× supersample)
- **외곽선**: sumi-e variable-weight brush (head 1.5-2x 두께)
- **얼굴**: chibi 표정 (눈 = 검은 점 2, 입 = 1 line). 코/귀 생략 (단 유비의 큰 귀는 silhouette 특징)
- **색**: art-bible §4 7 팔레트 + 세력 색 우선. 주홍/금색 sprite 금지 (LOD 0 + VFX 한정)
- **도상 통합** (§5.6): 청룡언월도/장팔사모/부채/큰 귀 = chibi 옆 비례 보정 무기 OR silhouette 돌출
- **금지**: 거대 눈동자, 광택, cell-shading gradient, Dynasty Warriors 비례

**Animation phased**: P1 idle 1f → P2 idle breath 2f → P3 walk 4f → P4 attack 3f → P5 reaction (피격/사망/승리)

**Reference**: Triangle Strategy / Octopath Traveler 의 chibi-tactical 결 (모에 anti-ref 지속)

---

## AI Prompt Scaffold

Copy-paste foundation. Append per-asset specifics (character name, pose, phase lighting) after this block.

> `sumi-e ink wash illustration, Romance of Three Kingdoms historical style, variable-weight ink outlines, silhouette-first composition, monochrome wash underpainting with limited muted colour, ochre earth and blue-grey palette, paper texture ground, negative space as tactical information, late-Ming woodblock print linework tradition, Yokoyama Mitsuteru manga influence, NOT anime, NOT photoreal, NOT cel-shading, NOT Western fantasy, NOT Dynasty Warriors aesthetic, no gradient glow, no bright saturated fills, ink bleeds at hero outline edges, 8-heads-tall figure proportion, historical Three Kingdoms costume accuracy`

Phase lighting modifier (append for atmospheric accuracy):
- Phase A–B: `neutral daylight, ochre-warm`
- Phase C: `amber dusk, deep mountain shadow`
- Phase D: `sunset orange haze, grief-lit`
- Phase E (canonical): `cold blue-grey dawn`
- Phase E (legendary): `gold dawn wash, five stars still burning`

---

*Source: `design/art/art-bible.md` §1–§6 + `design/art/characters/liu-bei.md` + `assets/data/story/story_content.json` cascade prose + `production/session-state/active.md` S65–S66 milestone record. Godot theme hex values in §1 are implementation-ready — match exactly to `art-bible.md` §4.1.*
