#!/usr/bin/env bash
# tools/ci/lint_destiny_branch_judge_no_static_var.sh
#
# destiny_branch_judge_static_var forbidden_pattern enforcement
# (TR-destiny-branch-014 + ADR-0018 §Forbidden Patterns + EC-DB-17 thread-safety
#  BY CONSTRUCTION: no static var in any DestinyBranchJudge subclass).
#
# Scan-set: production source + test stub + future `extends DestinyBranchJudge`.
# AC-LINT-2 verifies zero matches across all 3 files.
#
# Exit 0: PASS (no static var in judge class hierarchy)
# Exit 1: FAIL (static var detected — thread-safety BY CONSTRUCTION violated)
set -euo pipefail

TARGETS=(
    "src/feature/destiny_branch/destiny_branch_judge.gd"
    "src/feature/destiny_branch/default_destiny_branch_judge.gd"
    "tests/helpers/destiny_branch_judge_stub.gd"
)

while IFS= read -r f; do
    if [ -n "$f" ]; then TARGETS+=("$f"); fi
done < <(grep -rl "extends DestinyBranchJudge" src/ tests/ 2>/dev/null || true)

FAILED=0
PATTERN='^[[:space:]]*static[[:space:]]+var'
for t in "${TARGETS[@]}"; do
    if [ ! -f "$t" ]; then continue; fi
    if matches=$(grep -En "$PATTERN" "$t" | grep -v '^\s*#' || true); then
        if [ -n "$matches" ]; then
            echo "FAIL: $t declares static var — EC-DB-17 thread-safety violated:"
            echo "$matches"
            FAILED=1
        fi
    fi
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "PASS: DestinyBranchJudge classes declare no static var (EC-DB-17 thread-safety preserved)"
exit 0
