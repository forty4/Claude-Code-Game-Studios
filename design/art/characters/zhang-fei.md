# 장비 (Zhang Fei) — Portrait Asset Spec

> **Status**: B2.4-a — spec authored, pending external AI gen (B2.4-b)
> **Hero ID**: `shu_003_zhang_fei` · **Portrait ID**: `portrait_shu_zhang_fei`
> **Cascade signature**: ch21 장비 hidden destiny (`WIN_zhangfei_survives`) — 장비는 ch1 부터 party. cascade 는 historical drunk-death 회피
> **Sources**: `art-bible-v1-distilled.md` §1 palette + §2 line + §4 장비 anatomy seed; `heroes.json` `shu_003_zhang_fei`; B2.1 위연 v3 + B2.2 방통 v2s + B2.3 관우 pipeline + reframe 학습 적용 (commits `4e5ceae`, `f6e994e`, `b3610ef`)
> **Date**: 2026-05-19

---

## Canonical anchors (from `heroes.json`)

| Field | Value | Visual implication |
|---|---|---|
| name_ko / name_zh / 자 | 장비 / 张飞 / 翼德 (Yide) | 자 "翼德" — raw force assault archetype |
| Faction | Shu (0) | Peach Garden Oath 삼각 의 left-side. 유비 (center) + 관우 (right) 와 silhouette collision 없어야 함 |
| Class | default_class=1 (assault) | 위연과 같은 class 지만 character profile 정반대 (위연 calculating mercenary / 장비 raw force) |
| Stat profile | **Might 92** · Intellect 50 · Command 70 · Agility 60 · **HP 95 (5장 최고치)** | 무력 95 관우 바로 아래, HP 가장 높음 — 헤비 탱크. 지력 5장 중 최저 |
| Innate skill | `skill_thunder_roar` (장팔사모 호통) | 사모 + 큰 호통 — wide-open mouth 같은 wild 표정 silhouette 에 살짝 반영 가능 |
| Join chapter | 1 (canonical) | cascade signature 는 ch21 historical drunk-death survival. portrait 는 character canonical state |
| Bond | `bond_oath_peach_garden` (SWORN_BROTHER 유비 + 관우, 둘 다 대칭) | Peach Garden 삼각 composition 의 **left-side**. 유비 center / 관우 right / 장비 left |

---

## Portrait brief (per distilled §4 + production interpretation)

**Wedge-shaped silhouette** — 어깨 broad 하지만 관우 의 broad-square 와 다름. **upper-body 가 강하게 spread → 발/허리는 좁은 wedge taper**. 자세는 약간 forward-leaning, 정적이지만 곧 움직일 듯한 coiled energy. 5장 중 heaviest 와 가까운 build (관우 와 비슷한 mass 지만 distribution 다름 — 관우 = planted square, 장비 = forward wedge).

**사모 (장팔사모 丈八蛇矛 / serpent spear)** — vertical protrusion above helmet, 폴암 보다 가늘고 곧음. spear tip 은 serpent-shaped (S자 곡선) — 관우의 curved crescent 와 명확히 구분되는 weapon silhouette. 자루는 ink-black wood, tip 은 plain ink-black metal with subtle ink wash. 머리 위로 frame top edge 까지 도달.

**Wild curled beard** — 관우의 long flowing neat beard 와 명확한 대비. 짧지 않지만 less long, **curling outward + bristling + untamed** — 가슴 보다 위에서 끝나지만 양옆으로 spread 하는 wildness. jet-black, expressive brush-stroke.

**표범안 (Leopard-ring eyes)** — large round wide-open eyes with high contrast — 눈 흰자위 (sclera) 가 명확히 보이는 round wide eyes. 관우의 sharp narrow phoenix eyes 와 정반대. 위협적이지만 약간의 self-control (discipline in eyes, but barely — distilled §4). 눈썹 두껍고 굵음.

