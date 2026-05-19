# 방통 (Pang Tong) — Portrait Asset Spec

> **Status**: B2.2-a — spec authored, pending external AI gen (B2.2-b)
> **Hero ID**: `shu_007_pang_tong` · **Portrait ID**: `portrait_shu_pang_tong`
> **Cascade join**: ch15 낙봉파 hidden destiny (`WIN_luofeng_pang_tong_lives`) — UI 카드 표기는 "ch16 낙봉파" (signature_archive_popup)
> **Sources**: `art-bible-v1-distilled.md` §1 palette + §2 line + §4 방통 anatomy seed; `heroes.json` `shu_007_pang_tong`; B2.1 위연 pipeline 검증 (commit `3d60a46`)
> **Date**: 2026-05-19

---

## Canonical anchors (from `heroes.json`)

| Field | Value | Visual implication |
|---|---|---|
| name_ko / name_zh / 자 | 방통 / 庞统 / 士元 (Shiyuan) | 자 "士元" — 학사 archetype, 평범한 외관 안에 천재 |
| Faction | Shu (0) | Liu Bei 가 직접 영입한 canonical 책사 — 위연과 달리 ambivalence 없음. Shu 정체성 명확히 드러내야 함 |
| Class | default_class=3 (STRATEGIST) | 책사 (謀士) — 무복 아님, 학자 로브 + 부채 |
| Stat profile | Might 45 · Intellect 95 · Command 80 · Agility 55 | 지력 95 최고치 — 무력 45 는 비전투원. **NO 무복 / NO 검 / NO 갑옷** |
| Innate skills | `skill_blunt_strategy` + `skill_phoenix_chick` | 봉추 (Phoenix Chick) — 부채가 봉의 깃털을 상징 |
| Join condition | `story_ch15_pang_tong_joins` (hidden destiny only) | Luofengpo 화살 dodge — survived-against-canon character |
| Bond | `bond_phoenix_chick_loyalty` (LIEGE Liu Bei) + `bond_wolong_fengchu_paired_strategy` (RIVAL_STRATEGIST 제갈량, 대칭) | 와룡-봉추 paired strategy — Zhuge Liang 과 시각적으로 구분되어야 함 (NOT same archetype) |

---

## Portrait brief (per distilled §4 + production interpretation)

Centered vertical calm posture, **standing front-facing slightly 3/4**, wide-sleeve robes spreading **triangular silhouette** (책사 archetype 의 정적 read), 부채 (paper-white folding fan) 가 유일한 asymmetric prop — right hand 에 펴서 들거나 닫아서 든 채. **NO weapon, NO armour, NO ceremonial decoration beyond 학자 robe trim.** Ink-heavy 묵 robe with 황토 trim at cuff + collar. 부채 는 paper-white `#F2E8D4` (지백) — palette §1 정확 매칭.

얼굴: **deliberately unglamorous — round-ish jaw, NOT handsome, NOT young, NOT idealized** (Zhuge Liang 의 graceful 학자 외관과 의도적 대비). 평범한 외관 안에 천재의 calm. 시선: **centred forward, slight downward** — "가장 조용한 사람이 방을 통제한다" 의 자세. 어깨에 미세한 긴장 (낙봉파 화살을 비껴 간 character — survived-against-canon 기억).

머리: 책사 학자 spirit — bound topknot 또는 short bound hair, 잉크-black, plain. NO 화려한 학자 관모, NO 머리장식.

**Why these anchors**: 방통은 와룡 (제갈량) 의 paired counterpart — 둘은 함께 거론되지만 외관이 정반대여야 둘의 strategy duality 가 시각적으로 작동. 제갈량 = 키 크고 우아한 graceful 학자; 방통 = 짧고 둥근 unglamorous 학자. 同類 archetype 안의 contrast 가 이 portrait 의 본질. 또한 위연 (이전 portrait) 의 동적 asymmetric mercenary 와 대비되는 정적 centered 책사 — 두 portrait 가 같이 놓였을 때 5-hero cascade 의 시각 다양성이 시작됨.

---

## Midjourney prompt — copy-paste ready

