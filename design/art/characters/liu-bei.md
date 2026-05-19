# 유비 (Liu Bei) — Portrait Asset Spec

> **Status**: B2.5-a — spec authored, pending external AI gen (B2.5-b)
> **Hero ID**: `shu_001_liu_bei` · **Portrait ID**: `portrait_shu_liu_bei`
> **Cascade signature**: ch22 이릉 hidden destiny (`WIN_yiling_liu_bei_survives`) — 유비는 ch1 부터 party. cascade 는 historical 이릉 화공-grief 회피. ch25 영걸전 legendary finale 의 center figure
> **Sources**: `art-bible-v1-distilled.md` §1 palette + §2 line + §4 유비 anatomy seed; `heroes.json` `shu_001_liu_bei`; B2.1 위연 v3 + B2.2 방통 v2s + B2.3 관우 + B2.4 장비 pipeline + reframe 학습 적용 (commits `4e5ceae`, `f6e994e`, `b3610ef`, `5431283`)
> **Date**: 2026-05-19

> **NOTE**: 이 파일은 sprint-11 의 liu-bei.md (170-line 스텁 — sections 1-3 silhouette/costume/role-anchor, §4-N deferred) 와 다른 production spec. 기존 stub 은 historical sprint-mode 산물로 보존하지 않음 (overwrite). forward-going SoT 는 이 production spec.

---

## Canonical anchors (from `heroes.json`)

