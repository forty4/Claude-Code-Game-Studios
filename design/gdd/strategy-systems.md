# Strategy Systems — 도구 · 책략권 · 행동 연쇄

> **Status**: Implemented (Phase B + S94 ALLY + S97 ENEMY extension) — **v0.5 (S97 — ENEMY 교란 축 신설)**
> **Author**: claude (S89 user-driver collaborative draft + 3-specialist narrow re-review fix + INT_BASELINE adjudication; S94 ALLY items; S97 ENEMY debuff)
> **Last Updated**: 2026-05-30 (S97 — intimidate_scroll ENEMY-disrupt debuff implemented + windowed-verified)
> **Change log (v0.4 → v0.5)**: S97 — raw feedback #6 의 *"적을 교란"* 축이 mechanical 0 이던 gap 해소 (ALLY 축은 S94 가 해소). `intimidate_scroll` (협박권, 적 next attack ×0.70) 1종으로 **ENEMY target 축** 작동. **substrate 재사용 — damage-calc / BattleUnit 필드 변경 0**: 적 `pending_buff` 음수 magnitude(0.70) + `_resolve_pending_buff_magnitude` side-gate-free 소비 (`_passive_multiplier` 하한 clamp 없음). kind="intimidate" → cleared 시그널이 `unit_pending_debuff_changed` 로 라우팅 → 빨강 ▼ DebuffBadge (금색 ▶ 오인 방지). §3.7 item table + §7 tuning knobs (ENEMY_DISRUPT_RANGE / INTIMIDATE_MULT) 반영. +10 test (2086→2096 PASS) + windowed G-30 verify PASS. ENEMY 황토 palette 는 S91 arc-F 가 이미 author.
> **Change log (v0.3 → v0.4)**: S94 — raw feedback #6 의 cross-hero 지원 축 ("다른 장수를 도와주거나") 이 mechanical 0 이던 gap 해소. `aid_potion` (구호약, ALLY heal +20) + `rally_scroll` (독려권, ALLY next-attack ×1.30) 2종 구현 — 둘 다 self 제외 (cross-hero only). §3.7 item table + §7 tuning knobs (ALLY_SUPPORT_RANGE / AID_POTION_AMOUNT / RALLY_SCROLL_MULT) 반영. +15 test (2068→2083 PASS) + windowed G-30 verify PASS. damage-calc / BattleUnit 필드 / view-layer 변경 0 (기존 substrate 재사용; ALLY 금록 palette 는 S91 arc-F 가 이미 author).
> **Change log (v0.2 → v0.3)**: hero-database.md INT sweep audit revealed `stat_intellect` field already exists for all 19 named heroes (0-100 scale per ADR-0007). v0.2 의 INT 5-9 abstract scale 표기를 v0.3 에서 stat_intellect 0-100 직접 매핑으로 변경 — 데이터 중복 제거 + cross-doc grep 가능. User adjudicated INT_BASELINE = **60** (보더라인): 장비/허저/여포 (stat_intellect=50) 거부 + 관우/황충/마초 (60) 통과 + 위연/우금 (65) 통과 + 조운/유비/초선 (75) 이상 통과. Pillar #3 보호 (무력형 극단 차단) + 대부분 hero cross-class 책략 가능성 균형.
> **Change log (v0.1 → v0.2)**: 3-specialist narrow re-review (godot-gdscript-specialist + ux-designer + qa-lead) returned NEEDS REVISION × 2 + CONCERNS × 1 with 11 blocking findings. All 11 resolved via specialist-authored fix language. 2 user adjudications (binding): (A) Inventory panel anchor = Option B (bottom-center modal); (B) `command_scroll` DEFERRED to Phase 4+ — Phase B MVP item set reduced to 4 (heal_potion / strength_scroll / march_scroll / fire_scroll). Review log: `design/gdd/reviews/strategy-systems-review-log.md`.
> **Implements Pillar**: **Pillar 5 (전략적 조합 — Strategic Combinations)** primary; Pillar 1 (형세의 전술 — 책략권의 적정 사용은 적 형세 와해의 도구) supporting; Pillar 3 (역할 차별화 — 책략권 class 제한으로 강화) supporting
> **Depends on**: Turn Order (`ActionType` enum + `declare_action`), Grid Battle (per-unit context + adjacency), Damage Calc (`ResolveModifiers` field extension — see §6.1 cross-doc obligation), Hero Database (per-hero starting inventory + class + **INT sweep required pre-Phase-B**), Save/Load (per-chapter inventory state), Scenario Progression (chapter loot bundles)
> **User-adjudicated design decisions (binding, S89)**:
> (1) **MVP scope**: Strategic depth foundation ship target 안. minimum bar = 4 종 아이템 + 1 종 책략권 + UI + chapter-별 inventory + windowed verify.
> (2) **Token cost**: Item use = Action token 소모 (attack/skill/defend 와 동일 token category). 이동+아이템 OK / 이동+아이템+공격 NOT OK. Buff item 은 multi-turn carry.
> (3) **Inventory model**: per-hero (영걸전 style — Pillar #3 강화). 시작 슬롯 3개 / hero.
> (4) **Carry permanence**: 챕터 종료 시 자동 회수 + 다음 챕터 시작 시 보급. 영구 손실 없음.
> (5) **Pillar #3 보호**: 책략권 = class 제한 + 일회성 + 휴대 한계. "강캐 한 명 모든 책 들고 무쌍" 차단.
> (6) **v0.2 inventory panel anchor**: Option B (bottom-center modal) — UI-GB-02 action menu 과 동일 bottom-HUD vocabulary 통일 (ux-designer 추천 + user adjudicated).
> (7) **v0.2 command_scroll defer**: turn-queue mid-round mutation 은 TurnOrderRunner hard invariant. Phase 4+ 로 defer. 4 MVP item 으로 Pillar #5 입증.
> (8) **v0.3 INT_BASELINE = 60**: stat_intellect 0-100 scale 의 보더라인. 무력형 극단 (장비/허저/여포 50) 거부 + 중급 (관우/황충/마초 60) 통과. Pillar #3 보호 + cross-class 책략 가능성 균형. `INT_BASELINE` 상수는 `damage-calc.md` rev 2.9.4 에 등재 (cross-doc obligation §6.3).

---

## 1. Overview

Strategy Systems는 영걸전 (KOEI Heroes Saga) 의 핵심 전략적 재미 — "이동 후 무엇을 할지" 의 조합 puzzle — 을 본 게임으로 직접 이식하는 design layer 다. 세 sub-system 으로 구성: (a) **Inventory** — per-hero 3 slot 의 휴대 가능한 도구 ledger, (b) **Item** — 즉시 효과 또는 buff 를 적용하는 일회성 소비재, (c) **Scroll (책 / 책략권)** — 무장의 평소 class 가 사용할 수 없는 책략을 1회 사용 가능하게 하는 cross-class 특수 아이템. 모든 사용은 `ActionType.USE_ITEM` 으로 단일 declare_action 으로 발화되며 action token 1개를 소모한다 (move token 과 분리되어 "이동 + 아이템 사용" chain 은 가능). 시스템의 목표는 매 turn 의 결정 단위가 **단일 action 이 아닌 chain** 이 되도록 하는 것 — Pillar #5 의 mechanical 구현체.

---

## 2. Player Fantasy

플레이어가 turn 시작 시 느껴야 할 감각:

> "이번 턴에 누구를 누구로 어떻게 도울지" 의 puzzle.

영걸전의 가장 강력한 기억 — 후반 전투의 절체절명 순간에 "내 무장 한 명 한 명이 모두 의미 있는 선택지" 를 가지고 있어야 한다.

- **무력형 장수가 책 펴는 순간**: INFANTRY 관우가 화공권을 들고 있을 때, 평소엔 평타 + dragon_blade 만 쓰던 그가 이번 turn 에 화공을 발화 → 적 진형 와해. 이 순간이 **Pillar #5 의 정점**.
- **위급한 동료를 살리는 회복권**: 강유의 후계자 책략은 turn 이 자기 차례여야 한다. 하지만 부상당한 유비가 turn 차례를 한참 기다려야 한다면 누구든 회복권을 휴대했다면 즉시 사용 가능.
- **공격 전 강화권**: 다음 turn 의 공격에 +50% 가 붙는 강공권은 "이번 turn 에 강화 → 다음 turn 에 공격" 의 2-turn plan 을 강제한다 — 그 사이에 적이 무엇을 할지 예측해야 한다.
- **선택의 무게**: 슬롯 3개만 휴대 가능하므로 챕터 시작 시 "이 챕터의 적이 어떤 양상일까" 를 예측해 inventory 를 구성해야 한다.

**금기 fantasy** (anti-pattern):
- "강캐 한 명 모든 강화권 다 들고 단독 돌격" — Pillar #3 위반, anti-pillar "밸런스 붕괴"
- "회복권 무한 보급으로 전투 모두 무사고" — 챕터 별 supply 가 정해져야 함
- "책략권으로 모든 class 가 모든 책략 사용 가능" — class 제한 + INT 능력치 제한으로 보호

---

## 3. Detailed Rules

### 3.1 Inventory Model (per-hero, slot-based)

- 모든 player-controlled hero 는 inventory slot 3개를 가진다.
- Inventory 는 **per-hero** — 다른 hero 의 inventory 접근 불가. 단, "건네주기 (transfer)" 는 future scope.
- Slot 은 정렬 없음 (UI 표시 순서만 의미).
- 동일 item 의 중복 보유 가능 (예: 회복초 × 3).
- Slot 이 다 차 있는 hero 는 새 아이템 픽업 거부 (overflow 정책: future scope).
- Enemy unit 은 inventory 없음 (S90 MVP 범위; enemy item drop 은 future scope).

### 3.2 Item Categories

#### 3.2.1 즉시 효과 (Immediate-effect items)
- 사용 즉시 효과 발화 후 소비 (다음 turn 으로 carry 없음).
- 예: 회복초 (HP +25), 강심초 (status cure), 회복단 (모든 인접 ally HP +15).

#### 3.2.2 Buff 효과 (Buff items, multi-turn carry)
- 사용 turn 에는 token 소비 후 효과 발화 없음 (action token 이미 소비됨).
- **다음 turn 의 첫 attack / skill 시점**까지 carry 후 효과 발화.
- Carry 중 다른 buff 사용 시 덮어쓰기 (stacking 안 됨 — Pillar #3 보호).
- 예: 강공권 (next attack +50%), 정확권 (next attack accuracy +30%), 관통권 (next attack ignore DEF).
- HUD 표시: hero 의 unit polygon 옆 small icon + tooltip.

#### 3.2.3 Scroll / 책 / 책략권 (Cross-class skill grant)
- 사용 시 hero 의 평소 class 가 사용할 수 없는 skill 1회 발화.
- **Class 제한**: 각 책은 사용 가능 class 제한 + 일부는 `stat_intellect` ≥ 임계치 (Pillar #3 보호). **v0.3**: INT scale 은 heroes.json 의 `stat_intellect` field 직접 사용 (0-100 scale). v0.2 의 abstract 5-9 scale 폐기.
- 사용 시 그 skill 의 일반 발화 로직 그대로 사용 — particle / SFX / damage 계산 모두 동일.
- 예: 화공권 (fire_strategy 1회, `stat_intellect` ≥ 60), 회복권 (heal scroll, 누구나), 책략권 일반 (strategist 1회, `stat_intellect` ≥ 85 만 — Phase C+).

### 3.3 Action Token Integration

- `ActionType` enum 에 `USE_ITEM` 추가 (`turn_order_runner.gd`).
- `declare_action(USE_ITEM, ctx)` 의 ctx payload: `{slot_idx: int, target_unit_id: int | -1, target_pos: Vector2i | null}` (untyped Dictionary — G-25 nested-typed-collection 회피).
- Validation:
  - slot_idx 가 0..2 범위 내 + 해당 slot 에 item 존재
  - item 의 target_type 이 ctx 와 일치 (SELF / ALLY / ENEMY / GROUND)
  - item 의 class_restriction 이 caster class 와 일치 (책에만 적용)
  - item 의 int_requirement 가 caster INT 와 일치 (책에만 적용)
- Token 처리: `action_token_spent = true` 즉시 (attack 과 동일).
- 효과 발화 시점:
  - 즉시 효과: declare_action 내 동기 처리.
  - Buff 효과: caster.pending_buff = {kind, magnitude, expires_at_turn=current_turn+1} 저장. 다음 turn 의 첫 attack/skill resolve 시점 (damage_calc) 에서 consume. **consumption 책임**: GridBattleController 가 ResolveModifiers 에 magnitude 읽어 넣은 직후 `caster.pending_buff = {}` 으로 clear — DamageCalc 내에서 mutate 하지 않음 (ownership 명시).
  - Scroll: 해당 skill 의 `_resolve_skill_<skill_id>` 함수 호출 (기존 path 재사용).

#### 3.3.1 BattleUnit field additions (Phase B implementation contract)

godot-gdscript-specialist v0.2 review B-1 fix language. Add two fields to `src/core/battle_unit.gd`:

```gdscript
var pending_buff: Dictionary = {}
# {} = no active buff. When non-empty, must contain exactly:
#   { &"kind": StringName, &"magnitude": float, &"expires_at_turn": int }
# Use {} as the null-sentinel (NOT null — Dictionary var cannot hold null).
# Outer type is untyped Dictionary (not Dictionary[StringName, Variant])
# to avoid the G-25 nested-typed-collection parse error on value type.
var inventory: Array[StringName] = []
# Exactly INVENTORY_SLOT_COUNT entries; &"" = empty slot.
```

**ResolveModifiers ABI delta** (binding cross-doc obligation): add `pending_buff_magnitude: float = 1.0` to `src/feature/grid_battle/resolve_modifiers.gd` and extend the `make()` factory signature. **Default = 1.0** (multiplicative identity) — protects existing damage-calc tests from G-21 retroactive shift. GridBattleController is the sole caller of `ResolveModifiers.make()`; its call sites must read `attacker.pending_buff.get(&"magnitude", 1.0)` and pass into the factory at attack/skill resolve time. **This addition MUST be reflected in `damage-calc.md` §CR-1 and §6.3 in the same rev-N cross-system patch** that lands the code — see §6.3 below.

#### 3.3.2 G-32 InputRouter arm coverage (mandatory)

godot-gdscript-specialist v0.2 review B-4 fix language. The `&"use_item"` action match arm must appear in BOTH:
- `_handle_action_in_s0` (OBSERVATION state) — player may press I before clicking a unit; the arm sets `_did_visible_work = true` only if a unit's turn is active (guard: `_active_unit_id >= 0`); otherwise intentional no-op.
- `_handle_action_in_s1` (UNIT_SELECTED state) — primary use path; arm sets `_did_visible_work = true` unconditionally.

`tools/ci/lint_input_router_action_arm_coverage.sh` (S88 codification) will fail CI if `&"use_item"` is in `ACTIONS_BY_CATEGORY["grid"]` vocabulary but absent from both arm bodies. Implementer must satisfy the lint before story is Done. Inventory panel open/close is a UI toggle that does NOT change InputRouter state.

### 3.4 Chapter Lifecycle

- **챕터 시작**: 각 hero 의 inventory 가 chapter resource 의 `starting_inventory_by_hero: Dictionary[StringName, Array]` 에서 로드. (godot A-2 G-25 fix: 내부 Array 는 untyped 로 declare — element type `StringName` 는 loader 의 typed param 으로 enforce). 만약 hero 가 chapter resource 에 명시 안 됨 → default `["heal_potion"]` 1슬롯.
- **챕터 종료**: 모든 hero 의 inventory 가 자동 회수 — 다음 챕터 의 starting_inventory 가 새로 적용 (영구 누적 없음).
- **챕터 중 loot drop**: future scope (Phase 4+). MVP 는 starting inventory 만.

### 3.5 UI Surfaces

#### 3.5.1 Inventory Panel (UI-GB-15 — new battle-hud.md row obligation)

ux-designer v0.2 review B-1 fix language + user adjudication: **Option B (bottom-center modal)**.

- **Anchor**: bottom-center modal, anchored above UI-GB-02 action menu strip. Same bottom-HUD vocabulary as DEFEND two-tap (battle-hud.md §5.2).
- **Open state**: action menu (UI-GB-02) dismisses or stacks behind inventory panel; restored on inventory close.
- **Panel dimensions**: 3 slots horizontally arrayed, slot tile minimum **44pt × 44pt** on mobile (touch target — CLAUDE.md technical preference). Panel height ≈ 64pt; width auto-fit to 3 slots + tooltip surface.
- **Z-order**: above grid overlays / class emblems / HP bars; below outcome banner + critical-popup.
- **Open animation**: ink-wash fade-in (battle-hud.md §2.1 reference) over 0.15s. Reduce-motion alternative: instant appear (no animation).
- **Close animation**: same fade-out, 0.15s. Reduce-motion: instant.
- **No-active-hero state** (ux R-3): I 키 / button 은 no-op. Panel does NOT open for non-player-controlled units or when no unit's turn is active. If active unit has already spent action_token, panel opens **read-only** — slots visible (greyed with spent-action overlay), tooltips accessible, slot select disabled (planning preview only).

#### 3.5.2 Trigger & Slot Select Flow

- **Open trigger**: I 키 (PC) 또는 신규 button (mobile/PC tap surface). Toggle behaviour.
- **Slot select**:
  1. I → 패널 open.
  2. Slot click (1/2/3 key or tap) → target selection mode entered (based on item.target_type).
  3. Target chosen → `declare_action(USE_ITEM, ctx)` 발화 → token consumed + effect resolved.

#### 3.5.3 Target Selection Mode (UI-GB-17 — new battle-hud.md row obligation)

ux-designer v0.2 review B-2 fix language. **Highlight palette per target_type, distinct from existing 4 overlays** (move-range 청회, attack-range 황토, formation aura 청록, fog-of-war n/a):

- **ALLY target**: 금록 (#D4E8A0 — warm green) at 30% opacity. Distinct from formation 청록 by hue.
- **ENEMY target**: 황토 (#C8874A) at 50% opacity (more saturated than attack-range 25%) — communicates "item target" vs "normal attack". 
- **GROUND target**: 청회 (#5C7A8A) at 50% opacity + crosshair glyph (✚ or ∴) at tile center — distinguishable from move-range 청회 25% by both opacity and glyph.
- **Art-director sign-off required** before implementation lock — exact hex values may shift but the differentiation principle (opacity contrast + shape glyph, not hue only) is locked.

#### 3.5.4 Self-Target Auto-Resolve + Confirm Beat (ux B-4 fix)

For SELF-target items (heal_potion / strength_scroll / accuracy_scroll / march_scroll):
- **PC flow**: Slot click → one-frame forecast-style cost preview (action_token spend + effect preview e.g. HP bar after) → second click confirms. ESC during preview cancels without spending token.
- **Mobile flow**: Slot tap (Beat 1, visual pulse) → second slot tap within `TWO_TAP_TIMEOUT_S` (Beat 2) confirms. Tap outside slot during Beat 1 cancels.
- **Rationale**: action_token spend is irreversible; a confirm beat prevents accidental use under tense moments. Mirrors DEFEND two-tap (battle-hud.md §5.2).

#### 3.5.5 Cancel Pattern (ux B-3 fix)

- **PC cancel**: ESC during target-selection returns to inventory panel (open state, can choose different slot). Double-ESC closes panel entirely.
- **Mobile cancel**: tap any non-highlighted tile (invalid target) returns to inventory panel open state — same as PC ESC. Panel close on mobile = tap outside panel area OR press inventory button again (toggle).

#### 3.5.6 Tooltip Surface (ux R-2 fix)

- **PC**: hover over slot → tooltip appears after 300ms hover delay. Hover is **secondary info path only**, not primary (primary = click). Accessibility-compliant (no hover-only interaction per CLAUDE.md technical preference).
- **Mobile**: tap-and-hold ≥400ms → tooltip appears as floating card above slot. Tap-only = item select (target mode). Tap-and-hold is secondary; the item info is also reachable post-select via panel state.
- **Tooltip format**: `[아이템 name (i18n key item.<id>.name)]` / `[effect description (item.<id>.effect)]` / `[target: SELF|ALLY|ENEMY|GROUND]` / `[restriction: class + INT requirement if any, else omit]`.

#### 3.5.7 Active Buff Indicator (UI-GB-16 — new battle-hud.md row obligation)

- **Position**: hero polygon **upper-right corner** (upper-left already claimed by status seal icons per battle-hud.md §2.8).
- **Icon footprint**: 16×16pt.
- **Duration display**: weapon-swing glyph (e.g. `刃` or `▶`) rather than a numeric counter (ux R-1 fix — "1" is misleading since buff fires on next attack, not after 1 full turn). The glyph communicates "fires on next attack/skill".
- **Stack behaviour**: stacking forbidden per §3.2.2; new buff use **replaces** existing icon with the new buff's glyph + brief fade-blink transition (200ms) to signal overwrite. No popup warning (design intent per EC-SS-2).

#### 3.5.8 Accessibility Requirements (ux Accessibility Checklist fix)

Strategy systems must respect all 4 accessibility contracts:
1. **Touch target ≥44pt** on all inventory slot tiles + buttons (mobile + tablet) — per CLAUDE.md technical preferences.
2. **Colorblind-safe icons**: each item icon MUST be shape-distinguishable (e.g. heal_potion = drop shape; strength_scroll = star; fire_scroll = flame outline; march_scroll = arrow). No reliance on color alone — accessibility-requirements.md §6.2 pattern.
3. **Reduce-motion alternative**: panel open / close animation + active buff fade-blink must be disabled under reduce-motion toggle. Use instant transitions instead.
4. **No hover-only interactions**: tooltip-on-hover is **secondary info path only**; primary item info reachable post-select. Touch-and-hold is **not** the only way to read restrictions (mobile users without long-press capability still get info post-select).

#### 3.5.9 i18n Locale Key Convention (ux R-4 fix)

All UI strings use this naming convention:
- Item names: `item.<item_id>.name` (e.g. `item.heal_potion.name`)
- Item effects: `item.<item_id>.effect`
- Item restriction labels: `item.<item_id>.restriction_label`
- Reject messages: `item.reject.<reason_code>` — codes: `wrong_class`, `int_insufficient`, `action_spent`, `inventory_full`, `target_invalid`, `no_active_hero`
- UI surface labels: `ui.inventory.title`, `ui.inventory.empty_slot`, `ui.inventory.buff_active_label`, `ui.inventory.read_only_label`

### 3.6 Pillar #3 Protection Rules

Pillar 3 ("모든 무장에게 자리가 있다") 가 책략권 시스템의 가장 큰 risk. 다음 4개 mechanism 으로 보호:

1. **Class 제한**: 모든 책은 `usable_by_class: Array[UnitClass]` 명시. e.g. 화공권은 [INFANTRY, CAVALRY, COMMANDER] 만 (STRATEGIST 와 SCOUT 는 native fire_strategy 보유 또는 차별화 정책 — 강유의 후계자 책략 STRATEGIST 가 화공권 사용 못함은 의도).
2. **INT 임계 (v0.3 — 0-100 stat_intellect scale)**: 일부 강력한 책은 `int_requirement: int` (stat_intellect 비교). e.g. 화공권은 `stat_intellect ≥ 60` — 장비/허저/여포 (50) 거부 + 관우/황충/마초 (60) 통과. 천공 (天工) 책은 `stat_intellect ≥ 90` 만 — 제갈량 (99) / 방통 (95) / 강유 (90) 만 (Phase C+ 후보).
3. **휴대 한계 3 slot**: 한 hero 가 모든 책을 휴대 불가. "이 hero 에게 어떤 책 줄지" 의 선택 압박.
4. **Stacking 금지**: 동일 turn 에 multi-buff carry 불가 (위 §3.2.2). 새 buff 사용 시 기존 carry 덮어쓰기.

### 3.7 MVP Prototype Item List (Phase B)

**v0.2 user adjudication**: `command_scroll` DEFERRED to Phase 4+. Phase B MVP item set 4종 + Phase C extension 2종.

| ID | 한국어 | Kind | Target | Effect | Class restriction | INT req | Phase |
|----|--------|------|--------|--------|--------------------|---------|-------|
| `heal_potion` | 회복초 | immediate | SELF | HP +25 | none | none | **B 필수** |
| `strength_scroll` | 강공권 | buff | SELF | next attack/skill +50% | none | none | **B 필수** |
| `march_scroll` | 행군초 | immediate | SELF | 즉시 +2 movement (이번 turn 의 잔여 move 한정) | none | none | **B 필수** |
| `fire_scroll` | 화공권 | scroll | ALLY/ENEMY pos | fire_strategy skill 1회 발화 | INFANTRY, CAVALRY, COMMANDER 만 (STRATEGIST/SCOUT 불가 — STRATEGIST 는 native fire_strategy 보유) | `stat_intellect ≥ 60` | **B 필수** |
| `aid_potion` | 구호약 | immediate | **ALLY** (non-self) | 사정거리 Manhattan ≤3 아군 1명 HP +20 | none | none | **B+ 구현 (S94)** |
| `rally_scroll` | 독려권 | buff | **ALLY** (non-self) | 사정거리 Manhattan ≤3 아군 1명에게 next attack/skill +30% (대상의 `pending_buff` carry) | none | none | **B+ 구현 (S94)** |
| `intimidate_scroll` | 협박권 | debuff | **ENEMY** | 사정거리 Manhattan ≤3 적 1명의 next attack ×0.70 (−30%; 대상의 `pending_buff` 음수 carry) | none | none | **B+ 구현 (S97)** |
| `revive_pill` | 부활단 | immediate | ALLY (downed) | HP 50% 부활 | none | none | C extension |
| `accuracy_scroll` | 정확권 | buff | SELF | next attack accuracy +30 (또는 crit +25%) | none | none | C extension |
| ~~`command_scroll`~~ | ~~작전권~~ | — | — | **DEFERRED to Phase 4+** per S89 user adjudication (turn-queue mid-round mutation = TurnOrderRunner hard invariant; ADR required). | — | — | **Phase 4+** |

**Phase B 4 MVP items 으로 Pillar #5 입증 가능**: heal (생존 챕터의 자기 보호) + strength (다음 turn 공격 강화 — 2-turn plan) + march (이동 후 추가 이동 — 위치 puzzle) + fire (cross-class 책략 — INFANTRY 가 평소 못 쓰는 화공 사용).

**v0.4 (S94) — cross-hero ALLY 축 신설**: MVP 4종이 전부 SELF/GROUND 라 raw feedback #6 의 *"다른 장수를 도와주거나"* 축이 mechanical 0 이었음. `aid_potion` (cross-hero heal) + `rally_scroll` (cross-hero next-attack buff) 2종으로 **ALLY target 축**을 작동시킴. 둘 다 **self 제외** (`_find_ally_target_at` 가 caster 본인 배제) — self 는 heal_potion/strength_scroll 가 담당 → 역할 차별화 sharp (Pillar #3). 사정거리 = caster Manhattan ≤ ALLY_SUPPORT_RANGE(3) 의 ally-occupied 타일만 (형세 관련성 = Pillar #1 supporting). UI-GB-17 ALLY 금록 palette 사용. 구현 위치: `grid_battle_controller.gd` (`_use_item_aid_potion` / `_use_item_rally_scroll` / `_find_ally_target_at` / `get_item_target_tiles` ALLY arm) + `battle_hud.gd` (`_ITEM_TARGET_TYPE` ALLY + glyph ✚/⚑). 분배: 유비(COMMANDER, 지원 리더) 전 16챕터 + 제갈량 8챕터. windowed G-30 verify PASS (`tools/ci/g30/g30_inventory_smoke.gd -- ally`).

**v0.5 (S97) — ENEMY 교란 축 신설**: ALLY 축(S94) 이후에도 raw feedback #6 의 *"적을 교란"* 축이 mechanical 0 이었음 (모든 아이템이 SELF/ALLY/GROUND). `intimidate_scroll` (협박권, 적 next attack ×0.70) 1종으로 **ENEMY target 축**을 작동시킴. **substrate 재사용 — damage-calc 변경 0 / 새 BattleUnit 필드 0**: 대상 적의 `pending_buff` 를 음수 magnitude(0.70)로 설정 → 기존 `_resolve_pending_buff_magnitude` 가 side gate 없이 모든 attacker 에 작동(`_passive_multiplier` 하한 clamp 없음 → magnitude<1.0 이 정상 약화). kind="intimidate" 가 cleared 시그널을 `unit_pending_debuff_changed` 로 라우팅 → view 가 **금색 ▶ BuffBadge 대신 빨강 ▼ DebuffBadge** 렌더 (적이 강해진 것으로 오인 방지, raw feedback #5 visual feedback). 사정거리 = caster Manhattan ≤ ENEMY_DISRUPT_RANGE(3). UI-GB-17 ENEMY 황토(#C8874A 50%) palette 사용 (S91 arc-F 가 이미 author). 구현 위치: `grid_battle_controller.gd` (`_use_item_intimidate_scroll` / `_find_enemy_target_at` / `get_item_target_tiles` ENEMY arm / `_emit_pending_carry_cleared` kind 라우팅) + `battle_scene.gd` (`_on_unit_pending_debuff_changed` ▼ 배지) + `battle_hud.gd` (`_ITEM_TARGET_TYPE` ENEMY + glyph ⚔). 분배: 제갈량(STRATEGIST, 책략/교란) ch11-16 (march_scroll 스왑) + 방통(STRATEGIST) ch15-16 (빈 슬롯 addition). +10 test (2086→2096 PASS) + windowed G-30 verify PASS (`tools/ci/g30/g30_intimidate_smoke.gd`: ENEMY 타일 publish + 디버프 적용 ×0.70 + ▼ 배지 렌더).

---

## 4. Formulas

### 4.1 Immediate-effect: `heal_potion`
```
post_hp = min(unit.max_hp, unit.current_hp + HEAL_POTION_AMOUNT)
where HEAL_POTION_AMOUNT = 25
```
Edge: caster.current_hp == caster.max_hp 시 사용 자체 거부 (validation phase, slot 소비 안 함).

### 4.2 Buff: `strength_scroll`
```
unit.pending_buff = {
    &"kind": &"strength",
    &"magnitude": STRENGTH_SCROLL_MULT,  # default 1.50
    &"expires_at_turn": current_turn + 1,
}
# Damage calc consumption (next turn's resolve, via ResolveModifiers.pending_buff_magnitude):
# Strict gate: buff fires only if expires_at_turn > current_turn at attack time
# (qa A-2 fix — prevents same-turn buff+attack chain, which the action_token
# economy already disallows but the formula now enforces explicitly).
if attacker.pending_buff.get(&"kind", &"") == &"strength" \
   and attacker.pending_buff.get(&"expires_at_turn", 0) > current_turn:
    # GridBattleController reads magnitude into ResolveModifiers, then clears:
    resolve_mods.pending_buff_magnitude = attacker.pending_buff[&"magnitude"]
    attacker.pending_buff = {}  # consumed (use {} not null per §3.3.1)
# In DamageCalc F-DC-5, pending_buff_magnitude folds into P_mult product:
#     P_mult_pre_cap = D_mult × passives × formation × pending_buff_magnitude
#     P_mult = min(P_mult_pre_cap, P_MULT_COMBINED_CAP)  # default 1.31
```
**Cap (godot B-2 fix)**: `strength_scroll` 의 `pending_buff_magnitude` 는 F-DC-5 의 P_mult 로 편입된다. `pending_buff_magnitude × 다른 multipliers` 가 `P_MULT_COMBINED_CAP = 1.31` (damage-calc.md TK-DC-3) 를 초과하면 cap 적용. final raw damage 는 `DAMAGE_CEILING = 180` (damage-calc.md TK-DC-4) 로 다시 한 번 cap — Pillar 1 보호 유지. **별도의 MAX_RAW_DAMAGE 상수를 도입하지 않음** (v0.1 의 `MAX_RAW_DAMAGE = 200` desync 였음 — v0.2 에서 제거). `ResolveModifiers.pending_buff_magnitude` 확장은 §6.1 의 damage-calc.md rev N cross-doc obligation 으로 등재.

### 4.3 Scroll: `fire_scroll`
```
# Validation (v0.3 — stat_intellect 0-100 scale)
require attacker.unit_class in usable_by_class  # INFANTRY, CAVALRY, COMMANDER only
require attacker.stat_intellect >= int_requirement  # default 60 (= INT_BASELINE)
# Effect — caster substituted into native fire_strategy resolve path
call _resolve_skill_fire_strategy(caster=attacker, target_pos=ctx.target_pos)
# Token: action_token_spent = true (이미 declare_action 에서 처리됨)
```
**INT scaling — v0.3 reference (godot R-2 fix)**: native fire_strategy 는 `damage_per_tile = base × (1 + (caster.stat_intellect - INT_BASELINE) × INT_SCALING_RATE)` 형식 (damage-calc.md rev 2.9.4 §F-DC-X 명시). **`INT_BASELINE = 60`** (v0.3 user adjudication). `INT_SCALING_RATE ≈ 0.005` (1 stat point = +0.5% — exact 값은 damage-calc.md rev 2.9.4 의 cross-doc obligation 으로 systems-designer 가 확정). scroll 사용 시 동일 native 공식 그대로 적용 — 별도 multiplier 없음. **No double counting** — scroll 은 단지 cross-class skill grant, INT scaling 은 native skill formula 의 일부.

**예시** (stat_intellect 0-100 scale):
- 관우 (INFANTRY, stat_intellect=60): 통과 → damage = base × 1.00 (baseline)
- 황충 (ARCHER → fire_scroll 거부 class), 마초 (CAVALRY, 60): 통과 → base × 1.00
- 위연 (INFANTRY, 65): 통과 → base × 1.025 (+2.5%)
- 조운 (SCOUT → fire_scroll 거부 class — class 보호)
- 제갈량 (STRATEGIST → fire_scroll 거부 class; native fire_strategy 사용 시 base × (1 + (99-60)×0.005) = base × 1.195)
- **장비 (INFANTRY, stat_intellect=50): int_requirement 미달 → 거부** (Pillar #3 보호 — 무력형 극단 차단)

### 4.4 `march_scroll` (운동량)
```
unit.remaining_move_this_turn += MARCH_SCROLL_BONUS
where MARCH_SCROLL_BONUS = 2 (tiles)
# 즉시 effect — 이번 turn 의 잔여 move 범위에 +2 추가.
# unit.move_token_spent == true 인 경우 (이미 이번 turn 에 이동했음) 도 사용 가능
# → unit 이 다시 이동 가능 (token 재발급 효과). 단 action_token 은 이번 사용으로 소비됨.
```
Edge: action_token 이 사용된 상태 (이미 attack 함) 면 march_scroll 자체 거부 (책 사용 자체가 action 임).

### 4.5 `command_scroll` (작전권) — **DEFERRED to Phase 4+ per v0.2 user adjudication**

원본 spec (참고용, Phase 4+ 구현 시 base 로):
```
ally_target = adjacent unit with side == caster.side
require ally_target != null and !ally_target.action_token_spent
ally_target.action_token_spent = false  # nothing to do — already not spent
ally_target.move_token_spent = false    # refresh move token (영걸전 effect)
# 핵심: ally 가 이미 이 round 의 turn 을 끝낸 상태여도 작전권을 받으면 다시 행동 가능
# Implementation: turn_order_runner 가 ally 를 turn queue 에 재삽입 (현재 turn 후)
```

**Phase 4+ prerequisite (godot B-3)**: TurnOrderRunner ADR 작성 필요. 새 API 후보:
- `TurnOrderRunner.reactivate_unit(unit_id: int) -> bool` — 큐 현재 위치 직후 unit 재삽입 + action_token_spent / move_token_spent 모두 false 로 reset. invariant 확장 명시 필요 (round_started barrier 후 mid-round queue mutation 허용 조건).

Phase B 는 이 item 우회 가능 — 4 MVP items (heal/strength/march/fire) 만으로 Pillar #5 입증.

---

## 5. Edge Cases

| EC-ID | 상황 | 처리 |
|-------|-----|------|
| EC-SS-1 | Slot 다 차 있는 hero 가 새 아이템 픽업 시도 | reject (UI feedback: "inventory full"). MVP 는 chapter loot 없으므로 사실상 occurrence 0. |
| EC-SS-2 | Buff carry 중인 hero 가 새 buff 사용 | 기존 buff 덮어쓰기 (warning popup 없음 — design 의도). |
| EC-SS-3 | Buff carry 중인 hero 가 사망 → 부활 | pending_buff 유지 (death 가 buff 소거하지 않음). pending_buff 는 BattleUnit **resource data field** 이지 scene node lifecycle 에 종속 안 됨 — 따라서 polygon hide / queue_free 와 무관. **Revive 시 expires_at_turn 재계산 안 함** (qa B-2 fix): buff 는 `expires_at_turn > turn_number_of_revive` 조건 충족 시에만 발화. 즉 hero 가 turn 7 에 buff 사용 (expires_at_turn=8) → turn 7 말 사망 → turn 9 revive → turn 9 에 attack 하면 `expires_at_turn=8 > current_turn=9` false → buff 발화 안 함 + clear. Revive 자체는 action 이 아니라 buff 소비 안 함. |
| EC-SS-4 | Scroll caster 가 INT 충족 / class 불충족 | reject (UI: "이 class 는 사용 불가"). |
| EC-SS-5 | Scroll caster 가 class 충족 / INT 불충족 | reject (UI: "INT 부족 — 필요 N"). |
| EC-SS-6 | command_scroll target ally 가 이번 round 에 이미 작전권 받음 | **OUT OF SCOPE Phase B** (command_scroll DEFERRED to Phase 4+). Phase 4+ 구현 시 reject (UI: "이미 작전 받음"). |
| EC-SS-7 | fire_scroll target_pos 가 적 진영 한가운데 + caster 거리 너무 멀음 | scroll 의 range 는 native fire_strategy 와 동일 (Manhattan ≤ 3 from target_pos). caster 자신과 target_pos 의 거리 제한은 없음 — caster 가 target_pos 를 보지 못해도 (fog 미구현이라 모든 tile 가 시야) target 가능. |
| EC-SS-8 | 챕터 종료 시 사용 안 한 아이템 | discard (영구 회수, 다음 챕터 starting_inventory 로 새로 시작). |
| EC-SS-9 | Save/Load 도중 inventory 상태 | save_data 에 inventory 포함. Load 시 복원. 단 챕터 중간 save 시 사용한 아이템 차감 상태 유지. |
| EC-SS-10 | Buff 와 native skill 의 dual stacking (e.g. strength_scroll + dragon_blade) | dragon_blade 의 자체 multiplier × strength_scroll 의 1.50 = compound. 다만 damage cap 가 final cap 으로 막음. |

---

## 6. Dependencies

### 6.1 Upstream (이 시스템이 의존)
- **turn_order_runner.gd** — `ActionType` enum 에 `USE_ITEM` 추가 + `declare_action` 의 USE_ITEM arm. Action token 처리.
- **grid_battle_controller.gd** — `_on_input_action_fired(&"use_item", ctx)` handler. ctx → inventory dispatch. Damage calc 와의 buff carry 처리.
- **damage_calc.gd** (`design/gdd/damage-calc.md` rev 2.9.3 → 2.9.4 prospective) — **BINDING CROSS-DOC OBLIGATION (godot B-1)**: `ResolveModifiers` 에 `pending_buff_magnitude: float = 1.0` (multiplicative identity default — G-21 safe). `ResolveModifiers.make()` factory signature 확장. F-DC-5 P_mult 공식에 `pending_buff_magnitude` 편입: `P_mult_pre_cap = D_mult × passives × formation × pending_buff_magnitude`. P_MULT_COMBINED_CAP = 1.31 적용 후 DAMAGE_CEILING = 180 final cap. damage-calc.md §6.3 cross-reference 에 strategy-systems.md 추가 필요 (bidirectional obligation).
- **hero_database.gd** — per-hero `intelligence` (INT) stat 명시 (현재 일부 hero 만 있음 — full sweep 필요).
- **scenario_progression.gd** (chapter resource) — `starting_inventory_by_hero: Dictionary[StringName, Array[StringName]]` field 추가.
- **save_load.gd** — inventory snapshot 저장 / 복원.

### 6.2 Downstream (이 시스템에 의존)
- **battle_hud.gd** — Inventory panel UI surface. Active buff indicator.
- **input_router.gd** — `&"use_item"` action 등록 + I 키 binding. **G-32 per-state arm requirement (mandatory, godot B-4 fix)**: `&"use_item"` match arm with `_did_visible_work = true` MUST appear in BOTH `_handle_action_in_s0` (with `_active_unit_id >= 0` guard) AND `_handle_action_in_s1` (unconditional). `tools/ci/lint_input_router_action_arm_coverage.sh` (S88) fails CI if `&"use_item"` is in vocab but absent from both arm bodies — implementer must satisfy lint pre-Done.
- **skill_particle_effect.gd** — scroll-fired skill 의 particle 발화 (기존 path 재사용).
- **localization** (assets/locale/ko.po, en.po) — 아이템/책 이름 + tooltip + UI string.

### 6.3 Bidirectional cross-doc obligations checklist (Phase B blocker discipline)

| Cross-doc | Required change | Blocker? |
|-----------|-----------------|----------|
| `damage-calc.md` §6.3 + §CR-1 | Add `pending_buff_magnitude: float = 1.0` field to ResolveModifiers + F-DC-5 P_mult product extension + §6.3 bidirectional ref to strategy-systems.md. Rev N (likely 2.9.4) | **YES — same rev-N patch as Phase B code** |
| `design/ux/battle-hud.md` | Add 3 new UI-GB rows: UI-GB-15 (Inventory Panel anchor + dimensions + animation), UI-GB-16 (Active Buff Indicator — upper-right 16×16pt glyph), UI-GB-17 (Item Target Selection Overlay — 3 target_type palettes). Update §6.3 Touch Target Minimums table with 44pt inventory slot. | **YES — UI ADVISORY gate** |
| `design/ux/accessibility-requirements.md` | Add R-6 token (Item use UI accessibility — touch ≥44pt + shape-distinct icons + reduce-motion + tooltip secondary). §7 System Dependencies add Strategy Systems row. | **YES — accessibility advisory** |
| `hero-database.md` | **RESOLVED v0.3 audit**: `stat_intellect` field 가 heroes.json 의 모든 19 named heroes 에 이미 존재 (0-100 scale, ADR-0007 per `Resource.set` reflection). 별도 sweep 불필요. v0.3 에서 GDD INT 표기를 stat_intellect 직접 매핑으로 통일. AC-SS-6 fixture 는 실제 stat_intellect 값 (관우 60 / 장비 50 / 제갈량 99 등) 사용. | **RESOLVED v0.3** |
| `scenario-progression.md` | Add `starting_inventory_by_hero: Dictionary[StringName, Array]` field to ChapterDefinition resource. G-25 fix: inner Array untyped at field declaration, element type enforced at loader. | **YES — Phase B AC-SS-2 blocker** |
| `save-load.md` | Extend SaveData schema with per-hero inventory snapshot + per-hero pending_buff snapshot. Round-trip test required. | **YES — Phase B AC-SS-2 EC-SS-9 blocker** |
| `turn-order.md` | If separate doc, mention USE_ITEM action type addition. (turn_order.md is GDD #13 per systems-index; check whether ActionType enum doc lives there or in grid-battle.md) | **ADVISORY** — code edit on turn_order_runner.gd is the binding contract |
| `battle-hud.md` UI-GB-02 | Stack/dismiss interaction with new UI-GB-15 inventory panel — both share bottom-HUD anchor. Document the transition. | **YES — UI advisory** |

---

## 7. Tuning Knobs

| Knob | Default | Safe range | Affects |
|------|---------|------------|---------|
| `INVENTORY_SLOT_COUNT` | 3 | [1, 5] | hero 당 휴대 한계. 3 = 영걸전 reference. 5 = 너무 풍부 (player choice pressure 감소). 1 = 너무 제약적. |
| `HEAL_POTION_AMOUNT` | 25 | [15, 40] | heal_potion HP 회복량. max_hp 기준 ~25% baseline. |
| `STRENGTH_SCROLL_MULT` | 1.50 | [1.25, 2.00] | 강공권 attack multiplier. 1.50 = 의미있는 boost / 무쌍 안 됨 균형. |
| `MARCH_SCROLL_BONUS` | 2 | [1, 4] | march_scroll 추가 move tile. 2 = 1 tile attack range 회피 / 적 진입 마무리. |
| `ALLY_SUPPORT_RANGE` (S94) | 3 | [2, 4] | aid_potion / rally_scroll 의 cross-hero 사정거리 (Manhattan). fire_scroll FIRE_RANGE 와 동일 = 형세 관련성 (Pillar #1). 2 = 인접 위주(빡셈) / 4 = 너무 관대(위치 압박 ↓). |
| `AID_POTION_AMOUNT` (S94) | 20 | [15, 30] | 구호약 cross-hero 회복량. heal_potion(25) 보다 약간 낮음 = 원거리 지원 비용. |
| `RALLY_SCROLL_MULT` (S94) | 1.30 | [1.20, 1.50] | 독려권 cross-hero attack multiplier. strength_scroll(1.50) 보다 약함 = 지원 flavor + Pillar #3 ("강캐 단독 무쌍" 차단). |
| `ENEMY_DISRUPT_RANGE` (S97) | 3 | [2, 4] | intimidate_scroll 의 적 사정거리 (Manhattan). ALLY_SUPPORT_RANGE 와 동일 = 형세 관련성 (Pillar #1). 2 = 인접 위주(빡셈) / 4 = 너무 관대(위치 압박 ↓). |
| `INTIMIDATE_MULT` (S97) | 0.70 | [0.50, 0.85] | 협박권으로 약화된 적 next attack multiplier (< 1.0). 0.70 = −30% 의미있는 교란 / 무력화는 아님. 0.50 = 강력(거의 무효) / 0.85 = 미미. 음수 buff 로 `pending_buff` magnitude 재사용 (damage-calc 변경 0). |
| `INT_SCALING_RATE` (damage-calc.md rev 2.9.4) | 0.005 | [0.002, 0.010] | stat_intellect 1점 당 화공권 / native fire_strategy damage bonus 비율. 0.005 = stat_intellect 99 제갈량 native 가 60 baseline 보다 +19.5% 효과. |
| `BUFF_EXPIRY_TURNS` | 1 | [1, 2] | buff carry 지속. 1 = 다음 turn 의 첫 attack 까지만. 2 = future scope. |
| `COMMAND_SCROLL_PER_ROUND_LIMIT_PER_HERO` | 1 | [1, 2] | hero 당 round 당 작전권 수신 한계. 1 = 영걸전 reference. **Phase 4+ DEFER**. |
| `INT_BASELINE` (damage-calc.md rev 2.9.4) | **60** (v0.3 user adjudication) | [50, 70] | fire_strategy / fire_scroll 의 stat_intellect baseline. 60 = 보더라인 (장비/허저/여포 50 거부 + 관우/황충/마초 60 통과). 50 = 무력형 극단 포함 모두 통과 (Pillar #3 약화); 70 = 관우/마초 등 거부 (cross-class 의미 축소). |
| `INT_REQUIREMENT_THRESHOLDS` | {fire_scroll: 60, sky_book: 90 (Phase C+)} | per-item tuning | 책 별 stat_intellect 임계. 60 = MVP fire_scroll. 90 = 제갈량 (99) / 방통 (95) / 강유 (90) 한정 — 천공 책 Phase C+. |

---

## 8. Acceptance Criteria

> **v0.2 enhancement (qa-lead)**: each AC includes story-type / gate-level / concrete test-definition / required fixture / windowed risk per qa-lead AC Enhancement Table.

### AC-SS-1 (Token integration — Logic, BLOCKING):
- [ ] Unit test `tests/unit/core/turn_order_runner_use_item_test.gd`: `declare_action(USE_ITEM, {slot_idx:0, ...})` on unit with item in slot 0 asserts `action_token_spent == true` after call.
- [ ] `declare_action` with `slot_idx=3` (out of range) returns error code + `action_token_spent == false`.
- [ ] `declare_action` with `slot_idx=0` but `inventory[0] == &""` (empty slot) returns error code + `action_token_spent == false`.
- [ ] `tools/ci/lint_input_router_action_arm_coverage.sh` passes with `&"use_item"` appearing in BOTH `_handle_action_in_s0` AND `_handle_action_in_s1` arm bodies (G-32 protection).
- Required fixture: YAML — unit with 3-slot inventory, slot 0 filled.

### AC-SS-2 (Inventory load/save — Logic, BLOCKING):
- [ ] Unit test: load chapter resource with `tests/fixtures/strategy_systems/ch01_starting_inventory.yaml`, assert each hero's `inventory[i]` matches fixture.
- [ ] Same-test save/load round-trip: snapshot → save → load → assert byte-identical inventory state.
- [ ] Hero can hold 2× same item (e.g. heal_potion × 2 in slots 0+1) — fixture covers this.
- [ ] Chapter-end cleanup (EC-SS-8): simulate chapter end event, assert all hero inventories empty; load next chapter, assert starting_inventory freshly applied.
- [ ] Mid-chapter save (EC-SS-9): use one item (slot 0 → empty), save, load, assert slot 0 empty + slots 1-2 intact.
- [ ] Inventory full (EC-SS-1): chapter resource specifies 4 items for one hero; loader takes first 3, drops 4th + logs warning. Fixture covers this.
- Required fixture: `tests/fixtures/strategy_systems/ch01_starting_inventory.yaml`.

### AC-SS-3 (UI panel — UI, ADVISORY):
- [ ] Manual walkthrough doc at `production/qa/evidence/strategy_systems_ui_walkthrough.md`: tester opens panel (I key + button on mobile), clicks each slot, verifies target highlight per target_type (ALLY/ENEMY/GROUND distinct palette per §3.5.3), ESC + tap-outside-tile cancel paths, two-tap confirm for SELF items (§3.5.4), active buff indicator appears upper-right post-strength_scroll.
- [ ] Touch target ≥44pt verified on inventory slot tiles (mobile build).
- [ ] Reduce-motion toggle: panel open/close + buff blink animation disabled — verify via accessibility settings.
- [ ] Inventory panel `read-only` state when active unit's `action_token_spent == true` — slots visible but greyed.
- Required fixture: none (windowed only). **G-30 windowed risk: YES — manual evidence required.**

### AC-SS-4 (heal_potion immediate — Logic, BLOCKING):
- [ ] Unit test `tests/unit/feature/strategy_systems/heal_potion_test.gd`: `use_item(unit, "heal_potion")` with `current_hp = max_hp - 10` asserts `current_hp == max_hp` (clamp).
- [ ] Same test, `current_hp = max_hp - 30` (more than 25 below max) asserts `current_hp == max_hp - 5` (i.e. heal of exactly 25).
- [ ] Pre-condition `current_hp == max_hp` asserts reject (slot not decremented, token not spent).
- [ ] Slot decrement: pre `inventory[0] == &"heal_potion"` → post `inventory[0] == &""`.
- [ ] `action_token_spent == true` after successful use.
- Required fixture: none (inline test data).

### AC-SS-5 (strength_scroll buff carry — Logic, BLOCKING):
- [ ] Unit test: use `strength_scroll` turn N, assert `pending_buff == {&"kind": &"strength", &"magnitude": 1.50, &"expires_at_turn": N+1}` and `action_token_spent == true` same turn (no damage applied).
- [ ] Next turn (N+1) first attack resolve: assert `pending_buff_magnitude` flows into ResolveModifiers, asserting `raw_damage` multiplied by 1.50 vs identical-fixture unbuffed control; `pending_buff == {}` post-consumption.
- [ ] Same-turn buff+attack guard (qa A-2): cannot fire on turn N because `expires_at_turn=N+1 > current_turn=N` not satisfied at turn-N attack time (which never happens since action_token already spent — but unit test enforces this even with token bypass).
- [ ] Buff overwrite (EC-SS-2): use second strength_scroll while pending_buff exists, assert pending_buff replaced with new (magnitude/expires_at_turn). No popup.
- [ ] Death + revive (EC-SS-3): kill unit on turn 7 with `expires_at_turn=8`, revive on turn 9, attack on turn 10 → assert buff does NOT fire (`expires_at_turn=8 > current_turn=10` is false) and `pending_buff` cleared. Buff revive lifecycle per EC-SS-3 v0.2 spec.
- [ ] Cap (EC-SS-10): strength_scroll + dragon_blade skill compound resolve asserts `raw_damage <= DAMAGE_CEILING (180)`.
- Required fixture: `tests/fixtures/strategy_systems/buff_carry_snapshots.yaml`.

### AC-SS-6 (fire_scroll cross-class — Logic, BLOCKING):

> **v0.2 fix (qa B-3)**: class restriction direction was inverted in v0.1. Correct list of **rejecting** classes: STRATEGIST + SCOUT (per §3.7 usable_by_class = INFANTRY/CAVALRY/COMMANDER only).

- [ ] INFANTRY hero (관우 stat_intellect=60) `use_item("fire_scroll")` succeeds (class + INT both met).
- [ ] STRATEGIST hero (제갈량 stat_intellect=99) `use_item("fire_scroll")` returns class-reject — reason code `wrong_class` (제갈량 uses native fire_strategy).
- [ ] SCOUT hero (조운 stat_intellect=75) `use_item("fire_scroll")` returns class-reject — `wrong_class`.
- [ ] INFANTRY hero with `stat_intellect < 60` (장비, stat_intellect=50) `use_item("fire_scroll")` returns int-reject — `int_insufficient`.
- [ ] Damage formula identity (godot R-2): identical-caster (e.g. 관우 stat_intellect=60) native fire_strategy damage = fire_scroll damage — both call `_resolve_skill_fire_strategy` with same `attacker` argument; scroll path = native path. INT scaling owned by native formula per damage-calc.md rev 2.9.4 (INT_BASELINE=60, INT_SCALING_RATE≈0.005).
- [ ] Damage scaling sentinel: 제갈량 native fire_strategy (stat_intellect=99) damage = base × (1 + (99-60)×0.005) = base × 1.195. 관우 fire_scroll (stat_intellect=60) damage = base × 1.000.
- [ ] Range check (EC-SS-7): fire_scroll target_pos beyond Manhattan 3 from any valid origin asserts out-of-range reject identical to native fire_strategy reject.
- Required fixture: `tests/fixtures/strategy_systems/scroll_class_matrix.yaml`.

### AC-SS-7 (Pillar #3 + Pillar 1 protection — Integration + Config, BLOCKING for lint):
- [ ] `tools/ci/lint_strategy_systems_inventory_distribution.sh`: parse each chapter's `starting_inventory_by_hero`, assert no hero holds >3 slots, assert distribution across ≥5 heroes per chapter (no single-hero spam).
- [ ] Class-restriction lint: assert no chapter assigns a scroll to a hero whose class is in scroll's exclusion list (fire_scroll → not assigned to STRATEGIST/SCOUT hero).
- [ ] Cap stack test (linked from AC-SS-5 EC-SS-10): strength_scroll + dragon_blade compound damage cannot exceed DAMAGE_CEILING.
- [ ] Windowed Pillar #3 verify (AC-SS-8 linked): tester confirms no hero achieves "single-turn무쌍" using only their inventory.
- Required fixture: `ch01_starting_inventory.yaml` + cross-chapter check.

### AC-SS-8 (Windowed Pillar #5 verify — Visual/Feel, ADVISORY):

> **v0.2 fix (qa B-1)**: removed untestable "user feedback replaces prior feedback" criterion.

- [ ] Manual playtest log at `production/qa/evidence/strategy_systems_windowed_ch01.md`: tester records ≥2 item uses per battle across ≥3 of 4 chapters (ch01-04). Per-use entry: item id + reason chosen + outcome.
- [ ] Tester observation field: "did the player face a 'this turn 누구를 어떻게 도울지' decision?" — yes/no per battle, ≥75% yes target.
- [ ] Buff overwrite observation (EC-SS-2 A-2 playtest watch): record any tester complaint of "buff disappeared without warning" — if ≥1 complaint per session, escalate to design follow-up popup decision.
- [ ] Click depth check (ux A-3 playtest watch): per item use record interaction count from `unit click → effect applied`. Median ≤4 for non-SELF items, ≤5 for SELF items.
- Required fixture: none (windowed only). **G-30 windowed risk: YES — required gate.**

### AC-SS-9 (Test suite hygiene — Config/Data, ADVISORY) — converted from test AC to process AC per qa R-1:
- [ ] Smoke check: `godot --headless` test suite produces `Overall Summary` count ≥ `1996 + new_test_count`, exit 0, zero `Parse Error` / `Failed to load` stderr lines.
- [ ] Fixture path convention: `tests/unit/feature/strategy_systems/` + `tests/integration/feature/strategy_systems/` + `tests/fixtures/strategy_systems/` directories created.
- [ ] All new tests deterministic (no random seeds, no time-dependent assertions) per `.claude/docs/coding-standards.md`.
- [ ] G-21 cross-doc damage-calc test sweep complete (existing `tests/unit/damage_calc/` retroactive scan for `pending_buff_magnitude` field default = 1.0 identity-safe).

---

## Cross-References

- `design/NORTH-STAR.md` — Pillar #5 (전략적 조합) primary anchor + raw feedback #6
- `design/gdd/game-concept.md` — Genre / 영걸전 reference baseline
- `design/gdd/damage-calc.md` (rev 2.9.3) — ResolveModifiers extension obligation
- `design/gdd/hero-database.md` — per-hero INT stat (sweep 필요)
- `design/gdd/scenario-progression.md` — chapter resource starting_inventory_by_hero field
- `design/gdd/save-load.md` — inventory snapshot extension
- `production/milestones/mvp-demo-16ch.md` — Ship target redefinition (S89-S90+)
- `.claude/rules/godot-4x-gotchas.md` G-32 — InputRouter `_did_visible_work` flag 필수 (use_item action arm 추가 시)

---

## Open Questions

| OQ-ID | Question | Status |
|-------|----------|--------|
| OQ-SS-1 | Inventory transfer between heroes (건네주기)? | DEFER to Phase 4+ (post-MVP). |
| OQ-SS-2 | Enemy unit 의 item 사용 (적의 회복초 등)? | DEFER to Phase 4+. MVP enemy = no inventory. |
| OQ-SS-3 | Item loot drop during battle? | DEFER to Phase 4+. MVP = chapter starting inventory only. |
| OQ-SS-4 | Item rarity tiers (Common / Rare / Legendary)? | DEFER — MVP 는 단일 tier 만. |
| OQ-SS-5 | Item icon assets — 신규 그릴까 placeholder text 만 쓸까? | Phase B 시작 시 결정. **추천**: placeholder text + minimal procedural icon (사각형 + 색 + 글자) — assets 작업 분리. |
| OQ-SS-6 | command_scroll 이 round 의 turn queue 를 modify 하는 부분은 turn_order_runner 의 invariant 와 충돌? | **RESOLVED v0.2 (user adjudicated DEFER)** — Phase 4+ 로 defer. Phase 4+ 진입 시 ADR 작성 필요 (post: `TurnOrderRunner.reactivate_unit(unit_id)` API 추가 + round_started barrier 이후 mid-round queue mutation 허용 조건 명시). Phase B 는 command_scroll 우회. |
| OQ-SS-7 | Pillar #5 의 design test (§NORTH-STAR.md) 가 현재 5 항목이지만, 향후 6번째 (e.g. "조합의 강제력 — 단일 hero 가 모든 전투 해결 가능한가?") 가 필요한가? | OPEN — Phase B 후 playtest feedback 으로 결정. |

---

*Last updated: 2026-05-26 (S89 close — **v0.3 INT scale alignment + INT_BASELINE=60 lock**). v0.2 narrow re-review + v0.3 INT alignment 완료. 3 user adjudications (binding): panel = Option B; command_scroll = Phase 4+ DEFER; INT_BASELINE = 60. cross-doc obligations 6 → 5 (hero-database INT sweep RESOLVED v0.3). 남은 4 cross-doc obligations: damage-calc rev 2.9.4 (systems-designer in flight) / battle-hud UI-GB-15/16/17 (ux-designer completed) / accessibility R-6 (ux-designer completed) / scenario-progression starting_inventory_by_hero (Phase B implementation 시). Phase B 진입 가능 — damage-calc rev N landing 후 즉시 implementation. Review log: `design/gdd/reviews/strategy-systems-review-log.md`.*
