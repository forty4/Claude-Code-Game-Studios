#!/usr/bin/env bash
# tools/ci/lint_destiny_state_no_hidden_fate_subscription.sh
#
# destiny_state_no_hidden_fate_subscription forbidden_pattern enforcement
# (design/gdd/destiny-state.md §CR-DS-6 — Pillar 2 architectural lock pattern
#  defense-in-depth alongside the 5th invocation
#  destiny_state_reads_scenario_runner_state lint).
#
# Per CR-DS-6 + CR-DS-19: DestinyState MUST work downstream of the resolved
# DestinyBranchChoice — it never inspects the hidden-fate-counter substrate.
# Hidden-fate state is read ONLY by DestinyBranchJudge per ADR-0018 §CR-DB-7.
#
# This is the same lint shape as ai_system_reads_destiny_branch_state
# (Pillar 2 lock 4th invocation per ADR-0019) but targeting the
# hidden_fate_condition_progressed signal specifically.
#
# Scan-set: production source files only.
#
# Exit 0: PASS (DestinyState files contain no hidden_fate references)
# Exit 1: FAIL (violation detected)
set -euo pipefail

TARGETS=(
    "src/feature/destiny_state/destiny_state.gd"
)

while IFS= read -r f; do
    if [ -n "$f" ]; then TARGETS+=("$f"); fi
done < <(find src/feature/destiny_state -name "*.gd" 2>/dev/null || true)

FAILED=0
# Targets the 1 specific token from CR-DS-6 enforcement.
PATTERNS=(
    'hidden_fate_condition_progressed'
    'hidden_fate'
)
declare -A SEEN
for t in "${TARGETS[@]}"; do
    if [ -z "$t" ] || [ "${SEEN[$t]:-}" = "1" ]; then continue; fi
    SEEN[$t]=1
    if [ ! -f "$t" ]; then continue; fi
    for p in "${PATTERNS[@]}"; do
        if matches=$(grep -En "$p" "$t" | grep -Ev ':[[:space:]]*#' || true); then
            if [ -n "$matches" ]; then
                echo "FAIL: $t references hidden_fate substrate — CR-DS-6 violation:"
                echo "$matches"
                echo "  (DestinyState MUST work downstream of DestinyBranchChoice,"
                echo "   NEVER inspect hidden_fate_condition_progressed signal."
                echo "   Pillar 2 lock pattern defense-in-depth.)"
                FAILED=1
            fi
        fi
    done
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "PASS: DestinyState files contain no hidden_fate references (CR-DS-6 defense-in-depth preserved)"
exit 0
