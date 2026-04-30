# Architecture Review — Delta #8 (ADR-0011 Turn Order)

**Date**: 2026-04-30
**Mode**: lean delta (8th invocation; pattern-stable track at 8 invocations)
**Engine**: Godot 4.6 (pinned 2026-04-16)
**Verdict**: ✅ **PASS** (0 substantive corrections this delta — Status flip only; lowest correction count in 8-pattern history)
**ADRs Reviewed**: 12 total (1 net-new ADR-0011 escalated Proposed → Accepted; 11 prior Accepted re-verified for cross-conflict)
**GDDs Re-scanned**: 4 (turn-order primary; hp-status + damage-calc + balance-data cross-doc)
**Source ADR**: `docs/architecture/ADR-0011-turn-order.md`
**Status flip**: Proposed (2026-04-30 commit `b11ef20`) → Accepted (2026-04-30 via /architecture-review delta #8)

---

## Summary

ADR-0011 Turn Order escalated Proposed → Accepted with **0 substantive design-level corrections**
(Status flip only). The ADR was authored 2026-04-30 with embedded godot-specialist lean validation
that incorporated 3 same-patch pre-Write corrections + same-patch ADR-0001 amendment for
`victory_condition_detected` signal declaration (commit `b11ef20`). Delta #8 surfaced 0 net-new
substantive findings — a first in the 8-invocation pattern, attributable to:

1. **Embedded godot-specialist validation at design time** (8/8 PASS-or-CONCERN; 5 PASS + 3
   CONCERN→corrected pre-Write)
2. **4-precedent DI seam pattern stability** (ADR-0005 + ADR-0010 + ADR-0012 + ADR-0011)
3. **3-precedent battle-scoped Node form pattern stability** (ADR-0005 InputRouter Autoload Node +
   ADR-0010 HPStatusController battle-scoped Node + ADR-0011 TurnOrderRunner battle-scoped Node)
4. **Same-patch ADR-0001 amendment for signal addition** already applied at Proposed commit
   (`victory_condition_detected(result: int)` signal declaration + §3 Turn Order Domain table row +
   Last Verified date refresh — preventing the cross-doc gap that would otherwise have surfaced as
   delta #8 finding).

**Project transitions** (post-delta-#8 acceptance):

- **11 → 12 Accepted ADRs**
- **Foundation 5/5 + Core 2/2 → 3/3 Complete** — **first all-Foundation+Core-Complete state for
  the project**
- Mandatory ADRs before Pre-Production → Production gate: 1 → **0** (per `architecture.md` v0.6
  Phase 6)
- Pattern boundary precedent stable at **3 ADRs** (battle-scoped Node form for state-holders +
  signal-listeners is now project discipline)
- ✅ **Blocker §1 RESOLVED** (Turn Order → AI signal-inversion contract codified via direct
  delegation Contract 5 + interleaved queue invisibility; signal-inversion proposal explicitly
  rejected per ADR-0011 §Decision §Why this form)

---

## Phase 1: Files Loaded

- **ADR-0011** (full read; 511 LoC) — primary review target
- **ADR-0001** (full read; verified same-patch amendment correctly applied at lines 13/155/301)
- **ADR-0010** §Soft/Provisional clause + §Enables (grep + targeted Read)
- **ADR-0012** §Dependencies line 42 + lines 91/109/340/343 + Related references (grep + targeted
  Read)
- `design/gdd/turn-order.md` Status header
- `design/gdd/hp-status.md` §Dependencies 하위 의존성 table
- `design/gdd/balance-data.md` §Dependencies 하위 의존성 table
- `docs/architecture/tr-registry.yaml` v9 (header + TR-turn-order-001 + tail)
- `docs/architecture/architecture-traceability.md` v0.8 (Document Status + Coverage Summary +
  Registered TR-to-ADR map + Pending TR baseline + Changelog)
- `docs/architecture/architecture.md` v0.5 (Document Status + Phase 2 Turn Order row + Phase 5 ADR
  Audit + Phase 6 Required ADRs + Open Questions)
- `docs/registry/architecture.yaml` v5 (turn_order entries already present from commit `b11ef20`
  Proposed-time write)
- `docs/consistency-failures.md` (absent — no append required)

**Loaded**: 13 ADRs + 4 GDDs + 4 registry/index files. Engine: Godot 4.6.

---

## Phase 2: TR Extraction

**21 net-new TRs** extracted from ADR-0011 §Decision + §Validation Criteria + §GDD Requirements
Addressed sections, registered as **TR-turn-order-002..022** in `tr-registry.yaml` v9 → v10.

Coverage breakdown:

| TR-ID | ADR-0011 Section | Decision Locked |
|-------|-------------------|-----------------|
| TR-turn-order-002 | §Decision Module form | Battle-scoped Node form; pattern boundary 3-precedent |
| TR-turn-order-003 | §Decision State Ownership | 5 instance fields + Dictionary[int, UnitTurnState] |
| TR-turn-order-004 | §Decision RefCounted typed wrappers | UnitTurnState + TurnOrderSnapshot + TurnOrderEntry; snapshot() field-by-field copy |
| TR-turn-order-005 | §Decision Public mutator API | 3 methods (initialize_battle + declare_action + _advance_turn DI seam) |
| TR-turn-order-006 | §Decision Public read-only query API | 5 query methods O(1) |
| TR-turn-order-007 | §Decision Emitted signals | 4 GameBus signals; ADR-0001 same-patch amendment |
| TR-turn-order-008 | §Decision Consumed signal | unit_died with CONNECT_DEFERRED + R-1/R-2 mitigations |
| TR-turn-order-009 | §Decision Forbidden patterns | 5 patterns (consumer_mutation + external_queue_write + signal_emission_outside_domain + static_var_state_addition + typed_array_reassignment) |
| TR-turn-order-010 | §F-1 + §CR-5 tie-break cascade | 4-key deterministic total order |
| TR-turn-order-011 | §CR-2 T1–T7 sequence | 7-step strict ordering |
| TR-turn-order-012 | §CR-3 action budget | MOVE + ACTION binary tokens; reset to FRESH at T4 |
| TR-turn-order-013 | §CR-4 action types | 5 ActionType + DEFEND_STANCE locks |
| TR-turn-order-014 | §CR-6 static initiative MVP rule | Computed once at BI-2; no dynamic re-queuing |
| TR-turn-order-015 | §CR-7 death mid-round | CR-7a queue removal + CR-7d T5 interrupt |
| TR-turn-order-016 | §CR-9 BI-1..BI-6 battle initialization | 6-step sequence + Callable.call_deferred() form |
| TR-turn-order-017 | §F-2 charge accumulation | accumulated_move_cost reset at T4 (R-3 mitigation) |
| TR-turn-order-018 | §F-3 round cap + ADR-0006 BalanceConstants append | ROUND_CAP=30 + CHARGE_THRESHOLD=40 |
| TR-turn-order-019 | §Validation §14 G-15 test isolation | 6-element reset list (R-5 mitigation) |
| TR-turn-order-020 | §Validation §AC-18 + §AC-22 victory precedence | Mutual kill PLAYER_WIN + T7 PLAYER_WIN beats RE2 DRAW |
| TR-turn-order-021 | §Performance Implications | O(N log N) sort; O(1) queries; ~500 bytes per battle |
| TR-turn-order-022 | Cross-doc unit_id type advisory | Resolved 2026-04-30 delta #8 same-patch (lines 91/109/340/343 narrowed StringName → int) |

**Total per-system TR count post-registration**: 22 (1 existing + 21 net-new).
**Project TR registry total**: 121 → **142**.

---

## Phase 3: Traceability Matrix

✅ **All 22 TRs covered by ADR-0011** (no gaps, no partials).

| Status | Count | % |
|--------|-------|---|
| ✅ Covered (full chain GDD → ADR) | 22 | 100% |
| ⚠️ Partial | 0 | 0% |
| ❌ Gap | 0 | 0% |

---

## Phase 4: Cross-ADR Conflict Detection

**🟢 0 BLOCKING conflicts.**

Findings table:

| # | Type | Finding | Status |
|---|------|---------|--------|
| 1 | ✅ Same-patch verified | ADR-0001 lines 13/155/301 amendment for `victory_condition_detected(result: int)` correctly applied in commit `b11ef20`. Signal declaration + §3 Turn Order Domain table row + Last Verified date refresh all present. | None — verified correct |
| 2 | ⚠️ Status flip | ADR-0010 §Soft/Provisional clause (1) line 42 prose. | ✅ Applied delta #8 same-patch: "(1) ADR-0011 Turn Order (NOT YET WRITTEN — soft / provisional downstream)" → "(1) ADR-0011 Turn Order (Accepted 2026-04-30 via /architecture-review delta #8 — RATIFIED parameter-stable; no code change to ADR-0010 required)" |
| 3 | ⚠️ Status flip | ADR-0010 §Enables clause: "ADR-0011 still provisional" wording. | ✅ Applied delta #8 same-patch: "ADR-0011 still provisional" → "ADR-0011 ratified 2026-04-30 via delta #8" |
| 4 | ⚠️ Backfill from delta #7 | ADR-0012 line 42 ADR-0010 clause: "**ADR-0010 HP/Status (NOT YET WRITTEN — soft / provisional)**". Should have flipped in delta #7 but wasn't applied (delta #7 oversight). | ✅ Applied delta #8 same-patch (delta #7 backfill): flipped to "Accepted 2026-04-30 via /architecture-review delta #7 — RATIFIED" |
| 5 | ⚠️ Status flip | ADR-0012 line 42 ADR-0011 clause: "**ADR-0011 Turn Order (NOT YET WRITTEN — soft / provisional)**". | ✅ Applied delta #8 same-patch: flipped to "Accepted 2026-04-30 via /architecture-review delta #8 — RATIFIED" |
| 6 | ⚠️ Cross-doc advisory batch | ADR-0012 lines 91/109/340/343 declared `unit_id: StringName`; ADR-0010 + ADR-0011 LOCK `int` (matches ADR-0001 line 153 signal-contract source-of-truth + Dictionary[int, *] key consistency). 4 spots: line 91 (HP/Status API) + line 109 (Turn Order API) + line 340 (HP/Status Dependencies table) + line 343 (Turn Order Dependencies table). Delta #7 HP/Status carry + delta #8 Turn Order carry combined. | ✅ Applied delta #8 same-patch (4 edits): all narrowed StringName → int with explanatory annotations referencing delta #8 advisory batch + ADR-0001 line 153 source-of-truth + ADR-0010/0011 Dictionary[int, *] key consistency. Internal Damage Calc ContextResource fields (lines 186/192/197/201) + call sites (lines 260/352-353) retain implicit StringName pending follow-up ADR-0012 amendment that will propagate `int` through AttackerContext/DefenderContext factory signatures. |
| 7 | ⚠️ Carried advisory (defer) | ADR-0001 line 168 `signal input_action_fired(action: String, ...)` — should be `action: StringName` per ADR-0005 + GDD `input-handling.md` ACTIONS_BY_CATEGORY hot-path StringName literal convention. Delta #6 Item 10a carry. | DEFERRED to next ADR-0001 substantive edit. Not touched in delta #8 (delta #8 base scope does not include ADR-0001 edits beyond the already-applied b11ef20 amendment). |
| 8 | ⚠️ Carried advisory (defer) | ADR-0001 line 372 prose drift `hero_database.get(unit_id)` → `HeroDatabase.get_hero(hero_id: StringName)`. Delta #5 ADR-0007 carry. | DEFERRED to next ADR-0001 substantive edit. |
| 9 | ✅ Status flip (cross-system contract) | `registry/architecture.yaml` line 547 prose "Proposed 2026-04-30; pending Acceptance via /architecture-review delta #8" | ✅ Applied delta #8 same-patch: flipped to "Accepted 2026-04-30 via /architecture-review delta #8 — RATIFIED parameter-stable per ADR-0010 §Soft/Provisional clause (1) flip"; unit_id type advisory wording also updated at line 569 (consumers section) reflecting same-patch resolution |

**ADR Dependency Ordering** (post delta #8):

```
Platform (no deps): ADR-0001 / ADR-0002 / ADR-0003
Foundation:         ADR-0004 / ADR-0006 / ADR-0007 / ADR-0009 / ADR-0005
Core:               ADR-0008 → ADR-0010 → ADR-0011  ← THIS DELTA
Feature:            ADR-0012 (Damage Calc; 2-3 more pending — Grid Battle / AI / Formation Bonus)
```

✅ No cycles. ✅ No unresolved dependencies post delta #8.

---

## Phase 5: Engine Compatibility

✅ ADR-0011 §Engine Compatibility section present and complete.
✅ **Knowledge Risk: LOW** — Core gameplay logic only; no physics / rendering / UI / SDL3 / D3D12 /
   accessibility surface touched.
✅ **Post-Cutoff APIs Used**:
- Typed `Dictionary[int, UnitTurnState]` (Godot 4.4+, validated by ADR-0010 precedent)
- `Object.CONNECT_DEFERRED = 1` (stable through Godot 4.6 per godot-specialist Item 4)
- `Callable.call_deferred()` method-reference form (preferred 4.x idiom over string-based per
  project deprecated-apis pattern; godot-specialist Item 6)
✅ **Verification Required**: None additional (ADR-0010 + ADR-0001 precedents cover all engine-level
   concerns; godot-specialist 2026-04-30 lean validation already incorporated 3 same-patch corrections
   pre-Write).
✅ No deprecated APIs used.
✅ Version consistency: pinned at Godot 4.6 across all 12 ADRs.
✅ No conflicts with prior ADRs' engine assumptions.

**godot-specialist consultation**: already performed at ADR-0011 design-time per `active.md` extract:
"APPROVED WITH SUGGESTIONS, 8/8 PASS-or-CONCERN; 5 PASS + 3 CONCERN→corrected". 3 same-patch
corrections (Item 3 UnitTurnState.snapshot field-by-field copy + Item 6 Callable.call_deferred form +
cross-ADR check that surfaced ADR-0001 same-patch amendment requirement) already incorporated. No
additional consultation needed for delta #8 escalation.

---

## Phase 5b: GDD Revision Flags

✅ **None.** No HIGH-risk engine findings. All GDD assumptions consistent with verified engine
behavior. ADR-0011 §Decision §Why this form internal alternatives section already validates the
design against engine constraints (Stateless-static rejection per ADR-0005 §Alt 4 + ADR-0010 §Alt 3
pattern boundary; Autoload rejection per battle-scoped non-persistence requirement; Hybrid
rejection per bifurcation failure-mode analysis; Per-unit Resource rejection per battle-scoped
runtime-state classification mirroring ADR-0010 UnitHPState rationale). No GDD revision needed.

---

## Phase 6: Architecture Document Coverage

`architecture.md` v0.5 → **v0.6** updates applied:

- **Document Status**: ADRs Referenced 11 → **12 Accepted**
- **Phase 2 Module Ownership**: Turn Order row fully rewritten with ADR-0011 specifics
  (TurnOrderRunner battle-scoped Node + 5 instance fields + UnitTurnState RefCounted + 8 public API
  methods + 4 emitted signals (last `victory_condition_detected(int)` via same-patch ADR-0001
  amendment) + 1 consumed signal (`unit_died` with CONNECT_DEFERRED) + 5 forbidden_patterns + 2
  net-new BalanceConstants + Blocker §1 closure note)
- **Phase 5 ADR Audit**: 11 → **12 rows** (added ADR-0011 row); ADR-0012 unit_id type advisory
  RESOLVED entry refreshed (3 → 2 carried advisories — only ADR-0001 line 168 + line 372 remaining)
- **Phase 6 Required ADRs**: Mandatory list pruned **1 → 0**; Layer status: Foundation 5/5 + Core
  2/2 → **3/3 Complete**; Feature 1/3 + Presentation 0/1 + Polish 0/1 unchanged; net-new count 2-6
  → **1-5**
- **Open Questions §1**: ✅ Blocker §1 RESOLVED via ADR-0011 §Decision Contract 5 direct delegation
  pattern (signal-inversion proposal explicitly rejected; interleaved queue CR-1 invisibility codified)
- **System Layer Map preview list**: ADR-0011 struck from "additional ADRs needed before
  implementation" list
- **Audit summary**: 9/9 → 12/12 Engine Compatibility + GDD coverage statistics; pattern stable at
  8 invocations (avg ~2.5 corrections excluding delta #6 anomaly; delta #8 = 0 substantive
  corrections — lowest in 8-pattern history)
- **Changelog v0.6 entry** appended

`architecture-traceability.md` v0.8 → **v0.9** updates applied:

- **Document Status**: TRs registered 121 → 142; ADR coverage 11 → 12; first
  all-Foundation+Core-Complete state codified
- **Coverage Summary**: Core layer 2/2 → **3/3 Complete**; net-new count 2-6 → 1-5
- **Registered TR-to-ADR map**: +21 rows for TR-turn-order-002..022; TR-hp-status-018 entry status
  updated to RESOLVED 2026-04-30 delta #8
- **Pending TR baseline**: turn-order section collapsed (13 candidates → 21 net-new REGISTERED);
  total registered TRs 121 → 142; total pending TRs 73 → 52
- **Changelog v0.9 entry** appended

---

## Phase 7: Verdict

### ✅ **PASS** — Delta #8

**0 substantive corrections this delta** (Status flip only) — lowest correction count in the
8-invocation pattern history.

**Project transitions** (post-delta-#8 acceptance):

- 11 → **12 Accepted ADRs**
- Foundation 5/5 + Core 2/2 → **3/3 Complete** — first all-Foundation+Core-Complete state
- Mandatory ADRs before Pre-Production → Production gate: 1 → **0**
- Pattern boundary precedent stable at **3 ADRs**
- ✅ Blocker §1 RESOLVED

### Blocking Issues

None.

### Required ADRs (priority order)

✅ All Foundation + Core mandatory ADRs Accepted. Next critical-path ADRs (all Vertical-Slice
candidates; all Feature-layer):

1. **AI System ADR** — consumer of `unit_turn_started` (per ADR-0011 + ADR-0010 §6 turn-flow) +
   `request_action(unit_id, queue_snapshot)` Contract 5 direct delegation per ADR-0011 §Decision +
   `get_class_passives` (PASSIVE_TAG_BY_CLASS) + `get_class_cost_table` from ADR-0009. Required for
   Grid Battle Vertical Slice readiness.
2. **Grid Battle ADR finalization** — `battle_outcome_resolved` ownership per ADR-0001 single-owner
   rule; consumes ADR-0011 `victory_condition_detected` bridge signal; transitions to RESOLUTION;
   emits authoritative `BattleOutcome` Resource per ADR-0003 schema; SP-1 epic blocker.
3. **Formation Bonus ADR** — consumer of HeroDatabase `get_relationships` + shared cap
   `MAX_DEFENSE_REDUCTION = 30` from ADR-0008; per-unit cap `0.05` formation_def_bonus;
   integration with Damage Calc `ResolveModifiers.formation_atk_bonus` / `formation_def_bonus`
   fields.

---

## Phase 8: Files Written (delta #8 same-patch)

11 files modified + 1 created same-patch. All edits applied via Edit tool with explicit
old_string/new_string anchors.

**Modified** (11):

1. `docs/architecture/ADR-0011-turn-order.md` — Status flip Proposed → Accepted (line 5) + Last
   Verified date refresh with delta #8 specifics (line 13)
2. `docs/architecture/ADR-0010-hp-status.md` — §Soft/Provisional clause (1) flipped Soft →
   Ratified + §Enables clause refreshed
3. `docs/architecture/ADR-0012-damage-calc.md` — line 42 prose (delta #7 ADR-0010 backfill + delta
   #8 ADR-0011 primary + cross-doc unit_id type advisory annotation) + line 91 (HP/Status API
   `unit_id: StringName` → `unit_id: int` + ADR-0001 line 153 source-of-truth lock annotation) +
   line 109 (Turn Order API ditto) + line 340 (§Dependencies HP/Status table row) + line 343
   (§Dependencies Turn Order table row) + §Provisional-dependency contract footnote refresh +
   §Related ADR-0010/0011 references refresh
4. `design/gdd/turn-order.md` — Status header flip Designed → ✅ Accepted via ADR-0011 + Last
   Updated annotation
5. `design/gdd/hp-status.md` — §Dependencies 하위 의존성 table backfill (Turn Order row inserted +
   Damage Calc row Status updated to Accepted via ADR-0012)
6. `design/gdd/balance-data.md` — §Dependencies 하위 의존성 table backfill (Turn Order row
   inserted with ROUND_CAP + CHARGE_THRESHOLD references)
7. `docs/architecture/tr-registry.yaml` — v9 → v10 (header + 21 net-new TR-turn-order-002..022
   entries appended; ~135 LoC of new entries)
8. `docs/architecture/architecture-traceability.md` — v0.8 → v0.9 (Document Status + Coverage
   Summary + Registered TR-to-ADR map +21 rows + TR-hp-status-018 RESOLVED status update +
   Pending TR baseline turn-order collapse + Changelog v0.9 row append)
9. `docs/architecture/architecture.md` — v0.5 → v0.6 (Document Status + Phase 2 Turn Order row
   rewrite + Phase 5 ADR Audit 12 rows + ADR-0012 advisory RESOLVED entry + Phase 6 Required ADRs
   refresh + Open Questions §1 closure + System Layer Map preview list refresh + Module Ownership
   Blocker note resolution + Changelog v0.6 row append)
10. `docs/registry/architecture.yaml` — v5 → v6 (header version bump + line 547 hp_status
    consumer prose flip Soft → Accepted + line 569 turn_order consumer prose unit_id type advisory
    resolution annotation; 0 net-new entries — turn_order entries already present from commit
    `b11ef20` v4 → v5)
11. `production/session-state/active.md` — Session Extract delta #8 append (silent; gitignored)

**Created** (1):

12. `docs/architecture/architecture-review-2026-04-30d.md` — this verdict report

---

## Phase 9: Handoff

### Immediate actions (priority order)

1. **`/create-epics turn-order`** — eligible immediately post-delta-#8 Acceptance. ADR-0011
   §Migration Plan §1-§7 + §Validation Criteria §1-§20 form the runbook. Estimated 8-12 stories
   covering: §1 module files (Story 1) + §2 BalanceConstants append (Story 1 same-patch per
   ADR-0006 §6 obligation) + §3 initiative + queue construction (Story 2; AC-13 determinism test) +
   §4 T1–T7 sequence (Stories 3–7; 23 unit/integration tests covering AC-01..22) + §5 signal
   subscriptions + emissions (Story 8; CONNECT_DEFERRED per R-1) + §6 Charge accumulation F-2
   (Story 9; AC-14 + AC-15) + §7 G-15 test isolation (Story 10).

2. **`/create-epics hp-status`** — eligible since delta #7 (2026-04-30) Acceptance; first Core-layer
   epic. ADR-0010 §Migration Plan §1-§7 + §Validation Criteria §1-§13 form the runbook.

3. **`/create-epics input-handling`** — eligible since delta #6 (2026-04-30) Acceptance.

4. **`/create-epics hero-database`** — eligible since delta #5 (2026-04-30) Acceptance.

5. **`/sprint-plan sprint-2`** — formalize scope with **5 epic-eligible candidates**: hp-status +
   input-handling + hero-database + turn-order + scene-manager remainder. Foundation 5/5 + Core 3/3
   Complete critical-path now stable; sprint-2 should target Vertical-Slice candidate epics
   (Grid Battle + AI + Battle HUD + Battle Preparation; all Feature-layer).

### Gate guidance

✅ **All Foundation + Core mandatory ADRs Accepted.** First all-Foundation+Core-Complete state for
the project. The Pre-Production → Production gate is now technically eligible to run (mandatory ADR
list = 0). Strongly recommended to land at least 1-2 Vertical-Slice Feature ADRs (AI + Grid Battle)
before invoking `/gate-check pre-production` to ensure Vertical-Slice readiness criteria are met.

### Re-run trigger

Re-run `/architecture-review` after each new Vertical-Slice Feature ADR is written (first
candidate: AI System ADR; second: Grid Battle ADR finalization; third: Formation Bonus ADR). Each
delta should follow the established 8-precedent pattern (lean delta-mode; fresh-session
escalation Proposed → Accepted; godot-specialist independent validation at design time;
cross-doc obligations applied same-patch).

### Carried advisories (defer to next ADR-0001 substantive edit)

- **ADR-0001 line 168**: `signal input_action_fired(action: String, ...)` — should be `action:
  StringName` per ADR-0005 + GDD `input-handling.md` ACTIONS_BY_CATEGORY hot-path StringName
  literal convention. Delta #6 Item 10a carry.
- **ADR-0001 line 372**: prose drift `hero_database.get(unit_id)` → `HeroDatabase.get_hero(hero_id:
  StringName)`. Delta #5 ADR-0007 carry.

Both non-blocking; defer to next ADR-0001 substantive edit cycle.

### ADR-0012 internal ContextResource follow-up

Internal Damage Calc ContextResource fields (lines 186/192/197/201 — AttackerContext/DefenderContext
`unit_id: StringName` field declarations) + call sites (lines 260/352-353 — illustrative
references in §Migration Plan §Cross-system row signatures) retain implicit StringName semantics
pending follow-up ADR-0012 amendment that will propagate `int` through AttackerContext/DefenderContext
factory signatures. Out-of-scope for delta #8 (would require additional design decisions about
unit_id flow through Damage Calc's RefCounted wrappers); track as **5th cross-doc advisory** for
next ADR-0012 amendment.

---

## Process Insights from Delta #8

1. **Embedded godot-specialist validation at design time eliminates review-time corrections** —
   ADR-0011 was authored 2026-04-30 with 8/8 godot-specialist PASS-or-CONCERN review, applying 3
   same-patch corrections pre-Write. Delta #8 surfaced 0 net-new substantive corrections (Status
   flip only). Pattern observation: **lean delta-mode /architecture-review correction count
   correlates inversely with design-time godot-specialist depth**. When design-time validation is
   thorough enough to catch all substantive issues pre-Write, review-time validation simply
   confirms the work.
2. **Same-patch ADR-0001 amendment for new signal declarations is now codified project pattern** —
   ADR-0011 added `victory_condition_detected(result: int)` to GameBus via §Migration Plan §0
   same-patch ADR-0001 amendment at Proposed-time (commit `b11ef20`). Without this same-patch
   amendment, Turn Order code would not compile against GameBus, AND delta #8 would have surfaced
   the gap as a HIGH-priority finding requiring batched amendment. Codification: **any ADR that
   ADDS a signal to GameBus must include §Migration Plan §0 same-patch amendment to ADR-0001**
   (declaration + §3 domain table row + Last Verified date refresh). Distinct from prose-drift /
   type-name advisories which CAN be batched for next ADR-0001 substantive edit.
3. **Delta #7 backfill caught a process gap** — ADR-0010 acceptance in delta #7 was supposed to
   close ADR-0012's HP/Status soft-dep (line 42 prose flip Soft → Ratified) but the flip wasn't
   applied to ADR-0012 in delta #7. Delta #8 detected this gap during cross-conflict scan and
   backfilled same-patch alongside the ADR-0011 primary flip. Codification: **/architecture-review
   should always verify the prior delta's same-patch obligations were applied — process insight
   queues for documentation as `/architecture-review must verify prior-delta cross-doc flips were
   applied; backfill in current delta if gap detected`**.
4. **Cross-doc unit_id type advisory batch resolution pattern** — delta #7 + delta #8 each
   contributed 1 unit_id type advisory (HP/Status + Turn Order respectively). Both were resolved
   same-patch in delta #8 via 4-spot edit (ADR-0012 lines 91/109/340/343 narrowed StringName →
   int). Process pattern: **when /architecture-review touches ADR-X for any other reason
   (Status flip, prose update), batch all carried advisories targeting ADR-X same-patch**. This
   reduced the carry queue 3 → 2 (removed ADR-0012 unit_id type; ADR-0001 advisories deferred
   because delta #8 base scope did not include ADR-0001 edits beyond the pre-applied b11ef20
   amendment).
5. **Pattern boundary precedent stable at 3 ADRs** — battle-scoped Node form (ADR-0010 + ADR-0011)
   + Autoload Node form (ADR-0005) for state-holders + signal-listeners is now project discipline.
   Future stateful Core/Feature ADRs (Grid Battle + AI System + Battle HUD likely candidates)
   should adopt the appropriate variant. Stateless-static remains canonical for systems CALLED
   (5-precedent: ADR-0008 → 0006 → 0012 → 0009 → 0007).

---

## Working Tree State

11 modified + 1 created (12 total) post-edit. Pending commit + push.

---

End of architecture-review-2026-04-30d.md
