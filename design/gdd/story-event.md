# Story Event System (스토리 이벤트) — Design GDD #10

| Field | Value |
|-------|-------|
| **Tier** | Vertical Slice (post-MVP) |
| **Status** | Designed (rev 1.0 — 2026-05-05) |
| **Layer** | Feature |
| **Owner** | narrative-director (formal); claude direct-author this delta |
| **Governing ADR** | ADR-0017 ScenarioRunner (Beat 1/2/3/8/9 trigger source) + ADR-0018 DestinyBranch (DestinyBranchChoice consumer; D1 invalid-gate contract) + ADR-0001 GameBus (signal transport) |
| **Cross-refs** | game-concept Pillar 4 (삼국지의 숨결 — primary) + Pillar 2 (운명은 바꿀 수 있다 — supporting via Marked Hand register); destiny-branch.md §B Marked Hand + §F-DB-4 + §Bidirectional rev 1.3 N-ND-3/N-ND-4; destiny-state.md §6 Dependencies; scenario-progression.md §F-SP-1..§F-SP-3 + §UX.7 dual-cue_tag; art-bible §1.지지 원칙 2 + §4.6 색채 상태 전환 + §4.7 reserved_color_treatment |
| **Replaces** | systems-index.md row 10 PROVISIONAL → Designed (sprint-7 S7-06 close) |

---

## 1. Overview

Story Event is the **narrative-content-delivery and lookup system**: given a DestinyBranchChoice payload (or a Beat 1/2/3/9 trigger from ScenarioRunner), it resolves the appropriate text/cue identifier from the chapter's authoring data and emits it for downstream consumption (UI text rendering, audio cues, cinematic-layer triggers). It is the **single seam** between the mechanical scenario-progression+destiny-branch substrate and the player-facing narrative content.

This is NOT a writer's tool for authoring narrative copy. Korean text content lives in i18n string tables (`text_key` references in `ChapterDefinition.beat_1_text_key` etc.); chapter-authored branch maps + the 6 branch-state variant resolution rules (F-SE-1) are this GDD's scope. Pillar 4 canonical-vs-rewritten contrast at Beat 8 is the load-bearing fantasy this system delivers.

---

## 2. Player Fantasy

> "내가 한 일이 史記에 어떻게 새겨지는가 — 그 순간을 본다."

**Pillar 4 (primary) — 삼국지의 숨결 (The Spirit of Three Kingdoms)**: at Beat 8 of every chapter, the player witnesses how their choices stand against the canonical 演義 historical record. When the canonical branch fires, the moment confirms continuity with the legend. When a non-canonical branch fires, the moment reveals divergence — accompanied by the reserved color treatment (gold wash per art-bible §4.7) that visually marks the rewritten history. Story Event is the carrier of this contrast; without #10 the divergence has no narrative voice.

**Pillar 2 (supporting) — 운명은 바꿀 수 있다 (Destiny is changeable)**: when the player has accumulated retries and resolved a DRAW via the echo-gated path, Story Event delivers the secondary "Marked Hand" register — Beat 8 text that acknowledges the player rewrote this outcome but bears the weight of accumulated cost. *"운명을 다시 쓰는 자는 흔적 없이 다시 쓰지 못한다."* Per destiny-branch §B + N-ND-4: this register is **sole-carried by Story Event #10**. If #10 ships without echo-differentiation, the Marked Hand register disappears from the game entirely.

Story Event's surface is **text + cue_tag emissions**, not interactive UI. The actual rendering — typography, beat-pacing, audio synchronization — is handled by downstream Beat 8 cinematic-layer (deferred to sprint-8+). What the player feels at Beat 8 is the *content*: which branch fired, in which register, under what visual treatment.

---

## 3. Detailed Rules

### 3.1 Ownership boundaries (CR-SE-1..6)

- **CR-SE-1**: Story Event is the **sole owner** of branch-aware narrative-content variant resolution. ScenarioRunner emits trigger signals (chapter_started + destiny_branch_chosen + scenario_complete) without resolving variants. DestinyBranchJudge produces the DestinyBranchChoice payload; it does NOT determine which Beat 8 text fires. Story Event reads the payload + chapter authoring data + computes the variant key per F-SE-1.
- **CR-SE-2**: Story Event is the **sole consumer** of Beat 8 reveal text resolution at MVP. Beat 1/2/3/9 anchor text resolution is delegated to a future text-rendering layer (out of MVP scope); Story Event subscribes to those triggers but the MVP no-op handlers just echo-emit the raw `text_key` for downstream rendering. Sprint-8+ scope: Story Event takes ownership of all 5 narrative-bearing beats (1/2/3/8/9).
- **CR-SE-3**: Story Event is **read-only against ScenarioRunner + DestinyBranchJudge state**. Per CR-SE-19 (Pillar 2 architectural lock 6th invocation candidate), Story Event MUST NOT call `ScenarioRunner.get_state()`/`get_current_chapter()` outside subscription handlers; payload data flows IN via signal arguments only. Same constraint as Destiny State (CR-DS-19) — pure-function-takes-snapshot pattern 4th invocation candidate.
- **CR-SE-4**: Story Event emits 3 GameBus signals (NEW — to be added to game_bus.gd at sprint-8+ implementation):
  - `story_event_resolved(beat_number: int, variant_key: StringName, text_key: String, cue_tag: StringName)` — fires per beat per variant resolution; primary downstream feed
  - `story_event_invalid_path_detected(reason: StringName, choice_chapter_id: String)` — fires when DestinyBranchChoice arrives with `is_invalid==true`; routes to error-dialog per OQ-DB-13 + scenario-progression §UX.7 invalid-path UI carve-out
  - `story_event_revelation_committed(chapter_id: String, branch_key: String, register: StringName)` — fires AFTER Beat 8 resolution + post-reveal-dwell-window; signals "the player has now seen this branch's revelation" for Save/Load + telemetry
  Signal additions to ADR-0001 require a minor amendment per Evolution Rule #4 at sprint-8+ implementation story-001 close.
