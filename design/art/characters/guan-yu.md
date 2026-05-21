# 관우 (Guan Yu) — Portrait Asset Spec

> **Status**: B2.3-a — spec authored, pending external AI gen (B2.3-b)
> **Hero ID**: `shu_002_guan_yu` · **Portrait ID**: `portrait_shu_guan_yu`
> **Cascade signature**: ch20 번성 hidden destiny (`WIN_fancheng_guan_yu_survives`) — 관우는 ch1 부터 party 에 있음. cascade 는 survival 발동
> **Sources**: `art-bible-v1-distilled.md` §1 palette + §2 line + §4 관우 anatomy seed; `heroes.json` `shu_002_guan_yu`; B2.1 위연 + B2.2 방통 pipeline 검증 (commits `3d60a46`, `8a73f20`)
> **Date**: 2026-05-19

---

## Canonical anchors (from `heroes.json`)

| Field | Value | Visual implication |
|---|---|---|
| name_ko / name_zh / 자 | 관우 / 关羽 / 云长 (Yunchang) | 자 "云长" — heroic loyalty archetype |
| Faction | Shu (0) | But 녹포 (green robe) historical exception — see palette note below |
| Class | default_class=0 (WARRIOR / Heavy cavalry archetype) | 猛將 silhouette — heavy armor + polearm |
| Stat profile | **Might 95** · Intellect 60 · Command 80 · Agility 70 | 무력 95 최고치 — 순수 전투형. 5장 중 가장 무거운 read |
| Innate skills | `skill_dragon_blade` + `skill_loyalty` | 청룡언월도 + 충의 — 두 skill 모두 portrait silhouette 에 직접 반영 (polearm + 표정) |
| Join chapter | 1 (`story_ch1_intro`) — canonical join | cascade 는 ch20 번성 survival 에서 발동. portrait 는 character canonical state |
| Bond | `bond_oath_peach_garden` (SWORN_BROTHER 유비 + 장비, 둘 다 대칭) | Peach Garden 삼각 composition 의 right-side position. 유비/장비 portrait 와 silhouette collision 없어야 함 |

---

## Portrait brief (per distilled §4 + production interpretation)

**Massive immovable stance**, standing 3/4 view facing slightly left, body weight planted, shoulders broad and square. 5장 중 **scale 가장 큼** — figure 가 1024×1024 frame 의 vertical 80% 차지, 어깨 폭 위연/방통 대비 명확히 넓음. 머리 크기는 proportional 작음 (8-heads-tall, 어깨가 크게 보여야 immovable read).

**청룡언월도 (Green Dragon Crescent Blade)** — 폴암, 머리 위로 vertical protrusion (upper-right diagonal). 도신 (blade) 부분이 head level 보다 위에 위치 — silhouette 의 가장 두드러진 asymmetric feature. 자루 (shaft) 는 손에 잡혀 있고 도신 끝까지 frame 안에 들어와야 함. 도신 자체는 ink-black + 잉크 wash 의 microscopic 청회 hint (NOT 화려한 dragon engraving).

**녹포 (Green Battle Robe)** — historical canonical 청포. 색 `#2D6B4A` (distilled §1 의 Wu faction green 과 동일 hex — bible 의 "historical exception" 으로 명시 허용). 갑옷 위에 입은 robe + 어깨 망토. 갑옷 base: 묵 + 황토 trim (Shu 정체성). 녹포 가 Wu faction reading 으로 잘못 읽히지 않도록 prompt 에 "historical Guan Yu robe, NOT Wu faction" 명시.

**Long beard (美髯公)** — 가슴 level 까지 내려오는 긴 수염, ink-black flowing brush-stroke, chest 의 asymmetric mass. 수염 끝이 robe 의 chest panel 과 겹치며 silhouette break-up.

**얼굴**: weathered mature stern, sharp 봉의 눈 (phoenix eyes — long narrow), prominent brow. **NO vermillion red face** (canonical Three Kingdoms 의 새빨간 얼굴은 palette §1 reserved 주홍 `#C0392B` 침범 — restraint discipline 위반). 자연스러운 weathered sun-tanned 피부톤 (warm undertones OK; saturated red 금지). long beard + green robe + polearm 의 triplet 으로 관우 식별 가능 — red face 없이도 canonical recognition.

