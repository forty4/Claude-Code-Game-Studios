class_name BattleUnit
## BattleUnit — minimal roster entry passed to TurnOrderRunner.initialize_battle().
##
## Ratified by ADR-0011 §Decision §Public mutator API + §Migration Plan §3.
## Soft-dep on Battle Preparation ADR (unwritten at story-002 time). When the
## Battle Preparation ADR ships, this stub will be replaced by a richer type;
## the `initialize_battle(unit_roster: Array[BattleUnit])` contract is
## parameter-stable per ADR-0011 §Migration Plan §3 — callers need not change.
##
## RefCounted (NOT Resource) — battle-scoped runtime reference per ADR-0011 CR-1b
## lifecycle alignment (mirrors UnitTurnState + UnitHPState rationale).
##
## RULES:
##  - All 4 fields are public (no getters/setters) — owned by Battle Preparation
##    caller; TurnOrderRunner reads them read-only during BI-1..BI-3.
##  - unit_id type LOCKED to int per ADR-0001 line 153 + ADR-0011 contract.
##  - hero_id type LOCKED to StringName per ADR-0007 §2 hero_id contract.
##  - unit_class stores UnitRole.UnitClass enum int per CR-4 + ADR-0009.
##  - Production code MUST NOT add fields here without a Battle Preparation ADR
##    amendment — this stub shape is the published API boundary.
extends RefCounted

# ── Public variables ───────────────────────────────────────────────────────────

## Unique unit identifier for this battle instance. int per ADR-0001 + ADR-0011 lock.
## Assigned by Battle Preparation; must be unique within a single battle roster.
var unit_id: int = 0

## Hero identifier — links to HeroDatabase record for stat lookup at BI-2/BI-3.
## StringName per ADR-0007 §2 hero_id format (`^[a-z]+_\d{3}_[a-z_]+$`).
var hero_id: StringName = &""

## Unit class as UnitRole.UnitClass int backing value [0, 5].
## Stored as int per ADR-0009 + ADR-0007 §2 cross-script @export int convention.
## Cross-doc: int values align 1:1 with UnitRole.UnitClass enum backing values.
var unit_class: int = 0

## True if this unit is controlled by the human player; false if AI-controlled.
## Interleaved queue (CR-1) makes ownership invisible to queue sort order at the
## initiative level; is_player_controlled is the F-1 Step 3 tie-break only.
var is_player_controlled: bool = false
