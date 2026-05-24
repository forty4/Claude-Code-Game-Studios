## CivilianToken — battle-scoped data object representing one stranded civilian.
##
## Owned by GridBattleController; lifetime = single battle. NO scene-tree
## presence (visualization is a separate sibling Node spawned by
## GridBattleController). 3-state machine — IDLE / ESCORTED / SAVED — with
## assert-guarded mutators (callers MUST verify prior state per ADR-0022 §1).
##
## ADR: ADR-0022 Civilian System (Stranded Escort Tokens). Spec:
## design/quick-specs/ch05-civilian-evacuation.md §3.1.
class_name CivilianToken
extends RefCounted

enum State { IDLE = 0, ESCORTED = 1, SAVED = 2 }

var token_id: int = -1
var state: State = State.IDLE
## IDLE: token's current cell. ESCORTED: stale write OK (carrier owns position).
## SAVED: terminal — value retained for trace, do not mutate.
var grid_cell: Vector2i = Vector2i.ZERO
## ESCORTED: bound carrier unit_id. IDLE/SAVED: -1.
var carrier_unit_id: int = -1


## Factory — IDLE at initial_cell, no carrier. token_id assigned sequentially
## by GridBattleController._civilian_spawn_from_config (0..N-1).
static func make(id: int, initial_cell: Vector2i) -> CivilianToken:
	var t := CivilianToken.new()
	t.token_id = id
	t.grid_cell = initial_cell
	return t


## IDLE → ESCORTED. Caller MUST verify state == IDLE and unit_id >= 0.
func bind_to_carrier(unit_id: int) -> void:
	assert(state == State.IDLE,
		"CivilianToken.bind_to_carrier: not IDLE (token_id=%d, state=%d)" % [token_id, state])
	assert(unit_id >= 0,
		"CivilianToken.bind_to_carrier: invalid unit_id (%d)" % unit_id)
	state = State.ESCORTED
	carrier_unit_id = unit_id


## ESCORTED → SAVED. Caller MUST verify state == ESCORTED AND carrier in
## evacuate-zone. Terminal transition — token despawns from active collection
## immediately after this call by GridBattleController._civilian_commit_save.
func commit_save() -> void:
	assert(state == State.ESCORTED,
		"CivilianToken.commit_save: not ESCORTED (token_id=%d, state=%d)" % [token_id, state])
	state = State.SAVED
	carrier_unit_id = -1


## ESCORTED → IDLE on carrier death. Caller provides recovery cell (carrier's
## last cell OR nearest non-occupied non-FIRE 4-neighbor per ADR-0022 §2).
func recover_to_idle(recovery_cell: Vector2i) -> void:
	assert(state == State.ESCORTED,
		"CivilianToken.recover_to_idle: not ESCORTED (token_id=%d, state=%d)" % [token_id, state])
	state = State.IDLE
	grid_cell = recovery_cell
	carrier_unit_id = -1