머리: 학자 관모 아님. 무장 head wrap 또는 단단히 묶은 topknot. ink-black.

**Phase D lighting reframe**: §3 default "sunset red-orange grief" 인데 관우 hidden destiny 는 **번성 survival = relief moment**. 따라서 prompt 는 "warm amber late-afternoon light, the relief of return alive" — 같은 phase D atmospheric markers 지만 grief 가 아닌 comeback 의 톤.

**Why these anchors**: 관우 = cascade 의 immovable anchor. 위연 (B2.1, 동적 mercenary) + 방통 (B2.2, 정적 strategist) 는 둘 다 medium-light scale. 관우 는 처음으로 5장 중 heaviest read 도입 — silhouette 의 시각 무게가 한 단계 점프. 장비 (B2.4, raw force) 와의 cross-class 구분: 관우 = stoic immovable / 장비 = wild aggressive. 두 무장이 같이 frame 안에 놓였을 때 (Peach Garden tableau) 관우 가 right, 장비 가 left, 유비 가 center 의 캐논 composition 이 silhouette 만으로 작동해야 함.

---

## Midjourney prompt — copy-paste ready

```
Three Kingdoms general Guan Yu, massive immovable standing pose 3/4 view facing slightly left, body weight planted shoulders broad and square, holding Green Dragon Crescent Blade (青龍偃月刀) polearm with blade protruding vertically above the head as upper-right silhouette asymmetric protrusion, long flowing chest-length jet-black beard (美髯公 Beautiful Beard Duke) brushstroke style spilling over chest panel, weathered mature stern face with sharp narrow phoenix eyes prominent brow, NO vermillion red face NO bright red skin, naturalistic warm sun-tanned weathered complexion, jet-black hair bound in tight topknot or simple head wrap NO ornament NO ceremonial hat, historical Guan Yu dark green battle robe (deep forest green #2D6B4A — historical canonical 녹포 NOT Wu faction reading), iron-grey lamellar armor beneath robe with ochre-earth trim at cuff, dark shoulder mantle, polearm shaft visible in right hand crescent blade ink-black with subtle blue-grey wash hint, sumi-e ink wash painting illustration, Romance of Three Kingdoms historical style, variable-weight ink outlines thicker at silhouette edge, ink bleeds at outline edges, late-Ming woodblock print linework, Yokoyama Mitsuteru historical manga influence, monochrome wash underpainting limited muted colour palette, deep forest green #2D6B4A robe iron blue-grey #5C7A8A armor and ochre earth #C8874A trim on paper-white #F2E8D4 ground, ink-black #1C1A17 deep shadows and outlines, warm amber late-afternoon Phase-D Fancheng-return relief lighting NOT grief, generous negative space behind figure centered composition, 8-heads-tall proportion broad-shouldered heavy build, historical Three Kingdoms costume accuracy --ar 1:1 --style raw --s 200 --v 6 --no anime, photoreal, cel shading, gradient glow, bright saturation, dynasty warriors muscle armor, gold filigree, vermillion red accents, red skin face, modern western fantasy, glowing weapon trail, decorative dragon engraving on blade, small slender frame
```

**MJ 튜닝 메모** (1차 batch 가 어긋난 방향별):
- 폴암 (청룡언월도) 누락 / 잘못된 무기 → `holding long polearm with curved crescent blade protruding above head, blade visible in upper portion of frame` 강화
- 수염 짧음 / 없음 → `long flowing chest-length beard spilling onto torso, beard is essential character identifier` 강화
- 얼굴이 새빨감 (canon red face) → exclusion `NO red skin, NO red face, NO vermillion complexion` 추가 + `naturalistic skin tone` 강화
- 어깨가 좁아 medium build → `broad square shoulders heavy build, NOT slender, NOT athletic` 추가
- 녹포 색이 너무 밝거나 청록 → `deep forest green robe close to #2D6B4A, dark muted green NOT bright NOT teal` 강화
- 폴암 블레이드 화려 → `simple ink-black crescent blade, NO dragon carving, NO gold engraving, NO decorative trim`

