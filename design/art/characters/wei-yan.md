# 위연 (Wei Yan) — Portrait Asset Spec

> **Status**: B2.1-a — spec authored, pending external AI gen (B2.1-b)
> **Hero ID**: `shu_009_wei_yan` · **Portrait ID**: `portrait_shu_wei_yan`
> **Cascade join**: ch13 장사성 hidden destiny (`WIN_changsha_wei_yan_defects`) → ch14 slot 15
> **Sources**: `art-bible-v1-distilled.md` §1 palette + §2 line + §4 위연 anatomy seed; `heroes.json` `shu_009_wei_yan`
> **Date**: 2026-05-19

---

## Canonical anchors (from `heroes.json`)

| Field | Value | Visual implication |
|---|---|---|
| name_ko / name_zh / 자 | 위연 / 魏延 / 文长 (Wenchang) | 자 "文长" — late-defector ambivalence; not pure warrior |
| Faction | Shu (0) | But cloth trim is ochre — armour base must stay iron-grey (Wei-grey tones), reads as "joined Shu late" |
| Class | default_class=1 (assault) | Practical combat posture, not commander |
| Stat profile | Might 88 · Intellect 65 · Command 70 · Agility 75 | Might-leading but not raw force — calculation in the gaze |
| Innate skill | `skill_rebel_charge` | "Blade waiting for the moment" — posture must read as restraint, NOT mid-strike |
| Join condition | `story_ch13_wei_yan_defection` (hidden destiny only) | Wei Yan only joins when player executes Changsha hidden path — character is canonically a defector |
| Bond | `bond_late_defector_loyalty` with Liu Bei | Not Peach Garden tier — quieter, ambivalent loyalty |

---

## Portrait brief (per distilled §4 + production interpretation)

Asymmetric mercenary posture, **standing 3/4 view**, right hand resting on sword hilt at hip (NOT raised, NOT mid-draw — restraint is the whole point), calculating **downward** gaze, slight head-tilt right. Practical iron-grey lamellar armour with ochre-earth cloth trim and leather binding — **NO ceremonial decoration, NO Shu blue, NO gold filigree**. Weathered jaw, sharp narrow facial features, faint asymmetry. The silhouette must read "blade waiting for the right moment" — NOT loyal soldier, NOT charging warrior. Iron-grey + ochre palette base; the ochre cloth is the only colour-warmth, reinforcing Shu-but-not-Shu ambivalence.

**Why these anchors**: 위연 is the only Shu hero whose join requires the player to pursue the hidden destiny branch at Changsha (ch13). His baseline portrait carries that decision's visual weight — every other Shu hero joins by canonical history; 위연 joins by player choice. The portrait must function as visual punctuation of "destiny-rewritten character" without using reserved 주홍/금색 (those are saved for the moments themselves).

---

## Midjourney prompt — copy-paste ready

```
Three Kingdoms general Wei Yan, asymmetric mercenary stance 3/4 view, right hand resting on sword hilt at hip not raised, calculating downward gaze head tilted slightly right, weathered ambivalent expression sharp narrow facial features, practical iron-grey lamellar armor with ochre-earth cloth trim leather binding straps, NO ceremonial decoration NO Shu blue NO gold filigree, sumi-e ink wash painting illustration, Romance of Three Kingdoms historical style, variable-weight ink outlines thicker at silhouette edge, ink bleeds at outline edges, late-Ming woodblock print linework, Yokoyama Mitsuteru historical manga influence, monochrome wash underpainting limited muted colour palette, ochre earth #C8874A and iron blue-grey #5C7A8A on paper-white #F2E8D4 ground, ink-black #1C1A17 deep shadows and outlines, blue-grey cold daylight Phase-B Jing Province fog atmosphere, generous negative space behind figure centered composition, 8-heads-tall proportion, historical Three Kingdoms costume accuracy --ar 1:1 --style raw --s 200 --v 6 --no anime, photoreal, cel shading, gradient glow, bright saturation, dynasty warriors muscle armor, gold filigree, vermillion red accents, modern western fantasy, glowing weapon trail
```

