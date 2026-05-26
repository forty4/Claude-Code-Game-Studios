# Strategy Systems — Review Log

> **Document**: `design/gdd/strategy-systems.md`
> **System #15** in `design/gdd/systems-index.md`.
> Reviews logged in reverse chronological order.

---

## v0.3 INT scale alignment + INT_BASELINE lock (S89 arc-F, 2026-05-26)

**Driver**: Phase B pre-flight item #2 (hero-database INT sweep) audit. hero-database.md GDD specified per-hero INT field as "currently only partial" in v0.2 §6.3 cross-doc obligations. Direct audit of `assets/data/heroes/heroes.json` revealed `stat_intellect` field already exists for ALL 19 named heroes (0-100 scale, ADR-0007 per `Resource.set` reflection pattern). No sweep required — v0.2 의 "INT 5-9 abstract scale" 표기가 잘못된 추상화였고 0-100 stat_intellect 직접 사용이 정확.

**Audit table** (existing stat_intellect values, hero-database.md heroes.json):
- 제갈량 99, 방통 95, 주유 95, 강유 90, 조조 85
- 유비 75, 조운 75, 초선 75
- 손권 70, 장요 70
- 위연 65, 우금 65
- 황충 60, 관우 60, 마초 60
- 하후돈 55
- 장비 50, 허저 50, 여포 50
- 황건적 30-45

**User adjudication**: INT_BASELINE = **60** (보더라인). 무력형 극단 (50: 장비/허저/여포) 거부 + 중급 (60: 관우/황충/마초) 통과 + 위연/우금 (65) 통과 + 조운/유비/초선 (75) 이상 통과. Pillar #3 보호 (강캐 무력형 cross-class 차단) + 대부분 hero cross-class 책략 가능성 균형.

**v0.3 patch applied to strategy-systems.md**:
- Header status v0.2 → v0.3 + Change log
- §0 frontmatter user adjudication (8): INT_BASELINE=60 binding
- §3.2.3 Scroll: INT scale 0-100 통일 + 화공권 stat_intellect ≥ 60
- §3.6 Pillar #3 보호 #1+#2: class 제한 + INT 임계 stat_intellect 표기로 변경
- §3.7 prototype table fire_scroll INT req → `stat_intellect ≥ 60`
- §4.3 fire_scroll formula: stat_intellect / INT_BASELINE=60 / INT_SCALING_RATE≈0.005 + 5 hero 별 example (관우/황충/마초 통과; 위연/조운/제갈량/장비 cases)
- §6.3 cross-doc obligations: hero-database row → **RESOLVED v0.3** (sweep 불필요)
- §7 Tuning Knobs: INT_BASELINE 신규 row + INT_SCALING_RATE / INT_REQUIREMENT_THRESHOLDS 0-100 scale 로 update
- §8 AC-SS-6: fixture stat_intellect 실제 값 사용 (관우 60 / 장비 50 / 제갈량 99) + scaling sentinel 추가
- Footer updated