---

## Gemini prompt — copy-paste ready (reframe 학습 적용)

> 위연 v3 + 방통 v2-strengthened 의 **검증된 reframe 원칙** 적용:
> - "red face" 부정 → "warm sun-tanned olive complexion" type 명시 + series anchor ("same skin tone as previous two portraits in this series"). "red" / "vermillion" 단어 prompt 전체 0회 (canon prior 트리거 회피)
> - 부정 exclusion list 슬림화 (face color 관련 부정 제거)
> - **series anchor 강화**: 위연 v3 + 방통 v2 와 cascade 통일성 — 화풍 + 피부 톤 + 형식 모두 anchor

```
A portrait illustration of a Three Kingdoms-era Chinese general, painted in traditional sumi-e ink wash style. This is part of a 5-portrait series — match the established visual style of the previous two portraits (Wei Yan: mid-40s hardened mercenary; Pang Tong: round-faced middle-aged strategist with folding fan).

CRITICAL CHARACTER FACE AND SKIN: The character's skin tone is naturalistic warm sun-tanned olive — the same warm tan, weathered, sun-bronzed complexion as the first two portraits in this series. His face has mature, weathered, stern features: sharp narrow phoenix-shaped eyes (봉의 눈), prominent brow, mature middle-aged build of a hardened general. His skin color matches the skin of the prior portraits in this series exactly.

CRITICAL CHARACTER BUILD: This is the heaviest-built figure of this 5-portrait series. His build is heavy and broad — broad square shoulders, heavy torso, planted stance. He is distinctly more massive than the previous two portraits (Wei Yan's medium lean build, Pang Tong's medium scholar build). His silhouette reads "immovable" — heavy build is essential to character identity.

CRITICAL POLEARM PROTRUSION: In his right hand he holds a long polearm called the Green Dragon Crescent Blade (青龍偃月刀). The polearm shaft is held vertically. The curved crescent blade at the top of the polearm extends upward to reach the TOP EDGE of the image frame — the blade must be clearly visible as the upper asymmetric silhouette protrusion. The blade itself is plain ink-black metal with subtle blue-grey ink wash — uncarved, simple, restrained, with a smooth unadorned surface.

CHARACTER CONTEXT — Guan Yu (关羽, 云长), known for legendary loyalty. He stands in a massive, immovable, fully static pose — three-quarter view facing slightly left, body weight planted, both feet firmly on the ground.

His most distinctive identifying feature is his legendary long beard (美髯公). The beard is jet-black, flowing in expressive brushstroke ink-wash style, reaching all the way down to mid-chest, covering the upper portion of his torso and spilling over the front of his robe. The beard is essential to character recognition.

Hair bound in a tight topknot or simple military head wrap, jet-black, no ornament, no ceremonial hat.

He wears a deep forest green battle robe (exactly hex #2D6B4A — a deep muted shadow-green, the historical canonical green of this character) over iron blue-grey lamellar armor with ochre-earth (#C8874A) trim at the cuffs. A dark shoulder mantle frames the upper silhouette.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. Variable-weight ink outlines, thicker at the silhouette edge, with visible ink bleeds. Monochrome wash underpainting with restrained muted color: deep forest green (#2D6B4A) for the robe, iron blue-grey (#5C7A8A) for the armor, ochre earth (#C8874A) for the trim, ink-black (#1C1A17) for shadows and outlines, paper-white (#F2E8D4) with visible paper grain for the ground.

Lighting: warm late-afternoon amber. Generous negative space behind the figure. Composition centered, figure rendered at 8-heads-tall heavy-build proportion. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects, bright saturated colors, or modern Western fantasy elements. Do not use Dynasty Warriors aesthetics. Do not include gold filigree or ornate decoration.
```

