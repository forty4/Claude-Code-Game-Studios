#!/usr/bin/env bash
# tools/ci/lint_scenario_runner_branch_table_immutable.sh
#
# scenario_runner_branch_table_runtime_mutation forbidden_pattern enforcement
# (TR-scenario-progression-014 + ADR-0017 §Decision §Forbidden Patterns +
#  CR-15 #4 invariant: branch_table is hydrated once and read-only at runtime).
#
# Greps src/ for any pattern that mutates branch_table at runtime.
#
# Exit 0: PASS (no runtime mutation detected)
# Exit 1: FAIL (mutation pattern found)
set -euo pipefail

FAILED=0
TARGETS=("src/core/scenario_runner.gd" "src/feature/destiny_branch")

# Forbidden patterns (regex):
#   .branch_table[...] =     (subscript-assign)
#   .branch_table.erase(     (key removal)
#   .branch_table.clear(     (full clear)
#   .branch_table.merge(     (merge mutation)
PATTERNS=(
    '\.branch_table\[.*\][[:space:]]*='
    '\.branch_table\.erase[[:space:]]*\('
    '\.branch_table\.clear[[:space:]]*\('
    '\.branch_table\.merge[[:space:]]*\('
)

for target in "${TARGETS[@]}"; do
    if [ ! -e "$target" ]; then
        continue
    fi
    for pattern in "${PATTERNS[@]}"; do
        if matches=$(grep -rEn "$pattern" "$target" 2>/dev/null); then
            echo "FAIL: $target matches branch_table mutation pattern '$pattern':"
            echo "$matches"
            FAILED=1
        fi
    done
done

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi

echo "PASS: no branch_table runtime mutation patterns found"
exit 0
