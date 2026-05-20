# Battle Camera Work — Motion & Responsibility Spec (B1.4)

> Phase B 의 다음 단계 — 전투 화면의 카메라 움직임이 누구에게 무엇을 보여줘야 하는지 정의.
> 작성 2026-05-20 (S70 후속). 구현은 별도 phase — 본 문서는 디자인 합의 + 코드 가드레일.

---

## 1. Why this spec exists

`src/feature/camera/battle_camera.gd` 는 zoom + pan + drag + shake 의 **메커니즘** 만 제공한다. 어떤 이벤트에서 어떤 카메라 응답이 발생해야 하는지 — 즉 **policy** — 는 코드 측에 흩어져 있거나 (battle_scene 에 부분적으로 inline 작성) 아예 작성되지 않았다. 본 문서는:

- 어떤 카메라 모션이 우리 게임의 "정체성" 인지 (ink-wash 절제 vs 무쌍식 dynamic)
- 게임 진행 이벤트마다 어떤 카메라 응답이 정합한지
- 접근성 / Reduce Motion 에서 어떤 fallback 이 옳은지

세 가지를 합의해서, B1.5 (post-process) / G1 (hit feedback) / 후속 전투 작업이 같은 규약에서 카메라를 호출하게 한다.

---

## 2. Existing camera capability (baseline)

`battle_camera.gd:48-242` 의 공개 API:

| API | 시그니처 | 용도 |
|---|---|---|
| `setup(map_grid)` | DI seam, mount 전 호출 | 그리드 기준 viewport 계산 |
| `screen_to_grid(pos)` | Vector2 → Vector2i | 입력 좌표 변환 |
| `get_zoom_value()` | → float | 줌 상태 read-only |
| **`shake(intensity, duration)`** | float, float | 일시적 흔들림 (offset jitter) |
| `end_drag()` | void | 드래그 종료 정리 |

`shake` 가 G1 의 hit feedback channel 의 한 축. intensity = pixel 단위 진폭, duration = 초 단위.

**아직 없는 능력**:
- `focus_on(target_node, duration)` — 카메라 중심을 부드럽게 이동 (전투 시작 시 그리드 중앙 → 활성 unit, 또는 적 turn 시 적 unit)
- `intro_zoom_from(start_zoom)` — 챕터 타이틀 카드에서 그리드로 zoom-in 도입
- `flash_on(point)` — 특정 좌표에 강한 일시 줌 + 회복 (legendary moment 한정)

이 셋은 본 spec 의 AC 항목 — B1.4 구현 단계에 추가.

---

## 3. Camera motion taxonomy

게임 정체성 (ink-wash 절제, 무쌍 anti-reference, art-bible §5) 과 정합하는 5 가지 카메라 모션. 다른 패턴은 추가하지 않는다.

### M-1 — Hold (정지)

기본 상태. 카메라는 그리드 중앙에 고정. **전체 전투 시간의 ~90%** 가 M-1.

**규약**: 비-Hold 모션은 모두 자기-한정적 (self-limiting) — duration 명시, 끝나면 M-1 으로 복귀.

### M-2 — Shake (흔들림)

`battle_camera.shake()` 발동. 짧고 절제됨.

| 강도 | intensity (px) | duration (s) | 발동 이벤트 |
|---|---|---|---|
| Small | 2.0 | 0.10 | counter-attack 적중 / 약한 명중 |
| Medium | 4.0 | 0.18 | 일반 공격 적중 |
| Large | 7.0 | 0.30 | 치명타 (crit) / signature ability |
| Defeat | 10.0 | 0.45 | unit_died (player side) — 책무 강조 |

**제약**: Reduce Motion 활성 시 shake duration → 0 (no-op). intensity 는 디바이스 화면 폭 비례 클램핑 (mobile 에서 7px 이 PC 14px 처럼 보이지 않게).

### M-3 — Focus shift (포커스 이동)