**Gemini 튜닝 메모** (reframe 학습 적용):
- 빨간 얼굴 risk (highest — canon prior): "red" / "vermillion" 단어를 prompt 에서 완전 제거. type 명시 ("warm sun-tanned olive") + series anchor ("same skin tone as previous two portraits") 의 positive structure 로 anchor 우선. exclusion list 에서 face color 부정 모두 제거 (canon prior 트리거 회피).
- 폴암 블레이드 dragon engraving: "Green Dragon" 이름 직후에 즉시 type prescription ("plain ink-black metal, uncarved, simple, restrained, smooth unadorned surface") 으로 anchor. "NO dragon engraving" 같은 부정은 약하게 작동 — 긍정 prescription 이 더 효과적.
- 폴암 크롭: "extends upward to reach the TOP EDGE of the image frame" 좌표 명시. v3 학습 (lower-left of frame 같은 좌표 명시) 와 동일 원칙.
- 어깨/build narrow risk: series comparison anchor ("distinctly more massive than the previous two portraits") + type prescription ("heavy and broad — broad square shoulders, heavy torso, planted stance"). 부정 ("NOT slender, NOT athletic") 도 보조하지만 type 우선.
- 녹포 색 drift: hex 명시 + "deep muted shadow-green, the historical canonical green of this character" type prescription. "historical exception, NOT Wu faction" 같은 메타-설명 제거 (Gemini 가 historical/Wu 같은 추상 도메인 구분 못 honor).
- "Phase D relief vs grief" 미세 분간: 삭제. 단순 "warm late-afternoon amber" 만 — Gemini 가 grief vs relief 추상 honor 못 함.

---

## Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/portraits/portrait_shu_guan_yu.png` |
| Dimensions | 1024×1024 |
| Format | PNG (no transparency — paper-white `#F2E8D4` ground is design intent) |
| Variants in this spec | 1 (canonical baseline) — Peach Garden / Fancheng survival / death variants are future |
| Convention | `assets/art/portraits/{portrait_id}.png` — established by B2.1 |

---

## Integration plan (B2.3-c — same session as B2.3-b drop-in)

pipeline 은 B2.1 에서 검증 완료, B2.2 에서 일반화 증명 — 자산 drop-in 만으로 자동 통합:

1. `assets/art/portraits/portrait_shu_guan_yu.png` 배치
2. `godot --headless --import --path .` (이미지 import)
3. 헤드리스 부팅 + 풀 테스트 (baseline 유지 확인)
4. windowed 검증: 메인메뉴 → 시그니처 아카이브 → **관우 카드** portrait 표시 (위연 + 방통 카드와 동일 HBox 레이아웃, signature 미달성 시 alpha 0.45 dim)

**코드 변경 0** — SIGNATURE_CATALOG 가 이미 `&"shu_002_guan_yu"` 포함 (B2.1 commit `3d60a46`).

---

## Acceptance for AI generation (B2.3-b — user side)

Ship-able output must satisfy (single AND gate):
- ✅ 청룡언월도 polearm visible, blade extending above head as upper protrusion
- ✅ Chest-length long flowing black beard (NOT short, NOT trimmed)
- ✅ Broad square heavy build (NOT slender, NOT athletic)
- ✅ Massive immovable static pose (NOT dynamic action)
- ✅ Naturalistic skin tone — NOT red / NOT vermillion / NOT canon-red face
- ✅ Deep forest green #2D6B4A robe (NOT teal / NOT bright / NOT olive)
- ✅ Sumi-e 잉크-워시 visual language (NOT anime cel-shading, NOT photoreal, NOT gradient-glow)
- ✅ Iron-grey armor + ochre trim only (NO gold filigree, NO ornate decoration)
- ✅ Negative space around figure

If any miss → regen with tuning notes above. No manual touch-up (per AI-output-direct policy).

---

## Cross-reference: 5-hero cascade visual differentiation (B2.3 row added)