```
Three Kingdoms strategist Pang Tong, centered vertical calm standing pose front-facing slightly 3/4, wide-sleeve scholar robes spreading triangular silhouette, holding a paper-white folding fan in right hand as sole asymmetric prop, NO weapon NO armor NO ceremonial decoration, deliberately plain unglamorous face with round-ish jaw mature scholarly thoughtful expression, NOT handsome NOT young NOT idealized face, subtle shoulder tension reading as "survived an ambush", calm centered forward gaze with slight downward angle, bound topknot or short bound jet-black hair plain no ornament, ink-heavy black scholar robes with ochre-earth trim at cuff and collar, paper-white folding fan as visual focal accent, sumi-e ink wash painting illustration, Romance of Three Kingdoms historical style, variable-weight ink outlines thicker at silhouette edge, ink bleeds at outline edges, late-Ming woodblock print linework, Yokoyama Mitsuteru historical manga influence, monochrome wash underpainting limited muted colour palette, ink-black #1C1A17 dominant with ochre earth #C8874A trim and paper-white #F2E8D4 fan on paper-white ground, amber dusk warm Phase-C Sichuan mountain shadow atmosphere, generous negative space around figure centered composition, 8-heads-tall proportion, historical Three Kingdoms costume accuracy --ar 1:1 --style raw --s 200 --v 6 --no anime, photoreal, cel shading, gradient glow, bright saturation, dynasty warriors muscle armor, gold filigree, vermillion red accents, modern western fantasy, glowing weapon trail, handsome idealized scholar face, graceful Zhuge Liang silhouette, dynamic action pose
```

**MJ 튜닝 메모** (1차 batch 가 어긋난 방향별):
- 너무 우아 / 잘생긴 학자 (Zhuge Liang 처럼) → `plain unglamorous round face, NOT handsome` 강화 + `deliberately ordinary appearance` 추가
- 부채가 안 보임 / 잘못된 prop → `holding paper-white folding fan visible in right hand` 강화
- 자세가 너무 동적 / 액션 포즈 → `static contemplative pose, NOT moving, hands and body still` 추가
- 너무 밝음 / 색이 많음 → `dominantly monochrome ink, ochre trim is the only colour warmth` 추가
- 머리장식이 화려 → `plain bound hair, NO scholar's hat, NO ornament` 추가
- 너무 어림 → `mature middle-aged scholar face, weathered eyes, NOT young` 추가

---

## Gemini prompt — copy-paste ready

> Gemini Image (Imagen 4 계열) 은 자연어 prompt + 자연어 exclusion 으로 동작. AI Studio / Gemini 앱에서 사용 시 aspect ratio 는 드롭다운 OR 본문에 "1:1 square format" 명시.

```
A portrait illustration of Pang Tong (庞统, 士元), a Three Kingdoms-era Chinese strategist known as "Phoenix Chick" (鳳雛), painted in traditional sumi-e ink wash style.

He stands in a centered, vertical, calm pose, facing slightly three-quarter toward the viewer. His wide-sleeve scholar robes spread outward to form a triangular silhouette — the classic 모사 (strategist) shape. In his right hand, he holds a folded paper-white fan as his sole asymmetric prop. He carries no weapon, no armor, and no ceremonial decoration beyond simple scholar's trim.

His face is deliberately plain and unglamorous — a round-ish jaw with mature, weathered, scholarly features. He is NOT handsome, NOT young, NOT idealized. The point of this character is that his ordinary appearance conceals brilliant intellect. There is a subtle tension in his shoulders, as though he is remembering surviving an ambush. His gaze is calm, directed centered-forward with a slight downward angle — the quietest person in the room, who controls it.

His hair is bound in a simple topknot or short bound style, jet-black, with no scholar's hat and no ornament. He wears ink-heavy black scholar robes with ochre-earth (#C8874A) trim at the cuffs and collar.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. The outlines are variable-weight ink — thicker at the silhouette edge, thinner for interior detail, with visible ink bleeds at the outline edges. The underpainting is monochrome wash with very limited color: ink-black (#1C1A17) dominates for the robes, ochre earth (#C8874A) appears only as trim at cuff and collar, and the paper-white folding fan (#F2E8D4) is the visual focal accent. The ground is paper-white with visible paper grain.

The lighting is amber dusk warmth with deep Sichuan mountain shadow — evoking the moment after surviving Luofengpo. There is generous negative space behind the figure. The composition is centered, with the figure rendered at 8-heads-tall proportion. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects, bright saturated colors, or modern Western fantasy elements. Do not use Dynasty Warriors video-game aesthetics. Do not include red or gold accent colors. Do not depict him in a dynamic action pose or carrying a weapon. Do not give him a handsome, youthful, or idealized face — he is plain on purpose. Do not draw him in the graceful tall silhouette of Zhuge Liang — Pang Tong is shorter and rounder than his strategic counterpart, and the silhouette must reflect that contrast.
```

