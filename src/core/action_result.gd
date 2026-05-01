class_name ActionResult
## ActionResult — typed return value for TurnOrderRunner.declare_action().
##
## 4th RefCounted wrapper class for the turn-order module. Same-patch ADR-0011
## §State Ownership wrapper count amendment (3 → 4 wrappers) handled by
## orchestrator post-write — DO NOT modify ADR yourself.
##
## RULES:
##  - success=true  → side_effects MAY contain payloads; error_code == 0 (NONE).
##  - success=false → error_code IS the rejection reason; side_effects is empty.
##  - side_effects is an untyped Array per ADR-0011 §Decision (heterogeneous payload
##    for future HP/Status SE-3 / counter-attack notifications — story-005+).
##  - error_code is typed int (NOT TurnOrderRunner.ActionError) to avoid forward-
##    reference circular import: TurnOrderRunner uses ActionResult; ActionResult
##    would re-use TurnOrderRunner.ActionError → circular. Tests cast:
##        result.error_code as TurnOrderRunner.ActionError
##
## Static factory methods (make_success / make_failure) are the canonical
## construction path — do NOT construct ActionResult via ActionResult.new() + manual
## field assignment in production code.
##
## See ADR-0011 §Key Interfaces — declare_action return type.
extends RefCounted

# ── Public variables ───────────────────────────────────────────────────────────

## True if the action was accepted and the token was spent; false on rejection.
var success: bool = false

## TurnOrderRunner.ActionError enum int backing value.
## 0 = ActionError.NONE (success sentinel).
## Non-zero values are mutually exclusive failure modes (INVALID_ACTION_TYPE,
## TOKEN_ALREADY_SPENT, MOVE_LOCKED_BY_DEFEND_STANCE, UNIT_NOT_FOUND, NOT_UNIT_TURN).
var error_code: int = 0

## Heterogeneous payload for successful actions.
## story-004: always empty (ActionTarget validation deferred to story-007+).
## story-005+: may contain HP/Status SE-3 application notifications, charge updates, etc.
var side_effects: Array = []

# ── Static factory methods ─────────────────────────────────────────────────────

## Creates a successful ActionResult with an optional side-effects payload.
## error_code is set to 0 (ActionError.NONE).
##
## Usage:
##     return ActionResult.make_success()
##     return ActionResult.make_success([{"type": "status_applied", "effect_id": &"defend_stance"}])
static func make_success(side_effects_payload: Array = []) -> ActionResult:
	var r: ActionResult = ActionResult.new()
	r.success = true
	r.error_code = 0  # ActionError.NONE
	r.side_effects = side_effects_payload
	return r


## Creates a failed ActionResult with the given error code.
## side_effects is empty for all failure paths.
##
## Usage:
##     return ActionResult.make_failure(TurnOrderRunner.ActionError.TOKEN_ALREADY_SPENT as int)
static func make_failure(error_code_value: int) -> ActionResult:
	var r: ActionResult = ActionResult.new()
	r.success = false
	r.error_code = error_code_value
	r.side_effects = []
	return r
