## DefaultDestinyBranchJudge — production concrete subclass of DestinyBranchJudge.
##
## Implements F-DB-1 algorithm body in `_apply_f_sp_1`. Pre/post-call invariant
## guards live in the base class `resolve()`. F-DB-2 reserved_color_treatment
## derivation also lives in `resolve()` (post-result derivation).
##
## F-DB-1 algorithm (4-row decision per ADR-0017 §F-SP-1):
##   Row 1: outcome == DRAW AND NOT chapter.author_draw_branch
##          → DRAW fallback to WIN row; is_draw_fallback=true
##   Row 2: outcome == WIN
##          → WIN_default row; cue tag for win_after_persistence (presentation hint only)
##   Row 3: outcome == DRAW (with author_draw_branch=true)
##          → DRAW row; echo-gate predicate F-SP-2 routes to default vs echo branch
##   Row 4: outcome == LOSS
##          → LOSS_default row
##
## ADR: ADR-0017 §F-SP-1 (algorithm spec) + ADR-0018 §Decision (executor class).
## TR: TR-destiny-branch-001..015.
class_name DefaultDestinyBranchJudge
extends DestinyBranchJudge


## F-DB-1 algorithm — branch_table lookup via 4-row decision logic.
func _apply_f_sp_1(
		chapter: ChapterDefinition,
		outcome: BattleOutcome.Result,
		echo_count: int,
		first_attempt_resolved: bool,
) -> Dictionary:
	var branch_table: Dictionary = chapter.branch_table
	# Row 1: DRAW outcome + chapter has no DRAW branch authored → fallback to WIN.
	if outcome == BattleOutcome.Result.DRAW and not chapter.author_draw_branch:
		var fallback_key: String = branch_table.get("WIN_default", "") as String
		if fallback_key.is_empty():
			# WIN row missing — return empty to trigger post-call invariant guard.
			return _empty_result()
		return {
			"branch_key": fallback_key,
			"is_draw_fallback": true,
			"is_canonical_history": (fallback_key == chapter.canonical_branch_key),
		}
	# Row 2: WIN outcome → WIN_default row.
	if outcome == BattleOutcome.Result.WIN:
		var win_key: String = branch_table.get("WIN_default", "") as String
		if win_key.is_empty():
			return _empty_result()
		return {
			"branch_key": win_key,
			"is_draw_fallback": false,
			"is_canonical_history": (win_key == chapter.canonical_branch_key),
		}
	# Row 3: DRAW outcome (with author_draw_branch=true) → echo-gate routing.
	if outcome == BattleOutcome.Result.DRAW:
		var draw_key: String
		if _is_echo_gate_open(echo_count, chapter.echo_threshold, first_attempt_resolved):
			# Echo-gate open: prefer DRAW_echo row; fallback to DRAW_default if absent.
			draw_key = branch_table.get("DRAW_echo", "") as String
			if draw_key.is_empty():
				draw_key = branch_table.get("DRAW_default", "") as String
		else:
			draw_key = branch_table.get("DRAW_default", "") as String
		if draw_key.is_empty():
			return _empty_result()
		return {
			"branch_key": draw_key,
			"is_draw_fallback": false,
			"is_canonical_history": (draw_key == chapter.canonical_branch_key),
		}
	# Row 4: LOSS outcome → LOSS_default row.
	if outcome == BattleOutcome.Result.LOSS:
		var loss_key: String = branch_table.get("LOSS_default", "") as String
		if loss_key.is_empty():
			return _empty_result()
		return {
			"branch_key": loss_key,
			"is_draw_fallback": false,
			"is_canonical_history": (loss_key == chapter.canonical_branch_key),
		}
	# Outcome enum out of {WIN, DRAW, LOSS} — pre-call guard should have caught.
	return _empty_result()


## F-SP-2 echo-gate predicate (CR-6 formalized).
## Returns true iff DRAW outcome with sufficient echo accumulation AND
## first_attempt_resolved is false (anti-farm protection).
func _is_echo_gate_open(echo_count: int, echo_threshold: int, first_attempt_resolved: bool) -> bool:
	return (echo_count >= echo_threshold) and (not first_attempt_resolved)


## Returns an empty result Dictionary that triggers
## INVALID_BRANCH_TABLE_MISSING_OUTCOME in the base class post-call guard.
func _empty_result() -> Dictionary:
	return {
		"branch_key": "",
		"is_draw_fallback": false,
		"is_canonical_history": false,
	}
