# Battle HUD — Information Hierarchy Specification

> **Status**: v1.0 draft — B1.3 Phase B spec (2026-05-19, S70)
> **Owner**: UX Design
> **Parent spec**: `design/ux/battle-hud.md` (canonical for visual/audio surfaces, palette, AC list)
> **Phase B context**: Phase B 시각 정체성 트랙 — B1.1 Palette token foundation 완료, B1.2 hidden vignette + signature pulse 완료, B1.3 Phase A title card 색 토큰화 완료, **B1.3 Phase B = 이 문서 + 후속 구현**.
>
> **What this spec adds to battle-hud.md**:
> - **§3 (Information Hierarchy Tiers)** — 4-tier 시각 prominence 시스템. battle-hud.md §3 의 14 UI-GB-* 표는 "어떤 요소가 있는지" 만 정의했음. 이 문서는 "어떤 요소가 얼마나 두드러져야 하는지" 정의.
> - **§4 (Tier Assignments)** — 14 UI-GB-* 요소별 tier 매핑 + rationale.
> - **§5 (Prominence Rules)** — tier 별 font_size / opacity / position / animation 의 의무 범위.
> - **§6 (Conflict Resolution)** — 4 식별된 prominence 충돌 사이트 + 해소 방향.
>
> battle-hud.md §3 UI Elements 표 + §6 Palette 는 이 문서의 upstream constraint. 충돌 시 battle-hud.md 가 위; 이 문서는 그 위에서 prominence 만 추가 layer.

---

## 1. Why this spec exists

Phase B 시각 정체성 작업 진행 중 발견:

1. **battle-hud.md §3 표** 14 UI-GB-* 모두 `Priority: MVP` — "있어야 한다" 정도만 정의됨. 어떤 요소가 시각적으로 두드러져야 하는지 / 평소 background 로 가라앉아야 하는지 규칙 없음.
2. **현재 runtime 값 (battle_hud.gd 2049 line) audit** (S70 Explore 보고서):
   - UI-GB-01 (initiative queue) + UI-GB-07 (turn counter) + UI-GB-08 (victory condition) 모두 동일한 top ribbon 점유, `modulate.a = 1.0` 동등. 셋 중 어느 것이 first-glance 우선 인지 모호.
   - UI-GB-02 (action menu) + UI-GB-05 (skill list) 모두 44×44pt 버튼. 메인 액션 vs 서브 액션 시각 위계 미분리.
   - UI-GB-04 (forecast) + UI-GB-03 (unit info) 동시 표시 가능 — z-layering 의도 명시 안 됨.
   - Grid overlay 3종 (UI-GB-12/13/14): 0.15~0.70 alpha range 가 겹치며 동일 tile 에 누적 시 시각 noise 후보.
3. **Mobile responsive 코드 0** — 14 요소 모두 phone-width 에서 동일 render. battle-hud.md §4.3 (Mobile Collapse Rule) 은 UI-GB-04 forecast 만 명시; 나머지 13 요소 미정의.
4. **Phase B 시각 정체성 작업** 이 색 토큰화 (B1.1 + B1.3 Phase A) + 색 적용 (B1.2 vignette/pulse) 까지 완료된 상태. 다음 단계는 "어떤 요소를 색/크기로 어떻게 강조할지" — 이 문서가 그 규칙.

**이 문서가 하지 않는 것**:
- 새 UI-GB-* 요소 추가 (그건 battle-hud.md 수정 영역).
- 새 색 토큰 추가 (그건 Palette.gd + art-bible-distilled.md 영역).
- UI-GB-04 forecast 내부 섹션 ordering (battle-hud.md §4 가 이미 정의).
- 입력 흐름 / 터치 행동 (battle-hud.md §5 가 이미 정의).

---

## 2. Hierarchy Pillars

3 design pillar 이 tier 분할의 root 기준:

**P1 — 시야 중앙은 그리드** (Pillar 1: 형세의 전술)
플레이어 시야의 중앙 절반 (viewport center 50%) 은 항상 grid + unit + tile overlay 가 점유. 어떤 HUD 요소도 이 영역을 항상-점유 (always-on) 시각으로 차지하지 않는다. 일시 표시 (forecast, results) 만 침범 가능.

