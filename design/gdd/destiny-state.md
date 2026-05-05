# Destiny State Tracking System (운명 상태 추적) — Design GDD #16

| Field | Value |
|-------|-------|
| **Tier** | Vertical Slice (post-MVP) |
| **Status** | Designed (rev 1.0 — 2026-05-05) |
| **Layer** | Feature |
| **Owner** | systems-designer |
| **Governing ADR** | ADR-0003 SaveContext + ADR-0017 ScenarioRunner (downstream consumer) + ADR-0018 DestinyBranch (subscription source) |
| **Cross-refs** | game-concept Pillar 2 (운명은 바꿀 수 있다) + Pillar 4 (지난 장의 선택이 살아 있다); destiny-branch.md §Bidirectional rev 1.2 D1; scenario-progression.md F-SP-3 echo lifecycle + AC-SP-19 + AC-SP-20 |
| **Replaces** | systems-index.md row 16 PROVISIONAL → Designed (sprint-7 S7-07 close) |

---

## 1. Overview

Destiny State is the **per-save persistent archive** of player retry-and-choice history across the scenario. It owns three persisted structures: `Array[EchoMark]` (retry-loop accumulation), `branch_key` history per chapter (canonical vs alternative path tracking), and `flags_to_set` (cross-chapter narrative-state propagation). It subscribes to ScenarioRunner + DestinyBranchJudge via GameBus, writes to SaveContext at the 3 checkpoints (CP-1/CP-2/CP-3 per ADR-0003), and surfaces read-only queries to support Pillar 2 retry mechanics + Pillar 4 cross-chapter branch awareness.

This is the **substrate layer** that makes "the player can rewrite history" mechanically observable. Destiny State holds no narrative intelligence — it is a typed-archive with persistence discipline.

---

## 2. Player Fantasy

> "내 시도 하나하나가 사라지지 않는다. 다음 장에서 지난 선택이 메아리처럼 돌아온다."

Two pillars converge here:

- **Pillar 2 — 운명은 바꿀 수 있다 (Destiny is changeable)**: when a player retries Beat 5 (battle), each retry leaves a permanent EchoMark in the archive. The accumulated echo_count gates DRAW-echo branch routing in DestinyBranchJudge (per F-SP-2). The fantasy: the player feels their persistence — even past failures contribute to a transformed outcome. Echo marks are NOT punishment counters; they ARE the fuel that bends fate.

- **Pillar 4 — 지난 장의 선택이 살아 있다 (Past choices remain alive)**: when a player chooses a non-canonical branch in Chapter N, the Destiny State persists `(chapter_id, branch_key, is_canonical_history)` so that Chapter N+1's narrative beats can recognize the divergence. The fantasy: the world remembers what you did, not just what was supposed to happen.

Destiny State has **no UI surface of its own** at MVP. Its presence is felt through downstream consumers: DestinyBranchJudge reading `echo_count` for F-SP-2; future Story Event #10 reading `flags_to_set` for branch-aware dialogue; future Save Slot UI reading `echo_marks_archive.size()` for run-progression display.

---

## 3. Detailed Rules

### 3.1 Ownership boundaries (CR-DS-1..6)

- **CR-DS-1**: Destiny State is the **sole owner** of `echo_marks_archive: Array[EchoMark]` lifecycle. ScenarioRunner emits `scenario_beat_retried(EchoMark)`; Destiny State appends. No other system mutates the archive.
- **CR-DS-2**: Destiny State is the **sole owner** of `flags_to_set: PackedStringArray` lifecycle. DestinyBranchJudge does NOT write to flags directly. Destiny State subscribes to `destiny_branch_chosen(DestinyBranchChoice)` and resolves per-branch flag effects from chapter authoring data (CR-DS-7).
- **CR-DS-3**: Destiny State writes to `SaveContext` ONLY at the 3 checkpoints (CP-1 BEAT_1 entry / CP-2 BEAT_7 entry post-seal / CP-3 BEAT_9 entry). It is a **subscriber** to `save_checkpoint_requested(SaveContext)` — populates the SaveContext fields it owns, then releases. SaveManager handles disk I/O.
- **CR-DS-4**: Destiny State is **read-only from the perspective of all consumers**. Public read API is exclusively `get_*` methods returning `.duplicate(true)` snapshots. No mutator API is public.
- **CR-DS-5**: Destiny State emits 2 GameBus signals already declared in `game_bus.gd` (lines 54-55):
  - `destiny_state_flag_set(flag_key: String, value: bool)` — fires post-flag-mutation per CR-DS-2.
  - `destiny_state_echo_added(mark: EchoMark)` — fires post-archive-append per CR-DS-1.
  No other emissions.