**Darkest character** — 5장 중 가장 ink-heavy, 가장 high contrast. 갑옷이 진한 묵-tone iron-black, robe 는 dark slate-grey, 그림자 영역 더 진함. 관우 의 deep forest green 보다 한 단계 더 무겁고 어두운 인상.

**얼굴 skin tone**: warm sun-tanned olive — 위연 v3 + 방통 v2s + 관우 와 series consistency. NO 빨간 얼굴, NO 어색하게 어두운 피부 (Gemini default 인 "darkest character = darker skin" 트리거 회피 — character darkness 는 갑옷/robe/ink contrast 로만 표현).

머리: jet-black, military head wrap 또는 단단한 topknot. 헬멧을 쓴 변형도 가능 (관우의 simple wrap 과 구분 위해 슬쩍 더 무거운 head gear).

**Why these anchors**:
- 관우 (B2.3, heavy stoic) + 장비 (B2.4, heavy aggressive) — 둘 다 heavy build 지만 표정/자세/수염/눈/무기 모두 정반대. cascade 의 first 4 portrait 안에서 같은 "heavy" 범주 안의 시각 다양성 — 동질화 회피
- Peach Garden Oath 삼각 composition 준비: 장비 left / 관우 right / 유비 center. 셋이 같이 놓였을 때 weapon protrusion (장비 사모 수직 / 관우 폴암 수직 / 유비 paired swords 짧음) 만으로도 즉시 구분되어야 함
- 5장 중 **first wedge-shape silhouette** + **first 표범안 wide eyes** + **first wild beard** 도입 — 위연 v3 (asymmetric mercenary) + 방통 v2s (centered triangular scholar) + 관우 (immovable broad square) 의 silhouette 다양성 한 단계 더 확대

---

## Midjourney prompt — copy-paste ready

```
Three Kingdoms general Zhang Fei, wedge-shaped silhouette broad shoulders narrowing to waist forward-leaning coiled stance 3/4 view, holding long straight serpent spear (丈八蛇矛) vertically with serpent-shaped tip protruding above head as upper silhouette protrusion, wild curling outward bristling jet-black beard chest-length spreading sideways untamed brushstroke style, large round wide-open leopard-ring eyes with visible white sclera high contrast intense intimidating but with faint discipline barely held, thick prominent eyebrows, weathered sun-tanned olive warm complexion mature middle-aged hardened warrior face NOT red NOT vermillion, jet-black hair bound tightly under military head wrap or heavy topknot NO ornament, dark slate-grey heavy battle robe over deep ink-black iron lamellar armor with ochre-earth trim at cuffs, dark shoulder mantle, darkest figure of the five cascade heroes high ink contrast deep shadows, sumi-e ink wash painting illustration, Romance of Three Kingdoms historical style, variable-weight ink outlines thicker at silhouette edge, ink bleeds at outline edges, late-Ming woodblock print linework, Yokoyama Mitsuteru historical manga influence, monochrome wash underpainting limited muted colour palette, dark slate-grey robe and ink-black armor and ochre earth #C8874A trim on paper-white #F2E8D4 ground, ink-black #1C1A17 dominant deep shadows and outlines, warm late-afternoon Phase-D amber lighting, generous negative space behind figure centered composition, 8-heads-tall heavy-build proportion broad shoulders wedge silhouette, historical Three Kingdoms costume accuracy --ar 1:1 --style raw --s 200 --v 6 --no anime, photoreal, cel shading, gradient glow, bright saturation, dynasty warriors muscle armor, gold filigree, vermillion red accents, modern western fantasy, glowing weapon trail, decorative serpent engraving on spear, slender build, calm composed expression
```