- **CR-SE-5**: Story Event MUST NOT subscribe to `hidden_fate_condition_progressed`. Per CR-DB-7 + CR-DS-6 + CR-AI-8 Pillar 2 architectural lock pattern (stable at 4 invocations as of S7-04; Destiny State #16 GDD adds 5th candidate; Story Event #10 GDD adds 6th candidate). Hidden-fate state is read ONLY by DestinyBranchJudge — Story Event reads the resolved DestinyBranchChoice payload.
- **CR-SE-6**: Story Event is an **autoload Node** (9th invocation of autoload pattern after the 8 already shipped + Destiny State #16 candidate at position 7). Boot order: position 8 (after Destiny State; before BattleScene-domain Nodes). Same `class_name`-omission discipline per G-3.

### 3.2 Subscription contract (CR-SE-7..10)

- **CR-SE-7**: Subscriptions (4) — all CONNECT_DEFERRED at autoload `_ready()`:
  1. `GameBus.chapter_started(chapter_id: String, chapter_number: int)` → `_on_chapter_started(...)` → cache active chapter authoring data; emit Beat 1 anchor text via `story_event_resolved(1, &"chapter_anchor", chapter.beat_1_text_key, &"")`
  2. `GameBus.destiny_branch_chosen(choice: DestinyBranchChoice)` → `_on_destiny_branch_chosen(choice)` → resolve Beat 8 variant per F-SE-1; emit `story_event_resolved(8, variant_key, ...)` OR `story_event_invalid_path_detected(...)` per CR-SE-12
  3. `GameBus.scenario_complete(result: ScenarioResult)` → `_on_scenario_complete(result)` → emit Beat 9 chapter-final transition text via `story_event_resolved(9, &"chapter_transition", chapter.beat_9_text_key, &"")` for the LAST chapter of the result; per-chapter Beat 9 fires via `chapter_completed` (handler #4)
  4. `GameBus.chapter_completed(result: ChapterResult)` → `_on_chapter_completed(result)` → emit Beat 9 per-chapter transition text via `story_event_resolved(9, ...)`
- **CR-SE-8**: All 4 handlers MUST early-return on invalid payload per CR-DB-10 invalid-path emission contract:
  - `chapter_started`: skip if `chapter_id == ""` OR `chapter_number <= 0`
  - `destiny_branch_chosen`: per CR-SE-12 (D1 BLOCKING per destiny-branch.md rev 1.2 D1) — read `choice.is_invalid` FIRST before any other field access; if `true`, route via `story_event_invalid_path_detected` per F-SE-3
  - `scenario_complete`: skip if `result == null` OR `result.scenario_path_key == ""`
  - `chapter_completed`: skip if `result == null` OR `result.chapter_id == ""`
- **CR-SE-9**: Beat 2 (Echo) anchor text: per scenario-progression rev 2.2 §F-SP-1 + AC-SP-38 + AC-SP-41, Beat 2 has 4 variant possibilities (silent_visual + cue_tag tinting + draw_after_persistence acknowledgment + standard echo). MVP scope: Story Event resolves Beat 2 via `chapter.beat_2_fragment` Dictionary directly + cue_tag tinting from prior-chapter `flags_to_set` query (Destiny State.get_flags()). Sprint-8+ when Destiny State.get_flags() ships, the cue_tag tinting layer activates. MVP ships the silent_visual variant only for chapter-1 (per current shu_canon_full.json `beat_2_fragment.variant=silent_visual`).
- **CR-SE-10**: Beat 3 (Brief) anchor text: simple `chapter.beat_3_text_key` echo at MVP scope — no branch-aware variants because Beat 3 fires BEFORE the chapter outcome (single-text-per-chapter).

### 3.3 Branch-state variant resolution (CR-SE-11..13) — load-bearing for Pillar 4

- **CR-SE-11**: 6 branch-state variants are mechanically distinct at Beat 8 reveal. Story Event resolves which variant fires per F-SE-1; chapter-authored revelation text per `chapter.beat_8_revelations` Array. Variants:
  1. **canonical_win** — outcome=WIN AND is_canonical_history=true AND is_draw_fallback=false. Confirms 演義. NO reserved_color_treatment (per F-DB-2). Solemn register.
  2. **rewritten_win** — outcome=WIN AND is_canonical_history=false AND is_draw_fallback=false. Pillar 4 PRIMARY DELIVERY MOMENT. reserved_color_treatment=true triggers gold wash per art-bible §4.7. Marked register.
  3. **draw_partial** — outcome=DRAW AND is_draw_fallback=false AND echo_count < chapter.echo_threshold. Default DRAW (author_draw_branch=true chapters only). Solemn register.
  4. **draw_echo_marked** — outcome=DRAW AND is_draw_fallback=false AND echo_count >= chapter.echo_threshold. Pillar 2 SECONDARY DELIVERY MOMENT (Marked Hand register). Sole-carrier per destiny-branch N-ND-4 — if Story Event ships without this variant differentiation, Marked Hand disappears from the game.
  5. **draw_fallback** — outcome=DRAW AND is_draw_fallback=true. Per scenario-progression CR-14 + rev 1.3 narrative N-ND-3 register constraint: text MUST be in solemn-witness register (NOT explanatory/causal framing). The chapter authoring data MUST author this variant when `chapter.author_draw_branch=false`. WIN-default text re-use REJECTED at design review.
  6. **defeat** — outcome=LOSS. Standard tactical-defeat register. No Pillar 4 contrast.
- **CR-SE-12**: D1 invalid-path BLOCKING contract per destiny-branch.md rev 1.2 D1. Story Event's `_on_destiny_branch_chosen(choice)` handler MUST check `choice.is_invalid == false` BEFORE reading ANY of `choice.outcome / chapter_id / branch_key / echo_count / is_draw_fallback / is_canonical_history / reserved_color_treatment`. The `DestinyBranchChoice.invalid()` factory sets `outcome = BattleOutcome.Result.LOSS` as a GDScript enum default — reading `outcome` before `is_invalid` will silently process a corrupt path as a genuine LOSS with no runtime error. Lint pattern `lint_story_event_invalid_gate_first.sh` (sprint-8+ implementation candidate, NOT shipped this design GDD): grep handler body with awk-scoped extraction; if any `choice.outcome|choice.chapter_id|...` access appears before the `if not choice.is_invalid:` guard, FAIL. Test seam (AC-SE-13): inject `DestinyBranchChoice.invalid(reason: StringName)` → assert `story_event_invalid_path_detected(reason, "")` emitted AND no `story_event_resolved` emitted.
- **CR-SE-13**: Variant-key string namespace is closed at MVP scope: `&"canonical_win"`, `&"rewritten_win"`, `&"draw_partial"`, `&"draw_echo_marked"`, `&"draw_fallback"`, `&"defeat"`. Mirrors closed-vocabulary discipline of F-DB-3 + AIActionCommand.ActionType. Adding a 7th variant requires GDD revision + ADR amendment + downstream consumer coordination (UI text-rendering layer). APPEND-ONLY discipline — reordering variants requires migration registry entry.

### 3.4 Beat 8 revelation lookup (CR-SE-14..16)

- **CR-SE-14**: `chapter.beat_8_revelations: Array[Dictionary]` — each entry has 3 fields per existing ChapterDefinition + scenario-progression §B authoring spec:
  - `branch_key: String` — matches DestinyBranchChoice.branch_key (must be in chapter.branch_table.values())
  - `text_key: String` — i18n key (e.g., `"ch01.beat8.win_changbanpo_default"`)
  - `cue_tag: StringName` — per scenario-progression §UX.7 dual-cue_tag spec; non-empty when reserved_color_treatment OR Marked Hand register applies
- **CR-SE-15**: Beat 8 lookup algorithm (F-SE-2):
  1. Filter `chapter.beat_8_revelations` for entry where `entry.branch_key == choice.branch_key`
  2. If filter result is empty: emit `story_event_invalid_path_detected(&"beat_8_revelation_missing", choice.chapter_id)` + `push_error("Story Event: chapter %s missing beat_8 revelation for branch_key %s" % [...])` — chapter authoring drift; halt beat sequence per CR-DB-10 invalid-path
  3. If filter result has multiple entries: pick FIRST entry (deterministic — scenario-progression §B authoring schema validator should reject duplicates at scenario-build time; Story Event is defensive against authoring drift)
  4. Resolve variant_key per F-SE-1
  5. Emit `story_event_resolved(8, variant_key, entry.text_key, entry.cue_tag)`
- **CR-SE-16**: Beat 8 reveal-dwell window (cinematic timing — minimum 2.0s wall-clock dwell before Beat 9 advance per scenario-progression CR-10 + UX.7 dramatic doctrine). Story Event does NOT enforce the dwell window — that is ScenarioRunner's BEAT_6_RESULT or BEAT_8_REVEAL state-handler responsibility. Story Event emits the variant resolution synchronously at handler-fire time; the 2.0s gate lives upstream. Story Event emits `story_event_revelation_committed` AFTER ScenarioRunner's `advance_beat()` call returns from BEAT_8 → BEAT_9 — signals "the player has now seen this branch's revelation." Test seam (AC-SE-17): inject paired (destiny_branch_chosen, manual ScenarioRunner.advance_beat()) → assert `story_event_revelation_committed(...)` emits AFTER the second event, not the first.

### 3.5 Destiny State integration (CR-SE-17..18)

- **CR-SE-17**: Story Event reads from Destiny State via `DestinyState.get_flags() -> PackedStringArray` for branch-aware Beat 1/2/3/8/9 text variants (e.g., chapter 2's Beat 1 anchor MAY differ if `"divergence_recorded__ch01__rewritten_win"` is in flags_to_set). MVP scope: Story Event subscribes to `chapter_started` + queries `DestinyState.get_flags()` synchronously in handler. No flag-aware text variants are SHIPPED at MVP — chapter-1 stub data has empty branch-aware text map. Sprint-8+ scope: Story Event reads `chapter.beat_N_branch_aware_variants: Dictionary[String, String]` (NEW chapter authoring field, not yet added to ChapterDefinition) keyed on `flag_sentinel → text_key`.
- **CR-SE-18**: Story Event MUST NOT subscribe to `destiny_state_flag_set` events for narrative-rendering purposes. Flag-state queries are PULL (synchronous DestinyState API call) at handler-fire time, not PUSH (event subscription). Reason: PUSH would force Story Event to maintain its own per-chapter flag-state cache, doubling the persistence surface. PULL keeps Destiny State as the single source of truth.

### 3.6 Pillar 2 architectural lock (CR-SE-19)

- **CR-SE-19**: Story Event MUST NOT introspect ScenarioRunner internal state. Per F-SE-1..F-SE-3, all chapter context flows through signal arguments (`chapter_started(chapter_id, chapter_number)`) + chapter authoring data lookup via `ScenarioRunner.get_current_chapter()` ONLY in scope-bounded subscription handlers (read-only Resource access). Lint pattern `lint_story_event_no_scenario_runner_state_read` (sprint-8+ implementation candidate, NOT shipped this design GDD): `grep -E 'ScenarioRunner\\.(_state|_echo_counts|_current_chapter_index|advance_beat|confirm_deployment|accept_outcome)'` MUST return 0 matches in `src/feature/story_event/`. This extends the Pillar 2 architectural lock pattern stable at 4 invocations (battle_hud + scenario_runner + destiny_branch_judge + ai_system) — Story Event is the **6th invocation candidate** (after Destiny State #16 candidate 5th).

---

## 4. Formulas

### F-SE-1 — Branch-state variant resolution

```text
resolve_variant_key(choice: DestinyBranchChoice) -> StringName:
  # CR-SE-12 D1 invalid-gate FIRST — load-bearing
  if choice.is_invalid:
    return &""  # caller's responsibility: emit story_event_invalid_path_detected, NOT story_event_resolved

  match choice.outcome:
    BattleOutcome.Result.WIN:
      if choice.is_canonical_history:
        return &"canonical_win"
      else:
        return &"rewritten_win"
    BattleOutcome.Result.DRAW:
      if choice.is_draw_fallback:
        return &"draw_fallback"
      else:
        # author_draw_branch=true chapter; differentiate by echo state
        var chapter := ScenarioRunner.get_current_chapter()
        if chapter == null:
          return &"draw_partial"  # defensive — should never fire if invariants hold
        if choice.echo_count >= chapter.echo_threshold:
          return &"draw_echo_marked"  # Marked Hand register (Pillar 2 sole-carrier)
        else:
          return &"draw_partial"
    BattleOutcome.Result.LOSS:
      return &"defeat"
    _:
      push_error("Story Event: unknown outcome enum value %d" % choice.outcome)
      return &""
```

### F-SE-2 — Beat 8 revelation lookup

```text
resolve_beat_8_text_and_cue(choice: DestinyBranchChoice) -> Dictionary:
  # Returns {variant_key: StringName, text_key: String, cue_tag: StringName} or empty {} on invalid

  if choice.is_invalid:
    return {}  # caller routes to story_event_invalid_path_detected per F-SE-3

  var variant_key := resolve_variant_key(choice)
  if variant_key == &"":
    return {}  # F-SE-1 returned empty — invalid path

  var chapter := ScenarioRunner.get_current_chapter()
  if chapter == null:
    push_error("Story Event: no active chapter at beat_8 lookup")
    return {}

  for entry: Dictionary in chapter.beat_8_revelations:
    if (entry.get("branch_key", "") as String) == choice.branch_key:
      return {
        "variant_key": variant_key,
        "text_key": (entry.get("text_key", "") as String),
        "cue_tag": StringName(entry.get("cue_tag", "") as String),
      }

  # No matching revelation row for branch_key — chapter authoring drift
  push_error("Story Event: chapter %s missing beat_8 revelation for branch_key %s" % [
    chapter.chapter_id, choice.branch_key,
  ])
  return {}
```

### F-SE-3 — Invalid-path UI carve-out

```text
on_destiny_branch_chosen(choice: DestinyBranchChoice):
  # CR-SE-12 D1 invalid-gate enforcement — is_invalid checked BEFORE any other field access
  if choice.is_invalid:
    GameBus.story_event_invalid_path_detected.emit(choice.invalid_reason, choice.chapter_id)
    return  # halt beat sequence per CR-DB-10 + scenario-progression §UX.7

  # Valid path — resolve Beat 8 variant
  var resolved := resolve_beat_8_text_and_cue(choice)
  if resolved.is_empty():
    # F-SE-2 already pushed error; route to invalid-path UI as defensive fallback
    GameBus.story_event_invalid_path_detected.emit(&"beat_8_revelation_missing", choice.chapter_id)
    return

  GameBus.story_event_resolved.emit(
    8,
    resolved["variant_key"] as StringName,
    resolved["text_key"] as String,
    resolved["cue_tag"] as StringName,
  )
```

### F-SE-4 — Beat 1/9 anchor text emission

```text
on_chapter_started(chapter_id: String, chapter_number: int):
  if chapter_id == "" or chapter_number <= 0:
    return  # CR-SE-8 invalid-payload guard

  var chapter := ScenarioRunner.get_current_chapter()
  if chapter == null or chapter.chapter_id != chapter_id:
    push_warning("Story Event: chapter_started fires but get_current_chapter mismatch")
    return

  # Beat 1 — chapter anchor (no branch-awareness at MVP scope)
  GameBus.story_event_resolved.emit(
    1,
    &"chapter_anchor",
    chapter.beat_1_text_key,
    &"",
  )


on_chapter_completed(result: ChapterResult):
  if result == null or result.chapter_id == "":
    return

  var chapter := ScenarioRunner.get_current_chapter()
  if chapter == null:
    return

  # Beat 9 — per-chapter transition (no branch-awareness at MVP scope)
  GameBus.story_event_resolved.emit(
    9,
    &"chapter_transition",
    chapter.beat_9_text_key,
    &"",
  )
```

### F-SE-5 — Revelation commit telemetry

```text
on_scenario_runner_state_changed(prev_state: int, new_state: int):
  # NOTE: This is a HYPOTHETICAL handler — ScenarioRunner does NOT emit a generic
  # state-changed signal at MVP. The "revelation committed" semantic is instead
  # realized via Story Event's internal book-keeping at on_destiny_branch_chosen
  # success-path: cache the (chapter_id, branch_key, variant_key) triple; emit
  # story_event_revelation_committed at next chapter_completed handler entry.
  # Sprint-8+ refinement: ScenarioRunner can emit a beat_advanced(beat_number)
  # signal for tighter dwell-window observability.

  pass  # MVP no-op stub
```

---

## 5. Edge Cases

- **EC-SE-1** — `chapter_started` fires before Story Event autoload `_ready()` completes (race during cold-load). Mitigation: subscriptions are CONNECT_DEFERRED per CR-SE-7; signals queue until next frame after `_ready()` returns. Loss-of-event impossible under normal autoload boot order (position 8 — after ScenarioRunner position 6 + Destiny State position 7).

- **EC-SE-2** — DestinyBranchChoice arrives with `is_invalid == true` (e.g., F-DB-3 invariant violation). Per CR-SE-12 D1 BLOCKING contract, handler routes to `story_event_invalid_path_detected(reason, chapter_id)` WITHOUT reading any other field. Test seam: parameterized stub injects each of the 12 F-DB-3 invalid_reason vocabulary entries → assert correct reason propagation.

- **EC-SE-3** — `chapter.beat_8_revelations` empty (chapter authoring incomplete). F-SE-2 returns empty; F-SE-3 routes to `story_event_invalid_path_detected(&"beat_8_revelation_missing", chapter_id)` + push_error. Halt beat sequence per CR-DB-10.

- **EC-SE-4** — `chapter.beat_8_revelations` has multiple rows with same `branch_key` (authoring drift). F-SE-2 picks FIRST entry deterministically. scenario-progression authoring-schema validator (sprint-8+) catches at scenario-build time; Story Event is defensive against runtime drift.

- **EC-SE-5** — DestinyBranchChoice.branch_key not in `chapter.beat_8_revelations[*].branch_key` set. F-SE-2 returns empty after exhausting scan; F-SE-3 routes to invalid-path UI.

- **EC-SE-6** — Beat 8 revelation lookup races against chapter advance (`chapter_completed` fires concurrently). Mitigation: ScenarioRunner state machine enforces synchronous BEAT_7_JUDGMENT → BEAT_8_REVEAL transition (Pillar 2 lock 2nd precedent per ADR-0017 F-SP-3). `destiny_branch_chosen` emits AT BEAT_7 entry; `chapter_completed` emits at BEAT_9 entry. The minimum 2.0s dwell window (CR-SE-16) provides natural separation. EC-SE-6 cannot fire under correct ScenarioRunner state machine implementation.

- **EC-SE-7** — `scenario_complete` fires for the LAST chapter (multi-chapter scenario). Both `chapter_completed` (per-chapter) AND `scenario_complete` (scenario-final) handlers fire. Story Event emits Beat 9 text via `chapter_completed` only (CR-SE-9 + F-SE-4); `scenario_complete` handler is a no-op telemetry breadcrumb at MVP scope (sprint-8+ adds scenario-credits-roll trigger).

- **EC-SE-8** — DestinyBranchChoice with `outcome == LOSS` AND `is_canonical_history == true`. F-SE-1 routes to `&"defeat"` (outcome dominates). LOSS canonicality is informational metadata not exposed at narrative variant level — per Pillar 4, defeat variants don't differentiate canonical-vs-rewritten (the LOSS itself IS the divergence; reflecting it twice in variant + text would be over-marking).

- **EC-SE-9** — DRAW path with `is_draw_fallback=false` AND `echo_count == chapter.echo_threshold` (boundary). F-SE-1 uses `>=` so this routes to `&"draw_echo_marked"` (Marked Hand). Boundary-test (AC-SE-9) verifies inclusivity.

- **EC-SE-10** — Destiny State's `get_flags()` query returns empty PackedStringArray (no prior-chapter flags set). Beat 1/2 anchor variant resolution per CR-SE-17 falls back to default text_key. Not an error condition — chapter 1 always has empty flags state at scenario start.

- **EC-SE-11** — DestinyState autoload not yet booted when Story Event tries to query `get_flags()` (race during cold-load). Mitigation: boot order discipline — Destiny State at position 7, Story Event at position 8. If autoload ordering is corrupted (project.godot misconfiguration), Story Event falls back to empty flags PackedStringArray + push_warning. Not a runtime crash.

- **EC-SE-12** — DestinyBranchChoice arrives with `outcome` value outside `{0, 1, 2}` enum range (corrupt payload bypass-seam scenario). F-SE-1's `_` match arm catches + push_errors + returns empty variant_key. F-SE-3 routes to invalid-path UI as defensive fallback. Test seam (AC-SE-12): inject `outcome = -1` via bypass-seam (per damage-calc story-006 G-18 pattern) → assert error path.

---

## 6. Dependencies

| System | Direction | Coupling | Notes |
|--------|-----------|----------|-------|
| **Scenario Progression** (#6, MVP) | In | Soft (event subscriber) | Subscribes to `chapter_started` + `scenario_complete` + `chapter_completed`. Reads `ScenarioRunner.get_current_chapter()` at handler-fire time only (read-only Resource access). Per CR-SE-19 Pillar 2 lock, MUST NOT read internal state. |
| **Destiny Branch** (#4, MVP) | In | Hard (D1 BLOCKING invalid-gate contract per CR-SE-12) | Subscribes to `destiny_branch_chosen`. MUST check `is_invalid` FIRST before any other field access (D1 BLOCKING per destiny-branch.md rev 1.2 D1). 6 branch-state variants per F-SE-1 mechanically distinct at Beat 8 reveal. |
| **Destiny State** (#16, VS — Designed rev 1.0 sprint-7 S7-07) | In | Soft (read-only PULL query) | Per CR-SE-17, Story Event PULLs flags via `DestinyState.get_flags()` at handler-fire time. NO subscription to `destiny_state_flag_set` (per CR-SE-18 — single source of truth discipline). Sprint-8+ chapter authoring: branch-aware Beat 1/2/8 text variants keyed on flag sentinels. |
| **GameBus** (#1, MVP) | In/Out | Hard (signal transport) | 4 subscriptions in (CR-SE-7) + 3 emissions out (CR-SE-4: story_event_resolved + story_event_invalid_path_detected + story_event_revelation_committed). 3 NEW signals require ADR-0001 minor amendment per Evolution Rule #4 at sprint-8+ implementation. |
| **Beat 8 Cinematic-Layer** (future system, NOT yet authored) | Out | Soft (downstream consumer) | Consumes `story_event_resolved(8, variant_key, text_key, cue_tag)` for typography + audio + camera composition. Spec deferred to art-bible §4.7 follow-up OR future cinematic-system GDD. MVP scope: emission-only; rendering deferred. |
| **i18n string tables** (`assets/data/locales/`) | Out | Hard (text_key resolver) | text_key strings emitted by Story Event are resolved by a downstream text-rendering layer. MVP scope: text_keys are emitted as-is; localization infrastructure deferred per main project scope. |
| **Hidden-Fate System** | — | **FORBIDDEN** | Per CR-SE-5 + CR-SE-19 Pillar 2 architectural lock 6th invocation candidate. Story Event MUST NOT subscribe to `hidden_fate_condition_progressed`. |
| **Scenario authoring data** (chapter `.tres`/`.json` files) | In | Hard (chapter.beat_*_text_key + chapter.beat_8_revelations + chapter.beat_2_fragment) | Scenario-progression v2.1 chapter authoring schema validator (sprint-8+) MUST verify `beat_8_revelations` covers all `branch_table.values()` entries — Story Event is defensive against drift but authoring-time validation is the canonical gate. |

---

## 7. Tuning Knobs

| Constant | Default | Where | Rationale |
|----------|---------|-------|-----------|
| `BEAT_8_REVELATION_DWELL_MS` | `2000` | scenario-progression §UX.7 dramatic doctrine (NOT Story Event-owned) | Minimum wall-clock dwell between BEAT_8_REVEAL entry and BEAT_9_TRANSITION advance. Enforced by ScenarioRunner state-handler, NOT Story Event. Documented here for cross-ref clarity. |
| `STORY_EVENT_VARIANT_KEY_NAMESPACE` | `[&"canonical_win", &"rewritten_win", &"draw_partial", &"draw_echo_marked", &"draw_fallback", &"defeat"]` | (Hardcoded in F-SE-1 enum-like constants on Story Event class) | Per CR-SE-13, closed at MVP. APPEND-ONLY discipline. Adding 7th variant requires GDD revision + ADR amendment + downstream consumer coordination. |
| `BEAT_8_REVELATION_FALLBACK_TEXT_KEY` | `"common.beat8.invalid_path"` | (Hardcoded as defensive fallback text_key in F-SE-3) | When `story_event_invalid_path_detected` fires, downstream UI uses this i18n key for the player-facing error dialog. Per OQ-DB-13 BLOCKING VS dependency on scenario-progression error-dialog spec — Story Event emits the reason; scenario-progression renders. |

---

## 8. Acceptance Criteria

### 8.1 Branch-state variant resolution (AC-SE-1..6)

- **AC-SE-1**: Given DestinyBranchChoice with `outcome=WIN AND is_canonical_history=true AND is_draw_fallback=false`, when F-SE-1 invoked, then variant_key == `&"canonical_win"`.
- **AC-SE-2**: Given DestinyBranchChoice with `outcome=WIN AND is_canonical_history=false AND is_draw_fallback=false`, when F-SE-1 invoked, then variant_key == `&"rewritten_win"` (Pillar 4 PRIMARY DELIVERY MOMENT).
- **AC-SE-3**: Given DestinyBranchChoice with `outcome=DRAW AND is_draw_fallback=false AND echo_count=2 AND chapter.echo_threshold=3`, when F-SE-1 invoked, then variant_key == `&"draw_partial"`.
- **AC-SE-4**: Given DestinyBranchChoice with `outcome=DRAW AND is_draw_fallback=false AND echo_count=3 AND chapter.echo_threshold=3` (boundary), when F-SE-1 invoked, then variant_key == `&"draw_echo_marked"` (Pillar 2 SECONDARY DELIVERY MOMENT — Marked Hand). Inclusive `>=` boundary verified.
- **AC-SE-5**: Given DestinyBranchChoice with `outcome=DRAW AND is_draw_fallback=true`, when F-SE-1 invoked, then variant_key == `&"draw_fallback"` regardless of echo_count value (is_draw_fallback dominates per F-SE-1 nested match).
- **AC-SE-6**: Given DestinyBranchChoice with `outcome=LOSS` (canonical or non-canonical), when F-SE-1 invoked, then variant_key == `&"defeat"` (per EC-SE-8 — LOSS dominates).

### 8.2 Invalid-gate contract (AC-SE-7..13) — D1 BLOCKING

- **AC-SE-7**: Given DestinyBranchChoice with `is_invalid=true AND invalid_reason=&"chapter_null"`, when F-SE-1 invoked, then variant_key == `&""` AND no `outcome` field access occurred (verified via test seam — wrapper class throws on field access tracks).
- **AC-SE-8**: Given DestinyBranchChoice with `is_invalid=true`, when F-SE-3 invoked (full handler), then `story_event_invalid_path_detected(invalid_reason, chapter_id)` emits exactly once AND `story_event_resolved` does NOT emit.
- **AC-SE-9**: Given the 12 F-DB-3 invariant_violation:* StringName const vocabulary entries, when each one is injected via `DestinyBranchChoice.invalid(reason)`, then `story_event_invalid_path_detected.invalid_reason` matches each injected reason exactly (12 parameterized cases).
- **AC-SE-10**: Source-grep lint `lint_story_event_invalid_gate_first.sh` MUST verify in `src/feature/story_event/story_event.gd`: any `choice.outcome|chapter_id|branch_key|echo_count|is_draw_fallback|is_canonical_history|reserved_color_treatment` access is preceded by an `if choice.is_invalid:` guard (awk-scoped per scenario_runner_no_deferred_in_beat_7_seal.sh precedent). Sprint-8+ implementation; AC verified at lint level.
- **AC-SE-11**: Given DestinyBranchChoice with `is_invalid=true AND outcome=BattleOutcome.Result.LOSS` (factory default), when F-SE-3 invoked, then NO `story_event_resolved(8, &"defeat", ...)` emits — invalid-gate prevents the corrupt-LOSS misclassification per D1 contract.
- **AC-SE-12**: Given DestinyBranchChoice with bypass-seam-injected `outcome = -1` (out of enum range; per damage-calc story-006 G-18 bypass pattern), when F-SE-1 invoked, then variant_key == `&""` AND push_error emitted with "unknown outcome enum value -1" message.
- **AC-SE-13**: Given chapter.beat_8_revelations missing entry for choice.branch_key, when F-SE-3 invoked with valid choice, then `story_event_invalid_path_detected(&"beat_8_revelation_missing", chapter_id)` emits + push_error.

### 8.3 Beat 8 revelation lookup (AC-SE-14..17)

- **AC-SE-14**: Given chapter-1 shu_canon_full.json with 2 beat_8_revelations entries (canonical_win + canonical_loss), when DestinyBranchChoice with `branch_key="WIN_changbanpo_default"` invoked, then F-SE-2 returns Dictionary with `text_key="ch01.beat8.win_changbanpo_default" AND cue_tag=&"tag.beat8.canonical_win"`.
- **AC-SE-15**: Given duplicate beat_8_revelations entries with same branch_key (authoring drift), when F-SE-2 invoked, then FIRST entry returned deterministically (order-stable per Array iteration).
- **AC-SE-16**: Given full handler chain (chapter_started → destiny_branch_chosen → chapter_completed) for chapter-1 WIN canonical, when complete, then signal emission sequence is exactly: [story_event_resolved(1, &"chapter_anchor", "ch01.beat1.anchor", &""), story_event_resolved(8, &"canonical_win", "ch01.beat8.win_changbanpo_default", &"tag.beat8.canonical_win"), story_event_resolved(9, &"chapter_transition", "ch01.beat9.transition_to_xiakou", &"")]. 3 emissions in deterministic order.
- **AC-SE-17**: Given `story_event_revelation_committed(chapter_id, branch_key, register)` emission timing, when chapter_completed handler fires AFTER destiny_branch_chosen + ScenarioRunner advance through BEAT_8 → BEAT_9, then revelation_committed emits exactly once with the (chapter_id, branch_key, register=variant_key) triple from the cached (CR-SE-16) Beat 8 resolution.

### 8.4 Pillar 2 architectural lock (AC-SE-18..20)

- **AC-SE-18**: Source-grep lint `lint_story_event_no_scenario_runner_state_read.sh` MUST return 0 matches for `grep -E 'ScenarioRunner\\.(_state|_echo_counts|_current_chapter_index|advance_beat|confirm_deployment|accept_outcome)'` in `src/feature/story_event/`. Sprint-8+ implementation.
- **AC-SE-19**: Source-grep lint `lint_story_event_no_hidden_fate_subscription.sh` MUST return 0 matches for `grep -E 'hidden_fate_condition_progressed'` in `src/feature/story_event/`. Per CR-SE-5.
- **AC-SE-20**: Integration test (G-22 structural assertion pattern): `FileAccess.get_file_as_string("res://src/feature/story_event/story_event.gd").contains("hidden_fate")` MUST be `false` AND `.contains("DestinyBranchJudge.")` MUST be `false`. Per CR-SE-5 + CR-SE-19 + Pillar 2 lock 6th invocation candidate precedent.

### 8.5 Determinism + cross-API contract (AC-SE-21..23)

- **AC-SE-21**: Given two Story Event instances seeded with identical chapter authoring data + flag-state, when both invoked with identical event sequence (1 chapter_started + 1 destiny_branch_chosen + 1 chapter_completed), then both produce field-identical signal emission sequences. No `Time.*` / `rand*` / wall-clock dependencies.
- **AC-SE-22**: Given DestinyBranchChoice + chapter authoring data, when F-SE-1 + F-SE-2 invoked 100 times in succession, then all 100 invocations return field-identical results. Lint pattern `lint_story_event_no_static_var.sh` (sprint-8+) enforces source-level: any `static var` declaration in `src/feature/story_event/` FAILS per determinism contract.
- **AC-SE-23**: Cross-system contract — Beat 8 cinematic-layer (when authored) consumes `story_event_resolved(8, ...)` per documented signal payload shape. AC-SE-23 is a placeholder for cross-spec verification at the cinematic-layer GDD acceptance pass (sprint-8+).

---

## Open Questions (OQ-SE-1..4)

- **OQ-SE-1**: Should `story_event_revelation_committed` include the FULL DestinyBranchChoice payload (vs just chapter_id + branch_key + register)? Telemetry use cases might want the full audit trail; Save/Load might want it for cross-chapter callback. Decision deferred to sprint-8+ implementation when Save/Load #17 + telemetry epic land.

- **OQ-SE-2**: Should the `cue_tag` field surface MULTIPLE tags per Beat 8 entry (e.g., `cue_tag: PackedStringArray`)? scenario-progression rev 2.2 §UX.7 dual-cue_tag spec hints at this; current ChapterDefinition stores `cue_tag: String` (single). Coupled to scenario-progression v2.1 chapter authoring schema decision.

- **OQ-SE-3**: Should Beat 1/2/3 anchor text variants be branch-aware in MVP scope (CR-SE-17) OR deferred to sprint-8+? Decision: deferred to sprint-8+ per current chapter-1 stub data has empty branch-aware map. Activation requires NEW ChapterDefinition field `beat_N_branch_aware_variants: Dictionary[String, String]`.

- **OQ-SE-4**: Pillar 2 architectural lock 6th invocation — is the `DestinyState.get_flags()` PULL pattern (CR-SE-17) compatible with the lock pattern, or does it count as "introspecting another autoload's internal state"? Reading: PULL via documented public API on Destiny State is fine (Destiny State EXPOSES get_flags as a contracted read API per CR-DS-4); the lock forbids INTERNAL state reads (`._state`, `._echo_counts`). PULL pattern preserved.

---

## Implementation hooks (sprint-7 S7-06 GDD delta — NOT IMPLEMENTED HERE)

The following are **NOT** shipped this design-only GDD delta; documented for the implementation story (sprint-8+ candidate per VS tier scope):

1. `src/feature/story_event/story_event.gd` (~250 LoC autoload Node 9th invocation)
2. `tools/ci/lint_story_event_invalid_gate_first.sh` (CR-SE-12 D1 BLOCKING enforcement — awk-scoped handler body extraction)
3. `tools/ci/lint_story_event_no_scenario_runner_state_read.sh` (Pillar 2 lock 6th candidate)
4. `tools/ci/lint_story_event_no_hidden_fate_subscription.sh` (CR-SE-5 enforcement)
5. `tools/ci/lint_story_event_no_static_var.sh` (AC-SE-22 determinism contract)
6. `tests/unit/feature/story_event/branch_state_variant_resolution_test.gd` (AC-SE-1..6 + 8.4 Pillar 2 lock)
7. `tests/unit/feature/story_event/invalid_gate_contract_test.gd` (AC-SE-7..13 D1 BLOCKING — 12 vocabulary parameterized + bypass-seam)
8. `tests/unit/feature/story_event/beat_8_revelation_lookup_test.gd` (AC-SE-14..17)
9. `tests/unit/feature/story_event/architectural_lock_test.gd` (AC-SE-18..20 source-grep + G-22 structural)
10. `tests/unit/feature/story_event/determinism_test.gd` (AC-SE-21..22)
11. ADR-0001 minor amendment per Evolution Rule #4: 3 NEW GameBus signals (story_event_resolved + story_event_invalid_path_detected + story_event_revelation_committed)
12. `project.godot` autoload registration: `StoryEvent="*res://src/feature/story_event/story_event.gd"` at boot order position 8 (after DestinyState position 7)
13. ADR amendment OR new ADR: ratify story_event autoload Node 9th invocation + Pillar 2 lock 6th invocation (companion to Destiny State #16's 5th candidate)
14. systems-index.md row 10 status: PROVISIONAL → Designed (this delta closes it; sprint-8+ implementation flips to Implemented)
15. Chapter authoring schema extension (sprint-8+): NEW field `beat_N_branch_aware_variants: Dictionary[String, String]` on ChapterDefinition for OQ-SE-3 activation
16. scenario-progression v2.1 authoring-schema validator: verify `beat_8_revelations` covers all `branch_table.values()` entries; reject duplicate branch_key entries (catches EC-SE-3 + EC-SE-4 at scenario-build time)

---

## Cross-references

- **Governing**: ADR-0017 ScenarioRunner §F-SP-1 (DestinyBranchChoice emitter via DestinyBranchJudge.resolve at BEAT_7_JUDGMENT) + ADR-0018 DestinyBranch §F-DB-1 + §F-DB-4 + §CR-DB-10 invalid-path emission contract + ADR-0001 GameBus §Evolution Rule #4 (3 NEW signal slots minor amendment)
- **Pillar substrate**: game-concept.md §Pillar 4 (삼국지의 숨결 — primary delivery moment via rewritten_win variant) + §Pillar 2 (운명은 바꿀 수 있다 — sole-carrier via draw_echo_marked variant per destiny-branch.md N-ND-4)
- **D1 BLOCKING contract**: destiny-branch.md §Bidirectional rev 1.2 D1 — every consumer MUST gate field access on `is_invalid==false`; Story Event is the 1st CONSUMER to formalize this at GDD level (Destiny State #16 GDD CR-DS-8 + CR-DS-15 codified the same per-handler invariant)
- **Marked Hand register sole-carrier**: destiny-branch.md §B + §Bidirectional rev 1.3 N-ND-4 — Story Event MUST differentiate Beat 8 tone for `draw_echo_marked` variant; without it, Marked Hand secondary fantasy disappears from the shipped game
- **Register constraint**: destiny-branch.md §Bidirectional rev 1.3 N-ND-3 — `draw_fallback` variant text MUST be in solemn-witness register; WIN-default reuse REJECTED at design review; "because no clear victor emerged" anti-pattern explicitly forbidden
- **Visual contract integration**: art-bible.md §1.지지 원칙 2 (visual narrative pillar) + §4.6 색채 상태 전환 (Beat 7→8 transition rows) + §4.7 reserved_color_treatment addendum (gold wash trigger when variant_key=="rewritten_win")
- **Architectural lock pattern**: control-manifest.md §Pillar 2 Architectural Locks (Story Event 6th invocation candidate); destiny-state.md §3.6 (5th candidate sibling); ai-system.md §CR-AI-8 (4th precedent template); destiny-branch.md §CR-DB-7 (3rd precedent template)
- **Pure-function-takes-snapshot pattern**: ai-system.md §CR-AI-6 (1st invocation) + destiny-branch.md (2nd invocation per S7-03 commit) + destiny-state.md §CR-DS-19 (3rd invocation candidate) + this GDD §CR-SE-19 (4th invocation candidate)
- **Engine constraints**: tooling-gotchas.md G-3 (autoload no class_name); G-7 (silent-skip detection); G-22 (structural source-file assertion for AC-SE-20); G-18 (subclass var-shadowing — bypass-seam pattern for AC-SE-12)
- **Sprint-7 plan reference**: production/sprints/sprint-7.md S7-06 acceptance criteria + sprint-7 plan R-6 (Story Event #10 vs Destiny State #16 scheduling rationale — this delta confirms #10 is structurally similar to #16; "narrative-heavy" descriptor was overstated for the GDD-authoring task scope; actual narrative-content authoring remains separate)