- **CR-DS-6**: Destiny State MUST NOT subscribe to `hidden_fate_condition_progressed` (Pillar 2 architectural lock 5th candidate — extends the precedent set by Battle HUD + ScenarioRunner + DestinyBranchJudge + AISystem). Hidden-fate state is read ONLY by DestinyBranchJudge per ADR-0018 §CR-DB-7. Destiny State works downstream of the resolved DestinyBranchChoice — it never inspects the hidden-fate-counter substrate.

### 3.2 Subscription contract (CR-DS-7..9)

- **CR-DS-7**: Subscriptions (3) — all CONNECT_DEFERRED at autoload `_ready()`:
  1. `GameBus.scenario_beat_retried(mark: EchoMark)` → `_on_scenario_beat_retried(mark)` → append to archive (F-DS-1)
  2. `GameBus.destiny_branch_chosen(choice: DestinyBranchChoice)` → `_on_destiny_branch_chosen(choice)` → resolve per-branch flag effects (F-DS-3)
  3. `GameBus.save_checkpoint_requested(ctx: SaveContext)` → `_on_save_checkpoint_requested(ctx)` → populate ctx with owned fields (F-DS-5)
- **CR-DS-8**: All 3 handlers MUST early-return on invalid payload per CR-DB-10 invalid-path emission contract:
  - `scenario_beat_retried(EchoMark)`: skip if `mark.beat_index <= 0` or `mark.outcome == &""`.
  - `destiny_branch_chosen(DestinyBranchChoice)`: skip if `choice.is_invalid == true` (per ADR-0018 §CR-DB-10).
  - `save_checkpoint_requested(SaveContext)`: skip if `ctx == null` or `ctx.chapter_id == &""`.
- **CR-DS-9**: Destiny State is an **autoload Node** (8th invocation of autoload pattern after GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel + ScenarioRunner + HeroDatabase + BalanceConstants). Boot order: position 7 (after ScenarioRunner; before BattleScene-domain Nodes). Same `class_name`-omission discipline per G-3.

### 3.3 Echo lifecycle (CR-DS-10..12)

- **CR-DS-10**: EchoMark accumulation is **append-only within a chapter**. Reset semantics live at the boundary: when ScenarioRunner advances `BEAT_9_TRANSITION → LOADING (next chapter)`, Destiny State's `_on_chapter_advance` handler (subscribed to `chapter_completed`) snapshots the per-chapter echo aggregate INTO the archive history but does NOT delete past EchoMarks. The archive grows monotonically per save.
- **CR-DS-11**: Per-chapter echo_count derivation is **filter-based**: `_compute_echo_count(chapter_id) = filter(echo_marks_archive, m -> m.chapter_id == chapter_id).size()`. EchoMark struct currently lacks a `chapter_id` field (3-field MVP schema per ADR-0003: beat_index + outcome + tag). Destiny State maintains a parallel `Dictionary[StringName, int]` (`_chapter_echo_counts`) that is incremented on each `scenario_beat_retried` event, keyed by ScenarioRunner's `get_current_chapter().chapter_id`. This sidesteps the EchoMark schema gap until SaveMigrationRegistry adds chapter_id to EchoMark.
- **CR-DS-12**: Echo archive hard cap: `ECHO_ARCHIVE_HARD_CAP = 200` (BalanceConstants entry). On exceed, the OLDEST EchoMark is evicted (FIFO) with a `push_warning`. Player retry behavior never produces 200+ marks in normal play (≤5 per chapter × ~30 chapters = 150 max realistic); cap exists as DoS protection against pathological save corruption injecting unbounded marks.

### 3.4 Flag-effect lifecycle (CR-DS-13..15)

