## DefaultDestinyBranchJudge — concrete subclass of DestinyBranchJudge.
##
## SPRINT-7 S7-02 STATUS: STUB IMPLEMENTATION. The full F-DB-1 algorithm body
## (echo-gate predicate + branch_table lookup + invariant_violation:* vocabulary)
## is owned by destiny-branch S7-03 (ADR-0018 §Migration Plan §5).
##
## Current stub returns the chapter's canonical_branch_key as a minimal F-DB-3
## contract sufficient for ScenarioRunner BEAT_7_JUDGMENT entry to compile +
## chapter-1 stub fixture tests to pass. Real F-DB-1 algorithm replaces this body
## (NOT extends — destiny-branch S7-03 patch overwrites _apply_f_sp_1).
##
## Tests injecting non-canonical-branch behaviour use TestDestinyBranchJudgeWithSp1Stub
## (tests/helpers/destiny_branch_judge_stub.gd).
##
## ADR: ADR-0018 §Decision §DefaultDestinyBranchJudge.
## TR: TR-destiny-branch-001 (DestinyBranchJudge concrete subclass).
class_name DefaultDestinyBranchJudge
extends DestinyBranchJudge


## Stub F-DB-1 implementation. Returns canonical-branch result for chapter-1 stub.
## destiny-branch S7-03 will REPLACE this body with the full algorithm per ADR-0018.
func _apply_f_sp_1(
		chapter: ChapterDefinition,
		outcome: BattleOutcome.Result,
		_echo_count: int,
		_first_attempt_resolved: bool,
) -> Dictionary:
	# Minimal F-DB-3 contract: return canonical branch_key + flags.
	# For LOSS/DRAW outcomes, look up branch_table; for WIN, use canonical.
	var branch_key: String = chapter.canonical_branch_key
	var lookup_key: String = ""
	match outcome:
		BattleOutcome.Result.WIN:
			lookup_key = "WIN_default"
		BattleOutcome.Result.LOSS:
			lookup_key = "LOSS_default"
		BattleOutcome.Result.DRAW:
			lookup_key = "DRAW_default" if chapter.author_draw_branch else "WIN_default"
	if chapter.branch_table.has(lookup_key):
		branch_key = chapter.branch_table[lookup_key] as String
	var is_canonical: bool = (branch_key == chapter.canonical_branch_key)
	var is_draw_fallback: bool = (
		outcome == BattleOutcome.Result.DRAW
		and not chapter.author_draw_branch
	)
	# F-DB-2: reserved_color_treatment fires only for non-canonical WIN paths
	# that are NOT draw-fallback (per art-bible §4.7).
	var reserved_color: bool = (
		not is_canonical
		and outcome == BattleOutcome.Result.WIN
		and not is_draw_fallback
	)
	return {
		"branch_key": branch_key,
		"is_canonical_history": is_canonical,
		"is_draw_fallback": is_draw_fallback,
		"reserved_color_treatment": reserved_color,
		"is_invalid": false,
		"invalid_reason": &"",
	}