| Field | Value | Visual implication |
|---|---|---|
| name_ko / name_zh / 자 | 유비 / 刘备 / 玄德 (Xuande, "profound virtue") | 자 "玄德" — virtue-leader archetype |
| Faction | Shu (0) — **founder** | Shu 정체성 가장 명확. 묵 base + 황토 trim 표준 |
| Class | default_class=4 (**COMMANDER**) | 5장 중 유일한 commander. 무장 silhouette 아님 — 지휘 posture |
| Stat profile | Might 70 · Intellect 75 · **Command 90** (정점) · Agility 65 | balanced stats, command 만 명확히 leading — 무력보다 지휘 |
| Innate skills | `skill_inspire` (rally buff) + `skill_benevolence` (defensive team support) | 두 skill 모두 rally / 인의 → open-arm rally posture 와 직접 연결 |
| Join chapter | 1 (canonical, project's first hero) | cascade signature 는 ch22 이릉 survival (Phase D 의 grief-laden finale). portrait 는 character canonical state |
| Bond | `bond_oath_peach_garden` (SWORN_BROTHER 관우 + 장비, 둘 다 대칭) | Peach Garden 삼각 composition 의 **center**. 관우 (right) + 장비 (left) 와 함께 놓였을 때 framing 역할 |

---

## Portrait brief (per distilled §4 + production interpretation)

**Balanced open-arm rally posture** — 5장 중 유일하게 active gesture 자세. 약간 forward facing, 양발 어깨 너비 planted (장비 forward-leaning 도 아니고 관우 fully planted square 도 아닌 중간 balanced). **right arm raised forward with open palm in rally / call-to-arms gesture** — 또는 가슴 높이에서 손바닥 위로 향한 inviting/inspiring 자세. left hand 는 hip 의 sword pommel 에 가볍게 — relaxed reach.

**双股劍 (paired twin short swords)** — right hip 에 **두 자루 scabbard 나란히**. 5장 중 유일하게 **paired short weapons** + **vertical protrusion 없음**. 다른 4장은 모두 single prop (검 hilt / 부채 / 폴암 / 사모) 이고 관우/장비는 vertical 머리 위 protrusion 인데, 유비는 hip-level twin scabbard 의 horizontal asymmetric 만. silhouette 의 weight 가 weapon 이 아닌 자세에 있음.

**Prominent ears** — Three Kingdoms canonical visual marker (大耳, "big ears" = 귀인 의 표상). 머리 양옆에 약간 커 보이는 ears visible, naturalistic proportion (cartoon-ish 과장 금지 — 자연스러운 약간의 emphasis). 5장 중 유일한 character marker.

**Full-trim beard** — **잘 정돈된, 가지런한 mid-chest 길이 수염**. 관우의 long flowing 보다 짧고 더 trimmed, 장비의 wild curling 과 명확히 정반대. jet-black, 깔끔한 brushstroke, 수염 끝이 chest 에 닿거나 조금 아래. virtue-leader 의 self-discipline 시각 표현.

**시선: direct forward, calm warm**. 5장 중 **유일하게 looks AT (정면 응시) — 위연 downward / 방통 calm-forward-slight-downward / 관우 stoic-forward / 장비 intense-forward-but-glaring 와 다른 direct calm warm engagement**. virtue-leader 의 "leader-among-equals" — 위 가 아닌 사람-눈높이 응시.

**얼굴**: mature middle-aged, weathered but warm and composed. 위엄 있지만 군림하지 않는. 시리즈 통일 skin tone (warm sun-tanned olive). 표정: virtue-warm, slight smile 가능하나 over-soft 회피.

**Build**: **medium balanced** — 5장 중 유일하게 heavy 도 lean 도 아닌 중간. 관우/장비 의 heavy build 와 위연/방통 의 medium 사이의 average warrior-commander 비율.

**의복**: **묵 base robe + 황토 trim** — Shu 표준 hex 정확 (#1C1A17 robe + #C8874A trim at cuff + collar + 가운 하단 panel). 갑옷은 robe 안에 lamellar 보이지 않음 — virtue-king 은 갑옷보다 robe 가 dominant (commander, not 전투원). long cloak 후방으로 자연스럽게 흐름 — 약간의 wind-caught feel (NOT 화려한 flapping).

머리: jet-black bound topknot or simple bound style, scholar-warrior 의 중간. NO 황제 관모, NO 화려한 장식.

**Phase E lighting (baseline)**: "cool blue-grey dawn — strategic horizon, the moment before destiny is sealed or rewritten". Phase E baseline 은 cold blue-grey (legendary trigger 의 gold dawn 은 미래 variant). 5장 phase 통합: 위연 B cold / 방통 C amber dusk / 관우 + 장비 D warm amber / **유비 E cool dawn** — 모두 다른 phase.

**Why these anchors**:
- 유비 = cascade 의 anchor figure. 다른 4 영걸 (위연 / 방통 / 관우 / 장비) 가 유비 의 silhouette 을 framing 하는 composition intent (distilled §4: "his silhouette is the one the other four frame")
- 5장 중 유일하게 weapon-free 자세 (rally posture) + paired horizontal weapon (vertical above-head protrusion 없음) → 유비 silhouette 이 viewers 의 안구가 마지막에 머무는 calm center 가 됨 (장비/관우 의 vertical 무기 가 viewers 안구를 끌어 다른 4 영걸 쪽으로 밀어내는데, 유비는 그 visual energy 의 종착점)
- ch25 legendary finale 의 center — 다른 4 영걸이 모두 cascade unlock 됐을 때 legendary cue 의 gold dawn 이 유비 portrait 에 떨어짐 (그건 future variant; baseline 은 cool dawn)
- Peach Garden Oath 삼각 (관우 right / 장비 left / 유비 center) 시각 composition 의 center anchor

---

## Midjourney prompt — copy-paste ready

```
Three Kingdoms commander Liu Bei, balanced standing rally posture front-facing 3/4 slight, right arm raised forward at chest height with open palm in inspiring call-to-arms gesture, left hand resting relaxed on the pommel of paired twin short swords at right hip (双股劍 two short scabbards side by side, horizontal hip-level protrusion only NO vertical above-head weapon), prominent slightly larger ears visible at the side of the head naturalistic proportion, full-trim neatly trimmed mid-chest jet-black beard well-groomed and disciplined NOT wild NOT bushy, direct calm warm forward gaze looking at viewer eye-level engagement, mature middle-aged weathered but warm composed face slight virtue-warm expression, weathered sun-tanned olive complexion same skin tone as previous four cascade portraits, jet-black bound topknot or simple bound hair NO imperial crown NO ornament, ink-black base robe (#1C1A17 dominant) with ochre-earth (#C8874A) trim at cuff collar and lower panel, long flowing cloak behind catching slight wind, medium balanced build (NOT heavy NOT lean — average warrior-commander proportion), sumi-e ink wash painting illustration, Romance of Three Kingdoms historical style, variable-weight ink outlines thicker at silhouette edge, ink bleeds at outline edges, late-Ming woodblock print linework, Yokoyama Mitsuteru historical manga influence, monochrome wash underpainting limited muted colour palette, ink-black dominant with ochre-earth trim accents on paper-white #F2E8D4 ground, cool blue-grey dawn Phase-E lighting strategic horizon, generous negative space behind figure centered composition, 8-heads-tall balanced proportion, historical Three Kingdoms costume accuracy --ar 1:1 --style raw --s 200 --v 6 --no anime, photoreal, cel shading, gradient glow, bright saturation, dynasty warriors muscle armor, gold filigree, vermillion red accents, modern western fantasy, glowing weapon trail, single sword, vertical above-head weapon, bushy wild beard, exaggerated cartoonish ears, imperial yellow robe
```

**MJ 튜닝 메모**:
- Single sword (paired 누락) → `paired twin scabbards at right hip side by side, two weapons visible NOT one, double pommel grip` 강화
- 수염 wild / bushy → `neatly trimmed well-groomed full beard, NOT wild, NOT bushy, NOT spreading sideways like Zhang Fei` 강화
- 시선 옆 / 아래 → `direct calm gaze toward the viewer, looking at the camera eye-to-eye, NOT looking down, NOT looking to the side` 강화
- 귀 cartoonish 과장 → `slightly larger ears NATURALISTIC proportion, visible but realistic, NOT cartoonish, NOT exaggerated` 강화
- 황제풍 robe / 황금색 → `humble ink-black scholar-warrior robe, ochre trim only, NO imperial yellow, NO gold, NO ceremonial decoration` 강화
- Build heavy / lean → `medium balanced average build, NOT heavy like Guan Yu, NOT lean like Wei Yan` 강화

---

## Gemini prompt — copy-paste ready (reframe 학습 적용)

> 위연 v3 + 방통 v2 + 관우 + 장비 (sample 1→4) 의 **검증된 reframe 원칙** 모두 적용:
> - "red face" 부정 → "warm sun-tanned olive" + "same skin tone as previous four portraits in this series" series anchor. "red" / "vermillion" 단어 0회
> - 무기 type 우선: "paired twin short scabbards side by side at right hip" + "NO vertical above-head weapon" 분명 + 4 prior portraits 비교
> - 수염 type 우선: "neatly trimmed well-groomed mid-chest beard" + 장비 안티-비교 + 관우 안티-비교 (장비 wild / 관우 long flowing 와 다른 third style)
> - 귀 prominent risk: type 명시 ("slightly larger naturalistic proportion") + 부정 보조 ("NOT cartoonish exaggerated")
> - 시선 direct: "direct calm gaze at viewer" + 4 prior portraits 안티-비교
> - 자세 rally posture: "right arm raised forward with open palm" 부위별 묘사
> - Series anchor 가장 강함: 4 prior portraits 모두 reference

```
A portrait illustration of a Three Kingdoms-era Chinese commander, painted in traditional sumi-e ink wash style. This is the FINAL portrait of a 5-portrait series — match the established visual style of the previous four portraits (Wei Yan: mid-40s mercenary with hilt-on-scabbard; Pang Tong: round-faced strategist with fan; Guan Yu: heavy stoic general with long flowing beard and polearm; Zhang Fei: wedge-shaped fierce general with wild beard and serpent spear).

CRITICAL CHARACTER FACE AND SKIN: The character's skin tone is naturalistic warm sun-tanned olive — the same warm tan, weathered, sun-bronzed complexion as the previous four portraits in this series. His face has mature, weathered features that read as warm and composed — a virtue-leader, not a hardened warrior. His expression is calm and warm with a faint virtue-warmth. His gaze is directed straight forward at the viewer — direct, calm, eye-level engagement. This is the ONLY portrait in the series where the character looks DIRECTLY at the viewer; the previous four all looked downward, sideways, or stared past the viewer.

CRITICAL CHARACTER EARS: He has slightly larger ears than typical, visible at the side of his head — this is a canonical Three Kingdoms recognition marker for this character. The ears are proportioned naturalistically — slightly emphasized but realistic. They should be NOTICEABLE in the portrait but NOT cartoonish, NOT exaggerated, NOT distorted.

CRITICAL CHARACTER BEARD: His beard is jet-black, neatly trimmed and well-groomed, reaching mid-chest length. The beard is full but disciplined — every hair in place, the silhouette is clean and tidy. This is the THIRD style of beard in the series, distinct from both the previous portraits: shorter and more controlled than Guan Yu's long flowing chest-beard, neat and groomed instead of Zhang Fei's wild curling sideways-spread beard. Think "well-kept virtuous leader" rather than "warrior."

CRITICAL POSTURE AND WEAPONS: He stands in a balanced open-arm rally posture — slightly facing 3/4 toward the viewer. His right arm is raised forward at chest height with an open upturned palm in an inspiring call-to-arms gesture. His left hand rests relaxed on the pommel of weapons at his right hip. The weapons are PAIRED TWIN SHORT SWORDS (双股劍 "twin swords") — TWO short scabbards side by side at the right hip, with two visible pommel grips above. Both swords stay inside their scabbards. This is the ONLY portrait in the series with paired weapons; the previous four all carried a single prop (single sword, single fan, single polearm, single spear). There is NO vertical above-head weapon protrusion in this portrait — the weapon presence is at hip level only, horizontal.

CRITICAL CHARACTER BUILD: His build is medium balanced — distinctly NOT heavy (unlike the previous two portraits Guan Yu and Zhang Fei), NOT lean (unlike Wei Yan), NOT round-scholar (unlike Pang Tong). Average warrior-commander proportion. The visual weight of the silhouette comes from the open-arm rally posture and the long cloak behind, not from heavy mass.

CHARACTER CONTEXT — Liu Bei (刘备, 玄德), founder of Shu, virtue-king. Sworn brother of Guan Yu (right position of Peach Garden trio) and Zhang Fei (left position). When this portrait is placed between the previous two, the three form the canonical Peach Garden Oath triangle composition with this character at the CENTER.

He wears an ink-black base robe (hex #1C1A17 dominant) with ochre-earth (#C8874A) trim at the cuffs, collar, and lower panel. A long cloak flows behind, catching slight wind in a brushstroke style. There is NO imperial yellow color, NO gold, NO ceremonial decoration — the robe is humble scholar-warrior, the rank reads through posture not ornament.

Hair bound in a simple jet-black topknot, no imperial crown, no ornament.

The artistic style is sumi-e ink wash painting in the tradition of late-Ming Chinese woodblock prints and Yokoyama Mitsuteru's historical manga linework. Variable-weight ink outlines, thicker at the silhouette edge, with visible ink bleeds. Monochrome wash underpainting with restrained muted color: ink-black (#1C1A17) dominant for the robe, ochre earth (#C8874A) for the trim, paper-white (#F2E8D4) with visible paper grain for the ground.

Lighting: cool blue-grey dawn — Phase E strategic horizon, the moment before destiny is sealed or rewritten. Generous negative space behind the figure. Composition centered, figure rendered at 8-heads-tall balanced proportion. Historical Three Kingdoms costume accuracy throughout.

Aspect ratio: 1:1 square, 1024×1024 pixels.

Do not produce anime, cel-shaded, or stylized cartoon art. Do not produce photorealistic illustration. Do not include gradient glow effects, bright saturated colors, or modern Western fantasy elements. Do not use Dynasty Warriors aesthetics. Do not use imperial yellow or gold accent colors.
```

**Gemini 튜닝 메모** (reframe 학습 sample 5 적용):
- Skin tone series anchor: 가장 강화된 형태 — "previous four portraits" reference, sample 1→4 누적
- Paired weapons: 일반 single sword prior 가 강함 → "PAIRED TWIN SHORT SWORDS at right hip, TWO scabbards side by side" + "ONLY portrait in the series with paired weapons" series uniqueness 명시 + 4 prior portraits 단일 prop 비교. inverse 위험 차단을 위해 본문에서 paired emphasis 3회 반복
- Beard 3번째 스타일: 관우 (long flowing) + 장비 (wild curling) 와 anti-comparison + "neat trimmed well-groomed mid-chest" type. 두 prior portraits 와의 명확한 contrast 가 anchor
- Direct gaze risk: "ONLY portrait in the series where character looks DIRECTLY at viewer; previous four looked downward / sideways / past viewer" series uniqueness 가 가장 강한 anchor
- Prominent ears: "noticeable but naturalistic, NOT cartoonish" — emphasize 와 realism 의 균형. 부정 보조 minimal
- Imperial yellow / gold robe risk: "founder of Shu, virtue-king" character context 가 imperial yellow / gold prior 트리거 — type prescription ("humble ink-black scholar-warrior robe") + "rank reads through posture not ornament" 명시
- Phase E lighting: "cool blue-grey dawn — strategic horizon" 단순 (legendary gold dawn 은 future variant, 메타-설명 제거)

---

## Asset target

| Field | Value |
|---|---|
| Filename | `assets/art/portraits/portrait_shu_liu_bei.png` |
| Dimensions | 1024×1024 |
| Format | PNG (no transparency — paper-white `#F2E8D4` ground is design intent) |
| Variants in this spec | 1 (canonical baseline) — **legendary finale variant** (cool blue-grey dawn lifting into gold per Phase E legendary trigger) 는 별도 future spec (ch25 cascade complete state 시각 결산용) |
| Convention | `assets/art/portraits/{portrait_id}.png` — established by B2.1 |

---

## Integration plan (B2.5-c — same session as B2.5-b drop-in)

pipeline B2.1 검증 완료, B2.2-4 일반화 증명 (3 zero-code drop-ins) — 자산 drop-in 만:

1. `assets/art/portraits/portrait_shu_liu_bei.png` 배치
2. `godot --headless --import --path .` (이미지 import)
3. 헤드리스 부팅 + 풀 테스트 (baseline 유지 확인)
4. windowed 검증: 메인메뉴 → 시그니처 아카이브 → **유비 카드** portrait 표시 → **5장 카드 모두 portrait 완성** 첫 확인

**코드 변경 0** — SIGNATURE_CATALOG 가 이미 `&"shu_001_liu_bei"` 포함. 5/5 portrait pipeline 완성.

---

## Acceptance for AI generation (B2.5-b — user side)

Ship-able output must satisfy (single AND gate):
- ✅ **Paired twin short swords (双股劍) at right hip** — two scabbards side by side, NO single sword, NO vertical above-head weapon
- ✅ **Direct calm forward gaze at viewer** — looks AT (5장 중 유일)
- ✅ **Rally posture**: right arm raised forward with open palm at chest height
- ✅ **Full-trim neatly-trimmed mid-chest beard** — NOT wild (장비) NOT long flowing (관우) — 시리즈 3번째 beard style
- ✅ **Prominent ears**: noticeable but naturalistic — NOT cartoonish exaggerated
- ✅ **Medium balanced build**: NOT heavy (관우/장비), NOT lean (위연), NOT round (방통)
- ✅ **Naturalistic skin tone** — warm sun-tanned olive, 4 prior portraits 와 series consistency
- ✅ **묵 base robe + 황토 trim** — NO imperial yellow, NO gold accent
- ✅ **Sumi-e 잉크-워시 visual language + 시리즈 5장 화풍 통일**
- ✅ Negative space 충분

If any miss → regen with tuning notes above. No manual touch-up (per AI-output-direct policy).

---

## Cross-reference: 5-hero cascade visual differentiation — **FINAL MATRIX (5/5)**

| Hero | Phase / lighting | Posture | Prop | Build / silhouette | Beard | Eyes / gaze | Marker |
|---|---|---|---|---|---|---|---|
| **위연** (B2.1 v3 ✅) | B blue-grey cold | Asymmetric mercenary 3/4 | Sword hilt at scabbard | Medium lean | — | inward downward lower-left | weathered sharp narrow |
| **방통** (B2.2 v2s ✅) | C amber dusk Sichuan | Centered static near-frontal | Paper-white folding fan | Medium-short scholar (round) | — | calm forward slight-downward | plain round mature |
| **관우** (B2.3 ✅) | D warm amber Fancheng | Massive immovable broad square 3/4 | 청룡언월도 curved crescent polearm (vertical, top) | **Heavy broad-square** | **Long flowing chest-length neat** | **Phoenix narrow** | weathered stern |
| **장비** (B2.4 ✅) | D warm amber 이릉 | Forward-leaning coiled 3/4 | 사모 straight serpent spear (vertical, top) | **Heavy wedge (taper)** | **Wild curling outward sideways** | **Leopard round wide-open** | dark armor contrast |
| **유비** (B2.5 — this) | **E cool blue-grey dawn** | **Balanced open-arm rally 3/4** | **双股劍 paired twin short swords (hip-level, horizontal)** | **Medium balanced** | **Neat trimmed disciplined mid-chest** | **Direct forward at viewer** | **prominent ears** |

**5장 통일성 finalize**:
- **Phase 5/5 unique**: B / C / D / D / E — Phase D 만 2장 (관우 + 장비, Peach Garden Oath pair) 외 모두 다른 phase
- **Posture 5/5 unique**: asymmetric mercenary / centered scholar / immovable square / forward-leaning wedge / balanced rally
- **Prop 5/5 unique**: sword hilt / fan / polearm crescent / spear serpent / paired swords
- **Build 5/5 unique**: lean medium / short scholar round / heavy square / heavy wedge / **medium balanced**
- **Beard 5 patterns**: 위연/방통 없음 → 관우 long flowing → 장비 wild → 유비 trimmed (3 distinct beard styles in 3 heavy/commander heroes)
- **Eyes/gaze 5 patterns**: inward downward / calm forward / phoenix narrow / leopard round / **direct at viewer** (5장 중 유비만 응시)

**Cascade composition intents 충족**:
- Peach Garden Oath 삼각 (장비 left / 유비 center / 관우 right): 셋 모두 다른 build (heavy-wedge / medium-balanced / heavy-square) + 다른 weapon orientation (vertical serpent / horizontal paired / vertical crescent) + 다른 beard (wild / trimmed / long flowing) + 다른 gaze (intense / direct / stoic) → silhouette 만으로 즉시 구분
- 5장 같이 봤을 때 visual energy 흐름: 위연 (calculating inward) → 방통 (controlled stillness) → 관우 (immovable righteousness) → 장비 (contained ferocity) → **유비 (warm rally direct engagement)** — 5장 viewing path 가 emotionally 의 narrative arc 완성
- Reserved 주홍/금색 0회 등장 (5장 모두) — distilled §1 의 "destiny-branch only" + "legendary only" reservation 정확 준수. legendary trigger 의 gold dawn 은 ch25 cascade-complete state 의 future variant 로 별도 (이 baseline 5장 모두 cool/warm but never reserved)

---

## Phase B 시각 정체성 milestone

B2.* 트랙 (AI 자산 production) **완성**. B1.1 (Palette token) + B2.1-5 (5 portrait pipeline + 자산) 으로 distilled bible §1, §2, §4 의 시각 정체성 spec 이 production 자산으로 처음 변환됨. 미완 항목:
- B1.2 시그니처 발동 / hidden / legendary VFX (godot-shader-specialist, JU_HONG `#C0392B` 첫 적용)
- B1.3 HUD / 메뉴 정보 계층
- B1.4 카메라 워크
- B1.5 5-Phase post-process 톤 분리
- 챕터 배경 자산 (5 phase × N chapter)
- UI frame 자산
- 시그니처 일러스트 (5 cascade trigger 별)

B2 완료 후 통합 플레이세션 (`/playtest-report`) 으로 5장 portrait 가 실제 게임 흐름 안에서 어떻게 인상되는지 검증 권장.
