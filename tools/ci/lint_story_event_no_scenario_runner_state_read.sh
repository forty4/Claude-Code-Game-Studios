#!/usr/bin/env bash
# tools/ci/lint_story_event_no_scenario_runner_state_read.sh
#
# story_event_reads_scenario_runner_state forbidden_pattern enforcement
# (TR-story-event-019 candidate + design/gdd/story-event.md §CR-SE-19
#  — Pillar 2 architectural lock 6th invocation).
#
# Pillar 2 ("운명은 바꿀 수 있다") + Pillar 4 ("지난 장의 선택이 살아 있다")
# require that StoryEvent receive narrative-resolution triggers via emitted
# signals (chapter_started + destiny_branch_chosen + scenario_complete +
# chapter_completed) — NEVER read internal ScenarioRunner state. Public API
# calls (e.g. ScenarioRunner.get_current_chapter() for chapter authoring
# Resource lookup) are allowed; internal _state / _echo_count etc. are NOT.
#
# Lock precedent chain:
#   1st: battle_hud_subscribes_to_hidden_fate_signal (ADR-0015)
#   2nd: scenario_runner_deferred_seal_in_beat_7_entry (ADR-0017)
#   3rd: destiny_branch_judge_reads_scenario_runner_state (ADR-0018)
#   4th: ai_system_reads_destiny_branch_state (ADR-0019)
#   5th: destiny_state_reads_scenario_runner_state (sprint-8 S8-10)
#   6th: story_event_reads_scenario_runner_state (this lint, sprint-8 S8-09)
#
# Pattern stability declaration: 6 invocations is the codification threshold.
#
# Exit 0: PASS (StoryEvent reads no underscore-prefixed ScenarioRunner state)
# Exit 1: FAIL (violation detected — Pillar 2 lock 6th invocation broken)
set -euo pipefail

TARGETS=(
    "src/feature/story_event/story_event.gd"
)

while IFS= read -r f; do
    if [ -n "$f" ]; then TARGETS+=("$f"); fi
done < <(find src/feature/story_event -name "*.gd" 2>/dev/null || true)

FAILED=0
PATTERNS=(
    'ScenarioRunner\._state'
    'ScenarioRunner\._echo_counts'
    'ScenarioRunner\._current_chapter_index'
    'ScenarioRunner\._echo_count'
    'ScenarioRunner\._echo_marks'
    'ScenarioRunner\._chapter_index'
    'ScenarioRunner\._first_attempt_resolved'
    'ScenarioRunner\.advance_beat'
    'ScenarioRunner\.confirm_deployment'
    'ScenarioRunner\.accept_outcome'
)
declare -A SEEN
for t in "${TARGETS[@]}"; do
    if [ -z "$t" ] || [ "${SEEN[$t]:-}" = "1" ]; then continue; fi
    SEEN[$t]=1
    if [ ! -f "$t" ]; then continue; fi
    for p in "${PATTERNS[@]}"; do
        if matches=$(grep -En "$p" "$t" | grep -Ev ':[[:space:]]*#' || true); then
            if [ -n "$matches" ]; then
                echo "FAIL: $t reads ScenarioRunner internal state OR mutator API — Pillar 2 lock 6th invocation violated:"
                echo "$matches"
                echo "  (StoryEvent MUST receive triggers via emitted GameBus signals; mutator"
                echo "   API like advance_beat is the runtime-driver's responsibility, not Story Event."
                echo "   Public read API ScenarioRunner.get_current_chapter() IS allowed.)"
                FAILED=1
            fi
        fi
    done
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "PASS: StoryEvent reads no underscore-prefixed ScenarioRunner state (Pillar 2 lock 6th invocation preserved)"
exit 0
