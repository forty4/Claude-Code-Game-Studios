# Scenario Progression System (시나리오 진행)

> **Status**: In Design
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-18
> **Last Verified**: 2026-04-18
> **Implements Pillar**: Pillar 4 (삼국지의 숨결) primary; Pillar 2 (운명은 바꿀 수 있다) supporting

## Summary

Scenario Progression is the chapter-level state machine that sequences the player's journey through the 삼국지연의 storyline — loading scenario data, handing it off to Grid Battle, receiving the outcome, then advancing to the next chapter. It owns `assets/data/scenarios/{scenario_id}.json` per balance-data.md CR-2, and sits between Story Event (context) and Grid Battle (combat) so that every battle exists inside a historical frame. Without it, battles are disconnected matches; with it, the session has narrative momentum and a surface for destiny branches to act on.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Balance/Data, Save/Load (provisional), Grid Battle, Hero Database, Destiny State (downstream)`

## Overview

천명역전의 세션은 "스토리 이벤트 → 전투 준비 → 전투 → 전투 결과/운명 판정 → 다음 장(章)"의 리듬으로 흐르며, 시나리오 진행 시스템은 이 리듬의 지휘자다. 한 챕터(章)를 중심 단위로 삼아 시나리오 정의 파일(`scenarios/{scenario_id}.json`)을 로딩하고, 해당 챕터의 전투 데이터 — 맵, 무장 편성, 배치 좌표, 승리/패배 조건 — 를 Grid Battle에 넘기며, `battle_complete(outcome_data)` 시그널로 돌아온 결과를 받아 다음 챕터로 전환한다. MVP에서는 촉한 초반부 **3-5개 챕터**를 선형 순서로 진행하며, 각 챕터의 결과(승/패 + 운명 분기 달성 여부)는 Destiny State Tracking과 Save/Load에 전달되어 이후 챕터의 시작 조건을 결정한다(Save/Load GDD 미작성 — Dependencies에 잠정 계약 명시). 플레이어는 이 시스템의 기계적 작동을 직접 조작하지 않지만, "다음 장은 어떻게 될까?" — 관우가 살았기에 형주의 이야기가 달라질 것이라는 기대 — 가 이 시스템의 존재 증명이다. 이 시스템이 없으면 전투는 역사의 맥락을 잃고 Pillar 4(삼국지의 숨결)가 성립하지 않으며, Pillar 2(운명은 바꿀 수 있다)의 변화가 전파될 무대도 사라진다.

## Player Fantasy

5장에 도달했을 때, 플레이어는 자신이 지나온 1·2·3·4장이 단순한 과거가 아님을 느낀다. 앞 장에서 관우를 놓친 선택, 장판파에서 지킨 조운 — 그 결정들이 지금 눈앞의 지도와 등장 무장 명단에 **살아 있다**. 이 시스템의 환상은 "다음 장"이 아니라 "쌓여온 장들이 지금 이 장을 다르게 만들고 있다"는 자각 — 연쇄 영향(chain reaction)이 시간의 무게로 체감되는 감각이다.

1회차 플레이어는 이 무게를 두려움으로 경험한다: 역사의 비극이 한 장씩 가까워진다. 3회차 이상의 플레이어는 같은 무게를 주도권으로 경험한다: 지금 쌓는 돌 하나가 세 장 뒤의 전장을 바꿀 것을 안다. 같은 시스템이 회차에 따라 다르게 울리는 것 — 그것이 쌓임의 설계다.

*이 시스템은 Pillar 4(삼국지의 숨결 — 전투가 역사의 맥락 속에 존재함)를 일차 지탱하며, Pillar 2(운명은 바꿀 수 있다 — 변경된 역사의 연쇄 전파)의 무대 역할을 한다. Grid Battle의 환상이 "이 한 수가 판을 뒤집었다"이고 Destiny Branch의 환상이 "내가 역사를 바꿨다"라면, Scenario Progression의 환상은 그 사이의 공간 — "내가 쌓아온 장들이 지금을 만든다"다. 앵커 순간: N번째 장의 지도가 열리는 순간, 1장에서 했던 선택 때문에 이번 전장에 새로운 무장이 합류해 있거나 익숙한 적이 사라져 있을 때.*

## Detailed Design

### Core Rules

**CR-1 — Chapter is the atomic progression unit.**
One chapter = one Grid Battle + framing beats. MVP ships 3–5 linear chapters. No chapter-select, no branching chapter graph in MVP (branches act on *content within* a chapter, not on chapter order).

**CR-2 — Canonical chapter sequence (9 beats).**
Every chapter runs this sequence in order. Beats 1–4, 6–9 are non-combat; beat 5 is the battle.
  1. **Historical Anchor Narration** — text/SFX card naming the historical moment.
  2. **Prior-State Echo** — minimum 4 references to accumulated state (see CR-6).
  3. **Situation Briefing Dialogue** — Story Event content; Scenario owns only the trigger.
  4. **Battle Preparation** — roster confirm, deployment placement.
  5. **Battle** — handoff to Grid Battle; await `battle_complete(outcome_data)`.
  6. **Outcome Narration** — WIN/LOSS-specific closing beats.
  7. **Destiny Judgment** — **silent**; Scenario queries Destiny Branch predicates and stores result. No UI.
  8. **Revelation Beat** — if a destiny branch triggered, reveal it here (end-of-chapter, not mid-battle).
  9. **Chapter Transition** — autosave fires *only on WIN or Abandon*, then LOADING_CHAPTER for next.

**CR-3 — Pacing contract.**
Non-combat time (beats 1–4 + 6–9 combined) target: **4–5 min**, min **2 min**, max **7 min**. Scenario does not enforce beat-level timing but exposes `skip_event` input per beat (see Save/Load provisional contract).

**CR-4 — Outcome mapping.**
`outcome_data.result` values from Grid Battle: `WIN`, `LOSS`, `DRAW`. **DRAW is treated as LOSS** by policy — Scenario routes DRAW through the LOSS exit edge. Validator accepts only `{win, loss}` keys in `next_chapter`.

**CR-5 — LOSS handling.**
After beat 6 Outcome Narration on a loss, player is offered **Retry** or **Abandon**:
  - **Retry**: re-enter BATTLE_PREP with the pre-battle state (no autosave written, no destiny judgment run).
  - **Abandon**: advance to beat 7 Destiny Judgment with `result=LOSS` and proceed down the loss path. Autosave fires at beat 9 as normal.

**CR-6 — Prior-state echo minimums.**
Beat 2 must reference at least 4 of: (a) roster delta vs historical baseline, (b) last chapter's destiny outcome, (c) persistent NPC attitude flag, (d) environmental/regional label (e.g., "형주 수복 이후"). Content is Story Event's; Scenario asserts the reference-count contract at scenario validation (WARNING on miss).

