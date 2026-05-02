# Story 009: Cross-ADR _exit_tree audit — TD-057 final resolution

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Config/Data (audit + Path B retrofit) | **Estimate**: 1h
> **ADR**: ADR-0013 R-7 follow-up + ADR-0014 R-7 + TD-057

## Acceptance Criteria

- [x] **AC-1** Verified ADR-0010 HPStatusController `_exit_tree()` exists at `src/core/hp_status_controller.gd:45-47` with `GameBus.unit_turn_started.disconnect(_on_unit_turn_started)`. `_ready()` (line 40-42) connects exactly 1 autoload signal (`unit_turn_started`); disconnect set is COMPLETE (1 connect → 1 disconnect)
- [x] **AC-2** Verified ADR-0011 TurnOrderRunner `_exit_tree()` was **MISSING pre-audit**. Connection at `initialize_battle:188` (`GameBus.unit_died.connect(_on_unit_died, CONNECT_DEFERRED)`) had no symmetric disconnect — latent leak confirmed
- [x] **AC-3** **Path B taken**: TurnOrderRunner retrofitted in same patch — added `_exit_tree()` body at `src/core/turn_order_runner.gd` (after `_round_state` field, before `initialize_battle`) calling `GameBus.unit_died.disconnect(_on_unit_died)` with `is_connected` idempotent guard. TD-057 entry logged in `docs/tech-debt-register.md`
- [x] **AC-4** N/A — Path A not taken (TurnOrderRunner did need retrofit)
- [x] **AC-5** `docs/tech-debt-register.md` TD-057 entry: status RESOLVED 2026-05-03 with full audit findings table (4 systems × disconnect status) + verification report
- [x] **AC-6** Cross-links updated:
  - ADR-0013 R-6 → "RESOLVED 2026-05-03 via grid-battle-controller story-009 audit"
  - ADR-0014 R-7 → "RESOLVED 2026-05-03"
  - ADR-0014 §Implementation Notes (HPStatusController._exit_tree entry) → "Story-009 audit outcome" + retrofit summary + 4-invocation pattern stability marker
- [x] **AC-7** No new test file added per story spec. Smoke check (full regression suite) PASS post-retrofit: **837 / 0 errors / 0 failures / 0 orphans / Exit 0** (18th consecutive failure-free baseline)

## Implementation Notes

*Per ADR-0013 R-7 + ADR-0014 R-7 + ADR-0014 Implementation Notes section:*

1. **Audit scope**: 2 systems × 1 question each = "Does `_exit_tree()` exist + does it explicitly disconnect every autoload-sourced subscription set up in `_ready()`?"
2. **HPStatusController status (verified at ADR-0014 authoring)**: `_exit_tree()` line 45 has `GameBus.unit_turn_started.disconnect(_on_unit_turn_started)`. Story-009 verifies the disconnect set is COMPLETE (matches all `_ready()` autoload connects).
3. **TurnOrderRunner status (unverified)**: comment at line 115 of `src/core/turn_order_runner.gd` mentions "test isolation reset must disconnect" — that's about test cleanup, NOT production `_exit_tree()`. Story-009 reads the file fresh and verifies presence/absence.
4. **TD-057 outcome paths**:
   - **Path A (both clean)**: TD-057 status = RESOLVED (false alarm). Pattern stable at 4 invocations. No retrofit.
   - **Path B (TurnOrderRunner needs retrofit)**: ship the retrofit in same patch as story-009 — single `_exit_tree()` body addition. Then TD-057 = RESOLVED (TurnOrderRunner retrofit).
5. **Cross-ADR link updates**: edit ADR-0013 R-7 + ADR-0014 R-7 + ADR-0014 Implementation Notes section to add "RESOLVED via grid-battle-controller story-009 audit (2026-05-XX)".

## Test Evidence

**Story Type**: Config/Data (audit producing documentation updates; no production code change in Path A; small `_exit_tree` retrofit in Path B)
**Required evidence**: smoke check (full regression PASS post-audit) + tech-debt-register entry update + cross-ADR doc updates
**Status**: [x] Shipped 2026-05-03 — Path B retrofit. 837 PASS / 0 errors / 0 failures / 0 orphans / Exit 0 (18th failure-free baseline). TD-057 RESOLVED. Cross-ADR markers updated.

## Dependencies

- **Depends on**: Story 001 (GridBattleController _exit_tree as 4th invocation precedent in evidence chain)
- **Unlocks**: TD-057 closure; pattern stability documentation