**Gemini 튜닝 메모**:
- 잘생긴 학자 / Zhuge Liang 풍 → exclusion 강화: `The face must be deliberately ordinary, unglamorous, with no traditional beauty markers. This character's brilliance is hidden behind plain features — this is essential to who he is.`
- 부채 없음 / 잘못된 prop → `The folding fan held in his right hand is essential — it is paper-white, visible, and reads as the asymmetric focal accent of the entire silhouette.`
- 자세가 동적 → `He is completely still — feet planted, body weight centered, no implied motion. The stillness IS the strategic presence.`
- 색 너무 다양 → `The image must read as primarily ink-black with restrained ochre trim accents. The paper-white fan provides the only color contrast. No other colors should appear.`
- 너무 어림 / 화려한 학자 → `He is a mature middle-aged scholar with weathered eyes and lined features. There are no ornate hat, no jewelry, no decorative robe patterns.`

---

## Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/portraits/portrait_shu_pang_tong.png` |
| Dimensions | 1024×1024 |
| Format | PNG (no transparency — paper-white `#F2E8D4` ground is design intent) |
| Variants in this spec | 1 (canonical baseline) — Luofengpo / death variants are future |
| Convention | `assets/art/portraits/{portrait_id}.png` — established by B2.1 위연, followed here |

---

## Integration plan (B2.2-c — same session as B2.2-b drop-in)

pipeline 은 B2.1 에서 검증 완료 — 자산 drop-in 만으로 자동 통합:

1. `assets/art/portraits/portrait_shu_pang_tong.png` 배치
2. `godot --headless --import --path .` (이미지 import)
3. 헤드리스 부팅 + 풀 테스트 (baseline 유지 확인)
4. windowed 검증: 메인메뉴 → 시그니처 아카이브 → **방통 카드** portrait 표시 (위연 카드와 동일 HBox 레이아웃, signature 미달성 시 alpha 0.45 dim)

**코드 변경 0** — `signature_archive_popup.gd` 의 SIGNATURE_CATALOG 가 이미 hero_id `&"shu_007_pang_tong"` 를 포함 (B2.1 commit `3d60a46`), `HeroDatabase.get_portrait_texture()` 가 파일 존재만 감지하면 자동으로 표시. 이게 portrait pipeline 의 본질적 가치 — 첫 영웅 (위연) 의 코드 비용을 이후 4 영웅이 공유.

---

## Acceptance for AI generation (B2.2-b — user side)

Ship-able output must satisfy (single AND gate):
- ✅ 부채 visible in right hand (folding fan, paper-white)
- ✅ Centered vertical calm pose, NOT dynamic / NOT action
- ✅ Plain unglamorous mature face, NOT handsome / NOT young / NOT idealized
- ✅ Ink-black 묵 robes dominant, ochre trim only, NO Shu blue / NO red / NO gold / NO bright saturation
- ✅ Sumi-e 잉크-워시 visual language (NOT anime cel-shading, NOT photoreal, NOT gradient-glow)
- ✅ Triangular wide-sleeve silhouette (책사 archetype shape), NOT Zhuge Liang's tall graceful silhouette
- ✅ Negative space around figure

If any miss → regen with tuning notes above. No manual touch-up (per AI-output-direct policy).

---

## Cross-reference: 5-hero cascade visual differentiation

| Hero | Phase | Posture | Prop | Palette warmth | Face |
|---|---|---|---|---|---|
| **위연** (B2.1 ✅) | B (blue-grey cold) | Asymmetric mercenary | Sword hilt | Iron-grey + ochre | Weathered sharp narrow |
| **방통** (B2.2 — this) | C (amber dusk) | Centered triangular static | Paper-white fan | Ink-black + ochre trim | Plain round mature |
| 관우 (B2.3) | D? (sunset orange) | Massive immovable | 청룡언월도 (Green Dragon Crescent Blade) | Deep green robe | TBD |
| 장비 (B2.4) | D? | Wedge-shaped wild | 사모 (serpent spear) | High contrast darkest | Leopard-ring eyes |
| 유비 (B2.5) | E (cold blue→gold) | Balanced open-arm rally | 双股劍 (paired swords) | Ink + ochre | Prominent ears, full-trim beard |

5장이 같이 놓였을 때 phase / posture / prop / palette / face 5개 축에서 모두 차이가 나도록 — 이게 cascade 의 시각 정체성.