**P2 — 즉답 가능한 정보가 가장 두드러진다** (Pillar 1 의 직접 결과)
"지금 누구 차례?", "이 공격 안전한가?", "내 HP 얼마?" 같은 "지금 결정에 필요한 정보" 가 가장 강한 시각 contrast 를 가진다. "전체 진행도", "장비 일람" 같은 reference 정보는 약한 contrast.

**P3 — Ink-wash 절제** (art-bible §1)
시각 prominence 는 brush weight (outline_size, font_weight) + glyph shape + size 로 표현한다. Color saturation 으로 위계 만들지 않는다 (주홍/금색 reserved invariant). 어떤 tier 도 reserved 색을 사용하지 않는다.

---

## 3. Information Hierarchy Tiers

4 tier 시스템. 각 tier 는 시각 contrast budget 을 정의한다 — font_size 범위, modulate alpha 범위, animation 권한, position 권한.

### T1 — Decision-Critical (즉답 필요 정보)

플레이어가 "지금 행동을 결정하기 위해 반드시 봐야 하는 정보". 임의 1 초 frame 안에 식별 가능해야 함. 5 요소 이하로 제한 (인지 부하).

**Visual contract**:
- Font size: 18~24pt (text 요소만)
- Modulate alpha: 1.00 (절대 dim 금지)
- Position: top ribbon 또는 active unit 근접 anchor (시선 자연 도달 영역)
- Animation: 변화 시점 (HP 감소, turn 전환, ATTACK 가능) 에 emphasizing pulse 또는 stroke-draw 허용. 평상시 정적.
- Brush weight: outline_size ≥ 6 (text 요소), border_width ≥ 2px (panel 요소)

### T2 — Currently-Actionable (지금 작동 가능 정보)

플레이어 turn 동안 사용 가능한 액션 + 그 액션의 cost/state. T1 결정의 input.

**Visual contract**:
- Font size: 14~18pt
- Modulate alpha: 1.00 (active state) / 0.70 (pending two-tap) / 0.50 (disabled/spent)
- Position: bottom action bar 또는 selected unit anchor
- Animation: state 변화 (cooldown, token spend) 시점에 짧은 fade allowed. 평상시 정적.
- Brush weight: outline_size ≥ 4

### T3 — Reference (참고용 정보)

플레이어가 원할 때 들여다보는 detail. 즉답에 필수 아님. Tile tooltip, status icons, undo indicator.

**Visual contract**:
- Font size: 12~16pt
- Modulate alpha: 0.85~1.00 (visible) / hidden (default off)
- Position: anchor-to-source (tile, unit) 또는 small floating panel
- Animation: appear/dismiss fade 만 (180ms 이내). 평상시 정적.
- Brush weight: outline_size ≤ 4

### T4 — Ambient (분위기 / 상태 indicator)

판 위에 깔리는 spatial overlay — 시야에 잡히되 시선 집중 안 시킴. Grid overlay 류 (rally aura, formation aura, TR extended range, defend stance badge).

**Visual contract**:
- Font size: glyph 8~10px (text 없음)
- Modulate alpha: 0.15~0.40 (single state) / 누적 시 0.50 cap
- Position: world-space (grid cell, unit tile)
- Animation: subtle pulse (0.5~1.5Hz) 또는 정적. Strobe 금지 (vestibular).
- Brush weight: 1~2px outline

---

## 4. Tier Assignments (14 UI-GB-* elements)