| Hero | Phase / lighting | Posture | Prop | Palette warmth | Face / build |
|---|---|---|---|---|---|
| **위연** (B2.1 ✅) | B blue-grey cold | Asymmetric mercenary 3/4 | Sword hilt at hip | Iron-grey + ochre | Weathered sharp narrow / medium |
| **방통** (B2.2 ✅) | C amber dusk Sichuan shadow | Centered triangular static | Paper-white folding fan | Ink-black + ochre trim | Plain round mature scholar / medium |
| **관우** (B2.3 — this) | D warm amber relief (NOT grief) | Massive immovable 3/4 | 청룡언월도 polearm (upper protrusion) | Deep forest green #2D6B4A + iron-grey + ochre | Weathered stern phoenix-eyes long beard / **heavy** |
| 장비 (B2.4) | D? sunset orange | Wedge-shaped wild | 사모 (serpent spear) vertical | High contrast darkest | Leopard-ring eyes wild beard / heavy aggressive |
| 유비 (B2.5) | E cold blue→gold dawn | Balanced open-arm rally | 双股劍 paired swords | Ink + ochre trim | Prominent ears full-trim beard / medium balanced |

5장 통일성 추적 — phase / posture / prop / palette / face·build 5축. B2.3 시점:
- Phase 3가지 모두 등장 (B/C/D) — 위연 cold → 방통 dusk → 관우 warm amber. Phase 다양성 시각 확인 가능
- Build 첫 heavy 도입 (관우) — 위연/방통의 medium-build 와 명확한 무게 대비
- Prop: 검 hilt → 부채 → polearm — propusion 길이가 점점 길어지면서 silhouette 의 vertical extent 확대
- Palette 첫 green 도입 (관우 녹포 historical exception) — 위연 iron-grey, 방통 ink-heavy 와 색 다양성 시작

---

## Grid sprite (chibi) — Q5 Phase 1 (신규 2026-05-20)

art-bible §5.7 정합. portrait (sumi-e formal) 과 별도 자산.

