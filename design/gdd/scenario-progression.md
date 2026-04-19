# Scenario Progression System (시나리오 진행)

> **Status**: In Design — v2.0 rewrite in progress
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-18
> **Last Verified**: 2026-04-18
> **Implements Pillar**: Pillar 4 (삼국지의 숨결) primary; Pillar 2 (운명은 바꿀 수 있다) supporting
> **Supersedes**: `design/gdd/archive/scenario-progression-v1.md` (v1.0, MAJOR REVISION NEEDED per `design/gdd/reviews/scenario-progression-review-log.md`)
> **Binds to**: ADR-0001 (GameBus autoload) — `docs/architecture/ADR-0001-gamebus-autoload.md` (Accepted 2026-04-18)
> **TRs**: TR-scenario-progression-001, -002, -003 (see `docs/architecture/tr-registry.yaml`)

## Summary

Scenario Progression is the chapter-level state machine that sequences the player's journey through the 삼국지연의 storyline — loading scenario data, handing off to Grid Battle, receiving the tri-state outcome, and advancing to the next 장(章) with its echo state intact. It is the stage on which Pillar 4 (삼국지의 숨결) and Pillar 2 (운명은 바꿀 수 있다) meet.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Implements: Pillar 4 (primary), Pillar 2 (supporting) · Key deps: `Balance/Data, Grid Battle, Hero Database, Destiny Branch (provisional), Destiny State (provisional), Story Event (provisional), Save/Load (provisional)` · Binds to: `ADR-0001 GameBus autoload`

## Overview

천명역전의 한 세션은 9-beat 챕터 리듬으로 흐른다: **역사의 닻 → 과거의 메아리(Prior-State Echo) → 상황 브리핑 → 전투 준비 → 전투 → 결과 → 운명 판정 → 드러냄(Revelation) → 다음 장 전환**. Scenario Progression은 이 리듬의 지휘자로, 각 챕터 정의 파일(`assets/data/scenarios/{scenario_id}.json`, Balance/Data CR-2 소유)을 로딩하고, 비트 5에서 Grid Battle에 전투 페이로드를 넘기며, `battle_outcome_resolved(BattleOutcome)` 시그널로 돌아온 **삼상태(tri-state) 결과 `{WIN, DRAW, LOSS}`**를 받아 다음 챕터를 해석한다. 크로스-신(cross-scene) 시그널 교환은 모두 ADR-0001이 비준한 GameBus 오토로드를 통해 중계되며, Scenario는 GameBus에 5개의 확정 시그널(`chapter_started`, `battle_prepare_requested`, `battle_launch_requested`, `chapter_completed`, `scenario_complete`)과 2개의 PROVISIONAL 시그널 슬롯(`scenario_beat_retried`, `save_checkpoint_requested`)을 소유한다.

MVP는 촉한 초반부 **3–5개의 선형 챕터**로 구성되며, 각 챕터는 **사전 작성된 분기(pre-authored divergence)** 모델을 따른다 — 분기는 실시간 연쇄 계산이 아니라 작가가 기 설계한 대안 경로 중 하나를 선택하는 형태다. 패배 후 재시도는 허용되지만 무료가 아니다: 각 재시도는 **echo 상태**로 누적되어 해당 챕터의 이후 분기 판정에 영향을 미친다(echo 저장은 Destiny State 소유, 축적의 트리거는 Scenario의 `scenario_beat_retried` 방출). DRAW는 단순히 LOSS의 변형이 아니라 **자기만의 서사적 경로를 여는 제3의 결과**로 처리되며(Pillar 2), 비트 2 Prior-State Echo는 **다채널(multi-modal)** — 시각 요소(글리프/잔상) + 오디오 큐가 4–6초의 엔벨로프 안에서 함께 과거 상태를 떠올리게 한다. 1장은 축적된 과거가 없으므로 침묵하는 시각 전용 변형(silent-visual variant)으로 처리된다.

플레이어는 이 시스템의 기계적 작동을 직접 조작하지 않지만 그 효과는 직접 체감한다 — N장의 지도가 열릴 때, 지난 장의 선택이 합류 명단과 환경 라벨에 **살아 있다**는 감각이 Scenario Progression의 존재 증명이다. 이 시스템이 없으면 전투는 역사의 맥락을 잃고 Pillar 4(삼국지의 숨결)가 성립하지 않으며, 운명이 거스러질 무대도 사라진다. Player Fantasy는 Section B에서 상세화한다.

## Player Fantasy

**앵커 모먼트** — 3장 [유비 백하 전투]의 두 번째 재시도. 전투는 간신히 무승부로 끝나고 에코 카운터는 [2]로 올라간다. 운명 판정 비트(Beat 7)에서 이전에 본 적 없는 분기가 열린다: *"관우가 뒤로 빠져 백성을 먼저 대피시켰다."* 연의에도 정사에도 없는 길. 플레이어는 그 순간 깨닫는다 — **"이기지 못했지만 지지도 않았다. 그 좁은 틈으로만 들어갈 수 있는 문이 있었다."**

**느껴야 하는 것**

- **역사의 무게 (Pillar 4 — 삼국지의 숨결)**: 장과 장 사이에 이전 장의 선택이 지도, 합류 명단, 환경 라벨로 살아 있다. "1장에서 조자룡을 놓쳤기 때문에 지금 이 장이 이렇게 열렸다"는 개인적 인과의 감각 — 연의의 독자가 될 수 없는 체험.

- **재시도의 비용 (Pillar 2 — 운명은 바꿀 수 있다)**: 패배해도 다시 시도할 수 있지만 공짜가 아니다. 재시도한 비트는 에코(echo) 상태로 표시되고, 뒤의 분기 판정이 그 흔적을 읽는다. *"어렵지만 가능하게 한다. 쉬우면 드라마가 없다."* — 무료 무한 재시도는 승리의 의미를 지운다. 에코는 처벌이 아니라 이 길이 몇 번의 시도 끝에 열렸는지 기억하는 이야기의 질감이다.

- **제3의 결과 (DRAW as distinct outcome)**: {WIN, DRAW, LOSS} 삼상태. DRAW는 LOSS의 관대한 판정이 아니라 그 자체로 작가가 예비해둔 경로다 — "지지 않음"이 유일한 열쇠인 분기가 존재한다. 이는 단순히 세 가지 결과 분기가 아니라, *어떤 문은 오직 간신히 버틴 자에게만 열린다*는 약속이다.

- **사전 작성된 일탈, 개인적 반역 (Pre-authored divergence)**: 매 챕터의 분기는 실시간 연쇄 계산이 아닌 작가가 미리 그려둔 2–3개의 대안 경로다. 시스템은 카드를 뽑는 구조지만, 플레이어는 비표준(non-default) 경로를 선택했다는 사실로 자신의 반역을 확인한다. 반역은 연산되지 않고 선택된다.

**톤과 레지스터** — 담담하지만 무게 있는, 전술적이면서 따뜻한. 과장된 서사극이 아니라 장기판의 수 읽기 — 그러나 그 수는 역사의 무게를 진다.

**이 시스템이 없으면** — 위 감각들은 Scenario Progression이 장과 장을 9비트 리듬으로 엮고, 에코를 Destiny State와 연동해 기억하며, DRAW를 독립 결과로 해석하기 때문에 성립한다. 사라지면 전투는 개별 시나리오 퍼즐로 환원되고, "이기지 못했지만 지지도 않은 길"은 그저 잘못된 재시도가 된다 — Pillar 2의 반역은 무대를 잃는다.

**비교 작품 레퍼런스** — Into the Breach의 전술적 따뜻함 + Triangle Strategy의 분기 무게 + KOEI 영걸전의 장 전환 의식.

## Detailed Design

### Core Rules

**CR-1. Chapter as atomic progression unit.** 1 chapter = 1 battle + 8 surrounding ceremony beats. Chapters execute in linear order per `scenario.chapters[]`; MVP has no chapter-sequence branching (divergence happens WITHIN chapters via outcome/echo).

**CR-2. 9-beat canonical rhythm.** Every chapter follows 9 beats in fixed order:

| # | Beat | Role | Player input |
|---|------|------|--------------|
| 1 | 역사의 닻 (Historical Anchor) | Sets 演義/정사 context | Tap-to-advance (min 1s) |
| 2 | 과거의 메아리 (Prior-State Echo) | Multi-modal prior-chapter memory; Ch1 silent-visual variant | None; 4–6s envelope (min 2s before tap-to-advance) |
| 3 | 상황 브리핑 (Situation Brief) | Narrative setup; may carry DRAW-branch signaling | Tap-to-advance |
| 4 | 전투 준비 (Battle Prep) | Deployment, formation, equipment | Full agency — decision point #1 |
| 5 | 전투 (Battle) | Delegated to Grid Battle | Full agency — decision point #2 |
| 6 | 결과 (Outcome Reveal) | Displays result; retry-or-accept gate if LOSS/DRAW (min 2s before gate interactive) | Binary — decision point #3 |
| 7 | 운명 판정 (Destiny Judgment) | Branch fires from `{outcome, echo_count}`; witness gate, not choice | Tap-to-advance (min 1.5s dwell lockout) |
| 8 | 드러냄 (Revelation) | Canonical-history consequence contrast (per-branch authored) | Tap-to-advance |
| 9 | 다음 장 전환 (Chapter Transition) | Proleptic setup + echo reset | Auto-advance |

**CR-3. Tri-state outcome {WIN, DRAW, LOSS}.** Scenario accepts the tri-state determined by Grid Battle. Scenario cannot synthesize DRAW or override. No "close enough" rounding; no silent promotion.

**CR-4. Pre-authored divergence.** Each chapter defines 2–3 authored branches in its scenario data file. Branches are selected by Beat 7 state evaluation, not composed at runtime. No realtime cascade; no player branch-menu.

**CR-5. Branch selection formula (Beat 7).**

```
branch_key = chapter.branch_table.lookup({
  outcome       : Result,  // WIN | DRAW | LOSS
  echo_count    : int,     // THIS chapter's retry count (reset per chapter)
  is_draw_fallback : bool  // derived: (outcome == DRAW AND NOT chapter.author_draw_branch)
})
```

Unmatched WIN/LOSS is blocked by the authoring validator. DRAW in a non-DRAW-designated chapter triggers the `draw_fallback` tag on the WIN branch's revelation cue.

**CR-6. Echo-gated branch rule.** Echo-gated branches require `outcome == DRAW AND echo_count ≥ chapter.echo_threshold`. A clean (echo=0) first-try DRAW does NOT unlock echo-gated branches — it receives the default DRAW branch. Echo-gated branches reward the cost of struggle, not DRAW alone.

**CR-7. Echo accumulation (per-chapter).** Echo count increments by 1 on every player-confirmed retry (Beat 6 LOSS/DRAW → "Retry" → Beat 4 re-entry). Echo resets to 0 at Beat 9 (chapter transition). Echo is NOT carried across chapters for branch evaluation. The memory carried across chapters is the branch taken (via `ChapterResult` + `SaveContext`), not the retry count.

**CR-8. Retry semantics.**
- Offered only on `outcome ∈ {LOSS, DRAW}`. WIN does NOT offer retry.
- Re-enters at Beat 4 with prior deployment preserved as default (fully editable).
- Beats 1, 2, 3 do NOT re-fire on retry — they are chapter-opening ceremony, not retry markers.
- Mid-battle abandonment (Beat 5) = LOSS with `is_abandon: true`; advances to Beat 6.
- Each retry fires `scenario_beat_retried(EchoMark)` via GameBus.