| UI-GB | Element | Tier | Rationale | Current State | Action Item |
|---|---|---|---|---|---|
| 01 | Initiative Queue | **T1** | "누가 다음 turn" — 즉답 결정 input | ✅ ribbon position, 1.0/0.5 alpha swing 정합 | Active slot modulate.a=1.2 는 over-boost — 1.00 cap 권고 (T1 invariant) |
| 02 | Action Menu | **T2** | 지금 사용 가능 액션 list | ✅ 44×44, modulate.a 0.7 pending 정합 | OK as-is |
| 03 | Unit Info Panel | **T1** | HP/ATK/DEF — 즉답 결정 input | ⚠️ default hidden — tap 으로만 reveal. T1 invariant 약화 | UI-GB-03 의 HP 부분만 별도 T1 surface 로 (always-on) / 나머지 (ATK/DEF/skills) T3 로 분리 후보 |
| 04 | Combat Forecast | **T1** | Pillar 1 의 핵심 surface | ✅ 200pt panel, fade-in tween, mouse-filter PASS 정합 | OK as-is |
| 05 | Skill List | **T2** | USE_SKILL sub-menu | ✅ revealed on USE_SKILL action | UI-GB-02 와 시각 동일 — T2 안 subordination 신호 추가 후보 (예: skill list 만 14pt + 모서리 indent) |
| 06 | Tile Info Tooltip | **T3** | Reference detail | ✅ default hidden, hover/tap reveal | OK as-is |
| 07 | Turn/Round Counter | **T1** | "지금 몇 round" — 즉답 결정 input | ✅ ribbon position, 1.0 alpha | font_size 명시 안 됨 — 18pt 권고 (T1 floor) |
| 08 | Victory Condition Display | **T1** | "내 목표 무엇" — 즉답 결정 input | ✅ ribbon position, 18pt font, GEUM_SAEK border | ⚠️ GEUM_SAEK border 는 art-bible reservation 위반 위험 — 검토 필요 (border 만 sanctioned 인지 또는 다른 색으로 교체) |
| 09 | End-of-Battle Results | **T1 (one-shot)** | 결과 모달 | ✅ full-screen overlay | OK as-is |
| 10 | Undo Indicator | **T2** | 지금 가능 액션 | ✅ 44×44 button, default hidden | OK as-is |
| 11 | DEFEND Stance Badge | **T4** | Spatial status indicator | ⚠️ HUD-level 만 scaffold — 본래 unit tile world-space 의도 (battle-hud.md §3 표) | Story-007 deferred 항목으로 active — 본 spec 은 T4 tier 확정만 |
| 12 | TacticalRead Extended Range | **T4** | Spatial overlay (Strategist only) | ✅ 0.25/0.70 alpha, world-space, 讀 glyph 8px | OK as-is |
| 13 | Rally Aura Visual | **T4** | Spatial overlay (Commander only) | ✅ 0.20/0.30/0.40 stacked alpha, 황금 dashed border | OK as-is (border alpha 0.80 은 T4 ceiling 0.40 초과 — shape-based colorblind cue 명시 의도, 예외 허용) |
| 14 | Formation Aura | **T4** | Spatial overlay (active formation) | ✅ 0.15 flat fallback / pulse spec post-MVP | OK as-is |

**Tier 합계**: T1=6 (UI-GB-01/03/04/07/08/09) · T2=3 (UI-GB-02/05/10) · T3=1 (UI-GB-06) · T4=4 (UI-GB-11/12/13/14). T1 가 ≤5 권고 초과 (6) — UI-GB-03 분할 (always-on HP + detail panel) 시 T1=5 + T3=2 가 됨, 권고 일치.

---

## 5. Prominence Rules per Tier

### 5.1 Font size budget

| Tier | Floor | Ceiling | Outline floor |
|---|---|---|---|
| T1 | 18pt | 24pt | 6 |
| T2 | 14pt | 18pt | 4 |
| T3 | 12pt | 16pt | 0~4 |
| T4 | 8pt (glyph) | 10pt (glyph) | 1~2px |

**Cross-tier rule**: 동일 viewport 안에서 T2 의 ceiling 이 T1 의 floor 를 초과하면 안 된다. 즉 T2 font 가 18pt 이면 같은 화면 T1 은 ≥20pt. 현재 코드 baseline 은 이 규칙 자연 준수 (T1 default 18pt + T2 default 14~16pt).

### 5.2 Modulate alpha budget

| Tier | Active | Pending/Acted | Disabled |
|---|---|---|---|
| T1 | 1.00 | — | (T1 은 disabled state 없음 — 항상 active) |
| T2 | 1.00 | 0.70 | 0.50 |
| T3 | 0.85~1.00 | — | hidden |
| T4 | 0.15~0.40 | 0.20~0.30 누적 | hidden |

**T4 누적 cap**: 동일 tile 에 grid overlay 가 누적되면 합산 alpha 가 0.50 을 넘지 않도록 코드 측 cap 필요. 현재 UI-GB-13 stack 은 0.40 cap (적합) — 다만 UI-GB-12/13/14 동시 발화 케이스 (예: Strategist Commander 위 formation) 시 합산 0.50 초과 가능 — 후속 구현 시 cap 로직 명시.

### 5.3 Animation budget

| Tier | Allowed animation | Forbidden |
|---|---|---|
| T1 | state-change pulse (≤0.6s, 1-shot), stroke-draw on appear (≤0.4s) | continuous loop, strobe |
| T2 | state-change fade (≤0.3s) | continuous pulse, scale tween |
| T3 | appear/dismiss fade (≤0.18s) | any state-change animation |
| T4 | subtle pulse (0.5~1.5Hz envelope), 정적 | scale animation, strobe (vestibular invariant) |