`focus_on(target, duration)` — 신규 API. 카메라 position 을 target 의 world 위치로 부드럽게 이동 (Tween, TRANS_QUAD, EASE_OUT).

| 트리거 | duration | 비고 |
|---|---|---|
| `unit_turn_started` (active = enemy) | 0.35s | 적 차례 시 적 unit 으로 패닝. player turn 은 M-1 유지 (grid 전체 보기) |
| `attack_preview_requested` | 0.20s | 공격 표적 prominence. dismiss 시 M-1 복귀 |
| `signature_ability_charging` | 0.50s | (post-MVP) 시그니처 발동 직전 시그니처 unit 강조 |

**제약**: `_user_dragging` 중이면 M-3 발동 skip (사용자 의도 우선). Reduce Motion 시 duration *= 0.3 (작은 카메라 이동은 vestibular 영향 작음).

### M-4 — Intro zoom (도입 줌)

`intro_zoom_from(start_zoom)` — 챕터 진입 시 1회 발동. 챕터 타이틀 카드 fade-out 직후, 그리드가 노출되기 직전.

- start_zoom = 1.4 (살짝 줌인 상태)
- end_zoom = 1.0 (기본 zoom)
- duration = 0.6s, TRANS_CUBIC, EASE_OUT

**제약**: hidden_branch chapter 만 발동 (ch13/16/19/20/21/22/23/24/25 + legendary trigger). 일반 챕터는 인스턴트 1.0. Reduce Motion 시 duration → 0 (인스턴트).

### M-5 — Flash (강조 펄스) — legendary 한정

`flash_on(point)` — legendary cascade dawn 또는 같은 격의 emotional punctuation 에만 한정. zoom 1.0 → 1.15 → 1.0 over 0.40s + GEUM_SAEK overlay 협력.

**제약**: 챕터당 최대 1회. art-bible §1 reservation 과 동일한 "drought → flood" 원리 — 흔하면 효과 0.

---

## 4. Event → camera response 매핑

| GameBus event / battle phase | M-pattern | 비고 |
|---|---|---|
| `chapter_started` | M-4 (hidden/legendary only) | 일반 챕터 인스턴트 |
| `round_started` | M-1 (no-op) | 라운드 banner 는 HUD 책임 |
| `unit_turn_started` (player) | M-1 | grid 전체 보기 유지 |
| `unit_turn_started` (enemy) | M-3 (0.35s focus) | 적 unit 으로 부드럽게 패닝 |
| `attack_preview_requested` | M-3 (0.20s focus to defender) | dismiss 시 M-1 |
| `damage_applied` (hit) | M-2 Medium | crit 이면 Large |
| `damage_applied` (miss) | — | 카메라 영향 없음 (HUD 만) |
| `unit_died` (player side) | M-2 Defeat | "지키지 못함" 시각화 |
| `unit_died` (enemy side) | M-2 Small | 절제 (반복 발동 가능성) |
| `signature_ability_used` | M-2 Large | + M-5 (legendary cascade 시) |
| `battle_outcome_resolved` (legendary) | M-5 | art-bible legendary moment |
| `battle_outcome_resolved` (일반) | M-1 | outcome banner 가 책임 |

---

## 5. Accessibility — Reduce Motion override

`design/ux/accessibility-requirements.md` §4 + WCAG 2.1 SC 2.3.3 정합.

| Motion | Reduce Motion 시 fallback |
|---|---|
| M-2 shake | duration → 0 (no-op). 강도 시각 단서는 damage popup color 로 보완 |
| M-3 focus shift | duration *= 0.3 (이미 ≤0.5s — 작은 이동은 vestibular 영향 작음, 완전 비활성은 과함) |
| M-4 intro zoom | duration → 0 (인스턴트 1.0 zoom) |
| M-5 flash | duration → 0 (인스턴트 + GEUM_SAEK overlay 만 발동) |

UI-GB-* T4 누적 alpha pulse (battle-hud-info-hierarchy.md §5.3) 와 동일 패턴 — vestibular invariant 보호.