**CR-9. Beat 2 Prior-State Echo multi-modal contract.**
- **Ch2+ variant**: authored visual glyph/afterimage + audio cue; combined 4–6s envelope; audio target **−18 to −12 LUFS** (mobile audibility; v1.0's ≤−24 LUFS is REJECTED as inaudible on mobile-primary).
- **Ch1 silent-visual variant**: scenario-level fixed "beginning glyph" asset only; no audio component; same 4–6s envelope.
- **Authoring**: each Ch2+ chapter authors ONE fragment keyed on the immediately preceding chapter's `{branch_path_id, echo_count_at_completion, witness_unit}` triple; writer selects 1 primary driver, optionally 1 secondary.
- **Echo depth**: N−1 only (no N−2 reads in MVP).
- **Prohibition**: no retry-count meta-commentary ("N번째 시도에") in fragment text; echo surfacing is indirect (environmental-label shift, character texture, branch-text tone).

**CR-10. Beat 7 witness gate.**
- Displays selected branch with 1.5s minimum dwell lockout before the "continue" action becomes active.
- No branch menu; no selection UI; player cannot see locked/alternate branches.
- Non-default branches receive reserved-color treatment (주홍 #C0392B + 금색 #D4A017 per art bible) to distinguish the moment.
- `destiny_branch_chosen(DestinyBranchChoice)` fires at END of Beat 7 (after player advances), not at start. Downstream systems MUST NOT read branch state before Beat 7 completes.

**CR-11. Beat 8 Revelation content contract.**
- Each chapter authors ONE Beat 8 revelation per branch (3-branch chapter → 3 Beat 8 entries).
- Reveals the canonical-history consequence (演義/정사) as contrast to the branch taken.
- If player's branch == canonical path: omit revelation OR brief acknowledgment ("역사는 이대로 흘렀다"); do not stage contrast where none exists.
- Register: plainspoken, no judgment; does not editorialize whether the player's choice was "better."
- Every Beat 8 entry must cite its 演義 chapter or 정사 passage (AC testability).

**CR-12. Beat 9 transition + echo reset + proleptic setup.**
- `chapter_completed(ChapterResult)` emitted at Beat 9 entry.
- Echo state resets to 0 as part of Beat 9 processing.
- Beat 9 authored text carries proleptic setup — what the player's branch implies for what comes next.
- If more chapters remain → advance to next chapter's LOADING → CHAPTER_START. If last chapter → SCENARIO_END with `scenario_complete(ScenarioResult)`.

**CR-13. Ch1 narrative authoring rule.** Ch1's Beat 7 branch text must read as natural story outcome, not as system invitation. NO meta-framing ("이것이 운명을 바꾸는 첫 선택입니다"). Pillar 2's rebellion thesis accumulates Ch2+; Ch1 carries the first *offer* of rebellion, discovered rather than announced. Echo-gated branches are design-invalid for Ch1 (no prior echo possible) — data validator rejects.

**CR-14. DRAW branch authoring contract.**
- Each chapter data file declares `author_draw_branch: bool`.
- `true`: DRAW branch MUST be authored; build-time validator blocks missing DRAW branch.
- `false`: DRAW falls back to the chapter's WIN branch with `draw_fallback` tag prepended to the revelation cue id; Beat 8 uses a distinct lower-stakes revelation tone.
- MVP Ch3 (유비 백하 전투) is DRAW-designated (anchor-moment reachability, Section B).
- At least ONE DRAW branch across the MVP scenario MUST be unambiguously advantageous in a dimension the player values (narrative revelation, future unit option, canonical-delta texture). DRAW cannot uniformly read as "dignified LOSS."
- DRAW authoring rubric: choose per branch — **partial salvage** (most common), **moral victory**, or **threshold** (rarest; ≤1 per scenario; the anchor-moment type).

**CR-15. Hard constraints (what the player CANNOT do).**
1. Cannot skip Beat 2 (Ch1 silent variant still runs the 4–6s envelope; min 2s dwell before tap-to-advance).
2. Cannot retry from mid-battle — mid-battle abandon = LOSS.
3. Cannot preview, select, or browse alternate branches; branches are invisible until earned.
4. Cannot undo a branch decision after Beat 9 fires; chapter result is committed to persistent state.
5. Cannot carry echo across chapters; echo resets at Beat 9.
6. Cannot convert WIN into a retry (no WIN→retry gate).
7. Cannot access echo-gated branches on a clean (echo=0) DRAW.
8. Cannot replay a completed chapter from menu — NOT in MVP scope.
9. Cannot author an echo-gated branch in Ch1 (data validator rejects).
10. Cannot save mid-battle (Save/Load domain; Scenario does not bypass).

**CR-16. Scenario-end contract.**
- On last chapter's Beat 9, `scenario_complete(ScenarioResult)` fires.
- `ScenarioResult` minimum fields: `chapter_outcomes: Array[{chapter_id, branch_path_id, echo_count_at_completion}]`, `canonical_delta: PackedStringArray` (per-scenario authored list), `scenario_path_key: String` (composite of branch ids), `total_echo: int`.
- Epilogue is authored per-`scenario_path_key`, NOT computed. Epilogue count = product of branch counts across chapters; producer must approve total authoring scope before branch count per chapter is locked.
- Closing line references `canonical_delta` — the final Pillar 4 beat ("演義에서 이 자리는 비어 있었다").

### States and Transitions

12 states (10 chapter beats + LOADING + BATTLE_LOADING sub-state + SCENARIO_END). The only backward transition is BEAT_6_RESULT → BEAT_4_PREP (retry loop). All other transitions are forward-only; no API exposes arbitrary-beat jumps.

| State | Entry action | Exit trigger | Target state |
|-------|--------------|--------------|--------------|
| LOADING | Read `assets/data/scenarios/{scenario_id}.json` for `chapters[current_index]` | `scenario_data_loaded` (internal) | CHAPTER_START |
| CHAPTER_START | Emit `chapter_started(ChapterContext)` via GameBus | Immediate | BEAT_1_ANCHOR |
| BEAT_1_ANCHOR | Present anchor text; emit CP-1 `save_checkpoint_requested(SaveContext)` | `beat_sequence_complete(1)` OR tap after min 1s | BEAT_2_ECHO |
| BEAT_2_ECHO | BeatConductor selects Ch1 silent-visual OR Ch2+ multi-modal variant; fires `beat_visual_cue_fired` (+ `beat_audio_cue_fired` for Ch2+) | `beat_sequence_complete(2)` after 4–6s envelope OR tap after min 2s | BEAT_3_BRIEF |
| BEAT_3_BRIEF | Present situation brief (may carry DRAW signaling) | `beat_sequence_complete(3)` OR tap | BEAT_4_PREP |
| BEAT_4_PREP | Open deployment UI; on retry, prior deployment pre-fills | Player confirms → emit `battle_prepare_requested` then `battle_launch_requested` | BATTLE_LOADING |
| BATTLE_LOADING (sub-state) | Await Grid Battle scene readiness | Grid Battle internal readiness hook (see Grid Battle GDD v5.0) | BEAT_5_BATTLE |
| BEAT_5_BATTLE | Delegate to Grid Battle; listen for outcome | `battle_outcome_resolved(BattleOutcome)` via GameBus; validate `BattleOutcome.chapter_id == current_chapter_id` (EC-SP-5 guard) | BEAT_6_RESULT |
| BEAT_6_RESULT | Display outcome; if LOSS/DRAW, present retry-or-accept gate after min 2s dwell | "Retry" (LOSS/DRAW only): emit `scenario_beat_retried(EchoMark)`, `echo_count++` → BEAT_4_PREP. "Accept" or WIN: `beat_sequence_complete(6)` → BEAT_7_JUDGMENT | BEAT_4_PREP OR BEAT_7_JUDGMENT |
| BEAT_7_JUDGMENT | Evaluate branch via CR-5; display teaser with min 1.5s dwell lockout; apply reserved-color treatment if non-default | On tap after lockout: emit CP-2 `save_checkpoint_requested`, then `destiny_branch_chosen(DestinyBranchChoice)` | BEAT_8_REVEAL |
| BEAT_8_REVEAL | Fire per-branch revelation cue; display canonical-history contrast (or brief acknowledgment if branch == canonical) | `beat_sequence_complete(8)` OR tap | BEAT_9_TRANSITION |
| BEAT_9_TRANSITION | `echo_count = 0`; emit CP-3 `save_checkpoint_requested`; emit `chapter_completed(ChapterResult)`; route next | Immediate | LOADING (next chapter) OR SCENARIO_END |
| SCENARIO_END | Emit `scenario_complete(ScenarioResult)`; display authored epilogue per `scenario_path_key` | Player dismisses epilogue | Return to main menu (SceneManager) |

### Interactions with Other Systems

All cross-scene communication routes through GameBus per ADR-0001.

**Grid Battle (#2, MVP) — Battle delegation**
- Scenario emits: `battle_prepare_requested(BattleContext)`, `battle_launch_requested(BattleContext)`
- Scenario consumes: `battle_outcome_resolved(BattleOutcome)`
- `BattleContext` minimum fields: `chapter_id: String`, `map_id: String`, `player_unit_ids: PackedInt64Array`, `player_commander_id: int`, `enemy_unit_ids: PackedInt64Array`, `victory_conditions: VictoryConditions`, `defeat_conditions: DefeatConditions`
- `BattleOutcome` minimum fields (per ADR-0001): `result: Result{WIN,DRAW,LOSS}`, `chapter_id: String`, `final_round: int`, `surviving_units: PackedInt64Array`, `is_abandon: bool`
- Grid Battle owns tri-state determination including DRAW (e.g., `round_cap` reached without victory/defeat). Scenario cannot override.
- Boundary: Scenario hands off at Beat 5 entry; does not observe mid-battle state.

**Destiny State (#16, VS) — Echo storage**
- Scenario emits: `scenario_beat_retried(EchoMark)` per retry
- Destiny State emits (post-write): `destiny_state_echo_added(EchoMark)`
- `EchoMark` minimum fields: `chapter_id: String`, `beat_number: int` (MVP: always 5), `retry_count: int`, `timestamp_unix: int`
- Destiny State owns `Array[EchoMark]` per-save persistence.
- Reset: current-chapter echo count derived from `filter(chapter_id == current)` resets at Beat 9 conceptually; historical EchoMarks remain archived for telemetry but are NOT read by branch gates.

**Destiny Branch (#4, MVP) — Branch evaluation**
- Scenario emits: `destiny_branch_chosen(DestinyBranchChoice)` at end of Beat 7
- Destiny Branch **EXECUTES** F-SP-1 inside DestinyBranchJudge (formula spec owned by scenario-progression §D); Destiny Branch GDD ratifies the `DestinyBranchChoice` payload shape. *(rev v2.0-patch 2026-04-19 — destiny-branch rev 1.3 Bidirectional T-1 closure per rev 1.1/1.2/1.3 convergence; wording updated from "owns the branch-table lookup logic" to remove the ambiguity that made implementers read as "reinvents F-SP-1.")*
- `DestinyBranchChoice` minimum fields (**9 fields ratified by destiny-branch rev 1.2 F-DB-4, reflected here rev v2.0-patch 2026-04-19 per destiny-branch rev 1.3 systems B-3 + narrative B-ND-1 + ux B-UX-9-1 BLOCKING convergence)**: `chapter_id: String`, `branch_key: String`, `outcome: BattleOutcome.Result`, `echo_count: int`, `is_draw_fallback: bool`, `is_canonical_history: bool` *(new rev 1.1 — Pillar 4 payload-level enforcement; F-SP-1 output must include this key, and chapter authoring schema must carry `is_canonical_history: bool` per branch-table row with exactly-one-canonical-per-chapter authoring invariant)*, `reserved_color_treatment: bool`, `is_invalid: bool` *(new rev 1.1)*, `invalid_reason: StringName` *(new rev 1.1; vocabulary of 12 entries per destiny-branch rev 1.3 F-DB-3)*
- Scenario is a CONSUMER of branch logic, not an evaluator.
- Invalid-path emission contract (per destiny-branch rev 1.2 D1 BLOCKING for #10/#16/#17 VS): when `is_invalid == true`, the signal is still emitted (AC-SP-17 exactly-one preserved); downstream subscribers MUST check `is_invalid == false` before reading ANY other field. `invalid()` factory sets `outcome = BattleOutcome.Result.LOSS` as an enum default — reading `outcome` before `is_invalid` silently processes a corrupt path as a genuine LOSS.

**Story Event (#10, VS) — Beat cue authoring + firing**
- Scenario emits: `beat_visual_cue_fired(BeatCue)`, `beat_audio_cue_fired(BeatCue)` at Beats 2 and 8 (optionally Beat 1, Beat 7 reserved-color treatment).
- `BeatCue` minimum fields: `cue_id: String`, `beat_number: int`, `chapter_id: String`, `variant: String` (e.g., `"silent_visual"`, `"draw_fallback"`)
- Ch1 silent-visual variant: BeatConductor fires `beat_visual_cue_fired` only; omits `beat_audio_cue_fired`.
- Story Event owns cue asset registry and authoring templates.

**Save/Load (#17, VS) — Persistence**
- Scenario emits: `save_checkpoint_requested(SaveContext)` at 3 checkpoints — CP-1 Beat 1 entry, CP-2 post-Beat 7 (pre-Beat 8), CP-3 Beat 9 entry.
- `SaveContext` minimum fields at CP-2: `chapter_id: String`, `outcome: Result`, `branch_key: String`, `echo_count: int`, `echo_marks_archive: Array[EchoMark]`, `flags_to_set: PackedStringArray`
- MVP Save/Load does NOT support mid-battle save; app suspension on mobile resumes from most recent CP.

**Balance/Data (#27, MVP) — Scenario data loading**
- Scenario reads `assets/data/scenarios/{scenario_id}.json` (schema owned by Balance/Data CR-2).
- Per-chapter schema: `chapter_id`, `map_id`, `author_draw_branch: bool`, `echo_threshold: int`, `branch_table`, `beat_1_text`, `beat_2_fragment`, `beat_3_text`, `beat_8_revelations[]` (per-branch), `beat_9_text`, `victory_conditions`, `defeat_conditions`.
- No runtime mutation of scenario data.

**Hero Database (#8, MVP)** — Scenario does NOT directly query. Grid Battle resolves unit stats from `player_unit_ids`/`enemy_unit_ids` in `BattleContext`.

**SceneManager (ADR-0002 pending)** — BATTLE_LOADING sub-state awaits Grid Battle scene readiness via Grid Battle's internal readiness hook (NOT a GameBus signal; stays inside Grid Battle's public API). Until ADR-0002 lands, Scenario uses a deferred one-frame wait on `battle_launch_requested` emission as a provisional guard.

## Formulas

All formulas are deterministic. Scenario Progression has no RNG and no probabilistic math; its "formulas" are predicates, table lookups, and derivations feeding branch resolution and scenario composition.

### F-SP-1. Branch key resolution (CR-5 formalized)

Resolves the authored branch for a given chapter outcome and retry state.

```
resolve_branch(chapter, outcome, echo_count) → {branch_key, is_draw_fallback, cue_tag}:

  if outcome == DRAW AND NOT chapter.author_draw_branch:
    # DRAW fallback: reuse WIN branch with distinct cue tag
    return {
      branch_key        : chapter.branch_table.match({outcome: WIN, echo_count: 0}),
      is_draw_fallback  : true,
      cue_tag           : "draw_fallback"
    }

  # Normal path — exact match on (outcome, echo_count bucket)
  let key = chapter.branch_table.match({
    outcome    : outcome,
    echo_count : echo_count      # table lists echo_count rows as ranges (e.g., 0, ≥1)
  })
  return {branch_key: key, is_draw_fallback: false, cue_tag: null}
```

**Variables:**
- `outcome`: `Result ∈ {WIN, DRAW, LOSS}`
- `echo_count`: `int` in `[0, ∞)`; practical bound ~10 (no mechanical effect beyond `echo_threshold`).
- `chapter.author_draw_branch`: `bool`
- `chapter.branch_table`: authored lookup table; MUST include one entry per `outcome ∈ {WIN, LOSS}` at minimum; DRAW entries required iff `author_draw_branch == true`; echo-gated rows expressed as `echo_count ≥ threshold`.

**Example** (Ch3 [유비 백하 전투], `author_draw_branch=true`, `echo_threshold=1`):

| Input | Output `branch_key` | `is_draw_fallback` | `cue_tag` |
|-------|---------------------|--------------------|-----------|
| `(WIN, 0)` | `WIN_baixia_default` | false | null |
| `(WIN, 3)` | `WIN_baixia_default` | false | null (echo ignored on WIN) |
| `(DRAW, 0)` | `DRAW_baixia_default` | false | null (clean DRAW, echo-gate closed) |
| `(DRAW, 1)` | `DRAW_baixia_echo` | false | null (**Section B anchor moment path**) |
| `(DRAW, 5)` | `DRAW_baixia_echo` | false | null (threshold saturated) |
| `(LOSS, 0)` | `LOSS_baixia_default` | false | null |

**Example** (Ch2 hypothetical, `author_draw_branch=false`):

| Input | Output `branch_key` | `is_draw_fallback` | `cue_tag` |
|-------|---------------------|--------------------|-----------|
| `(DRAW, 0)` | `WIN_ch2_default` | true | `"draw_fallback"` |
| `(DRAW, 2)` | `WIN_ch2_default` | true | `"draw_fallback"` (echo-gate inert when `author_draw_branch=false`) |

### F-SP-2. Echo-gate predicate (CR-6 formalized)

Determines whether an echo-gated branch is available for a given DRAW outcome.

```
is_echo_gate_open(outcome, echo_count, echo_threshold) → bool:
  return (outcome == DRAW) AND (echo_count ≥ echo_threshold)
```

**Variables:**
- `echo_threshold`: `int` in `[1, ∞)`. Value `0` is design-invalid (would open echo-gate on every DRAW, collapsing the clean-DRAW-excluded rule CR-6). Ch1 rejects any `echo_threshold` field (CR-13).
- Typical MVP range: `echo_threshold ∈ {1, 2}`; Ch3 anchor-moment chapter targets `echo_threshold = 1`.

**Example:**

| Input `(outcome, echo_count, echo_threshold)` | Output |
|------------------------------------------------|--------|
| `(DRAW, 0, 1)` | false (clean DRAW blocked) |
| `(DRAW, 1, 1)` | true (gate opens at minimum retry cost) |
| `(WIN, 5, 1)` | false (echo-gate requires DRAW) |
| `(LOSS, 3, 1)` | false (echo-gate requires DRAW) |

### F-SP-3. Echo accumulation / reset (CR-7 formalized)

```
on_player_retry(state):
  state.echo_count += 1
  emit scenario_beat_retried(EchoMark{
    chapter_id     : state.chapter_id,
    beat_number    : 5,                                 # MVP: always battle beat
    retry_count    : state.echo_count,
    timestamp_unix : Time.get_unix_time_from_system()
  })

on_chapter_transition(state):
  state.echo_count = 0
  # EchoMarks remain archived in Destiny State for telemetry (NOT read by branch gates)
```

**Variables:**
- `state.echo_count`: `int`; initialized to `0` at CHAPTER_START; incremented at Beat 6 "Retry" confirmation; reset at BEAT_9_TRANSITION entry.

**Invariant:** at BEAT_7_JUDGMENT entry, `state.echo_count == count(scenario_beat_retried emissions during current chapter)`. This value is the `echo_count` input to F-SP-1 and F-SP-2.

### F-SP-4. `scenario_path_key` composition (CR-16 formalized)

```
scenario_path_key(chapter_outcomes) → String:
  return chapter_outcomes
    .map(c => c.branch_path_id)
    .join("-")
```

**Variables:**
- `chapter_outcomes`: `Array[{chapter_id, branch_path_id, echo_count_at_completion}]`, ordered by chapter index.
- `branch_path_id`: `String`; authored-stable identifier per branch.

**Example** (3-chapter MVP playthrough hitting the anchor moment):
- Chapters resolved: `[WIN_ch1_default, DRAW_ch2_fallback, DRAW_ch3_echo]`
- `scenario_path_key` → `"WIN_ch1_default-DRAW_ch2_fallback-DRAW_ch3_echo"`

Used by `scenario_complete(ScenarioResult)` to select the authored epilogue variant.

### F-SP-5. Epilogue authoring count (scope check)

Computes the authoring cost of scenario-end epilogues; surfaced to producer before per-chapter branch counts are locked.

```
epilogue_count(chapters) → int:
  return chapters.map(c => c.branch_count).product()
  where c.branch_count = chapter.branch_table.distinct_branch_ids.count
```

**Variables:**
- `chapters`: Array of chapter definitions.
- `c.branch_count`: `int`, typically `2`–`3` per CR-4.

**Example:**

| Config | `epilogue_count` | Notes |
|--------|------------------|-------|
| 3 chapters × 2 branches | 8 | MVP floor (acceptable) |
| 3 chapters × 3 branches | 27 | MVP ceiling (producer-approve required) |
| 5 chapters × 3 branches | 243 | Out-of-scope for MVP; defer to VS |

**Constraint:** `branch_count_per_chapter` is bounded in practice by this product. Producer approves `epilogue_count` before Tuning Knobs locks per-chapter branch count.

### F-SP-6. Timing constants

| Constant | Value | Scope | Source rule |
|----------|-------|-------|-------------|
| `beat_2_envelope` | `[4.0, 6.0]` seconds (authored per chapter; hard constraint, not a tuning knob) | Beat 2 total duration | CR-9 |
| `beat_2_min_dwell` | `2.0` seconds | Beat 2 input lockout before tap-to-advance | CR-9 / CR-15 |
| `beat_1_min_dwell` | `1.0` second | Beat 1 input lockout before tap-to-advance | CR-2 |
| `beat_6_gate_delay` | `2.0` seconds | Beat 6 retry-or-accept gate interactive delay | CR-2 |
| `beat_7_dwell_lockout` | `1.5` seconds | Beat 7 "continue" action lockout | CR-10 |
| `beat_2_audio_lufs_target` | `-18.0` to `-12.0` LUFS | Beat 2 audio cue integrated loudness (mobile audibility) | CR-9 (v1.0 `≤-24 LUFS` REJECTED) |

All timing constants above are authored-fixed for MVP. They migrate to Tuning Knobs only if playtest surfaces specific issues.

## Edge Cases

All edge cases specify explicit behavior. "Handle gracefully" is not a valid specification.

### EC-SP-1. Scenario JSON load failure

**Condition**: `assets/data/scenarios/{scenario_id}.json` is missing, unreadable, or fails schema validation at LOADING state entry.

**Behavior**:
- ScenarioRunner emits internal error signal `scenario_load_failed(error_code, scenario_id)` (NOT on GameBus — stays internal to ScenarioRunner + its parent scene).
- ScenarioRunner transitions to a terminal FAULT state; no `chapter_started` emitted.
- UI layer displays platform-appropriate error dialog ("시나리오 데이터를 불러올 수 없습니다") with a "메인 메뉴" action.
- No partial state persisted; existing save checkpoints remain at their last good value.

### EC-SP-2. `chapter_id` mismatch on `battle_outcome_resolved`

**Condition**: BattleOutcome arrives while ScenarioRunner is in BEAT_5_BATTLE but `BattleOutcome.chapter_id != state.chapter_id` (stale battle completion or signal race).

**Behavior**:
- ScenarioRunner logs a warning with both chapter IDs.
- Outcome is DROPPED; state remains BEAT_5_BATTLE.
- No synthesized fallback outcome; ScenarioRunner waits for matching BattleOutcome.
- If no matching outcome arrives within `battle_outcome_timeout = 60s`, emit `scenario_beat_timeout(beat: 5, chapter_id)` internal; surface to UI as recoverable error ("전투 결과 동기화 실패 — 챕터 재시작").

### EC-SP-3. Battle outcome received in non-BEAT_5 state

**Condition**: `battle_outcome_resolved` arrives while ScenarioRunner is in any state except BEAT_5_BATTLE (stale signal replay, out-of-sequence signal).

**Behavior**:
- Signal is IGNORED silently (no warning, no error — benign stale signal per ADR-0001 deferred-connect discipline).
- ScenarioRunner state unchanged.

### EC-SP-4. Mobile app suspension / recovery per beat

**Condition**: OS-triggered app suspension at any beat.

**Behavior** (resume state = most recent written checkpoint):

| Suspended during | Most recent CP | Resume state |
|------------------|----------------|--------------|
| BEAT_1_ANCHOR entry (before CP-1 write completes) | Previous chapter's CP-3 (or scenario start) | LOADING → current chapter |
| BEAT_1_ANCHOR (post CP-1) through BEAT_6_RESULT | CP-1 | CHAPTER_START (re-play chapter from Beat 1) |
| BEAT_5_BATTLE (mid-battle) | CP-1 | CHAPTER_START (MVP Save/Load does not support mid-battle save) |
| BEAT_7_JUDGMENT dwell lockout (before CP-2 write) | CP-1 | CHAPTER_START (re-play chapter; preserves determinism of branch state inputs) |
| Post CP-2 write through BEAT_8_REVEAL | CP-2 | BEAT_8_REVEAL (branch already determined) |
| BEAT_9_TRANSITION | CP-2 or CP-3 | BEAT_8_REVEAL OR next chapter's LOADING (whichever CP is more recent) |

Rationale: CP-1 recovery re-plays the chapter up to the suspension point. For 9-beat chapters (~30–60s ceremony + 2–5 min battle), re-play cost is acceptable at MVP. VS may add CP-1.5 (Beat 4 deployment) if playtest surfaces friction.

### EC-SP-5. Grid Battle scene never becomes ready (BATTLE_LOADING timeout)

**Condition**: ScenarioRunner is in BATTLE_LOADING sub-state and no Grid Battle readiness hook fires.

**Behavior**:
- BATTLE_LOADING timeout: `battle_loading_timeout = 10s`.
- On timeout, emit `scenario_beat_timeout(beat: 5, chapter_id)` internal.
- UI displays "전투 씬 로드 실패" with two actions:
  - "재시도" — transition back to BEAT_4_PREP *without* incrementing echo (technical retry, NOT gameplay retry).
  - "메인 메뉴" — trigger save + exit.
- Retry from BATTLE_LOADING does NOT fire `scenario_beat_retried`.

### EC-SP-6. Beat 2 cue asset missing at runtime

**Condition**: BeatConductor cannot resolve `beat_2_fragment.visual_asset` or (for Ch2+) `beat_2_fragment.audio_asset` at BEAT_2_ECHO entry.

**Behavior**:
- **Visual asset missing**: SCENARIO FAULT. This is a build-time authoring error that should have been caught pre-runtime; silent suppression violates CR-9 delivery of Pillar Decision 4. Emit `scenario_fault(chapter_id, fault: "beat_2_visual_missing")`, pause ScenarioRunner, display platform error.
- **Audio asset missing (Ch2+ only)**: DEGRADE to silent-visual mode for this beat only. Log warning. Continue 4–6s envelope. Do NOT fault the scenario.
- **Audio asset missing (Ch1 silent-visual variant)**: not applicable — Ch1 authors no audio asset.

### EC-SP-7. Tap spam during dwell lockout

**Condition**: Player taps/clicks repeatedly during any min-dwell window (Beat 1, 2, 6, 7 lockouts).

**Behavior**:
- Inputs received BEFORE lockout expiry are DROPPED (no queuing).
- First input AFTER expiry triggers advancement.
- No visible feedback for dropped taps at MVP; VS may add subtle "not yet" indicator (out of scope here).

### EC-SP-8. Branch table missing a required entry

**Condition**: `chapter.branch_table` missing a WIN or LOSS entry, OR `author_draw_branch: true` without a DRAW entry.

**Behavior**:
- **Build-time**: authoring validator blocks the build (error, not warning).
- **Run-time** (if validator bypassed): at BEAT_7_JUDGMENT, emit `scenario_fault(chapter_id, fault: "branch_table_incomplete")`, pause ScenarioRunner. Do NOT synthesize fallback branch.

### EC-SP-9. Echo-gated branch declared in Ch1 data

**Condition**: Ch1 scenario data contains `echo_threshold` field or echo-gated branch rows.

**Behavior**:
- **Build-time**: authoring validator rejects Ch1 chapter (design-invalid per CR-13).
- **Run-time** (if bypassed): at BEAT_7_JUDGMENT, F-SP-2 returns false unconditionally for Ch1 (echo_count is always 0 by CR-7 + first-chapter invariant). Echo-gated entry unreachable; default branch fires. Warning logged.

### EC-SP-10. Retry confirmed, deployment changed, app suspended before battle launch

**Condition**: Player chose "Retry" at Beat 6, modified deployment in BEAT_4_PREP, then app suspended before confirming `battle_launch_requested`.

**Behavior**:
- Most recent CP is CP-1. Resume to CHAPTER_START.
- Modified deployment is NOT preserved (no CP fired for Beat 4 state in MVP).
- Echo count NOT preserved for this aborted retry attempt (the `scenario_beat_retried` signal was emitted on retry confirmation, but CP write for the incremented echo happens only at CP-2 — which never fired).
- Net effect: resume chapter cleanly with `echo=0`. The partial retry attempt is erased.
- Known MVP limitation; documented for playtest surveillance.

### EC-SP-11. Scenario completes with `total_echo == 0`

**Condition**: Player clears all chapters without any retry (clean scenario).

**Behavior**:
- Normal scenario completion. `ScenarioResult.total_echo = 0`.
- Epilogue selection proceeds per `scenario_path_key`. No special "clean run" epilogue at MVP unless explicitly authored.
- Clean-DRAW-on-every-chapter is a valid path: every DRAW was clean (echo=0), echo-gated branches never fired, every DRAW resolved to default DRAW branch (or `draw_fallback` for non-DRAW-designated chapters).

### EC-SP-12. Player interaction after `scenario_complete`

**Condition**: Player taps/inputs while SCENARIO_END state displays epilogue.

**Behavior**:
- SCENARIO_END has no internal dwell lockout in MVP (unlike Beat 7). Tap-to-dismiss is active immediately.
- On dismiss, ScenarioRunner transitions out of SCENARIO_END; SceneManager returns to main menu.
- No GameBus signal emitted on dismiss — it is a scene transition, not a scenario-domain event.

## Dependencies

### Upstream (this system depends on)

| System | Priority | Role |
|--------|----------|------|
| GameBus autoload (ADR-0001) | Accepted | Signal relay; all cross-scene communication routes through `/root/GameBus` |
| Balance/Data (#27) | MVP | Owns `assets/data/scenarios/{scenario_id}.json` schema; provides per-chapter data |
| Grid Battle (#2) | MVP | Battle delegation at Beat 5; produces tri-state `BattleOutcome{WIN,DRAW,LOSS}` |
| Hero Database (#8) | MVP | Unit stat resolution; queried by Grid Battle via `BattleContext.player_unit_ids` / `.enemy_unit_ids` (indirect dependency) |
| Destiny Branch (#4) | MVP | Owns `chapter.branch_table.match()` lookup logic (F-SP-1 implementation) and `DestinyBranchChoice` payload |
| Destiny State (#16) | VS | Owns `Array[EchoMark]` persistence; current-chapter echo aggregate read for branch gates |
| Story Event (#10) | VS | Owns cue asset registry; resolves `BeatCue.cue_id → visual/audio asset` |
| Save/Load (#17) | VS | `SaveContext` serialization / restoration; 3-checkpoint policy |
| SceneManager (ADR-0002, pending) | Foundation | Battle scene load coordination; BATTLE_LOADING sub-state await |
| Art Bible | Reference | Reserved-color definitions (주홍 #C0392B, 금색 #D4A017) consumed for Beat 7 non-default branch treatment |
| Audio Direction | Reference | Beat 2 multi-modal LUFS target (−18 to −12 LUFS) informed by mobile-primary platform constraint |

### Downstream (systems depend on this system)

| System | Interface consumed | Usage |
|--------|---------------------|-------|
| Grid Battle (#2) | `battle_prepare_requested(BattleContext)`, `battle_launch_requested(BattleContext)` | Reads `BattleContext` to load map + instantiate units |
| Destiny Branch (#4) | `destiny_branch_chosen(DestinyBranchChoice)` | Branch firing event — triggers downstream effects in world state |
| Destiny State (#16) | `scenario_beat_retried(EchoMark)` | Retry event — triggers echo persistence |
| Story Event (#10) | `beat_visual_cue_fired(BeatCue)`, `beat_audio_cue_fired(BeatCue)` | Cue presentation triggers (Beats 1, 2, 7, 8) |
| Save/Load (#17) | `save_checkpoint_requested(SaveContext)` | 3 checkpoint emissions per chapter (CP-1, CP-2, CP-3) |
| UI layer | `chapter_started`, `chapter_completed`, `scenario_complete` | HUD updates, transition animations, results screen |

### Cross-System Contracts

- **ADR-0001 (GameBus Autoload, Accepted 2026-04-18)**: Scenario Progression is one of 8 signal domains. All 7 Scenario-owned signals plus 1 inbound (`battle_outcome_resolved`) route through `/root/GameBus`. No direct scene-to-scene signal connections permitted. Two Scenario signals are PROVISIONAL (name+emitter locked, payload shape pending): `scenario_beat_retried`, `save_checkpoint_requested`. Section C + D lock the payload shapes; ADR-0001 signal table promotes them from PROVISIONAL to confirmed at next `/architecture-review`.
- **Signal rename (from ADR-0001)**: `battle_complete` → `battle_outcome_resolved` cascades to `grid-battle.md` (v5.0 pending) and `turn-order.md` (v-next pending). This GDD uses the new name exclusively.
- **TR-registry** (`docs/architecture/tr-registry.yaml`): `TR-scenario-progression-001`, `-002`, `-003` track this system's traceable requirements. Registry entry additions deferred to Task #13 (post-design).

### Bidirectional Dependency Citations Required

Per `.claude/rules/design-docs.md` ("Dependencies must be bidirectional — if system A depends on B, B's doc must mention A"), the following GDDs must cite Scenario Progression as an upstream dependency once authored or revised:

| GDD | Status | Citation action |
|-----|--------|-----------------|
| `design/gdd/grid-battle.md` | v4.0 (MAJOR REVISION NEEDED; v5.0 pending) | Must list Scenario Progression as BattleContext consumer + BattleOutcome emitter target; cite ADR-0001 signal rename |
| `design/gdd/destiny-branch.md` | Not authored (#4 MVP) | On authoring: cite Scenario Progression as source of Beat 7 branch-evaluation inputs; lock `DestinyBranchChoice` payload per CR-5 / CR-10 |
| `design/gdd/destiny-state.md` | Not authored (#16 VS) | On authoring: cite Scenario Progression as `scenario_beat_retried` emitter; own `EchoMark` struct per F-SP-3 |
| `design/gdd/story-event.md` | Not authored (#10 VS) | On authoring: cite Scenario Progression as `beat_*_cue_fired` emitter; own `BeatCue` struct + `draw_fallback` tag handling |
| `design/gdd/save-load.md` | Not authored (#17 VS) | On authoring: cite Scenario Progression as `save_checkpoint_requested` emitter; own `SaveContext` struct + 3-CP acceptance |

## Tuning Knobs

### Per-Chapter Knobs (authored in `scenarios/{scenario_id}.json`)

| Knob | Type | Safe Range | Default | Affects | Invalid Values |
|------|------|-----------|---------|---------|----------------|
| **TK-SP-1** `echo_threshold` | int | `[1, 3]` | `2` (Ch1–Ch2), `1` (Ch3+) | Gate for unlocking Pillar-2 "reversal" branches via echo-gate predicate F-SP-2. Higher = harder defiance. | `0` erases the retry-cost thesis (free reversal); `>3` makes the gate unreachable within MVP chapter lengths. |
| **TK-SP-2** `branch_count_per_chapter` | int | `[2, 3]` | `3` | Number of authored branches per chapter (default path + 1–2 alternatives). Drives Destiny Branch #4 budget. | `1` collapses to linear (breaks Pillar 2 divergence); `>3` blows authoring budget at 3–5 chapter MVP scope. |
| **TK-SP-3** `author_draw_branch` | bool | `{true, false}` | `true` for ≥1 Ch3+ chapter, `false` otherwise | Whether this chapter authors a distinct DRAW branch (vs. routing DRAW via the `draw_fallback` tag). Drives Pillar 2 "제3의 결과" promise. | N/A — both values legal; falsey for every MVP chapter erases the DRAW-as-distinct-outcome claim. |

### Scenario-Scope Knobs (authored in `scenarios/manifest.json`)

| Knob | Type | Safe Range | Default | Affects | Invalid Values |
|------|------|-----------|---------|---------|----------------|
| **TK-SP-4** `chapter_count` | int | `[3, 5]` MVP | `5` | MVP scenario length. Higher = more Pillar-4 historical span. Beyond MVP this is a production contract, not a tuning knob. | `<3` insufficient for echo accumulation to matter; `>5` blows MVP authoring budget. |
| **TK-SP-5** `beat_2_envelope` | `[float, float]` seconds | `[3.0, 7.0]` | `[4.0, 6.0]` | Beat 2 Prior-State Echo duration envelope (visual glyph fade + audio cue tail). Mobile touch/attention budget. | `<3.0s` inaudible cue tail on mobile speakers; `>7.0s` breaks pacing per ux-designer convergent verdict. |

### Safety Timeout Knobs (engine-side, `ProjectSettings` → `scenario/*`)

| Knob | Type | Safe Range | Default | Affects | Invalid Values |
|------|------|-----------|---------|---------|----------------|
| **TK-SP-6** `battle_outcome_timeout` | float sec | `[30, 120]` | `60` | Max wait from `battle_launch_requested` emit to `battle_outcome_resolved` receipt. Timeout → BATTLE_LOADING escape + EC-SP-5 error path. | `<30` fires on slow mobile devices during normal battles; `>120` strands the player past typical session length. |
| **TK-SP-7** `battle_loading_timeout` | float sec | `[5, 30]` | `10` | BATTLE_LOADING sub-state max duration (Grid Battle scene load window per ADR-0001 scope stability). Timeout → EC-SP-5. | `<5` false-positives on mid-range Android; `>30` hides real load failures. |

### Explicitly NOT Tuning Knobs (Hard Architectural Constraints)

The following values are written in the GDD/ADR and are **not user-tunable**. Changing them requires a GDD revision, not a config edit:

- **9-beat chapter rhythm** (CR-2) — altering beat count invalidates Sections B, C, H.
- **12-state machine + BATTLE_LOADING sub-state** (CR-2, Section C transition table) — structural; bound by ADR-0001 signal set.
- **3-checkpoint save policy** (CR-15) — CP-1 Beat-1-entry, CP-2 post-Beat-7, CP-3 Beat-9-entry. Contract with Save/Load #17.
- **Beat 7 dwell lockout = 1.5s** (CR-11) — witness-gate invariant per narrative-director + ux-designer convergence. Not a pacing knob.
- **Beat 2 audio target −18 to −12 LUFS** (CR-9) — mobile-audibility floor; replaces v1.0 `≤−24 LUFS` defect. Below −18 LUFS reintroduces the original review failure.
- **Reserved colors 주홍 `#C0392B` + 금색 `#D4A017`** — Art Bible lock; only Destiny Branch may use.
- **1 chapter = 1 battle** (CR-1) — atomic progression contract with Grid Battle; multi-battle chapters require a Pillar 2 redesign gate.
- **Tri-state outcome `{WIN, DRAW, LOSS}`** — payload contract on `BattleOutcome`; binary collapse reverts to v1.0 DRAW-erasure defect.
- **Echo reset = per-chapter on Beat 9** (CR-14) — cross-specialist locked 2026-04-18.
- **Clean DRAW excluded from echo-gate** (CR-8) — cross-specialist locked 2026-04-18; ensures the echo-gate stays a retry-cost gate, not a win-quality gate.

### Tuning Governance

- Per-chapter and scenario-scope knobs (TK-SP-1 through TK-SP-5) live in authored JSON and are validated at scenario load per EC-SP-8 (branch-table validator).
- Safety timeout knobs (TK-SP-6, TK-SP-7) live in `ProjectSettings` under `scenario/*` keys and apply to all scenarios.
- Any knob edit that exits the **Safe Range** column MUST cite a design rationale in the commit message or be rejected in code review.

## Visual/Audio Requirements

> **Specialist contributions** — Visual half authored by `art-director` (against Art Bible §§ 4, 5.4, 7.4–7.6); Audio half authored by `audio-director` (no audio-direction docs exist yet — marked-provisional decisions flagged in Open Questions). Open items that require follow-up decisions before asset production are captured in the **Open Questions** section at the end of this GDD as `OQ-AV-*`.

### Visual Requirements

#### V.1 Per-Beat Visual Specifications

**Beat 1 — 역사의 닻.** Full-screen parchment panel (지백 `#F2E8D4`→`#EDE0C4`) with 묵 wash border and Art Bible "이중선" frame. Palette: 묵 + 황토 only; no reserved colors. Motion: static with a single slow fade-in of the title text over 0.5s (Ease Out Cubic). Text: Noto Serif KR headline 24–28px mobile / 32–40px PC; body in Noto Sans KR 14px mobile minimum. 演義/정사 citation in 보조 텍스트 `#8B5A2B` at 12px mobile (e.g., `《三國演義》 제42회`).

**Beat 2 — 과거의 메아리.** Dark 묵 field (`#1C1A17` at 70–80% opacity over preceding Beat 1 panel) with a centered glyph-afterimage. Palette restricted to 묵, 지백 ghost tones, 황토 environmental labels; **no reserved colors**. Detailed contract in §V.2.

**Beat 3 — 상황 브리핑.** Scroll/parchment panel with mood shifted to strategic register (Art Bible 상태 2 — 청회 cool light, tactical tension). 청회 `#5C7A8A` wash at 10–15% opacity behind text panel. No reserved colors. Motion: panel slides in from bottom 8–12px over 120ms (Ease Out Cubic), then static. DRAW-branch chapters may use environmental-label register shift in prose (no distinct color signal).

**Beat 6 — 결과.** Three visual states from the tri-state result:
- **WIN**: Standard 황토/청회 field, calm declarative result title (`#2A2620`). Retry/accept gate inactive for 2s min dwell.
- **DRAW**: Same palette as WIN but weight/tone distinct. Must NOT be visually indistinguishable from LOSS (v1.0 defect risk). **Never reserved colors** (those belong to Beat 7 only).
- **LOSS**: Desaturation step per Art Bible 상태 6; 먹 wash slightly expanded. Not full grayscale (reserved for 비극 path at Beats 7/8). Retry/accept gate interactive after 2s min dwell.

Motion: panel appears immediately, result label fades in 200ms, gate UI slides from bottom at 2s (Ease Out Cubic).

**Beat 7 — 운명 판정.** Highest-stakes visual surface. HUD suppressed to 0% opacity; full-screen 묵 dark panel takes over (Art Bible § 7.6 "Phase 2 판정"). Witness commander's 반신 portrait in 운명態 (256×256px mobile / 512×512px PC) at center. Branch text in Noto Serif KR bold. **Reserved-color treatment for non-default branches per CR-10** detailed in §V.3. Motion: 묵 베일 wipes top-to-bottom over 400ms (수묵 번짐 edge); 1.5s dwell lockout before continue becomes active; on tap-to-advance, dissolves 200ms.

**Beat 8 — 드러냄.** Full-width parchment contrast band anchored near bottom third of screen (distinct from main narrative panel above). Citation 《三國演義》 제42회 or 《三國志》 蜀書 先主傳 in bracket label, 3차 단선 1px 묵 border, 보조 텍스트 color. Non-canonical branches: band at full opacity with canonical statement. Canonical branches: band omitted or reduced to single "역사는 이대로 흘렀다" line at 40% opacity (비활성). 運命態 portrait from Beat 7 carries forward at reduced scale. Motion: contrast panel slides up from bottom 150ms after main revelation text settles (sequential); citation text fades in at +300ms for dramatic pause.

**Beat 9 — 다음 장 전환.** Auto-advancing; no input except epilogue-tail dismiss. Full-screen 황토/지백 scroll surface (Art Bible 상태 7). Proleptic text in Noto Sans KR body weight (lighter register than Beats 1/7). Motion: 500ms eased cross-fade from Beat 8 surface. No reserved colors. Final chapter adds 인장 stamp (chapter count seal) before transitioning to SCENARIO_END epilogue screen.

#### V.2 Beat 2 Prior-State Echo — Visual Contract

**Glyph design intent.** Single authored seal-impression / brushstroke abstraction (not illustrative), ~96×96px mobile / 128×128px PC, centered on dark field. Drawn in Art Bible 수묵 line style — evocative, closer to 印章 than portrait. Surrounding the glyph, a faint environmental-label echo may appear (2–3 characters, 12px, 지백 at 30% opacity) — indirect echo-state surfacing per CR-9.

**Ch1 silent-visual variant.** Fixed campaign-opening glyph (e.g., 涿郡). No audio companion (AC-SP-6 contract). To compensate for absent audio, Ch1 glyph holds at peak luminance for **~60% of envelope** versus **~40% for Ch2+** (Ch2+ can ride audio tail for extended presence). No secondary echo-label text for Ch1 (no echo_count to surface).

**Fade curve within [4.0, 6.0]s envelope.**

| Phase | Duration share | Curve |
|-------|----------------|-------|
| Fade-in | ~20% | Ease Out Cubic |
| Hold at peak opacity | Ch2+ ~40% / Ch1 ~60% | Linear |
| Fade-out | ~20–30% | Ease In Cubic |

> **Flagged as `OQ-AV-1`** — curve derived from Art Bible § 7.4 UI animation principle; needs formal art-director + ux-designer sign-off.

**Mobile contrast.** Glyph peak luminance ≥ 80% white value (near 지백 `#F2E8D4`) against 묵 scrim (`#1C1A17` at 70–80% opacity) → luminance ratio ≈ 14:1 (well above WCAG AA). The 묵 field MUST be applied as a dark scrim (not a scene cut) so contrast is screen-content-independent. Secondary echo-label text at 지백 30% opacity over scrim is intentionally below WCAG AA — acceptable as ambient atmosphere, not information UI.

#### V.3 Reserved Color Protocol

Per Art Bible § 4 "Destiny Bleeds Once" principle:

| Color | Hex | Permitted Beats | Treatment |
|-------|-----|-----------------|-----------|
| 주홍 (朱紅) | `#C0392B` | **Beat 7 non-default branches only** | 삼중선 outer line (2px), screen-edge vignette (10–15% bleed), branch title text color |
| 금색 (金色) | `#D4A017` | **Beat 7 echo-gated branches only** (secondary accent) | Narrow horizontal accent line beneath branch text; 삼중선 inner line (0.5px) |

**Beats 1, 2, 3, 6, 8, 9: both reserved colors are unconditionally prohibited.** Any asset containing `#C0392B` or `#D4A017` (±8% luminance / ±10° hue) for these beats is rejected.

**Beat 7 default WIN branches**: standard 묵 panel, 기본 텍스트 `#2A2620`, no vignette. Absence of reserved colors is the affirmative signal. Enforced at asset level via `DestinyBranchChoice.reserved_color_treatment` flag (see Section C interactions).

**Signal semantics**:
- 주홍 alone → non-default branch (divergence via any means)
- 주홍 + 금색 accent → echo-gated branch (DRAW + prior retries; the anchor-moment fingerprint)

#### V.4 Mobile Performance Constraints

**Draw call budget per beat** (scenario ceremony beats total budget ~90 of the <500 mobile 2D ceiling):

| Beat | Max draw calls | Notes |
|------|----------------|-------|
| 1 | ≤ 5 | Static panel + text |
| 2 | ≤ 20 | Glyph + opacity tween + scrim; environmental-label echo counted here |
| 3 | ≤ 5 | Static panel + text |
| 6 | ≤ 10 | Three outcome states; desaturation is shader pass, not particles |
| 7 | ≤ 30 | 주홍 vignette (shader), portrait, text panel, 삼중선 border; echo variant adds 금 accent |
| 8 | ≤ 15 | Smaller portrait + main panel + contrast citation band |
| 9 | ≤ 5 | Scroll + text + cross-fade |

> **Flagged as `OQ-AV-2`** — needs technical-artist validation against Godot 4.6 CanvasItem batching on mobile target devices before lock.

**Texture resolutions**: Beat 2 glyph 128/256 (mobile/PC); Beat 7/8 반신 portrait 256×256; Beat 8 contrast panel 1024×256 tiled; Beat 1/3/9 scroll 1024×1024 shared atlas; Beat 7 dark scrim shader (no texture).

**Shader fallbacks** (low-end mobile path):
- Beat 6 LOSS desaturation → fallback: semi-transparent 묵 overlay at 30% opacity
- Beat 7 주홍 vignette → fallback: 8-frame pre-baked alpha sprite (eliminates runtime shader at cost of one extra draw)
- Beat 7 portrait 금색 border glow → fallback: pre-rendered portrait variant with baked glow layer

> **Flagged as `OQ-AV-3`** — shader vs. pre-baked decisions delegated to technical-artist + godot-shader-specialist.

**Art Bible § 7.4 prohibition**: no ambient particle effects in Beats 1, 2, 3, 6, 8, 9. Beat 7 is the sole context for any particle use, and even there restraint is required.

#### V.5 Asset Inventory (5-chapter MVP upper bound)

| Category | Count |
|----------|-------|
| Shared panel / scroll surfaces | 4 |
| Beat 2 echo glyphs (1 Ch1 fixed + 4 Ch2–5, ×2 resolutions) | 10 |
| Beat 7 destiny border / vignette / accent | 4–5 |
| Beat 7 commander 운명態 portraits (1 per chapter × 2 variants) | ~10 |
| Chapter completion 인장 seals | 5 |
| Epilogue scroll | 1 |
| **Total texture assets** | **~35** |

Excludes audio (below), shader files (→ technical-artist), authored text data. Portrait count is the primary production risk — confirm witness commander assignments per chapter before authoring (→ producer).

**Additional open items**: `OQ-AV-4` (Art Bible missing Beat 2 glyph style guide — production blocker); `OQ-AV-5` (Beat 8 contrast panel — shared atlas vs. dedicated strip).

---

### Audio Requirements

#### A.1 Per-Beat Audio Specifications

| Beat | Character / Palette | Stem | LUFS target | Envelope | Tag |
|------|---------------------|------|-------------|----------|-----|
| 1 | 거문고 or 가야금 low register, no percussion, no fill | 2.0–3.0s non-looping stinger | **−20 LUFS** | Fires on entry; completes within 1.0s min dwell | 역사의 시작 |
| 2 | 해금 (processed echo of prior chapter's Beat 1 tonality) | Attack 0.5–1.0s, peak 2.0–2.5s, decay through envelope | **−15 LUFS ±1** (in [−18, −12]) | 4.0–6.0s authored | 이전 장의 잔향 |
| 3 | 단소 or 태평소 restrained mid-register + light 장구 60–70 BPM | Seamless looping bed, <8s loop | **−20 LUFS** | Player-controlled | 전술적 각성 |
| 6 | WIN = clean 징 ring; DRAW = dampened 징 + 해금 suspension; LOSS = muted 징 + silence | 3.0–4.0s non-looping per variant | **−16 LUFS** per variant | Over 2.0s gate delay | 결과의 울림 |
| 7 | Default: near-silent 가야금 single stroke. Non-default / echo-gated: 해금 modal-shift phrase | 2.0–3.5s non-looping | **−22 LUFS** default / **−18 LUFS** reversal | Heard within 1.5s dwell lockout | 운명이 갈라지는 순간 |
| 8 | 거문고 single line, low room reverb | 6.0–10.0s pad; 0.3s duck on advance | **−22 LUFS** | Player-controlled | 역사의 그림자 |
| 9 | 대금 melody over 가야금 pedal, 4–6 bars @ ~80 BPM | 8.0–12.0s one-shot | **−20 LUFS** | Auto-advance | 장을 넘김 |

**All cues**: true-peak ceiling **−1.0 dBTP**. Mono-authored, stereo-placed centered on the bus (phone speaker realism).

#### A.2 Beat 2 Prior-State Echo — Full Audio Contract

**Instrumental intent.** 해금 processed with short room reverb (medium, 1.2–1.8s decay) and optional ±8¢ pitch flutter conveying instability of memory. Source material: modal fragment derived from the prior chapter's Beat 1 stinger — recognizably related in interval content, not an exact quote. Per-chapter authored asset.

**Integrated loudness target: `−15 LUFS ±1`** within the mandatory **`[−18.0, −12.0] LUFS`** band per CR-9 + AC-SP-37.

*Rationale*: Mobile bottom-firing mono speakers roll off below ≈−20 LUFS in short cues. v1.0's `≤−24 LUFS` was inaudible in ambient environments (commute, café) — documented review failure. −18 LUFS is audibility floor; −12 LUFS ceiling preserves restrained 담담한 register. `−15 LUFS` gives 3 LUFS headroom in each direction for transient variation without triggering QA blocking defect.

**Envelope detail**:

| Time | Behavior |
|------|----------|
| 0.0s | Silence; visual glyph fades in |
| 0.5–1.0s | Audio attack begins (0.3–0.5s onset) |
| 2.0–2.5s | Peak LUFS; haegeum phrase at clearest |
| 2.5–4.0s | Natural decay + reverb tail |
| 4.0–6.0s (authored) | Silence or < −40 dBFS before tap-to-advance |

The 2.0s minimum dwell guarantees peak is heard. Cue MUST complete (phrase ended, reverb substantially decayed) by 4.0s so the minimum-envelope case doesn't truncate audible content.

**True-peak ceiling `−1.0 dBTP`** (prevents inter-sample clipping in AAC 128kbps streaming / OGG quality-4 on-device). Godot's Vorbis import can produce inter-sample peaks beyond 0 dBFS → margin non-negotiable. Every Beat 2 asset must pass `ebur128` true-peak scan before delivery.

**Ch1 silent-visual variant — `beat_audio_cue_fired` MUST NOT emit.** BeatConductor branches on `BeatCue.variant == "silent_visual"` and suppresses the signal entirely. Any null-asset or placeholder emission is a contract violation. AC-SP-6 explicitly tests for signal absence on Ch1. Authoring validators must reject any `beat_2_fragment.audio_asset` field in Ch1 scenario data (per CR-13).

**Mono authoring.** Phone internal speakers are effectively mono; stereo imaging is lost on speaker playback and unreliable on budget BT earbuds. Mono centered on stereo bus is phase-coherent, survives BT mono downmix, loses nothing on iOS/Android internal speakers. Reverb's stereo wet signal must sum to mono without phase cancellation — verify with DAW mono-sum test before delivery.

#### A.3 Beat 9 Chapter Transition Music

Proleptic ceremony — forward-moving, neither triumphant nor mournful. 대금 + 가야금 pedal, 8.0–12.0s non-looping. Final-chapter variant (12.0–16.0s, more conclusive resolution) may be authored if scenario-end routing requires distinct close — scope flagged as `OQ-AV-8` (scenario-close variant in MVP or deferred to VS).

**Beat 8 → Beat 9 crossfade**: Beat 8 pad ducks at **−6 dB/s** starting BEAT_9_TRANSITION entry; Beat 9 fades in over 1.0s. No hard cut.

#### A.4 Mix Bus Structure

```
Master
├── ScenarioBus               (scenario ceremony + beat cues)
│   ├── ScenarioMusicBus      (Beats 1, 3, 8, 9 beds)
│   └── ScenarioCueBus        (Beats 2, 6, 7 stingers)
├── GridBattleBus             (Grid Battle-owned; Scenario MUST NOT touch)
└── UiBus                     (UI sfx, error dialogs)
```

**Beat 5 handoff (Grid Battle boundary)**: on BEAT_5_BATTLE entry, BeatConductor sets `ScenarioBus` to `−INF dB` (**mute, not duck** — ceremony has no role during battle). Restore to 0 dB on `battle_outcome_resolved` receipt before BEAT_6_RESULT. This is a deterministic mute-and-restore, not dynamic ducking.

**Mastering chain on `ScenarioBus` output**:
1. Bus compressor — 2:1 ratio, −20 dBFS threshold, 10ms attack, 200ms release (glue compression for sparse 국악 palette; not effect compression)
2. True-peak limiter — **ceiling −1.0 dBTP**, 3ms lookahead, final insert before master. This is the architectural enforcement point for the per-asset true-peak requirement.
3. No bus-level EQ for MVP. Per-asset EQ during sound design preferred.

`ScenarioMusicBus` may carry a light high-shelf cut (−2dB @ 8kHz) to compensate for mobile speaker brightness — sound-designer call, not architectural.

#### A.5 Ducking Rules

| Trigger | Target bus | Amount | Ramp | Restore |
|---------|-----------|--------|------|---------|
| `beat_audio_cue_fired` for Beat 2 | `ScenarioMusicBus` | −6 dB | 0.2s | On BEAT_3_BRIEF entry |
| Fault/error dialog (EC-SP-1, EC-SP-5, EC-SP-6) | `ScenarioBus` | −8 dB | 0.3s | On dialog dismiss |
| Beat 6 retry dialog | (none — not a fault) | — | — | — |

Error-dialog sfx authoring (whether dialogs carry their own cues on `UiBus`) flagged as `OQ-AV-9`.

#### A.6 Mobile Playback Calibration

**Measurement standard**: EBU R128 via `ffmpeg -af ebur128` or equivalent `libebur128` integration. Measurements taken on exported OGG decoded to PCM, not DAW project. Hardware reference profile for QA SPL calibration flagged as `OQ-AV-10`.

**QA device set (minimum)**:
- iOS worst-case: iPhone SE (3rd gen) — bottom-firing mono
- iOS representative: iPhone 13/14 — stereo array
- Android budget: Samsung Galaxy A15 or equivalent — mono-dominant
- Android mid: Google Pixel 7a — small-driver stereo

QA playback at system volume 60–80% (max introduces device-level limiting that masks loudness defects).

**Why `[−18, −12] LUFS` and why v1.0 `≤−24 LUFS` failed**: EBU R128 reference is −23 LUFS calibrated for living-room full-range speakers at controlled distance. Mobile phone speakers start at 200–300 Hz with SPL well below TV speakers at equivalent perceptual distance. Content at −24 LUFS on a bottom-firing phone speaker in ambient environments is functionally inaudible — the exact v1.0 failure mode. Industry practice for mobile game audio non-dialogue cues: −18 to −14 LUFS. `−12 LUFS` ceiling preserves headroom versus dialogue/impact sfx and keeps 담담한 aesthetic register intact.

#### A.7 Asset Inventory

| Asset type | Quantity (3-ch MVP) | Quantity (5-ch MVP) | Notes |
|------------|---------------------|---------------------|-------|
| Beat 1 anchor stinger | 1 | 1 | Shared |
| Beat 2 echo fragments | 2 (Ch2, Ch3) | 4 (Ch2–Ch5) | **Per-chapter authored; Ch1 has NO asset** |
| Beat 3 brief loop | 1 | 1 | Shared (or per-chapter if distinct color — flagged) |
| Beat 6 result stingers | 3 (WIN/DRAW/LOSS) | 3 | Shared across all chapters |
| Beat 7 judgment cues | 2 (default / reversal) | 2 | Shared |
| Beat 8 revelation pad | 1–3 | 1–3 | Shared vs. per-branch flagged as `OQ-AV-7` |
| Beat 9 transition | 1 (+1 optional close) | 1 (+1) | Per-chapter proleptic variant flagged as `OQ-AV-8` |
| **Total cues** | **11–14** | **13–16** | |

Beat 2 echo fragments are the only assets that scale linearly with chapter count. Beat 6 variants (single-with-suffixes vs. three-independent) flagged as `OQ-AV-6`. BATTLE_LOADING sub-state audio flagged as `OQ-AV-8`.

## UI Requirements

> **Specialist contributions** — UX half authored by `ux-designer`; engine-implementation half authored by `godot-specialist` against Godot 4.6 (`docs/engine-reference/godot/VERSION.md`). Open items requiring decision before implementation are captured in the **Open Questions** section as `OQ-UI-*`.

### UX Design

#### UX.1 Per-Beat Interaction Map

| Beat | Advance mode | Lockout (F-SP-6) | Input affordance | Skip / replay |
|------|--------------|------------------|------------------|---------------|
| 1 역사의 닻 | Player-gated | 1.0s min dwell | Full-screen tap/click/key; affordance indicator appears post-lockout | None |
| 2 과거의 메아리 | Player-gated | 2.0s min dwell inside 4.0–6.0s envelope | Full-screen tap/click/key; quieter indicator than Beat 1 | None |
| 3 상황 브리핑 | Player-gated | None | Full-screen tap OR discrete "계속" affordance (44px min) | Does not re-fire on retry (CR-8) |
| 6 결과 | Player-gated | 2.0s gate delay before buttons interactive | WIN: "계속" only. DRAW/LOSS: "다시 시도" + "계속" (both 44px min). | No skip; retry re-enters at Beat 4 |
| 7 운명 판정 | Player-gated | **1.5s witness-gate lockout (invariant)** | Affordance reveals from locked (see UX.2) | None (CR-15 item 3) |
| 8 드러냄 | Player-gated | +500ms affordance-visibility soft-gate (UX only, not mechanical) | Full-screen tap OR discrete on contrast band | None |
| 9 다음 장 전환 | Auto-advance (500ms cross-fade) | — | Epilogue-dismiss at SCENARIO_END only (EC-SP-12) | None |

All beats: touch + mouse + keyboard (Space/Enter) are functionally equivalent. **No hover-only interactions** anywhere (technical-preferences contract).

#### UX.2 Beat 7 Witness-Gate Interaction Contract

The 1.5s dwell lockout (CR-11) is a **convergent decision between narrative-director and ux-designer** and is **not a pacing knob**. The invariant governs how the lockout is communicated to the player:

- **Reveal-from-locked model**: the "계속" affordance does **not exist in the scene tree** during the 1.5s lockout. It is instantiated and fades in (150–200ms) only after lockout expiry. Rationale: a visible disabled button with a countdown frames the moment as a delay to push through; an absent-then-appearing affordance communicates "something just became possible" — aligned with the narrative intent of witness, not delay.
- **No countdown indicator** during lockout. The 묵 베일 wipe (400ms) + branch-text settling provide implicit temporal cues.
- **Post-lockout advance**: "계속" at bottom of screen receives default focus; full-screen tap is a secondary affordance. Touch anywhere, click anywhere, or Space/Enter.
- **Pre-lockout taps are dropped silently** per EC-SP-7 — no visual/audio feedback, no "not yet" indicator. Rationale: feedback invites treating the moment as a puzzle to defeat. VS may revisit after playtesting; MVP default is silence on dropped taps.

#### UX.3 Error and Fault Dialogs

All three dialogs (EC-SP-1 scenario load fault, EC-SP-2 sync timeout, EC-SP-5 BATTLE_LOADING timeout) are **modal full-interruption overlays** — no partial-dismissal, no swipe-to-dismiss, no back-button cancel. The scrim uses no reserved colors (주홍/금색 reserved for Beat 7). `ScenarioBus` ducks −8 dB on dialog appearance (Audio §A.5).

| Dialog | Actions | Default focus | Dismiss |
|--------|---------|---------------|---------|
| EC-SP-1 scenario load fault | "메인 메뉴" (only) | "메인 메뉴" | On action tap |
| EC-SP-2 sync timeout | "챕터 재시작" (only) | "챕터 재시작" | On action tap |
| EC-SP-5 BATTLE_LOADING timeout | "재시도" + "메인 메뉴" | "재시도" | On action tap |

**Layout**: vertically centered modal card on semi-transparent scrim. Mobile portrait: 80–90% screen width, auto-height. Mobile landscape / PC: max 480px card width (needs art-director confirmation).

**Button layout on narrow phones (<375pt)**: stack vertically rather than side-by-side to preserve 44px min touch targets with adequate tap-gap padding.

**Focus**: Tab/D-pad cycles only between dialog buttons (trapped focus). Space/Enter activates.

**App suspension during dialog**: on resume, **silently recover to the most recent save checkpoint**; do NOT re-show the fault dialog (flagged as `OQ-UI-3` for final confirmation). Save state is unchanged during dialog display per EC-SP-1 contract.

#### UX.4 Information Hierarchy Per Beat

| Beat | Primary | Secondary | Tertiary |
|------|---------|-----------|----------|
| 1 | Anchor headline text | 演義/정사 citation label | Advance affordance (post-lockout) |
| 2 | Glyph / seal impression | Audio cue (concurrent, Ch2+) | Environmental-label echo text |
| 3 | Situation brief body | Chapter/context label | DRAW-branch register shift (implicit) |
| 6 | Result label (WIN/DRAW/LOSS) | Result-specific narrative line | Gate buttons (reveal at 2.0s) |
| 7 | **Co-primary: branch text + commander portrait** | Reserved-color treatment | 삼중선 border + vignette |
| 8 | Revelation text | Canonical-history contrast band (+150ms) | Citation label (+300ms) |

**Beat 7 risk**: 주홍 vignette is high-saturation and may attract visual attention before branch text can be read. Flagged as `OQ-UI-6` for art-director mockup review — if yes, reduce vignette opacity or confine 주홍 to frame only (no full-screen edge bleed).

#### UX.5 Accessibility Requirements

**Text scale**. All ceremony text uses theme-relative sizing via Godot `ThemeDB`, not hardcoded pixel sizes. OS-level text-scale propagation path:

| System scale | Base 14px renders as | Citation 12px renders as |
|--------------|----------------------|--------------------------|
| 100% | 14px | 12px |
| 125% | 18px | 15px |
| 150% | 21px | 18px |
| 200% | 28px | 24px |

The 12px citation at 30% opacity (Beat 2 ambient echo-label) is explicit ambient atmosphere and is exempt from minimum text size — it must still scale proportionally so it doesn't appear vanishingly small against scaled base text. Implementation feasibility flagged as `OQ-UI-5`.

**Reduced-motion alternatives** (OS detection via Godot 4.5+ AccessKit + in-game setting fallback):

| Motion | Standard | Reduced-motion fallback |
|--------|----------|-------------------------|
| Beat 2 scrim entry | Wipe/fade + glyph fade | Dissolve scrim over 1.0s; glyph animation unchanged (already slow) |
| Beat 6 LOSS desaturation | Shader-animated desat progression | Cut immediately to desaturated end state on entry |
| Beat 7 묵 베일 | 400ms top-to-bottom wipe | 400ms cross-dissolve, no directional motion |

AccessKit API for reduced-motion detection flagged as `OQ-UI-7` (verify against Godot 4.6 engine-reference).

**Color-blind considerations** (Beat 7 reserved colors). 주홍 `#C0392B` is red; `#D4A017` is yellow-gold. Deuteranopia/protanopia (~8% of males) may not distinguish 주홍 vignette from default dark 묵.

**Dual-channel signal**:
- Non-default branches: **2px 삼중선 outer border** (shape/line — visible under all color-vision conditions) + 주홍 color
- Echo-gated branches: 삼중선 + **금색 horizontal accent line below branch text** (positional/structural) + 주홍

Assessment: the 삼중선 border provides shape-based differentiation sufficient as a secondary signal **if border weight is legible on mobile** — flagged as `OQ-UI-4` for art-director device validation. If insufficient, a glyph marker (e.g., 印章 adjacent to branch text) is the VS fallback.

**Touch target enforcement (44px minimum)** — survey and mitigations:

| Beat | Element | Risk | Mitigation |
|------|---------|------|------------|
| 1, 2 | Full-screen tap | None (entire screen is target) | — |
| 3 | "계속" button | Text-sized risk | Enforce 44px min-height in theme |
| 6 | "다시 시도" + "계속" | Side-by-side on narrow screens | Stack vertically on <375pt width |
| 7 | "계속" (post-lockout) | Small overlay risk | Enforce 44px min-height; full-screen tap as backup |
| 8 | Advance affordance | Icon-only risk | Enforce 44px min |
| Dialogs | Two-button rows | Side-by-side narrow-screen risk | Stack vertically on mobile |

**Closed captions**. No dialogue in scenario ceremony (all audio is non-verbal). Visual channel is the primary carrier for Beat 2 (glyph is the beat, not the audio). Beat 9 chapter-transition music gets an optional ambient audio-description caption (`[다음 장으로의 여정 음악]`) — flagged as `OQ-UI-8`; VS scope unless accessibility target requires at MVP.

#### UX.6 Accessibility Checklist — Ceremony Beats

- ✓ Usable with keyboard only (Space/Enter for advance; Tab for dialog buttons)
- ✓ Usable with gamepad only (focus model per implementation; see UI-6)
- ✓ Minimum readable text size at 100% scale; scale-up path to 200%
- ⏳ Functional without reliance on color alone — 삼중선 border is structural dual-channel; device validation pending (`OQ-UI-4`)
- ✓ No flashing below photosensitive threshold (all transitions are slow; no rapid strobes)
- ✓ No spoken dialogue needing subtitles; visual channel carries narrative
- ⏳ Scales correctly at all supported resolutions — Beat 6 stacking + theme-relative sizing pending (`OQ-UI-5`)

---

### Engine Implementation (Godot 4.6 / GDScript)

#### UI-1 Scene and Node Architecture

**Persistent scenario scene.** `ScenarioRunner.tscn` is loaded once for the full scenario lifecycle; not reloaded per beat.

**Tree layout**:
```
ScenarioRunner (Node)
├── BeatConductor (Node — owns timing, lockout timers, cue dispatch)
└── ScenarioCeremonyRoot (CanvasLayer, layer=10)
    └── SafeAreaContainer (MarginContainer — insets applied from DisplayServer)
        ├── Beat1Anchor (Control, Full Rect, AnimationPlayer enter/exit)
        ├── Beat2Echo (Control, Full Rect, AnimationPlayer enter/exit)
        ├── Beat3Brief, Beat6Result, Beat7Judgment, Beat8Revelation, Beat9Transition
        └── FaultOverlay (CanvasLayer layer=100 sibling for dialogs)
```

**Panel swap mechanism**: toggle `visible` flag; per-panel `AnimationPlayer` owns `enter`/`exit` animations. **Do NOT use a monolithic top-level AnimationPlayer** — per-panel ownership allows incremental art iteration and clean interruption. Sequence:

```gdscript
current_panel.animation_player.play("exit")
await current_panel.animation_player.animation_finished
current_panel.visible = false
next_panel.visible = true
next_panel.animation_player.play("enter")
```

If playtesting surfaces need for overlapping cross-dissolve between panels, this pattern changes to a two-panel compositor (`OQ-UI-1`).

**BeatConductor placement**: plain `Node` (not autoload), sibling of `ScenarioCeremonyRoot`. Testable in isolation via GdUnit4 without the full ceremony tree.

#### UI-2 Input Handling

**Tap-to-advance** uses `_gui_input(event: InputEvent)` on the active panel root — **not** `_unhandled_input`. This consumes input within the UI layer and prevents leaks to game-world handlers. Panel `mouse_filter` is `MOUSE_FILTER_STOP` when active; `MOUSE_FILTER_IGNORE` when hidden.

**Touch + mouse parity** in a shared branch:
```gdscript
func _gui_input(event: InputEvent) -> void:
    if _is_locked:
        return  # silent drop per EC-SP-7; no queue
    if (event is InputEventScreenTouch and event.pressed) \
        or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
        _on_advance_requested()
```

**Dwell lockout enforcement**: `Timer` node (`one_shot = true`) per locked beat. Panel sets `_is_locked = true` on entry; `timer.timeout` handler clears it. **Do NOT use `set_process_input(false)`** — it affects the whole node and can interfere with OS-level back-button handling on Android.

**44px touch target**: all interactive Controls set `custom_minimum_size = Vector2(44, 44)`. Beat 6 button row is the highest-risk point — verify via `Control.get_minimum_size()` in layout tests on reference devices.

#### UI-3 Signal Wiring

- **ScenarioRunner → GameBus**: direct emission of the 5 owned signals + 2 PROVISIONAL per ADR-0001. ScenarioRunner never calls methods on UI nodes directly.
- **Panel → BeatConductor**: each panel emits internal `advance_requested`; BeatConductor connects in `_ready()`, validates against current beat state (lockout check, dwell timer), then calls `ScenarioRunner._on_beat_advance_confirmed()` or drops.
- **UI panel → GameBus subscriptions**: via `CONNECT_DEFERRED` in panel `_ready()`; disconnect in `_exit_tree()` (fires only on scenario scene unload — correct lifecycle).
- **Cinematic input block**: BeatConductor emits `ui_input_block_requested` / `ui_input_unblock_requested` on GameBus at Beats 1, 2, 7 entry/exit (the only BeatConductor → GameBus emissions permitted).

#### UI-4 Safe-Area Handling (Mobile)

`DisplayServer.screen_get_safe_area()` returns a `Rect2i` of insets. Read once in `ScenarioCeremonyRoot._ready()` and apply to a `MarginContainer` named `SafeAreaContainer`.

- **Inside `SafeAreaContainer`**: text, buttons, portraits, contrast bands, interactive elements
- **Outside `SafeAreaContainer`** (direct children of `ScenarioCeremonyRoot`): full-screen scrims (Beat 2 dark field `#1C1A17`, Beat 7 묵 panel, Beat 7 주홍 vignette shader) — these bleed edge-to-edge past notch/home-indicator zones by design
- **PC**: `screen_get_safe_area()` returns `Rect2i(0,0,0,0)` on desktop — `MarginContainer` overrides are zero; no platform-conditional code needed

Android 15+ edge-to-edge mode affects safe-area return values; verify Android export preset consistency (`OQ-UI-6a` — verify against engine-reference).

#### UI-5 Frame Budget

**Beat 7 draw call estimate** (heaviest beat; budget ≤30 per Visual §V.4):

| Element | Draw calls |
|---------|-----------|
| 묵 background `ColorRect` | 1 |
| 주홍 vignette shader `ColorRect` | 1 |
| 금색 accent (echo variant) `ColorRect` | 1 |
| Portrait `TextureRect` | 1 |
| Branch text `Label` (font atlas batching) | 1–3 |
| 삼중선 border (3 nested ColorRects) | 3 |
| **Estimated total** | **9–11** |

Well within the Beat 7 ≤30 ceiling and the <500 mobile 2D budget. Portrait 금색 glow border shader flagged for technical-artist validation against Godot 4.6 CanvasItem batching on target Android devices.

**AnimationPlayer vs. Tween**:
- `AnimationPlayer` — for **authored designer-driven sequences** (Beat 2 glyph fade curve, Beat 7 묵 베일 wipe, Beat 9 cross-fade). Artist has direct control over specific ease curves.
- `Tween` — for **procedural data-driven transitions** (dwell-lockout affordance fade-in, data-driven portrait fade with duration from `BeatCue`). GC-friendly; `create_tween()` auto-disposes.
- **Never** use `_process(delta)` for manual lerp — always `Tween`.

**`process_mode`**: `ScenarioCeremonyRoot` uses `PROCESS_MODE_ALWAYS` so ceremony can run during game-level pauses for dialogs; individual beat panels use `PROCESS_MODE_PAUSABLE`. BeatConductor timers use `TIMER_PROCESS_IDLE` (respects pause tree).

#### UI-6 Godot 4.6 Gotchas (verify against engine-reference before implementation)

- **Dual-focus system (4.6, HIGH RISK)** — mouse/touch focus is separate from keyboard/gamepad focus. Tap-to-advance uses `_gui_input` (bypasses this), but Beat 6 `Button` nodes need explicit testing on both paths. Set `Button.focus_mode = FOCUS_NONE` on touch-only ceremony buttons if gamepad support is deferred.
- **Recursive Control disable (4.5+)** — setting `mouse_filter = MOUSE_FILTER_IGNORE` on a parent recursively suppresses children's input. Preferred mechanism for panel-level lockout, but verify: if a child has `MOUSE_FILTER_STOP`, that child may still fire `_gui_input`. Test on 4.6 specifically.
- **`screen_get_safe_area()` on Android edge-to-edge (4.5+)** — on Android 15+, returns system gesture insets. If export preset disables edge-to-edge, may return zeros on notched devices. Verify export preset consistency.
- **Glow rework (4.6)** — glow processes before tonemapping. LOW risk for 2D CanvasLayer rendering (3D WorldEnvironment post-process does not affect 2D CanvasLayer draws).
- **AnimationMixer base (4.3+)** — `AnimationPlayer extends AnimationMixer`. Stable API; no action needed.

#### UI-7 SceneManager Integration (ADR-0002 Pending)

**MVP-provisional contract** until ADR-0002 lands:
- `ScenarioRunner.tscn` is loaded by upstream (main menu) via `change_scene_to_file()` or persistent instantiation.
- Grid Battle scene is loaded by ScenarioRunner directly as a provisional measure; `battle_launch_requested` fires; scenario ceremony `CanvasLayer` layer=10 is visually superseded by Grid Battle HUD at a higher layer.
- On `battle_outcome_resolved` receipt, ScenarioRunner calls `queue_free()` on the Grid Battle scene reference and resumes ceremony.
- BeatConductor is a persistent `Node` inside `ScenarioRunner.tscn` — **never** reloaded per beat.

**Post-ADR-0002 compatibility**: SceneManager will own Grid Battle scene load/unload. BeatConductor's interface is designed forward-compatible — it waits for `beat_sequence_complete(5)` from ScenarioRunner after `BATTLE_LOADING`, and the internal wait mechanism (deferred one-frame now, SceneManager hook later) is encapsulated inside ScenarioRunner.

**Expected source paths at implementation**:
- `src/gameplay/scenario_runner.gd` + `.tscn`
- `src/gameplay/beat_conductor.gd`
- `src/ui/ceremony/scenario_ceremony_root.gd`
- `src/ui/ceremony/beats/beat_[1..9]_*.gd` (one script per panel)

## Cross-References

[To be designed]

## Acceptance Criteria

**Coverage summary.** All 16 Core Rules (CR-1 through CR-16), all 6 Formulas (F-SP-1 through F-SP-6), and all 12 Edge Cases (EC-SP-1 through EC-SP-12) are covered by at least one AC below. Each pillar decision locked 2026-04-18 is covered by a dedicated Pillar-Fidelity AC. **AC-SP-6** replaces v1.0 `AC-SP-20` (not-independently-testable defect). **AC-SP-37** replaces v1.0 `≤−24 LUFS` with the instrumentation-verified `−18 to −12 LUFS` target.

### H.1 Core Rules ACs

- **AC-SP-1**: Given a 5-chapter scenario JSON with chapters ordered `[ch1, ch2, ch3, ch4, ch5]`, when ScenarioRunner processes each chapter to completion, then chapters execute in strictly ascending index order and no chapter is skipped or repeated.
  - **Method**: unit
  - **Evidence**: GdUnit4 test asserts `chapter_started` emissions ordered ch1→ch5 with no gaps; log trace from signal spy
  - **Covers**: CR-1

- **AC-SP-2**: Given a chapter at CHAPTER_START, when the chapter runs to SCENARIO_END, then exactly 9 beat-state transitions fire in order: BEAT_1_ANCHOR → BEAT_2_ECHO → BEAT_3_BRIEF → BEAT_4_PREP → BEAT_5_BATTLE → BEAT_6_RESULT → BEAT_7_JUDGMENT → BEAT_8_REVEAL → BEAT_9_TRANSITION. Any deviation in order or count is a test failure.
  - **Method**: unit
  - **Evidence**: GdUnit4 test records `current_state` transitions via state-change callback; assert exact sequence array
  - **Covers**: CR-2, CR-15

- **AC-SP-3**: Given ScenarioRunner is in BEAT_5_BATTLE and Grid Battle emits `battle_outcome_resolved` with `result = DRAW`, when ScenarioRunner advances to BEAT_7_JUDGMENT, then `resolve_branch()` receives `outcome == DRAW` (not WIN, not LOSS). ScenarioRunner must not convert, round, or override the received tri-state value.
  - **Method**: unit
  - **Evidence**: GdUnit4 test injects `BattleOutcome{result: DRAW}` via mock; assert `DestinyBranchChoice.outcome == DRAW` in captured `destiny_branch_chosen` payload
  - **Covers**: CR-3, CR-5

- **AC-SP-4**: Given a chapter with `author_draw_branch = true` and `echo_threshold = 1`, when ScenarioRunner receives `outcome = DRAW` and `echo_count = 0` at Beat 7, then the branch key returned is `DRAW_<chapter>_default` (not the echo-gated key) and `is_draw_fallback = false`.
  - **Method**: unit
  - **Evidence**: GdUnit4 test calls `resolve_branch(chapter, DRAW, 0)`; assert returned struct fields match expected values
  - **Covers**: CR-4, CR-6, F-SP-1, F-SP-2

- **AC-SP-5**: Given a chapter where the player chooses "Retry" at Beat 6 three times, when ScenarioRunner reaches BEAT_7_JUDGMENT entry, then `state.echo_count == 3` and exactly 3 `scenario_beat_retried` signals have been emitted on GameBus. When Beat 9 fires, `state.echo_count == 0` immediately after transition.
  - **Method**: unit
  - **Evidence**: GdUnit4 test with mock GameBus signal spy; assert echo_count == 3 before Beat 9, == 0 after; assert signal emission count == 3
  - **Covers**: CR-7, CR-8, F-SP-3

- **AC-SP-6 (replaces v1.0 AC-SP-20)**: Given a Ch2+ chapter (not Ch1), when ScenarioRunner enters BEAT_2_ECHO, then (a) `beat_visual_cue_fired` is emitted on GameBus within 100ms of BEAT_2_ECHO entry, (b) `beat_audio_cue_fired` is emitted on GameBus within 100ms of BEAT_2_ECHO entry, and (c) the state does not advance to BEAT_3_BRIEF until at least 2000ms have elapsed since BEAT_2_ECHO entry. For Ch1, only (a) fires and (b) must NOT be emitted.
  - **Method**: integration
  - **Evidence**: GdUnit4 integration test with GameBus signal spy; assert signal presence/absence and minimum elapsed time measured via `Time.get_ticks_msec()` before and after; cite ADR-0001 for GameBus routing requirement
  - **Covers**: CR-9, F-SP-6

- **AC-SP-7**: Given Beat 7 is entered with a non-default branch (any branch other than the WIN default), when the state is rendered, then the branch text node applies color `#C0392B` (주홍) or `#D4A017` (금색) per the Art Bible treatment. Given a default-WIN branch, neither reserved color is applied.
  - **Method**: manual playtest
  - **Evidence**: Screenshot of Beat 7 screen in `production/qa/evidence/` for both default and non-default branch; QA tester annotates observed color hex from color picker; lead sign-off required
  - **Covers**: CR-10

- **AC-SP-8**: Given a 3-branch chapter where `branch == canonical`, when Beat 8 renders, then the revelation UI displays only a brief acknowledgment and does NOT display a contrast panel. Given a non-canonical branch, a canonical-history contrast panel is present and the authored `演義 chapter` or `정사 passage` citation is visible in the revelation text.
  - **Method**: manual playtest
  - **Evidence**: Screenshots for canonical and non-canonical paths in `production/qa/evidence/`; QA tester confirms citation string is present/absent per path
  - **Covers**: CR-11

- **AC-SP-9**: Given Beat 9 entry with more chapters remaining, when `chapter_completed(ChapterResult)` is emitted and ScenarioRunner transitions to the next chapter's LOADING, then (a) `echo_count = 0` in ScenarioRunner state, (b) `ChapterResult` payload contains `chapter_id`, `branch_path_id`, and `echo_count_at_completion` fields. Given the last chapter, `scenario_complete(ScenarioResult)` is emitted instead and ScenarioRunner enters SCENARIO_END.
  - **Method**: unit
  - **Evidence**: GdUnit4 test asserts both signal payloads against minimum field schema; assert echo_count == 0 post-transition; cite ADR-0001
  - **Covers**: CR-12, CR-16

- **AC-SP-10**: Given a Ch1 scenario data file containing an `echo_threshold` field, when the authoring validator runs, then the build exits with a non-zero error code and outputs a message identifying Ch1 and the disallowed field. Given a Ch1 data file without `echo_threshold`, the validator passes with exit code 0.
  - **Method**: unit
  - **Evidence**: GdUnit4 test invokes validator with fixture files; assert exit codes and error output
  - **Covers**: CR-13, CR-15, EC-SP-9

- **AC-SP-11**: Given a chapter with `author_draw_branch = false`, when ScenarioRunner receives `outcome = DRAW` at Beat 7, then `resolve_branch()` returns `branch_key` equal to the chapter's WIN default key, `is_draw_fallback = true`, and `cue_tag = "draw_fallback"`.
  - **Method**: unit
  - **Evidence**: GdUnit4 test calls `resolve_branch(chapter_with_no_draw, DRAW, 0)`; assert all three returned struct fields
  - **Covers**: CR-14, F-SP-1

- **AC-SP-12**: Given a chapter with `author_draw_branch = true`, when the authoring validator runs against a chapter data file that omits the DRAW branch entry, then the build exits with a non-zero error code. Given a chapter with `author_draw_branch = false`, a missing DRAW entry does not produce a validator error.
  - **Method**: unit
  - **Evidence**: GdUnit4 validator tests with two fixture files; assert exit codes
  - **Covers**: CR-14, EC-SP-8

### H.2 State Machine ACs

- **AC-SP-13**: Given ScenarioRunner is in any state other than BEAT_6_RESULT, when any state transition is requested, then the resulting state has a higher ordinal than the current state (forward-only invariant). The only permitted backward transition is BEAT_6_RESULT → BEAT_4_PREP. An attempt to jump to an arbitrary beat via any public API must be rejected.
  - **Method**: unit
  - **Evidence**: GdUnit4 state machine test iterates all 12 states; asserts no backward transition outside the defined retry arc; asserts no public `go_to_beat(n)` method is callable externally
  - **Covers**: CR-2, CR-8

- **AC-SP-14**: Given ScenarioRunner enters BATTLE_LOADING and no Grid Battle readiness hook fires within 10 seconds (simulated via timeout injection), when the timeout elapses, then (a) the UI presents "전투 씬 로드 실패" with exactly two actions: "재시도" and "메인 메뉴", (b) "재시도" returns ScenarioRunner to BEAT_4_PREP, (c) `echo_count` is unchanged, (d) `scenario_beat_retried` is NOT emitted.
  - **Method**: integration
  - **Evidence**: GdUnit4 integration test with mock Grid Battle (never fires readiness); assert UI string, state after retry action, echo_count invariant, signal-spy confirms no `scenario_beat_retried` emission; cite ADR-0001
  - **Covers**: EC-SP-5, CR-8

- **AC-SP-15**: Given ScenarioRunner is in SCENARIO_END displaying the authored epilogue, when the player taps to dismiss, then ScenarioRunner exits SCENARIO_END, SceneManager receives a scene-transition request to the main menu, and no GameBus signal is emitted at dismiss time.
  - **Method**: integration
  - **Evidence**: GameBus signal spy confirms zero emissions after dismiss; scene transition log confirms return to main menu scene; cite ADR-0001
  - **Covers**: CR-16, EC-SP-12

- **AC-SP-16**: Given ScenarioRunner emits `chapter_started(ChapterContext)`, then all downstream consumers (Grid Battle, UI layer) receive the signal via `/root/GameBus` and not via a direct scene signal connection. Verify by asserting no `connect()` calls between ScenarioRunner and Grid Battle or UI scene nodes exist in source.
  - **Method**: unit (static analysis)
  - **Evidence**: Grep of `src/` for direct `connect` calls from `scenario_runner.gd` to Grid Battle or UI scene nodes; zero matches required; cite ADR-0001
  - **Covers**: CR-1 (GameBus contract), ADR-0001

### H.3 Signal Contract ACs

- **AC-SP-17**: Given ScenarioRunner is wired to GameBus per ADR-0001, when one full chapter completes (no retry), then exactly these 5 confirmed signals are emitted in order on GameBus: `chapter_started`, `battle_prepare_requested`, `battle_launch_requested`, `destiny_branch_chosen`, `chapter_completed`. No signal named `battle_complete` is emitted (rename enforcement).
  - **Method**: integration
  - **Evidence**: GdUnit4 integration test with GameBus signal spy records emission sequence; assert ordered list equality; assert `battle_complete` signal count == 0; cite ADR-0001
  - **Covers**: ADR-0001 signal set, signal rename

- **AC-SP-18**: Given a chapter with `author_draw_branch = true` and a DRAW outcome, when `destiny_branch_chosen(DestinyBranchChoice)` is emitted, then payload contains all minimum fields: `chapter_id: String`, `branch_key: String`, `outcome: Result` (value == DRAW), `echo_count: int`, `is_draw_fallback: bool` (value == false), `reserved_color_treatment: bool`.
  - **Method**: unit
  - **Evidence**: GdUnit4 test asserts payload field presence and types via schema check; assert `outcome == DRAW` and `is_draw_fallback == false`
  - **Covers**: CR-5, CR-10, ADR-0001

- **AC-SP-19**: Given a player retry at Beat 6, when `scenario_beat_retried(EchoMark)` is emitted (PROVISIONAL signal), then payload contains: `chapter_id: String`, `beat_number: int` (value == 5), `retry_count: int` (equals current echo_count), `timestamp_unix: int` (nonzero).
  - **Method**: unit
  - **Evidence**: GdUnit4 test with mock retry trigger; assert all four EchoMark fields and values; cite ADR-0001 PROVISIONAL status
  - **Covers**: CR-8, F-SP-3, ADR-0001

- **AC-SP-20**: Given Beat 9 entry, when `save_checkpoint_requested(SaveContext)` is emitted as CP-3 (PROVISIONAL signal), then payload `SaveContext` contains at minimum: `chapter_id`, `outcome`, `branch_key`, `echo_count`, `echo_marks_archive`, `flags_to_set`. When CP-2 fires (post-Beat-7), `SaveContext.outcome` matches the `BattleOutcome.result` received at Beat 5 with no modification.
  - **Method**: unit
  - **Evidence**: GdUnit4 test asserts field presence on CP-3 payload; separate test asserts CP-2 `outcome` round-trip matches injected `BattleOutcome.result`; cite ADR-0001 PROVISIONAL status
  - **Covers**: CR-12, CR-15, ADR-0001

- **AC-SP-21**: Given `battle_outcome_resolved(BattleOutcome)` arrives while ScenarioRunner is in BEAT_6_RESULT (not BEAT_5_BATTLE), when the signal fires, then ScenarioRunner state does not change and no downstream processing occurs. No error or warning is logged (benign stale signal per ADR-0001).
  - **Method**: unit
  - **Evidence**: GdUnit4 test emits signal in BEAT_6_RESULT state; assert state unchanged, assert no log output of level WARNING or above; cite ADR-0001 deferred-connect discipline
  - **Covers**: EC-SP-3, ADR-0001

### H.4 Formula ACs

- **AC-SP-22**: Given the F-SP-1 branch-resolution function and all 6 input rows from the Ch3 example table in Section D, when `resolve_branch()` is called with each row, then each output `{branch_key, is_draw_fallback, cue_tag}` matches the documented expected value exactly.
  - **Method**: unit
  - **Evidence**: GdUnit4 parametric test with 6 fixture rows; assert all three output fields per row
  - **Covers**: F-SP-1, CR-4, CR-5

- **AC-SP-23**: Given the F-SP-2 echo-gate predicate and the 4 example rows in Section D, when `is_echo_gate_open()` is called with each input triple `(outcome, echo_count, echo_threshold)`, then each boolean output matches the documented expected value. Specifically: `(DRAW, 0, 1) = false`, `(DRAW, 1, 1) = true`, `(WIN, 5, 1) = false`, `(LOSS, 3, 1) = false`.
  - **Method**: unit
  - **Evidence**: GdUnit4 parametric test asserts all 4 cases; 100% coverage required per coding-standards balance formula rule
  - **Covers**: F-SP-2, CR-6

- **AC-SP-24**: Given the F-SP-3 echo accumulation/reset contract, when `on_player_retry()` is called N times followed by `on_chapter_transition()`, then (a) `state.echo_count == N` immediately before transition, (b) `state.echo_count == 0` immediately after transition, (c) exactly N `scenario_beat_retried` emissions occurred, each with `retry_count == i` for the i-th call.
  - **Method**: unit
  - **Evidence**: GdUnit4 test with N=3; assert all three conditions; signal spy confirms emission count and payload values
  - **Covers**: F-SP-3, CR-7

- **AC-SP-25**: Given the F-SP-4 `scenario_path_key` composition function and a 3-chapter `chapter_outcomes` array `["WIN_ch1_default", "DRAW_ch2_fallback", "DRAW_ch3_echo"]`, when `scenario_path_key()` is called, then the returned string equals `"WIN_ch1_default-DRAW_ch2_fallback-DRAW_ch3_echo"` exactly (delimiter `-`, no trailing dash, ordered by chapter index).
  - **Method**: unit
  - **Evidence**: GdUnit4 test asserts string equality
  - **Covers**: F-SP-4, CR-16

- **AC-SP-26**: Given the F-SP-5 epilogue count formula, when called with `[{branch_count:2},{branch_count:2},{branch_count:2}]`, output is 8. When called with `[{branch_count:3},{branch_count:3},{branch_count:3}]`, output is 27. When called with `[{branch_count:3},{branch_count:3},{branch_count:3},{branch_count:3},{branch_count:3}]`, output is 243.
  - **Method**: unit
  - **Evidence**: GdUnit4 parametric test asserts all 3 cases
  - **Covers**: F-SP-5, CR-16

- **AC-SP-27**: Given the F-SP-6 timing constants, when ScenarioRunner enters BEAT_1_ANCHOR and the player taps at t=0ms, the tap is dropped and the state remains BEAT_1_ANCHOR. When the player taps at t=1001ms, the state advances to BEAT_2_ECHO. Perform the same test for Beat 2 (min dwell 2000ms), Beat 6 (gate delay 2000ms), and Beat 7 (dwell lockout 1500ms).
  - **Method**: unit
  - **Evidence**: GdUnit4 tests for each of the 4 beats; each test asserts state unchanged at (min_dwell − 1ms) tap and state advanced at (min_dwell + 1ms) tap
  - **Covers**: F-SP-6, CR-2, CR-7, CR-15, EC-SP-7

### H.5 Edge Case ACs

- **AC-SP-28**: Given `assets/data/scenarios/{scenario_id}.json` is absent from disk, when ScenarioRunner enters LOADING, then (a) `chapter_started` is NOT emitted on GameBus, (b) ScenarioRunner enters a terminal FAULT state, (c) the UI displays a dialog containing the string "시나리오 데이터를 불러올 수 없습니다" with a "메인 메뉴" button, (d) no write to save state occurs.
  - **Method**: integration
  - **Evidence**: Integration test removes fixture file before LOADING; assert signal-spy shows zero `chapter_started` emissions; assert UI string presence; assert save state file is unmodified (file hash before and after must match)
  - **Covers**: EC-SP-1

- **AC-SP-29**: Given ScenarioRunner is in BEAT_5_BATTLE awaiting `chapter_id = "ch_3"`, when `battle_outcome_resolved` arrives with `chapter_id = "ch_2"` (mismatch), then (a) ScenarioRunner remains in BEAT_5_BATTLE, (b) no outcome processing occurs, (c) a WARNING-level log message containing both chapter IDs is emitted, (d) if no matching signal arrives within 60 seconds, ScenarioRunner emits internal `scenario_beat_timeout` and UI shows "전투 결과 동기화 실패" with "챕터 재시작" action.
  - **Method**: integration
  - **Evidence**: Integration test injects mismatched outcome; assert state unchanged; assert log output; fast-forward timeout via `Time` mock; assert UI string
  - **Covers**: EC-SP-2

- **AC-SP-30**: Given the player modifies deployment in BEAT_4_PREP after confirming retry at Beat 6, and the app is suspended (simulated via `SceneTree.quit()`) before `battle_launch_requested` is emitted, when the app resumes, then (a) ScenarioRunner loads from CP-1 and enters CHAPTER_START, (b) `echo_count == 0` in loaded state, (c) the modified deployment is not present.
  - **Method**: integration
  - **Evidence**: Integration test with save-file inspection; assert resume state == CHAPTER_START; assert `echo_count == 0`; assert deployment matches pre-retry default
  - **Covers**: EC-SP-4, EC-SP-10

- **AC-SP-31**: Given Beat 2 for a Ch2+ chapter where `beat_2_fragment.audio_asset` cannot be resolved at runtime, when BeatConductor enters BEAT_2_ECHO, then (a) `beat_audio_cue_fired` is NOT emitted, (b) `beat_visual_cue_fired` IS emitted, (c) the 4–6s envelope still completes, (d) a WARNING-level log is recorded, (e) ScenarioRunner does NOT fault and proceeds to BEAT_3_BRIEF. Separately: if `beat_2_fragment.visual_asset` cannot be resolved, ScenarioRunner emits `scenario_fault` and halts.
  - **Method**: integration
  - **Evidence**: Two integration tests with injected missing-asset conditions; signal spy confirms audio-absent/visual-present for audio failure; signal spy confirms `scenario_fault` for visual failure; log assertion for WARNING; timing assertion for envelope completion
  - **Covers**: EC-SP-6, CR-9

- **AC-SP-32**: Given BATTLE_LOADING sub-state with `battle_loading_timeout = 10s`, when "재시도" is selected after timeout, then ScenarioRunner returns to BEAT_4_PREP and `echo_count` is identical to its value before the BATTLE_LOADING entry. `scenario_beat_retried` is NOT emitted.
  - **Method**: unit
  - **Evidence**: GdUnit4 test with timeout mock; assert echo_count delta == 0; signal spy confirms no `scenario_beat_retried`
  - **Covers**: EC-SP-5, CR-8

- **AC-SP-33**: Given a scenario where the player completes all chapters with zero retries (echo_count remains 0 throughout), when `scenario_complete(ScenarioResult)` is emitted, then `ScenarioResult.total_echo == 0` and epilogue selection proceeds via `scenario_path_key` without error or special-case branching.
  - **Method**: unit
  - **Evidence**: GdUnit4 test asserts `total_echo == 0` in payload; assert epilogue lookup does not throw null/key-not-found; assert all-DRAW-clean path is resolved without crash
  - **Covers**: EC-SP-11, CR-16, F-SP-4

### H.6 Pillar-Fidelity ACs

- **AC-SP-34 (Pillar 4 — 삼국지의 숨결)**: Given a 2-chapter scenario where Ch1 ends with `branch_path_id = "WIN_ch1_zhao_yun_lost"` (a branch that sets a narrative flag `zhao_yun_not_recruited`), when Ch2 loads and enters CHAPTER_START, then the loaded `ChapterContext` contains `zhao_yun_not_recruited` in its `flags` field, and the Ch2 Beat 3 situation brief text node displays content authored for that flag state (not the default brief text).
  - **Method**: integration
  - **Evidence**: Integration test with two chapter fixtures; assert `ChapterContext.flags` contains expected flag; screenshot of Beat 3 brief text in `production/qa/evidence/` showing non-default content; lead sign-off
  - **Covers**: Pillar 4 — prior chapter choice visible in next chapter's loaded state

- **AC-SP-35 (Pillar 2 — 운명은 바꿀 수 있다)**: Given Ch3 with `author_draw_branch = true` and `echo_threshold = 1`, when the player achieves `outcome = DRAW` after 1 retry (`echo_count = 1`), then Beat 7 displays a branch key that is observably distinct from the `DRAW` branch reached with `echo_count = 0`. The distinct branch must be rendered without error and must be identifiable in the `destiny_branch_chosen` payload as a different `branch_key` string value.
  - **Method**: integration
  - **Evidence**: Integration test injects two `BattleOutcome{DRAW}` scenarios (echo=0 and echo=1); assert `DestinyBranchChoice.branch_key` differs between the two; screenshot of Beat 7 for both in `production/qa/evidence/`
  - **Covers**: Pillar 2 — echo accumulation visibly gates the reversal branch

- **AC-SP-36 (DRAW-as-distinct-outcome)**: Given a chapter with `author_draw_branch = true`, when `battle_outcome_resolved` delivers `result = DRAW`, then the `branch_key` in `destiny_branch_chosen` does NOT equal any WIN-keyed or LOSS-keyed branch id from the same chapter's `branch_table`. The DRAW branch must be a distinct authored entry, not a runtime alias of WIN or LOSS.
  - **Method**: unit
  - **Evidence**: GdUnit4 test loads Ch3 fixture (`author_draw_branch=true`); calls `resolve_branch(DRAW, 0)`; assert returned `branch_key` is not present in WIN or LOSS rows of the same `branch_table`
  - **Covers**: DRAW-as-distinct-outcome pillar decision

- **AC-SP-37 (Beat 2 multi-modal audibility — replaces v1.0 `≤−24 LUFS` defect)**: Given a Ch2+ chapter whose `beat_2_fragment.audio_asset` is an authored audio cue, when the audio cue is played during BEAT_2_ECHO on a reference mobile device (or via software loudness analyzer targeting the mobile-primary audio profile), then the integrated loudness of the cue measures between −18.0 LUFS and −12.0 LUFS. A measurement below −18.0 LUFS or above −12.0 LUFS is a test failure. The v1.0 value of `≤−24 LUFS` is explicitly out of spec and any asset measuring below −18.0 LUFS must be re-authored.
  - **Method**: instrumentation (loudness analysis — e.g., ffmpeg `ebur128` filter or equivalent)
  - **Evidence**: Loudness measurement report per cue asset stored in `production/qa/evidence/`; report shows integrated LUFS value for each Beat 2 audio asset; any out-of-range measurement is a blocking defect
  - **Covers**: Beat 2 multi-modal audibility pillar decision, CR-9, F-SP-6

## Cross-References

- **Pillars source**: `design/gdd/game-concept.md` *(repairs v1.0 broken reference to nonexistent `design/gdd/game-pillars.md`)*
- **Architecture decision — GameBus autoload**: `docs/architecture/ADR-0001-gamebus-autoload.md` (Accepted 2026-04-18)
- **Architecture review report**: `docs/architecture/architecture-review-2026-04-18.md`
- **TR registry entries**: `docs/architecture/tr-registry.yaml` → `TR-scenario-progression-001`, `-002`, `-003`, `TR-gamebus-001`
- **v1.0 review log**: `design/gdd/reviews/scenario-progression-review-log.md` (30 BLOCKING / ~20 Recommended; see AC-SP-6 and AC-SP-37 for the repairs this v2.0 introduces)
- **v1.0 archive**: `design/gdd/archive/scenario-progression-v1.md`
- **Systems index entry (row 6)**: `design/gdd/systems-index.md`
- **Upstream GDDs cited**: `design/gdd/grid-battle.md` (v4.0; v5.0 pending — signal rename `battle_outcome_resolved` cascade), `design/gdd/turn-order.md` (v-next pending — drops `battle_ended` ownership per ADR-0001 single-owner rule)
- **Art Bible**: `design/art/` (ink-wash aesthetic; reserved colors 주홍 `#C0392B` / 금색 `#D4A017`; Art Bible §§ 4, 5.4, 7.4–7.6 cited throughout Visual Requirements)
- **Project coding standards**: `.claude/docs/coding-standards.md` (balance formulas 100% / gameplay 80% coverage); `.claude/docs/technical-preferences.md` (Godot 4.6 / GDScript / 44px touch targets / 60fps mobile / 512MB ceiling)

## Open Questions

> **Taxonomy** — 30 open items organized into 5 buckets. None block the GDD v2.0 **lock**; several are MVP implementation blockers tracked here for downstream coordination. ADR-0001 blocker (v1.0 `OQ-SP-01`) was **RESOLVED** when ADR-0001 was Accepted 2026-04-18.

### Bucket 1 — Pillar / Creative-Direction Questions

**None outstanding.** All 5 pillar-alignment decisions and all 4 cross-specialist convergent decisions were locked 2026-04-18 and are baked into Sections B, C, D, and H.

### Bucket 2 — Cross-Specialist Decisions (UI + Visual/Audio)

| ID | Item | Who decides | Target gate |
|----|------|-------------|-------------|
| `OQ-UX-1` | Advance affordance style (text label vs. icon) for Beats 1 & 2 | art-director + ux-designer | Before UI implementation |
| `OQ-UX-2` | Beat 6 button ordering — "다시 시도" left (conventional) vs. right (reframes retry as destructive) | narrative-director + ux-designer | Before UI implementation |
| `OQ-UI-1` | Panel swap pattern — sequential (current spec) vs. cross-dissolve compositor | ux-designer + godot-specialist | After first playtest |
| `OQ-UI-3` | App-resume after error dialog — silent recovery to checkpoint vs. re-show dialog | ux-designer + game-designer | Before UI implementation |
| `OQ-UI-4` | 삼중선 border weight sufficient as colorblind dual-channel signal at mobile 375pt/320pt widths | art-director (device validation) | Before Beat 7 asset production |
| `OQ-UI-6` | 주홍 vignette vs. Beat 7 branch-text readability (risk: vignette overwhelms text) | art-director (mockup review) | Before Beat 7 asset production |
| `OQ-UI-8` | Beat 9 music audio-description caption — MVP or VS scope | ux-designer + accessibility-specialist | MVP accessibility pass |
| `OQ-AV-1` | Beat 2 fade curve formal sign-off (Ease Out Cubic / Hold / Ease In Cubic derived from Art Bible § 7.4 analogy) | art-director + ux-designer | Before Beat 2 asset production |
| `OQ-AV-4` | Art Bible missing Beat 2 glyph style guide (stroke weight, negative-space rules, reference examples) | art-director | **Blocks Beat 2 glyph production** |
| `OQ-AV-5` | Beat 8 contrast panel — shared atlas (with Beats 1/3/9) or dedicated parchment strip | art-director | Before Beat 8 asset production |
| `OQ-AV-6` | Beat 6 cue variants — single asset with `_win`/`_draw`/`_loss` suffixes vs. three independently authored stingers | audio-director | Before Beat 6 audio production |
| `OQ-AV-7` | Beat 8 — shared ambient pad (1 asset) vs. per-branch authored pads (up to 3 per chapter) | audio-director + producer (scope) | Before Beat 8 audio production |
| `OQ-AV-8a` | Beat 9 scenario-close music variant — MVP scope or deferred to VS | audio-director + producer | MVP scope lock |
| `OQ-AV-8b` | BATTLE_LOADING sub-state audio — silence / ambient hold / Grid Battle pre-roll | audio-director + godot-specialist | Before Beat 5 handoff implementation |
| `OQ-AV-9` | Error-dialog sfx authoring — do EC-SP-1 / EC-SP-5 / EC-SP-2 fault dialogs carry UI sfx, and on which bus | audio-director + ux-designer | Before error-dialog implementation |

### Bucket 3 — Engine-Reference Verifications (Godot 4.6)

All items flagged "verify against engine-reference before implementation" in Sections V/A and UI. These are **not blockers for the GDD lock** — they are implementation-time checks on post-LLM-cutoff Godot 4.6 behavior (our training predates 4.4 features; see `docs/engine-reference/godot/VERSION.md`).

| ID | Item | Specialist |
|----|------|-----------|
| `OQ-UI-2` | Godot 4.6 dual-focus system behavior with `Button.focus_mode = FOCUS_NONE` on touch-only ceremony buttons | godot-specialist |
| `OQ-UI-5` | `ThemeDB` theme-relative text scaling propagation from OS text-scale settings to Godot Control font sizes | godot-specialist |
| `OQ-UI-6a` | `DisplayServer.screen_get_safe_area()` return values on Android 15+ edge-to-edge mode (vs. export preset edge-to-edge disabled) | godot-specialist |
| `OQ-UI-7` | Godot 4.6 AccessKit API for OS reduced-motion preference detection | godot-specialist |
| `OQ-AV-2` | Per-beat draw call ceilings under Godot 4.6 CanvasItem batching on target Android mid-range devices | technical-artist |
| `OQ-AV-3` | Beat 7 주홍 vignette implementation — shader pass vs. pre-baked 8-frame alpha sprite | godot-shader-specialist + technical-artist |
| `OQ-AV-10` | Hardware reference profile for LUFS QA SPL calibration (formal device SPL curve or software-only measurement) | audio-director + QA |

### Bucket 4 — Upstream Contract Dependencies (MVP Blockers)

These are cross-GDD contracts referenced as PROVISIONAL in this document. They must be ratified before story-level implementation of Scenario Progression.

| Contract | System (index row) | Status | Affects |
|----------|-------------------|--------|---------|
| `DestinyBranchChoice` payload shape | Destiny Branch #4 (MVP) | PROVISIONAL — **prioritize** | `destiny_branch_chosen` signal (ADR-0001 slot); Section C Interactions; AC-SP-18, AC-SP-22, AC-SP-36 |
| `EchoMark` payload shape + echo storage ownership | Destiny State #16 (VS) | PROVISIONAL | `scenario_beat_retried` + `destiny_state_echo_added` signals (ADR-0001 slots); Section C Interactions; AC-SP-19, AC-SP-24 |
| `BeatCue` payload shape | Story Event #10 (VS) | PROVISIONAL | `beat_visual_cue_fired` + `beat_audio_cue_fired` signals (ADR-0001 slots); Section C Interactions; AC-SP-6, AC-SP-31 |
| `SaveContext` payload + DRAW schema + Echo serialization + 3-CP policy owner | Save/Load #17 (VS) | PROVISIONAL | `save_checkpoint_requested` signal (ADR-0001 slot); Section C Interactions; AC-SP-20, AC-SP-30 |
| SceneManager ownership of Grid Battle scene load/unload | ADR-0002 Scene Manager | Not yet drafted | `UI-7` section uses provisional direct-instantiation until ratified |

### Bucket 5 — Production / Content-Authoring Blockers

| Item | Owner | Blocks |
|------|-------|--------|
| Witness commander assignment per chapter (who is the 운명 포트레이트 at each Beat 7) | producer + narrative-director | Beat 7 portrait asset production (~10 assets for 5-chapter MVP); F-SP-5 epilogue scope logic |
| Scenario JSON authoring schema formalization (`assets/data/scenarios/{scenario_id}.json` field-level spec with validator) | lead-programmer + game-designer + systems-designer | Content authoring start; EC-SP-8 (branch-table validator); CR-13 (Ch1 field prohibitions) |
| Per-chapter `echo_threshold` defaults + validator rules (CR-13 enforcement ruleset) | game-designer + systems-designer | AC-SP-10, AC-SP-12 validator fixture tests |
| Chapter scenario authoring kick-off (Ch1–Ch5 data files + Beat 2 fragment triples + branch tables) | narrative-director + writer + producer | All playable content; resolves all per-chapter PROVISIONAL fields in above contracts |

### Resolved (v1.0 → v2.0)

These v1.0 open questions / blocking items have been resolved in this revision and are recorded for audit trail:

| v1.0 ID | v1.0 status | Resolution in v2.0 |
|---------|-------------|---------------------|
| `OQ-SP-01` (ADR status for GameBus autoload) | Blocking | ADR-0001 Accepted 2026-04-18; contracts stable |
| Pillar 2 cascade-claim architecturally empty | BLOCKING (Top-3) | Pillar 2 reframed as **pre-authored divergence**; CR-4, CR-5, Section B anchor moment rewritten |
| `retry_attempt_cap = 0` ludonarrative dissonance | BLOCKING (Top-3) | Retry consequence model = **Echo state**; CR-7, CR-8, F-SP-3 |
| Beat 2 five-specialist convergent failure | BLOCKING (Top-3) | Beat 2 **multi-modal contract** (CR-9) + Ch1 silent-visual variant (CR-13) + AC-SP-6 (replaces AC-SP-20) + AC-SP-37 (replaces ≤−24 LUFS) |
| Pillar 4 DRAW → LOSS erasure (CR-4) | Blocking | **Tri-state {WIN, DRAW, LOSS}** as distinct outcomes; CR-3, CR-5, F-SP-1; `author_draw_branch` + `draw_fallback` tag |
| `design/gdd/game-pillars.md` broken reference | Blocking | Replaced with `design/gdd/game-concept.md` in Cross-References above |