- **CR-DS-13**: Flag-effect resolution at `destiny_branch_chosen(choice)` proceeds per F-DS-3. Per-branch flag effects come from chapter authoring data: each ChapterDefinition.branch_table value MAY map to an entry in a future `flag_effects: Dictionary[String, PackedStringArray]` field. MVP scope: this Dictionary is empty (no branch-driven flags shipped); the subscription handler is functional but writes 0 flags per call. Sprint-8+ chapter authoring fills this in.
- **CR-DS-14**: `flags_to_set` is `PackedStringArray` per ADR-0003 (value-type round-trip safety through ResourceSaver). Flag identifiers are case-sensitive snake_case strings (e.g., `"ch01_zhang_fei_solo_stand"`). Duplicates are de-duplicated on insert (FIFO uniqueness — first-add wins). Removal is NOT supported in MVP scope (flags are append-only per save).
- **CR-DS-15**: Beat 8 canonical-history enforcement: when `destiny_branch_chosen(choice)` fires and `choice.is_canonical_history == false`, Destiny State adds a sentinel flag `"divergence_recorded__{chapter_id}__{branch_key}"` to flags_to_set. This marks the per-chapter divergence for downstream Story Event #10 dialogue branching. When `choice.is_draw_fallback == true`, Destiny State adds the additional sentinel `"draw_fallback__{chapter_id}"`. Both sentinels survive cross-chapter advance (CR-DS-14 append-only).

### 3.5 Persistence contract (CR-DS-16..18)

- **CR-DS-16**: At `save_checkpoint_requested(ctx)`, Destiny State writes to ctx: `ctx.echo_count = _chapter_echo_counts.get(ctx.chapter_id, 0)`, `ctx.echo_marks_archive = _full_archive.duplicate(true)`, `ctx.flags_to_set = PackedStringArray(_flags_to_set)`. SaveContext owns the on-disk schema; Destiny State produces a fresh snapshot per checkpoint (no shared mutable references).
- **CR-DS-17**: At save load (driven by SaveManager — Destiny State subscribes to `save_loaded(ctx: SaveContext)` per ADR-0003 future signal slot), Destiny State rehydrates: `_full_archive.assign(ctx.echo_marks_archive.duplicate(true))`, `_flags_to_set = PackedStringArray(ctx.flags_to_set)`, then re-derives `_chapter_echo_counts` by re-scanning the archive (per CR-DS-11). Hydration is idempotent.
- **CR-DS-18**: Destiny State is **stateless from a save-corruption standpoint**: any malformed EchoMark in the loaded archive (per CR-DS-8 invalid-payload guard) is silently dropped during rehydration with a `push_warning`. The archive on disk is treated as untrusted input.

### 3.6 Pillar 2 architectural lock (CR-DS-19)

- **CR-DS-19**: Destiny State MUST NOT introspect ScenarioRunner internal state. Per F-SP-3 echo accumulation is always **driven by emitted `scenario_beat_retried(EchoMark)` events**, never by reading `ScenarioRunner._state` or `ScenarioRunner._echo_counts`. Lint pattern `destiny_state_no_scenario_runner_read` (sprint-7 S7-07 implementation candidate, NOT shipped this delta) will enforce: `grep -E 'ScenarioRunner\\.(_state|_echo_counts|_current_chapter_index)'` MUST return 0 matches in `src/feature/destiny_state/`. This extends the Pillar 2 architectural lock pattern stable at 4 invocations (battle_hud_subscribes_to_hidden_fate_signal + scenario_runner_deferred_seal_in_beat_7_entry + destiny_branch_judge_reads_scenario_runner_state + ai_system_reads_destiny_branch_state) — Destiny State would be the **5th invocation candidate** at implementation story-001 close.

---

## 4. Formulas

### F-DS-1 — EchoMark accumulation

```text
on_scenario_beat_retried(mark: EchoMark):
  if mark.beat_index <= 0 or mark.outcome == &"":
    return  # CR-DS-8 invalid-payload guard

  current_chapter_id := ScenarioRunner.get_current_chapter().chapter_id
  if _full_archive.size() >= ECHO_ARCHIVE_HARD_CAP:
    push_warning("echo archive at hard cap %d; evicting oldest" % ECHO_ARCHIVE_HARD_CAP)
    _full_archive.pop_front()

  _full_archive.append(mark)
  _chapter_echo_counts[current_chapter_id] = _chapter_echo_counts.get(current_chapter_id, 0) + 1
  GameBus.destiny_state_echo_added.emit(mark)
```