**Cross-doc obligation count v0.3 close-out**: v0.2 의 6 row → v0.3 의 1 active row remaining (5 of 6 RESOLVED/COMPLETED):
- ✅ **hero-database INT sweep** — RESOLVED v0.3 (sweep 불필요, stat_intellect 이미 존재).
- ✅ **damage-calc rev 2.9.4** — systems-designer spawn completed. 4 changes applied: §CR-1 ResolveModifiers `pending_buff_magnitude: float = 1.0` field + make() factory extension; F-DC-5 P_mult product extension (counter-guard added; cap chain preserved); new §F-DC-8 INT_BASELINE=60 constant + INT_SCALING_RATE=0.005 + worked examples; §6 Downstream Dependents row 6 added for strategy-systems.md v0.3+. New OQ-DC-11 flagged: existing fire_strategy uses fixed 20 dmg, no INT scaling — Phase B blocker (must choose: defer scaling OR apply formula with base_damage=20 preserving no-behavior-change at INT_BASELINE). Apex cell sentinel preserved (Cavalry 178 unchanged with default pending_buff_magnitude=1.0). 4 inconsistencies caught + fixed post-spawn (agent built on v0.2 spec; worked examples and TK-DC-10 description aligned to v0.3 0-100 scale).
- ✅ **battle-hud UI-GB-15/16/17** — ux-designer spawn completed. Inventory Panel (UI-GB-15) bottom-center modal with 44pt slot tiles + 2-beat SELF confirm. Active Buff Indicator (UI-GB-16) upper-right 16×16pt with weapon-swing glyph. Item Target Selection Overlay (UI-GB-17) 3 distinct palettes (ALLY 금록 / ENEMY 황토 / GROUND 청회 + crosshair glyph). §6.3 Touch Target table + §9 downstream table updated. 2 art-director sign-off pending items flagged (UI-GB-17 hex values; R-6-B icon shapes).
- ✅ **accessibility R-6 token** — ux-designer spawn completed. R-6-A through R-6-D sub-requirements (touch ≥44pt / shape-distinct icons / reduce-motion / tooltip secondary-path) + §7 Strategy Systems row + §9 v1.3 entry.
- ⏳ **scenario-progression starting_inventory_by_hero** — Phase B impl 시 (small ChapterDefinition field 추가; v0.3 §6.3 row 5).

**Outcome v0.3**: INT scale data 와 GDD spec 가 정확히 일치 (cross-doc grep 가능). Phase B fixture authoring 시 실제 stat_intellect 값 그대로 사용 가능. damage-calc rev 2.9.4 가 INT_BASELINE / INT_SCALING_RATE 상수 등재하면 Phase B 진입 가능.

---

## v0.2 narrow re-review close-out (S89, 2026-05-26)

**Reviewers**: 3 specialists in parallel via Agent subagent — all on v0.1 first draft.

| Specialist | Verdict | Counts | Output |
|------------|---------|--------|--------|
| godot-gdscript-specialist | **NEEDS REVISION** | 4 B + 3 R + 3 A | Engine-specific risks, G-25/G-12/G-21/G-32 gotcha sweep, Phase B order |
| ux-designer | **NEEDS REVISION** | 4 B + 4 R + 3 A | §3.5 UI Surfaces buildability, accessibility checklist, 3 panel anchor candidates |
| qa-lead | **CONCERNS** | 3 B + 4 R + 4 A | AC testability per-AC, per-EC coverage gap, fixture schema sketch, TDD path |

**Combined verdict**: NEEDS REVISION — **11 blocking findings** total.

### Convergent blockers (raised by multiple specialists)

1. **command_scroll queue mutation** — godot B-3 + qa R-3 + v0.1 OQ-SS-6 — TurnOrderRunner hard invariant. **User adjudicated: DEFER to Phase 4+**. Phase B 4 MVP items (heal/strength/march/fire) 으로 Pillar #5 입증.
2. **Buff formula spec gap / revive contradiction / cap desync** — godot B-1+B-2 + qa B-2 — multi-layer:
   - v0.1 `MAX_RAW_DAMAGE = 200` desync with damage-calc.md `DAMAGE_CEILING = 180` → v0.2 removes the new constant, uses existing cap chain.
   - `pending_buff` field typing on BattleUnit — v0.2 §3.3.1 mandates `Dictionary` (untyped) with `{}` sentinel (NOT null per G-25).
   - `ResolveModifiers.pending_buff_magnitude: float = 1.0` ABI delta — v0.2 mandates damage-calc.md rev N cross-doc obligation.
   - Revive lifecycle contradiction (EC-SS-3) — v0.2 clarifies `expires_at_turn > current_turn` strict gate.
