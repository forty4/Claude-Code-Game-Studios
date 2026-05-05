## ScenarioResult — payload for GameBus.scenario_complete.
##
## Emitted by ScenarioRunner at SCENARIO_END entry (last chapter Beat 9 exit).
## Shape ratified via ADR-0001 §Evolution Rule #4 / /architecture-review delta #12:
## widened from String to ScenarioResult (4-field typed Resource per ADR-0017 §CR-16
## + F-SP-4 GDD intent).
##
## F-SP-4: scenario_path_key is composed from per-chapter branch_path_ids joined by
## "::" separator (e.g., "WIN_changbanpo_default::LOSS_zhugeliang_default").
##
## ADR: ADR-0017 §Key Interfaces §ScenarioResult.
## TR: TR-scenario-progression-004 (scenario_complete payload shape).
class_name ScenarioResult
extends Resource


## Ordered collection of per-chapter outcome summaries.
## Each entry is an Array[ChapterResult] value; stored as Array[Dictionary]
## for forward-compatible JSON round-trip until Save/Load #17 GDD lands.
## Keys per entry: chapter_id, branch_path_id, echo_count_at_completion, outcome.
@export var chapter_outcomes: Array[Dictionary] = []

## F-SP-4: canonical delta count — number of chapters where player took the
## canonical branch. Used for destiny-state + achievement tracking.
@export var canonical_delta: int = 0

## F-SP-4: composed scenario path key from per-chapter branch_path_ids joined
## by "::" separator. Provides a single string for save-slot display + lookup.
@export var scenario_path_key: String = ""

## Sum of echo_count_at_completion across all chapters.
## Reflects total retry effort over the scenario arc.
@export var total_echo: int = 0