**CR-7 — Autosave atomic definition.**
Autosave fires at **exactly** `branch_judgment_complete` (end of beat 7) on WIN or Abandon. LOSS-retry path does **not** autosave. There is no mid-chapter save in MVP.

**CR-8 — HP reset ownership.**
Scenario does **not** reset HP. HP reset is owned by Grid Battle per `hp-status.md` CR-1b (reset per battle on BATTLE_START). Scenario only supplies the unit roster.

**CR-9 — Destiny flag access is read-only from Scenario.**
Scenario reads `destiny_state.has_flag(key)` for beat-2 references and beat-7 predicate evaluation. Scenario never writes to Destiny State — writes happen inside Destiny Branch on judgment.

### States and Transitions

Scenario Progression runs as a 10-state machine. States map to the 9-beat sequence from CR-2 plus infrastructure states (IDLE, ERROR, COMPLETE).

#### States

| # | State | Beat(s) | Purpose |
|---|-------|---------|---------|
| 1 | `IDLE` | — | No scenario loaded. Initial state. |
| 2 | `LOADING_CHAPTER` | — | Reads `scenarios/{scenario_id}.json` chapter block; validates; resolves refs. |
| 3 | `OPENING_EVENT` | 1–3 | Historical Anchor → Prior-State Echo → Situation Briefing. |
| 4 | `BATTLE_PREP` | 4 | Roster confirm + deployment placement. |
| 5 | `IN_BATTLE` | 5 | Scene handed to Grid Battle; ScenarioRunner awaits `battle_complete`. |
| 6 | `OUTCOME` | 6 | Outcome Narration. On LOSS, offers Retry/Abandon. |
| 7 | `BRANCH_JUDGMENT` | 7 | Silent. Evaluates destiny predicates; stores result. |
| 8 | `TRANSITION` | 8–9 | Revelation Beat (if any) → autosave → next chapter. |
| 9 | `COMPLETE` | — | Final chapter's TRANSITION finished; session at scenario end. |
| 10 | `ERROR` | — | Load failure, battle timeout, or unknown-branch-key recovery. |

#### Transition Table

| From → To | Trigger | Side Effect |
|-----------|---------|-------------|
| IDLE → LOADING_CHAPTER | `start_scenario(id)` or resume from save | Read scenario file |
| LOADING_CHAPTER → OPENING_EVENT | Chapter block parsed + validated | Story Event cue fires beat 1 |
| LOADING_CHAPTER → ERROR | Parse/validate failure | `push_error`, offer reload-last-autosave |
| OPENING_EVENT → BATTLE_PREP | Beat 3 complete | Load unit_roster, deployment_positions |
| BATTLE_PREP → IN_BATTLE | Player confirms deployment | Scene transition; GameBus relay armed |
| IN_BATTLE → OUTCOME | `battle_complete(outcome_data)` received | Store outcome; play Outcome Narration |
| IN_BATTLE → ERROR | 3600s watchdog timeout | `push_error`, offer reload-last-autosave |
| OUTCOME → BATTLE_PREP | LOSS + player chose Retry | Restore pre-battle snapshot |
| OUTCOME → BRANCH_JUDGMENT | WIN, or LOSS + player chose Abandon | Evaluate predicates silently |
| BRANCH_JUDGMENT → TRANSITION | Predicates resolved | Stage Revelation Beat content (if triggered) |
| BRANCH_JUDGMENT → ERROR | Unknown branch key | `push_error`; treat as not-triggered + continue |
| TRANSITION → LOADING_CHAPTER | `next_chapter_id` resolved + not last chapter | Fire autosave (WIN/Abandon path) |
| TRANSITION → COMPLETE | Final chapter finished | Fire autosave; emit `scenario_complete` |
| ERROR → LOADING_CHAPTER | Player chose reload-last-autosave | Reload save |
| ERROR → IDLE | Player chose return-to-title | Clear session state |

#### Handoff mechanics

**Battle handoff (BATTLE_PREP → IN_BATTLE → OUTCOME)**: ScenarioRunner lives in a persistent scene above Grid Battle. When BATTLE_PREP confirms, SceneManager loads the Grid Battle scene with a payload (`map_id`, `unit_roster[]`, `deployment_positions{}`, `victory_conditions{}`, optional `battle_start_effects[]`). A **GameBus autoload** (architecture-level — see Open Questions / ADR candidate) relays the `battle_complete(outcome_data)` signal from the Grid Battle scene back to ScenarioRunner, which then unloads Grid Battle and enters OUTCOME.

**outcome_data shape** (received from Grid Battle per `grid-battle.md` §5):

```
{
  result: WIN | LOSS | DRAW,      # DRAW mapped to LOSS per CR-4
  rounds_used: int,
  surviving_units: [unit_id],
  fatalities: [unit_id]
}
```

**Error recovery**: ERROR state always offers two exits — reload-last-autosave (back to LOADING_CHAPTER) or return-to-title (IDLE). No silent recovery.

### Interactions with Other Systems

This sub-section specifies ownership boundaries and interface contracts for every system Scenario Progression touches.

#### Ownership map

| System | What Scenario owns | What the other system owns |
|--------|--------------------|-----------------------------|
| **Story Event** | Trigger sequencing (which beat fires when) | Beat content (narration text, dialogue, presentation) |
| **Grid Battle** | Battle payload construction; listening for outcome | All combat resolution; emits `battle_complete(outcome_data)` on CLEANUP |
| **Destiny Branch** | *When* predicates are evaluated (beat 7 only) | *How* predicates evaluate; the set of defined branch keys |
| **Destiny State** | Read-only queries (`has_flag`, `get_outcome`) | Flag storage, writes, serialization |
| **Hero Database** | Resolving `unit_id → hero_record` at LOADING_CHAPTER | Hero stats, `join_chapter`, base roster |
| **Balance/Data** | `scenarios/` category schema + validation rules | Loader pipeline (Discovery → Parse → Validate → Build) |
| **Save/Load** *(provisional)* | Emitting checkpoint payload at beat 7 complete | Serialization, slot management, resume orchestration |

#### Upstream interfaces (Scenario reads)

- **`balance_data.get("scenarios", scenario_id)`** → scenario JSON, pre-validated. Scenario does **not** re-validate on read.
- **`hero_database.get(unit_id)`** → hero record. Called for each `unit_roster[]` entry during LOADING_CHAPTER.
- **`destiny_state.has_flag(key)`** → `bool`. Used in beat 2 Prior-State Echo authoring and beat 7 predicate evaluation.
- **`destiny_state.get_last_outcome()`** → `{chapter_id, branch_triggered|null}`. Used for beat-2 reference (b).
- **`destiny_branch.evaluate(chapter_id, outcome_data, destiny_state)`** → `{branch_key|null, revelation_cue_id|null}`. Single silent call at beat 7.