### F-DS-2 — echo_count query

```text
get_echo_count(chapter_id: StringName) -> int:
  return _chapter_echo_counts.get(chapter_id, 0)

get_full_archive() -> Array[EchoMark]:
  return _full_archive.duplicate(true)
```

`get_echo_count` is the consumer API for DestinyBranchJudge's F-SP-2 echo-gate predicate (`echo_count >= echo_threshold AND NOT first_attempt_resolved`). DestinyBranchJudge calls Destiny State at Beat 7 entry; result drives DRAW_default vs DRAW_echo branch routing.

### F-DS-3 — flag-effect resolution

```text
on_destiny_branch_chosen(choice: DestinyBranchChoice):
  if choice.is_invalid:
    return  # CR-DS-8 invalid-payload guard (CR-DB-10 mirror)

  # CR-DS-15 sentinel flags (always-on, MVP scope)
  if not choice.is_canonical_history:
    _add_flag("divergence_recorded__%s__%s" % [choice.chapter_id, choice.branch_key])
  if choice.is_draw_fallback:
    _add_flag("draw_fallback__%s" % choice.chapter_id)

  # Per-branch authored effects (sprint-8+ scope; MVP no-op)
  for flag in _resolve_branch_flag_effects(choice.chapter_id, choice.branch_key):
    _add_flag(flag)


_add_flag(flag: String) -> void:
  if flag in _flags_to_set:
    return  # CR-DS-14 dedup
  _flags_to_set.append(flag)
  GameBus.destiny_state_flag_set.emit(flag, true)
```

### F-DS-4 — cross-chapter continuity (flag persistence + echo reset semantics)

```text
on_chapter_completed(result: ChapterResult):
  # CR-DS-10 echo aggregate snapshot (no archive deletion)
  prior_chapter_id := result.chapter_id
  prior_count := _chapter_echo_counts.get(prior_chapter_id, 0)
  if prior_count > 0:
    _archived_chapter_counts[prior_chapter_id] = prior_count
  # NOTE: _chapter_echo_counts[prior_chapter_id] STAYS — re-querying it returns
  # the historical value. The DestinyBranchJudge calls get_echo_count(CURRENT
  # chapter_id), which is implicitly 0 for newly-loaded chapters because no
  # EchoMark has been added yet. No explicit reset needed.

  # flags_to_set: NO change — append-only persists across chapters per CR-DS-14
```

### F-DS-5 — SaveContext population

```text
on_save_checkpoint_requested(ctx: SaveContext):
  if ctx == null or ctx.chapter_id == &"":
    return  # CR-DS-8 invalid-payload guard

  ctx.echo_count = _chapter_echo_counts.get(ctx.chapter_id, 0)
  ctx.echo_marks_archive = _full_archive.duplicate(true)
  ctx.flags_to_set = PackedStringArray(_flags_to_set)
  # Other ctx fields (chapter_number, last_cp, outcome, branch_key, etc.) are
  # owned by ScenarioRunner per ADR-0017 §F-SP-3 — Destiny State does NOT touch them.
```

---

## 5. Edge Cases

- **EC-DS-1** — `scenario_beat_retried` fires before Destiny State autoload `_ready()` completes (race during cold-load). Mitigation: subscriptions are CONNECT_DEFERRED per CR-DS-7; signals queue until next frame after `_ready()` returns. Loss-of-event impossible under normal autoload boot order (position 7 — after ScenarioRunner position 6).

- **EC-DS-2** — DestinyBranchChoice arrives with `is_invalid == true` (e.g., F-DB-3 invariant violation). Per CR-DS-8 + CR-DB-10, handler early-returns; no flag mutation; no signal emission. Test seam: parameterized stub injects `is_invalid=true` → assert `_flags_to_set` unchanged.

- **EC-DS-3** — Save load with stale `echo_marks_archive` (older `schema_version`). SaveManager + SaveMigrationRegistry handle schema upgrade BEFORE `save_loaded` fires. Destiny State assumes the loaded `ctx.echo_marks_archive` matches current EchoMark schema. If migration produces malformed marks, CR-DS-18 silent-drop guard activates.