**MJ 튜닝 메모**:
- 무기 잘못 (검 / 폴암 / 청룡언월도 모양) → `long straight spear shaft with serpent-shaped curving S-tip, NOT a curved crescent polearm, NOT a sword` 강화
- 수염 neat / 짧음 → `wild curling beard spreading outward like flames, bristling and untamed, NOT neat, NOT trimmed, NOT long flowing` 강화
- 눈 narrow / 평범 → `large round wide-open intense leopard eyes, NOT narrow, NOT phoenix-eyed` 강화
- Build slender → `wedge silhouette: broad upper shoulders tapering to narrower waist and feet` 강화
- 색이 너무 밝거나 colourful → `dark slate-grey robe and ink-black armor, this character is the darkest of the five — high ink contrast` 강화
- 표정 calm / 부드러움 → `intense intimidating expression, contained ferocity, eyes barely held in discipline` 강화

---

## Gemini prompt — copy-paste ready (reframe 학습 적용)

> 위연 v3 + 방통 v2 + 관우 의 **검증된 reframe 원칙** 적용:
> - "red face" 부정 → "warm sun-tanned olive complexion" + "same skin tone as previous portraits in this series" series anchor. "red" / "vermillion" 단어 prompt 0회
> - "darkest character" risk 차단: skin tone series anchor + "character darkness conveyed through armor/robe/ink contrast only, NOT through skin tone shift" type 명시
> - 무기 type 우선: "straight spear with serpent S-tip" (관우 curved polearm 과 구분)
> - 수염 type 우선: "wild curling outward bristling" 부위별 묘사 (neat beard prior 회피)
> - 눈 type 우선: "large round wide-open visible sclera high contrast" 부위별 묘사
> - Series anchor 강화: "same skin tone as previous three portraits"

```
A portrait illustration of a Three Kingdoms-era Chinese general, painted in traditional sumi-e ink wash style. This is part of a 5-portrait series — match the established visual style of the previous three portraits (Wei Yan: mid-40s mercenary with hilt-on-scabbard; Pang Tong: round-faced middle-aged strategist with fan; Guan Yu: heavy stoic general with long beard and polearm).

CRITICAL CHARACTER FACE AND SKIN: The character's skin tone is naturalistic warm sun-tanned olive — the same warm tan, weathered, sun-bronzed complexion as the first three portraits in this series. His face has mature, weathered, intense features. CRITICAL: large round wide-open leopard-ring eyes with clearly visible white sclera around the iris, high contrast and intimidating — these are NOT narrow eyes, NOT phoenix-shaped. Thick prominent dark eyebrows. The expression reads as contained ferocity — intense and dangerous, with faint self-discipline barely held in check.

CRITICAL CHARACTER BUILD AND POSE: His build is heavy with a distinct WEDGE silhouette — broad upper shoulders tapering inward to a narrower waist and feet. This wedge shape is different from the previous portrait (Guan Yu's broad-square build). He stands in a slight forward-leaning coiled stance, three-quarter view facing slightly left — static but reading as "about to move." Both feet planted.

CRITICAL SPEAR PROTRUSION: In his right hand he holds a long straight spear (the 丈八蛇矛, "Eighteen-foot Serpent Spear"). The spear shaft is held vertically and extends upward to reach the TOP EDGE of the image frame. The spear tip is shaped like a serpent — a curving S-shape blade tip, NOT a straight point, NOT a curved crescent (the previous portrait's polearm). The shaft is plain ink-black wood, the tip is plain ink-black metal with subtle ink wash — uncarved, simple, smooth unadorned surface.

CRITICAL BEARD DIRECTION: His beard is jet-black, wild and curling outward — bristling, untamed, spreading sideways like flames. The beard reaches mid-chest length but its silhouette spread is HORIZONTAL (sideways spread) rather than vertical (straight down). This is the wild contrast to the previous portrait's neat long flowing beard.

CHARACTER CONTEXT — Zhang Fei (张飞, 翼德), known for raw force and the thunder roar. Peach Garden Oath sworn brother (left position of the trio, with Liu Bei center and Guan Yu right).

CRITICAL CHARACTER DARKNESS: This figure reads as the darkest of the 5-portrait series. The character's darkness is conveyed through armor and robe tones and ink contrast intensity — NOT through skin tone shift (skin matches prior portraits exactly). The dark slate-grey heavy battle robe and ink-black iron lamellar armor create high contrast against the paper-white ground. Shadow areas are deeper and more dominant than in the prior three portraits.

He wears a dark slate-grey heavy battle robe over ink-black iron lamellar armor with ochre-earth (#C8874A) trim at the cuffs. A dark shoulder mantle frames the upper silhouette. Hair bound tightly in a military head wrap or heavy topknot, jet-black, no ornament.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. Variable-weight ink outlines, thicker at the silhouette edge, with visible ink bleeds. Monochrome wash underpainting with restrained muted color: dark slate-grey for the robe, ink-black (#1C1A17 dominant) for the armor and shadows, ochre earth (#C8874A) for the trim, paper-white (#F2E8D4) with visible paper grain for the ground.

Lighting: warm late-afternoon amber. Generous negative space behind the figure. Composition centered, figure rendered at 8-heads-tall heavy-build proportion with wedge silhouette. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects, bright saturated colors, or modern Western fantasy elements. Do not use Dynasty Warriors aesthetics. Do not include gold filigree or ornate decoration on the weapon.
```