#### Downstream interfaces (Scenario emits)

- **Signal `chapter_started(chapter_id, chapter_number)`** — fires on entering OPENING_EVENT. Story Event subscribes.
- **Signal `battle_prepare_requested(payload)`** — fires on entering BATTLE_PREP. UI layer (deployment screen) subscribes.
- **Signal `battle_launch_requested(payload)`** — fires on BATTLE_PREP → IN_BATTLE transition. SceneManager subscribes; GameBus relays `battle_complete` back.
- **Signal `chapter_completed(result)`** — fires at end of BRANCH_JUDGMENT, with shape `ScenarioProgressionResult { chapter_id, outcome, branch_triggered, flags_to_set[] }`. Destiny State subscribes to write flags; Save/Load subscribes to trigger autosave.
- **Signal `scenario_complete(scenario_id)`** — fires on entering COMPLETE.

#### Scenario file location & load pattern

- **Path**: `assets/data/scenarios/{scenario_id}.json` (locked by `balance-data.md` CR-2).
- **Load pattern**: per-scenario, lazy. DataRegistry loads only the active scenario's file; not all scenarios at boot.
- **Category**: `"scenarios"` in the Balance/Data REQUIRED_CATEGORIES list. Missing file is FATAL per Balance/Data validation.
- **Envelope**: standard `{schema_version, category: "scenarios", data: {...}}` per Balance/Data JSON envelope contract.

#### Provisional Save/Load contract