**MJ 튜닝 메모** (1차 batch 가 어긋난 방향별):
- 너무 깨끗 / 애니풍 → `--s 100` 으로 낮추고 `rough brush texture, paper grain visible` 추가
- 너무 지저분 / 흐림 → `--s 350` 으로 올리고 `ink bleeds` 제거
- 자세 오류 (팔 들거나 검 뽑음) → `hand resting on sword hilt at hip, sword sheathed, NOT drawing` 강화
- 색이 너무 많음 → 메인에 `desaturated muted palette` 추가
- 얼굴이 anime → `mature weathered face, NOT young, NOT idealized` 추가

---

## Gemini prompt — copy-paste ready (v3, reframe 학습 적용)

> v1 / v2 시행착오를 통해 학습한 **Gemini reframe 원칙** 적용:
> - "absence 명시" (NOT drawn, NO blade visible) → **STANCE + visible portion STRUCTURE 명시** ("wooden hilt grip and scabbard fitting visible, weapon held inside")
> - prop STATE 의 부정형 강조 → prop visibility 의 inverse 강화 위험. v3 는 "blade" / "sword" 단어 빈도 최소화 + 시각 anchor 를 hilt + scabbard 의 visible portion 으로 이동
> - 양손 무기 issue 차단: "NO second weapon in his other hand — his left hand rests relaxed at his side" 명시
> - 시선: "lower-left of frame" 좌표 + "looks at the ground in front of his feet" 구체 지시

```
A portrait illustration of a Three Kingdoms-era Chinese general, painted in traditional sumi-e ink wash style. This is the first of a 5-portrait series — establish the style baseline.

CRITICAL CHARACTER FACE: The character is Wei Yan (魏延, 文长), a hardened mercenary general in his mid-40s. His face is mature, weathered, sun-bronzed, and hardened by years of soldiering — visible lines at the eyes, lined forehead, weathered jaw. Sharp narrow features with subtle asymmetry. He looks like a hardened veteran soldier who has survived many campaigns. Build is medium — lean and practical, NOT slender, NOT heavy. He carries the visible tiredness and ambivalence of an opportunist who joins last among the generals.

CRITICAL STANCE AND HANDS: He stands in an asymmetric mercenary three-quarter view facing slightly right. Body weight casual — one hip slightly cocked, weight resting on one leg. His right hand rests gently on the bound wooden grip of a hilt protruding from a scabbard at his left hip — only the round wooden pommel and the bound hilt grip are visible above the scabbard's metal fitting; the rest of the weapon stays enclosed inside the black lacquered scabbard. The visual silhouette shows: wooden hilt grip (small protrusion above hip line) + scabbard length hanging down beneath. NO long blade extends from his hand. NO drawn weapon. NO second weapon in his other hand — his left hand rests relaxed at his side. The silhouette read is "a blade waiting inside its sheath" — restraint, not action.

CRITICAL GAZE DIRECTION: His eyes are directed downward toward the ground in front of his feet, lower-left area of the frame. He is NOT looking at the viewer. He is NOT looking to the side. He is calculating something while staring at the ground — the inward gaze of a man weighing options.

He wears practical iron blue-grey lamellar armor with ochre-earth cloth trim and leather binding straps at the joints. The armor is functional combat gear, NOT ceremonial. No gold filigree, no ornate decoration, no Shu-blue accent colors.

Hair: jet-black, bound in a simple tight topknot, no ornament.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. Variable-weight ink outlines, thicker at the silhouette edge, thinner for interior detail, with visible ink bleeds. Monochrome wash underpainting with restrained muted color: iron blue-grey (#5C7A8A) for the armor, ochre earth (#C8874A) for the cloth trim, ink-black (#1C1A17) for the scabbard and shadows, paper-white (#F2E8D4) with visible paper grain for the ground.

Lighting: cool blue-grey daylight — strategic tension atmosphere. Generous negative space behind the figure. Composition centered, figure rendered at 8-heads-tall lean-build proportion. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects, bright saturated colors, or modern Western fantasy elements. Do not use Dynasty Warriors aesthetics with muscle-baroque armor or glowing weapon trails. Do not include red or gold accent colors. Do not show a young, idealized, or handsome face — only mature weathered veteran.
```

**Gemini 튜닝 메모** (v3 단계):
- 두 손에 다른 무기 / 양손 무기 → "NO second weapon in other hand — left hand relaxed at side" 강화 inline
- 검신이 보임 → "weapon stays enclosed inside scabbard, only wooden pommel and hilt grip visible above fitting" 같은 visible portion STRUCTURE 묘사로 재구성. "blade" / "drawn" 단어 빈도 최소화.
- 시선이 정면 / 옆 → "downward toward ground in front of his feet, lower-left of frame" 좌표 명시. "He is NOT looking at viewer" 직접 부정 보조.
- 얼굴이 anime / 어림 → "hardened veteran in mid-40s" 구체 나이 + "visible lines at eyes, lined forehead" 부위별 묘사.
- 화풍 drift → "first of a 5-portrait series — establish the style baseline" series anchor 도입.