---

## 6. Implementation Acceptance Criteria

본 spec 의 구현 단계 (B1.4 구현) 진입 시 만족해야 할 조건.

**AC-B14-01**: `focus_on(target_node, duration)` API 추가 + `unit_turn_started(enemy)` 핸들러에서 호출.
— Type: Integration — Gate: ADVISORY.

**AC-B14-02**: `attack_preview_requested` 시점에 `focus_on(defender_node, 0.20)` 호출 + `_dismiss_forecast` 시점에 `_revert_focus()` 호출.
— Type: Integration — Gate: ADVISORY.

**AC-B14-03**: `shake()` 호출 site 4 분류 (Small/Medium/Large/Defeat) 가 §3 M-2 표 와 매칭. 코드 grep 으로 verify — intensity 값 enum 화 권고 (`SHAKE_SMALL = 2.0`, `SHAKE_MEDIUM = 4.0`, ...).
— Type: Lint — Gate: ADVISORY.

**AC-B14-04**: `intro_zoom_from(start_zoom)` API 추가 + hidden/legendary chapter 진입 시 호출. 일반 챕터 인스턴트.
— Type: Integration — Gate: ADVISORY.

**AC-B14-05**: `flash_on(point)` API 추가 + legendary cascade dawn 시점에 1회 호출. 챕터당 1회 cap 검증.
— Type: Integration — Gate: ADVISORY (post-MVP).

**AC-B14-06**: Reduce Motion preference 활성 시 M-2/M-3/M-4/M-5 모두 §5 fallback 표 와 정합 — 시각 비-vestibular cue 만 남도록 verify.
— Type: Integration — Gate: BLOCKING (a11y invariant).

**AC-B14-07**: drag 중 (`_user_dragging == true`) 에는 M-3/M-4 발동 skip. 사용자 의도 우선.
— Type: Integration — Gate: BLOCKING (UX invariant).

---

## 7. Open Questions / Future Work

1. **`flash_on` 시점 합의** (AC-B14-05) — legendary cascade dawn 의 정확한 frame (signature 5/5 도달 직후? Beat 8 시작? `battle_outcome_resolved` 직후?). 별도 sequence diagram 필요.
2. **카메라 → unit polygon 결합 방식** — focus_on 의 target_node 가 reparented 되는 케이스 (turn_indicator 가 unit 폴리곤 자식으로 이동) 와의 안정성. world_position lookup 시점 invariant 명시.
3. **Mobile 카메라 zoom default** — phone landscape 의 viewport 가 PC 보다 작으므로 default zoom 1.0 이 적합한지 재검증. 별도 mobile epic 후보.
4. **Cinematic mode** — Beat 1/8/9 prose 표시 중 카메라 모션 (intro zoom variant?) 의 추가 정의. post-MVP.

---

## 8. Dependencies

### Upstream (이 spec 이 의존)
- `src/feature/camera/battle_camera.gd` — 기존 `shake()` API + zoom/pan baseline
- `design/art/art-bible.md` §5 anti-reference (무쌍 anti) — M-2/M-5 강도 가드
- `design/ux/accessibility-requirements.md` §4 (Reduce Motion)
- `design/ux/battle-hud-info-hierarchy.md` §5.3 (animation budget) — T-tier vestibular invariant 와의 정합

### Downstream (이 spec 이 구속)
- `src/feature/camera/battle_camera.gd` 후속 구현 — focus_on / intro_zoom_from / flash_on 추가
- `src/feature/battle_scene/battle_scene.gd` — event → camera dispatch
- `src/feature/grid_battle/grid_battle_controller.gd` — damage_applied 시 shake 호출 site 분류 (hit/crit/defeat)
- G1 (hit feedback) — M-2 매핑이 이 spec 의 §3 M-2 표 와 정합해야 함
- B1.5 post-process — flash + intro zoom 의 시각 협력 (gold wash 등)