3. **G-32 InputRouter arm coverage** — godot B-4 + qa A-4 — v0.2 §3.3.2 mandates `&"use_item"` arm in BOTH S0 (guarded) AND S1 (unconditional) with `_did_visible_work = true`.
4. **§3.5 UX panel buildability** — ux B-1 to B-4 — v0.2 fully rewrites §3.5 into 9 sub-sections:
   - §3.5.1 panel anchor (user adjudicated Option B = bottom-center modal)
   - §3.5.2 trigger/select flow
   - §3.5.3 target-selection palette (3 distinct overlays per target_type)
   - §3.5.4 SELF-target two-tap confirm
   - §3.5.5 cancel pattern (PC ESC + mobile tap-outside)
   - §3.5.6 tooltip surface (PC hover delay + mobile tap-and-hold, secondary path only)
   - §3.5.7 active buff indicator (UI-GB-16, upper-right glyph not number)
   - §3.5.8 accessibility (44pt touch / colorblind shape / reduce-motion / no hover-only)
   - §3.5.9 i18n locale key convention

### Per-specialist blockers — full inventory

**godot-gdscript-specialist (4 B)**:
- B-1: pending_buff field typing + ResolveModifiers ABI delta cross-doc obligation. → v0.2 §3.3.1 + §6.1.
- B-2: MAX_RAW_DAMAGE=200 desync with DAMAGE_CEILING=180. → v0.2 §4.2 cap chain rewrite.
- B-3: command_scroll queue mutation Phase B blocker. → v0.2 §3.7 DEFER + §4.5 DEFER + OQ-SS-6 RESOLVED.
- B-4: G-32 use_item arm coverage S0/S1 explicit. → v0.2 §3.3.2 + §6.2.

**ux-designer (4 B)**:
- B-1: Inventory panel anchor/size/z-order unspecified. → v0.2 §3.5.1 Option B (user adjudicated).
- B-2: Target highlight palette conflict with existing 4 overlays. → v0.2 §3.5.3 3 distinct palettes.
- B-3: Mobile cancel pattern unspecified. → v0.2 §3.5.5 tap-outside cancel.
- B-4: SELF-target auto-resolve unspecified. → v0.2 §3.5.4 two-tap confirm.

**qa-lead (3 B)**:
- B-1: AC-SS-8 sentiment criterion untestable. → v0.2 §8 AC-SS-8 replaced with quantified playtest log criteria.
- B-2: AC-SS-1~6 lack concrete test definitions + revive contradiction. → v0.2 §8 all AC rewritten with concrete test definitions per qa AC Enhancement Table; EC-SS-3 revive lifecycle clarified.
- B-3: AC-SS-6 fire_scroll class restriction inverted. → v0.2 §8 AC-SS-6 reversed direction per qa fix language.

### User adjudications (binding, S89)

1. **Inventory panel anchor**: Option B (bottom-center modal). UI-GB-02 action menu vocabulary 통일.
2. **command_scroll**: DEFER to Phase 4+. ADR required at Phase 4+ entry.

### Recommendations applied (selective, high-ROI)

- ux R-1: buff icon glyph (e.g. 刃 or ▶) instead of numeric "1" counter — v0.2 §3.5.7.
- ux R-2: tooltip timing (PC 300ms hover, mobile 400ms tap-and-hold, secondary path) — v0.2 §3.5.6.
- ux R-3: no-active-hero state (read-only panel for spent-token) — v0.2 §3.5.1.
- ux R-4: i18n locale key convention — v0.2 §3.5.9.
- godot R-2: fire_scroll INT formula clarification (no double-counting) — v0.2 §4.3.
- godot R-3: class_name enumeration + G-12 risk for "Item" name — flagged in Phase B order.
- qa R-1: AC-SS-9 converted from test AC to process AC — v0.2 §8 AC-SS-9.
- qa R-2: march_scroll G-30 windowed dependency — v0.2 AC-SS-3 includes movement overlay re-render windowed verify.
- qa R-4: hero_database INT sweep — v0.2 §6.3 cross-doc obligations checklist (binding pre-Phase-B).

### Advisories logged for Phase B + future

