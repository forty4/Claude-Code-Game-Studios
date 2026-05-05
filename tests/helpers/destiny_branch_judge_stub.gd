## TestDestinyBranchJudgeWithSp1Stub — test-only DestinyBranchJudge subclass.
##
## Returns a caller-provided F-DB-3 contract Dictionary instead of running the
## real F-DB-1 algorithm. Used by ScenarioRunner unit tests that want to inject
## specific branch resolution outcomes without driving the full chapter +
## branch_table state.
##
## Usage:
##   var judge: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
##   judge.set_sp1_output({
##       "branch_key": "TEST_branch",
##       "is_canonical_history": false,
##       "is_draw_fallback": false,
##       "reserved_color_treatment": true,
##       "is_invalid": false,
##       "invalid_reason": &"",
##   })
##   var choice: DestinyBranchChoice = judge.resolve(chapter, outcome, 0, true)
##   # choice.branch_key == "TEST_branch"
##
## Coordinated with destiny-branch S7-03 — shared helper file. S7-03 may extend
## this with additional injection methods but MUST NOT break the set_sp1_output()
## contract used by S7-02 unit tests.
class_name TestDestinyBranchJudgeWithSp1Stub
extends DestinyBranchJudge


var _stub_output: Dictionary = {
	"branch_key": "",
	"is_canonical_history": false,
	"is_draw_fallback": false,
	"reserved_color_treatment": false,
	"is_invalid": false,
	"invalid_reason": &"",
}


## Sets the F-DB-3 contract Dictionary returned by _apply_f_sp_1.
func set_sp1_output(output: Dictionary) -> void:
	_stub_output = output.duplicate(true)


## Override returns the stub output instead of running F-DB-1.
func _apply_f_sp_1(
		_chapter: ChapterDefinition,
		_outcome: BattleOutcome.Result,
		_echo_count: int,
		_first_attempt_resolved: bool,
) -> Dictionary:
	return _stub_output.duplicate(true)
