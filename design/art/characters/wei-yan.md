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

## Gemini prompt — copy-paste ready

> Gemini Image (Imagen 4 계열) 은 자연어 prompt + 자연어 exclusion 으로 동작. AI Studio / Gemini 앱에서 사용 시 aspect ratio 는 드롭다운 OR 본문에 "1:1 square format" 명시.

```
A portrait illustration of Wei Yan (魏延, 文长), a Three Kingdoms-era Chinese general, painted in traditional sumi-e ink wash style.

He stands in an asymmetric mercenary posture, three-quarter view facing slightly right, with his right hand resting on the hilt of his sheathed sword at his hip — the weapon is not drawn, his arm is not raised. His gaze is directed downward and to the side, calculating and ambivalent. His face shows weathered, mature, sharp narrow features with subtle asymmetry — not idealized, not youthful, not anime-styled.

He wears practical iron-grey lamellar armor with ochre-earth cloth trim and leather binding straps. There is no ceremonial decoration, no Shu-blue accent colors, no gold filigree, no ornate surface pattern.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. The outlines are variable-weight ink — thicker at the silhouette edge, thinner for interior detail, with visible ink bleeds where the ink meets the paper at the outline edges. The underpainting is monochrome wash with limited muted color: ochre earth tone (hex #C8874A) for the cloth trim, iron blue-grey (hex #5C7A8A) for the armor base, ink-black (hex #1C1A17) for deep shadows and outlines, paper-white (hex #F2E8D4) with visible paper grain for the ground.

The lighting is cold blue-grey daylight, evoking the strategic tension of Jing Province fog. There is generous negative space behind the figure on a neutral paper ground. The composition is centered, with the figure rendered at 8-heads-tall proportion. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects, bright saturated colors, or modern Western fantasy elements. Do not use Dynasty Warriors video-game aesthetics with muscle-baroque armor or glowing weapon trails. Do not include red or gold accent colors. Do not depict the sword being drawn, raised, or held in a strike pose. Do not show a young, idealized, or anime-styled face.
```

**Gemini 튜닝 메모**:
- 너무 깨끗 / 디지털 일러스트 느낌 → 본문에 추가: `rough textured brushwork is essential, with irregular ink bleed and visible paper grain throughout the entire image`
- 자세 오류 (검 뽑음 / 팔 듦) → exclusion 강화: `The sword remains entirely sheathed in its scabbard. His hand merely rests on the hilt — the blade is not visible at all.`
- 얼굴이 anime / 너무 어림 → `The face must have mature, realistic, weathered proportions. This is a hardened soldier, not a young hero — visible signs of age and combat experience on the face.`
- 색이 너무 다양 → `Restrict the color palette strictly to the four named hex values only. The image should read as primarily monochromatic ink wash with very restrained color accents — no other colors should appear.`
- 배경이 sumi-e 안 됨 → `The background is paper-white with visible paper grain texture, in the tradition of traditional Chinese ink painting — NOT a digital gradient, NOT a solid color fill.`

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
