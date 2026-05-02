# Story 009: Cross-ADR _exit_tree audit — TD-057 final resolution

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Config/Data (audit) | **Estimate**: 1h
> **ADR**: ADR-0013 R-7 follow-up + ADR-0014 R-7 + TD-057 candidate

## Acceptance Criteria

- [ ] **AC-1** Verify ADR-0010 HPStatusController `_exit_tree()` exists with autoload-disconnect (already verified at ADR-0014 authoring 2026-05-02 — line 45 of `src/core/hp_status_controller.gd` has `GameBus.unit_turn_started.disconnect(_on_unit_turn_started)`); story-009 confirms still present and properly disconnects ALL autoload-source subscriptions (not just unit_turn_started — check entire `_ready()` body for connect calls and verify each has matching disconnect)
- [ ] **AC-2** Verify ADR-0011 TurnOrderRunner `_exit_tree()` exists with autoload-disconnect — read `src/core/turn_order_runner.gd` (line 115 mentions "test isolation reset must disconnect" but actual `_exit_tree` body status unverified at ADR-0014 authoring); confirm body present + all autoload subscriptions disconnected
- [ ] **AC-3** If TurnOrderRunner missing `_exit_tree()` autoload-disconnect: log TD-057 entry in `docs/tech-debt-register.md` with HIGH severity (latent leak in production-shipped code; battle-scene-end frees TurnOrderRunner but GameBus retains callable); resolution path = retrofit `_exit_tree()` body in same patch as story-009
- [ ] **AC-4** If TurnOrderRunner has `_exit_tree()` already: close TD-057 candidate as "false alarm — both battle-scoped Nodes (HPStatusController + TurnOrderRunner) ALREADY have _exit_tree autoload-disconnect cleanup; no retrofit needed; pattern stable at 4 invocations including ADR-0013 BattleCamera + ADR-0014 GridBattleController"
- [ ] **AC-5** Update `docs/tech-debt-register.md`: TD-057 status → either "RESOLVED 2026-05-02 (false alarm)" OR "RESOLVED 2026-05-XX (TurnOrderRunner retrofit shipped in story-009)" depending on AC-2 outcome
- [ ] **AC-6** Cross-link audit result back to ADR-0013 R-7 + ADR-0014 R-7 + ADR-0014 §Implementation Notes (the section that flagged "HPStatusController._exit_tree ALREADY EXISTS — partial false alarm; only TurnOrderRunner audit remains"); update each ADR's §Risks subsection with "RESOLVED via grid-battle-controller story-009 audit"
- [ ] **AC-7** No new test file required — this is an audit story producing documentation updates only. Existing regression suite must remain ≥757/0/0/0/0/0 PASS

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
**Status**: [ ] Not yet executed

## Dependencies

- **Depends on**: Story 001 (GridBattleController _exit_tree as 4th invocation precedent in evidence chain)
- **Unlocks**: TD-057 closure; pattern stability documentation