---

## Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/portraits/portrait_shu_wei_yan.png` |
| Dimensions | 1024×1024 |
| Format | PNG (no transparency — paper-white `#F2E8D4` ground is design intent) |
| Variants in this spec | 1 (canonical baseline) — Phase-C / destiny-branch / death variants are future |
| Convention | `assets/art/portraits/{portrait_id}.png` — established by this asset; future heroes follow |

---

## Integration plan (B2.1-c — next session)

1. Create `assets/art/portraits/` directory + place delivered PNG
2. Add `HeroDatabase.get_portrait_texture(hero_id)` helper — returns `Texture2D` or `null`
3. Primary surface: **`signature_archive_popup.gd`** 위연 카드 — currently text-only; add TextureRect above name. Fallback to current text-only display when texture is null (graceful for other 4 heroes still pending)
4. Verify: 헤드리스 부팅 깨끗 + popup 에서 위연 카드만 portrait 표시, 나머지 4 카드는 기존 동일
5. Acceptance: portrait 가 distilled bible §1 palette 안에서 읽힘 (no reserved 주홍/금색 침투) · §4 anatomy 요소 visible (hand-on-hilt, downward gaze, iron-grey + ochre, NOT loyal-soldier silhouette) · NOT anime / NOT photoreal / NOT Dynasty Warriors. AI 출력 그대로 사용 — manual paint 금지 (정책)

---

## Acceptance for AI generation (B2.1-b — user side)

Ship-able output must satisfy (single AND gate):
- ✅ Hand position visible at sword hilt, weapon sheathed (NOT drawn / NOT raised)
- ✅ Downward gaze (NOT looking at camera / NOT heroic upward)
- ✅ Iron-grey + ochre-earth palette only (NO blue Shu accents, NO red, NO gold, NO bright saturation)
- ✅ Sumi-e ink-wash visual language (NOT anime cel-shading, NOT photoreal, NOT gradient-glow)
- ✅ Negative space around figure (figure NOT filling entire 1024×1024)

If any miss → regen with tuning notes above. No manual touch-up (per AI-output-direct policy).

---

## Grid sprite (chibi) — Q5 Phase 1 (신규 2026-05-20)

art-bible §5.7 정합. 위 portrait (8-head sumi-e) 와 별도 자산 — LOD 1 grid 표시용 chibi reframe.

### Per-hero chibi 요소 (위연 한정)

- **신원 일관성**: portrait 의 hardened mercenary 정체성 유지 — narrow features, weathered face, mid-40s. 단 chibi 단순화 적용 (눈 = 검은 점 2개, 입 = 단일 선, 주름 생략).
- **무기 표현**: 칼이 scabbard 안 — chibi 비례에 맞춘 작은 wooden hilt + 검집 visible at left hip. 칼 자체 추출 안 함 ("blade waiting inside its sheath" 정체성 유지).
- **자세**: 약간 옆을 본 asymmetric 자세. 한쪽 hip cocked. 시선은 약간 아래 (downward 명시 안 해도 chibi 비례라 자연스러움).
- **머리**: jet-black topknot. chibi 비례라 머리 영역 33% 차지.
- **갑옷**: iron blue-grey lamellar + ochre cloth trim. chibi 단순화 — 자수/장식 생략, 색 블록으로만.

### Gemini prompt — copy-paste ready