**Gemini 튜닝 메모** (reframe 학습 적용):
- "red face" risk: "red"/"vermillion" 단어 0회. type 명시 ("warm sun-tanned olive") + series anchor ("same as first three portraits"). 위연 v3 / 방통 v2 / 관우 에서 검증된 패턴
- "darkest character" risk: 단순 "darkest" 만 명시하면 Gemini 가 skin tone 어둡게 만들 위험 → "darkness conveyed through armor/robe tones and ink contrast, NOT through skin tone shift" 명시 + skin tone series anchor
- 무기 type 우선: "straight spear with serpent S-tip" anchor + 관우 폴암 안티-비교 ("NOT a curved crescent")
- 수염 wild type: "curling outward bristling spreading sideways like flames" 부위별 동사 묘사 + 관우 안티-비교 ("contrast to previous portrait's neat long flowing beard")
- 눈 표범안: "large round wide-open with visible white sclera, high contrast" 부위별 + 관우 안티-비교 ("NOT narrow, NOT phoenix-shaped")
- 표정 calm risk: "contained ferocity, faint self-discipline barely held" type prescription
- Spear tip decoration: "uncarved, simple, smooth unadorned" type prescription (관우 blade 와 동일 reframe)

---

## Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/portraits/portrait_shu_zhang_fei.png` |
| Dimensions | 1024×1024 |
| Format | PNG (no transparency — paper-white `#F2E8D4` ground is design intent) |
| Variants in this spec | 1 (canonical baseline) — Peach Garden / drunk-death variants are future |
| Convention | `assets/art/portraits/{portrait_id}.png` — established by B2.1 |

---

## Integration plan (B2.4-c — same session as B2.4-b drop-in)

pipeline B2.1 검증 완료, B2.2-3 일반화 증명 — 자산 drop-in 만:

1. `assets/art/portraits/portrait_shu_zhang_fei.png` 배치
2. `godot --headless --import --path .` (이미지 import)
3. 헤드리스 부팅 + 풀 테스트 (baseline 유지 확인)
4. windowed 검증: 메인메뉴 → 시그니처 아카이브 → **장비 카드** portrait 표시

**코드 변경 0** — SIGNATURE_CATALOG 가 이미 `&"shu_003_zhang_fei"` 포함.

---

## Acceptance for AI generation (B2.4-b — user side)