**Reduce Motion override** (cross-doc: damage-calc.md UI-4, accessibility-requirements.md §4): T4 pulse 는 Reduce Motion 활성 시 정적으로 fallback. T1 의 state-change pulse 는 1-shot 이라 vestibular 영향 작음 — Reduce Motion 시 stroke-draw 만 비활성화 (state-change 자체는 instant). T2/T3 fade 는 모두 ≤300ms 라 영향 없음 (WCAG 2.1 SC 2.3.3 기준).

### 5.4 Position budget

| Tier | Anchor zones |
|---|---|
| T1 | top ribbon (offset_top ≤ 60pt) / center forecast panel (mouse-pass through) |
| T2 | bottom action bar (offset_bottom ≥ -88pt) / selected unit world anchor |
| T3 | source-anchor (tile, unit) / floating tooltip near pointer |
| T4 | world-space (grid cell) only — HUD layer 침범 금지 |

**Grid 중앙 50% 점유 금지** (P1 invariant): 어떤 tier 도 viewport center 50% 영역 (offset_top 25%~75%, offset_left 25%~75%) 을 always-on 으로 점유하지 않는다. T1 forecast + T1 results screen 만 일시 점유 가능.

---

## 6. Identified Conflicts + Proposed Resolutions

### C-1: UI-GB-01 vs UI-GB-07 vs UI-GB-08 (top ribbon 동등 prominence)

**현재**: 셋 모두 ribbon, 모두 modulate 1.0, 모두 T1. First-glance 우선 모호.

**제안**: ribbon 안 spatial ordering 으로 prominence 강조 — left = round/turn (UI-GB-07) / center = initiative queue (UI-GB-01) / right = victory condition (UI-GB-08). Reading order 한 - 영 공통 left-to-right 자연.
- UI-GB-07 (left) — round/turn — 가장 먼저 본다 (시간 frame)
- UI-GB-01 (center) — initiative — 가장 시간 자주 본다 (per-turn 변화)
- UI-GB-08 (right) — victory condition — 가장 적게 본다 (battle 시작 시점 + 가끔 확인)

UI-GB-01 의 active slot scale 1.0 → 1.2 boost (현재 코드 line 1087) 는 ribbon 안 1차 attention attractor 로 적합 — UI-GB-07/08 는 보조 위계. **No code change required for C-1** — 자연 ordering 으로 해소. Spec 명시만.

### C-2: UI-GB-02 vs UI-GB-05 (액션 메인 vs 서브 시각 동일)

**현재**: 둘 다 44×44pt 버튼, 동일 시각.

**제안**: UI-GB-05 (skill list) 는 UI-GB-02 의 USE_SKILL 액션 활성 시점에 슬라이드 인되는 sub-panel. 시각 subordination 신호 추가:
- (a) UI-GB-05 버튼 텍스트 14pt (UI-GB-02 의 18pt 보다 small) — T2 floor 유지
- (b) UI-GB-05 panel border 가 UI-GB-02 의 USE_SKILL 버튼에서 시작하는 ink-stroke 가시 연결선 (~30px), "sub-menu of UI-GB-02" 명시
- (c) UI-GB-05 panel 좌측 8pt indent 시각 위계

**Implementation impact**: battle_hud.gd skill_list mount 코드에 ~5 line indent + font_size override. Tracking: B1.3 구현 phase.

### C-3: UI-GB-04 (forecast) vs UI-GB-03 (unit info) 동시 표시

**현재**: 둘 다 T1, 동시 visible 가능, z-layering 코드 측 add_child 순서 (UI-GB-03=1st, UI-GB-04=6th — forecast 가 위) 만 의존.

**제안**: 명시적 z-layer 규칙 추가:
- UI-GB-04 forecast 표시 중 (S3 state) → UI-GB-03 unit info 가 forecast 와 visual 충돌하지 않도록 자동 dim (modulate 0.85 → 0.50). 5.2 의 T2 disabled state 와 일치.
- Forecast dismiss 시 UI-GB-03 1.00 복귀.

**Implementation impact**: `_present_combat_forecast` 안 1 추가 site (UI-GB-03 modulate 변경) + dismiss path (`_dismiss_forecast`) 안 1 추가 site (복귀). Tracking: B1.3 구현 phase.