- **EC-DS-4** — Echo archive overflow (`>= ECHO_ARCHIVE_HARD_CAP`). FIFO eviction of oldest EchoMark per F-DS-1. `push_warning` logged for telemetry. Player-perceived: indistinguishable (200+ retries is impossible in normal MVP play).

- **EC-DS-5** — Cross-chapter advance with non-canonical history flagged. Sentinel `"divergence_recorded__chN__branchX"` persists in `flags_to_set`. Story Event #10 (when authored) reads this to gate Chapter N+1 dialogue branches. MVP scope: flag is set but no consumer reads it.

- **EC-DS-6** — Multiple consecutive `scenario_beat_retried` events in same frame (e.g., player rapidly tapping retry). Each event appends an EchoMark — no debouncing at Destiny State layer. ScenarioRunner is the rate-limiter (per F-SP-3 retry-loop guard).

- **EC-DS-7** — `destiny_branch_chosen(choice)` fires twice for same chapter (e.g., scenario_beat_retried interleave). MVP: each event appends sentinel flag; CR-DS-14 dedup ensures only one `"divergence_recorded__chN__branchX"` entry exists. Multiple `"draw_fallback__chN"` entries coalesce to one.

- **EC-DS-8** — SaveContext arriving at CP-1 (BEAT_1 entry) with empty `chapter_id`. CR-DS-8 invalid-payload guard skips population. CP-1 is the first save AFTER chapter load — chapter_id should be non-empty by then. Skip is defensive; logs `push_warning`.

- **EC-DS-9** — `destiny_branch_chosen` fires but ScenarioRunner.get_current_chapter() returns null (race during chapter-advance frame). Mitigation: F-DS-3 reads `choice.chapter_id` (a payload field, not a ScenarioRunner query) per CR-DS-19 Pillar 2 lock. Destiny State NEVER calls `ScenarioRunner.get_current_chapter()` in the destiny_branch handler — eliminates the race.

- **EC-DS-10** — `_chapter_echo_counts` queried for unknown `chapter_id`. F-DS-2 returns 0 via Dictionary.get() default. DestinyBranchJudge sees echo_count=0 → routes to DRAW_default (not DRAW_echo) per F-SP-2. Safe default.

---

## 6. Dependencies

