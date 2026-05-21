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

## Gemini prompt — copy-paste ready (v2-strengthened, reframe 학습 적용)

> 위연 v3 와 동일 **Gemini reframe 원칙** 적용:
> - "absence 명시" ("NOT handsome, NOT idealized") → **type 명시 우선** ("round-ish jaw, soft contours, broad cheekbones, average forehead proportions")
> - exclusion list 에서 face 관련 부정 제거 (attractive prior 트리거 위험 차단)
> - **series anchor**: "matching the skin tone of the previous portrait" — 위연 v3 와 cascade 통일
> - Anti-comparison (Zhuge Liang) 은 character context 단락에 통합 (분리된 CRITICAL block 으로 weight 분산 방지)

```
A portrait illustration of a Three Kingdoms-era Chinese strategist, painted in traditional sumi-e ink wash style. This is part of a 5-portrait series — match the established visual style of the previous portrait (Wei Yan: a mid-40s hardened mercenary general with mature weathered sun-bronzed olive complexion).

CRITICAL CHARACTER FACE: The character's face shape is round and full — a round-ish jaw with soft contours, broad cheekbones, average forehead proportions. His features are deliberately unremarkable — symmetric but plain, the kind of face that does not stand out in a crowd. Light crow's feet at the eye corners and a slightly lined forehead show his middle age. His skin tone is naturalistic warm-olive, weathered from years of strategic life, matching the skin tone of the previous portrait in this series. This is a face shape that conceals brilliance behind plainness.

CHARACTER CONTEXT — Pang Tong (庞统, 士元), known as "Phoenix Chick" (鳳雛), the strategic counterpart to Zhuge Liang. The two strategists must be visually OPPOSITE in proportions: Zhuge Liang is tall and refined with sharp aristocratic features; Pang Tong is shorter, rounder, and ordinary-looking. Liu Bei initially dismissed Pang Tong because of his unimpressive appearance — that visible plainness IS the character.

He stands in a centered, vertical, completely static pose, facing slightly three-quarter toward the viewer. His build is shorter and rounder than the previous portrait in the series — a softer, slightly stout scholar's frame. Wide-sleeve scholar robes spread outward from his arms to form a triangular silhouette — the classic 모사 (strategist) shape.

In his right hand he holds a folded paper-white folding fan as his sole asymmetric prop. The fan is the visual focal accent — paper-white, clearly visible. He carries no weapon, no armor, no ceremonial decoration.

There is subtle tension in his shoulders, as though he is remembering surviving an ambush at Luofengpo. His gaze is calm, directed centered-forward with a slight downward angle.

Hair bound in a simple topknot, jet-black, no scholar's hat, no ornament. He wears ink-heavy black scholar robes (#1C1A17 dominant) with ochre-earth (#C8874A) trim at the cuffs and collar.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. Variable-weight ink outlines, thicker at the silhouette edge, with visible ink bleeds. Monochrome wash underpainting with very limited color: ink-black for the robes, ochre earth as trim only, the paper-white folding fan provides the only color contrast. Paper-white ground (#F2E8D4) with visible paper grain.

Lighting: warm amber dusk — Sichuan mountain shadow atmosphere. Generous negative space behind the figure. Composition centered, figure rendered at 8-heads-tall scholar-build proportion. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects or bright saturated colors. Do not include red or gold accent colors.
```

**Gemini 튜닝 메모** (v2 단계):
- 얼굴 conventional handsome → CRITICAL FACE block 의 부위별 type 묘사 우선 ("round-ish jaw, soft contours, broad cheekbones") + 부정 exclusion list 슬림
- Zhuge Liang anti-comparison: 분리된 CRITICAL block 으로 두면 weight 분산 위험 — character context 단락에 통합
- 시리즈 통일성: "matching skin tone of previous portrait" series anchor 도입 (위연 v3 와 cascade 화풍 통일)
- 얼굴 strong attractive prior 트리거 회피: "If your rendering looks attractive" 같은 명시적 negation 제거

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

---

## Grid sprite (chibi) — Q5 Phase 1 (신규 2026-05-20)

art-bible §5.7 정합. portrait (sumi-e formal) 과 별도 자산.

