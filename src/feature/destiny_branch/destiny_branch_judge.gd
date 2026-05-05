## DestinyBranchJudge — @abstract base class for destiny branch resolution.
##
## Owns the callable signature for F-SP-1 (resolve_branch) per ADR-0017 §F-SP-1
## + ADR-0018 §Decision §DestinyBranchJudge. Concrete implementation in
## DefaultDestinyBranchJudge ships the F-DB-1 algorithm body.
##
## RESPONSIBILITY SPLIT:
##   - resolve()  — public entry; runs pre-call invariant guards + dispatches to
##                  _apply_f_sp_1() + runs post-call invariant guards on returned
##                  Dictionary + applies F-DB-2 reserved_color_treatment derivation.
##   - _apply_f_sp_1()  — @abstract subclass hook; implements the F-DB-1
##                        branch_table lookup algorithm (4-row Decision A logic).
##
## LIFECYCLE: instantiated transiently at BEAT_7_JUDGMENT entry per ADR-0017:
##   var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()
##   var choice: DestinyBranchChoice = judge.resolve(chapter, outcome, echo_count, first_attempt_resolved)
## RefCounted scope drop reclaims memory after resolve() returns.
##
## DETERMINISM (CR-DB-2 + CR-DB-11): no static var, no instance state across
## calls, no RNG, no wall-clock dependency, no autoload state read. Verified via
## V-12 thread-safety integration test (2 instances × 1000 concurrent calls).
##
## FORBIDDEN (CI lint enforced):
##   - GameBus signal emission (lint: destiny_branch_judge_emits_gamebus_signal)
##   - static var declaration (lint: destiny_branch_judge_static_var)
##   - reading ScenarioRunner state (lint: destiny_branch_judge_reads_scenario_runner_state
##     — Pillar 2 architectural lock 3rd precedent)
##
## ADR: ADR-0018 §Decision §DestinyBranchJudge.
## TR: TR-destiny-branch-001..015.
@abstract
class_name DestinyBranchJudge
extends RefCounted


# ─── F-DB-3 invariant_violation:* vocabulary (12 entries closed set) ──────────

const INVALID_CHAPTER_NULL: StringName = &"invariant_violation:chapter_null"
const INVALID_CHAPTER_ID_MISSING: StringName = &"invariant_violation:chapter_id_missing"
const INVALID_DEFAULT_BRANCH_KEY_MISSING: StringName = &"invariant_violation:default_branch_key_missing"
const INVALID_BRANCH_TABLE_NULL_OR_MALFORMED: StringName = &"invariant_violation:branch_table_null_or_malformed"
const INVALID_BRANCH_TABLE_EMPTY: StringName = &"invariant_violation:branch_table_empty"
const INVALID_BRANCH_TABLE_MISSING_OUTCOME: StringName = &"invariant_violation:branch_table_missing_outcome"
const INVALID_BRANCH_KEY_TYPE_INVALID: StringName = &"invariant_violation:branch_key_type_invalid"
const INVALID_IS_DRAW_FALLBACK_TYPE_INVALID: StringName = &"invariant_violation:is_draw_fallback_type_invalid"
const INVALID_IS_CANONICAL_HISTORY_TYPE_INVALID: StringName = &"invariant_violation:is_canonical_history_type_invalid"
const INVALID_IS_DRAW_FALLBACK_OUTCOME_MISMATCH: StringName = &"invariant_violation:is_draw_fallback_outcome_mismatch"
const INVALID_OUTCOME_UNKNOWN: StringName = &"invariant_violation:outcome_unknown"
const INVALID_CR13_ECHO_THRESHOLD_ON_CH1: StringName = &"invariant_violation:cr13_echo_threshold_on_ch1"


