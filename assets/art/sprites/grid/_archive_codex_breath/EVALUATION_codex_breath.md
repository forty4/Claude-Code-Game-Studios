# Q5 Phase 2 — Codex CLI image-to-image breath frame 실험 보고

**Date**: 2026-05-21 (S72)
**Tools tested**: codex CLI v0.130.0 (gemini CLI 는 native image gen access 0 으로 시작 자체 불가)
**Verdict**: codex image-to-image **quality control trade-off 무능** → 사용자 web 도구로 회귀
**Generated trials**: 2 (위연 1 영웅, codex_v1 / codex_v2)

---

## v1 trial — "subtle inhale" prompt

**입력 prompt 핵심**: "chest expanded slightly, shoulders raised slightly. The breath delta should be SUBTLE but visible at 64×64 display."

**결과**:
- ✅ Macro consistency 매우 강함 — 얼굴/자세/무기/의상 identity 모두 보존
- ✅ Alpha background 보존 (codex 가 Swift 후처리 코드로 input 의 alpha mask 복사)
- ⚠️ **Chest delta 거의 0** — single image 비교에서도, 그리드 부팅 시각 attestation 에서도 "전혀 움직임 없음"
- ⚠️ 미세 outline drift 있음 (lamellar pattern)

**Verdict**: ping-pong loop 시 시각상 정적 = breath cycle 효과 0

## v2 trial — "DRAMATIC inhale" prompt

**입력 prompt 핵심**: "chest puffed out about 10% wider, shoulders raised 5-8% noticeably. EXAGGERATED but still natural. If a viewer cannot immediately tell the two frames apart at 100% size, the result is WRONG."

**결과**:
- ⚠️ Chest delta 약간 + (그러나 v1 만큼은 아니어도 모호)
- ❌ **Alpha background 손실** — 검정 opaque fill + 그리드 패턴 decorative frame 추가
  (v1 의 alpha-preserving Swift 후처리가 v2 에서는 적용 안 됨)
- ❌ Outline drift 명확 (lamellar pattern, brush stroke 위치)
- ❌ Frame consistency 깨짐 — alpha 잃어서 게임 mount 시 검정 사각형 박힘 critical

**Verdict**: alpha critical regression → ship 불가

---

## 학습 — codex image-to-image 의 trade-off 모드

| Prompt strength | Macro consistency | Visible delta | Alpha preserve | Verdict |
|---|---|---|---|---|
| "subtle" (v1) | ✅ 강함 | ❌ 거의 0 | ✅ 보존 | 시각 정적 |
| "DRAMATIC" (v2) | ⚠️ drift | ⚠️ 약간 + | ❌ 손실 | alpha critical fail |

**Codex image_gen tool 의 한계**: "frame consistency + visible delta + alpha preserve" 세 가지를 동시에 충족 못 함. Prompt 강화 시 모든 채널에서 자유 변형 → critical 채널 (alpha) 까지 무너짐. v1 처럼 보수적 prompt 면 모든 채널 보존 but delta 자체가 사라짐.

**비교 — 사용자 web 도구 (idle v1→v3 cascade)**: 같은 한계 있을 수 있지만 사용자가 직접 iteration 통제 → v1→v3 까지 3 cascade 로 5장 satisfactory 한 idle frame 도달. codex CLI 는 단발 호출이라 iteration 통제 어려움.

**결정**: codex CLI 는 quick test 용으로만 유용. 본격 asset generation 은 사용자 web 도구로 진행. 5 영웅 breath prompt 작성 완료 (각 hero md 의 `## Breath frame (Phase 2)` 섹션).

---

## Archive files

- `sprite_shu_wei_yan_breath_codex_v1.png` (3.4 MB, alpha 보존, delta 0)
- `sprite_shu_wei_yan_breath_codex_v1.png.import` (Godot import sidecar — Phase 2 첫 commit 시점 캐시)
- `sprite_shu_wei_yan_breath_codex_v2.png` (5.2 MB, alpha 손실 + decoration)
- 본 문서

## 정식 위치 상태

`assets/art/sprites/grid/` 에 breath PNG 0장. 코드 (`chapter_visuals.gd:481`) 의
`HeroDatabase.get_grid_sprite_frame_texture(hero_id, "breath")` 가 null 반환 →
graceful fallback 으로 1-frame static idle 로 회귀. 5 영웅 모두 static 상태로
사용자 web 도구 generation 5장 대기.

## 사용자 web 도구 generation 대기 항목

각 영웅 md 의 `## Breath frame (Phase 2)` 섹션 prompt 입력 → 5장 PNG 출력 →
`assets/art/sprites/grid/sprite_shu_{hero_id}_breath.png` 정식 위치 drop.
- 위연: design/art/characters/wei-yan.md
- 방통: design/art/characters/pang-tong.md
- 관우: design/art/characters/guan-yu.md
- 장비: design/art/characters/zhang-fei.md
- 유비: design/art/characters/liu-bei.md
