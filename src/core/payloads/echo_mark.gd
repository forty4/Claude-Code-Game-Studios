## EchoMark — narrative-state entry accumulated across retry cycles.
##
## Ratified by ADR-0003 §Schema Stability. MUST extend Resource, declare
## class_name EchoMark, and annotate every persisted field with @export.
## Non-@export fields are SILENTLY DROPPED by ResourceSaver — see ADR-0003
## §Schema Stability for the BLOCKING invariant rationale.
##
## MVP schema is a 3-field baseline (beat_index, outcome, tag). Scenario
## Progression epic will evolve this via SaveMigrationRegistry (story-006).
##
## This file replaces the gamebus story-002 PROVISIONAL stub. The path
## src/core/payloads/echo_mark.gd is the historically-pinned location; the
## "Destiny State GDD #16" note in the prior stub header has been superseded
## by ADR-0003 §Schema Stability §EchoMark Resource Contract (BLOCKING).
class_name EchoMark
extends Resource

## 1-indexed beat index at which this EchoMark was accumulated (1..9).
@export var beat_index: int = 0

## Beat outcome identifier (StringName; schema evolves with scenario-progression).
@export var outcome: StringName = &""

## Narrative tag for downstream scenario-progression queries.
@export var tag: StringName = &""