## Resolves the destiny branch choice for a given chapter + outcome + echo state.
##
## Pre-call invariant guards (F-DB-3 12-entry vocabulary) run before _apply_f_sp_1
## delegation. Post-call invariant guards run on the returned Dictionary. F-DB-2
## reserved_color_treatment derivation runs after both.
##
## [param chapter] The current chapter's definition (read-only). May be null.
## [param outcome] Battle outcome tri-state (WIN/DRAW/LOSS) — never coerced.
## [param echo_count] Current echo count for this chapter.
## [param first_attempt_resolved] Already-sealed value from ScenarioRunner per
##                                F-SP-3 v2.2 + Pillar 2 lock (judge MUST NOT read
##                                from ScenarioRunner state — receives via 4th arg).
## [return] Populated DestinyBranchChoice with all 9 fields set; is_invalid=true
##          + invalid_reason populated on any guard failure.
func resolve(
		chapter: ChapterDefinition,
		outcome: BattleOutcome.Result,
		echo_count: int,
		first_attempt_resolved: bool,
) -> DestinyBranchChoice:
	# Step 1: Pre-call invariant guards (F-DB-3 vocabulary entries 1-6).
	var pre_call_violation: StringName = _check_pre_call_invariants(chapter, outcome)
	if pre_call_violation != &"":
		if pre_call_violation == INVALID_CR13_ECHO_THRESHOLD_ON_CH1:
			push_error("DestinyBranchJudge: cr13_echo_threshold_on_ch1 — Ch1 must not declare echo_threshold")
		return DestinyBranchChoice.invalid(pre_call_violation)
	# Step 2: Delegate to F-DB-1 algorithm.
	var sp1_result: Dictionary = _apply_f_sp_1(
		chapter, outcome, echo_count, first_attempt_resolved
	)
	# Step 3: Post-call invariant guards on Dictionary shape (F-DB-3 vocabulary entries 7-12).
	var post_call_violation: StringName = _check_post_call_invariants(sp1_result, outcome)
	if post_call_violation != &"":
		return DestinyBranchChoice.invalid(post_call_violation)
	# Step 4: Construct the populated DestinyBranchChoice (F-DB-2 derivation included).
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.chapter_id = chapter.chapter_id
	choice.outcome = outcome
	choice.echo_count = echo_count
	choice.branch_key = sp1_result["branch_key"] as String
	choice.is_draw_fallback = sp1_result["is_draw_fallback"] as bool
	choice.is_canonical_history = sp1_result["is_canonical_history"] as bool
	# F-DB-2 reserved_color_treatment derivation:
	#   reserved_color_treatment = (branch_key != canonical_branch_key) AND (NOT is_draw_fallback)
	# Step 4a fallback override: is_draw_fallback == true ⟹ reserved_color_treatment = false
	if choice.is_draw_fallback:
		choice.reserved_color_treatment = false
	else:
		choice.reserved_color_treatment = (choice.branch_key != chapter.canonical_branch_key)
	choice.is_invalid = false
	choice.invalid_reason = &""
	return choice


## Pre-call invariant guards (chapter shape + outcome). Returns "" on success
## or the invariant_violation:* StringName on failure.
func _check_pre_call_invariants(
		chapter: ChapterDefinition,
		outcome: BattleOutcome.Result,
) -> StringName:
	if chapter == null:
		return INVALID_CHAPTER_NULL
	if chapter.chapter_id.is_empty():
		return INVALID_CHAPTER_ID_MISSING
	if chapter.canonical_branch_key.is_empty():
		return INVALID_DEFAULT_BRANCH_KEY_MISSING
	# branch_table null/malformed: typed-Dict @export defaults to {} when malformed
	# at hydration time; but a programmatic test may inject null directly.
	# Use TYPE_DICTIONARY check via typeof() since untyped Dict @export.
	if typeof(chapter.branch_table) != TYPE_DICTIONARY:
		return INVALID_BRANCH_TABLE_NULL_OR_MALFORMED
	if chapter.branch_table.is_empty():
		return INVALID_BRANCH_TABLE_EMPTY
	# Outcome enum must be in {0, 1, 2}.
	var outcome_int: int = outcome as int
	if outcome_int < 0 or outcome_int > 2:
		return INVALID_OUTCOME_UNKNOWN
	# CR-13: Ch1 must NOT have echo_threshold > 0 (authoring invariant).
	if chapter.chapter_number == 1 and chapter.echo_threshold > 0:
		return INVALID_CR13_ECHO_THRESHOLD_ON_CH1
	return &""


## Post-call invariant guards on F-SP-1 output Dictionary. Returns "" on success
## or the invariant_violation:* StringName on failure.
func _check_post_call_invariants(
		sp1_result: Dictionary,
		outcome: BattleOutcome.Result,
) -> StringName:
	# Required keys present.
	if not sp1_result.has("branch_key"):
		return INVALID_BRANCH_TABLE_MISSING_OUTCOME
	if not sp1_result.has("is_draw_fallback"):
		return INVALID_IS_DRAW_FALLBACK_TYPE_INVALID
	if not sp1_result.has("is_canonical_history"):
		return INVALID_IS_CANONICAL_HISTORY_TYPE_INVALID
	# Type checks.
	if typeof(sp1_result["branch_key"]) != TYPE_STRING:
		return INVALID_BRANCH_KEY_TYPE_INVALID
	if typeof(sp1_result["is_draw_fallback"]) != TYPE_BOOL:
		return INVALID_IS_DRAW_FALLBACK_TYPE_INVALID
	if typeof(sp1_result["is_canonical_history"]) != TYPE_BOOL:
		return INVALID_IS_CANONICAL_HISTORY_TYPE_INVALID
	# Empty branch_key after dispatch indicates branch_table missing the outcome row.
	if (sp1_result["branch_key"] as String).is_empty():
		return INVALID_BRANCH_TABLE_MISSING_OUTCOME
	# Cross-field invariant: is_draw_fallback ⟹ outcome == DRAW.
	if (sp1_result["is_draw_fallback"] as bool) and outcome != BattleOutcome.Result.DRAW:
		return INVALID_IS_DRAW_FALLBACK_OUTCOME_MISMATCH
	return &""


## Abstract implementation hook for F-DB-1 algorithm (branch_table lookup).
##
## Subclasses MUST override. Returned Dictionary shape (F-DB-3 minimal contract):
##   branch_key: String              — non-empty branch identifier
##   is_draw_fallback: bool          — true iff DRAW outcome and no DRAW row authored
##   is_canonical_history: bool      — true iff branch_key == chapter.canonical_branch_key
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