### C-4: Grid overlay 누적 alpha cap (UI-GB-12/13/14)

**현재**: 동일 tile 에 TR (0.70) + Rally (0.40) + Formation (0.15) 시 alpha 합산 ~1.0 — T4 ceiling 초과 + tile 자체 가시성 저하.

**제안**: GridLayer 측 alpha mixing rule 도입:
- 동일 tile 위 T4 overlay 최대 2 개만 render — 3 번째는 lowest-priority 자동 skip
- 우선순위: TR (Strategist class-specific) > Rally (Commander aura) > Formation (board-wide)
- 누적 합산 alpha 가 0.50 초과 시 가장 약한 overlay 가 0.50/N (N=overlay count) 로 scale 다운

**Implementation impact**: GridLayer 측 helper `_render_overlays_with_alpha_cap(tile_coord, overlay_specs)`. 별도 epic — Phase B 안에서 처리하기엔 큼. **B1.3 spec 에서는 conflict + 해결 방향만 명시**; 구현은 후속.

### C-5 (신규): UI-GB-08 victory condition border = GEUM_SAEK 의 reservation 검토

**현재** (battle_hud.gd:607): UI-GB-08 panel border = Palette.GEUM_SAEK 0.95 alpha. art-bible §1: "GEUM_SAEK — Legendary / destiny-reversed ONLY".

**검토 필요**: victory condition border 가 "must-do tactical UI" 인지 vs "운명 역전 emotional punctuation" 인지. 만약 전자라면 UI_GOLD (border 도 가능) 로 교체. 후자라면 (= legendary chapter 시각적 sanctity) 현 상태 유지.