- godot A-1: buff consumption ownership (GridBattleController clears pending_buff, NOT DamageCalc) — v0.2 §3.3 last bullet.
- godot A-2: G-25 nested typed collection on `starting_inventory_by_hero` — v0.2 §3.4 + §6.3.
- godot A-3: G-19/G-21 Stage-N+1 retroactive shift on damage-calc tests — v0.2 §8 AC-SS-9 sweep requirement.
- ux A-1: buff indicator vs status seal corner collision — flagged in §3.5.7 upper-right placement.
- ux A-2: buff overwrite no warning — watch in AC-SS-8 playtest.
- ux A-3: click-depth ≤4 — watch in AC-SS-8 playtest.
- qa A-1: fixture path convention — v0.2 §8 AC-SS-9.
- qa A-2: same-turn buff guard formula — v0.2 §4.2 + §8 AC-SS-5.
- qa A-3: revive_pill missing from §4 — flagged for Phase C extension.
- qa A-4: G-32 AC coverage — v0.2 §8 AC-SS-1.

### Cross-doc obligations triggered

| Document | Required change | Phase B blocker? |
|----------|-----------------|------------------|
| `damage-calc.md` | Rev N (likely 2.9.4) — `pending_buff_magnitude` field + F-DC-5 product + §6.3 bidirectional ref + `INT_BASELINE` for fire_strategy formula | **YES — same patch as Phase B code** |
| `battle-hud.md` | 3 new rows (UI-GB-15/16/17) | **YES — UI advisory** |
| `accessibility-requirements.md` | R-6 token + §7 row | **YES — advisory** |
| `hero-database.md` | INT sweep across 14+ heroes | **YES — AC-SS-6 blocker** |
| `scenario-progression.md` | ChapterDefinition `starting_inventory_by_hero` field (G-25 untyped Array) | **YES — AC-SS-2 blocker** |
| `save-load.md` | SaveData schema extension (inventory + pending_buff snapshot) | **YES — AC-SS-2 EC-SS-9 blocker** |

### Phase B implementation order (godot-gdscript-specialist recommendation)

1. BattleUnit field additions (inventory + pending_buff) + G-14 import refresh.
2. `ActionType.USE_ITEM` enum + declare_action arm.
3. InputRouter `&"use_item"` arm (S0+S1, G-32 lint gate).
4. heal_potion immediate (AC-SS-4).
5. strength_scroll buff carry — requires `ResolveModifiers.pending_buff_magnitude` ABI extension + damage-calc.md cross-doc patch (AC-SS-5).
6. fire_scroll cross-class (AC-SS-6) — requires damage-calc.md `INT_BASELINE` clarification first.
7. march_scroll (AC-SS-4 b-variant).
8. ~~command_scroll~~ — DEFERRED.

### Final state v0.2

- 17 sub-sections under §3 (Detailed Rules)
- 5 formulas (§4.2 strength, §4.3 fire, §4.4 march, §4.5 command DEFER spec, §4.1 heal)
- 10 edge cases (EC-SS-1 ~ EC-SS-10) with v0.2 enhancements at EC-SS-3 + EC-SS-6
- 9 AC clusters (AC-SS-1 ~ AC-SS-9) all with concrete test definitions per qa enhancement table
- 8 tuning knobs (§7 unchanged)
- 7 open questions (OQ-SS-6 RESOLVED, others unchanged)
- 1 binding cross-doc obligations checklist (§6.3 new)

**Outcome**: Phase B 진입 가능. Phase B 시작 전 mandatory action: (a) damage-calc.md narrow re-review for `INT_BASELINE` clarification + `pending_buff_magnitude` field addition; (b) hero-database.md INT sweep; (c) battle-hud.md UI-GB-15/16/17 row authoring (ux-designer follow-up); (d) accessibility-requirements.md R-6 token (ux-designer follow-up).

---

## v0.1 first draft (S89, 2026-05-26)

Author: claude (S89 user-driver collaborative draft).
Driver: S89 user raw feedback #6 — KOEI 영걸전 식 전략 조합 부재. 5 user adjudications binding (MVP scope / Pillar #5 / Action token shared / 3-slot per-hero inventory / 챕터 자동 회수).
Status at draft: untested by specialist re-review.
Length: ~700 lines.
Next: narrow re-review (this v0.2 close-out entry).