```
A chibi grid sprite of a Three Kingdoms-era Chinese general, painted in STRICTLY ink-wash sumi-e brush style applied to chibi proportions. For a tactical RPG's combat grid (LOD 1, 64×64 px display, 128×128 native).

CRITICAL CHIBI PROPORTIONS: 3-head ratio — head : torso : legs = 1 : 1 : 1. Head ~33% of total height. Shoulder width ~1.2x head width.

CRITICAL VISUAL STYLE — SUMI-E BRUSH QUALITY (HIGHEST PRIORITY): Outlines MUST be hand-painted ink-wash brush strokes with VISIBLE thickness variation — thicker at silhouette edges (1.5-2x), thinner inside, with occasional brush-bleed and dry-drag texture. Robe folds and shaded areas show visible ink-wash bleed. This is traditional East Asian ink painting (墨绘 / 水墨) in chibi form. STRICTLY NOT vector-clean cartoon, NOT CalArts/Disney cartoon, NOT uniform digital ink lines. The brush quality must look hand-painted, not vector-traced.

CRITICAL CHARACTER FACE: Wei Yan (魏延, 文长), hardened mercenary. In chibi: two small black dots for eyes (NO large anime pupils), single short mouth line, NO nose detail. Identity comes from stance and weapon, NOT face. Skin: sun-bronzed warm beige. NO blush, NO pink/red cheek dots, NO moe softening of any kind.

CRITICAL WEAPON COUNT — EXACTLY ONE WEAPON ITEM IN ENTIRE FRAME: One single sword sheathed in a scabbard at his LEFT hip. Right hand rests on the wooden hilt protruding from the scabbard. Only the wooden pommel and hilt grip visible above the scabbard's metal fitting — blade stays fully enclosed in the black lacquered scabbard. ABSOLUTELY NO drawn blade, NO second sword, NO additional dagger or knife, NO weapon on the back, the right hip, the floor, or in the left hand. The figure carries EXACTLY ONE weapon item total. Left hand empty at his side.

STANCE: Asymmetric mercenary three-quarter view facing slightly right. Body weight casual — one hip slightly cocked. Silhouette read: "blade waiting inside sheath" — restraint preserved despite chibi.

Hair: jet-black, simple tight topknot, no ornament.

Outfit: Practical iron blue-grey (#5C7A8A) lamellar armor with ochre-earth (#C8874A) cloth trim — chibi-simplified, NO decorative patterns, just flat color blocks separated by hand-painted ink-brush outlines. Black lacquered scabbard.

Background: TRANSPARENT alpha PNG. The figure sits on transparent alpha — no paper texture, no fill, no border.

NEGATIVE / ANTI-REFERENCE: NO photorealism. NO anime moe (no large eyes, no shoujo features, NO pink/red cheek blush dots). NO cell-shading gradients. NO glow effects. NO Dynasty Warriors muscle-baroque. NO bright saturation. NO red or gold accents (reserved for legendary VFX). NO clean vector cartoon, NO uniform-thickness outlines, NO CalArts/Disney style. NO additional weapons beyond the single sheathed sword.

Composition: chibi figure centered, ~60% canvas vertically. Generous negative space.

Aspect ratio: 1:1, 128×128 native (intended display 64×64 after 2× supersample downscale).
```

### Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/sprites/grid/sprite_shu_wei_yan_idle.png` |
| Dimensions | 128×128 native (display 64×64 after 2× supersample) |
| Format | PNG with alpha (transparent background — chapter_visuals 가 polygon tint 배경 제공) |
| Frame | 1 of 1 (Phase 1 idle pose only — breath/walk/attack post-MVP) |
| Convention | `assets/art/sprites/grid/sprite_{hero_id}_idle.png` — Phase 2-4 추가 시 `_breath_0.png` / `_walk_0..3.png` / `_attack_0..2.png` |

### Acceptance for AI generation

Ship-able output must satisfy (single AND gate):
- ✅ 3-head chibi 비례 (사실적 8-head 비례 금지)
- ✅ 얼굴 단순화 (눈 = 점 2개, 입 = 1선) — anime 큰 눈 금지
- ✅ NO 핑크/빨간 볼터치 / blush / moe softening (S71 attestation: 1차 regen 에서 발견)
- ✅ Iron-grey + ochre-earth 팔레트 (장식/자수 생략)
- ✅ **EXACTLY ONE weapon — 왼쪽 hip sheathed sword 만**. 두 번째 칼/단검/추가 무기 절대 금지 (S71 attestation: 1차 regen 위연 에서 추가 칼 발견)
- ✅ Sumi-e variable brush 외곽선 + 잉크 wash bleed visible — vector-clean / CalArts / 균일 두께 line 모두 금지 (S71 attestation: 1차 regen 5장 중 3장 miss)
- ✅ 투명 배경 (alpha PNG, paper-cream fill 도 금지)
- ✅ 평면 색 (gradient / cell-shading 금지)
- ✅ 주홍/금색 침투 0

미달 시 regen. portrait 와 동일 정책 (manual touch-up 금지).