Ship-able output must satisfy (single AND gate):
- ✅ 사모 (straight spear with serpent S-tip) 가 vertical, blade frame top edge 까지 도달
- ✅ Wild curling outward bristling 수염 (NOT neat, NOT long flowing — 관우와 정반대)
- ✅ Large round wide-open 표범안 (NOT narrow, NOT phoenix — 관우와 정반대)
- ✅ Wedge silhouette: broad shoulders → narrower waist + feet (NOT broad square 관우 와 구분)
- ✅ Slight forward-leaning coiled stance (NOT planted-still 관우 와 구분)
- ✅ Naturalistic skin tone — warm sun-tanned olive, 위연/방통/관우와 series consistency (NOT 어둡게 shift, NOT red)
- ✅ Dark slate-grey robe + ink-black armor + ochre trim only — 5장 중 가장 high contrast
- ✅ Sumi-e 잉크-워시 visual language, 시리즈 화풍 통일
- ✅ Negative space 충분

If any miss → regen with tuning notes above. No manual touch-up (per AI-output-direct policy).

---

## Cross-reference: 5-hero cascade visual differentiation (B2.4 row added)

| Hero | Phase / lighting | Posture | Prop | Build / silhouette | Face / beard / eyes |
|---|---|---|---|---|---|
| **위연** (B2.1 v3 ✅) | B blue-grey cold | Asymmetric mercenary 3/4 | Sword hilt at scabbard | Medium lean | Weathered sharp narrow / no beard / inward |
| **방통** (B2.2 v2s ✅) | C amber dusk | Centered static near-frontal | Paper-white folding fan | Medium-short scholar (round) | Plain round mature / no beard / forward calm |
| **관우** (B2.3 ✅) | D warm amber relief | Massive immovable broad square 3/4 | 청룡언월도 curved crescent polearm (vertical, top) | **Heavy broad square** | Weathered stern / **long neat flowing chest beard** / **phoenix-narrow eyes** |
| **장비** (B2.4 — this) | D warm amber | Forward-leaning coiled 3/4 | **사모 straight spear, serpent S-tip** (vertical, top) | **Heavy wedge (shoulders→waist taper)** | Intense barely-controlled / **wild curling outward beard** / **leopard-round eyes wide-open** |
| 유비 (B2.5) | E cold blue→gold dawn | Balanced open-arm rally | 双股劍 paired swords (short, dual) | Medium balanced | Prominent ears / full-trim beard / direct forward |

5장 통일성 추적 — phase / posture / prop / build / face·beard·eyes 5축. B2.4 시점:
- Phase 3가지 사용 (B/C/D) — D 가 2장 (관우 + 장비, 둘 다 cascade survival hidden destiny + Phase D 한중-이릉)
- Build: medium → medium-short → heavy-square → **heavy-wedge** — 같은 "heavy" 범주 안의 첫 구별 (square vs wedge silhouette)
- Beard: 0 → 0 → neat flowing chest-length → **wild curling outward** — 같은 "long beard" 안의 첫 구별 (neat vs wild)
- Eyes: 측면 → forward calm → **phoenix narrow** → **leopard round wide-open** — 처음으로 시선 방향이 아닌 eye SHAPE 으로 구별
- Prop: 검 hilt → 부채 → **curved crescent polearm** → **straight serpent spear** — 같은 "vertical protrusion above head" 범주의 첫 구별 (curve vs straight, crescent vs S-tip)

**관우 ↔ 장비 cross-reference (Peach Garden left/right pair)**:
- 둘 다 heavy build + vertical weapon protrusion + warm Phase D lighting
- 정반대: build shape (square vs wedge) + beard (neat vs wild) + eyes (narrow vs round) + posture (planted vs forward-leaning) + weapon tip (crescent vs serpent S)
- 5축 모두 명확한 contrast → 같은 frame 에 함께 놓여도 즉시 구분 가능

---

## Grid sprite (chibi) — Q5 Phase 1 (신규 2026-05-20)

art-bible §5.7 정합.