### Per-hero chibi 요소 (방통 한정)
- **정체성 유지**: 둥근 얼굴 + 평범한 인상 + 부채를 든 책사. chibi 단순화: 눈 = 점 2개, 입 = 1선, 둥근 윤곽 유지.
- **부채**: 손에 든 큰 부채가 chibi 비례에 맞게 (어깨 폭의 1.0x). 봉의 깃털 도상.
- **자세**: 중심 수직 calm. 어깨 약간 처짐 (subtle tension from Luofengpo arrow dodge).
- **머리**: 윤건(綸巾) + 학창의(鶴氅衣) silhouette — 사각 모자 + 넓은 sleeves 가 wide-sleeve triangular silhouette 형성.

### Gemini prompt — copy-paste ready

```
A chibi grid sprite of a Three Kingdoms-era Chinese strategist, painted in STRICTLY ink-wash sumi-e brush style applied to chibi proportions. For tactical RPG combat grid (LOD 1, 64×64 px display, 128×128 native).

CRITICAL CHIBI PROPORTIONS: 3-head ratio — head : torso : legs = 1 : 1 : 1. Head ~33% of total height.

CRITICAL VISUAL STYLE — SUMI-E BRUSH QUALITY (HIGHEST PRIORITY): Outlines MUST be hand-painted ink-wash brush strokes with VISIBLE thickness variation — thicker at silhouette edges (1.5-2x), thinner inside, with occasional brush-bleed and dry-drag texture. Robe folds especially show visible ink-wash bleed and graduated tone (the strategist's robe is the primary stage for sumi-e brush quality). This is traditional East Asian ink painting (墨绘 / 水墨) in chibi form. STRICTLY NOT vector-clean cartoon, NOT CalArts/Disney cartoon, NOT uniform digital ink. The brush must look hand-painted.

CRITICAL CHARACTER FACE: Pang Tong (龐統, 士元), strategist mid-to-late 30s. In chibi: two small black dots for eyes (NO large anime pupils), single short mouth line, NO nose detail. Face is deliberately ROUND and FULL — round-ish jaw, soft contours — distinguishing him from sharp-featured warriors. Skin: naturalistic warm-olive. ABSOLUTELY NO blush, NO pink/red cheek dots, NO moe softening (the round face provides identity — no cuteness markers needed).

CRITICAL PROP COUNT — EXACTLY ONE PROP IN ENTIRE FRAME: One large feather fan (봉추 phoenix feather emblem) held by the right hand at chest level. Fan width ~1.0x shoulder width. ABSOLUTELY NO additional fans, NO scrolls, NO weapons, NO secondary props of any kind anywhere in the frame. Left hand empty at his side. The figure carries EXACTLY ONE prop total.

POSE: Centered vertical calm stance — facing slightly right, weight evenly on both feet, NO hip cocking.

Outfit: Wide-sleeve scholar robe (鶴氅衣) — sleeves form triangular silhouette extending past shoulders. Square scholar cap (윤건). Robe color: ink-heavy black-grey (#1C1A17 deepened), with paper-white (#F2E8D4) fan and inner robe lining for contrast.

Background: TRANSPARENT alpha PNG. The figure sits on transparent alpha — no paper-cream fill, no border.

NEGATIVE / ANTI-REFERENCE: NO anime moe (no large eyes, no shoujo features, NO pink/red cheek blush dots, NO kawaii cuteness markers). NO cell-shading gradients. NO glow effects. NO Dynasty Warriors muscle-baroque. NO red/gold accents (reserved for VFX). NO clean vector cartoon, NO uniform-thickness outlines, NO CalArts/Disney style.

Composition: chibi figure centered, ~60% canvas vertically. Generous negative space.

Aspect ratio: 1:1, 128×128 native (display 64×64).
```

### Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/sprites/grid/sprite_shu_pang_tong_idle.png` |
| Dimensions | 128×128 native |
| Format | PNG with alpha |
| Frame | 1 of 1 (idle pose) |

### Acceptance for AI generation
- ✅ 3-head chibi 비례 / 얼굴 단순화 (눈 점 2 + 입 1선)
- ✅ NO 핑크/빨간 볼터치 / blush / moe softening (S71 attestation: 1차 regen 방통에서 발견 — 강화)
- ✅ 둥근 얼굴 형 (sharp-features 금지)
- ✅ **EXACTLY ONE prop — 부채 하나만**. 추가 부채/scroll/무기 절대 금지
- ✅ Wide-sleeve scholar robe silhouette
- ✅ 어두운 ink-heavy 색 + paper-white fan/lining contrast
- ✅ Sumi-e variable brush 외곽선 + 잉크 wash bleed visible (특히 로브 — vector-clean / CalArts 금지)
- ✅ 투명 배경 (alpha PNG, paper-cream fill 금지) + 평면 색 + 주홍/금색 침투 0
