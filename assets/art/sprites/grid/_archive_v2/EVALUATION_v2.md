# Q5 Phase 1 — Chibi grid sprite v2 평가

**Date**: 2026-05-21 (S72 second sprite batch, ~2hr after v1)
**Generated**: 5장 모두 (위연/방통/관우/장비/유비), 강화된 v2 prompt 적용
**Verdict**: 4장 PASS (canonical 위치 ship), 위연 1장 v3 필요 (이 archive)

---

## v1 → v2 prompt 강화 효과 검증

| 강화 항목 | v1 결과 | v2 결과 | 검증 |
|---|---|---|---|
| **Sumi-e style HIGHEST PRIORITY 명시 + NOT vector-clean 강화** | 5장 중 3장 vector cartoon 으로 빠짐 | 5장 모두 sumi-e 침투 (관우/장비 strong, 위연/유비 mid, 방통 유지) | ✅ 효과 입증 |
| **Weapon count "EXACTLY ONE" + 위치별 ban** | 위연 추가 칼 1자루 | 위연만 다른 방식으로 fail (검집 가로 들기 자세 — held not worn). 다른 4장 1-weapon ✅ | ⚠️ **위연만 다른 way 로 fail** — 추가 강화 필요 |
| **No-moe + blush 명시 ban** | 방통 핑크 볼터치 | 5장 모두 blush 0 | ✅ 완전 해소 |
| **차별 절대수치 (관우 1.4× / 장비 1.5× / 유비 1.5×)** | 모두 약화 | 장비 leopard-ring 명확 (흰자 ring 까지) / 관우 약간 + / 유비 약간 + | ✅ 장비 best, 관우/유비 partial |
| **투명 배경 명시** | paper-cream fill 가능성 | 5장 모두 alpha PNG (체크무늬 background 확인) | ✅ 완전 해소 |

**검증 결과**: 4-core 강화 모두 정량적 개선 입증. **prompt revision strategy 가 작동함**.

---

## 영웅별 v2 평가

### 위연 v2 — **REGEN HIGH (v3 필요)** — 이 archive

**PASS**:
- ✅ 3-head chibi 비례
- ✅ topknot + 갑옷 색 (iron grey + ochre)
- ✅ 얼굴 단순화 (눈 점, 입 1선) + NO blush
- ✅ 투명 배경

**FAIL**:
- ⚠️ **검집을 가로로 들고 있는 mercenary 자세** — prompt 가 "left hip 에 sheathed" 명시했지만 모델이 "blade waiting inside its sheath" 를 *검집을 들고 있는 자세* 로 해석. v1 의 "추가 칼" 과 다른 way 의 weapon 배치 fail.
- ⚠️ Sumi-e brush — 약간 개선됐지만 여전히 cleaner cartoon 측

**Root cause**: prompt 의 "scabbard at his left hip" 가 모델에게 *검집의 위치* 만 명시, *부착 방식* 명시 부족. 일반 mercenary art reference 가 가로 들기 자세 도상을 끌어옴.

### 방통 v2 — **SHIP ✅**
- ✅ 둥근 얼굴 / 부채 chest / 학창의 / 윤건 / sumi-e wash / 1 prop / 투명 배경 / **NO blush** (v1 미스 해소)

### 관우 v2 — **SHIP ✅**
- ✅ 청룡언월도 vertical / 긴 수염 / 녹포 / NOT red-faced / **sumi-e brush 명확** (v1 미스 해소) / 1 weapon / 투명 배경
- ⚠️ borderline: 어깨 1.4× sumo-broad 까진 아니지만 약간 더 넓어짐 (PARTIAL — windowed 시 차이 충분히 식별 가능 판단)

### 장비 v2 — **SHIP ✅✅ 최고**
- ✅ Wedge torso / spear S-curve / 곱슬 수염 wild / 최고 대비 / **sumi-e wash 강함** / **leopard-ring eye 명확 (1.5× + 흰자 ring)** / 1 weapon / 투명 배경 / forward-lean

### 유비 v2 — **SHIP ✅ borderline**
- ✅ Open-arm 대칭 / 双股劍 paired / trim 수염 / ink-base + ochre / NO blush / 투명 배경 / 1 weapon set
- ⚠️ borderline: 큰 귀 1.5× Buddha-iconography 까진 아니지만 약간 + (PARTIAL — ship 가능 판단)
- ⚠️ Sumi-e brush 부분 적용 (옷에 wash 보임, 외곽선은 still clean)

---

## v3 prompt 강화 (위연 한정)

### 추가된 명시

1. **Weapon mount type 강제화** (가장 critical):
   - "HIP-WORN, NOT HELD"
   - "The scabbard is NOT held in any hand — it is mounted on the belt as part of his outfit, like a samurai's daisho or a soldier's sidearm"
   - "The blade points DOWN"
   - "The scabbard remains attached to the hip throughout — it does NOT detach, it is NOT raised, it is NOT held horizontally in front of the body"

2. **Reference 명시화**:
   - "Reference: a samurai/general standing at rest with the katana mounted at the obi, OR a Roman legionnaire with the gladius sheathed at the side"
   - "NOT a knight presenting a sheathed sword forward"
   - "NOT a figure carrying or displaying a scabbard horizontally"

3. **Hands position section 신규** (양손 따로 명시):
   - LEFT HAND: "hangs straight down at the side, fingers relaxed, EMPTY"
   - RIGHT HAND: "rests RELAXED on top of the wooden hilt"
   - Both: "DO NOT depict either hand carrying, lifting, holding-out, or presenting"

4. **Negative-ref 추가**:
   - "NO carrying or holding the scabbard horizontally in front of the body"
   - "NO scabbard detached from the hip"
   - "NO presenting/displaying the sheathed sword"
   - "NO ready-to-draw or combat-ready posture"

---

## 학습 패턴 — v1 → v2 → v3 cumulative

(v1 EVALUATION 의 4 학습 패턴 추가 +)

5. **Weapon POSITION ≠ Weapon MOUNT** — single-image 모델은 "scabbard at left hip" 같은 위치 명시만으로 mount/attachment 도상을 인지 못함. 명시적인 *attachment* 동사 ("worn", "mounted on belt") + *negative-pose* ban ("NOT held", "NOT carried") + *reference* (samurai-at-rest) 3겹 필요.

6. **Reference 도상 활용** — 차별 절대수치 (장비 leopard 1.5×, 유비 귀 Buddha-iconography) 에서 외부 비유가 효과 입증 (장비 best 결과). 마찬가지로 weapon 도 reference 도상 (samurai obi, Roman gladius) 가 v3 에 적용. 다음 art generation batch (Phase 2 frames, 챕터 배경) 에 reusable.

7. **모델의 default attractor 인지** — mercenary 캐릭터 + 검 prompt 는 모델 default 로 "행동 자세" (검집 가로 들기, ready-to-draw) 끌어옴. *AT REST stance* 명시 + *ready-to-draw 자세 ban* 이 default attractor 를 차단.