**Resolution** (art-director, 2026-05-20): UI-GB-08 은 tactical objective UI — "must-do mission panel" 성격. GEUM_SAEK 는 art-bible §1 + battle-hud.md §6.1 reservation ("victory screen only, §2.11") 과 불일치. **UI_GOLD (#E8D68A) 로 교체** — 1 line at `battle_hud.gd:607`. palette.gd 의 UI_GOLD docstring (line 63-68) 이 이미 이 케이스의 invariant 를 명시 ("Deliberately NOT GEUM_SAEK ... reserve UI_GOLD for text-only vivid states"). ADR 불필요. **C-5 RESOLVED**.

---

## 7. Mobile / Responsive Considerations

**현재 상태**: battle_hud.gd 안 mobile-responsive 코드 0. 14 요소 모두 phone-width (<480pt) 에서 동일 render. battle-hud.md §4.3 (Mobile Collapse Rule) 은 UI-GB-04 forecast 만 명시.

### 7.1 Mobile 우선 가시성 (viewport < 480pt)

T1/T2 는 항상 가시. T3/T4 는 mobile 에서 축소/지연 가능.

| Tier | Mobile <480pt 처리 |
|---|---|
| T1 (6) | 모두 가시. Ribbon 은 가로 압축 — 8pt left/right margin. |
| T2 (3) | 모두 가시. Action menu 가 bottom anchor — keyboard 충돌 회피. |
| T3 (1) | Tile tooltip 은 tap-reveal (현재 코드 정합). |
| T4 (4) | 모두 가시 — world-space 이므로 viewport 영향 없음. |

### 7.2 Mobile reflow 작업 (B1.3 후속 / 별도 epic 후보)

- UI-GB-01 initiative queue 가 5+ unit 일 때 ribbon 가로 overflow — horizontal scroll 또는 8-slot cap.
- UI-GB-03 unit info panel default width 180pt 가 phone landscape 에서 grid 침범 — auto-collapse to side affordance.
- UI-GB-04 forecast 의 §4.3 collapse rule (battle-hud.md) 가 이미 정의 — 다른 panel 도 동일 패턴 follow-up.

**Recommendation**: mobile reflow 는 B1.3 본 spec 의 범위 밖. 별도 epic "battle-hud mobile responsive" 로 분리.

---

## 8. Implementation Acceptance Criteria

B1.3 spec 의 구현 phase 진입 시 만족해야 할 조건. 모두 battle_hud.gd + battle_scene.gd 측 수정.

**AC-B13-01**: UI-GB-01 active slot scale 1.2 boost 가 modulate 1.0 cap 안에서 작동 (T1 invariant). 현재 코드 line 1087 의 `modulate.a = 1.2` 가 cap 위반 — 1.00 으로 변경 + brightness 강조는 다른 채널 (border outline 두꺼움) 로 이동.
— Type: Visual — Gate: ADVISORY (visual review 후 land).

**AC-B13-02**: C-2 — UI-GB-05 (skill list) 의 시각 subordination. 버튼 font 14pt + panel 좌측 8pt indent 적용. 시각 screenshot evidence.
— Type: Visual — Gate: ADVISORY.

**AC-B13-03**: C-3 — Forecast 표시 중 UI-GB-03 unit info modulate.a 가 0.50 으로 dim. Forecast dismiss 시 1.00 복귀. Unit + integration test 가능 — `_present_combat_forecast` 호출 시점 + `_dismiss_forecast` 시점 modulate 값 assertion.
— Type: Integration — Gate: BLOCKING.

**AC-B13-04**: T4 누적 alpha cap. 동일 tile 에 3+ T4 overlay 적용 시 GridLayer 측 cap logic 작동 — 합산 alpha ≤ 0.50. Synthetic fixture 로 verify.
— Type: Integration — Gate: ADVISORY (별도 epic 분리 가능).

**AC-B13-05** ✅ RESOLVED (art-director, 2026-05-20): C-5 — UI-GB-08 border = `Palette.UI_GOLD` (was `Palette.GEUM_SAEK`). art-bible §1 + battle-hud.md §6.1 + palette.gd UI_GOLD docstring 3-way invariant 정합. `battle_hud.gd:607` 1-line change 적용. ADR 불필요.
— Type: Decision — Gate: BLOCKING — Status: **RESOLVED**.

**AC-B13-06**: Tier 5.1 font size budget 준수. 14 UI-GB-* 의 모든 font_size override 가 tier-별 floor/ceiling 안에 들어옴. 코드 grep 으로 verify — `add_theme_font_size_override` 호출의 두 번째 인자 vs 해당 element 의 tier 매핑.
— Type: Lint — Gate: ADVISORY (drift detection).

---

## 9. Open Questions / Future Work

1. **UI-GB-08 border 색** (AC-B13-05) — art-director 합의. art-bible §1 invariant 와 정합성.
2. **UI-GB-03 분할** — HP 부분만 always-on T1 surface + 나머지 (ATK/DEF/skills) T3 detail panel 분리. mobile-first viewport 에서 효과 클 후보. 디자인 결정 필요.
3. **Mobile reflow epic** (§7.2) — 14 요소 중 ribbon overflow + unit info panel auto-collapse + tile tooltip 위치 강건성. 별도 epic.
4. **Reduce Motion override matrix** — T1/T2/T3/T4 별 정확한 animation 비활성화 rule. accessibility-requirements.md §4 와 cross-doc.
5. **UI-GB-11 (DEFEND 守 seal) world-space 이동** — story-007 deferred. T4 tier 확정 (이 문서) + 실제 world-space mount 이전.
6. **Phase C 이후 tier 확장** — 추후 메뉴/팝업 (signature archive popup, consequence screen, story beat screen) 에도 동일 tier 시스템 적용 — 별도 spec 또는 이 문서 확장.

---

## 10. Dependencies

### Upstream (이 spec consume)
| Source | Status | What is consumed |
|---|---|---|
| `design/ux/battle-hud.md` | v1.1 | 14 UI-GB-* 정의, §6 palette/accessibility, §4 forecast 구조 |
| `design/art/art-bible-v1-distilled.md` | v1 | §1 palette (주홍/금색 reservation), §3 5-phase lighting |
| `src/foundation/palette.gd` | S70 | 6 base + 2 derived (JI_BAEK_DIM/CHEONG_HOE_LIFT, B1.3 Phase A) + UI utility (UI_GOLD/MUK_OUTLINE/BACKDROP_DARK) |
| Phase B 진행 상태 (active.md) | S70 | B1.1/B1.2/B1.3 Phase A 완료 — 이 문서가 Phase B 시작 |

### Downstream (이 spec constrain)
| Target | Status | What is provided |
|---|---|---|
| battle_hud.gd 구현 phase | Not yet started | §5 prominence rules + §6 conflict resolutions + §8 AC list |
| Mobile responsive epic | Not yet authored | §7.2 의 reflow 요건 |
| accessibility-requirements.md §4 | Not yet authored | §5.3 Reduce Motion matrix |
