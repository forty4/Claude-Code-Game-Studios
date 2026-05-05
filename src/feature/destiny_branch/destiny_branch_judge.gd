## DestinyBranchJudge — @abstract base class for destiny branch resolution.
##
## Owns the callable signature for F-SP-1 (resolve_branch) per ADR-0017 §Decision
## §F-SP-1/F-SP-2 Execution. Concrete implementation lives in
## DefaultDestinyBranchJudge (stub for S7-02; full F-DB-1 algorithm in S7-03).
##
## LIFECYCLE: instantiated transiently at BEAT_7_JUDGMENT entry per ADR-0017:
##   var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()
##   var choice: DestinyBranchChoice = judge.resolve(chapter, outcome, echo_count, first_attempt_resolved)
## RefCounted scope drop reclaims memory after resolve() returns.
##
## FORBIDDEN: DestinyBranchJudge MUST NOT emit signals on GameBus
##   (forbidden_pattern: destiny_branch_judge_emits_gamebus_signal).
## FORBIDDEN: static var declarations (forbidden_pattern: destiny_branch_judge_static_var).
## FORBIDDEN: reading ScenarioRunner state directly
##   (forbidden_pattern: destiny_branch_judge_reads_scenario_runner_state — Pillar 2 lock).
##
## ADR: ADR-0017 §Decision + ADR-0018 §Decision §DestinyBranchJudge.
## TR: TR-scenario-progression-006 (DestinyBranchJudge @abstract interface).
@abstract
class_name DestinyBranchJudge
extends RefCounted


## Resolves the destiny branch choice for a given chapter + outcome + echo state.
##
## Calls _apply_f_sp_1 (abstract) which subclasses must implement to evaluate
## the F-SP-1 / F-SP-2 formula logic.
##
## [param chapter] The current chapter's definition (read-only).
## [param outcome] Battle outcome tri-state (WIN/DRAW/LOSS) — never coerced.
## [param echo_count] Current echo count for this chapter.
## [param first_attempt_resolved] True if this is the first battle attempt seal.
## [return] Populated DestinyBranchChoice with all 9 fields set.
func resolve(
		chapter: ChapterDefinition,
		outcome: BattleOutcome.Result,
		echo_count: int,
		first_attempt_resolved: bool,
) -> DestinyBranchChoice:
	var sp1_result: Dictionary = _apply_f_sp_1(
		chapter, outcome, echo_count, first_attempt_resolved
	)
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.chapter_id = chapter.chapter_id
	choice.outcome = outcome
	choice.echo_count = echo_count
	choice.branch_key = sp1_result.get("branch_key", "") as String
	choice.is_draw_fallback = sp1_result.get("is_draw_fallback", false) as bool
	choice.is_canonical_history = sp1_result.get("is_canonical_history", false) as bool
	choice.reserved_color_treatment = sp1_result.get("reserved_color_treatment", false) as bool
	choice.is_invalid = sp1_result.get("is_invalid", false) as bool
	choice.invalid_reason = sp1_result.get("invalid_reason", &"") as StringName
	return choice


## Abstract implementation hook for F-SP-1 + F-SP-2 formula evaluation.
##
## Subclasses MUST override this method. The returned Dictionary MUST contain
## these keys (F-DB-3 minimal contract):
##   branch_key: String
##   is_canonical_history: bool
##   is_draw_fallback: bool
##   reserved_color_treatment: bool
##   is_invalid: bool
##   invalid_reason: StringName
##
## [param chapter] Chapter definition (read-only; do not mutate branch_table).
## [param outcome] Battle outcome tri-state.
## [param echo_count] Echo count for this chapter.
## [param first_attempt_resolved] Sealed boolean from ScenarioRunner BEAT_7 entry.
## [return] Dictionary satisfying F-DB-3 minimal contract.
@abstract
func _apply_f_sp_1(
		chapter: ChapterDefinition,
		outcome: BattleOutcome.Result,
		echo_count: int,
		first_attempt_resolved: bool,
) -> Dictionary