Until `save-load.md` (#17 VS) is authored, Scenario designs against this provisional checkpoint payload emitted at beat 7 complete:

| Field | Type | Purpose |
|-------|------|---------|
| `schema_version` | int | Per-file schema version |
| `scenario_id` | string | Active scenario |
| `current_chapter_id` | string | Chapter just completed |
| `chapter_number` | int | 1-indexed |
| `completed_chapters[]` | string[] | History of cleared chapter_ids |
| `chapter_outcomes{}` | map | `chapter_id → {result, branch_triggered}` |
| `destiny_state_snapshot_ref` | string | Opaque ID; Destiny State owns format |
| `mid_chapter_resume_beat` | int\|null | Always `null` in MVP (no mid-chapter save) |
| `mid_chapter_battle_active` | bool | Always `false` in MVP |

Any change to this contract after `save-load.md` is authored must update both GDDs bidirectionally.

## Formulas

Scenario Progression is a state-machine system; most of its "math" is routing logic and validation asserts rather than numerical computation. Combat, stats, and growth formulas live in other GDDs.

### F-SP-1 — Chapter number derivation

Current chapter's 1-indexed position in the played sequence.

- **Variables**:
  - `completed_chapters` — array of chapter_ids already cleared (WIN or Abandon). From save/session state.
- **Formula**: `chapter_number = len(completed_chapters) + 1`
- **Output range**: `[1, N]` where N = total chapters in scenario (3–5 for MVP).
- **Example**: Player just cleared Chapter 1 (Yellow Turban Skirmish) → `completed_chapters = ["ch01_yellow_turban"]` → entering Chapter 2 → `chapter_number = 2`.
- **Used for**: `hero_database.get` filter (heroes where `join_chapter ≤ chapter_number`), Prior-State Echo reference (b), UI "제N장" labels.

### F-SP-2 — Next chapter resolution

Given a completed chapter, resolves the next `chapter_id` to load.

- **Variables**:
  - `current_chapter.next_chapter` — object: `{win: chapter_id|null, loss: chapter_id|null}`
  - `outcome.result` — `WIN | LOSS | DRAW` (DRAW mapped to LOSS by CR-4)
  - `is_abandon` — `bool` (LOSS path only; `true` if player chose Abandon)
- **Formula** (pseudo):

  ```
  effective_result = (outcome.result == DRAW) ? LOSS : outcome.result
  if effective_result == WIN:
      next_id = current_chapter.next_chapter.win
  elif effective_result == LOSS and is_abandon:
      next_id = current_chapter.next_chapter.loss
  else:  # LOSS without Abandon = retry, no next chapter resolved
      next_id = null
  ```

- **Output**: `chapter_id | null`. `null` when `next_chapter.win == null` (scenario complete) or retry branch.
- **Example**: Chapter 3 WIN with `next_chapter = {win: "ch04", loss: "ch04_bad"}` → `next_id = "ch04"`.
- **Example**: Chapter 3 LOSS + Retry → `next_id = null` (re-enter BATTLE_PREP, no transition).
- **Example**: Chapter 3 LOSS + Abandon → `next_id = "ch04_bad"`.

### F-SP-3 — Prior-State Echo reference-count validation

Authoring-time assertion run by scenario validator (WARNING on miss).

- **Variables**:
  - `beat2_content` — authored Story Event content for beat 2.
  - `echo_types` — set of reference categories present: `{roster_delta, last_destiny_outcome, npc_attitude_flag, environmental_label}`.
- **Formula**: `ref_count = |echo_types| ; assert ref_count ≥ 4`
- **Output range**: `[0, 4]`. Violation: `ref_count < 4` → `VALIDATION_WARNING`.
- **Example**: Chapter 5 beat 2 references (a) Guan Yu in roster, (b) Chapter 4's destiny outcome, (c) Zhang Fei's grief flag — but omits environmental label → `ref_count = 3 < 4` → WARNING.
- **Used by**: scenario JSON validator (SV-17 in Interactions).

### F-SP-4 — Scenario completion check

Determines whether TRANSITION should route to COMPLETE.

- **Variables**:
  - `next_id` — output of F-SP-2.
  - `current_chapter.is_final` — bool flag in scenario JSON.
- **Formula**: `scenario_complete = (next_id == null and current_chapter.is_final == true)`
- **Output**: `bool`.
- **Example**: Chapter 5 (`is_final = true`) WIN with `next_chapter.win = null` → `scenario_complete = true` → enter COMPLETE state.
- **Edge**: `next_id == null` but `is_final == false` is a validation error (dangling scenario) — FATAL at load time.

## Edge Cases

### EC-SP-1 — Scenario file missing at `LOADING_CHAPTER`

`balance_data.get("scenarios", scenario_id)` returns null.
→ Balance/Data validation already caught this as FATAL at startup. If it somehow reaches Scenario runtime, enter ERROR, `push_error("scenario file missing: {id}")`, offer reload-last-autosave or return-to-title. Never auto-advance.

### EC-SP-2 — Scenario file present but chapter_id not found

`scenario.chapters[]` has no entry with matching `chapter_id` (e.g., save from older scenario version).
→ Enter ERROR, `push_error("chapter not found in scenario: {chapter_id}")`, offer return-to-title only (autosave is the cause of the corruption). Do not offer reload-last-autosave.

### EC-SP-3 — `next_chapter.win == null` but `is_final == false`

Authoring error: dangling scenario.
→ Caught at scenario load by validator (SV-14). FATAL — scenario fails to load. If bypassed, Scenario treats as scenario_complete=true and enters COMPLETE with a `push_error` warning.

### EC-SP-4 — Hero `join_chapter > chapter_number` but roster includes them

Chapter 2's `unit_roster` lists a hero whose `join_chapter = 4`.
→ Scenario validator warns at load (SV-09 WARNING); at runtime, the hero IS included in the roster — Scenario honors scenario authoring over `join_chapter` (scenario is the narrative contract). Flag documented in Open Questions; may tighten to ERROR post-MVP.

### EC-SP-5 — `battle_complete` signal fires twice

Grid Battle or GameBus bug causes duplicate emission.
→ ScenarioRunner maintains a `battle_outcome_received: bool` guard in IN_BATTLE. First fire transitions to OUTCOME; second fire is ignored with `push_warning("duplicate battle_complete ignored")`.

### EC-SP-6 — Battle watchdog timeout (3600s)

60 minutes elapsed in IN_BATTLE without `battle_complete`.
→ Enter ERROR with reason `BATTLE_TIMEOUT`. Offer reload-last-autosave (loses current chapter progress) or return-to-title. Do NOT fabricate an outcome.

### EC-SP-7 — Destiny flag key referenced but never defined

Beat 2 prior-state echo or beat 7 predicate references `destiny_state.has_flag("flag_not_in_registry")`.
→ `destiny_state.has_flag` returns `false` (read-only, no raise). Logged as `push_warning` once per unknown key. Scenario continues. Validator catches this at load as SV-17 WARNING (elevated to ERROR once Destiny State GDD lands).

### EC-SP-8 — `completed_chapters` contains chapter_ids not in current scenario

Save from older scenario version has cleared `"ch03_old"` which no longer exists.
→ Enter ERROR at resume-from-save. Offer return-to-title only. Do not strip unknown chapter_ids silently — player must start a new scenario.

### EC-SP-9 — App closed mid-battle (no save resume)

Player force-quits during IN_BATTLE. MVP does not mid-chapter save.
→ On relaunch, Scenario resumes from last autosave (end of previous chapter's beat 7). Current in-progress battle is **lost** by design. UI on resume shows "Resumed from Chapter N" with no confusion about mid-battle state.

### EC-SP-10 — App closed mid-OPENING_EVENT or mid-BATTLE_PREP

Same as EC-SP-9 — last autosave is at end of previous chapter.
→ Player re-plays beats 1–4 on resume. Acceptable cost; matches CR-7 no-mid-chapter-save contract.

### EC-SP-11 — Player starts new scenario with save from different scenario

Active save is for `scenario_three_kingdoms`, player starts `scenario_tutorial`.
→ Scenario presents confirmation dialog "This will discard current progress. Continue?" Autosave is overwritten only on confirmation. No silent overwrites.

### EC-SP-12 — Scenario has 0 chapters

Malformed scenario file.
→ Validator catches as FATAL (SV-04). Scenario fails to load.

### EC-SP-13 — Chapter references unknown map_id or hero_id

`battle.map_id = "map_unknown"` or `unit_roster` has `unit_id = "hero_deleted"`.
→ Validator catches at load (SV-05, SV-06). Severity ERROR — scenario fails to enter OPENING_EVENT; stays in ERROR state.

### EC-SP-14 — `chapter_number` diverges from `completed_chapters` length

E.g., `chapter_number = 3` but `completed_chapters = ["ch01"]` (length 1).
→ Invariant violation. F-SP-1 is the source of truth; `chapter_number` from save is discarded in favor of `len(completed_chapters) + 1`. `push_warning("chapter_number desync corrected")`.

### EC-SP-15 — Revelation beat triggered but `revelation_cue_id` is null

Destiny Branch returned `{branch_key: "guan_yu_saved", revelation_cue_id: null}`.
→ Branch triggered but author forgot to author the reveal cue. Scenario skips beat 8 silently with `push_warning`, advances to beat 9. Validator catches as SV-19 WARNING.

## Dependencies

### Upstream (Scenario reads from these)

| System | GDD status | Interface | Notes |
|--------|------------|-----------|-------|
| **Balance/Data** | ✅ `design/gdd/balance-data.md` | `balance_data.get("scenarios", scenario_id)` | Balance/Data already lists `scenarios` in REQUIRED_CATEGORIES. **Bidirectional update: add Scenario Progression to balance-data.md's dependents list.** |
| **Grid Battle** | ⚠️ `design/gdd/grid-battle.md` v4.0 (MAJOR REVISION) | Payload out `{map_id, unit_roster[], deployment_positions{}, victory_conditions{}, battle_start_effects[]?}`; signal in `battle_complete(outcome_data)` on CLEANUP | Scenario's contract holds against grid-battle.md §5; if v5.0 changes the signal shape, Scenario must revise. **Bidirectional update: add Scenario Progression to grid-battle.md's dependents list.** |
| **Hero Database** | ✅ `design/gdd/hero-database.md` | `hero_database.get(unit_id)`; `join_chapter` int 1-indexed | **Bidirectional update: add Scenario Progression to hero-database.md's dependents list.** |
| **Destiny Branch** | ❌ Not designed (#13 MVP Feature) | `destiny_branch.evaluate(chapter_id, outcome_data, destiny_state) → {branch_key\|null, revelation_cue_id\|null}` | **Provisional contract.** Scenario commits to: single silent call at beat 7; returns nullable branch_key. Must be revisited when `destiny-branch.md` lands. |
| **Destiny State** | ❌ Not designed (#16 MVP Feature) | `destiny_state.has_flag(key) → bool`; `destiny_state.get_last_outcome() → {chapter_id, branch_triggered}` | **Provisional contract.** Scenario commits to: read-only access; never writes. Flag key set unknown until `destiny-state.md` lands — validator SV-17 stays WARNING until then. |
| **Story Event** | ❌ Not designed (#11 MVP Feature) | Signal consumer: `chapter_started(chapter_id, chapter_number)` triggers beats 1–3, 6, 8 presentation | **Provisional contract.** Scenario owns *when* beats fire; Story Event owns *what plays*. Must revisit when `story-event.md` lands. |
| **Save/Load** | ❌ Not designed (#17 VS) | Checkpoint payload emitted at `chapter_completed` (see Section C.3 provisional table) | **Provisional contract.** Scenario commits to: 9-field payload shape; fires on WIN or Abandon only. May be revised when `save-load.md` lands. |

### Downstream (these consume from Scenario)

| System | GDD status | Interface | Notes |
|--------|------------|-----------|-------|
| **Destiny State** | ❌ Not designed (#16) | Subscribes to `chapter_completed(result)` to write flags | Write ownership remains with Destiny State, not Scenario. |
| **Save/Load** | ❌ Not designed (#17 VS) | Subscribes to `chapter_completed` to trigger autosave | Save/Load owns serialization; Scenario only triggers. |
| **Story Event** | ❌ Not designed (#11) | Subscribes to `chapter_started` for beats 1, 3, 6, 8 content playback | |
| **UI layer** (Deployment screen) | Not yet specced | Subscribes to `battle_prepare_requested(payload)` | Belongs to battle-prep UI GDD (future). |
| **SceneManager** | Architecture concern | Subscribes to `battle_launch_requested(payload)`; GameBus autoload relays `battle_complete` back | See Open Questions for ADR candidate. |

### Bidirectional updates required on approval

When Scenario Progression GDD is approved, these files must be updated to mention Scenario as a dependent. This is a bookkeeping task, not a design task:

- `design/gdd/balance-data.md` — add Scenario Progression to "Dependents" list and note `scenarios` category ownership.
- `design/gdd/grid-battle.md` — add Scenario Progression to "Dependents" list; note that Scenario owns the battle payload assembly.
- `design/gdd/hero-database.md` — add Scenario Progression to "Dependents" list; note that Scenario consumes `join_chapter`.
- `design/gdd/hp-status.md` — add Scenario Progression to "Dependents" list (Scenario asserts HP reset ownership boundary).
- `design/gdd/systems-index.md` — update Scenario Progression row status from "Not Started" to "In Design" → "Approved" on review pass.

### Provisional contracts summary

Three upstream systems (Destiny Branch, Destiny State, Save/Load) and one (Story Event) are undesigned. All provisional contract surfaces are documented in Section C.3 and here. **Risk**: if any of these GDDs commits to a different shape during their authoring, Scenario Progression requires a revision pass.

## Tuning Knobs

| Knob | Default | Safe range | Affects | Config location |
|------|---------|------------|---------|-----------------|
| `non_combat_target_min_s` | 120 | 60–180 | Pacing floor. Chapters shorter than this feel transactional; Pillar 4 weakens. | `scenario_config.json` |
| `non_combat_target_s` | 270 | 180–360 | Pacing target (4.5 min). Beats 1–4 + 6–9 combined. Authoring guideline; Scenario does not enforce. | `scenario_config.json` |
| `non_combat_target_max_s` | 420 | 300–600 | Pacing ceiling. Beyond this, players skip; Pillar 4 immersion drops. Scenario surfaces a WARNING when authored beats exceed this. | `scenario_config.json` |
| `battle_watchdog_s` | 3600 | 1800–7200 | IN_BATTLE timeout. Too low → false timeouts on slow play; too high → frozen battles hang session. | `scenario_config.json` |
| `prior_state_echo_min_refs` | 4 | 2–6 | Beat 2 reference-count threshold (F-SP-3). Lower = forgiving authoring / weaker accumulation feel. | `scenario_config.json` |
| `retry_attempt_cap` | 0 (unlimited) | 0–10 | If > 0, Scenario forces Abandon after N failed retries. 0 = never force. MVP default is unlimited retries. | `scenario_config.json` |
| `autosave_on_abandon` | `true` | `{true, false}` | Whether Abandon path triggers autosave. Default true (CR-7). Disabling means Abandon re-enters from last WIN-autosave on relaunch. | `scenario_config.json` |
| `draw_policy` | `"treat_as_loss"` | `{"treat_as_loss", "reject_draw"}` | DRAW outcome handling (CR-4). `reject_draw` is post-MVP; Grid Battle victory conditions would need to exclude DRAW states. | `scenario_config.json` |
| `mvp_chapter_count_min` | 3 | 1–8 | Minimum chapters a scenario must define. Validator SV-04 threshold. | `scenario_config.json` |
| `mvp_chapter_count_max` | 5 | 3–20 | Maximum chapters per scenario. Soft guideline for MVP scope. Validator emits WARNING if exceeded. | `scenario_config.json` |
| `revelation_beat_max_s` | 20 | 10–45 | Beat 8 content length ceiling. Prevents post-chapter reveal from stalling return-to-menu. | `scenario_config.json` |
| `ERROR_exit_options` | `["reload", "title"]` | — | Which exits ERROR state offers. `reload` available only when last autosave is intact. Not a numeric knob but a config flag. | `scenario_config.json` |

**Non-knobs** (looks tunable but is a contract, not a preference):

- The **9 beats** are a contract, not a knob. Reordering or omitting beats breaks Story Event and Destiny State integration.
- The **autosave atomic point** (end of beat 7) is a contract with Save/Load, not a knob.
- **DRAW → LOSS mapping logic** (as opposed to the `draw_policy` enum) is a contract.

## Visual/Audio Requirements

Non-battle beats 1, 2, 4, 6, 8, 9 are Scenario Progression's visual/audio surface. Beats 3 (Story Event), 5 (Grid Battle), 7 (silent by design) are owned elsewhere.

### Visual — per beat

**Beat 1 (Historical Anchor Card).** Full-bleed card, asymmetric composition. Title anchors upper-left third; 인장 seal lower-right third; remaining two-thirds deliberate void. Background: 지백 (#F2E8D4) with 황토 (#C8874A) corner vignette ≤12%, dry-brush edge bleed inward 5–8%. Seal: 묵 (#1C1A17) at 80% opacity, rotated 2–3°. Typography: period brush typeface, 28–32sp title, 16sp subtitle at 60% opacity. Animation: ink-bleed reveal from center over 0.6s; seal lands last. Skip affordance: full-screen tap, 44px minimum; "tap to continue" hint after 1.5s.

**Beat 2 (Prior-State Echo).** Must feel like memory surfacing, not a data readout. Four reference layers fade in and out sequentially (NOT simultaneously) across 4–6s:

- (a) Roster delta — hero portrait fragment, shoulder-cropped, 40% opacity; lost heroes render in desaturated ink-wash, gained in muted color. 1.2s.
- (b) Last destiny outcome — 14sp handwritten-angle margin note. 3s persistence.
- (c) NPC attitude flag — eyes-only portrait crop, 30% opacity. 0.8s.
- (d) Environmental label — ink-brush geographic label brushed onto existing card. 2s.

**No 주홍 or 금색 in Beat 2 under any circumstances**, even on prior destiny triumph — use muted color language only. Reserved colors belong to Beat 8 alone.

**Beat 6 (Outcome).** Partial-screen card, bottom third; upper two-thirds implied battlefield aftermath. Double-border panel (art bible UI grammar).

- **WIN**: ink density *decreases*; more 지백 breathes through. 묵 text on 지백 field; panel border carries 황토 warm accent. Mood: 결연함 (resolute), not radiant.
- **LOSS**: ink density *increases*; 묵 compresses 지백. Panel border pure 묵 double-line. Retry/Abandon buttons inside card: Retry primary (青灰, 44px), Abandon secondary (묵, 44px). **No 주홍 on either button** — practical choice, not destiny.

Card rises from below in 0.4s ease-out; ink-tone shift is a 1.5s ambient background transition.

**Beat 8 (Revelation) — where 주홍 and 금색 earn their entrance.** Only fires when Destiny Branch returned a non-null `branch_key`. When no branch triggers, Beat 8 is visually invisible (absence is information).

When triggered:

1. 0.0–0.3s: hold inherited Beat 7 state.
2. 0.3–0.6s: single 주홍 (#C0392B) brushstroke bleeds in left-to-right at mid-height, full opacity. **First moment of red in the chapter.**
3. 0.6–1.2s: revelation text above stroke — 24sp brush typeface in **묵** (not 주홍). The red is the stroke beneath, not the text.
4. 1.2–2.0s: IF branch is a positive destiny shift, 금색 (#D4A017) seeps from stroke center — warmth diluting into 주홍, max 30% screen width at peak. IF loss-path revelation, 금색 does **not** appear; 주홍 fades alone over 3s.
5. 2.0–4.0s (capped by `revelation_beat_max_s`): full cue displays, affected hero portrait at 50% screen height, full color + 금빛 테두리 빛 on positive branch. Skip affordance active throughout.

**Grammar the player learns**: 주홍 alone = door closes. 주홍 + 금색 = door opens.

**Beat 9 (Chapter Transition).** Functional beat, ink-wash register maintained. Autosave: small 인장 stamp animation lower-right (0.2s) + "저장 완료" 12sp 60% opacity 묵 marginal note. No spinners, no external save icons. Next-chapter preview: Beat 1 title cropped at 50% opacity beneath autosave confirmation — promise, not trailer. 2–3s before LOADING_CHAPTER auto-advance; 44px skip. **LOSS/Abandon variant**: preview uses 먹화 (heavier ink) continuity from Beat 6 LOSS.

### Audio — per beat

**Beat 1.** Single guzheng harmonic pluck (not a chord — decay is the sound). Mobile-safe: chords wash out, single notes survive. After 1.5–2s, low erhu drone enters at −18 LUFS, holds under narration. SFX: one wooden frame drum / ban (板) transient, pitched low, ~80ms gated decay, fires **on the frame the text card appears** (not after). Assets: `sfx_chapter_anchor_seal_01.ogg`, `mus_chapter_anchor_entry_loop.ogg` (8-bar loop minimum).

**Beat 2.** Sparse, not silent. Each of the 4 reference layers gets a bamboo-breath micro-cue (not a note — a breath) timed to UI appearance. ≤−24 LUFS, ≤400ms. Asset: `sfx_echo_stateref_breath_01.ogg` (reused for all 4, no pitch variation). **Fallback** if UI timing is too cluttered: single erhu drone continuity from Beat 1 at −22 LUFS — drone continuing is itself the signal. Micro-cue approach preferred but requires tight UI timing contract.

**Beat 4 (Battle Prep).** Tension without reveal; battle music is Grid Battle's domain. Slow taiko-adjacent heartbeat (two strokes, 70 BPM, ~4-bar gap between pairs) + low bamboo flute pedal tone underneath. 16-bar loop minimum; no melodic content (would compete with Grid Battle handoff). On confirm: ban strike + guzheng upward pluck = handoff signal, last audio Scenario owns before Grid Battle takes over. Assets: `amb_chapter_battleprep_tension_loop.ogg`, `sfx_battleprep_confirm_deploy_01.ogg`.

**Beat 6.** WIN/LOSS must be unmistakable without reading text.

- **WIN**: guzheng 4-note ascending figure landing on pentatonic root + erhu sustained fifth above. 6–8s one-shot (no loop). −12 LUFS. Deliberately small — **not celebratory**. Escalating this for "bigger wins" erases Pillar 4 accumulated weight.
- **LOSS**: Beat 1 erhu drone returns, descends half-step, ends on minor-second-above-tonic (unresolved). Silence after 3s. **No "sad music" swell** — descent into dissonance + silence outperforms mournful melody.

Assets: `mus_outcome_win_resolve_01.ogg`, `mus_outcome_loss_descend_01.ogg`.

**Beat 7 (Destiny Judgment) — silence is the design.** No audio event fires. Audio bus muted (not just faded — no reverb tail bleed). Silence makes fate feel like it operates on its own terms, indifferent to player attention. Silence also creates the container Beat 8 will break. **Lead-programmer implementation contract**: bus mute, not fade; confirm no Beat 4 ambient bleeds through.

**Beat 8 (Revelation).**

- **Triggered**: single guzheng harmonic at reveal UI top, held 2s → second note a major third below → silence. ~5s total. −10 LUFS — loudest moment of the non-combat sequence. Only place audio is allowed to *lead* attention.
- **Untriggered**: silence. No "nothing happened" cue — absence confirms non-trigger.

Asset: `mus_revelation_destiny_trigger_01.ogg`.

**Beat 9.** Autosave SFX: brushed-cymbal shimmer or bronze bell tap, ≤800ms, −22 LUFS, functional (not dramatic). Next-chapter music bridge: new guzheng phrase crossfades from silence (not from Beat 8) over 2s, loops until next chapter's Beat 1 SFX fires. **Each chapter authors its own bridge phrase** — reusing one phrase homogenizes chapters and erases Pillar 4 weight. MVP: 5 bridges, not 1. Assets: `sfx_chapter_autosave_confirm_01.ogg`, `mus_chapter_transition_bridge_loop_{chXX}.ogg`.

### Pillar 4 risk surface

- **Beat 2 collapsing into a data readout** — visual must feel involuntary (memory surfacing), not informational; micro-cue sounds must lock to UI reveal timing, not hover or render.
- **Beat 8 firing without rarity** — if destiny branches trigger too often, 주홍 stroke + guzheng harmonic lose weight by chapter 3. Content design constraint: design as if seen 2–3 times per playthrough.
- **Beat 9 energy competing with Beat 8** — transition must feel like exhale after held breath; any visual/audio momentum equaling Beat 8 is a Pillar 4 violation.
- **Triumphalism on WIN** — full-orchestra swells or fanfares reset the emotional ledger; accumulated cost evaporates. Keep WIN cue deliberately small.

### Platform constraints

- Mobile (iOS/Android) + PC both supported.
- No hover-only interactions — every skip/continue affordance is tap/click with 44px minimum touch target.
- Audio must survive small mobile speakers (single notes over chords; transient percussion over sustained swells).

## UI Requirements

Scenario Progression owns the non-battle screen layer. Per-beat UI surfaces:

- **Beat 1 — Historical Anchor Card.** Full-screen modal. Single skip affordance (44px tap region, full-screen). No other interactable elements.
- **Beat 2 — Prior-State Echo layer.** Overlay on lingering Beat 1 card background; no interaction elements. Skip affordance same as Beat 1.
- **Beat 4 — Deployment screen.** Scenario emits `battle_prepare_requested(payload)`; a dedicated battle-prep UI (separate GDD, not authored here) owns the deployment surface. Scenario requires: (a) the UI must emit `battle_launch_confirmed` back to Scenario, (b) must expose an "abort back to main menu" path that returns Scenario to IDLE.
- **Beat 6 — Outcome Card.** Bottom-third panel. On WIN: primary "계속" button (44px). On LOSS: two-button row — Retry (primary, 44px), Abandon (secondary, 44px). Buttons must be keyboard-navigable (tab-order) and gamepad-navigable (D-pad), not hover-dependent.
- **Beat 8 — Revelation Overlay.** Full-screen. Skip affordance active immediately (full-screen tap, 44px). Auto-advance at `revelation_beat_max_s`.
- **Beat 9 — Chapter Transition Card.** Full-screen. Skip affordance jumps directly into LOADING_CHAPTER. Auto-advance after 2–3s.
- **ERROR state dialog.** Modal centered. Two buttons: "마지막 저장 불러오기" (only shown if last autosave intact) + "제목 화면으로" (always shown). 44px minimum. Error reason rendered in a small text block above buttons, never hidden.
- **Scenario-restart confirmation dialog** (EC-SP-11). Modal. Two buttons: "계속" (discard current save) + "취소" (return). 44px. Default focus on "취소" — destructive actions never default-focus.

### Cross-cutting UI rules

- All Scenario-owned UI runs on touch + mouse + keyboard. No hover-only states.
- All buttons minimum 44px touch target (per project technical-preferences).
- Skip affordances never require a precise aim — full-screen tap regions for narrative beats.
- Text rendering must support Korean at 14sp minimum; narration at 16sp+.
- No UI element uses 주홍 or 금색 outside Beat 8 (per art bible reserved-color contract).
- Modal error/confirm dialogs dim the background to 50% opacity black — consistent with art bible modal grammar.

### Accessibility notes (MVP floor)

- All skip affordances also bind to keyboard `Space` / `Enter`.
- Button focus rings use a high-contrast outline (not color alone).
- Beat 2 duration (4–6s) is long enough to read at slow reading speed; auto-advance respects `revelation_beat_max_s` but always allows manual skip.

Full accessibility GDD handles contrast ratios, font-size scaling, motion-reduce fallbacks for ink-bleed animations — out of scope here.

## Cross-References

### Upstream GDDs (this system depends on)

- `design/gdd/balance-data.md` — CR-2 (scenarios category ownership), JSON envelope contract, REQUIRED_CATEGORIES.
- `design/gdd/grid-battle.md` §5 (`battle_complete(outcome_data)` on CLEANUP), §2.3 (victory condition types), CR-1 (battle payload surface).
- `design/gdd/hero-database.md` — Scenario Block (`join_chapter` int 1-indexed), hero record shape.
- `design/gdd/hp-status.md` — CR-1b (HP reset per battle on BATTLE_START, owned by Grid Battle).

### Downstream / provisional (contracts this system establishes)

- `design/gdd/destiny-branch.md` (future #13) — will consume `destiny_branch.evaluate(chapter_id, outcome_data, destiny_state)` contract.
- `design/gdd/destiny-state.md` (future #16) — will define flag key schema, subscribe to `chapter_completed(result)`.
- `design/gdd/save-load.md` (future #17 VS) — will consume 9-field checkpoint payload.
- `design/gdd/story-event.md` (future #11) — will subscribe to `chapter_started(chapter_id, chapter_number)` and provide beats 1–3, 6, 8 content.

### Supporting references

- `design/gdd/game-concept.md` — Pillar 4 (삼국지의 숨결), Pillar 2 (운명 역전), MVP scope.
- `design/gdd/systems-index.md` — #12 Scenario Progression row; updates on approval.
- `design/gdd/game-pillars.md` — pillar definitions.
- `design/art/art-bible.md` — reserved colors (주홍 + 금색), ink-wash language, 인장 grammar.
- `design/registry/entities.yaml` — cross-system facts; Scenario will register new entries (scenario file path, chapter ID convention) on approval.

### Documents that must update when this GDD approves

- `design/gdd/balance-data.md` — add Scenario Progression to dependents list.
- `design/gdd/grid-battle.md` — add Scenario Progression to dependents list.
- `design/gdd/hero-database.md` — add Scenario Progression to dependents list.
- `design/gdd/hp-status.md` — add Scenario Progression to dependents list.
- `design/gdd/systems-index.md` — row status "Not Started" → "Approved".
- `design/registry/entities.yaml` — new entries for cross-system facts introduced here.

## Acceptance Criteria

Each criterion is verifiable by a QA tester. Tied to specific CR / F-SP / EC entries.

### Logic & state machine

- **AC-SP-01** (CR-1 / F-SP-4) — A scenario file with 3–5 chapters loads successfully; a file with 0, 1, 2 or > 20 chapters fails validation with the documented severity (FATAL/WARNING).
- **AC-SP-02** (CR-2) — On `start_scenario()`, beats 1–9 fire in order; no beat is skipped unless explicitly triggered (beat 8 skip on null branch_key).
- **AC-SP-03** (CR-4) — A battle returning `outcome_data.result = DRAW` routes through the LOSS exit edge in F-SP-2; `next_chapter.draw` key is not read.
- **AC-SP-04** (CR-5) — On LOSS, UI presents both Retry and Abandon buttons; Retry re-enters BATTLE_PREP with no autosave write; Abandon enters BRANCH_JUDGMENT with `result=LOSS` and autosave fires at beat 9.
- **AC-SP-05** (CR-7) — Autosave fires exactly once per chapter, at `branch_judgment_complete`. On Retry, no autosave is written.
- **AC-SP-06** (CR-8) — Scenario never calls `unit.reset_hp()`; Grid Battle's BATTLE_START is the only HP-reset site (verified by grep + integration test).
- **AC-SP-07** (CR-9) — Scenario never calls any `destiny_state.set_*` or `destiny_state.write_*` method (verified by grep on codebase after implementation).
- **AC-SP-08** (F-SP-1) — `chapter_number` always equals `len(completed_chapters) + 1`, even after a corrupted save (EC-SP-14 desync is corrected, not propagated).
- **AC-SP-09** (F-SP-2) — Unit tests cover 4 routing cases: WIN, LOSS+Retry, LOSS+Abandon, DRAW. All resolve to the documented `next_id`.
- **AC-SP-10** (F-SP-3) — Validator emits `VALIDATION_WARNING` when a chapter's beat 2 content references fewer than 4 of the echo categories.

### State transitions

- **AC-SP-11** — All 15 valid transitions in the transition table are reachable in a test scenario; no unlisted transition succeeds (verified via state machine test harness).
- **AC-SP-12** — Firing `start_scenario` from any state other than IDLE is rejected with a `push_error` — never silently replaces active session.

### Edge cases

- **AC-SP-13** (EC-SP-1) — Missing scenario file produces ERROR state with correct error_reason; does not crash the session.
- **AC-SP-14** (EC-SP-5) — `battle_complete` fired twice produces exactly one OUTCOME entry; second fire logs a warning and is ignored.
- **AC-SP-15** (EC-SP-6) — Injecting a 3600s+1 delay in IN_BATTLE produces ERROR with reason `BATTLE_TIMEOUT`; Scenario does not synthesize an outcome.
- **AC-SP-16** (EC-SP-9) — Force-close during IN_BATTLE (simulated) followed by relaunch: Scenario resumes at LOADING_CHAPTER for the chapter where the last autosave landed.
- **AC-SP-17** (EC-SP-11) — Starting a new scenario with an active save from a different scenario shows the confirmation dialog with default focus on "취소".

### Visual / audio

- **AC-SP-18** (Beat 8) — 주홍 brushstroke appears only when `branch_key != null`; 금색 seep appears only when branch is a positive destiny shift. Verified via screenshot evidence for all branch combinations.
- **AC-SP-19** (Beat 7) — Audio bus is muted (not faded) during BRANCH_JUDGMENT; no Beat-4 ambient bleeds through. Verified via audio capture during test play.
- **AC-SP-20** (Beat 2) — 4 echo reference layers fade in and out sequentially; at no point do more than 2 layers occupy the screen at ≥50% opacity simultaneously. Verified via frame-sampled screenshot evidence.

### UI / input

- **AC-SP-21** — All skip affordances respond to mouse click, keyboard Space/Enter, and touch (44px minimum). No skip requires hover.
- **AC-SP-22** — Beat 6 LOSS buttons (Retry, Abandon) are reachable via keyboard Tab and gamepad D-pad.
- **AC-SP-23** — ERROR dialog and restart-confirmation dialog both default-focus the safe option (reload / 취소).

### Data / registry

- **AC-SP-24** (Dependencies) — On GDD approval, `balance-data.md`, `grid-battle.md`, `hero-database.md`, `hp-status.md` all list Scenario Progression as a dependent; `systems-index.md` row status updated.
- **AC-SP-25** — `scenario_config.json` validates against all 12 tuning knobs with defaults and safe ranges documented in Section G.

## Open Questions

### Architecture / ADR candidates (surface to /architecture-decision)

- **OQ-SP-01 — GameBus autoload.** Scene-boundary signal relay for `battle_complete` is documented as "GameBus autoload" per C.3 locked decision. **Recommendation**: author ADR for GameBus before Scenario Progression implementation begins, to ratify the pattern for all future cross-scene signal flows (not just battle handoff).
- **OQ-SP-02 — Scene ownership during IN_BATTLE.** ScenarioRunner as a persistent node above Grid Battle vs. autoload singleton vs. scene-replacement with handoff token. Architecture-level call.

### Blocked on downstream GDDs

- **OQ-SP-03 — Destiny State flag key allowlist.** Until `destiny-state.md` (#16) defines the flag key schema, SV-17 validator stays at WARNING severity. Must revisit this GDD to tighten to ERROR once flag set is known.
- **OQ-SP-04 — Save/Load contract finalization.** The 9-field provisional checkpoint payload in C.3 must be reconciled with `save-load.md` (#17 VS) once authored. May require revision here if Save/Load commits to a different shape.
- **OQ-SP-05 — Story Event beat-content schema.** How do beats 1, 3, 6, 8 content IDs map to actual presentation assets? Contract surface: `chapter_started(chapter_id, chapter_number)` signal. Content shape lives in Story Event GDD.
- **OQ-SP-06 — Destiny Branch predicate schema.** The exact shape of `destiny_branch.evaluate()` return value is provisional. Revisit when `destiny-branch.md` (#13) lands.

### Blocked on Grid Battle v5.0

- **OQ-SP-07 — Grid Battle v5.0 outcome_data shape.** Scenario commits to `{result, rounds_used, surviving_units, fatalities}` based on `grid-battle.md` v4.0 §5. If v5.0 adds fields (e.g., `abandon_triggered`, `last_round_state`), Scenario must consume them.

### Post-MVP design decisions (deferred, not blocked)

- **OQ-SP-08 — Chapter-select menu.** Out of MVP scope. Requires chapter-gating rules (which chapters are re-playable, which lock after first clear).
- **OQ-SP-09 — Replay / history browser.** Out of MVP scope.
- **OQ-SP-10 — Mid-chapter beat-granular save.** Current design uses per-chapter autosave only. Beat-granular save (Option A from design-lock discussion) is post-MVP pending Story Event coupling cost assessment.
- **OQ-SP-11 — Loss-state branches.** Can losing a specific chapter itself unlock a destiny branch (e.g., losing Chapter 3 opens a tragedy path)? Post-MVP. Scenario's state machine accommodates but no content authored for MVP.
- **OQ-SP-12 — NG+ state.** How does a new-game-plus carry over destiny_state, hero roster, completed_chapters? Post-MVP design.
- **OQ-SP-13 — DRAW as its own exit.** Currently `draw_policy = "treat_as_loss"`. Post-playtesting, may warrant promoting DRAW to its own `next_chapter.draw` key.
- **OQ-SP-14 — Retry attempt cap.** Default 0 (unlimited). Playtest data should inform whether capping retries improves engagement or frustrates players.
- **OQ-SP-15 — Hero `join_chapter` violation severity.** Currently WARNING (EC-SP-4). May tighten to ERROR post-MVP once authoring pipeline is robust.
- **OQ-SP-16 — Multi-scenario save slot management.** Currently one active save per scenario. Multi-save per scenario + multi-scenario is post-MVP.

### Accessibility

- **OQ-SP-17 — Motion-reduce fallbacks.** Beat 1 ink-bleed animation, Beat 2 sequential fades, Beat 8 brushstroke reveal — all need motion-reduce alternatives. Defer full spec to accessibility GDD, but flag that defaults exist here.

### Content design (narrative-director's risk surface)

- **OQ-SP-18 — Beat 8 rarity guardrail.** If destiny branches trigger on every chapter, the 주홍 + guzheng grammar loses weight by chapter 3. Content-design constraint: target 2–3 triggers per full playthrough (of 3–5 chapters). Needs narrative-director sign-off on branch-trigger density per chapter.