| System | Direction | Coupling | Notes |
|--------|-----------|----------|-------|
| **Scenario Progression** (#6, MVP) | In | Soft (event subscriber) | Subscribes to `scenario_beat_retried` + `chapter_completed` + `save_checkpoint_requested`. Never reads ScenarioRunner internals (CR-DS-19 Pillar 2 lock). |
| **Destiny Branch** (#4, MVP) | In | Soft (event subscriber + read consumer) | Subscribes to `destiny_branch_chosen` for flag effect resolution. DestinyBranchJudge calls `Destiny State.get_echo_count(chapter_id)` for F-SP-2 echo-gate predicate. |
| **Save/Load** (#17, VS) | Out | Hard (persistence contract) | Writes to SaveContext.echo_marks_archive + flags_to_set + echo_count fields per ADR-0003. Reads via `save_loaded(ctx)` future signal slot. |
| **GameBus** (#1, MVP) | In/Out | Hard (signal transport) | 3 subscriptions in (CR-DS-7) + 2 emissions out (CR-DS-5: destiny_state_flag_set + destiny_state_echo_added). |
| **Story Event** (#10, VS) | Out | Soft (read consumer; not yet authored) | Future #10 will read `flags_to_set` to gate dialogue branches. MVP: flags are written but no consumer reads. |
| **Hidden-Fate System** | — | **FORBIDDEN** | Per CR-DS-6 + CR-DS-19 Pillar 2 architectural lock. Destiny State MUST NOT subscribe to `hidden_fate_condition_progressed`. |

---

## 7. Tuning Knobs

| Constant | Default | Where | Rationale |
|----------|---------|-------|-----------|
| `ECHO_ARCHIVE_HARD_CAP` | `200` | `BalanceConstants` (`assets/data/balance/balance_entities.json`) | DoS protection against pathological save corruption. ≥40× expected normal-play maximum (5 retries × 30 chapters). FIFO eviction with push_warning on exceed. |
| `ECHO_AGGREGATE_RESET_BEAT` | `9` | (Implicit; not exposed) | Beat at which prior-chapter echo aggregate snapshots into archive history. Hardcoded to 9 (Beat 9 chapter transition). Adjustment requires re-validating CR-DS-10 + F-DS-4 invariants. |
| `DESTINY_STATE_FLAG_SENTINEL_FORMAT_DIVERGENCE` | `"divergence_recorded__{chapter_id}__{branch_key}"` | (Hardcoded in F-DS-3) | Sentinel format per CR-DS-15. Documented as a tuning knob for future Story Event #10 authoring; format change requires consumer-side coordination. |
| `DESTINY_STATE_FLAG_SENTINEL_FORMAT_DRAW_FALLBACK` | `"draw_fallback__{chapter_id}"` | (Hardcoded in F-DS-3) | Sentinel format per CR-DS-15. |

---

## 8. Acceptance Criteria

### 8.1 Echo lifecycle (AC-DS-1..6)

- **AC-DS-1**: Given Destiny State in initial state and `scenario_beat_retried(EchoMark)` emitted with valid mark (beat_index=5, outcome=&"LOSS", tag=&"ch01"), when handler completes, then `_full_archive.size() == 1` AND `_chapter_echo_counts["ch01_changbanpo"] == 1` AND `destiny_state_echo_added(mark)` emitted exactly once.
  - **Evidence**: GdUnit4 unit test `test_scenario_beat_retried_appends_echo_and_emits_signal`.
- **AC-DS-2**: Given 5 valid `scenario_beat_retried` events fire across same chapter, when handler completes for each, then `_full_archive.size() == 5` AND `get_echo_count("ch01_changbanpo") == 5` AND `destiny_state_echo_added` emitted exactly 5 times.
- **AC-DS-3**: Given EchoMark with `beat_index <= 0` OR `outcome == &""`, when handler invoked, then `_full_archive` unchanged AND `destiny_state_echo_added` NOT emitted (CR-DS-8 invalid-payload guard).
- **AC-DS-4**: Given `_full_archive.size() == ECHO_ARCHIVE_HARD_CAP` (= 200) and a new valid `scenario_beat_retried`, when handler completes, then size remains 200 AND oldest EchoMark evicted (FIFO) AND `push_warning` emitted with cap-exceed message.
- **AC-DS-5**: Given chapter advance via `chapter_completed("ch01_changbanpo", ...)`, when handler completes, then `_chapter_echo_counts["ch01_changbanpo"]` retains prior count (e.g., 3) AND `_archived_chapter_counts["ch01_changbanpo"] == 3`. New chapter's `get_echo_count("ch02_xinye")` returns 0 by default (Dictionary.get).
- **AC-DS-6**: Given `get_full_archive()` invoked twice after archive populated, when both calls return, then both return Array[EchoMark] with identical content but distinct Object identity (proves `.duplicate(true)` snapshot per CR-DS-4).

### 8.2 Flag-effect lifecycle (AC-DS-7..11)

- **AC-DS-7**: Given `destiny_branch_chosen(choice)` with `choice.is_invalid == true`, when handler invoked, then `_flags_to_set` unchanged AND `destiny_state_flag_set` NOT emitted (CR-DS-8 + CR-DB-10 invalid-path).
- **AC-DS-8**: Given `destiny_branch_chosen(choice)` with `choice.is_canonical_history == false` AND `choice.chapter_id == "ch01_changbanpo"` AND `choice.branch_key == "WIN_changbanpo_alternative"`, when handler completes, then `"divergence_recorded__ch01_changbanpo__WIN_changbanpo_alternative" in _flags_to_set` AND `destiny_state_flag_set("divergence_recorded__...", true)` emitted exactly once.
- **AC-DS-9**: Given `destiny_branch_chosen(choice)` with `choice.is_draw_fallback == true` AND `choice.chapter_id == "ch01_changbanpo"`, when handler completes, then `"draw_fallback__ch01_changbanpo" in _flags_to_set` AND corresponding `destiny_state_flag_set` emitted exactly once.
- **AC-DS-10**: Given `destiny_branch_chosen(choice)` with both `is_canonical_history == false` AND `is_draw_fallback == true`, when handler completes, then BOTH sentinels exist in `_flags_to_set` AND `destiny_state_flag_set` emitted exactly twice (one per sentinel).
- **AC-DS-11**: Given identical `destiny_branch_chosen(choice)` fires twice (e.g., test-injected re-emission), when handler completes for both, then `_flags_to_set` size unchanged after second call (CR-DS-14 dedup) AND `destiny_state_flag_set` emitted only once total.

### 8.3 Persistence contract (AC-DS-12..15)

- **AC-DS-12**: Given Destiny State holds `_full_archive` (3 marks) + `_flags_to_set` (2 flags) + `_chapter_echo_counts["ch01_changbanpo"] == 3`, when `save_checkpoint_requested(ctx)` fires with `ctx.chapter_id == "ch01_changbanpo"`, then `ctx.echo_count == 3` AND `ctx.echo_marks_archive.size() == 3` AND `ctx.flags_to_set.size() == 2`.
- **AC-DS-13**: Given saved SaveContext with archive + flags, when SaveManager `save_loaded(ctx)` fires (future signal), then Destiny State rehydrates: `_full_archive.size() == ctx.echo_marks_archive.size()` AND `_flags_to_set` content equals `ctx.flags_to_set` AND `_chapter_echo_counts` re-derived from archive scan (per CR-DS-17).
- **AC-DS-14**: Given save load with malformed EchoMark in archive (e.g., `beat_index == -1`), when handler completes, then malformed mark dropped from `_full_archive` AND `push_warning` emitted (CR-DS-18 silent-drop).
- **AC-DS-15**: Given `save_checkpoint_requested(ctx)` with `ctx == null` OR `ctx.chapter_id == &""`, when handler invoked, then handler early-returns AND `push_warning` emitted (CR-DS-8 + EC-DS-8).

### 8.4 Pillar 2 architectural lock (AC-DS-16..18)

- **AC-DS-16**: Source-grep lint `lint_destiny_state_no_scenario_runner_read.sh` MUST return 0 matches for `grep -E 'ScenarioRunner\\.(_state|_echo_counts|_current_chapter_index)'` in `src/feature/destiny_state/`. Lint shipped at implementation story-001 close (sprint-7 S7-07 implementation, NOT this design GDD delta).
- **AC-DS-17**: Source-grep lint `lint_destiny_state_no_hidden_fate_subscription.sh` MUST return 0 matches for `grep -E 'hidden_fate_condition_progressed'` in `src/feature/destiny_state/`. Per CR-DS-6.
- **AC-DS-18**: Integration test (G-22 structural assertion pattern): `FileAccess.get_file_as_string("res://src/feature/destiny_state/destiny_state.gd").contains("hidden_fate")` MUST be `false`. Per CR-DS-6 + Pillar 2 lock 5th candidate precedent.

### 8.5 Determinism + cross-API contract (AC-DS-19..21)

- **AC-DS-19**: Given two Destiny State instances seeded with identical archive + flags, when both invoked with identical event sequence (5 scenario_beat_retried + 1 destiny_branch_chosen), then both produce field-identical state (archive content + flag set + chapter counts). No `Time.*` / `rand*` / wall-clock dependencies.
- **AC-DS-20**: Given Destiny State writes a `SaveContext` (AC-DS-12) and ResourceSaver/Loader round-trips it through disk, when reloaded into a fresh Destiny State, then `_full_archive` content + `_flags_to_set` content + `_chapter_echo_counts` are bitwise-equivalent to the pre-save state. ≥2 platforms verified per AC-DB-24 5-platform deferral pattern (Linux Editor + macOS Apple Silicon dev-machine sufficient for sprint-7 close; full 5-platform deferred to release-prep).
- **AC-DS-21**: `DestinyBranchJudge` invocation site `judge.resolve(...)` consumes `Destiny State.get_echo_count(chapter_id)` per F-SP-2; given `_chapter_echo_counts["ch03"] == 5` AND `chapter.echo_threshold == 3`, when judge invoked, then F-SP-2 echo-gate predicate evaluates true AND DRAW_echo branch routed (per ADR-0018 F-DB-1 row 3 echo-gated path).

---

## Open Questions (OQ-DS-1..3)

- **OQ-DS-1**: Should the EchoMark schema be extended to include `chapter_id` (currently 3-field per ADR-0003) to eliminate the `_chapter_echo_counts` parallel structure (CR-DS-11 workaround)? If yes, requires SaveMigrationRegistry entry + ADR-0003 schema_version bump. Decision deferred to sprint-8 SaveMigrationRegistry epic (currently blocked behind Save/Load #17 GDD CUT from sprint-7).

- **OQ-DS-2**: Should `flags_to_set` support flag REMOVAL (currently append-only per CR-DS-14)? Removal would enable per-chapter "redemption" mechanics where prior divergences can be retroactively undone. Decision deferred — no Pillar 2/4 narrative beat in MVP requires this; removal adds significant testing surface (idempotency + replay scenarios).

- **OQ-DS-3**: Should `destiny_state_flag_set` emit a `false`-value variant for flag removal (if OQ-DS-2 ratified)? Currently the signal emits `(flag_key, true)` only. Coupled to OQ-DS-2 — if removal NOT supported, signal stays single-direction.

---

## Implementation hooks (sprint-7 S7-07 GDD delta — NOT IMPLEMENTED HERE)

The following are **NOT** shipped this design-only GDD delta; documented for the implementation story (sprint-8+ candidate per VS tier scope):

1. `src/feature/destiny_state/destiny_state.gd` (~150 LoC autoload Node 8th invocation)
2. `tools/ci/lint_destiny_state_no_scenario_runner_read.sh` (Pillar 2 lock 5th invocation)
3. `tools/ci/lint_destiny_state_no_hidden_fate_subscription.sh` (CR-DS-6 enforcement)
4. `tests/unit/feature/destiny_state/echo_lifecycle_test.gd` (AC-DS-1..6)
5. `tests/unit/feature/destiny_state/flag_effect_lifecycle_test.gd` (AC-DS-7..11)
6. `tests/unit/feature/destiny_state/persistence_contract_test.gd` (AC-DS-12..15)
7. `tests/unit/feature/destiny_state/architectural_lock_test.gd` (AC-DS-16..18 source-grep + G-22 structural)
8. `tests/unit/feature/destiny_state/determinism_test.gd` (AC-DS-19..21)
9. `BalanceConstants` entry: `ECHO_ARCHIVE_HARD_CAP = 200` (UPPER_SNAKE_CASE per data-files.md constants-registry exception)
10. `project.godot` autoload registration: `DestinyState="*res://src/feature/destiny_state/destiny_state.gd"` at boot order position 7
11. ADR-0019 amendment OR new ADR: ratify destiny_state autoload Node 8th invocation + Pillar 2 lock 5th invocation
12. systems-index.md row 16 status: PROVISIONAL → Designed (this delta closes it; sprint-8 implementation flips to Implemented)

---

## Cross-references

- **Governing**: ADR-0003 SaveContext §Schema Stability §EchoMark Resource Contract; ADR-0017 ScenarioRunner §F-SP-3 (echo lifecycle); ADR-0018 DestinyBranch §CR-DB-10 (invalid-path emission)
- **Pillar substrate**: game-concept.md §Pillar 2 (운명은 바꿀 수 있다 — echo-archive enables retry mechanic) + §Pillar 4 (지난 장의 선택이 살아 있다 — flags_to_set enables cross-chapter recognition)
- **Upstream events**: scenario-progression.md §F-SP-3 (`scenario_beat_retried` emitter); destiny-branch.md §F-DB-1 (`destiny_branch_chosen` emitter)
- **Downstream consumers**: destiny-branch.md §F-SP-2 echo-gate predicate (reads `get_echo_count`); future story-event.md §10 (reads `flags_to_set` for dialogue branching)
- **Save persistence**: ADR-0003 §Migration; future Save/Load #17 GDD (currently CUT from sprint-7 per Producer pressure-cut decision)
- **Architectural lock pattern**: control-manifest.md §Pillar 2 Architectural Locks (Destiny State 5th invocation candidate); ai-system.md §CR-AI-8 (4th precedent template); destiny-branch.md §CR-DB-7 (3rd precedent template)
- **Engine constraints**: tooling-gotchas.md G-3 (autoload no class_name); G-7 (silent-skip detection); G-22 (structural source-file assertion for AC-DS-18)
