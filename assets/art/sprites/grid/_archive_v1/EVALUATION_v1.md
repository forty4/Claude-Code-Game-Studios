# Q5 Phase 1 — Chibi grid sprite v1 평가

**Date**: 2026-05-21 (S72 첫 sprite batch)
**Generated**: 5장 (위연/방통/관우/장비/유비), `sprite_shu_{hero_id}_idle.png` 1024×1024 native
**Verdict**: 5장 모두 regen — 강화된 prompt 로 v2 진행
**Archive 의도**: A/B 학습 evidence — v2 와 visual comparison 으로 prompt revision 효과 검증

---

## Cross-cutting issue (5장 중 3장 동일 패턴)

**Style consistency miss**: "fused sumi-e + chibi" 문구가 Gemini 에게 모호 → 출력이 두 그룹으로 갈라짐.

| Style 그룹 | 영웅 | 외곽선 | 잉크 wash |
|---|---|---|---|
| **Sumi-e ✅** | 방통, 장비 | 변형 두께 brush + 잉크 bleed visible | 옷/수염에 wash 적용 |
| **Vector cartoon ⚠️** | 위연, 관우, 유비 | clean uniform line, flat fill | wash 침투 약함 |

5장이 같은 그리드에 보일 때 style 충돌 우려. 모델이 "sumi-e + chibi" 를 chibi 우세로 해석 시 cartoon 으로 빠지는 경향 → prompt 의 sumi-e 우선순위 명시 부족이 root cause.

---

## 영웅별 평가

### 위연 (sprite_shu_wei_yan_idle.png) — REGEN HIGH

**PASS**:
- ✅ 3-head chibi 비례
- ✅ topknot + 갑옷 색 (iron blue-grey + ochre)
- ✅ Mercenary 자세 (hip-cocked OK)
- ✅ 얼굴 단순화 (눈 점)

**MISS**:
- ⚠️ **추가 칼 1자루** (왼쪽 아래) — prompt "NO second weapon" 위반. critical.
- ⚠️ Sumi-e brush miss — clean vector line + flat fill

### 방통 (sprite_shu_pang_tong_idle.png) — REGEN LOW (거의 ship 가능)

**PASS**:
- ✅ 둥근 얼굴 명확
- ✅ 부채 chest level
- ✅ 학창의 wide-sleeve silhouette
- ✅ ink-heavy 검은색 + 화이트 fan contrast
- ✅ **Sumi-e brush 가장 잘 적용** (5장 중 best)

**MISS**:
- ⚠️ 얼굴에 핑크 볼터치 (anime moe 미세 침투)

### 관우 (sprite_shu_guan_yu_idle.png) — REGEN MED

**PASS**:
- ✅ 청룡언월도 polearm 머리 위 수직
- ✅ 긴 검은 수염 chest 까지
- ✅ 녹포 #2D6B4A
- ✅ NOT red-faced

**MISS**:
- ⚠️ 어깨 1.3× 강조 약함 — 다른 영웅 대비 명확히 더 크지 않음
- ⚠️ Sumi-e brush miss — clean vector line

### 장비 (sprite_shu_zhang_fei_idle.png) — REGEN LOW (거의 ship 가능)

**PASS**:
- ✅ Wedge torso + 곱슬 수염 wild
- ✅ 장팔사모 spear vertical + S-curve tip
- ✅ 최고 대비 (5장 중 가장 어둠)
- ✅ Sumi-e brush 적용 (방통 다음 best)

**MISS**:
- ⚠️ leopard-ring 눈 강조 약함 — 일반 chibi 점 크기와 다르지 않음
- ⚠️ forward-lean 약함 (거의 직립)

### 유비 (sprite_shu_liu_bei_idle.png) — REGEN MED

**PASS**:
- ✅ Open-arm 대칭 + 정면 시선 (유일)
- ✅ 双股劍 paired swords at right hip
- ✅ Trim 정돈 수염
- ✅ Ink-base + ochre trim

**MISS**:
- ⚠️ 큰 귀 silhouette 돌출 약함 — 일반 귀 크기와 차별 안 됨
- ⚠️ Sumi-e brush miss — clean vector line
- ⚠️ ochre trim 의 yellow 약간 진함 (bright gold 경계선)

---

## Prompt revision 요약 (5장 공통 + 영웅별 강화)

### 4-core 공통 강화 (5장 모두 적용)

| 항목 | v1 prompt | v2 강화 |
|---|---|---|
| **Sumi-e style** | "Fused sumi-e + chibi" 모호 | "STRICTLY ink-wash sumi-e brush style ... HIGHEST PRIORITY ... STRICTLY NOT vector-clean, NOT CalArts" — 우선순위 명시 + negative ref 강화 |
| **Weapon count** | "NO second weapon" (일반) | "EXACTLY ONE weapon item in entire frame ... NO drawn blade, NO additional dagger/knife, NO weapon on back/right hip/floor/left hand" — 절대화 + 위치별 ban |
| **No-moe** | "NO anime moe (no large eyes, no shoujo features)" | + "NO blush, NO pink/red cheek dots, NO moe softening" — blush 명시 추가 |
| **Background** | "paper-white #F2E8D4 background" (paper-cream fill 의도) | "TRANSPARENT alpha PNG ... no paper texture, no fill, no border" — 진짜 transparent 명시 |

### 영웅별 차별 절대수치 강화

| 영웅 | v1 prompt | v2 강화 |
|---|---|---|
| **관우** | "Shoulder width ~1.3x other heroes" (비교) | "approximately 1.4x typical chibi shoulder width ... sumo-wrestler-broad body on chibi-height proportions" — 절대 비유 + 비교 강화 |
| **장비** | "eyes SLIGHTLY larger and rounder" (모호) | "approximately 1.5x the size of normal chibi eye dots ... bold black circular pupils with white outer ring (leopard-ring 표범 눈)" — 1.5× 절대수치 + 형태 명시 |
| **유비** | "ears should be slightly visible as silhouette protrusion (NOT erased)" (subtle) | "approximately 1.5x normal anatomical proportion ... CLEARLY EXAGGERATED ... obvious silhouette protrusions ... Buddha's elongated earlobes 비유" — Buddha-iconography 수준으로 강화 |

### 학습 패턴 — 다음 batch 에 일반화

1. **"Fused X + Y"** 같은 모호한 hybrid style 지시는 모델이 한쪽으로 빠짐 → "STRICTLY X applied to Y" + HIGHEST PRIORITY 명시 필요
2. **비교 strength** ("more than other heroes") 는 single-image generation 에서 reference frame 없음 → 절대 수치 (1.4×, 1.5×) + 외부 비유 (sumo, Buddha) 필요
3. **Negative-ref ban** 은 단순 "NO" 보다 위치별/형태별 명시 필요 ("NO weapon on back, NO weapon on right hip, NO dagger in left hand")
4. **Moe creep** 은 default 강한 attractor → blush 같은 구체 marker 까지 명시 ban 필요

---

## 다음 단계

1. **외부 generation v2**: 사용자가 강화된 5 hero md prompt 를 Gemini 등에 입력 → 5 PNG v2 생성
2. **v2 PNG → `assets/art/sprites/grid/`** (archive 와 같은 위치 아님, 정식 위치)
3. **v2 평가**: 같은 5-영웅 acceptance gate 로 재평가 → PASS 시 Phase 1 코드 진입 / 미달 시 v3
4. **Codification**: 학습 패턴 1-4 가 다음 art generation batch (Phase 2 walk/attack frame, 챕터 배경, UI frame) 에 reusable
