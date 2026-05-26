# Strategy Systems — 도구 · 책략권 · 행동 연쇄

> **Status**: In Design — v0.1 first draft (S89 authoring)
> **Author**: claude (S89 user-driver collaborative draft)
> **Last Updated**: 2026-05-26 (S89 close — Phase A lock 1차안)
> **Implements Pillar**: **Pillar 5 (전략적 조합 — Strategic Combinations)** primary; Pillar 1 (형세의 전술 — 책략권의 적정 사용은 적 형세 와해의 도구) supporting; Pillar 3 (역할 차별화 — 책략권 class 제한으로 강화) supporting
> **Depends on**: Turn Order (`ActionType` enum + `declare_action`), Grid Battle (per-unit context + adjacency), Damage Calc (`ResolveModifiers` field extension), Hero Database (per-hero starting inventory + class), Save/Load (per-chapter inventory state), Scenario Progression (chapter loot bundles)
> **User-adjudicated design decisions (binding, S89)**:
> (1) **MVP scope**: Strategic depth foundation ship target 안. minimum bar = 5-7 종 아이템 + 1-2 종 책략권 + UI + chapter-별 inventory + windowed verify.
> (2) **Token cost**: Item use = Action token 소모 (attack/skill/defend 와 동일 token category). 이동+아이템 OK / 이동+아이템+공격 NOT OK. Buff item 은 multi-turn carry.
> (3) **Inventory model**: per-hero (영걸전 style — Pillar #3 강화). 시작 슬롯 3개 / hero.
> (4) **Carry permanence**: 챕터 종료 시 자동 회수 + 다음 챕터 시작 시 보급. 영구 손실 없음.
> (5) **Pillar #3 보호**: 책략권 = class 제한 + 일회성 + 휴대 한계. "강캐 한 명 모든 책 들고 무쌍" 차단.

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
- **Class 제한**: 각 책은 사용 가능 class 제한 + 일부는 INT 스탯 ≥ 임계치 (Pillar #3 보호).
- 사용 시 그 skill 의 일반 발화 로직 그대로 사용 — particle / SFX / damage 계산 모두 동일.
- 예: 화공권 (fire_strategy 1회, INT ≥ 5 만), 회복권 (heal scroll, 누구나), 책략권 일반 (strategist 1회, INT ≥ 7 만).

### 3.3 Action Token Integration

- `ActionType` enum 에 `USE_ITEM` 추가 (`turn_order_runner.gd`).
- `declare_action(USE_ITEM, ctx)` 의 ctx payload: `{slot_idx: int, target_unit_id: int | -1, target_pos: Vector2i | null}`.
- Validation:
  - slot_idx 가 0..2 범위 내 + 해당 slot 에 item 존재
  - item 의 target_type 이 ctx 와 일치 (SELF / ALLY / ENEMY / GROUND)
  - item 의 class_restriction 이 caster class 와 일치 (책에만 적용)
  - item 의 int_requirement 가 caster INT 와 일치 (책에만 적용)
- Token 처리: `action_token_spent = true` 즉시 (attack 과 동일).
- 효과 발화 시점:
  - 즉시 효과: declare_action 내 동기 처리.
  - Buff 효과: caster.pending_buff = {kind, magnitude, expires_at_turn=current_turn+1} 저장. 다음 turn 의 첫 attack/skill resolve 시점 (damage_calc) 에서 consume.
  - Scroll: 해당 skill 의 `_resolve_skill_<skill_id>` 함수 호출 (기존 path 재사용).

### 3.4 Chapter Lifecycle

- **챕터 시작**: 각 hero 의 inventory 가 chapter resource 의 `starting_inventory_by_hero` 에서 로드.
  - 만약 hero 가 chapter resource 에 명시 안 됨 → default `["heal_potion"]` 1슬롯.
- **챕터 종료**: 모든 hero 의 inventory 가 자동 회수 — 다음 챕터 의 starting_inventory 가 새로 적용 (영구 누적 없음).
- **챕터 중 loot drop**: future scope (Phase 4+). MVP 는 starting inventory 만.

### 3.5 UI Surfaces

- **I 키 또는 신규 button** (battle HUD): 활성 hero 의 inventory 패널 toggle.
- **Inventory panel**: 3 slot 의 icon + 아이템 이름 + tooltip (effect 요약 + target_type + restriction).
- **선택 flow**:
  1. I 키 → 패널 open
  2. slot click (1/2/3) → target_type 에 따라:
     - SELF: 즉시 사용 (target = caster).
     - ALLY: 인접 ally 만 highlight, click 으로 선택.
     - ENEMY: 적 위치 highlight (적 책략권 / 화공 등).
     - GROUND: 지정 tile.
  3. 선택 → `declare_action(USE_ITEM, ...)` 발화.
- **Cancel**: ESC.
- **HUD buff indicator**: caster 옆 small icon (active buff 표시) + duration counter.

### 3.6 Pillar #3 Protection Rules

Pillar 3 ("모든 무장에게 자리가 있다") 가 책략권 시스템의 가장 큰 risk. 다음 4개 mechanism 으로 보호:

1. **Class 제한**: 모든 책은 `usable_by_class: Array[UnitClass]` 명시. e.g. 화공권은 [STRATEGIST, COMMANDER] 만. 무력형 (INFANTRY, CAVALRY) 은 들 수도 없음 (chapter inventory 에 distribute 시점 부터).
2. **INT 임계**: 일부 강력한 책은 `int_requirement: int` 추가. e.g. 천공 (天工) 책은 INT ≥ 9 — 제갈량 / 방통 / 강유만.
3. **휴대 한계 3 slot**: 한 hero 가 모든 책을 휴대 불가. "이 hero 에게 어떤 책 줄지" 의 선택 압박.
4. **Stacking 금지**: 동일 turn 에 multi-buff carry 불가 (위 §3.2.2). 새 buff 사용 시 기존 carry 덮어쓰기.

### 3.7 MVP Prototype Item List (Phase B)

5-7 종 아이템 + 1-2 종 책으로 MVP 입증:

| ID | 한국어 | Kind | Target | Effect | Class restriction | INT req |
|----|--------|------|--------|--------|--------------------|---------|
| `heal_potion` | 회복초 | immediate | SELF | HP +25 | none | none |
| `revive_pill` | 부활단 | immediate | ALLY (downed) | HP 50% 부활 | none | none |
| `strength_scroll` | 강공권 | buff | SELF | next attack/skill +50% | none | none |
| `accuracy_scroll` | 정확권 | buff | SELF | next attack accuracy +30 (또는 crit +25%) | none | none |
| `march_scroll` | 행군초 | immediate | SELF | 즉시 +2 movement (이번 turn 의 잔여 move 한정) | none | none |
| `fire_scroll` | 화공권 | scroll | ALLY/ENEMY pos | fire_strategy skill 1회 발화 | INFANTRY, CAVALRY, COMMANDER 만 (즉 STRATEGIST 와 SCOUT 는 못 씀; INFANTRY/CAVALRY 가 가장 흥미로움 — 그들이 평소 못 쓰는 책략) | INT ≥ 5 |
| `command_scroll` | 작전권 | immediate | ALLY (adjacent) | 인접 ally 1명에게 free action token (영걸전 "작전" 권) | none | none |

5-7 개 중 **MVP 필수 4개**: `heal_potion` / `strength_scroll` / `march_scroll` / `fire_scroll`. 나머지 3개 는 Phase B 후속.

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
    kind = "strength",
    magnitude = STRENGTH_SCROLL_MULT,  # default 1.50
    expires_at_turn = current_turn + 1,
}
# Damage calc consumption (next turn's resolve):
if attacker.pending_buff.kind == "strength" and attacker.pending_buff.expires_at_turn >= current_turn:
    raw_damage *= attacker.pending_buff.magnitude
    attacker.pending_buff = null  # consumed
```
Cap: `STRENGTH_SCROLL_MULT × eff_atk` 가 기존 damage cap (`MAX_RAW_DAMAGE = 200`) 을 초과하면 cap 에서 잘림 (Pillar 1 보호).

### 4.3 Scroll: `fire_scroll`
```
# Validation
require attacker.unit_class in usable_by_class
require attacker.INT >= int_requirement
# Effect
call _resolve_skill_fire_strategy(caster=attacker, target_pos=ctx.target_pos)
# Damage: identical to 제갈량's fire_strategy native — same formula, same cap, same particle
# Token: action_token_spent = true (이미 declare_action 에서 처리됨)
```
**핵심**: scroll 사용 시 caster 의 INT 가 책의 효과 magnitude 에 영향 — 즉 `damage_per_tile = base × (1 + (caster.INT - int_req) × 0.05)`. → INT 5 hero 가 화공권 쓰면 base damage 만, INT 9 제갈량이 쓰면 (9-5)×5% = +20% bonus. INT 보호.

### 4.4 `march_scroll` (운동량)
```
unit.remaining_move_this_turn += MARCH_SCROLL_BONUS
where MARCH_SCROLL_BONUS = 2 (tiles)
# 즉시 effect — 이번 turn 의 잔여 move 범위에 +2 추가.
# unit.move_token_spent == true 인 경우 (이미 이번 turn 에 이동했음) 도 사용 가능
# → unit 이 다시 이동 가능 (token 재발급 효과). 단 action_token 은 이번 사용으로 소비됨.
```
Edge: action_token 이 사용된 상태 (이미 attack 함) 면 march_scroll 자체 거부 (책 사용 자체가 action 임).

### 4.5 `command_scroll` (작전권)
```
ally_target = adjacent unit with side == caster.side
require ally_target != null and !ally_target.action_token_spent
ally_target.action_token_spent = false  # nothing to do — already not spent
ally_target.move_token_spent = false    # refresh move token (영걸전 effect)
# 핵심: ally 가 이미 이 round 의 turn 을 끝낸 상태여도 작전권을 받으면 다시 행동 가능
# Implementation: turn_order_runner 가 ally 를 turn queue 에 재삽입 (현재 turn 후)
```
Edge: ally_target 가 이미 받은 작전권으로 행동 중 (또는 reactivated) 이면 cumulative 안 됨 — 동일 round 내 1회 한정.

---

## 5. Edge Cases

| EC-ID | 상황 | 처리 |
|-------|-----|------|
| EC-SS-1 | Slot 다 차 있는 hero 가 새 아이템 픽업 시도 | reject (UI feedback: "inventory full"). MVP 는 chapter loot 없으므로 사실상 occurrence 0. |
| EC-SS-2 | Buff carry 중인 hero 가 새 buff 사용 | 기존 buff 덮어쓰기 (warning popup 없음 — design 의도). |
| EC-SS-3 | Buff carry 중인 hero 가 사망 → 부활 | pending_buff 유지 (death 가 buff 소거하지 않음). 단 부활단으로 부활 시 다음 turn 부터 buff carry 적용. |
| EC-SS-4 | Scroll caster 가 INT 충족 / class 불충족 | reject (UI: "이 class 는 사용 불가"). |
| EC-SS-5 | Scroll caster 가 class 충족 / INT 불충족 | reject (UI: "INT 부족 — 필요 N"). |
| EC-SS-6 | command_scroll target ally 가 이번 round 에 이미 작전권 받음 | reject (UI: "이미 작전 받음"). |
| EC-SS-7 | fire_scroll target_pos 가 적 진영 한가운데 + caster 거리 너무 멀음 | scroll 의 range 는 native fire_strategy 와 동일 (Manhattan ≤ 3 from target_pos). caster 자신과 target_pos 의 거리 제한은 없음 — caster 가 target_pos 를 보지 못해도 (fog 미구현이라 모든 tile 가 시야) target 가능. |
| EC-SS-8 | 챕터 종료 시 사용 안 한 아이템 | discard (영구 회수, 다음 챕터 starting_inventory 로 새로 시작). |
| EC-SS-9 | Save/Load 도중 inventory 상태 | save_data 에 inventory 포함. Load 시 복원. 단 챕터 중간 save 시 사용한 아이템 차감 상태 유지. |
| EC-SS-10 | Buff 와 native skill 의 dual stacking (e.g. strength_scroll + dragon_blade) | dragon_blade 의 자체 multiplier × strength_scroll 의 1.50 = compound. 다만 damage cap 가 final cap 으로 막음. |

---

## 6. Dependencies

### 6.1 Upstream (이 시스템이 의존)
- **turn_order_runner.gd** — `ActionType` enum 에 `USE_ITEM` 추가 + `declare_action` 의 USE_ITEM arm. Action token 처리.
- **grid_battle_controller.gd** — `_on_input_action_fired(&"use_item", ctx)` handler. ctx → inventory dispatch. Damage calc 와의 buff carry 처리.
- **damage_calc.gd** (`design/gdd/damage-calc.md` rev 2.9.3) — `ResolveModifiers` 에 `pending_buff_magnitude: float` field 추가. 기존 cap 들 (P_MULT_COMBINED_CAP, MAX_RAW_DAMAGE) 와 함께 multiplicative 적용.
- **hero_database.gd** — per-hero `intelligence` (INT) stat 명시 (현재 일부 hero 만 있음 — full sweep 필요).
- **scenario_progression.gd** (chapter resource) — `starting_inventory_by_hero: Dictionary[StringName, Array[StringName]]` field 추가.
- **save_load.gd** — inventory snapshot 저장 / 복원.

### 6.2 Downstream (이 시스템에 의존)
- **battle_hud.gd** — Inventory panel UI surface. Active buff indicator.
- **input_router.gd** — `&"use_item"` action 등록 + I 키 binding + per-state arm (G-32 codify 따라 _did_visible_work flag 필수).
- **skill_particle_effect.gd** — scroll-fired skill 의 particle 발화 (기존 path 재사용).
- **localization** (assets/locale/ko.po, en.po) — 아이템/책 이름 + tooltip + UI string.

### 6.3 Bidirectional notes
- `damage-calc.md` 가 본 GDD 를 §6.3 dependent system 으로 등재해야 함 (cross-doc obligation).
- `turn-order.md` (if separate doc) 도 마찬가지.
- `hero-database.md` 의 per-hero INT field 정의 update 필요.

---

## 7. Tuning Knobs

| Knob | Default | Safe range | Affects |
|------|---------|------------|---------|
| `INVENTORY_SLOT_COUNT` | 3 | [1, 5] | hero 당 휴대 한계. 3 = 영걸전 reference. 5 = 너무 풍부 (player choice pressure 감소). 1 = 너무 제약적. |
| `HEAL_POTION_AMOUNT` | 25 | [15, 40] | heal_potion HP 회복량. max_hp 기준 ~25% baseline. |
| `STRENGTH_SCROLL_MULT` | 1.50 | [1.25, 2.00] | 강공권 attack multiplier. 1.50 = 의미있는 boost / 무쌍 안 됨 균형. |
| `MARCH_SCROLL_BONUS` | 2 | [1, 4] | march_scroll 추가 move tile. 2 = 1 tile attack range 회피 / 적 진입 마무리. |
| `FIRE_SCROLL_INT_BONUS` | 0.05 | [0.02, 0.10] | INT 1점 당 화공권 damage bonus 비율. 0.05 = INT 9 제갈량 의 책 사용이 INT 5 hero 보다 +20% 효과. |
| `BUFF_EXPIRY_TURNS` | 1 | [1, 2] | buff carry 지속. 1 = 다음 turn 의 첫 attack 까지만. 2 = future scope. |
| `COMMAND_SCROLL_PER_ROUND_LIMIT_PER_HERO` | 1 | [1, 2] | hero 당 round 당 작전권 수신 한계. 1 = 영걸전 reference. |
| `INT_REQUIREMENT_THRESHOLDS` | {fire_scroll: 5, sky_book: 9} | per-item tuning | 책 별 INT 임계. 9 = 제갈량/방통/강유 한정. 5 = 중간 (관우/장비 등 무력형 도 일부 가능). |

---

## 8. Acceptance Criteria

### AC-SS-1 (Foundation 단계, Phase B 완료 시점):
- [ ] `ActionType.USE_ITEM` enum 값 추가 + turn_order_runner 의 declare_action arm 작동.
- [ ] `declare_action(USE_ITEM, ctx)` 가 정상 token 처리 (action_token_spent = true).
- [ ] `declare_action(USE_ITEM, invalid_slot)` 가 reject (slot index out of range).
- [ ] `declare_action(USE_ITEM, empty_slot)` 가 reject (slot 비어 있음).

### AC-SS-2 (Inventory 단계, Phase B 완료 시점):
- [ ] BattleUnit 에 `inventory: Array[StringName]` field (3 slot, &"" = empty).
- [ ] Chapter resource 의 `starting_inventory_by_hero` 로드 시 정확히 inventory 채워짐.
- [ ] Hero 가 inventory 에 동일 item 2개 보유 가능.
- [ ] Save / Load 사이클 후 inventory 동일하게 복원.

### AC-SS-3 (UI 단계, Phase B 완료 시점):
- [ ] I 키 (또는 button) 누르면 inventory panel open.
- [ ] Panel 에 3 slot 표시 + slot 별 item icon + tooltip.
- [ ] Slot 1/2/3 click 또는 숫자 키 → target selection mode (target_type 별로 highlight).
- [ ] ESC 키로 cancel.
- [ ] Active buff indicator 가 hero polygon 옆에 표시 (icon + 1-turn duration).

### AC-SS-4 (heal_potion immediate, Phase B 첫 prototype):
- [ ] heal_potion 사용 시 caster.current_hp += 25 (cap max_hp).
- [ ] Slot 에서 차감.
- [ ] action_token_spent = true.
- [ ] HP 가 max_hp 면 사용 reject (slot 차감 안 됨).
- [ ] Particle / SFX 발화 (sage-green pulse + heal SFX — 별도 spec).

### AC-SS-5 (strength_scroll buff multi-turn carry):
- [ ] strength_scroll 사용 turn 에는 즉시 효과 없음 + action_token 소비.
- [ ] 다음 turn 의 첫 attack/skill resolve 시 damage × 1.50.
- [ ] 사용 후 caster.pending_buff = null (consumed).
- [ ] Buff carry 중 다른 buff 사용 시 기존 덮어쓰기.
- [ ] Hero 사망 → 부활 시 buff 유지 (EC-SS-3).

### AC-SS-6 (fire_scroll cross-class, Phase B 두 번째 prototype):
- [ ] INFANTRY hero (관우, 장비) 가 fire_scroll 사용 가능 (class 충족).
- [ ] STRATEGIST hero 가 fire_scroll 사용 거부 (class 불충족 — strategist 는 native fire_strategy 사용).
- [ ] INT < 5 hero (e.g. 위연 INT=4) 가 fire_scroll 사용 거부.
- [ ] INT 9 제갈량 native fire_strategy 의 damage 가 INT 5 관우 fire_scroll damage 보다 (9-5)×0.05 = 20% 높음.
- [ ] Particle = 기존 fire_strategy native particle 재사용 (별도 spec 없음).

### AC-SS-7 (Pillar #3 protection check):
- [ ] 어떤 hero 도 단독으로 strength_scroll × 3 보유 시 turn 단독으로 무쌍 불가 — windowed playtest 로 검증.
- [ ] 모든 chapter 의 starting_inventory 가 5+ hero 에 분산되어야 함 (한 hero 에 spam 안 됨).
- [ ] 책 (scroll) 의 class_restriction 위반 시 슬롯 자체 reject (chapter 시작 시 hero 에게 책이 distribute 되는 단계에서 lint check).

### AC-SS-8 (Windowed verify, Phase B 마무리 — Pillar #5 작동 입증):
- [ ] ch01-04 에서 사용자가 windowed 로 한 챕터 진행 시 평균 ≥ 2 회 item 사용 발생 (heal / strength / scroll 등).
- [ ] 사용자 raw feedback (manual playtest): "전투의 turn 마다 선택할 게 있다" 가 "공격수단 평타뿐" 을 대체.
- [ ] Combat duration 이 strategy systems 도입 전 대비 +10-20% 증가 (사용자 사고 시간 + 사용 시간 — 의도된 효과).

### AC-SS-9 (test suite, Phase B 단계):
- [ ] tests/unit/feature/strategy_systems/ 아래 inventory + USE_ITEM action + buff carry + scroll resolution 의 unit test.
- [ ] tests/integration/strategy_systems/ 아래 chapter inventory load → use → save 의 e2e flow.
- [ ] 기존 1996 tests + 신규 tests 모두 PASS.

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
| OQ-SS-6 | command_scroll 이 round 의 turn queue 를 modify 하는 부분은 turn_order_runner 의 invariant 와 충돌? | Phase B 시작 시 turn_order_runner specialist 와 검증 필요. invariant violation 시 round_started 이후 mid-round queue mutation 의 ADR (architecture decision record) 필요. |
| OQ-SS-7 | Pillar #5 의 design test (§NORTH-STAR.md) 가 현재 5 항목이지만, 향후 6번째 (e.g. "조합의 강제력 — 단일 hero 가 모든 전투 해결 가능한가?") 가 필요한가? | OPEN — Phase B 후 playtest feedback 으로 결정. |

---

*Last updated: 2026-05-26 (S89 first draft). Phase B 시작 전 narrow re-review 권장 — godot-gdscript-specialist (token integration) + ux-designer (inventory panel UX) + qa-lead (AC-SS-1 to AC-SS-9 testability).*
