# Destiny Branch System (운명 분기)

> **Status**: APPROVED — rev 1.3.1 (post tenth-pass /design-review 2026-04-19 — APPROVED with 3 doc-hygiene patches applied in-session)
> **Author**: user + game-designer + specialists (per Section delegation)
> **Last Updated**: 2026-04-19 (rev 1.3.1 — tenth-pass APPROVED + 3 doc-hygiene patches: AC-DB-21 stale-count `5→12` bumped to rev 1.3 F-DB-3; AC-DB-34 stale-count `10→12` bumped to rev 1.3 F-DB-3 with 2 rev 1.3 entries enumerated in parenthetical; F-DB-1 step 1c comment stripped of rejected-API breadcrumb per pass-10 precondition #1 `zero is_valid_result(` hit. All 10 pass-10 preconditions now PASS. Rev 1.3 — ninth-pass blocker sweep: 11 consolidated Tier-1 + 9 Tier-2; 4 user design decisions locked [D1-rev1.3 `reduce_haptics` = 7th Intermediate toggle authored in accessibility-requirements.md §2/§7/§9; D2-rev1.3 AC-DB-20 helper locked to Godot stdout/stderr redirect + grep buffer implementation; D3-rev1.3 OQ-DB-10 threshold inverted to max-miss-rate ≤10% by Ch2 end as Pillar 2 failure threshold; D4-rev1.3 OQ-DB-16 resolved SWALLOW + promoted to BLOCKING VS + closed]. Fixes: F-DB-1 empty-Dictionary guard (systems B-1); assembly-time is_draw_fallback⟹DRAW cross-field invariant check (systems B-2); `BattleOutcome.is_valid_result` invented-API replaced with `outcome in BattleOutcome.Result.values()` (gdscript B-1); signature alignment `outcome: BattleOutcome.Result` throughout (gdscript B-2); `@abstract` annotation on `_apply_f_sp_1` base (gdscript B-3); zero-canonical-row runtime warning path added (narrative B-ND-2); AC-DB-09 fallback removed, committed to `monitor_signals()` + `assert_signal_not_emitted()` (qa-lead B-2); AC-DB-20 helper locked to stdout-redirect implementation (qa-lead B-3); ADVISORY-AC lifecycle — each ADVISORY AC now carries owner + gate + promotion condition (qa-lead B-1); scenario-progression §Interactions line 189 6-field lag + IP-006 UX.2 ack flagged with co-merge gates (systems B-3 + ux B-UX-9-1 + narrative B-ND-1); OQ-DB-11 closed referencing scenario-progression UX.2 lines 817-819 (ux B-UX-9-3); new AC-DB-39 for affordance-onset timing sync; new OQ-DB-17 for Korean braille adequacy (a11y B-2); AC-DB-07 forbidden-pattern list extended with Engine.get_*_frames + DisplayServer.window_* + OS.get_processor_count (systems R-1); TK-DB-1 safe range bounds now carry measurable protocol (systems R-2); V-DB-2 Korean subtitle copy register amended (narrative N-ND-1); Story Event #10 BLOCKING constraint reframed as register-constraint not example-copy (narrative N-ND-3); AC-DB-24 empty-StringName fixture row added (qa-lead R-2); AC-DB-31 chapter-argument-immutability fixture added (qa-lead R-5); UI-DB-5 reversal-trigger condition (b) marked as dead-end (ux R-UX-9-4); Section B "Marked Hand standalone absence" risk note added (narrative N-ND-4); Bucket 2 AC-DB-39 affordance-onset added; Coverage 40→43 ACs. Rev 1.2 resolved 12 Tier-1 + ~18 Tier-2; rev 1.1 resolved 7 Tier-1 + 10 Tier-2 (see review log).
> **Implements Pillar**: Pillar 2 (primary — 운명은 바꿀 수 있다), Pillar 4 (supporting — 삼국지의 숨결)
> **Binds to**: ADR-0001 GameBus autoload (signal contract + DestinyBranchChoice 9-field payload lock)
> **Consumes from Scenario Progression**: F-SP-1 resolve_branch (adds `is_canonical_history` authored field per branch-table row), F-SP-2 is_echo_gate_open

## Overview

The **Destiny Branch System** (운명 분기) is the short-lived judgment module that decides, at one moment per chapter, which of the chapter's pre-authored branches the scenario takes. At Beat 7 — after the battle has resolved and the player has accepted the result — `DestinyBranchJudge` receives `(chapter, BattleOutcome, echo_count)`, executes Scenario Progression's `resolve_branch` formula (F-SP-1), assembles a typed `DestinyBranchChoice` payload, and emits it on the GameBus autoload per ADR-0001. The judge carries no persistent state; its entire life is one synchronous evaluation per chapter. This GDD ratifies the `DestinyBranchChoice` payload shape that ADR-0001 currently holds as a **PROVISIONAL** slot. Player-facing, this is where Pillar 2 crosses from promise to fact: when a non-default branch fires, reserved colors 주홍 `#C0392B` + 금색 `#D4A017` enter the frame for the first and only time that chapter, and the player — without ever seeing a branch menu — registers that history just took a different path because of what they did.

## Player Fantasy

### Primary framing: Ceremonial Witness

The emotional target is **ceremonial witness**: the player does not *choose* a branch; they *observe* which branch the world takes because of what they did. The fantasy is Pillar 2 made concrete at a precise moment — the 1.5-second dwell lockout at Beat 7, the reserved colors 주홍 `#C0392B` + 금색 `#D4A017` entering the frame for the first (and only) time in the chapter, and the pre-linguistic realization that history just took a different path.

**The 30-second moment.** The battle is over. The player accepted the result at Beat 6. The screen enters Beat 7's witness gate — and holds. For 1.5 seconds there is nothing to click. That silence is not UX friction; it is the ceremony the system is built to deliver. If the branch is non-default, the reserved colors bleed into the panel. The player registers, without language and without menu, that the world moved because of what they did. Beat 8 then delivers the 演義 contrast in words — but Beat 7 must land wordlessly first.

**Register.** Solemn, liturgical — temple-bell rather than fanfare. *"관측되는 것이지 선택되는 것이 아니다."* The closest emotional reference is KOEI 영걸전's hidden-branch reveal (direct lineage) or Dark Souls' deliberate post-boss pause, not Triangle Strategy's explicit vote screen — the game respects that something meaningful happened by *not* immediately narrating it.

### Secondary register: The Marked Hand (DRAW + high echo_count only)

When the DRAW branch fires after multiple retries (echo-gated path, `is_echo_gate_open == true` per F-SP-2), a trace of cost enters the fantasy: the player rewrote this outcome, but not without weight. *"운명을 다시 쓰는 자는 흔적 없이 다시 쓰지 못한다."* This secondary note is carried primarily by downstream systems — Beat 2 Prior-State Echo fragments on subsequent chapters (Story Event #10 VS + Destiny State #16 VS) and Beat 8 revelation tone (Story Event #10 VS). Destiny Branch itself contributes only the *signal*: the `DestinyBranchChoice` payload surfaces `echo_count` + `is_draw_fallback` so downstream systems can honor the accumulated cost. The primary witness fantasy still governs Beat 7's felt moment; the marked-hand note layers on top through downstream content.

### What this fantasy is NOT

- **NOT a branch-selection menu.** The player never sees alternate branches or their count.
- **NOT an achievement badge.** No "BRANCH UNLOCKED" chrome. The reserved colors + silence carry the entire communication.
- **NOT a reward for the battle.** The reveal belongs to Beat 7, not to Grid Battle's victory screen.
- **NOT confirmation that the player "played well."** The system is silent on judgment; it only reports what happened.
- **NOT an undo surface.** Beat 9 commits the branch; there is no rewind. The irreversibility of Beat 7 is load-bearing for Ceremonial Witness — witnessing is irreversible by definition. Player dissatisfaction with a branch outcome should be addressed through Beat 8 content quality (Story Event #10 territory), not through undo mechanics (scope-rejected at CR-DB-12 #3).

### Ch1 tutorial shape — priming-null by design

Per scenario-progression CR-13, Ch1 cannot declare `echo_threshold`, which combined with the default-WIN pattern means Ch1's Beat 7 always emits `reserved_color_treatment=false`. **The player's first-ever Beat 7 is always the default variant** — ink-density motion only, no reserved colors, no haptic, no 해금. This is intentional:

- Ch1 establishes the default visual vocabulary. V-DB-2's ink-density ramp becomes retroactively meaningful once the player has seen the reserved-color contrast at Ch2+.
- The Ceremonial Witness fantasy is gated Ch2+ in practice. Ch1's Beat 7 is a quiet transition moment, not a revelation.
- Pillar 2's mechanical expression relies on contrast; contrast requires a prior. The design accepts this tutorial shape rather than introducing a Ch1 demo-reveal or mandating a Ch2 first-reveal guarantee (both evaluated and rejected: demo breaks system boundary; mandate constrains scenario-progression authoring).

**Consequence for first-playthrough**: if the Ch2 chapter fixture also resolves to a default branch (clean WIN on first attempt, no DRAW, no LOSS), the player may not experience the reserved-color reveal until Ch3. This is acceptable tutorial pacing for Pillar 2 *up to a concrete threshold* — rev 1.3 failure-threshold framing (per game-designer B-2): **Pillar 2 FAILS MVP acceptance if more than 10% of playtest sessions reach Ch2 end without a reserved-color reveal.** The 30% escalation threshold in rev 1.2 was corrected per game-designer adversarial finding — it measured rate-of-exposure, not quality-of-realization, and accepting a 29% miss rate through Ch3 is narratively catastrophic for a system whose entire purpose is to deliver Pillar 2's crossing from possibility to observed fact. See OQ-DB-10 for full gate conditions + qualitative probe requirement.

**Degraded-channel note (rev 1.3 game-designer N-1 addendum)**: the "wordless pre-linguistic realization" framing in this section describes the full-channel experience. For Reduce-Motion + colorblind + PC-no-gamepad players, the Beat 7 moment is delivered primarily through the V-DB-2 subtitle channel (`beat_7.subtitle.reserved`) — the revelation is subtitle-dependent, not wordless, for that player population. This degradation is acceptable per IP-006 carve-out + UI-DB-4 matrix but the "wordless" framing IS a full-channel claim, not a universal one.

### Pillar anchoring

- **Pillar 2 (primary)** — this section *is* the Pillar 2 moment. The game's core promise crosses from possibility to observed fact here.
- **Pillar 4 (supporting)** — Beat 8 canonical-history contrast (演義 vs. rewritten) is delivered by Story Event #10 consuming the `DestinyBranchChoice` payload; Beat 7 sets the condition for that contrast to land.

**Provisional assumption**: the secondary "Marked Hand" register depends on Story Event #10 (VS, not yet designed) authoring distinct Beat 8 tones for echo-gated vs. default DRAW branches. If #10 chooses not to differentiate, destiny-branch still delivers the primary ceremonial-witness register alone.

**Standalone-absence risk (rev 1.3 narrative N-ND-4)**: destiny-branch itself contributes only the SIGNAL (payload fields `echo_count`, `is_draw_fallback`). Beat 7's wordless visual moment (V-DB-1, V-DB-2, A-DB-2) is IDENTICAL whether `echo_count` is 1 or 10 — a player on their fifth retry sees exactly the same Beat 7 as a player on their first. The accumulated-weight quality Section B describes has NO expression within destiny-branch; it exists only as a promise to Story Event #10 VS. **If #10 VS is cut, deprioritized, or ships without echo-differentiated Beat 8 tone, the Marked Hand register disappears from the game entirely with no destiny-branch fallback.** This is an accepted MVP risk (Marked Hand is a secondary register layered on top of the primary Ceremonial Witness), but #10 VS is the sole carrier — producer coordination must track #10 VS design-start + content-authoring as a Vertical Slice deliverable, not defer to Alpha.

## Detailed Design

### Core Rules

**CR-DB-1. System boundary.** Destiny Branch is a distinct system — not a private method on ScenarioRunner — because four cross-cutting responsibilities require a named owner: (a) authoring the `DestinyBranchChoice` typed Resource payload per ADR-0001 §3; (b) ratifying ADR-0001's PROVISIONAL signal-slot payload; (c) carrying the idempotency guarantee as an independently-testable invariant; (d) executing F-SP-1 per the registry note "Destiny Branch #4 will consume branch_key from this formula; MUST NOT re-implement the DRAW-fallback branch by pattern."

**CR-DB-2. The judge is a pure function.** `DestinyBranchJudge` is a `RefCounted` class with a single public method `resolve(chapter, outcome, echo_count) → DestinyBranchChoice`. No instance state between calls, no external state read inside the function body, no RNG call site.

**CR-DB-3. Judge is transient per call.** ScenarioRunner creates `DestinyBranchJudge.new()` at BEAT_7_JUDGMENT tap exit, calls `resolve()` synchronously, reads the returned payload, and discards the instance (RefCounted scope drop). No long-lived instance, no autoload, no caching.

**CR-DB-4. Emission lives in ScenarioRunner.** `destiny_branch_chosen.emit()` is called by ScenarioRunner's BEAT_7_JUDGMENT tap handler, not by DestinyBranchJudge. The tap handler reads as one sequential block: (1) `var choice = judge.resolve(...)`; (2) emit CP-2 `save_checkpoint_requested`; (3) emit `destiny_branch_chosen(choice)`. **Statement-order guarantee (rev 1.2 R-3 clarification)**: Godot's `emit()` is synchronous — it fires on the current statement and returns immediately. Per ADR-0001 all cross-scene subscribers use `CONNECT_DEFERRED`, which defers *handler invocation* to the next idle frame but does NOT defer `emit()` itself. Therefore emit-statement order is deterministic and preserves the CP-2 → branch emission ordering that AC-SP-17 / AC-DB-25 assert. Subscriber *receive* order is a separate concern (next idle frame, Godot scheduler) and is NOT what AC-DB-25 tests.

**CR-DB-5. One evaluation per chapter.** `resolve()` is called exactly once per chapter, at BEAT_7_JUDGMENT tap exit. No signal, state transition, or player action within the chapter may re-trigger it. (Covers a gap in scenario-progression CR-15 — which forbids mid-battle retry + post-Beat-9 undo but not mid-Beat-7 re-trigger.)

**CR-DB-6. No intermediate state observable.** Internal computation — branch-table lookup, F-SP-2 echo-gate evaluation, draw-fallback derivation — is invisible to any system before `destiny_branch_chosen` fires. No interim signal, no partial emission, no side-effect on shared state. Downstream MUST NOT pre-read branch state via alternate channels.

**CR-DB-7. Signal emitted exactly once per chapter, at Beat 7 exit.** `destiny_branch_chosen` fires once per chapter, on the tap event that exits BEAT_7_JUDGMENT (after the 1.5s dwell lockout). Evaluation time (judge.resolve call) is distinct from emission time; the two are separated by the CP-2 save emission. This distinction is load-bearing for the AC-SP-17 ordering contract.

**CR-DB-8. No branch structural information leaks.** The judge does not emit, log, or pass any information about `chapter.branch_table` size, un-taken branches, or other-row conditions. The only output is `DestinyBranchChoice` for the branch that fired. `reserved_color_treatment: bool` tells renderers reserved colors apply — it does NOT tell them "a different path was possible." (Scenario-progression CR-13 is the authoring-layer rule; CR-DB-8 is the system-layer rule. Separation is clean.)

**CR-DB-9. `reserved_color_treatment` is derived, not authored.** Rule: `reserved_color_treatment = (branch_key != chapter.default_branch_key)`. Pure function of F-SP-1's output. No per-row authored override — guarantees the Ceremonial Witness fantasy reliability across all 5 chapters × 2–3 branches of MVP scope.

**CR-DB-10. Invalid-input result pattern.** When invariants are violated (null chapter, missing outcome row, unknown outcome enum, Ch1-echo_threshold CR-13 violation, missing default_branch_key), the judge still returns a constructable `DestinyBranchChoice` with `is_invalid: true` + `invalid_reason: StringName` ∈ the vocabulary in Section D. ScenarioRunner emits unconditionally to preserve AC-SP-17. Downstream consumers (Story Event #10, Destiny State #16, Save/Load #17) gate content on `is_invalid`; if true, surface player-facing error dialog and halt beat sequence. Warning-severity recoveries (negative `echo_count` → clamp to 0, `draw_fallback` applied) do NOT set `is_invalid`; they may surface a warning-prefixed source flag for telemetry.

**CR-DB-11. Determinism invariant.** No randomness, no wall-clock dependency, no instance-level memory. Identical `(chapter, outcome, echo_count)` → field-identical `DestinyBranchChoice`. Asserted by per-fixture tests (Section H).

**CR-DB-12. Scope rejection (NOT in MVP).**
1. Dynamic branch generation — no runtime composition of branch text/conditions/revelations.
2. Branch previewing — players never see branch count, conditions, or un-taken content.
3. Branch undo / rewind — Beat 9 commits; no pre-judgment restore.
4. Per-difficulty branch variants — one `branch_table` per chapter; no runtime `echo_threshold` shift.
5. Conditional reserved-color suppression — no authored override of CR-DB-9. (**Photosensitivity rationale, rev 1.2 REC-2**: this scope-rejection was evaluated against accessibility-requirements.md §2 photosensitive-epilepsy concerns. V-DB-1's Reduce Motion snap variant removes animation onset while preserving 주홍 chromatic information — snap is the designated mitigation for SC 2.3.3. A separate SC 2.3.1 flash-safety audit is flagged for Pre-Production (see V-DB-1 note + OQ-DB-[photosensitive]). Per-player opt-out of reserved-color rendering would break the Pillar 2 Ceremonial Witness fantasy for all players; individual photosensitivity accommodations are deferred to OS-level color-filter / display-accommodations settings, not in-game override.)
6. Mid-chapter branch re-evaluation — one `resolve()` call per chapter (CR-DB-5).
7. Probability-weighted branches — selection is deterministic from `(outcome, echo_count)`; no RNG (CR-DB-11).

Any of these becoming in-scope for VS/Alpha requires a superseding design decision + ADR-0001 amendment.

### States and Transitions

Destiny Branch has no persistent state machine — it is a transient function within ScenarioRunner's BEAT_7_JUDGMENT state. The interaction sequence within Beat 7:

| # | Phase | Owner | Action | Preconditions | Postconditions |
|---|-------|-------|--------|---------------|----------------|
| 1 | BEAT_7_JUDGMENT entry | ScenarioRunner | Display branch teaser UI, start 1.5s dwell lockout timer | BEAT_6_RESULT exited with player tap on "Accept" or WIN | Dwell timer running; tap input blocked |
| 2 | Dwell lockout | ScenarioRunner + UI | Hold; input blocked for 1.5s minimum (scenario-progression CR-10) | Dwell timer running | Timer elapsed; tap input unblocked |
| 3 | Tap received | ScenarioRunner | Consume tap; begin Beat 7 exit sequence | Dwell timer elapsed | Exit sequence started |
| 4 | Judge construction | ScenarioRunner | `var judge := DestinyBranchJudge.new()` | Exit sequence started | Judge instance exists |
| 5 | Evaluation | DestinyBranchJudge | `var choice := judge.resolve(chapter, outcome, echo_count)` — execute F-SP-1, derive `reserved_color_treatment` per CR-DB-9, handle invalid paths per CR-DB-10, return `DestinyBranchChoice` | Judge instance exists; inputs well-formed OR invalid with handled reason | `choice` bound; judge internal state discarded |
| 6 | CP-2 save emit | ScenarioRunner | `GameBus.save_checkpoint_requested.emit(save_context)` | `choice` exists | CP-2 save inflight (Save/Load #17 handles async) |
| 7 | Branch emit | ScenarioRunner | `GameBus.destiny_branch_chosen.emit(choice)` | CP-2 emit statement returned (AC-SP-17 ordering) | Subscribers deferred-fire on next idle frame |
| 8 | Judge disposal | Godot runtime | RefCounted scope drop; judge instance freed | `resolve()` returned; local `judge` out of scope | Judge memory reclaimed |
| 9 | BEAT_7_JUDGMENT exit | ScenarioRunner | Transition to BEAT_8_REVEAL | Branch emit statement returned | Beat 8 begins |

Key property: the judge is alive only between steps 4–8. It carries no identity, no history, no persistence. Within the chapter, the `DestinyBranchChoice` payload — held by subscribers via deferred dispatch — is the sole surviving artifact of the judge's existence.

### Interactions with Other Systems

| System | Tier | Direction | Interface |
|--------|------|-----------|-----------|
| **Scenario Progression** (#6 MVP) | Hard | Both | **destiny-branch consumes**: F-SP-1 formula spec, F-SP-2 predicate, `chapter` resource shape (`branch_table`, `default_branch_key`, `author_draw_branch`, `echo_threshold`), `BattleOutcome.result`, `echo_count`. **destiny-branch provides**: `DestinyBranchJudge.resolve()` pure function called by ScenarioRunner at BEAT_7_JUDGMENT tap exit; `DestinyBranchChoice` typed payload shape. Contract: destiny-branch NEVER mutates ScenarioRunner state, NEVER emits signals (CR-DB-4), NEVER calls `Time.get_ticks_msec()`. |
| **Grid Battle** (#1 MVP) | Hard (indirect) | In | `BattleOutcome.result: Result {WIN, DRAW, LOSS}` flows through ScenarioRunner into `resolve()`. destiny-branch does NOT subscribe to `battle_outcome_resolved` directly. DRAW is NEVER re-interpreted (AC-SP-3 locks this). |
| **GameBus** (ADR-0001) | Hard | Contract | `destiny_branch_chosen(DestinyBranchChoice)` — this GDD ratifies the payload. **9-field shape** locked in Section D. **ADR-0001 minor amendment required** per Evolution Rule #4: current provisional list (`chapter_id, branch_key, revelation_cue_id, required_flags, authored`) replaced by ratified 9-field list (`chapter_id, branch_key, outcome, echo_count, is_draw_fallback, is_canonical_history, reserved_color_treatment, is_invalid, invalid_reason`). |
| **Destiny State** (#16 VS) | Soft downstream (PROVISIONAL) | Out | Subscribes to `destiny_branch_chosen` via GameBus. Reads `echo_count` + `is_draw_fallback` for echo-archive maintenance. MUST gate content consumption on `is_invalid == false`. PROVISIONAL: #16 VS not yet designed; if it chooses a different consumption pattern this GDD may need adjustment. |
| **Story Event** (#10 VS) | Soft downstream (PROVISIONAL) | Out | Subscribes to `destiny_branch_chosen`. Beat 8 revelation content keyed on `(chapter_id, branch_key)`. Differentiates tone by `is_draw_fallback` (scenario-progression CR-14, lower-stakes DRAW-fallback) and by echo-gated path. Halts beat sequence if `is_invalid == true`. PROVISIONAL: Beat 8 `BeatCue` shape is locked by #10 VS. |
| **Save/Load** (#17 VS) | Soft downstream (PROVISIONAL) | Out (via ScenarioRunner chain) | Subscribes to `chapter_completed(ChapterResult)` emitted by ScenarioRunner at Beat 9; `ChapterResult.branch_triggered` set from `DestinyBranchChoice.branch_key`. CP-2 at Beat 7 exit (before `destiny_branch_chosen`) does NOT yet contain `branch_key` — CP-2 captures "player accepted outcome, about to witness branch"; CP-3 at Beat 9 captures the committed branch. |
| **ADR-0001 GameBus** | Hard upstream | Binding | `CONNECT_DEFERRED` mandatory for cross-scene subscribers; `DestinyBranchChoice` must round-trip via `ResourceSaver`/`ResourceLoader` (ADR-0001 V-3). `DestinyBranchChoice` defined in `src/core/payloads/destiny_branch_choice.gd` with `class_name` + `@export` fields. |
| **ADR-0003 Save/Load** | Soft upstream (contract timing only) | Reference | CP-2 / CP-3 timing owned by ADR-0003; destiny-branch only references them to document Beat 7 emission-order contract. |

**Bidirectional consistency note**: scenario-progression.md §Interactions line 186–188 currently reads "Destiny Branch owns the branch-table lookup logic (CR-5 formula implementation) and the `DestinyBranchChoice` payload authoring." This GDD interprets that as: scenario-progression SPECIFIES F-SP-1 (formula contract), destiny-branch EXECUTES F-SP-1 inside DestinyBranchJudge. Scenario-progression's next revision should confirm or refine this wording. Not a conflict today; a tension to watch.

**Engine notes (Godot 4.6 / GDScript)**:
- `DestinyBranchJudge` extends `RefCounted`, not `Node`. No scene-tree presence, no `_ready`, no `_exit_tree`.
- `DestinyBranchChoice` extends `Resource`, declares `class_name DestinyBranchChoice`, `@export`s the **9 fields** (per F-DB-4). Must pass the `payload_serialization_test.gd` round-trip per ADR-0001 V-3.
- `resolve()` is fully synchronous — no `await`, no coroutine. Total execution budget is a tiny fraction of the 16.6ms frame budget (one dictionary lookup + a few comparisons).

## Formulas

destiny-branch does not define *new* formulas in the balance sense — it executes F-SP-1 (owned by scenario-progression) and assembles a typed payload. Section D spells out: (1) the payload assembly algorithm, (2) the `reserved_color_treatment` derivation extracted as a formula, (3) the `invalid_reason` vocabulary, and (4) the ratified `DestinyBranchChoice` field schema with invariants + worked examples.

### F-DB-1. `DestinyBranchChoice` assembly

The assembly formula is defined as:

`resolve(chapter, outcome, echo_count) → DestinyBranchChoice`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| chapter | `chapter` | `ChapterResource` | non-null when valid | Chapter resource from ScenarioRunner current-chapter context (owned by scenario-progression) |
| outcome | `outcome` | `BattleOutcome.Result` | {WIN, DRAW, LOSS} | Battle outcome from Grid Battle (passthrough via ScenarioRunner; AC-SP-3) |
| echo_count | `echo_count` | int | [0, ∞) practical; negative clamps to 0 with warning | Current-chapter retry count from ScenarioRunner state (F-SP-3 contract) |

**Algorithm** (GDScript pseudocode):

```gdscript
func resolve(chapter: ChapterResource, outcome: BattleOutcome.Result, echo_count: int) -> DestinyBranchChoice:
    # Rev 1.3 signature alignment (gdscript B-2): `outcome` is typed `BattleOutcome.Result`
    # to match F-DB-4 @export schema. All `%d` format calls use `int(outcome)` cast per
    # Godot 4.6 typed-enum-in-format-string rules.
    # 1. Invariant checks (CR-DB-10)
    if chapter == null:
        push_error("DestinyBranchJudge: chapter is null")
        return DestinyBranchChoice.invalid(&"invariant_violation:chapter_null")
    if chapter.chapter_id == "":
        push_error("DestinyBranchJudge: chapter.chapter_id empty")
        return DestinyBranchChoice.invalid(&"invariant_violation:chapter_id_missing")
    if chapter.default_branch_key == "":
        push_error("DestinyBranchJudge: chapter.default_branch_key empty")
        return DestinyBranchChoice.invalid(&"invariant_violation:default_branch_key_missing")
    if chapter.branch_table == null or not (chapter.branch_table is Dictionary):
        push_error("DestinyBranchJudge: chapter.branch_table null or non-Dictionary")
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_table_null_or_malformed")
    # 1a. Empty-Dictionary guard (rev 1.3 systems B-1). `{}` passes null + Dictionary-type
    #     checks but cannot satisfy outcome-keyed lookup. Route explicitly.
    if chapter.branch_table.is_empty():
        push_error("DestinyBranchJudge: chapter.branch_table is empty Dictionary")
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_table_empty")
    # 1b. At-least-one-canonical-row runtime warning (rev 1.3 narrative B-ND-2). Exactly-one
    #     enforcement is authoring-layer (scenario-progression v2.1 schema validator), but
    #     destiny-branch MUST surface zero-canonical chapters as a warning so silent Pillar-4
    #     collapse is observable in development. Not is_invalid — ship must proceed; telemetry
    #     surfaces authoring drift.
    var canonical_row_count: int = 0
    for row_key in chapter.branch_table:
        var row: Variant = chapter.branch_table[row_key]
        if row is Dictionary and row.get("is_canonical_history", false):
            canonical_row_count += 1
    if canonical_row_count == 0:
        push_warning("DestinyBranchJudge: chapter %s has ZERO canonical rows (Pillar 4 drift)" % chapter.chapter_id)
    elif canonical_row_count > 1:
        push_warning("DestinyBranchJudge: chapter %s has %d canonical rows (Pillar 4 requires exactly one)" % [chapter.chapter_id, canonical_row_count])
    # 1c. Outcome-value check — GDScript-native membership test against the enum's
    #     concrete values. Type-safe; survives enum reordering.
    if not int(outcome) in BattleOutcome.Result.values():
        push_error("DestinyBranchJudge: outcome enum value %d invalid" % int(outcome))
        return DestinyBranchChoice.invalid(&"invariant_violation:outcome_unknown")
    if chapter.chapter_number == 1 and chapter.has_echo_threshold():
        push_error("DestinyBranchJudge: Ch1 echo_threshold violates CR-13")
        return DestinyBranchChoice.invalid(&"invariant_violation:cr13_echo_threshold_on_ch1")

    # 2. Warning-severity clamp (not invalidating)
    if echo_count < 0:
        push_warning("DestinyBranchJudge: echo_count clamped from %d to 0" % echo_count)
        echo_count = 0

    # 3. Execute F-SP-1 via overridable seam _apply_f_sp_1 (see Section F test-seam contract).
    #    Formula specified by scenario-progression §D. The seam is `virtual` so GdUnit4 test
    #    subclasses can inject mock F-SP-1 output per AC-DB-20c/20d/20e without touching
    #    scenario-progression code. See `TestDestinyBranchJudgeWithSp1Stub` pattern below.
    var f_sp_1: Dictionary = _apply_f_sp_1(chapter, outcome, echo_count)
    # 3a. Key-presence guard (required-key set is the contract with F-SP-1)
    if f_sp_1.is_empty() or not f_sp_1.has("branch_key") or not f_sp_1.has("is_draw_fallback") or not f_sp_1.has("is_canonical_history"):
        push_error("DestinyBranchJudge: F-SP-1 output missing required key(s) for outcome %d" % outcome)
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_table_missing_outcome")
    # 3b. Type guards — defense-in-depth against authoring errors or test-double bugs.
    #     Parentheses MANDATORY around `X is Y` per godot-gdscript-specialist rev 1.2 B-5
    #     (GDScript 4.6 `is` binds tighter than `not`, but explicit parentheses prevent
    #     future-maintainer misreads and pass `not (X is Y)` through any linter ambiguity check).
    if not (f_sp_1["branch_key"] is String):
        push_error("DestinyBranchJudge: F-SP-1 branch_key is non-String type")
        return DestinyBranchChoice.invalid(&"invariant_violation:branch_key_type_invalid")
    if not (f_sp_1["is_draw_fallback"] is bool):
        push_error("DestinyBranchJudge: F-SP-1 is_draw_fallback is non-bool type")
        return DestinyBranchChoice.invalid(&"invariant_violation:is_draw_fallback_type_invalid")
    if not (f_sp_1["is_canonical_history"] is bool):
        push_error("DestinyBranchJudge: F-SP-1 is_canonical_history is non-bool type")
        return DestinyBranchChoice.invalid(&"invariant_violation:is_canonical_history_type_invalid")

    # 3c. Cross-field invariant enforcement (rev 1.3 systems B-2). F-DB-4 declares
    #     `is_draw_fallback == true ⟹ outcome == DRAW`. Without assembly-time enforcement,
    #     a pathological F-SP-1 output with `is_draw_fallback: true` + outcome ∈ {WIN, LOSS}
    #     silently assembles a violating-the-invariant payload with `is_invalid=false`.
    #     Enforce here before step 4 uses is_draw_fallback to override reserved_color.
    if f_sp_1["is_draw_fallback"] and outcome != BattleOutcome.Result.DRAW:
        push_error("DestinyBranchJudge: is_draw_fallback=true requires outcome=DRAW; got %d" % int(outcome))
        return DestinyBranchChoice.invalid(&"invariant_violation:is_draw_fallback_outcome_mismatch")

    # 4. Derive reserved_color_treatment per F-DB-2 / CR-DB-9
    var reserved_color: bool = (f_sp_1["branch_key"] != chapter.default_branch_key)
    # 4a. Fallback override: is_draw_fallback=true → reserved_color=false (F-DB-2 local enforcement).
    #     This step is the enforcement site for the payload invariant at F-DB-4
    #     (reserved_color_treatment==true ⟹ is_draw_fallback==false); see invariant note.
    if f_sp_1["is_draw_fallback"]:
        reserved_color = false

    # 5. Assemble payload (9 fields per F-DB-4)
    var choice := DestinyBranchChoice.new()
    choice.chapter_id = chapter.chapter_id
    choice.branch_key = f_sp_1["branch_key"]
    choice.outcome = outcome
    choice.echo_count = echo_count
    choice.is_draw_fallback = f_sp_1["is_draw_fallback"]
    choice.is_canonical_history = f_sp_1["is_canonical_history"]
    choice.reserved_color_treatment = reserved_color
    choice.is_invalid = false
    choice.invalid_reason = &""
    return choice
```

**Output:** `DestinyBranchChoice` Resource (**9 fields** per F-DB-4).
**Output Range:** `is_invalid ∈ {false, true}` — exactly one of two shapes (valid narrative payload or invalid flag payload).
**Complexity:** O(1) per call — one dictionary lookup (F-SP-1) + constant-time field assignments.

**Test-seam contract for `_apply_f_sp_1` (rev 1.2 D3 + rev 1.3 `@abstract` annotation per gdscript B-3).** The `_apply_f_sp_1` method is declared **`@abstract`** on `DestinyBranchJudge` (Godot 4.5+ annotation — verified in `docs/engine-reference/godot/VERSION.md` 4.5 feature additions). The base method has no body; concrete subclasses MUST override it. The production judge used by ScenarioRunner is itself a concrete subclass that delegates to scenario-progression's F-SP-1 implementation. This pattern (a) makes the seam explicit to the GDScript linter — prior rev 1.2 wording "declared virtual" without annotation produced `override-without-super` warnings in Godot 4.5+; (b) fails hard at parse time if a concrete subclass forgets to override, catching test-harness bugs immediately rather than silently returning empty Dictionary. The canonical GdUnit4 stub pattern (lives in `tests/helpers/destiny_branch_judge_stub.gd`):

```gdscript
class_name TestDestinyBranchJudgeWithSp1Stub
extends DestinyBranchJudge

var _stub_output: Dictionary = {}

func set_sp1_output(output: Dictionary) -> void:
    _stub_output = output

func _apply_f_sp_1(_chapter: ChapterResource, _outcome: BattleOutcome.Result, _echo_count: int) -> Dictionary:
    return _stub_output
```

The `@abstract` declaration lives on the base `DestinyBranchJudge._apply_f_sp_1` in `src/feature/destiny_branch/destiny_branch_judge.gd`:

```gdscript
@abstract
func _apply_f_sp_1(chapter: ChapterResource, outcome: BattleOutcome.Result, echo_count: int) -> Dictionary:
    pass  # unreachable — must be overridden
```

**Concurrent-override caveat (rev 1.3 systems R-3).** EC-DB-17 thread-safety guarantee applies to the base class construction. Subclasses overriding `_apply_f_sp_1` MUST NOT introduce class-level (`static var`) state; the CI lint rule grepping `static var` in `destiny_branch_judge.gd` AND in any file declaring a subclass of `DestinyBranchJudge` enforces this. TestDestinyBranchJudgeWithSp1Stub uses instance-level `_stub_output` which is safe (each test instance isolated).

Test code constructs `TestDestinyBranchJudgeWithSp1Stub.new()`, calls `set_sp1_output({...})` with any of the malformed shapes (non-String branch_key, non-bool is_draw_fallback, etc.), then calls `resolve()` and asserts the resulting `invalid_reason`. AC-DB-20c/20d/20e use this pattern (no monkey-patching; no property-based-testing API; no GdUnit4 version-fragile assumption). This follows damage-calc rev 2.6 bypass-seam precedent (AC-DC-21/28/51).

### F-DB-2. `reserved_color_treatment` derivation

The derivation formula is defined as:

`reserved_color_treatment = (choice.branch_key != chapter.default_branch_key) AND (NOT is_draw_fallback)`

The second clause (fallback override) is applied in F-DB-1 step 4a as a local enforcement — it does NOT rely on scenario-progression's CR-14 authoring discipline to keep fallback `branch_key == default_branch_key`. Even if a writer bug causes F-SP-1 to return `is_draw_fallback=true` alongside a `branch_key` that differs from `default_branch_key`, destiny-branch will force `reserved_color=false` to preserve Pillar 2 semantics locally.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `choice.branch_key` | — | String | ∈ `chapter.branch_table` keys | Result of F-SP-1 |
| `chapter.default_branch_key` | — | String | Non-empty | Authored key of the chapter's default branch |
| `is_draw_fallback` | — | bool | {true, false} | F-SP-1 output — true when DRAW outcome resolved via WIN-branch fallback per CR-14 |

**Output Range:** bool ∈ {true, false}

**Behavior at extremes:**
- Always `false` when F-DB-1 invalid-path taken (`is_invalid == true`) — even if branch_key != default by chance, the invalid flag means there is no "branch divergence" to celebrate. The `invalid()` factory sets `reserved_color_treatment=false` as default; it is never overridden on the invalid path.
- Always `false` when `is_draw_fallback == true` — enforced locally at F-DB-1 step 4a regardless of whether `branch_key` equals `default_branch_key`.

**Example:**
- Ch3 `default_branch_key = "WIN_ch3_default"`, F-SP-1 returns `branch_key = "DRAW_ch3_echo"` → **true**
- Ch1 `default_branch_key = "WIN_ch1_default"`, F-SP-1 returns `branch_key = "WIN_ch1_default"` → **false**
- Ch2 (no DRAW branch authored) DRAW outcome → F-SP-1 returns `branch_key = "WIN_ch2_default"` with `is_draw_fallback = true` → `reserved_color_treatment = false` (fallback is NOT a divergence)

### F-DB-3. `invalid_reason` vocabulary

`invalid_reason` is populated ONLY when `is_invalid == true`. Warning-severity conditions (negative echo_count clamp, draw_fallback application) surface via `push_warning` for telemetry and via other payload fields (e.g., `is_draw_fallback == true` implicitly signals the fallback) — they do NOT populate `invalid_reason`.

| `invalid_reason` StringName | Trigger condition | Expected frequency |
|---|---|---|
| `&"invariant_violation:chapter_null"` | `chapter` argument is null | Zero in ship; tests only |
| `&"invariant_violation:chapter_id_missing"` | `chapter.chapter_id` empty String | Zero in ship (authoring validator catches); runtime guard |
| `&"invariant_violation:default_branch_key_missing"` | `chapter.default_branch_key` unset or empty | Zero in ship (authoring validator catches); runtime guard |
| `&"invariant_violation:branch_table_null_or_malformed"` | `chapter.branch_table` null or non-Dictionary type | Zero in ship (schema validator catches); runtime guard |
| `&"invariant_violation:branch_table_empty"` | `chapter.branch_table` is an empty Dictionary `{}` (rev 1.3 systems B-1) | Zero in ship (authoring validator catches); runtime guard — distinguishes empty-table authoring error from F-SP-1 missing-row |
| `&"invariant_violation:branch_table_missing_outcome"` | F-SP-1 returns empty dict, or output missing `branch_key` / `is_draw_fallback` / `is_canonical_history` keys | Zero in ship (authoring validator enforces one-per-outcome row + F-SP-1 schema lock); runtime guard |
| `&"invariant_violation:is_draw_fallback_outcome_mismatch"` | F-SP-1 returns `is_draw_fallback: true` with `outcome != DRAW` (rev 1.3 systems B-2 cross-field enforcement) | Zero in ship (F-SP-1 authoring discipline); runtime guard enforces F-DB-4 invariant at assembly time |
| `&"invariant_violation:branch_key_type_invalid"` | F-SP-1 `branch_key` not a String | Zero in ship (F-SP-1 schema lock); defense-in-depth |
| `&"invariant_violation:is_draw_fallback_type_invalid"` | F-SP-1 `is_draw_fallback` value not a bool (rev 1.2 B-6) | Zero in ship (F-SP-1 schema lock); defense-in-depth against silent GDScript bool coercion |
| `&"invariant_violation:is_canonical_history_type_invalid"` | F-SP-1 `is_canonical_history` value not a bool (rev 1.2 B-6) | Zero in ship (F-SP-1 schema lock); defense-in-depth against silent GDScript bool coercion |
| `&"invariant_violation:outcome_unknown"` | `outcome` not ∈ {WIN, DRAW, LOSS} | Zero in ship (enum type-checked); defense-in-depth |
| `&"invariant_violation:cr13_echo_threshold_on_ch1"` | Ch1 chapter declares `echo_threshold` at runtime | Zero in ship (CR-13 build validator catches); belt-and-suspenders |

Extensibility rule: adding a new `invariant_violation:*` flag requires (a) appending to this table, (b) adding a per-flag GdUnit4 test fixture, (c) updating the `DestinyBranchChoice.invalid()` factory switch if one is used.

### F-DB-4. `DestinyBranchChoice` payload schema (ratified)

The authoritative **9-field** payload shape. **Replaces ADR-0001's 5-field provisional list per Evolution Rule #4** (minor amendment, not supersession). The 9th field `is_canonical_history: bool` was added to enforce Pillar 4 (演義 contrast) at the payload level — without it, Story Event #10 VS would need to maintain its own `(chapter_id, branch_key) → is_canonical_history` lookup as content authoring convention, with no payload-level safety net against mis-authoring.

```gdscript
class_name DestinyBranchChoice
extends Resource

@export var chapter_id: String = ""
@export var branch_key: String = ""
@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS
@export var echo_count: int = 0
@export var is_draw_fallback: bool = false
@export var is_canonical_history: bool = false
@export var reserved_color_treatment: bool = false
@export var is_invalid: bool = false
@export var invalid_reason: StringName = &""

static func invalid(reason: StringName) -> DestinyBranchChoice:
    var c := DestinyBranchChoice.new()
    c.is_invalid = true
    c.invalid_reason = reason
    return c
```

**Note (file layout)**: `DestinyBranchChoice` lives at `src/core/payloads/destiny_branch_choice.gd`. `DestinyBranchJudge` lives at `src/feature/destiny_branch/destiny_branch_judge.gd`. Neither script is marked `@tool` — payload Resources and pure-function judges do not need editor execution.

**BattleOutcome class_name constraint (rev 1.2 B-7).** `BattleOutcome` MUST be declared as a top-level `class_name BattleOutcome` in its own script file (owned by Grid Battle #1 MVP, path TBD at grid-battle v5.0 revision), NOT as an inner class of another script. Reason: the `@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS` default value on the `DestinyBranchChoice` Resource (F-DB-4 below) resolves at Resource script parse time via the Godot 4.6 global class registry. Inner-class references are not resolvable at parse time and would break `ResourceLoader.load()` for any saved `DestinyBranchChoice` — violating AC-DB-24. Flag this as a Bidirectional Update requirement on grid-battle v5.0 (see Section F).

**Field schema:**

| Field | Type | Range / Constraints | Source |
|---|---|---|---|
| `chapter_id` | String | Non-empty iff `is_invalid == false`; matches ScenarioRunner.current_chapter_id | `chapter.chapter_id` |
| `branch_key` | String | Non-empty iff `is_invalid == false`; member of `chapter.branch_table` keys | F-SP-1 output |
| `outcome` | `BattleOutcome.Result` (typed enum export) | ∈ {WIN=0, DRAW=1, LOSS=2} | Passthrough from `BattleOutcome.result` |
| `echo_count` | int | ≥ 0 (negatives clamped to 0 with `push_warning`; clamped value is what propagates to the payload) | ScenarioRunner state at BEAT_7_JUDGMENT entry |
| `is_draw_fallback` | bool | true iff F-SP-1 applied DRAW → WIN fallback per scenario-progression CR-14 | F-SP-1 output |
| `is_canonical_history` | bool | true iff the resolved branch upholds the canonical 演義 historical record for this chapter. Authored per branch-table row; passed through from F-SP-1 output. Pillar 4 enforcement. | F-SP-1 output (authored field) |
| `reserved_color_treatment` | bool | Per F-DB-2; always false when `is_invalid == true` OR `is_draw_fallback == true` | CR-DB-9 + F-DB-2 step 4a |
| `is_invalid` | bool | true iff invariant violation detected | CR-DB-10 |
| `invalid_reason` | StringName | ∈ F-DB-3 vocabulary iff `is_invalid == true`; `&""` otherwise. **StringName type preservation across `ResourceSaver.save()`/`ResourceLoader.load()` is expected per Godot @export semantics but remains UNVERIFIED on Android + Windows export targets** — see OQ-DB-6 (BLOCKING implementation-start gate). | CR-DB-10 |

**Payload invariants** (enforced by tests):
- `is_invalid == true` ⟹ downstream consumers MUST NOT read `chapter_id`, `branch_key`, `outcome`, `is_canonical_history` for content selection. Field values may be empty/default.
- `is_invalid == false` ⟺ `invalid_reason == &""`.
- `is_draw_fallback == true` ⟹ `outcome == DRAW`.
- `reserved_color_treatment == true` ⟹ `branch_key != chapter.default_branch_key` AND `is_invalid == false` AND `is_draw_fallback == false`.
- `is_canonical_history` is independent of `reserved_color_treatment` — a default branch may or may not align with canonical history (authored per chapter); a non-default branch likewise. Beat 8 contrast keys on `is_canonical_history`, not on `reserved_color_treatment`.

**Default-value sentinel note**: `invalid()` factory produces a payload with `outcome = LOSS` (enum default), `is_canonical_history = false`, and all narrative strings empty. Downstream MUST gate on `is_invalid == true` before reading any field — the LOSS default is convenience, not a signal. Consider treating this as an implementation-hygiene question for the VS gate: whether a dedicated `outcome = UNKNOWN = -1` sentinel would make violations of the gate contract more obvious at the reading site (flagged informally; no change required at MVP).

### Worked examples (6 rows cover all significant paths)

| # | Chapter fixture | outcome | echo_count | F-SP-1 returns | DestinyBranchChoice (fields) |
|---|---|---|---|---|---|
| E1 | Ch1 (`default="WIN_ch1_default"`, no echo_threshold) | WIN | 0 | `{branch_key:"WIN_ch1_default", is_draw_fallback:false, is_canonical_history:true}` | `chapter_id="ch1"; branch_key="WIN_ch1_default"; outcome=WIN; echo_count=0; is_draw_fallback=false; is_canonical_history=true; reserved_color_treatment=false; is_invalid=false; invalid_reason=&""` |
| E2 | Ch3 (`default="WIN_ch3_default"`, `author_draw_branch=true`, `echo_threshold=1`) | DRAW | 0 | `{branch_key:"DRAW_ch3_default", is_draw_fallback:false, is_canonical_history:false}` | `chapter_id="ch3"; branch_key="DRAW_ch3_default"; outcome=DRAW; echo_count=0; is_draw_fallback=false; is_canonical_history=false; reserved_color_treatment=true; is_invalid=false; invalid_reason=&""` |
| E3 | Ch3 (same as E2) | DRAW | 1 | `{branch_key:"DRAW_ch3_echo", is_draw_fallback:false, is_canonical_history:false}` (echo-gated) | `chapter_id="ch3"; branch_key="DRAW_ch3_echo"; outcome=DRAW; echo_count=1; is_draw_fallback=false; is_canonical_history=false; reserved_color_treatment=true; is_invalid=false; invalid_reason=&""` |
| E4 | Ch2 (`default="WIN_ch2_default"`, `author_draw_branch=false`) | DRAW | 0 | `{branch_key:"WIN_ch2_default", is_draw_fallback:true, is_canonical_history:true}` | `chapter_id="ch2"; branch_key="WIN_ch2_default"; outcome=DRAW; echo_count=0; is_draw_fallback=true; is_canonical_history=true; reserved_color_treatment=false; is_invalid=false; invalid_reason=&""` |
| E5 | (null) — invalid call | WIN | 0 | (not called; CR-DB-10 path) | `chapter_id=""; branch_key=""; outcome=LOSS; echo_count=0; is_draw_fallback=false; is_canonical_history=false; reserved_color_treatment=false; is_invalid=true; invalid_reason=&"invariant_violation:chapter_null"` |
| E6 | Ch1 (author error: has `echo_threshold=1`) | DRAW | 1 | (not called; CR-13 runtime trip) | `chapter_id=""; branch_key=""; outcome=LOSS; echo_count=0; is_draw_fallback=false; is_canonical_history=false; reserved_color_treatment=false; is_invalid=true; invalid_reason=&"invariant_violation:cr13_echo_threshold_on_ch1"` |

**Cross-reference check:**
- E1/E2/E3 align with scenario-progression's AC-SP-22 (F-SP-1 6-row example) — destiny-branch's assembly adds the 2 derived fields + 2 invalid fields around F-SP-1's core 3-field output.
- E3 demonstrates Pillar 2's observable differentiation (AC-SP-35): `branch_key` distinct from E2 at same outcome.
- E4 demonstrates CR-DB-9 correctness under F-SP-1 fallback (branch_key == default → reserved_color_treatment == false).
- E5/E6 demonstrate AC-SP-17 preservation (payload always emitted; `is_invalid` is the gate, not non-emission).

## Edge Cases

**EC-DB-1. Chapter resource null at `resolve()` call.**
- **If** `chapter == null`: return `DestinyBranchChoice.invalid(&"invariant_violation:chapter_null")`. ScenarioRunner emits the invalid payload. Downstream halts beat sequence with error dialog.

**EC-DB-2. Chapter missing `default_branch_key`.**
- **If** `chapter.default_branch_key == ""`: return `DestinyBranchChoice.invalid(&"invariant_violation:default_branch_key_missing")`. Authoring validator should have caught at build; runtime guard is defense-in-depth.

**EC-DB-3. Branch table missing outcome row.**
- **If** F-SP-1 returns empty / no match for `outcome` (e.g., `branch_table` has WIN+LOSS rows but DRAW outcome arrives on a chapter with `author_draw_branch=true` where writer forgot DRAW row): return `DestinyBranchChoice.invalid(&"invariant_violation:branch_table_missing_outcome")`. Authoring validator enforces one-row-per-outcome per scenario-progression CR-5; runtime guard.

**EC-DB-4. Unknown outcome enum value.**
- **If** `outcome` not ∈ {WIN=0, DRAW=1, LOSS=2} (corrupted payload, save-file tampering): return `DestinyBranchChoice.invalid(&"invariant_violation:outcome_unknown")`.

**EC-DB-5. Ch1 echo_threshold violation at runtime (CR-13).**
- **If** Ch1 chapter resource has `echo_threshold` set: return `DestinyBranchChoice.invalid(&"invariant_violation:cr13_echo_threshold_on_ch1")`. Build validator (scenario-progression CR-13) should reject; belt-and-suspenders runtime guard.

**EC-DB-6. Negative `echo_count`.**
- **If** `echo_count < 0` (impossible per F-SP-3 contract, but defense-in-depth): clamp to 0 with `push_warning`; continue execution. `is_invalid` stays `false`. The clamped value propagates to `DestinyBranchChoice.echo_count`.

**EC-DB-7. ScenarioRunner invokes judge outside BEAT_7_JUDGMENT.**
- **If** non-BEAT_7 code path calls `resolve()` (contract violation): judge itself is stateless and returns a valid `DestinyBranchChoice` for whatever inputs it receives — it cannot detect calling state. CR-DB-5 violation is detected at ScenarioRunner's state-machine guard. **Mitigation**: ScenarioRunner state-guard prevents the call; GdUnit4 state-fixture test asserts judge is not reachable from wrong state. Not a destiny-branch edge; escalated to scenario-progression's responsibility.

**EC-DB-8. Save restored mid-Beat-7 (between CP-2 and `destiny_branch_chosen` emission).**
- **If** crash or app-suspend happens between `save_checkpoint_requested` emission and `destiny_branch_chosen` emission: on resume, CP-2 snapshot restores ScenarioRunner to "just about to emit branch" state. Re-invokes judge. Re-execution is safe per CR-DB-11 (determinism): same inputs → same `DestinyBranchChoice` → same branch emitted. Player sees the witness-gate reveal again. **This is the intended behavior**; CP-2's purpose is to ensure branch re-computes identically on resume.

**EC-DB-9. `destiny_branch_chosen` subscriber freed mid-deferred-dispatch.**
- **If** Story Event #10 or other subscriber node freed between `CONNECT_DEFERRED` subscribe and emission-arrival idle frame: Godot's signal system handles freed-subscriber via `is_instance_valid` guards mandated by ADR-0001 §6. Dispatch is a no-op for freed subscribers. Not a destiny-branch bug — ADR-0001 lifecycle discipline covers it. **Mitigation**: cross-check via ADR-0001 V-4 test (cross-scene emit with freed subscriber).

**EC-DB-10. Two ScenarioRunners instantiated (testing scenario).**
- **If** test harness creates two ScenarioRunner instances, both reach BEAT_7_JUDGMENT, both call `DestinyBranchJudge.new()`: two independent judges, each produces its own `DestinyBranchChoice`. Judges are stateless, no interference. `destiny_branch_chosen` fires twice on GameBus — **violates CR-DB-7 (once per chapter)**. Mitigation is ScenarioRunner's responsibility; destiny-branch CANNOT detect this.

**EC-DB-11. `branch_key` collision between chapters (author bug).**
- **If** Ch2 `branch_table` has `"WIN_shared_default"` and Ch3 also uses `"WIN_shared_default"`: destiny-branch emits correctly with `chapter_id` + `branch_key` both populated. Downstream content lookup must key on the tuple `(chapter_id, branch_key)`, never on `branch_key` alone. **Mitigation**: authoring validator rejects non-namespaced branch_keys (enforce `{OUTCOME}_{chapter_id}_{variant}` naming per scenario-progression F-SP-1 examples).

**EC-DB-12. F-SP-1 output contains unexpected extra keys.**
- **If** a future F-SP-1 revision adds new fields (e.g., a telemetry field) beyond the 3 destiny-branch reads: destiny-branch's assembly uses specific key lookups (`f_sp_1["branch_key"]`, `f_sp_1["is_draw_fallback"]`) — extra keys are silently ignored. Forward-compatible. **Contract**: destiny-branch treats F-SP-1 output as read-only; never assumes fixed shape beyond the 3 documented fields. If F-SP-1 adds a *required* new output, scenario-progression revision triggers destiny-branch revision per Section F.

**EC-DB-13. `echo_count` extremely large (e.g., 10,000).**
- **If** echo_count is adversarially large: `resolve()` still O(1). F-SP-1's echo-gated rows use `echo_count >= threshold`, so any value ≥ threshold triggers the echo-gated branch. No numerical overflow (int range ~9.2×10^18). `DestinyBranchChoice.echo_count` carries the raw value through. No mitigation needed; noted for defensive-test completeness.

**EC-DB-14. Simultaneous battle_outcome_resolved + app-resume race.**
- **If** `battle_outcome_resolved` arrives at ScenarioRunner while scene is simultaneously loading from save: ScenarioRunner's state-machine guard rejects the signal if not in BEAT_5_BATTLE (scenario-progression AC-SP-14). Judge is not invoked. Not a destiny-branch edge; scenario-progression owns the guard.

**EC-DB-15. GameBus autoload freed between CP-2 emit and destiny_branch_chosen emit.**
- **If** `/root/GameBus` is freed during ScenarioRunner's exit-handler block (malformed test teardown or force-tree-manipulation): the direct `GameBus.destiny_branch_chosen.emit(choice)` call would crash on null-autoload access. Not a production scenario — GameBus is a singleton autoload. **Mitigation**: ScenarioRunner's exit-handler MUST wrap emission calls in `if is_instance_valid(GameBus): GameBus.destiny_branch_chosen.emit(choice)` per ADR-0001 §6 lifecycle discipline. Destiny-branch CANNOT detect this — owned by ScenarioRunner's emission site. EC-DB-9 covers subscriber-freed; this covers emitter-context-freed.

**EC-DB-16. F-SP-1 output fields missing or wrong-typed.**
- **If** F-SP-1 returns a Dictionary missing `branch_key`, `is_draw_fallback`, or `is_canonical_history` keys (e.g., test-double returns only partial shape): F-DB-1 step 3a guard catches missing keys and returns `invalid_reason:branch_table_missing_outcome` (single flag for any-key-missing; granularity by specific missing key is NOT exposed — an AC covering "only `is_canonical_history` missing" asserts the same `branch_table_missing_outcome` flag, see AC-DB-18).
- **If** `branch_key` value is non-String type: F-DB-1 step 3b guard catches and returns `invalid_reason:branch_key_type_invalid`.
- **If** `is_draw_fallback` value is non-bool type (e.g., null, int, String "false"): F-DB-1 step 3b guard catches and returns `invalid_reason:is_draw_fallback_type_invalid` (rev 1.2 fix — without this guard, GDScript silently coerces non-empty String "false" → true, causing step 4a fallback-override to misfire).
- **If** `is_canonical_history` value is non-bool type: F-DB-1 step 3b guard catches and returns `invalid_reason:is_canonical_history_type_invalid` (rev 1.2 fix — without this guard, GDScript silently coerces the value when assigning to the `@export var ... : bool` at step 5 line 196, corrupting Pillar 4 payload-level signal downstream).
- Extra keys are still silently ignored (EC-DB-12 forward-compatibility). Contract: required keys are hard-enforced with per-field type guards; optional keys are permissive.

**EC-DB-17. Concurrent resolve() from two RefCounted instances.**
- **If** the test harness or runtime instantiates two `DestinyBranchJudge` instances and invokes `resolve()` on both concurrently (WorkerThreadPool scenario, not production): both calls complete safely because the judge holds no class-level state, static variables, or shared resource references. Thread safety is guaranteed by construction (CR-DB-2 pure function + no class-level state). **Contract note**: future maintainers MUST NOT add `static var` to `DestinyBranchJudge` or its helpers — doing so silently breaks this guarantee. Flagged as a CI lint rule (grep `static var` in `destiny_branch_judge.gd` → fail if present).

**Cross-reference:**
- EC-DB-1..5 align with CR-DB-10 invalid-path contract.
- EC-DB-8 aligns with ADR-0003 Save/Load CP-2 purpose.
- EC-DB-9 aligns with ADR-0001 V-4 validation criterion (cross-scene emit with freed subscriber).
- EC-DB-10 and EC-DB-14 escalate to scenario-progression responsibility (documented for scope clarity, not destiny-branch bugs).

## Dependencies

### Upstream (this system depends on)

| Dependency | Tier | Hard / Soft | Interface | Change propagation risk |
|---|---|---|---|---|
| **Scenario Progression** (#6 MVP, v2.0 re-review pending) | MVP | **Hard** — this system cannot function without the F-SP-1 + F-SP-2 specs | Provides: F-SP-1 `resolve_branch` spec (CR-5, §D), F-SP-2 `is_echo_gate_open` predicate, `chapter` resource schema, `BattleOutcome` passthrough via ScenarioRunner state, `echo_count` from F-SP-3 | High — any F-SP-1 spec change forces destiny-branch assembly (F-DB-1) revision |
| **Grid Battle** (#1 MVP, v5.0 re-review pending) | MVP | **Hard** (indirect) | Provides: `BattleOutcome.result: Result {WIN, DRAW, LOSS}` — flows through ScenarioRunner into `resolve()`. destiny-branch does NOT subscribe to `battle_outcome_resolved` directly. | Medium — rename or semantic change to `BattleOutcome.Result` enum forces destiny-branch type updates |
| **ADR-0001 GameBus** | Accepted 2026-04-18 | **Hard** | Signal contract: `destiny_branch_chosen(DestinyBranchChoice)`; payload Resource pattern; `CONNECT_DEFERRED`; `ResourceSaver`/`ResourceLoader` round-trip (V-3) | Low — ADR is stable; this GDD triggers one minor amendment (see "Bidirectional updates" below) |

### Downstream (these systems depend on this one) — all PROVISIONAL

| Dependent | Tier | Hard / Soft | Interface | Note |
|---|---|---|---|---|
| **Destiny State** (#16 VS, Not Started) | VS | **Soft** (PROVISIONAL) | Subscribes to `destiny_branch_chosen`. Reads `echo_count` + `is_draw_fallback` for echo-archive maintenance. MUST gate content consumption on `is_invalid == false`. | If #16 VS chooses a different consumption pattern this GDD may need adjustment. |
| **Story Event** (#10 VS, Not Started) | VS | **Soft** (PROVISIONAL) | Subscribes to `destiny_branch_chosen`. Beat 8 revelation content keyed on `(chapter_id, branch_key)`. Differentiates tone by `is_draw_fallback` and echo-gated path. Halts beat sequence if `is_invalid == true`. | Beat 8 `BeatCue` payload shape is locked by #10 VS (PROVISIONAL in ADR-0001). |
| **Save/Load** (#17 VS, Not Started) | VS | **Soft** (PROVISIONAL) | Indirect — subscribes to `chapter_completed(ChapterResult)` emitted by ScenarioRunner at Beat 9. `ChapterResult.branch_triggered` is set from `DestinyBranchChoice.branch_key`. | CP-2 at Beat 7 exit precedes `destiny_branch_chosen` emission (AC-SP-17 ordering); CP-3 at Beat 9 captures the committed `branch_key`. |

### ADR dependencies

| ADR | Status | Relationship |
|---|---|---|
| **ADR-0001 GameBus autoload** | Accepted 2026-04-18 | Hard — signal contract + payload shape ratification |
| **ADR-0002 Scene Manager** | Accepted 2026-04-18 | Soft — destiny-branch's caller (ScenarioRunner) lives within scene lifecycle governed by ADR-0002 |
| **ADR-0003 Save/Load** | Accepted 2026-04-18 | Soft — CP-2/CP-3 timing anchors referenced by Section C Interactions |

### Bidirectional updates required in other GDDs/ADRs

This section triggers the following changes in other documents. Flagged for producer coordination:

| Document | Required change | Rationale | Priority |
|---|---|---|---|
| **ADR-0001 GameBus** (`docs/architecture/ADR-0001-gamebus-autoload.md`) | **Minor amendment** per Evolution Rule #4: replace `destiny_branch_chosen` PROVISIONAL shape (5 fields: `chapter_id, branch_key, revelation_cue_id, required_flags, authored`) with ratified **9-field** shape (per F-DB-4 in this GDD: `chapter_id, branch_key, outcome, echo_count, is_draw_fallback, is_canonical_history, reserved_color_treatment, is_invalid, invalid_reason`). Update §5 Destiny domain table row + provisional count 4→3. Append changelog line citing this GDD. | Ratifies the PROVISIONAL slot per ADR-0001 §Evolution Rule #4 — minor, not supersession. The 9th field `is_canonical_history` is added per narrative-director Issue 1 finding to enforce Pillar 4 at payload level. | **Required before destiny-branch implementation** |
| **Scenario Progression** (`design/gdd/scenario-progression.md`) §Interactions line 186-188 | Clarify wording "Destiny Branch owns the branch-table lookup logic (CR-5 formula implementation) and the DestinyBranchChoice payload authoring" → "Destiny Branch EXECUTES F-SP-1 inside DestinyBranchJudge (formula spec owned by scenario-progression §D); Destiny Branch GDD ratifies DestinyBranchChoice payload." Resolves tension T-1. | Current wording ambiguous; implementer may read as "destiny-branch reinvents F-SP-1." Registry note already reinforces execute-only ownership. | Next scenario-progression revision (v2.1 or later) |
| **Scenario Progression** F-SP-1 formula spec (§D) | Add `is_canonical_history: bool` to F-SP-1 output contract. Authored per branch-table row — each row in `chapter.branch_table` declares whether its outcome upholds the canonical 演義 historical record. F-SP-1's Dictionary output becomes `{branch_key, is_draw_fallback, is_canonical_history}` (3 required keys). Update F-SP-1 worked examples + AC-SP-22 accordingly. | Pillar 4 enforcement at payload level; prevents Story Event #10 from maintaining parallel content-layer lookup table (narrative-director Issue 1). | **Required before destiny-branch implementation** — coordinated ADR-0001 + scenario-progression revision |
| **Scenario Progression** Chapter authoring schema | Add `is_canonical_history: bool` field to each `branch_table` row in `assets/data/scenarios/{scenario_id}.json` chapter entries. Schema validator enforces presence per row. | Supports F-SP-1 output contract expansion. | Required for implementation story start |
| **Scenario Progression** AC-SP-18 | Add `is_invalid: bool` and `invalid_reason: StringName` to the required-field assertion list. Current list (6 fields) remains valid; 2 fields added. | Keeps AC-SP-18 consistent with this GDD's F-DB-4 payload. Non-breaking — test still passes with the 6-field assertion, just underspecified. | Next scenario-progression revision |
| **Scenario Progression** AC-SP-17 | Add a sentence: "The emitted `DestinyBranchChoice` MAY have `is_invalid == true` in error conditions; the exactly-one-emission contract still holds." | Documents that AC-SP-17's "exactly one" contract survives invalid-path handling. Non-breaking. | Next scenario-progression revision |
| **Destiny State GDD** (#16 VS, not yet authored) | On authoring: consume `destiny_branch_chosen.is_invalid` before reading content fields. Archive `echo_count` + `is_draw_fallback` + `is_canonical_history` in echo-storage metadata. | Enforces CR-DB-10 invalid-gating contract downstream. | Required for #16 VS design start |
| **Story Event GDD** (#10 VS, not yet authored) | On authoring: (1) consume `destiny_branch_chosen.is_invalid` before Beat 8 content lookup; (2) Beat 8 canonical-contrast text MUST key on `is_canonical_history` field (Pillar 4 enforcement at payload level — replaces content-layer lookup table); (3) **BLOCKING REGISTER CONSTRAINT (rev 1.3 narrative N-ND-3 — reframed from example-copy mandate to register constraint)** — for every chapter where `author_draw_branch=false`, fallback-DRAW Beat 8 text MUST be authored in the SAME solemn-witness register as non-fallback Beat 8 text; it MUST mark the stasis as a fact of the world but MUST NOT use explanatory or causal framing (no "because no clear victor emerged"-style exposition). WIN-default Beat 8 text reused verbatim on fallback-DRAW is REJECTED at #10 design review (actively damages Pillar 2). The example sentence "the canonical record stood because no clear victor emerged" is NOT a required copy — it was rev 1.1's illustrative example which narrative N-ND-3 correctly flagged as register-antithetical. Writer has full authoring license on specific phrasing within the register constraint; (4) differentiate Beat 8 tone for echo-gated DRAW (`echo_count >= threshold` AND `is_draw_fallback=false`) — at minimum one distinct text line acknowledging the cost (Section B "Marked Hand" register). | Items 2 and 3 are BLOCKING requirements for #10 VS design start (Pillar 2 + Pillar 4 protection). Item 4 is STRONGLY RECOMMENDED (Section B secondary register); rev 1.3 N-ND-4 flags it as sole-carrier of Marked Hand register — if #10 VS ships without echo-differentiation, Marked Hand disappears from the shipped game. | **BLOCKING for #10 VS design start** |
| **Save/Load GDD** (#17 VS, not yet authored) | On authoring: `ChapterResult.branch_triggered` populated from `DestinyBranchChoice.branch_key` at Beat 9. `ChapterResult` also carries `is_canonical_history` for save-slot summary UI. Do NOT persist `is_invalid == true` choices as committed branches (halt before CP-3). | Prevents corrupt save state from invalid runs; enables canonical-divergence summary display. | Required for #17 VS design start |
| **Story Event #10 VS + Destiny State #16 VS + Save/Load #17 VS — invalid-gate contract (rev 1.2 D1 BLOCKING)** | Every downstream consumer MUST check `is_invalid == false` before reading ANY of `outcome`, `chapter_id`, `branch_key`, `echo_count`, `is_draw_fallback`, `is_canonical_history`, `reserved_color_treatment`. The `invalid()` factory sets `outcome = BattleOutcome.Result.LOSS` as a GDScript enum default, which is a valid enum value — reading `outcome` before `is_invalid` will silently process a corrupt path as a genuine LOSS with no runtime error. This constraint replaces the weaker rev 1.1 "MUST gate content consumption on is_invalid" wording with a per-field enforceable contract. Each of the three VS GDDs MUST add at least one AC asserting "reading `outcome` before `is_invalid` check is a design-time defect" (concrete evidence: grep rule against `_on_destiny_branch_chosen` handler bodies to fail CI if any `choice.outcome` read appears before `if not choice.is_invalid:` guard). | Pillar 2 + Pillar 4 correctness under invalid-path emissions (AC-SP-17 preserves emission contract; this contract preserves content correctness downstream). Rev 1.2 game-designer BLOCK-2 + narrative-director BLOCK-1 convergence. | **BLOCKING for #10 VS + #16 VS + #17 VS design start** |
| **Grid Battle v5.0 GDD** (#1 MVP, in revision) | On v5.0 revision: declare `BattleOutcome` as a top-level `class_name BattleOutcome` in its own script file (not as inner class of any other script). Required because destiny-branch F-DB-4 `@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS` resolves via Godot 4.6 global class registry at Resource parse time; inner classes break `ResourceLoader.load()` silently. | AC-DB-24 serialization round-trip correctness. Rev 1.2 godot-gdscript B-7. | **BLOCKING for destiny-branch implementation** (same gate as ADR-0001 amendment) |
| **ADR-0001 minor amendment (rev 1.2 expansion)** | In addition to the rev 1.1 9-field payload ratification, the ADR amendment MUST include: (a) BattleOutcome top-level `class_name` requirement note; (b) invalid-path emission contract note ("is_invalid=true payloads are emitted; subscribers gate on is_invalid before reading content"); (c) cross-link to this GDD's F-DB-3 vocabulary (10 entries rev 1.2). | Rev 1.1 flagged the 9-field shape; rev 1.2 surfaces two additional contract details that belong in the ADR not buried in this GDD. | **Required before destiny-branch implementation** |
| **`is_canonical_history` authoring invariant (rev 1.2 narrative-director BLOCK-1 CARRYOVER, rev 1.3 narrative B-ND-1/B-ND-2 upgrade)** | scenario-progression v2.1 chapter-authoring schema validator (when adding the new `is_canonical_history: bool` per-row field per rev 1.1) MUST enforce: exactly one branch-table row per chapter has `is_canonical_history=true`, and that row's branch_key corresponds to the historical 演義 canonical outcome for that chapter. Author-time validation; violation fails the scenario build. Without this invariant, a writer-error can produce multiple "canonical" branches or zero canonical branches in a chapter — Beat 8 contrast (Story Event #10) becomes undefined. **Rev 1.3 runtime warning path added in destiny-branch F-DB-1 step 1b**: a zero-canonical or multi-canonical chapter triggers `push_warning` + telemetry flag (not is_invalid — ship proceeds), so authoring drift is observable during development even before scenario-progression v2.1 authoring-schema validator lands. | Closes the narrative-architectural gap surfaced by narrative-director BLOCK-1 (`is_canonical_history` authoring discipline relocated to scenario-progression) + rev 1.3 adds runtime safety net. | Required for scenario-progression v2.1 + Destiny State #16 VS + Story Event #10 VS correctness. Runtime warning in destiny-branch IS implemented MVP. |
| **scenario-progression §Interactions line 189 payload list (rev 1.3 systems B-3 + narrative B-ND-1 + ux B-UX-9-1 CONVERGED BLOCKING)** | scenario-progression.md §Interactions line 189 currently reads "`DestinyBranchChoice` minimum fields: `chapter_id: String`, `branch_key: String`, `outcome: Result`, `echo_count: int`, `is_draw_fallback: bool`, `reserved_color_treatment: bool`" — 6 fields. This lags rev 1.2's 9-field ratification + rev 1.3's 12-entry invalid-reason vocabulary. **Silent-incompatibility risk (not just doc lag)**: any authoring tool or integration validator built against the 6-field shape will silently omit `is_canonical_history` / `is_invalid` / `invalid_reason` on payload construction, collapsing Pillar 4 contrast to always-false and making `is_invalid=true` emissions indistinguishable from valid-path default-branch emissions. Must be updated to 9-field list co-merged with scenario-progression v2.1. **Implementation-story gate**: any Story Event #10 VS / Destiny State #16 VS / Save/Load #17 VS implementation story is BLOCKED from opening until scenario-progression §Interactions line 189 is synced in code, NOT just acknowledged in prose. | Scenario-progression v2.1 landing closes rev 1.1 T-1 + rev 1.2 Bidirectional rows + rev 1.3 convergence. | **BLOCKS #10 / #16 / #17 VS implementation-story open** |
| **scenario-progression UX.2 IP-006 Beat-7 carve-out acknowledgment (rev 1.3 ux B-UX-9-1)** | scenario-progression.md UX.2 (the Beat 7 panel spec) currently contains no explicit reference to IP-006's Beat-7 ceremonial carve-out. interaction-patterns.md IP-006 line 193 claims "Scenario Progression... applies the Beat-7 carve-out, not the default triad" but the scenario-progression doc itself carries no matching acknowledgment — an implementer reading sp.md UX.2 has no authoritative signal that the default R-1 triad (color + icon + text-prefix) does NOT apply at Beat 7 and must be substituted with color + audio (해금) + haptic. Scenario-progression v2.1 UX.2 revision MUST add a one-paragraph Beat-7 carve-out acknowledgment referencing IP-006 + destiny-branch UI-DB-5. | Closes the end-to-end UX compliance chain flagged at ux B-UX-9-1. Without this, carve-out is asserted in 2 of 3 docs; the doc that owns Beat 7 rendering is silent. | **BLOCKS VS implementation-story open** (paired with OQ-DB-11 closed; scenario-progression v2.1 required) |

### Pre-Implementation Gate Checklist (rev 1.3 new — consolidates all BLOCKING carryovers)

No destiny-branch implementation story opens until ALL of the following are verified merged to main:

- [ ] **ADR-0001 amendment landed** — 9-field payload ratification + BattleOutcome top-level class_name note + invalid-path emission contract + 12-entry F-DB-3 vocabulary (OQ-DB-1, OQ-DB-6 StringName verification for macOS canonical lane)
- [ ] **scenario-progression v2.1 §Interactions line 189 payload list synced** to 9-field shape (rev 1.3 BLOCKING convergence — silent incompatibility if skipped)
- [ ] **scenario-progression v2.1 F-SP-1 output contract includes `is_canonical_history: bool`** required key + chapter authoring schema adds `is_canonical_history: bool` per branch-table row + authoring-schema validator enforces exactly-one-canonical-per-chapter (rev 1.2 CARRYOVER + rev 1.3 runtime warning in destiny-branch as safety net)
- [ ] **scenario-progression v2.1 UX.2 adds Beat-7 carve-out acknowledgment** referencing IP-006 + destiny-branch UI-DB-5 (rev 1.3 ux B-UX-9-1)
- [ ] **Grid Battle v5.0 declares `class_name BattleOutcome` top-level** (not inner class) — required for F-DB-4 @export parse resolution; AC-DB-24 serialization depends on this (rev 1.2 B-7)
- [ ] **`reduce_haptics` 7th Intermediate toggle landed in accessibility-requirements.md §2 + §7** (rev 1.3 D1 decision — destiny-branch A-DB-2 + UI-DB-4 ACCEPTED GAP cite this toggle as the formal opt-out path)

No Vertical Slice implementation story opens until additionally:
- [ ] **OQ-DB-11 affordance-onset timing sync AC-DB-39 passes** (scenario-progression UX.2 150-200ms fade-in matches destiny-branch V-DB-5)
- [ ] **OQ-DB-12 Godot 4.6 haptic-preference engine-reference verification complete** (may resolve negative; if so, documented GDExtension wrapper path + A-DB-2 stays at in-game-Settings-only opt-out)
- [ ] **OQ-DB-13 scenario-progression error-dialog R-1..R-5 spec merged** (AC-DB-38 depends on concrete Intermediate-tier-testable criteria)
- [ ] **AC-DB-24 Android + Windows CI lanes pass** (OQ-DB-6 BLOCKING for VS close per rev 1.3 qa-lead B-1 lifecycle)

No MVP exit until:
- [ ] **First mobile playtest confirms Ch1-priming-null miss-rate ≤10% by Ch2 end** (OQ-DB-10 rev 1.3 D3 failure threshold) — if >10%, scenario-progression authoring constraint or Ch2 Beat 8 priming text required

### Circular-dependency check

None. destiny-branch consumes from scenario-progression (upstream) and provides to scenario-progression (downstream) — but the consumption is *spec* (F-SP-1 description) and the provision is *payload* (the emitted `DestinyBranchChoice`). Both live in scenario-progression's §D and §Interactions, but as distinct contract surfaces. No cycle.

### Engine/platform dependencies

- **Godot 4.6 / GDScript**: `RefCounted`, `Resource`, `StringName`, `@export`, `class_name` — all pre-4.2 stable.
- **GameBus autoload (ADR-0001)**: `/root/GameBus` must load before ScenarioRunner subscribes.
- **ResourceSaver/ResourceLoader**: must round-trip `DestinyBranchChoice` (ADR-0001 V-3).
- No shader, VFX, audio, input-system, or rendering dependencies.

## Tuning Knobs

destiny-branch is unusual: it's a judge/contract module with effectively **no tunables of its own**. The values that affect its behavior are authored upstream. This section documents the referenced knobs (pointer only, no duplication) and makes the "no destiny-branch knobs" stance explicit.

### Knobs destiny-branch REFERENCES (no duplication — scenario-progression is source of truth)

| Knob | Owned by | Source | Effect on destiny-branch | Safe range | Extreme behavior |
|---|---|---|---|---|---|
| `dwell_lockout_ms` | scenario-progression CR-10 | `design/gdd/scenario-progression.md` | Pre-tap hold before `DestinyBranchJudge.resolve()` is invoked (step 2–3 of Section C interaction sequence). Longer → more ceremonial; shorter → less impactful reveal. | [1000, 3000] ms (default 1500 per CR-10) | < 1000: violates Pillar 2 ceremonial-witness fantasy. > 3000: player tap-frustration risk. |
| `echo_threshold` (per-chapter) | scenario-progression TK-SP-1 | `design/gdd/scenario-progression.md` | Gates echo-gated branches. destiny-branch reads it indirectly via F-SP-1's F-SP-2 predicate call. Higher → harder to unlock Pillar 2 reversals. | [1, 3] per chapter; Ch1 rejects any value (CR-13) | `0`: collapses echo-gate rule (CR-6 violation). `>3`: unreachable within MVP 3–5 chapter lengths. |
| `branch_count_per_chapter` | scenario-progression TK-SP-2 | `design/gdd/scenario-progression.md` | Number of rows in `chapter.branch_table`. More rows → more distinct `branch_key` values destiny-branch may emit per chapter. | [2, 3] | `1`: collapses to linear (Pillar 2 violation). `>3`: blows MVP authoring budget at 5 chapters × 2–3 branches. |

### Knobs destiny-branch OWNS (rev 1.2 correction)

**One knob at MVP** (rev 1.2 — rev 1.1 incorrectly claimed "None at MVP"; V-DB-1 Layer 2 panel-wash opacity was already a tunable with a declared safe range).

| Knob | Symbol | Default | Safe range | Effect | Owner | Extreme behavior |
|---|---|---|---|---|---|---|
| **TK-DB-1 Beat 7 panel-wash opacity** | `beat_7_panel_wash_opacity` | `0.15` | `[0.10, 0.25]` (playtest-tuning band) | Perceptibility of V-DB-1 Layer 2 reserved-color panel wash against ink-wash Beat 7 panel base. Calibrated for mobile mid-brightness displays. | destiny-branch (art-director consulting) | Lower bound `< 0.10`: rev 1.3 measurable definition (systems R-2) — perceptibility failure defined as <80% of playtest participants identifying the reserved-color reveal within 5 seconds on the reference display (mobile mid-brightness ~300 nits) at default Beat 7 panel size. Upper bound `> 0.25`: measurable definition — panel-wash CanvasItem modulate alpha causes the wash to occlude Beat 7 panel branch-teaser text legibility below WCAG 2.1 AA 4.5:1 contrast ratio OR produces visible bleed into Beat 8's 금색 onset (measured via pre/post-frame histogram delta on the panel region). |

CI visual-regression test (UI-DB-5) asserts rendered opacity at peak hold is within the safe range until playtest locks the final value. If playtest converges on a value outside the band, art-director approval + safe-range amendment required. **Rev 1.3 note (systems R-2)**: the safe range is a pre-playtest estimate, not a verified range. Vignette-V-DB-1-Layer-1 (40% peak opacity) is the primary perceptibility vector; TK-DB-1's wash is secondary. If playtest data shows the Layer-1 vignette delivers sufficient R-1 signal alone, art-director may drop the wash entirely (set `beat_7_panel_wash_opacity = 0.0`, rejecting the [0.10, 0.25] lower bound) with a corresponding safe-range amendment.

The other "None at MVP" items remain:
- `reserved_color_treatment` derivation is a **rule** (CR-DB-9), not a tunable.
- `invalid_reason` vocabulary (F-DB-3) is a **contract**, not a tunable.
- `DestinyBranchChoice` **9-field** schema (F-DB-4) is a **contract**, not a tunable.
- Dwell-timer parameters are owned by scenario-progression (CR-10); reserved-color hex values are owned by art-director (art bible §4.1 lock).

If future revisions add additional tunables (e.g., a dev-mode toggle for "log F-SP-1 internal computation" or "always set reserved_color_treatment for debug"), they must be declared here and registered in `design/registry/entities.yaml` per project standards.

### Tuning governance notes

- **No circular tuning.** destiny-branch does not introduce knobs that feed back into scenario-progression or Grid Battle. Data flows one-way: scenario-progression specs in → destiny-branch executes → payload out.
- **No runtime-tunable knobs.** All upstream knobs (scenario-progression TK-SP-1, TK-SP-2, CR-10 dwell) are authored at scenario-build time. destiny-branch's determinism invariant (CR-DB-11) guarantees that tuning changes take effect only when the chapter resource is reloaded.
- **No per-difficulty variants.** Explicitly rejected at CR-DB-12 #4.
- **Implication for playtesting**: tuning destiny-branch's observable behavior is achieved by editing `assets/data/scenarios/{scenario_id}.json` chapter entries (scenario-progression's authored surface), not by editing any destiny-branch code or config.

## Visual/Audio Requirements

### V-DB-1. Beat 7 witness-gate entrance — reserved-color variant

Active when `reserved_color_treatment == true`. Art bible cross-reference: §4.1 reserved-color lock, §7.6 Phase 2 entrance spec, §8.3 state-transition table.

| Layer | Element | Color | Opacity | Timing |
|---|---|---|---|---|
| 1 | Edge vignette | 주홍 `#C0392B` | 0% → 40% | 0–600ms linear fade-in |
| 2 | Panel wash | 주홍 `#C0392B` | 0% → 15% | 400–1200ms (overlaps vignette tail) |
| — | Peak hold | — | — | 1200–1500ms |
| — | Tap-unlock | (scenario-progression input layer) | — | at 1500ms minimum |

**금색 `#D4A017` explicitly absent at Beat 7.** Reserved for Beat 8 역전 성공 (Story Event #10) per art bible §8.3 state-transition table. Using 금색 at Beat 7 would front-load the revelation and deplete Beat 8's payoff signal.

Panel-wash layer composites over the existing ink-wash Beat-7 panel; vignette composites over the scene frame.

**Perceptibility calibration note (R1 advisory, rev 1.2 declared as a formal Tuning Knob).** Layer 2 panel wash 주홍 at 15% opacity over the ink-wash panel base is a playtest-and-tune target, not a locked value. The 15% figure has not been validated for perceptibility on mobile mid-brightness displays. First mobile playtest MUST include a Beat 7 perceptibility pass; CI visual-regression test (UI-DB-5) accepts opacity within a 10%–25% tuning band until playtest locks the final value. If 15% fails perception, raise to 20–25%. If the layered vignette (40% peak) proves sufficient without the wash, drop the wash (requires art-director approval). **This value IS a destiny-branch-owned Tuning Knob (TK-DB-1 `beat_7_panel_wash_opacity`, default 0.15, range [0.10, 0.25]) — see Tuning Knobs section. Originally stated "None at MVP" was inaccurate per systems-designer R-2.**

**Flash-safety note (rev 1.2 REC-1 per ux + accessibility).** V-DB-1's Reduce Motion 0ms snap (40% vignette + panel-wash peak, 주홍 #C0392B on full-frame panel) presents one instantaneous saturated-red onset. This is NOT a "flash" per WCAG SC 2.3.1 three-per-second definition — a single onset at Beat 7 tap is well under the three-per-second threshold — but a saturated-red snap at 40%+ opacity on a panel covering a large viewport area is a photosensitive-epilepsy review consideration. A formal SC 2.3.1 photosensitive-safety audit is flagged for Pre-Production (see OQ-DB-[photosensitive] in Open Questions). Damage-calc rev 2.5's policy covers popup-scale elements only; Beat 7 is a full-frame moment and requires its own audit pass.

**Reduce Motion variant (R-3 compliant)** — WCAG 2.2 SC 2.2.1 + SC 2.3.3 + damage-calc rev 2.5 `max(baseline_hold, 1200ms)` policy citation.

When the player has Reduce Motion enabled (accessibility-requirements.md §2 toggle, or OS-level `prefers-reduced-motion`):

| Layer | Reduce Motion behavior |
|---|---|
| 1 Edge vignette | Snap to 40% opacity at 0ms (no 600ms fade); hold through dwell elapsed |
| 2 Panel wash | Snap to peak opacity at 0ms (no 800ms fade); hold through dwell elapsed |
| Peak hold | `max(baseline_hold, 1200ms)` — under standard 1500ms dwell, hold duration is unchanged (1500ms ≥ 1200ms floor). If dwell is tuned below 1200ms post-MVP, the floor prevails. |
| Tap-unlock | Unchanged — 1500ms minimum still applies (narrative gate; NOT overridden by Reduce Motion per accessibility-requirements.md R-3 explicit carve-out) |

Rationale: Reduce Motion suppresses animation onsets, not narrative timing. The dwell lockout is load-bearing for Ceremonial Witness (Section B) and must survive. The reserved-color signal is preserved at full visual strength — Reduce Motion players get the same chromatic information delivered without animation.

### V-DB-2. Beat 7 witness-gate default visual — non-reserved-color variant

Active when `reserved_color_treatment == false` (WIN-default, LOSS-default, or `is_draw_fallback == true`).

- Pure ink-wash panel. No reserved colors. No muted gold derivatives (art bible §4.1 절대 금지).
- Single motion differentiator: 먹선 (ink-line) weight increases `0.8px → 1.2px` linearly over the 1.5s dwell. Settles at 1.2px at peak.
- Art bible cross-reference: §8.3 motion vocabulary (평상시 → 결정적 transition).
- This is NOT a "weaker reveal" — it's the affirmative signal that nothing divergent happened, using ink-density rather than color. V-DB-2 is **deliberately low-signal**; implementers and playtesters should not attempt to boost the effect.

**Reduce Motion variant (R-3 compliant)**.

When Reduce Motion is enabled: **set 먹선 weight statically to 1.2px from Beat 7 onset; no onset animation** (rev 1.2 REC-3 wording clarification per accessibility-specialist — "snap at 0ms" could be misread as a fast transition; "static from onset" makes it unambiguous that there is no frame-one animation). Hold through dwell elapsed. The absence-of-divergence semantic is preserved; only the animation onset is suppressed.

**Default-branch accessibility fallback (addresses BLOCKING-3, rev 1.2 semantic upgrade per ux REC-3 + a11y REC-5)**. Under Reduce Motion + low audio (가야금 near-silent at −22 LUFS), V-DB-2's animation is snapped out and the audio channel is functionally absent for hard-of-hearing players. To prevent a zero-channel Beat 7 on default branches, scenario-progression subtitle channel MUST emit a Beat 7 subtitle entry on every Beat 7 tap event regardless of reserved-color variant. **The subtitle MUST encode divergence semantics, not just the instrument name** — describing "what is heard" (e.g., "가야금 울림") does not convey "the world did / did not diverge." Required localization keys (string-table authoring owned by Localization GDD #30; semantic contract owned by narrative-director):

| Variant | Loc key | Suggested ko-KR source | English gloss |
|---|---|---|---|
| Default branch (reserved_color_treatment=false) | `beat_7.subtitle.default` | 운명이 같은 길을 걸었다 (fate walked the same path) | "The path holds." |
| Reserved-color branch (reserved_color_treatment=true) | `beat_7.subtitle.reserved` | 운명이 다른 길로 갈라졌다 (fate diverged) | "The path turns." |
| DRAW fallback (is_draw_fallback=true) | `beat_7.subtitle.fallback` | 결판 없이 길은 이어졌다 (path continued without verdict) | "No verdict. The path continues." |

Ownership: scenario-progression §A.1 subtitle authoring (emits the strings) + narrative-director (final ko-KR copy) + Localization #30 (string-table registration). destiny-branch cross-references the semantic contract as a R-1 compliance dependency. Braille-display readability: ko-KR strings render via Korean braille tables — adequacy flagged for Intermediate tier verification (rev 1.3 corrected cross-ref: see **OQ-DB-17** accessibility gate, not OQ-DB-13 per a11y B-2 — OQ-DB-13 covers error-dialog a11y, NOT braille adequacy).

**Register note (rev 1.3 narrative N-ND-1)**: the ko-KR source phrasings above are declarative-expository ("fate walked the same path" / "fate diverged") and may not fully honor the solemn-liturgical-witness register Section B specifies ("관측되는 것이지 선택되는 것이 아니다"). The current strings are the rev 1.2 first-pass authoring; narrative-director may revise toward an observational or participial construction (e.g., "길은 흔들리지 않았다" — "the path did not waver" — for default; or similar for reserved / fallback) that places the player inside the moment of witnessing rather than narrating what happened. Final copy is narrative-director's authority; the loc-key semantic contract (divergence encoded) is the non-negotiable part.

### V-DB-3. `is_draw_fallback == true` Beat 7 treatment

Identical to V-DB-2. By F-DB-4 construction, `is_draw_fallback == true → reserved_color_treatment == false`. Downstream tone differentiation (distinguishing fallback DRAW from true default) is delegated to Story Event #10's Beat 8 content. CR-DB-8 forbids any Beat 7 visual signal that would leak fallback status.

### V-DB-4. `is_invalid == true` Beat 7 handoff

When `is_invalid == true`, destiny-branch renders nothing. No reserved-color treatment, no haptic pulse, no ink-density motion. Any Beat 7 audio cue (scenario-progression's 가야금 / 해금 per §Audio Requirements A.1) is also suppressed since BEAT_7_JUDGMENT does not properly enter. Visual and audio handling for the error path is delegated entirely to ScenarioRunner's error-dialog surface (scenario-progression's UI responsibility).

**Accessibility baseline requirement (addresses HIGH-3, rev 1.2 upgraded to enforceable per accessibility-specialist BLOCKING-A)**: ScenarioRunner's error-dialog (V-DB-4 delegation target) MUST meet accessibility-requirements.md R-1 through R-5 baseline — screen-reader label, keyboard dismissal, subtitle for any audio, haptic pulse on mobile, no motion-only signal. **Enforcement mechanism (rev 1.2)**: this requirement is promoted from prose-only "MUST" to testable gate via AC-DB-38 (new) + OQ-DB-13 BLOCKING (new, see Open Questions). The conditional "if scenario-progression's error-dialog spec does not yet codify this" hedge is removed — the gap IS formally flagged as BLOCKING VS-implementation-story regardless of scenario-progression's current state.

### V-DB-5. Tap-ready affordance at 1500ms (cross-GDD cross-reference)

At the 1500ms dwell-lockout exit, the player must receive a visible signal that tap input is now accepted (addresses BLOCK-UX-2 — flow-breaking confusion on input un-readiness). Ownership: **scenario-progression Beat 7 UI spec** (input-layer ownership per CR-DB-4). destiny-branch does NOT render the affordance — it cross-references as a blocking dependency.

Minimum spec suggested for scenario-progression: a single-frame cursor/prompt indicator pulse (mobile: subtle tap-target highlight; PC: cursor glyph transition), synchronous with the 1500ms tap-unlock moment. If scenario-progression v2.0 does not spec this, flag as OQ-DB-11 (blocking VS implementation story) + cross-reference in scenario-progression's next revision.

### A-DB-1. Beat 7 audio — reference to scenario-progression (authoritative source)

Beat 7 audio specification (instrument, LUFS, duration) is owned by **scenario-progression.md §Audio Requirements A.1 Per-Beat Audio Specifications** (table row for Beat 7). destiny-branch **references** but does not override:

| Parameter | Value | Source |
|---|---|---|
| Default variant instrument | 가야금 single stroke, near-silent | scenario-progression A.1 (line 696) |
| Non-default / echo-gated instrument | 해금 modal-shift phrase | scenario-progression A.1 |
| LUFS (default) | −22 LUFS | scenario-progression A.1 |
| LUFS (non-default / reversal) | −18 LUFS | scenario-progression A.1 |
| Duration | 2.0–3.5s non-looping | scenario-progression A.1 |
| True-peak ceiling | −1.0 dBTP | scenario-progression §Audio Requirements "All cues" note |
| Timing | Heard within 1.5s dwell lockout | scenario-progression A.1 + this GDD's V-DB-1/V-DB-2 timing |

destiny-branch owns NO audio cue of its own. The 해금 modal-shift for non-default branches satisfies the art bible §4.5 colorblind-compensation "전용 사운드" requirement through scenario-progression's authoring.

**Design note (rev 1.0 /consistency-check 2026-04-19)**: destiny-branch v1.0 initial draft proposed an additional temple-bell cue at −12 LUFS based on an art-director spawn that had not loaded scenario-progression's §Audio Requirements. /consistency-check surfaced the conflict; user directed deferral to scenario-progression's authoritative spec (`CONFLICT-1` resolved 2026-04-19). The ceremonial-witness fantasy (Section B) is still satisfied by 가야금 / 해금 at the specified LUFS — the Player Fantasy register phrase "temple-bell rather than fanfare" describes the FEEL, not a literal instrument.

### A-DB-2. Haptic / rumble pulse — reserved-color variant only (destiny-branch contribution)

Fires when `reserved_color_treatment == true`, synchronous with scenario-progression's 해금 cue onset. Platform-specific delivery:

**Mobile (iOS/Android)** — primary channel:
- Single low-intensity haptic pulse, duration ~50ms.
- **SHOULD check OS haptic preference where a platform API is available (rev 1.2 D4 downgrade).** Previous rev 1.1 wording ("MUST check OS haptic preference") cited `Input.get_haptic_feedback_enabled()` which does NOT exist in Godot 4.6 (accessibility-specialist BLOCKING-B). Verified Godot 4.6 haptic-query API is currently unknown; engine-reference verification pass is flagged as OQ-DB-12 (see Open Questions). Interim contract:
  - A-DB-2 fires unconditionally on `reserved_color_treatment == true` on mobile.
  - **Explicit user opt-out** is honored via in-game Settings `reduce_haptics` toggle (Settings/Options #28, elevated to Alpha per `design/accessibility-requirements.md` OQ-3 resolution). **Rev 1.3 (D1 decision per game-designer B-1 + ux B-UX-9-2 + a11y B-1 convergence)**: `reduce_haptics` is formally committed as the **7th Intermediate tier toggle** in `design/accessibility-requirements.md` §2 (rev 1.2 landed only the original six: text-scaling, subtitles, input-remapping, colorblind-modes, reduced-motion, high-contrast — haptic was unhoused). Settings/Options #28 implementation-story scope includes building the toggle surface for all 7 Intermediate toggles. When `reduce_haptics == true`, A-DB-2 is a no-op; triad degrades to visual + audio.
  - If OQ-DB-12 resolves with a verified Godot 4.6 platform API (or GDExtension wrapper) for OS-level haptic preference query, A-DB-2 is amended to honor OS-level opt-out in addition to the Settings toggle.
- Rationale: rev 1.1's hard "MUST" on an unverified API made A-DB-2 unimplementable. Downgrade to SHOULD + in-game Settings opt-out keeps the accessibility contract enforceable at MVP without hallucinating engine APIs.

**PC with gamepad connected** — substitute channel (addresses BLOCKING-1 PC triad gap):
- Controller rumble pulse 50ms, low-intensity, synchronous with 해금 cue. Uses Godot 4.6 `Input.start_joy_vibration(device_id, 0.0, 0.3, 0.05)` (weak motor only; strong motor reserved for combat/damage feedback per project audio convention).
- Fires on all connected gamepads; safe no-op if gamepad does not support rumble.
- Gracefully degrades on gamepad disconnect.

**PC keyboard/mouse only** — degraded channel:
- No tactile signal available. Triad collapses to 2 channels (visual vignette + 해금 audio). Acknowledged gap; see UI-DB-5 PC accessibility rationale.

**Default branch (`reserved_color_treatment == false`)**: no haptic/rumble on any platform. Scenario-progression's default 가야금 cue plays; no compensation needed since no reserved color reveal occurred.

**Accessibility channel role**: A-DB-2 is the "화면 진동 / tactile" channel of the art bible §4.5 colorblind-compensation triad (비네트 + 화면 진동 + 전용 사운드). Vignette V-DB-1 is visual; scenario-progression's 해금 is audio; A-DB-2 is tactile.

### A-DB-3. Audio scope boundary

destiny-branch owns **zero** audio cues. All Beat 7 audio is owned by scenario-progression §Audio Requirements A.1.

- Beat 7 default 가야금 + non-default 해금: scenario-progression
- Beat 8 revelation audio: Story Event #10 VS
- Beat 2 Prior-State Echo audio: scenario-progression §A.2 + Story Event #10 VS (per-chapter authoring)
- Grid Battle outcome audio (victory/defeat/DRAW sting): Grid Battle #1 MVP
- Scenario-level epilogue audio: scenario-progression

destiny-branch's only audio-adjacent contribution is A-DB-2 mobile haptic pulse (accessibility channel, reserved-color variant only). This is a tactile cue, not an audio cue.

### Asset-spec deliverables flag

destiny-branch-owned assets require `/asset-spec` output before production:
1. 주홍 `#C0392B` edge vignette texture (alpha-bleed shader or pre-baked radial PNG)
2. 주홍 `#C0392B` panel-wash texture (rectangular, matches scenario-progression Beat 7 panel dimensions)
3. Optional: ink-density motion parameters for V-DB-2 (shader uniform values; no texture needed if implemented via material parameter animation)

Beat 7 audio assets (가야금 default + 해금 non-default stems) are owned by scenario-progression §Audio Requirements A.1 and asset-spec'd through that GDD, not this one.

## UI Requirements

Destiny Branch's UI footprint is minimal — it contributes visual layers that composite over scenario-progression's Beat 7 panel, but does NOT own the panel, the text, the tap handler, or the state-machine transitions.

### UI-DB-1. Tap-unlock ownership

- ScenarioRunner owns the BEAT_7_JUDGMENT tap handler.
- Visual feedback for tap-ready state (cursor, prompt indicator) is owned by scenario-progression Beat 7 UI spec.
- destiny-branch has NO tap handler, no cursor change, no input ownership.

### UI-DB-2. Panel composition layer order

Layer order (bottom → top):
1. scenario-progression Beat 7 panel (background + branch teaser text + 가야금 default / 해금 non-default audio cue per scenario-progression §A.1)
2. V-DB-2 ink-density motion (applied to 먹선 rendering of the panel itself — material parameter)
3. V-DB-1 panel wash (composited over panel when `reserved_color_treatment == true`)
4. V-DB-1 edge vignette (composited over the scene frame, outside the panel)
5. A-DB-2 haptic pulse (non-visual — tactile layer on mobile, synchronous with scenario-progression's 해금 cue onset)

V-DB-2 is always active; V-DB-1 + A-DB-2 conditional on `reserved_color_treatment == true`. Beat 7 audio layer (scenario-progression-owned) is always active — 가야금 on default, 해금 on non-default.

### UI-DB-3. Mobile touch target

- Tap area: full-screen (owned by scenario-progression).
- No destiny-branch-specific touch targets.
- Dwell-lockout input blocking (1.5s) is enforced at the ScenarioRunner layer, not destiny-branch.

### UI-DB-4. Accessibility hooks

Reserved-color reveal requires non-color parallel channels per art bible §4.5 colorblind-compensation triad + accessibility-requirements.md R-1. Channel delivery:

- **Audio channel**: scenario-progression's 해금 modal-shift phrase (Beat 7 non-default variant per §A.1, −18 LUFS) — REQUIRED when `reserved_color_treatment == true`. Owned by scenario-progression, not destiny-branch. (Default 가야금 at −22 LUFS plays when `reserved_color_treatment == false`.)
- **Tactile channel**: Haptic pulse (A-DB-2) on mobile; gamepad rumble on PC-with-gamepad. No tactile on PC keyboard/mouse — acknowledged gap. OS haptic opt-out respected.
- **Motion channel**: Ink-density change (V-DB-2) is present in both variants; not itself a differentiator for reserved-color vs default.
- **Subtitle channel (cross-GDD)**: scenario-progression §A.1 subtitle entries for 가야금 and 해금 cues. See V-DB-2 Default-branch accessibility fallback for the R-1 subtitle requirement on every Beat 7 tap.

**Accessibility channel matrix** (addresses BLOCKING-1 gap analysis):

| Player condition | Visual vignette | Audio 해금 | Tactile haptic/rumble | Channels | Status |
|---|---|---|---|---|---|
| Full vision + hearing + mobile | ✓ | ✓ | ✓ haptic | 3 | COMPLIANT |
| Colorblind + hearing + mobile | PARTIAL (shape) | ✓ | ✓ haptic | 2+ effective | COMPLIANT |
| Colorblind + deaf + mobile | PARTIAL | ✗ | ✓ haptic | 1 unambiguous | MARGINAL — haptic anchors |
| Full vision + deaf + PC-gamepad | ✓ | ✗ | ✓ rumble | 2 | COMPLIANT |
| Full vision + deaf + PC-no-gamepad | ✓ | ✗ | ✗ | 1 | **ACCEPTED GAP** — see UI-DB-5 rationale |
| Colorblind + deaf + PC-gamepad | PARTIAL | ✗ | ✓ rumble | 1.5 effective | MARGINAL — rumble anchors |
| Colorblind + deaf + PC-no-gamepad | PARTIAL | ✗ | ✗ | 0–1 | **ACCEPTED GAP** — see UI-DB-5 rationale |
| Mobile with in-game Settings `reduce_haptics`=on | ✓ | ✓ | ✗ (Settings opt-out) | 2 | COMPLIANT — honors explicit in-game opt-out per A-DB-2 rev 1.2 |
| Mobile + deaf + colorblind + Settings `reduce_haptics`=on (rev 1.2 REC-1, rev 1.3 toggle-housing confirmed) | PARTIAL (shape) + SUBTITLE | ✗ | ✗ | 1–2 | **ACCEPTED GAP** — explicit user opt-out of haptic is respected even when it collapses the visual+audio+haptic triad; the V-DB-2 subtitle channel `beat_7.subtitle.reserved` carries the divergence semantic for this player population. Rev 1.3: `reduce_haptics` toggle formally committed as 7th Intermediate tier toggle in accessibility-requirements.md §2 (rev 1.3 D1 decision — rev 1.2 REC-1 note "documented in accessibility-requirements.md" is now accurate; prior to rev 1.3 the toggle was asserted here but not enumerated in a-req.md). |
| Reduce Motion ON + mobile (haptic enabled) | ✓ snapped (V-DB-1 RM variant, hue unchanged for colorblind) | ✓ | ✓ haptic | 2–3 | COMPLIANT — RM variant preserves chromatic signal; colorblind players receive no additional benefit from the snap itself (rev 1.2 game-designer REC-1 + a11y confirmation) |
| Reduce Motion ON + deaf + PC-no-gamepad (rev 1.2 ux BLOCK-UX-5) | ✓ snapped | ✗ | ✗ | 1 (shape only) | **ACCEPTED GAP** — same rationale as the Full vision + deaf + PC-no-gamepad row below; reversal trigger specified in UI-DB-5 |
| Cognitive accessibility / slow processing (any platform) — 1500ms dwell (rev 1.2 ux REC-4 + a11y NTH-3) | ✓ | ✓ | ✓ platform | 3 | **DEFERRED** — cognitive-load presets are Full Vision tier per accessibility-requirements.md §3; 1500ms dwell is a hard narrative gate at MVP (CR-DB-5 + scenario-progression CR-10), acknowledged as a trade-off between Ceremonial Witness fantasy and cognitive accessibility |

Screen-reader support is OUT OF SCOPE for MVP (accessibility-requirements.md §3 Screen-reader / AccessKit deferred to **Full Vision tier**, NOT Alpha). Deferred to OQ-DB-7. Pre-AccessKit, scenario-progression's 해금 at −18 LUFS serves as the de-facto non-visual signal for visually-impaired players at Intermediate tier. When AccessKit ships at Full Vision, destiny-branch will need a machine-readable `reserved_color_treatment` → `"beat_7.reserved_color.sr_label"` (localization key) → "운명이 다른 길을 갔다" / "History took a different path" label hook via scenario-progression's beat-text system.

### UI-DB-5. Platform variance, PC accessibility rationale & dark/light mode

- Reserved colors 주홍 + 금색 are fixed hex values per art bible lock. No light/dark mode variants.
- Panel-wash opacity target 15% with 10–25% playtest tuning band (R1 per V-DB-1 perceptibility note); CI visual-regression test asserts rendered opacity at peak hold is within band.
- Tactile channel: mobile haptic (A-DB-2) or PC-with-gamepad rumble. **PC keyboard/mouse-only players do NOT receive a tactile signal** — acknowledged accessibility gap for the deaf + colorblind + PC + no-gamepad combination.
- No other platform-specific UI divergence.

**PC accessibility degradation rationale (addresses BLOCKING-1, rev 1.2 rewrite per ux BLOCK-UX-5 + a11y confirmation)**. The deaf + colorblind + PC + no-gamepad combination receives a single partial channel (vignette shape without hue semantics). This is an accepted Intermediate-tier gap, justified by:
1. Gamepad support on PC is "Partial" (technical-preferences.md) — players who invest in accessibility-accommodating hardware can close the gap via rumble.
2. Adding a text-glyph or icon substitute would break Section B's "wordless pre-linguistic realization" Ceremonial Witness fantasy for ALL players to serve a narrow intersection, a trade-off rejected by creative-director framing. **However, see IP-006 Beat-7 carve-out (rev 1.2 D2 — design/ux/interaction-patterns.md): IP-006 generally mandates color + icon + text prefix as the redundancy triad for destiny reveals; Beat 7 destiny-branch is the documented exception, with color + audio (해금) + haptic/rumble substituting for icon + text. This preserves Pillar 2 wordlessness while keeping IP-006 compliance auditable.**
3. **(Rev 1.2 corrected)** Full Vision tier AccessKit will close the screen-reader gap for visually-impaired players by making V-DB-5 tap-ready affordance + the (rev 1.2) subtitle loc-keys `beat_7.subtitle.{default|reserved|fallback}` machine-readable. AccessKit does **NOT** provide a tactile or unambiguous visual substitute for deaf+colorblind+PC-no-gamepad players — that cell's reversal trigger is a separate Full Vision concern, not an AccessKit feature. **Reversal trigger for deaf+colorblind+PC-no-gamepad cell (rev 1.2 ux REC-5, rev 1.3 ux R-UX-9-4 correction)**: closes at Full Vision **ONLY via condition (a) — when a keyboard-rumble haptic device class (e.g., accessibility keyboards with tactile feedback) is supported by Godot 4.6+ input layer.** **Rev 1.3**: condition (b) ("on-screen non-color semantic indicator adopted project-wide that does NOT conflict with IP-006 Beat-7 carve-out") is formally marked a LOGICAL DEAD END per ux R-UX-9-4: any project-wide on-screen indicator necessarily appears at Beat 7 (a standard destiny-reveal moment), at which point it IS the icon+text-prefix pair the Beat-7 carve-out explicitly forbids. The two conditions are mutually exclusive. Future Full Vision scoping must NOT pursue (b) as a viable path. An alternative condition (c) is conceivable: a dedicated Beat-7-exempt out-of-band indicator (e.g., a bottom-screen semantic text strip outside the vignette panel) — but this requires creative-director approval that such an indicator does not erode Ceremonial Witness. (c) remains unspec'd; Full Vision scoping may elect to open it.

Escalated to art-director + accessibility-specialist for acknowledgment; logged in accessibility-requirements.md as a known Intermediate-tier gap closing at Full Vision.

**IP-006 cross-reference (rev 1.2 D2 carve-out)**: This GDD's V-DB-1..5 + A-DB-2 + UI-DB-1..5 constitutes the canonical implementation spec for interaction-patterns.md IP-006 "destiny reveal." **IP-006's general triad (color + icon + text prefix + animation cadence) is amended with a Beat-7-Destiny-Branch carve-out (rev 1.2)**: the Ceremonial Witness fantasy at Beat 7 substitutes audio (해금) + haptic/rumble in place of the icon + text-prefix pair, keeping total redundancy at 3+ channels while preserving wordlessness. The carve-out is authored directly in `design/ux/interaction-patterns.md` IP-006 body (not just cross-referenced from here) — see that file for the amended pattern text. Other destiny-reveal contexts (save-slot summary, epilogue header, scenario-select flags) still apply the full IP-006 triad; only Beat 7 within Destiny Branch uses the carve-out.

### UX flag

> **UX Flag — Destiny Branch (blocking VS implementation)**: This system has minor UI requirements that composite over scenario-progression's Beat 7 panel. In Phase 4 (Pre-Production), run `/ux-design` targeting `design/ux/beat-7.md` for the Beat 7 witness gate (primary ownership: scenario-progression; contributing specs: this GDD's V-DB-1..5 + A-DB-1..3 + UI-DB-1..5). The Beat 7 UX spec MUST address OQ-DB-11 (tap-ready affordance). Stories that reference Beat 7 UI should cite `design/ux/beat-7.md` once authored, not this GDD directly. Cross-cites scenario-progression's Beat 7 UX flag (which owns the primary panel + tap handler surface).

## Acceptance Criteria

**43 ACs across 8 buckets** (rev 1.3 rollup: rev 1.1 37 + rev 1.2 AC-DB-20d/20e/38 + rev 1.3 AC-DB-20f/20g/39). Each is GIVEN-WHEN-THEN format, independently verifiable by a QA tester without reading this GDD.

### Bucket 1 — Formula correctness (F-DB-1 worked examples E1–E6)

**AC-DB-01** (E1 Ch1 WIN default). **GIVEN** a Ch1 chapter fixture with `chapter_id="ch1"`, `default_branch_key="WIN_ch1_default"`, no `echo_threshold`, and a valid `branch_table`, **WHEN** `DestinyBranchJudge.new().resolve(chapter, WIN, 0)` is called, **THEN** the returned `DestinyBranchChoice` has `chapter_id="ch1"`, `branch_key="WIN_ch1_default"`, `outcome=WIN`, `echo_count=0`, `is_draw_fallback=false`, `reserved_color_treatment=false`, `is_invalid=false`, `invalid_reason=&""`.
- **Evidence**: GdUnit4 unit test in `tests/unit/destiny_branch/` asserting all **9 field values**.

**AC-DB-02** (E2 Ch3 DRAW default). **GIVEN** a Ch3 chapter fixture with `author_draw_branch=true`, `echo_threshold=1`, `default_branch_key="WIN_ch3_default"`, and a DRAW branch row `"DRAW_ch3_default"`, **WHEN** `resolve(chapter, DRAW, 0)` is called, **THEN** the returned `DestinyBranchChoice` has `branch_key="DRAW_ch3_default"`, `is_draw_fallback=false`, `reserved_color_treatment=true`, `is_invalid=false`.
- **Evidence**: GdUnit4 unit test.

**AC-DB-03** (E3 Ch3 DRAW echo-gated — Pillar 2 observable). **GIVEN** the same Ch3 fixture as AC-DB-02, **WHEN** `resolve(chapter, DRAW, 1)` is called, **THEN** the returned `DestinyBranchChoice.branch_key == "DRAW_ch3_echo"` — DISTINCT from AC-DB-02's `"DRAW_ch3_default"` branch_key. Additionally `reserved_color_treatment=true`, `is_invalid=false`.
- **Evidence**: GdUnit4 unit test asserting the echo=0 and echo=1 outputs produce different `branch_key` values from the same chapter fixture.

**AC-DB-04** (E4 Ch2 DRAW fallback). **GIVEN** a Ch2 chapter fixture with `author_draw_branch=false`, `default_branch_key="WIN_ch2_default"`, **WHEN** `resolve(chapter, DRAW, 0)` is called, **THEN** the returned `DestinyBranchChoice` has `branch_key="WIN_ch2_default"`, `is_draw_fallback=true`, `reserved_color_treatment=false`, `outcome=DRAW`, `is_invalid=false`.
- **Evidence**: GdUnit4 unit test.

**AC-DB-05** (E5 null chapter). **GIVEN** `chapter=null`, **WHEN** `resolve(null, WIN, 0)` is called, **THEN** the returned `DestinyBranchChoice` has `is_invalid=true`, `invalid_reason=&"invariant_violation:chapter_null"`, `reserved_color_treatment=false`, all narrative fields (chapter_id, branch_key) at default empty values.
- **Evidence**: GdUnit4 unit test + `push_error` log capture.

**AC-DB-06** (E6 CR-13 runtime violation). **GIVEN** a Ch1 chapter fixture that has `echo_threshold=1` set (authoring-validator bug), **WHEN** `resolve(chapter, DRAW, 1)` is called, **THEN** the returned `DestinyBranchChoice` has `is_invalid=true`, `invalid_reason=&"invariant_violation:cr13_echo_threshold_on_ch1"`.
- **Evidence**: GdUnit4 unit test with fixture exhibiting the CR-13 violation.

### Bucket 2 — Core Rule invariants (CR-DB-2/3/4/5/6/7/8/9/11)

**AC-DB-07** (CR-DB-2 + CR-DB-11 determinism). **GIVEN** a valid `ChapterResource` fixture and identical `(outcome, echo_count)` inputs, **WHEN** `resolve()` is called twice (once on a first `DestinyBranchJudge` instance, once on a second independently-constructed instance), **THEN** the two returned `DestinyBranchChoice` objects are field-equal across all **9 `@export` fields**. Additionally, the judge source must contain no `Time.get_ticks_msec`, `Time.get_ticks_usec`, `randi`, `randf`, `randf_range`, `randi_range`, or `/root/*` autoload state-read patterns.
- **Evidence**: GdUnit4 unit test calling resolve twice + CI grep lint step in `.github/workflows/tests.yml` matching the forbidden-API regex against `src/feature/destiny_branch/destiny_branch_judge.gd`; returns non-zero exit code if any forbidden pattern is found. **Rev 1.3 forbidden-pattern list expansion per godot-gdscript R-4 + systems R-1**: `Time.get_ticks_msec`, `Time.get_ticks_usec`, `Time.get_unix_time_from_system`, `Time.get_datetime_dict_from_system`, `Time.get_datetime_string_from_system`, `OS.get_ticks_msec`, `OS.get_datetime_dict_from_system`, `OS.get_processor_count`, `randi`, `randf`, `randf_range`, `randi_range`, `RandomNumberGenerator` (any instance method), `Engine.get_process_frames`, `Engine.get_physics_frames`, `DisplayServer.window_` (any method — viewport-dependent), `ClassDB.get_class_list`, `/root/*` autoload state-read patterns. Lint infrastructure (grep-based GitHub Actions step) is an implementation-story prerequisite. **[ADVISORY until lint-step-PR merged. Owner: DevOps. Gate: MVP implementation-story open. Promotion: BLOCKING when `.github/workflows/tests.yml` contains a job named `destiny-branch-determinism-lint` that greps this pattern list and exits non-zero on any hit. MVP implementation story DOES NOT close without the lint job merged.]**

**AC-DB-08** (CR-DB-3 transient lifecycle). **GIVEN** a local-scope variable `var judge := DestinyBranchJudge.new()` and a `WeakRef` to it, **WHEN** `judge.resolve(...)` is called and the local variable goes out of scope, **THEN** the `WeakRef.get_ref()` returns `null` on the next idle frame (no lingering reference from a signal connection, callable binding, or autoload).
- **Evidence**: GdUnit4 unit test using `weakref()` + `await get_tree().process_frame`.

**AC-DB-09** (CR-DB-4 judge emits nothing, rev 1.3 committed to single API per qa-lead B-2). **GIVEN** a GdUnit4 test extending `GdUnitTestSuite` with `monitor_signals(GameBus, false)` registered on the autoload instance (passed as the GDScript symbol `GameBus`, NOT the NodePath `/root/GameBus` — gdscript R-3) BEFORE judge construction, **WHEN** `DestinyBranchJudge.new().resolve(chapter, outcome, echo_count)` is called in isolation (no ScenarioRunner present), **THEN** `assert_signal_not_emitted(GameBus, "destiny_branch_chosen")` passes. Rev 1.3: timeout-probe fallback REMOVED — `await_signal_on(..., 100)` is NOT equivalent proof (slow runner or late emission produces false-pass). GdUnit4 version pin is an implementation-story prerequisite; if installed version does not expose `monitor_signals`, the implementation story opens a blocker against the GdUnit4 install task, not a fallback assertion path.
- **Evidence**: GdUnit4 integration test using `monitor_signals(GameBus, false)` + `assert_signal_not_emitted(GameBus, "destiny_branch_chosen")`. **[Implementation-story prerequisite: verify `monitor_signals` + `assert_signal_not_emitted` methods exist at `addons/gdUnit4/src/core/GdUnitTestSuite.gd` after GdUnit4 is installed. Owner: DevOps (GdUnit4 install task). Gate: MVP implementation-story open. Promotion: BLOCKING from MVP open — no ADVISORY path.]**

**AC-DB-10** (CR-DB-5 one eval per chapter, guarded by ScenarioRunner). **GIVEN** a ScenarioRunner instance in a state other than BEAT_7_JUDGMENT (e.g., BEAT_5_BATTLE), **WHEN** test code attempts to invoke the Beat-7-exit code path that would call `DestinyBranchJudge.new()`, **THEN** ScenarioRunner's state-machine guard rejects the call and no `DestinyBranchJudge` instance is constructed.
- **Evidence**: GdUnit4 state-fixture test injecting ScenarioRunner into non-BEAT_7 state.

**AC-DB-11** (CR-DB-6 no intermediate state observable, rev 1.2 rewrite per qa-lead BLOCK-2). **GIVEN** a GdUnit4 test extending `GdUnitTestSuite` that calls `monitor_signals(GameBus, false)` ONCE before the judge call (GdUnit4 4.x `monitor_signals` monitors ALL signals emitted by the target object; no per-signal registration needed), **WHEN** `judge.resolve(chapter, outcome, echo_count)` is called, **THEN** between the `new()` call and the return of `resolve()` the test asserts `assert_signal_not_emitted(GameBus, signal_name)` for each name in the explicit signal set {`destiny_branch_chosen`, `save_checkpoint_requested`, `chapter_completed`, `battle_outcome_resolved`, `scene_transition_requested`, `scene_transition_failed`, `save_persisted`, `save_load_failed`, `tile_destroyed`, `beat_visual_cue_fired`, `beat_audio_cue_fired`}, AND a snapshot of all public GameBus autoload properties (enumerated via `get_property_list()` filtered to `PROPERTY_USAGE_SCRIPT_VARIABLE`) shows field-equal values before and after the call. Signal set MUST be kept synchronized with ADR-0001's signal registry via an **executable CI grep lint** (not a process promise): `.github/workflows/tests.yml` runs a step that counts `assert_signal_not_emitted` calls in this test file and asserts the count is ≥ ADR-0001 non-PROVISIONAL signal count; mismatch fails the build.
- **Evidence**: GdUnit4 integration test + `get_property_list()` snapshot + CI grep lint step committed to `.github/workflows/tests.yml` alongside the test file. **[Implementation-story prerequisite: `.github/workflows/tests.yml` job `destiny-branch-no-intermediate-state-lint` counts `assert_signal_not_emitted` calls in this test file and fails build if count < ADR-0001 non-PROVISIONAL signal count. Owner: DevOps. Gate: MVP implementation-story open. Promotion: BLOCKING from MVP open (no ADVISORY path — rev 1.3 qa-lead B-1). MVP implementation story DOES NOT close without the lint job merged.]**

**AC-DB-12** (CR-DB-7 signal fires exactly once per chapter via ScenarioRunner). **GIVEN** a ScenarioRunner with a scripted Beat 7 sequence (construct → dwell-timer-elapsed → tap-event → exit-handler), **WHEN** the full Beat 7 exit sequence runs, **THEN** the signal collector records exactly one `destiny_branch_chosen` emission AND exactly one preceding `save_checkpoint_requested` emission in emit-statement order. A subsequent second call to the same exit-handler in the same test frame produces zero additional emissions. **Note**: assertion tests emit-statement order (deterministic by CR-DB-4 code sequence), NOT subscriber-receive order (which is deferred per CONNECT_DEFERRED).
- **Evidence**: GdUnit4 integration test using `GdUnitSignalCollector` per-signal emit-count query (verify exact method name against installed GdUnit4 version: `get_signal_emit_count()` or `get_value_count()` — method must exist and return a non-negative int matching emission count). Use `await_signal_on(GameBus, "destiny_branch_chosen", [choice], 100)` as the canonical assertion pattern if the direct count method differs across GdUnit4 versions.

**AC-DB-13** (CR-DB-8 no branch structural leak). **GIVEN** a chapter fixture with a `branch_table` containing 3 rows (default + 2 alternates), **WHEN** `resolve()` is called and the returned `DestinyBranchChoice` is inspected, **THEN** the payload contains NO field whose name or value reveals the count (3), the alternate branch_keys, or any condition from un-taken rows. The **9 locked fields** (F-DB-4) are the full output surface; field-name allowlist = exactly `{chapter_id, branch_key, outcome, echo_count, is_draw_fallback, is_canonical_history, reserved_color_treatment, is_invalid, invalid_reason}`.
- **Evidence**: GdUnit4 unit test inspecting field list via reflection + **allowlist equality assertion** (field names enumerated from `get_property_list()` filtered to `PROPERTY_USAGE_SCRIPT_VARIABLE` must equal the 9-name set above; any extra or missing name fails). Stricter than regex exclusion per godot-gdscript N-1.

**AC-DB-14** (CR-DB-9 reserved_color_treatment derivation — positive case, rev 1.2 explicit GIVEN-WHEN-THEN per qa-lead REC-1). **GIVEN** a `TestDestinyBranchJudgeWithSp1Stub` + a chapter fixture with `default_branch_key="WIN_ch3_default"` and stub configured `set_sp1_output({"branch_key": "DRAW_ch3_echo", "is_draw_fallback": false, "is_canonical_history": false})`, **WHEN** `resolve(chapter, DRAW, 1)` is called, **THEN** `DestinyBranchChoice.reserved_color_treatment == true` AND `DestinyBranchChoice.is_invalid == false`.
- **Evidence**: GdUnit4 unit test; independently verifiable without reading AC-DB-03. Parameterized over {Ch1..Ch5 default_branch_key fixtures} × {stubbed non-default branch_key}.

**AC-DB-15** (CR-DB-9 + F-DB-2 — negative case when branch == default, rev 1.2 explicit GIVEN-WHEN-THEN). **GIVEN** a `TestDestinyBranchJudgeWithSp1Stub` + a chapter fixture with `default_branch_key="WIN_ch2_default"` and stub configured `set_sp1_output({"branch_key": "WIN_ch2_default", "is_draw_fallback": false, "is_canonical_history": true})` (branch_key equals default), **WHEN** `resolve(chapter, WIN, 0)` is called, **THEN** `DestinyBranchChoice.reserved_color_treatment == false`. Parameterized second row: stub `set_sp1_output({"branch_key": "WIN_ch2_default", "is_draw_fallback": true, "is_canonical_history": true})` with `resolve(chapter, DRAW, 0)` → same expected result (F-DB-2 step 4a fallback override).
- **Evidence**: GdUnit4 parameterized unit test; independently verifiable without reading AC-DB-01 or AC-DB-04.

### Bucket 3 — Invalid-path vocabulary (12 separate ACs — rev 1.2: +20d, +20e; rev 1.3: +20f branch_table_empty, +20g is_draw_fallback_outcome_mismatch)

**AC-DB-16**. **GIVEN** `chapter=null`, **WHEN** `resolve(null, WIN, 0)` is called, **THEN** the returned payload has `is_invalid=true` AND `invalid_reason == &"invariant_violation:chapter_null"`.
- **Evidence**: GdUnit4 unit test (also covered by AC-DB-05; restated here as vocabulary-flag AC).

**AC-DB-17**. **GIVEN** a chapter fixture with `default_branch_key=""`, **WHEN** `resolve(chapter, WIN, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:default_branch_key_missing"`.
- **Evidence**: GdUnit4 unit test.

**AC-DB-18**. **GIVEN** a chapter fixture whose `branch_table` is missing a row for the supplied outcome, **WHEN** `resolve(chapter, outcome, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:branch_table_missing_outcome"`.
- **Evidence**: GdUnit4 unit test.

**AC-DB-19**. **GIVEN** an `outcome` integer value not ∈ {0, 1, 2}, **WHEN** `resolve(chapter, outcome, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:outcome_unknown"`.
- **Evidence**: GdUnit4 unit test.

**AC-DB-20** (rev 1.3 helper committed to stdout-redirect per D2 decision). **GIVEN** a Ch1 chapter fixture with `echo_threshold` set, **WHEN** `resolve(chapter, DRAW, 1)` is called, **THEN** `invalid_reason == &"invariant_violation:cr13_echo_threshold_on_ch1"` AND `push_error` is emitted with a message containing the literal substring `"cr13_echo_threshold_on_ch1"` (per F-DB-1 line 166 — not ScenarioRunner-scope; the judge itself push_errors).
- **Evidence**: GdUnit4 unit test + `tests/helpers/error_log_capture.gd` helper. **Helper implementation LOCKED per rev 1.3 D2 decision**: **Option (a) Godot stdout/stderr redirect + grep captured buffer**. API contract: `ErrorLogCapture.begin() -> void` captures the current stdout/stderr streams via `OS.read_string_from_stdio()` / OS redirection pattern; `ErrorLogCapture.end() -> Array[String]` stops capture + returns line-split captured output; `ErrorLogCapture.assert_error_contains(substring: String) -> bool` runs `end()` + returns true iff any captured line contains `substring`. Headless CI (macOS Metal canonical lane) is the reference target; platform-specific line-ending normalization (`\r\n` → `\n`) is the helper's responsibility. GDExtension log-hook and GdUnit4 built-in options explicitly REJECTED at rev 1.3. Helper scaffolding is an implementation-story prerequisite. The fixture is constructed via `MockChapterResource.with_ch1_echo_violation()` helper which bypasses the authoring validator to simulate the build-validator escape scenario (helper is also an implementation-story prerequisite; see Bucket 6 AC-DB-29). **[Implementation-story prerequisite: `tests/helpers/error_log_capture.gd` scaffolded with stdout-redirect implementation. Owner: Test Infrastructure (implementation-story-0). Gate: MVP implementation-story open. Promotion: BLOCKING from MVP open — no ADVISORY path.]**

**AC-DB-20a** (new guard — chapter_id empty). **GIVEN** a chapter fixture with `chapter_id=""`, **WHEN** `resolve(chapter, WIN, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:chapter_id_missing"`.
- **Evidence**: GdUnit4 unit test.

**AC-DB-20b** (new guard — branch_table null/malformed). **GIVEN** a chapter fixture with `branch_table = null` (or non-Dictionary type), **WHEN** `resolve(chapter, WIN, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:branch_table_null_or_malformed"` AND the call does NOT crash into `_apply_f_sp_1` with a null-deref.
- **Evidence**: GdUnit4 unit test with two fixtures (null, non-Dictionary).

**AC-DB-20c** (new guard — branch_key non-String type, rev 1.2 test-seam upgrade per qa-lead BLOCK-3 + D3 decision). **GIVEN** a `TestDestinyBranchJudgeWithSp1Stub` instance (see F-DB-1 test-seam contract) configured with `set_sp1_output({"branch_key": 42, "is_draw_fallback": false, "is_canonical_history": true})`, **WHEN** `resolve(valid_chapter, WIN, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:branch_key_type_invalid"`.
- **Evidence**: GdUnit4 unit test using `TestDestinyBranchJudgeWithSp1Stub` (virtual `_apply_f_sp_1` override subclass; `tests/helpers/destiny_branch_judge_stub.gd`). `_apply_f_sp_1` is declared **virtual** on `DestinyBranchJudge` per F-DB-1 test-seam contract — no monkey-patching required. Follows damage-calc rev 2.6 bypass-seam precedent (AC-DC-21/28/51).

**AC-DB-20d** (new rev 1.2 — `is_draw_fallback` non-bool type). **GIVEN** a `TestDestinyBranchJudgeWithSp1Stub` configured with `set_sp1_output({"branch_key": "valid_key", "is_draw_fallback": "false", "is_canonical_history": true})` (String "false" instead of bool false), **WHEN** `resolve(valid_chapter, DRAW, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:is_draw_fallback_type_invalid"`. Parameterized with {null, 0, 1, "false", "true", []} × {valid_chapter fixtures} — any non-bool value triggers the guard.
- **Evidence**: GdUnit4 parameterized unit test; covers the silent-coercion failure mode surfaced by systems-designer B-3 + godot-gdscript B-6.

**AC-DB-20e** (new rev 1.2 — `is_canonical_history` non-bool type). **GIVEN** a `TestDestinyBranchJudgeWithSp1Stub` configured with `set_sp1_output({"branch_key": "valid_key", "is_draw_fallback": false, "is_canonical_history": "true"})` (String "true" instead of bool true), **WHEN** `resolve(valid_chapter, WIN, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:is_canonical_history_type_invalid"`. Parameterized matrix same as AC-DB-20d.
- **Evidence**: GdUnit4 parameterized unit test; covers Pillar 4 payload-level silent-coercion failure mode (game-designer BLOCK-1).

**AC-DB-20f** (new rev 1.3 — empty-Dictionary branch_table per systems B-1). **GIVEN** a chapter fixture with `branch_table = {}` (empty Dictionary, passes null + Dictionary-type checks at F-DB-1 step 1), **WHEN** `resolve(chapter, WIN, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:branch_table_empty"` AND the call does NOT reach `_apply_f_sp_1`. This distinguishes the empty-table authoring error from the F-SP-1-missing-row path covered by AC-DB-18.
- **Evidence**: GdUnit4 unit test with one fixture (empty-Dictionary branch_table, otherwise-valid chapter).

**AC-DB-20g** (new rev 1.3 — `is_draw_fallback` + outcome mismatch per systems B-2). **GIVEN** a `TestDestinyBranchJudgeWithSp1Stub` configured with `set_sp1_output({"branch_key": "valid_key", "is_draw_fallback": true, "is_canonical_history": true})` AND a parameterized outcome ∈ {WIN, LOSS} (NOT DRAW), **WHEN** `resolve(valid_chapter, outcome, 0)` is called, **THEN** `invalid_reason == &"invariant_violation:is_draw_fallback_outcome_mismatch"`. Parameterized over both non-DRAW outcomes to assert the cross-field invariant. The complementary positive case — `is_draw_fallback: true` with `outcome == DRAW` — produces a valid payload (covered by AC-DB-04).
- **Evidence**: GdUnit4 parameterized unit test (2 rows: WIN-outcome, LOSS-outcome); asserts the payload-level F-DB-4 invariant `is_draw_fallback == true ⟹ outcome == DRAW` is enforced at assembly time.

### Bucket 4 — Payload invariants & serialization

**AC-DB-21** (F-DB-2 extended — reserved_color_treatment MUST be false when is_invalid=true). **GIVEN** any input that triggers `is_invalid=true` (all 12 vocabulary paths per F-DB-3 rev 1.3), **WHEN** the returned `DestinyBranchChoice` is inspected, **THEN** `reserved_color_treatment == false` regardless of whether `branch_key` would satisfy the `(branch_key != chapter.default_branch_key)` inequality.
- **Evidence**: GdUnit4 parameterized test across all 12 invalid-path fixtures.

**AC-DB-22** (F-DB-4 invariant — is_draw_fallback⟹DRAW). **GIVEN** a GdUnit4 parameterized test with an explicit fixture set covering (a) Ch2 with `author_draw_branch=false` × outcome ∈ {WIN, DRAW, LOSS} × echo_count ∈ {0, 1}, and (b) Ch3 with `author_draw_branch=true` × outcome ∈ {WIN, DRAW, LOSS} × echo_count ∈ {0, 1} — 12 rows total, **WHEN** `resolve()` is called for each row and the returned `DestinyBranchChoice` is inspected, **THEN** for every row where `is_draw_fallback == true`, the implication `outcome == DRAW` holds (never WIN, never LOSS). Additionally, a CI grep lint rule verifies no code path in `destiny_branch_judge.gd` sets `choice.is_draw_fallback = true` without `outcome == DRAW` in the same function.
- **Evidence**: GdUnit4 parameterized test over the explicit 12-row fixture matrix (no property-based testing API — GdUnit4 does not ship `forAll`/`Arbitrary`). CI grep lint rule committed with the test. Fixture values live in `tests/fixtures/destiny_branch/is_draw_fallback_matrix.gd` as a canonical source. **[Implementation-story prerequisite: fixture file scaffolded. Owner: Test Infrastructure (implementation-story-0). Gate: MVP implementation-story open. Promotion: BLOCKING from MVP open — no ADVISORY path (rev 1.3 qa-lead B-1). MVP implementation story DOES NOT close without the fixture file committed.]**

**AC-DB-23** (F-DB-3 closed vocabulary, rev 1.3 updated to 12-entry set per systems B-1/B-2). **GIVEN** a `DestinyBranchChoice` with `is_invalid=true`, **WHEN** `invalid_reason` is inspected, **THEN** its StringName value is a member of the exact 12-element set: {`&"invariant_violation:chapter_null"`, `&"invariant_violation:chapter_id_missing"`, `&"invariant_violation:default_branch_key_missing"`, `&"invariant_violation:branch_table_null_or_malformed"`, `&"invariant_violation:branch_table_empty"`, `&"invariant_violation:branch_table_missing_outcome"`, `&"invariant_violation:branch_key_type_invalid"`, `&"invariant_violation:is_draw_fallback_type_invalid"`, `&"invariant_violation:is_canonical_history_type_invalid"`, `&"invariant_violation:is_draw_fallback_outcome_mismatch"`, `&"invariant_violation:outcome_unknown"`, `&"invariant_violation:cr13_echo_threshold_on_ch1"`}.
- **Evidence**: GdUnit4 parameterized test asserting `invalid_reason in ALLOWED_INVALID_REASONS` constant. The constant is authoritative and must be kept synchronized with F-DB-3 via code review; a separate CI grep lint verifies `destiny_branch_judge.gd` contains exactly **12** distinct `&"invariant_violation:"` literal StringNames (no more, no fewer — a mutation test that inadvertently adds a 13th flag without updating F-DB-3 fails the lint). Count-assertion lint step is an implementation-story prerequisite on `.github/workflows/tests.yml`. **[ADVISORY until lint-step PR merges; owner: DevOps; gate: MVP implementation-story open; promotion: BLOCKING when `.github/workflows/tests.yml` contains the count step.]**

**AC-DB-24** (ADR-0001 V-3 payload serialization, rev 1.3 empty-StringName fixture row added per qa-lead R-2; historical claim corrected per gdscript R-2). **GIVEN** a valid `DestinyBranchChoice` instance with all **9 fields** populated across a fixture matrix covering (i) `invalid_reason` as a non-empty StringName value + `is_canonical_history=true`; (ii) `invalid_reason` as a non-empty StringName value + `is_canonical_history=false`; **(iii — rev 1.3 NEW)** `invalid_reason = &""` (valid-path happy case — catches empty-StringName demotion to String on round-trip); **(iv — rev 1.3 NEW)** `invalid_reason = &""` + `is_invalid=false` + all other fields at default, **WHEN** it is serialized via `var save_err := ResourceSaver.save(choice, tmp_path)` and reloaded via `var reloaded := ResourceLoader.load(tmp_path)`, **THEN** (a) `save_err == OK` (must be asserted BEFORE reload — `ResourceSaver.save()` returns `Error` since Godot 4.0 [not 4.4 per rev 1.2 historical error]; silent save failure would produce a false-positive test); (b) `reloaded != null`; (c) the reloaded instance has field-equal values to the original for all 9 fields; (d) `typeof(reloaded.invalid_reason) == TYPE_STRING_NAME` on ALL 4 fixture rows (empty and non-empty StringName both preserve type identity; rev 1.3 qa-lead R-2 closes the silent false-pass path where empty StringName demotes to String).
- **Evidence**: GdUnit4 unit test in `tests/unit/core/payload_serialization_test.gd` (new file; destiny-branch implementation story scaffolds it as part of ADR-0001 V-3 suite). **Cross-platform gate (rev 1.2 clarified per qa-lead BLOCK-6, rev 1.3 lifecycle sharpened per qa-lead B-1)**: MVP gate requires pass on macOS Metal canonical lane only; Android + Windows lanes are gated by OQ-DB-6 BLOCKING. Concretely: MVP implementation story closes on macOS pass; Android/Windows pass gates VS-implementation-story close. **[macOS canonical lane: BLOCKING for MVP open AND close. Owner: lead-programmer. Android/Windows lanes: ADVISORY until OQ-DB-6 resolves with named CI lane definitions; promotion: BLOCKING for VS implementation-story close. Owner: DevOps (CI lane) + lead-programmer (test). MVP DOES NOT close without macOS pass; VS DOES NOT close without Android + Windows pass.]**

### Bucket 5 — Cross-system contract (self-contained; no inherited identifiers)

**AC-DB-25** (AC-SP-17 emission ordering, emission-side). **GIVEN** a ScenarioRunner executing its BEAT_7_JUDGMENT exit sequence (dwell elapsed → tap received → exit handler), **WHEN** a GdUnit4 signal spy records emissions on `/root/GameBus`, **THEN** exactly one `save_checkpoint_requested` emission occurs BEFORE exactly one `destiny_branch_chosen` emission, within the same synchronous exit-handler block. No other `destiny_branch_chosen` emissions occur elsewhere in the chapter.
- **Evidence**: GdUnit4 integration test with ordered signal-emission assertion.

**AC-DB-26** (AC-SP-18 payload completeness). **GIVEN** a valid (is_invalid=false) `DestinyBranchChoice` emitted on `destiny_branch_chosen`, **WHEN** the payload is inspected, **THEN** all **9 `@export` fields** are populated with type-valid values: `chapter_id` non-empty String, `branch_key` non-empty String, `outcome` typed `BattleOutcome.Result` ∈ {WIN, DRAW, LOSS}, `echo_count` ≥ 0, `is_draw_fallback` bool, `is_canonical_history` bool, `reserved_color_treatment` bool, `is_invalid=false`, `invalid_reason=&""`.
- **Evidence**: GdUnit4 integration test with payload field-schema assertion using `get_property_list()` enumeration.

**AC-DB-27** (AC-SP-35 Pillar 2 observable, emission-side). **GIVEN** a Ch3 chapter fixture with `author_draw_branch=true` + `echo_threshold=1`, **WHEN** two full Beat 7 sequences run — one with `echo_count=0` and one with `echo_count=1` — and two `destiny_branch_chosen` emissions are captured, **THEN** the two captured `DestinyBranchChoice.branch_key` values are observably distinct strings.
- **Evidence**: GdUnit4 integration test with two run-through fixtures + string-inequality assertion.

**AC-DB-28** (AC-SP-36 DRAW branch distinctness). **GIVEN** a chapter with `author_draw_branch=true` and a `branch_table` containing rows for WIN and LOSS outcomes, **WHEN** `resolve(chapter, DRAW, 0)` is called, **THEN** the returned `DestinyBranchChoice.branch_key` is NOT equal to any WIN-outcome-row or LOSS-outcome-row branch_key in the same chapter's branch_table.
- **Evidence**: GdUnit4 unit test asserting `branch_key` is not in the union of WIN-row and LOSS-row keys.

**AC-DB-39** (V-DB-5 affordance-onset timing sync, rev 1.3 new per ux B-UX-9-3 closing OQ-DB-11). **GIVEN** a ScenarioRunner Beat 7 scripted sequence (dwell-timer 1500ms elapses → scenario-progression UX.2 reveal-from-locked 계속 affordance instantiates + fades in over 150-200ms), **WHEN** a frame-capture integration test records the timestamp at which the 계속 affordance reaches ≥50% opacity, **THEN** that timestamp is ≥1500ms AND ≤1700ms from BEAT_7_JUDGMENT entry, AND the affordance is NOT instantiated before 1500ms. Tests the scenario-progression + destiny-branch V-DB-5 interface consistency.
- **Evidence**: GdUnit4 integration test with `Time.get_ticks_msec()` timestamp capture around frame-render of the affordance node (accepts a 50ms slack for test-runner scheduler jitter). Pass criterion verifies scenario-progression UX.2 lines 817-819 reveal-from-locked model is implemented as spec'd. **[Owner: ux-designer (scenario-progression side) + lead-programmer (destiny-branch side). Gate: VS implementation-story close. Promotion: BLOCKING for VS close.]**

### Bucket 6 — Test infrastructure

**AC-DB-29** (MockChapterResource fixture convention). **GIVEN** the test suite under `tests/unit/destiny_branch/` and `tests/integration/destiny_branch/`, **WHEN** any test needs a `chapter` argument for `resolve()`, **THEN** the test constructs the chapter using the canonical `MockChapterResource` helper from `tests/helpers/mock_chapter_resource.gd` (not inline `Dictionary` substitutes). Linter enforces this via CI grep rule: no `chapter.branch_table` access in test files that don't import the helper.
- **Evidence**: CI lint rule + GdUnit4 test suite adherence. **[Implementation-story prerequisite: `tests/helpers/mock_chapter_resource.gd` scaffolded + CI lint job `destiny-branch-mock-helper-required` merged. Owner: Test Infrastructure (implementation-story-0). Gate: MVP implementation-story open. Promotion: BLOCKING from MVP open. MVP DOES NOT close without helper + lint job merged.]**

**AC-DB-30** (GameBus signal spy setup order for integration tests, rev 1.3 lifecycle sharpened per qa-lead B-1). **GIVEN** any integration test asserting emissions on `destiny_branch_chosen` or `save_checkpoint_requested`, **WHEN** the test executes, **THEN** `monitor_signals(GameBus, false)` is called in `before_test()` (BEFORE any `DestinyBranchJudge.new()` or ScenarioRunner exit-handler call), not after.
- **Evidence**: CI grep lint rule on `.github/workflows/tests.yml`: for each file in `tests/integration/destiny_branch/**/*.gd`, regex-match that the first occurrence of `monitor_signals(GameBus` appears in a line within a `func before_test()` body AND before any occurrence of `DestinyBranchJudge.new()` or `ScenarioRunner.new()`. **[Implementation-story prerequisite: lint job `destiny-branch-signal-spy-order-lint` merged on `.github/workflows/tests.yml`. Owner: DevOps. Gate: MVP implementation-story open. Promotion: BLOCKING from MVP open — no ADVISORY path (rev 1.3 qa-lead B-1). MVP DOES NOT close without lint job merged.]**

**AC-DB-31** (No-state-mutation on caller's inputs + payload-side clamp propagation, rev 1.3 extended per qa-lead R-5 to cover Object-by-reference chapter immutability). **GIVEN** (i) a caller variable `var caller_echo_count := -1`; (ii) a caller variable `var caller_chapter := MockChapterResource.with_valid_fixture()` with a snapshot of its `branch_table` + `default_branch_key` + `chapter_id` fields captured BEFORE `resolve()`; (iii) a caller variable `var caller_outcome := BattleOutcome.Result.WIN`, **WHEN** `judge.resolve(caller_chapter, caller_outcome, caller_echo_count)` returns a `DestinyBranchChoice` called `resolved_choice`, **THEN** (a) `caller_echo_count == -1` (the value in the caller's frame is unchanged — GDScript passes int by value; judge's negative-clamp operates on the function parameter's local copy); AND (b) `resolved_choice.echo_count == 0` (the clamped value is what propagates to the payload, not the original negative); AND **(c — rev 1.3 NEW per qa-lead R-5)** `caller_chapter.branch_table` + `caller_chapter.default_branch_key` + `caller_chapter.chapter_id` are field-equal to their pre-call snapshot (`chapter` is Object-by-reference; CR-DB-2 "no external state read inside function body" + CR-DB-6 "no side-effect on shared state" require assembly/overrides NOT mutate the chapter); AND **(d — rev 1.3 NEW)** `caller_outcome == BattleOutcome.Result.WIN` (enum-by-value passthrough). Warm case: with `caller_echo_count := 5`, both caller variable AND `resolved_choice.echo_count` equal `5`; chapter + outcome immutability assertions hold identically.
- **Evidence**: GdUnit4 unit test with parameterized fixtures: (negative echo → caller-int unchanged + payload clamped + chapter fields unchanged) and (positive echo → caller-int unchanged + payload matches + chapter fields unchanged).

### Bucket 6a — is_canonical_history payload enforcement (Pillar 4)

**AC-DB-33** (F-DB-4 is_canonical_history passthrough, rev 1.3 lifecycle sharpened per qa-lead R-3 + B-1). **GIVEN** a chapter fixture where F-SP-1 returns `is_canonical_history: true` on a given branch row, **WHEN** `resolve()` is called and returns a valid `DestinyBranchChoice`, **THEN** `choice.is_canonical_history == true`. **MVP scope**: fixture uses a `TestDestinyBranchJudgeWithSp1Stub` + hand-authored 3-row mini-matrix (Ch_test with WIN/DRAW/LOSS rows, each declaring a known is_canonical_history) — this decouples the AC from unscaffolded scenario-JSON authoring. **VS scope (rev 1.3 new gate)**: when scenario-progression v2.1 authoring schema + `assets/data/scenarios/*.json` files land, the mini-matrix MUST be superseded by a full parameterized matrix over all 5 MVP chapters × 3 outcomes × {echo=0, echo=1+} levels (minimum 30 parameterized rows). **[MVP mini-matrix: BLOCKING for MVP implementation-story close. Owner: lead-programmer. Full-chapter matrix: BLOCKING for Full Vision implementation-story close (rev 1.3 promotes from previously-unspecified "ADVISORY until v2.1 lands" to concrete gate). Owner: lead-programmer + narrative-director (scenario JSON). Full Vision DOES NOT close without full-matrix coverage.]**
- **Evidence**: GdUnit4 parameterized test over the 3-row mini-matrix at MVP (authored directly in `tests/fixtures/destiny_branch/canonical_history_matrix.gd` as a test-owned fixture, not read from scenario JSON). Full-matrix promotion when scenario-progression v2.1 authoring schema lands, gated to Full Vision implementation-story close per above.

**AC-DB-34** (F-DB-4 is_canonical_history invalid-gating, rev 1.3 vocabulary expansion 10→12). **GIVEN** any invalid-path return (**all 12 `invalid_reason` vocabulary values** per F-DB-3 rev 1.3), **WHEN** the returned `DestinyBranchChoice` is inspected, **THEN** `is_canonical_history == false` (default value; never carries an authored true on invalid path).
- **Evidence**: GdUnit4 parameterized test across **all 12 invalid-path fixtures**. Note: `cr13_echo_threshold_on_ch1` requires `MockChapterResource.with_ch1_echo_violation()` helper (implementation-story prerequisite per AC-DB-20/AC-DB-29); the 2 rev 1.2 entries (is_draw_fallback_type_invalid, is_canonical_history_type_invalid) + the 2 rev 1.3 entries (branch_table_empty, is_draw_fallback_outcome_mismatch) use `TestDestinyBranchJudgeWithSp1Stub` or `MockChapterResource` fixtures per AC-DB-20d/20e/20f/20g seam patterns.

### Bucket 7 — Performance

**AC-DB-32** (resolve() under 1ms + zero RefCounted orphans after 100 calls, rev 1.2 tightened timing-variance tolerance per qa-lead REC-4). **GIVEN** a valid chapter fixture and a defined warmup procedure (10 preliminary `resolve()` calls executed before measurement begins, with one `await get_tree().process_frame` between warmup and measurement), **WHEN** `DestinyBranchJudge.new().resolve(chapter, outcome, echo_count)` is called 100 times in a tight loop measured via `Time.get_ticks_usec()` deltas, **THEN** (a) the **median** call completes in under 1000 microseconds on the canonical platform (macOS Metal); AND (b) the **99th-percentile** call completes under 2000 microseconds (tolerates one GC pause or scheduler slice per 100-call burst without false-flaking); AND (c) after the 100 calls complete and one `await get_tree().process_frame` elapses, the scene-tree's `RefCounted`-backed object count returns to its pre-loop baseline (zero leaked judge instances). Rev 1.1's "every individual call under 1000us" wording was non-deterministic; rev 1.2 switches to median+p99 discipline matching damage-calc rev 2.x precedent.
- **Evidence**: GdUnit4 performance test with `Time.get_ticks_usec` + `Performance.get_monitor(Performance.Monitor.OBJECT_COUNT)` assertion. **Rev 1.2 engine-reference note per godot-gdscript R-1**: `Performance.Monitor.OBJECT_COUNT` is asserted as the Godot 4.6 enum path but is currently UNVERIFIED against `docs/engine-reference/godot/` — flagged in OQ-DB-14 for engine-reference pass. Fallback path `Performance.get_monitor(8)` (raw int enum value) is acceptable if the named path proves unavailable. CI runs on macOS Metal canonical lane (median+p99 budget). Windows D3D12 + Linux Vulkan + Android run weekly with WARN severity. Mobile platform budget is deferred to Beta gate, not MVP gate.

### Bucket 8 — Cross-GDD accessibility enforcement (rev 1.2 new)

**AC-DB-38** (V-DB-4 error-dialog a11y gate, rev 1.3 criteria made concrete per a11y REC-1). **GIVEN** a destiny-branch emission path where `is_invalid == true` (any of the 12 rev 1.3 vocabulary entries), **WHEN** ScenarioRunner renders the error-dialog surface (V-DB-4 delegation), **THEN** an automated a11y audit must pass on that surface covering the following concrete Godot 4.6 Intermediate-tier checks: (a) **screen-reader label** — error-dialog root Control has a non-empty `tooltip_text` property AND a non-empty custom metadata key `a11y_label` (pre-AccessKit placeholder; replaces with AccessKit node-role property at Full Vision tier); (b) **keyboard dismissal** — Esc keypress via `Input.action_press("ui_cancel")` + `Input.action_release("ui_cancel")` dismisses the dialog within 1 frame (asserted via `await get_tree().process_frame`); Enter keypress via `ui_accept` triggers the same dismiss path; (c) **subtitle track** — if any audio cue is played during dialog lifecycle, a Label node under the dialog's subtitle layer contains the cue's `has_narrative_weight` flag's corresponding locale-keyed string (per R-5); (d) **haptic pulse** on mobile export target — mocked via `HapticInvocationRecorder.expect_invocation_called_once()` (mock contract: a single `invoke(duration_ms, intensity)` call is recorded, respecting Settings `reduce_haptics=true` as no-op; mock lives at `tests/helpers/haptic_invocation_recorder.gd`); (e) **no motion-only signal** — asserted by rendering the dialog twice (once with Reduce Motion off, once with Reduce Motion on) and confirming the dismiss-ready state is conveyed via the same `tooltip_text` / `a11y_label` metadata regardless of animation state. **[AC PASS criteria (a)-(e) are now concrete and Godot-4.6-testable without AccessKit dependency. AC blocks destiny-branch VS-implementation-story close UNTIL all 5 criteria pass + scenario-progression's error-dialog spec codifies these requirements (OQ-DB-13 BLOCKING VS) + `HapticInvocationRecorder` helper is scaffolded. Owner: accessibility-specialist + ux-designer (scenario-progression side) + Test Infrastructure (helper). Gate: VS implementation-story close. Promotion: BLOCKING for VS (unchanged; rev 1.3 makes criteria operationally testable). MVP implementation story close NOT blocked by this AC — MVP ships with invalid-path emission correctness per AC-DB-34 only; error-dialog a11y is VS scope.]**
- **Evidence**: GdUnit4 integration test that triggers an invalid destiny-branch emission and inspects the rendered error-dialog tree for the 5 concrete checks above. Helper dependencies: `tests/helpers/haptic_invocation_recorder.gd` (scaffolded at VS implementation-story-0) + existing `error_log_capture.gd` (rev 1.3 D2 stdout-redirect).

### Coverage summary

| Bucket | ACs | Covers |
|---|---|---|
| 1 Formula correctness | 6 | F-DB-1 worked examples E1–E6 |
| 2 Core Rule invariants | 9 | CR-DB-2, 3, 4, 5, 6, 7, 8, 9, 11 |
| 3 Invalid-path vocabulary | 12 | F-DB-3 × 12 flags (rev 1.3 +2: branch_table_empty [systems B-1], is_draw_fallback_outcome_mismatch [systems B-2]) |
| 4 Payload invariants & serialization | 4 | F-DB-2 extended, F-DB-4 invariants (9 fields), F-DB-3 closed set, ADR-0001 V-3 (rev 1.3 +empty-StringName fixture row per qa-lead R-2) |
| 5 Cross-system contract | 5 | AC-SP-17, 18, 35, 36 (emission-side, self-contained) + V-DB-5 affordance-onset timing sync (rev 1.3 AC-DB-39 per ux B-UX-9-3) |
| 6 Test infrastructure | 3 | MockChapterResource, signal-spy order (rev 1.2 CI grep), caller-input immutability (rev 1.3 extended to chapter-Object-by-reference + outcome-enum per qa-lead R-5) |
| 6a is_canonical_history enforcement | 2 | Pillar 4 payload-level enforcement (passthrough + invalid gating) |
| 7 Performance | 1 | median<1ms + p99<2ms + zero leaks over 100 calls (macOS Metal canonical, rev 1.2 variance-aware) |
| 8 Cross-GDD a11y enforcement (rev 1.2) | 1 | V-DB-4 error-dialog R-1..R-5 gate (AC-DB-38 — scenario-progression-owned, destiny-branch-gated; rev 1.3 criteria made concrete Intermediate-tier-testable per a11y REC-1) |
| **Total** | **43** | CR-DB-1 (design justification) and CR-DB-12 (scope rejection) are design-level, not runtime-testable — deliberately uncovered |

## Open Questions

| # | Item | Owner | Target resolution | Blocks |
|---|---|---|---|---|
| **OQ-DB-1** | ADR-0001 minor amendment for `DestinyBranchChoice` **9-field** shape (replace the current 5-field provisional list per Evolution Rule #4). Also update ADR-0001 provisional count 4→3. | technical-director (ADR) + producer | Before MVP implementation story starts | AC-DB-24 payload-serialization test / signal_contract_test.gd |
| **OQ-DB-2** | scenario-progression v2.1 revision — §Interactions line 186-188 wording clarification (T-1 resolution), AC-SP-18 payload field-set addition, AC-SP-17 invalid-path clarification sentence | narrative-director + producer | Next scenario-progression revision | Nothing immediate — destiny-branch ships on current AC-SP-18; the 2 added fields are non-breaking |
| **OQ-DB-3** | Destiny State #16 VS design start — confirms the PROVISIONAL subscriber contract (consume `destiny_branch_chosen.echo_count` + `is_draw_fallback`; gate on `is_invalid == false`) | systems-designer + producer | VS milestone | Nothing MVP — #16 not required for destiny-branch MVP correctness |
| **OQ-DB-4** | Story Event #10 VS design start — confirms Beat 8 tone differentiation for `is_draw_fallback` + echo-gated paths; enables "Marked Hand" secondary fantasy from Section B | narrative-director + producer | VS milestone | Nothing MVP — the secondary fantasy layer sits on top of the primary Ceremonial Witness, which works without #10 |
| **OQ-DB-5** | F-SP-1 mutability risk — any future scenario-progression revision to F-SP-1 (additional required output field, changed shape) forces a corresponding destiny-branch F-DB-1 update. Process guard. | narrative-director (scenario-progression) + game-designer (destiny-branch) + producer | Permanent / any future F-SP-1 revision | Nothing today; flagged for change-propagation discipline |
| **OQ-DB-6 [BLOCKING]** | Platform variance on StringName serialization — ADR-0001 §Verification Required #1 flags that Resource payloads must round-trip on Android + Windows export targets. Not yet tested. **Upgraded from OPEN to BLOCKING implementation-start gate**: AC-DB-24 must pass on macOS + Android + Windows CI lanes before any destiny-branch implementation story is marked Done. Adding Android export target + CI lane is a prerequisite task (owned by DevOps). | lead-programmer + DevOps + QA | Before implementation story close | **BLOCKS implementation story completion** |
| **OQ-DB-7** | Screen-reader label hook — target text "운명이 다른 길을 갔다" / "History took a different path" for reserved-color reveal. Needs a label-injection hook via scenario-progression's beat-text system. Localization string key placeholder: `"beat_7.reserved_color.sr_label"` (owned by Localization GDD #30 for string-table registration). **Milestone correction**: accessibility-requirements.md §3 defers Screen-reader / AccessKit to **Full Vision tier** (NOT Alpha). Settings/Options #28's Alpha elevation was for Intermediate toggle surfacing, not for screen-reader support. Pre-AccessKit at Intermediate tier, scenario-progression's 해금 at −18 LUFS serves as the de-facto non-visual signal for visually-impaired players. | ux-designer + accessibility-specialist | Full Vision milestone (AccessKit ships) | Nothing MVP — Intermediate tier does not include AccessKit; 해금 audio is the interim proxy |
| **OQ-DB-8** | Whether an implementation ADR is needed for destiny-branch — may not be required for a system this simple (one pure function + one typed Resource). If VS design surfaces cross-cutting concerns (e.g., future branch-preview telemetry), an ADR may become warranted. | technical-director | Review at VS gate | Nothing MVP |
| **OQ-DB-10 [rev 1.3 D3 — inverted to failure threshold]** | Ch1 priming-null tutorial shape observation — per Section B decision, Ch1's always-default Beat 7 is accepted as the tutorial shape without mechanical mitigation. First mobile playtest must observe whether Ch1 Beat 7 + Ch2+ reserved-color reveal lands as intended. **Rev 1.3 failure-threshold framing (per game-designer B-2 — replaces rev 1.2 escalation-trigger framing which measured rate-of-exposure instead of quality-of-realization)**: **Pillar 2 FAILS MVP acceptance if more than 10% of playtest sessions reach Ch2 end without a reserved-color reveal** (defined: Beat 7 firing with `reserved_color_treatment == true` at least once in Ch1 or Ch2). >10% miss rate is narratively unacceptable for a system whose entire purpose is to deliver Pillar 2's crossing from possibility to observed fact. If >10% miss rate observed, MVP does NOT pass until scenario-progression authoring adds a Ch2 first-reveal guarantee (mandate non-default branch on first-attempt DRAW) OR a Ch2 Beat 8 narrative priming text that establishes the reserved-color contrast verbally before Ch3. **Rev 1.3 advisory qualitative probe (per game-designer B-2 + narrative N-ND-2)**: in addition to the ≤10% quantitative ceiling, each playtest session MUST include an observer-recorded qualitative assessment at the first reserved-color Beat 7 — "Did the player register surprise / weight / recognition at this moment, or did they tap through without apparent awareness?" — because rate-of-exposure ≠ quality-of-felt-realization. Qualitative assessment is advisory at MVP, BLOCKING at VS. Deafblind-mobile regression subcase tracked as accepted Intermediate gap per UI-DB-4. | game-designer + narrative-director + producer | First mobile playtest (MVP gate — BLOCKING for MVP exit if >10% miss rate) | **BLOCKS MVP exit** (rev 1.3 upgrade from "Nothing MVP") if >10% miss-rate observed |
| **OQ-DB-11 [RESOLVED 2026-04-19 rev 1.3 ux B-UX-9-3]** | ~~Beat 7 tap-ready affordance at 1500ms dwell-lockout exit — scenario-progression v2.0 does not currently spec a visual affordance...~~ **Resolved**: scenario-progression.md UX.2 lines 817-819 already spec the affordance (reveal-from-locked model — the "계속" affordance does NOT exist in the scene tree during the 1.5s lockout; instantiated and fades in 150-200ms after lockout expiry). destiny-branch's OQ-DB-11 was based on an incorrect premise (scenario-progression v2.0 was believed to lack the spec; it does not). No interim UI-DB-6 addition needed. V-DB-5 cross-reference retained as-is; new AC-DB-39 (rev 1.3) added to Bucket 5 for affordance-onset timing sync verification. | ux-designer (scenario-progression confirmed) | Closed 2026-04-19 | N/A — resolved |
| **OQ-DB-9 [RESOLVED 2026-04-19]** | Beat 7 audio ownership conflict surfaced by `/consistency-check` — initial v1.0 draft proposed a temple-bell cue at −12 LUFS; scenario-progression §A.1 already specified 가야금 default / 해금 non-default at −22/−18 LUFS. User directed deferral to scenario-progression's authoritative spec. **Resolution**: A-DB-1 rewritten as reference-only; A-DB-2 haptic reframed as destiny-branch's sole audio-adjacent contribution (accessibility 화면 진동 channel); A-DB-3 scope boundary updated (destiny-branch owns zero audio cues); V-DB-4 + UI-DB-2/4/5 + asset-spec flag updated. | /consistency-check 2026-04-19 | Closed in same session | N/A |
| **OQ-DB-12 [BLOCKING verification; interim A-DB-2 downgraded]** | Godot 4.6 haptic-preference API verification — rev 1.1 A-DB-2 cited `Input.get_haptic_feedback_enabled()` which does NOT exist at Godot 4.6 per accessibility-specialist BLOCKING-B. Rev 1.2 downgraded A-DB-2 to best-effort + in-game Settings `reduce_haptics` opt-out (D4 decision). Engine-reference pass MUST verify whether Godot 4.6 exposes: (a) a native API for iOS `UIFeedbackGenerator` preference; (b) a native API for Android `Vibrator` system-pref; (c) whether AccessKit 4.5+ surfaces haptic-enabled state cross-platform. If none are available, document GDExtension wrapper path as a separate engineering task. | lead-programmer + godot-specialist + DevOps (engine-reference-verification lane) | Before VS implementation story close | Full A-DB-2 OS-pref contract (not MVP; in-game Settings opt-out suffices at MVP) |
| **OQ-DB-13 [BLOCKING VS]** | V-DB-4 error-dialog a11y R-1..R-5 gate (AC-DB-38 dependency) — scenario-progression's error-dialog spec does NOT currently codify machine-readable label + keyboard dismiss + subtitle + haptic + no-motion-only-signal requirements. destiny-branch's invalid-path emissions route to this dialog. **Promoted from rev 1.1 "if…flag" hedge to BLOCKING** per accessibility-specialist BLOCKING-A + D1-aligned enforcement. Scenario-progression v2.1 MUST author the spec; destiny-branch AC-DB-38 tests compliance. | ux-designer (scenario-progression owner) + accessibility-specialist + narrative-director | Before VS implementation story | **BLOCKS VS implementation story** (AC-DB-38) |
| **OQ-DB-14** | `Performance.Monitor.OBJECT_COUNT` Godot 4.6 enum-path verification — AC-DB-32 asserts this path; rev 1.2 godot-gdscript R-1 flags it as UNVERIFIED against `docs/engine-reference/godot/`. Fallback: `Performance.get_monitor(8)` raw int. Verification pass to add an engine-reference entry if path confirmed, or revise AC-DB-32 to fallback. | godot-specialist + DevOps | Before VS implementation story | Nothing MVP — fallback is acceptable; this is doc hygiene |
| **OQ-DB-15 [Photosensitive]** | V-DB-1 Reduce Motion 0ms snap on full-frame 주홍 #C0392B at 40%+ opacity — SC 2.3.1 three-per-second flash threshold is not triggered (single onset per Beat 7), but saturated-red snap on large viewport area warrants a dedicated photosensitive-epilepsy safety audit. Damage-calc rev 2.5 policy covers popup-scale only; Beat 7 is full-frame. | accessibility-specialist + art-director + external a11y audit (Pre-Production) | Pre-Production (before first external playtest) | Nothing MVP; blocks external playtest if audit fails |
| **OQ-DB-17 [rev 1.3 new per a11y B-2]** | Korean braille adequacy for `beat_7.subtitle.{default\|reserved\|fallback}` localization keys. Rev 1.2's braille flag on V-DB-2 incorrectly cross-referenced OQ-DB-13 (which covers error-dialog a11y, NOT braille adequacy). Verify: (a) Korean braille tables render the ko-KR source strings ("운명이 같은 길을 걸었다" / "운명이 다른 길로 갈라졌다" / "결판 없이 길은 이어졌다") without ambiguity for Korean-reading braille-display users; (b) English glosses ("The path holds." / "The path turns." / "No verdict. The path continues.") preserve the divergence semantic in English braille. | accessibility-specialist + localization-lead (Localization GDD #30) | Intermediate tier verification before external playtest | Nothing MVP — Intermediate braille adequacy is Polish-tier polish; flagged so it is tracked, not lost |
| **OQ-DB-16 [RESOLVED 2026-04-19 rev 1.3 D4 — SWALLOW]** | ~~Dwell-lockout early-tap UX decision — swallow vs queue-to-fire-on-unlock.~~ **Resolved SWALLOW per rev 1.3 D4**: early taps during the 1.5s dwell lockout are dropped silently. Ceremonial Witness fantasy (Section B) depends on the 1.5s silence being INHABITED, not counted-down-to-skip. Queue-to-fire-on-unlock rejected as anti-fantasy per game-designer B-3 (a tap-trained player would instinctively queue a tap immediately on entry, collapsing the ceremony to a 1500ms wait animation with instant exit). Constraint propagates to scenario-progression's BEAT_7_JUDGMENT input handler: during dwell-lockout, input events are consumed and discarded; no queue, no visual feedback on the discarded tap (silence is the feedback). Scenario-progression v2.1 must formalize this in its input-layer Beat 7 UI spec. | ux-designer + creative-director (resolved) | Closed 2026-04-19 | N/A — resolved |
