#!/usr/bin/env bash
# tools/ci/lint_destiny_branch_judge_no_scenario_runner_read.sh
#
# destiny_branch_judge_reads_scenario_runner_state forbidden_pattern enforcement
# (TR-destiny-branch-014 + ADR-0018 §Forbidden Patterns
#  — Pillar 2 architectural lock 3rd precedent).
#
# Pillar 2 ("운명은 바꿀 수 있다") requires that DestinyBranchJudge receive
# `first_attempt_resolved` as the 4th argument from ScenarioRunner — NEVER read
# it directly from autoload state. The seal value passes BY parameter from the
# already-sealed `first_attempt_resolved` per F-SP-3 v2.2 +
# scenario_runner_deferred_seal_in_beat_7_entry forbidden_pattern (Pillar 2
# architectural lock 2nd precedent).
#
# Scan-set: production source files only (test stub may reference ScenarioRunner
# in setup helpers if future tests require it).
#
# Exit 0: PASS (judge receives first_attempt_resolved by argument)
# Exit 1: FAIL (judge reads ScenarioRunner state — Pillar 2 lock violated)
set -euo pipefail

TARGETS=(
    "src/feature/destiny_branch/destiny_branch_judge.gd"
    "src/feature/destiny_branch/default_destiny_branch_judge.gd"
)

while IFS= read -r f; do
    if [ -n "$f" ]; then TARGETS+=("$f"); fi
done < <(grep -rl "extends DestinyBranchJudge" src/ 2>/dev/null || true)

FAILED=0
# Patterns that read ScenarioRunner state at runtime.
PATTERNS=(
    'ScenarioRunner\.[a-zA-Z_]'
    '_scenario_state\.[a-zA-Z_]'
    'get_node\(.*ScenarioRunner'
)
for t in "${TARGETS[@]}"; do
    if [ ! -f "$t" ]; then continue; fi
    for p in "${PATTERNS[@]}"; do
        if matches=$(grep -En "$p" "$t" | grep -v '^\s*#' || true); then
            if [ -n "$matches" ]; then
                echo "FAIL: $t reads ScenarioRunner state — Pillar 2 lock 3rd precedent violated:"
                echo "$matches"
                echo "  (judge MUST receive first_attempt_resolved as 4th argument, NOT read autoload)"
                FAILED=1
            fi
        fi
    done
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "PASS: DestinyBranchJudge classes read no ScenarioRunner state (Pillar 2 lock 3rd precedent preserved)"
exit 0