### Per-hero chibi 요소 (장비 한정)
- **정체성**: assault cavalry, raw force, forward-leaning. wedge-shaped silhouette.
- **무기**: 장팔사모 (serpent spear, 丈八蛇矛) — chibi 머리 위로 솟은 수직 spear. tip 은 S-curve (serpent).
- **수염**: 검은 곱슬 수염, 거칠게 흩어짐 — chibi 비례에서도 wild silhouette 유지.
- **눈**: 표범 눈 (leopard-ring) — chibi 단순화에서도 눈 = 검은 점이되 약간 더 크고 또렷.

### Gemini prompt — copy-paste ready

```
A chibi grid sprite of a Three Kingdoms-era Chinese assault cavalry general, painted in STRICTLY ink-wash sumi-e brush style applied to chibi proportions. For tactical RPG combat grid (LOD 1, 64×64 display, 128×128 native).

CRITICAL CHIBI PROPORTIONS: 3-head ratio. Wedge-shaped torso (shoulders wider than hips). Pronounced forward lean — clear momentum read, weight on front foot.

CRITICAL VISUAL STYLE — SUMI-E BRUSH QUALITY (HIGHEST PRIORITY): Outlines MUST be hand-painted ink-wash brush strokes with VISIBLE thickness variation — thicker at silhouette edges (1.5-2x), thinner inside, with brush-bleed and dry-drag texture. THE BEARD especially uses heavy wet-brush ink with visible drag and bleed (the wildness IS the brush quality). Armor folds also show ink-wash bleed. This is traditional East Asian ink painting (墨绘 / 水墨) in chibi form. STRICTLY NOT vector-clean cartoon, NOT CalArts/Disney cartoon, NOT uniform digital ink. The brush must look hand-painted.

CRITICAL CHARACTER FACE — LEOPARD-RING EYES (HIGHLY EXAGGERATED): Zhang Fei (張飛, 翼德), raw force. Eyes are notably LARGER and ROUNDER than typical chibi dot eyes — approximately 1.5x the size of normal chibi eye dots. The eyes should be CLEARLY VISIBLE as bold black circular pupils with white outer ring around them (leopard-ring 표범 눈 intensity). Each eye occupies a meaningfully visible portion of the face, intense glare implied. Single mouth line, NO nose. Skin: darker / higher contrast than other heroes (highest contrast in the 5-hero series). NO blush, NO pink/red cheek dots, NO moe softening.

CRITICAL WEAPON COUNT — EXACTLY ONE WEAPON ITEM IN ENTIRE FRAME: One single tall spear (장팔사모 — Serpent Spear) held vertically in right hand. Spear shaft extends UP past head, TIP at top with clear S-curve (serpent silhouette). Spear shaft thinner than Guan Yu's polearm. ABSOLUTELY NO secondary weapon, NO sword on the hip, NO dagger, NO additional spear. The figure carries EXACTLY ONE weapon total. Left hand empty.

CRITICAL BEARD AND HAIR: Black curly wild beard, scattered and rough — silhouette spills beyond armor edges. Hair tied in topknot but with stray curls. The beard's wildness is the visual key.

Outfit: Dark armor with leather binding. Dark color palette — highest contrast figure. NO ceremonial gold, NO bright colors.

Background: TRANSPARENT alpha PNG.

NEGATIVE / ANTI-REFERENCE: NO anime moe (NO pink/red cheek blush dots, NO moe softening). NO Dynasty Warriors muscle-baroque exaggeration. NO red/gold accents. NO cell-shading gradients. NO clean vector cartoon, NO uniform-thickness outlines, NO CalArts/Disney style. NO additional weapons beyond the single serpent spear. NO normal-size chibi dot eyes (eyes MUST be visibly larger/rounder).

Composition: forward-leaning chibi with spear vertically above. ~70% canvas vertically.

Aspect ratio: 1:1, 128×128 native.
```

### Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/sprites/grid/sprite_shu_zhang_fei_idle.png` |
| Dimensions | 128×128 native |
| Format | PNG with alpha |
| Frame | 1 of 1 (idle pose) |

