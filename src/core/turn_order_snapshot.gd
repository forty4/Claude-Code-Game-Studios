class_name TurnOrderSnapshot
## TurnOrderSnapshot — pull-based read-only snapshot of the turn queue.
##
## Ratified by ADR-0011 §Decision §Typed Resource / wrapper definitions.
## RefCounted (NOT Resource) — battle-scoped non-persistent per CR-1b.
## Pure value semantics: consumers (Battle HUD, AI) cannot mutate
## TurnOrderRunner._queue or _unit_states via this snapshot
## (forbidden_pattern: turn_order_consumer_mutation — ADR-0011 §Decision).
##
## Consumers call TurnOrderRunner.get_turn_order_snapshot() which returns a
## deep copy built from the live queue. Pull-based — Battle HUD calls on
## round_started / unit_turn_ended / unit_died receipts per Contract 3.
##
## See ADR-0011 §Decision §Key Interfaces for full specification.
extends RefCounted

# ── Public variables ───────────────────────────────────────────────────────────

## Current round number at snapshot time. Mirrors TurnOrderRunner._round_number.
var round_number: int = 0

## Ordered queue of entries for this round, sorted by initiative cascade (F-1).
## Each entry is a TurnOrderEntry RefCounted wrapper (pure value semantics).
var queue: Array[TurnOrderEntry] = []
