## DestinyBranchChoice — payload for GameBus.destiny_branch_chosen.
##
## Emitter: ScenarioRunner (at BEAT_7_JUDGMENT exit / post-tap-advance per CR-DB-4
## emission ownership; DestinyBranchJudge.resolve() populates the fields but does
## NOT emit — ScenarioRunner owns the emit site).
##
## 9-field shape RATIFIED via ADR-0001 Evolution Rule #4 / /architecture-review
## delta #13 (2026-05-04). Supersedes PROVISIONAL stub. Shape is the canonical
## contract per AC-SP-18 + ADR-0018 §Decision §DestinyBranchChoice payload.
##
## is_invalid == true means the choice could not be resolved (e.g., missing
## canonical_branch_key or unknown archetype); subscribers MUST gate content
## reads on is_invalid == false per CR-DB-10.
##
## ADR: ADR-0017 §Key Interfaces + ADR-0018 §Decision §DestinyBranchChoice.
## TR: TR-scenario-progression-008 (destiny_branch_chosen payload shape).
class_name DestinyBranchChoice
extends Resource


## Chapter identifier this choice applies to.
@export var chapter_id: String = ""

## The resolved branch path identifier from chapter.branch_table lookup.
@export var branch_key: String = ""

## The battle outcome that drove this branch resolution.
@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS

## Echo count at the moment of branch resolution (post-retry-loop snapshot).
@export var echo_count: int = 0

## True when this is a DRAW branch and the echo gate was NOT open
## (i.e., author_draw_branch=true but echo_count < echo_threshold OR
## first_attempt_resolved=true). Indicates fallback-to-WIN behaviour.
@export var is_draw_fallback: bool = false

## True when branch_key == chapter.canonical_branch_key.
## Drives Pillar 4 "지난 장의 선택이 살아 있다" destiny-state propagation.
@export var is_canonical_history: bool = false

## Art-bible §4.7 reserved-color treatment flag.
## True when the WIN branch resolves to a non-canonical outcome (the "역전 성공"
## reserved-color treatment is triggered). Derived per F-DB-2:
## reserved_color_treatment = (branch_key != canonical_branch_key) AND NOT is_draw_fallback.
@export var reserved_color_treatment: bool = false

## True when branch resolution failed (invalid chapter data, missing keys, etc.).
## Subscribers MUST check this field before reading branch_key or other fields.
@export var is_invalid: bool = false

## Human-readable reason string when is_invalid=true.
## Must be a value from the F-DB-3 12-entry invalid_reason vocabulary.
## Empty StringName when is_invalid=false.
@export var invalid_reason: StringName = &""