### Acceptance
- ✅ 3-head + wedge torso + **명확한 forward-lean** (S71 attestation: 1차 regen 거의 직립 — 강화)
- ✅ **눈 = 1.5× larger + rounder leopard-ring** — 일반 chibi dot 보다 명확히 큼 (S71 attestation: 1차 regen 약화 — 절대수치 강화)
- ✅ NO 핑크/빨간 볼터치 / blush / moe softening
- ✅ **EXACTLY ONE weapon — 장팔사모 spear 하나만**. 추가 칼/단검 절대 금지
- ✅ 장팔사모 spear 머리 위 vertical, 명확한 S-curve tip
- ✅ Wild curly black beard silhouette spilling beyond armor
- ✅ 어두운 palette + 최고 대비 (5 영웅 중 가장 어두움)
- ✅ Sumi-e variable brush 외곽선 + 잉크 wash bleed visible, 특히 수염은 wet-brush 강조
- ✅ 투명 배경 (alpha PNG, paper-cream fill 금지) + 평면 색 + 주홍/금색 침투 0


## Breath frame (Phase 2) — 신규 2026-05-21

art-bible §5.7 Phase 2 — idle breath 2-frame ping-pong (1.6s cycle). 장비의 호흡
은 **assault 결의 가장 깊은 호흡** — chest 가장 크게 expand + 어깨 명확 lift +
wedge torso 더 두드러짐. leopard-ring eye + wild beard silhouette 보존 critical.

### Breath modification prompt — image-to-image (idle PNG 입력 시)

```
Apply BREATH MODIFICATIONS to the input idle PNG of Zhang Fei, producing the
second frame of his 2-frame breath cycle.

VISIBLE CHANGES (clearly mid-inhale, deepest breath of the 5 heroes):
- Chest puffed outward ~12% wider than idle (DEEPEST among 5 heroes)
- Shoulders raised noticeably ~6-8% higher
- Torso slightly elongated ~3-4% vertically
- Wedge torso silhouette becomes more pronounced (shoulders more visibly wider
  than hips)
- Forward-lean stance unchanged (NOT straightened) — momentum read preserved

EVERYTHING ELSE 100% IDENTICAL TO INPUT IDLE:
- Same LEOPARD-RING EYES — 1.5× larger black dots with white outer ring
- Same single mouth line, NO nose
- Same wild curly black beard spilling beyond armor edges (wet-brush ink wash)
- Same hair topknot with stray curls
- Same 장팔사모 spear held vertically in right hand, S-curve tip at top
- Same dark armor with leather binding, same darkest color in the 5-hero series
- Same sumi-e wet-brush ink quality (especially beard)
- Same TRANSPARENT alpha PNG background (NOT black fill, NOT decorative frame)
- Same image dimensions

Output filename: sprite_shu_zhang_fei_breath.png
```

### Text-to-image fallback prompt (idle PNG 없이)

위 idle prompt 를 base + 위 VISIBLE CHANGES 블록을 `POSE` 섹션 앞에 삽입.
leopard-ring eye 1.5× + wild beard wet-brush + wedge torso forward-lean 보존
critical 명시.

### Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/sprites/grid/sprite_shu_zhang_fei_breath.png` |
| Frame | 2 of 2 (Phase 2 ping-pong with idle) |
| Format | PNG with alpha (TRANSPARENT background) |
| Dimensions | idle 와 동일 |

### Acceptance for breath frame
- ✅ Side-by-side with idle: 가장 깊은 호흡 명확 (다른 4 영웅 대비 chest delta 최대)
- ✅ leopard-ring eye 1.5× + 흰자 ring 동일 (drift 금지)
- ✅ Wild curly beard silhouette 보존 (wet-brush ink wash 동일)
- ✅ 장팔사모 spear vertical + S-curve tip 위치 동일
- ✅ Forward-lean stance 유지 (호흡으로 직립 변경 금지)
- ✅ TRANSPARENT alpha background
- ✅ 1 weapon + NO blush + 최고 대비 어두운 palette 동일
