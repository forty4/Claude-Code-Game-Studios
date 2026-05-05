#!/usr/bin/env bash
# tools/ci/lint_destiny_state_no_scenario_runner_read.sh
#
# destiny_state_reads_scenario_runner_state forbidden_pattern enforcement
# (TR-destiny-state-019 candidate + design/gdd/destiny-state.md §CR-DS-19
#  — Pillar 2 architectural lock 5th invocation).
#
# Pillar 2 ("운명은 바꿀 수 있다") requires that DestinyState receive echo
# accumulation events via emitted scenario_beat_retried(EchoMark) signals from
# ScenarioRunner — NEVER read internal state (`_state`, `_echo_counts`,
# `_current_chapter_index`) directly. Public API calls (e.g.
# `ScenarioRunner.get_current_chapter()`) are allowed for chapter_id
# derivation per CR-DS-11 schema-gap workaround until SaveMigrationRegistry
# adds chapter_id to EchoMark.
#
# Lock precedent chain:
#   1st: battle_hud_subscribes_to_hidden_fate_signal (ADR-0015)
#   2nd: scenario_runner_deferred_seal_in_beat_7_entry (ADR-0017)
#   3rd: destiny_branch_judge_reads_scenario_runner_state (ADR-0018)
#   4th: ai_system_reads_destiny_branch_state (ADR-0019)
#   5th: destiny_state_reads_scenario_runner_state (this lint, sprint-8 S8-10)
#
# Scan-set: production source files only (test stubs may reference internal
# fields for setup helpers if future tests require it).
#
# Exit 0: PASS (DestinyState reads no underscore-prefixed ScenarioRunner state)
# Exit 1: FAIL (violation detected — Pillar 2 lock 5th invocation broken)
set -euo pipefail

TARGETS=(
    "src/feature/destiny_state/destiny_state.gd"
)

while IFS= read -r f; do
    if [ -n "$f" ]; then TARGETS+=("$f"); fi
done < <(find src/feature/destiny_state -name "*.gd" 2>/dev/null || true)

FAILED=0
# Patterns that read ScenarioRunner internal state at runtime.
# `_`-prefixed fields are forbidden; public API (no underscore) is allowed.
PATTERNS=(
    'ScenarioRunner\._state'
    'ScenarioRunner\._echo_counts'
    'ScenarioRunner\._current_chapter_index'
    'ScenarioRunner\._echo_count'
    'ScenarioRunner\._echo_marks'
    'ScenarioRunner\._chapter_index'
    'ScenarioRunner\._first_attempt_resolved'
)
# Deduplicate and run each unique target.
declare -A SEEN
for t in "${TARGETS[@]}"; do
    if [ -z "$t" ] || [ "${SEEN[$t]:-}" = "1" ]; then continue; fi
    SEEN[$t]=1
    if [ ! -f "$t" ]; then continue; fi
    for p in "${PATTERNS[@]}"; do
        if matches=$(grep -En "$p" "$t" | grep -Ev ':[[:space:]]*#' || true); then
            if [ -n "$matches" ]; then
                echo "FAIL: $t reads ScenarioRunner internal state — Pillar 2 lock 5th invocation violated:"
                echo "$matches"
                echo "  (DestinyState MUST receive scenario_beat_retried via emitted signal,"
                echo "   NOT read \`ScenarioRunner._<field>\` directly. Public API like"
                echo "   \`ScenarioRunner.get_current_chapter()\` IS allowed per CR-DS-11.)"
                FAILED=1
            fi
        fi
    done
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "PASS: DestinyState reads no underscore-prefixed ScenarioRunner state (Pillar 2 lock 5th invocation preserved)"
exit 0