### Per-hero chibi 요소 (관우 한정)
- **정체성**: heavy cavalry, immovable pillar. chibi 라도 frame 안에서 가장 큰 silhouette (다른 영웅 대비 어깨 폭 1.3x).
- **무기**: 청룡언월도 (Green Dragon Crescent Blade) — chibi 머리 높이 위로 솟은 수직 polearm. 초승달 날 = 우상단 돌출.
- **수염**: 긴 검은 수염 — 흉부까지 내려옴, chibi 비례에서 두드러진 silhouette element.
- **녹포**: 녹색 (#2D6B4A) 전포 — historical exception. iron under-armor.

### Gemini prompt — copy-paste ready

```
A chibi grid sprite of a Three Kingdoms-era Chinese heavy cavalry general, painted in STRICTLY ink-wash sumi-e brush style applied to chibi proportions. For tactical RPG combat grid (LOD 1, 64×64 px display, 128×128 native).

CRITICAL CHIBI PROPORTIONS: 3-head ratio. Head ~33%.

CRITICAL SILHOUETTE — WIDEST IN FRAME: Guan Yu's body MUST appear visibly broader and heavier than a normal chibi figure. Shoulder width is approximately 1.4x typical chibi shoulder width — shoulders extend OUT visibly beyond a normal chibi outline. Heavyset stance, thick torso, broad chest. He should look CLEARLY larger and bulkier than typical 3-head chibi proportions would suggest — this heavy-cavalry mass is the key identifier. Picture a sumo-wrestler-broad body on chibi-height proportions. NOT a normal-width chibi.

CRITICAL VISUAL STYLE — SUMI-E BRUSH QUALITY (HIGHEST PRIORITY): Outlines MUST be hand-painted ink-wash brush strokes with VISIBLE thickness variation — thicker at silhouette edges (1.5-2x), thinner inside, with brush-bleed and dry-drag texture. Green robe folds show visible ink-wash bleed and graduated tone. This is traditional East Asian ink painting (墨绘 / 水墨) in chibi form. STRICTLY NOT vector-clean cartoon, NOT CalArts/Disney cartoon, NOT uniform digital ink. The brush must look hand-painted.

CRITICAL CHARACTER FACE: Guan Yu (關羽, 雲長), heavy cavalry general, immovable. In chibi: two small black dots for eyes, single short mouth line, NO nose detail. Skin: warm sun-tanned olive — same tone as other heroes. NOT red-faced (no historical "red face" stereotype). NO blush, NO pink/red cheek dots, NO moe softening.

CRITICAL WEAPON COUNT — EXACTLY ONE WEAPON ITEM IN ENTIRE FRAME: One single polearm (Green Dragon Crescent Blade — 青龍偃月刀) held vertically alongside body in his right hand. Polearm extends UP past the head silhouette — crescent blade visible at top-right of frame as silhouette protrusion. Polearm shaft thicker than typical spear (heavy weapon read). ABSOLUTELY NO secondary weapon, NO sword on the hip, NO dagger, NO additional spear or polearm. The figure carries EXACTLY ONE weapon total. Left hand empty.

CRITICAL BEARD: Long black beard extending down to mid-chest — major asymmetric silhouette element. In chibi proportions, beard occupies significant lower-face area, distinguishing him at a glance.

POSE: Stable centered stance, weight on both feet.

Outfit: Green (#2D6B4A) battle robe (historical exception — Shu green, deeper than naval green), iron under-armor showing at shoulders + chest. Practical combat gear, NO ceremonial decoration.

Background: TRANSPARENT alpha PNG.

NEGATIVE / ANTI-REFERENCE: NO anime moe, NO red face, NO Dynasty Warriors muscle-baroque, NO cell-shading gradients, NO glow, NO bright saturation, NO gold accents. NO clean vector cartoon, NO uniform-thickness outlines, NO CalArts/Disney style. NO additional weapons beyond the single polearm. NO narrow / normal-width chibi body (must be visibly broader).

Composition: chibi figure centered with polearm extending vertically above head. ~70% canvas vertically (taller than other heroes due to polearm).

Aspect ratio: 1:1, 128×128 native.
```

### Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/sprites/grid/sprite_shu_guan_yu_idle.png` |
| Dimensions | 128×128 native |
| Format | PNG with alpha |
| Frame | 1 of 1 (idle pose) |

### Acceptance for AI generation
- ✅ 3-head chibi + **어깨 폭 1.4× — heavy cavalry mass 가 명확히 시각화** (S71 attestation: 1차 regen 에서 normal-width 로 약화 — 강화)
- ✅ 얼굴 단순화 (눈 점 2 + 입 1선) + NO 핑크/빨간 볼터치 / blush / moe softening
- ✅ **EXACTLY ONE weapon — 청룡언월도 polearm 하나만**. 추가 칼/단검 절대 금지
- ✅ 청룡언월도 polearm 머리 위로 수직 돌출
- ✅ 긴 검은 수염 chest 까지 (silhouette 핵심)
- ✅ 녹색 (#2D6B4A) 전포 — historical Shu green exception
- ✅ NOT red-faced
- ✅ Sumi-e variable brush 외곽선 + 잉크 wash bleed visible (특히 녹포 — vector-clean / CalArts 금지)
- ✅ 투명 배경 (alpha PNG, paper-cream fill 금지) + 평면 색


## Breath frame (Phase 2) — 신규 2026-05-21

art-bible §5.7 Phase 2 — idle breath 2-frame ping-pong (1.6s cycle). 관우의 호흡
은 **heavy cavalry 결** — chest 명확 expand + 어깨 명확 raise. 1.4× 어깨 폭 +
긴 수염 silhouette 보존 critical (드라마틱 호흡으로 어깨 폭이 더 두드러져 보임).

### Breath modification prompt — image-to-image (idle PNG 입력 시)

```
Apply BREATH MODIFICATIONS to the input idle PNG of Guan Yu, producing the
second frame of his 2-frame breath cycle.

VISIBLE CHANGES (clearly mid-inhale, heavy cavalry feel):
- Chest puffed outward ~10% wider than idle (clear, heavy breath)
- Shoulders raised noticeably ~5-6% higher
- Torso slightly elongated ~3% vertically
- Heavy-cavalry breath presence — the broad silhouette emphasized further

EVERYTHING ELSE 100% IDENTICAL TO INPUT IDLE:
- Same WIDEST silhouette — shoulder ratio ~1.4× still preserved
- Same face (eye dots, mouth line), NOT red-faced
- Same long black beard down to mid-chest (silhouette key)
- Same 청룡언월도 polearm held vertically in right hand, crescent blade visible
  at top-right, polearm position unchanged (not swinging, not lowering)
- Same green (#2D6B4A) Shu battle robe with iron under-armor
- Same sumi-e ink-wash brush quality, especially the green robe folds
- Same TRANSPARENT alpha PNG background (NOT black fill, NOT decorative frame)
- Same image dimensions

Output filename: sprite_shu_guan_yu_breath.png
```

### Text-to-image fallback prompt (idle PNG 없이)

위 idle prompt 를 base + 위 VISIBLE CHANGES 블록을 `POSE` 섹션 앞에 삽입.
어깨 1.4× ratio + 긴 수염 silhouette 보존 critical 명시.

### Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/sprites/grid/sprite_shu_guan_yu_breath.png` |
| Frame | 2 of 2 (Phase 2 ping-pong with idle) |
| Format | PNG with alpha (TRANSPARENT background) |
| Dimensions | idle 와 동일 |

### Acceptance for breath frame
- ✅ Side-by-side with idle: heavy breath delta 명확
- ✅ 어깨 1.4× ratio 보존 (호흡으로 어깨 폭이 더 두드러져 보이는 게 의도)
- ✅ 긴 검은 수염 silhouette 보존 + 청룡언월도 vertical 위치 동일
- ✅ 녹포 (#2D6B4A) 색 + iron under-armor 동일
- ✅ TRANSPARENT alpha background
- ✅ Sumi-e brush 유지, 녹포 잉크 wash 동일
- ✅ 1 weapon (청룡언월도) 만 + NOT red-faced + NO blush


## Walk frames (Phase 3) — 신규 2026-05-21

art-bible §5.7 Phase 3 — walk animation 2-frame ping-pong. 관우 walk: heavy
cavalry 결의 무거운 step (slow swing 인상). 1.4× 어깨 폭 + 청룡언월도
vertical + 긴 수염 silhouette 모두 보존, 다리만 alternation.

### Walk frame 0 prompt — left step (image-to-image)

```
Apply WALK STEP MODIFICATIONS to the input idle PNG of Guan Yu, producing
walk frame 0 (LEFT foot forward).

VISIBLE CHANGES (heavy cavalry step, slow swing feel):
- Left leg stepped forward visibly (~12-14% of figure height advance)
- Right leg trailing slightly back, weight distributed deliberately
- Body very subtly leaned forward ~2-4° (heavy momentum, not light step)
- Green robe naturally falls with the step

EVERYTHING ELSE 100% IDENTICAL TO INPUT IDLE:
- Same WIDEST silhouette (어깨 1.4× ratio 보존)
- Same face (eye dots, mouth line), NOT red-faced
- Same long black beard down to mid-chest (silhouette key)
- Same 청룡언월도 polearm vertical in right hand — POLEARM POSITION UNCHANGED
  (no swing, no lean, blade tip at top-right same spot)
- Same green (#2D6B4A) robe + iron under-armor
- Same sumi-e brush + green robe ink wash
- Same TRANSPARENT alpha background, same dimensions

Output filename: sprite_shu_guan_yu_walk_0.png
```

### Walk frame 1 prompt — right step (image-to-image)

```
Apply WALK STEP MODIFICATIONS to the input idle PNG, producing walk frame 1
— MIRROR of walk frame 0 (RIGHT foot forward).

Same identity preservation list (1.4× shoulder ratio, long beard, polearm
vertical, green robe). Same heavy step feel.

Output filename: sprite_shu_guan_yu_walk_1.png
```

### Asset target

| Field | Value |
|---|---|
| Filenames | `sprite_shu_guan_yu_walk_0.png` / `sprite_shu_guan_yu_walk_1.png` |
| Frame count | 2 (Phase 3 walk ping-pong) |
| Format | PNG with alpha (TRANSPARENT background) |
| Dimensions | idle 와 동일 |

### Acceptance for walk frames
- ✅ Side-by-side: leg alternation 명확, heavy step 인상
- ✅ 어깨 1.4× ratio 보존 + 긴 수염 silhouette 동일
- ✅ 청룡언월도 polearm 위치 정확히 동일 (swing 금지)
- ✅ 녹포 색 동일 + NOT red-faced
- ✅ TRANSPARENT alpha + same dimensions
