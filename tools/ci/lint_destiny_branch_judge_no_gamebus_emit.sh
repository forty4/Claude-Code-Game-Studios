#!/usr/bin/env bash
# tools/ci/lint_destiny_branch_judge_no_gamebus_emit.sh
#
# destiny_branch_judge_emits_gamebus_signal forbidden_pattern enforcement
# (TR-destiny-branch-014 + ADR-0018 §Forbidden Patterns + CR-DB-4 emission
#  ownership: ScenarioRunner emits destiny_branch_chosen, NOT the judge).
#
# Scan-set: production source + test stub + future `extends DestinyBranchJudge`
# discovery. AC-LINT-1 verifies zero matches across all 3 files.
#
# Exit 0: PASS (no GameBus emission from judge classes)
# Exit 1: FAIL (judge emits GameBus signal — emission ownership violated)
set -euo pipefail

TARGETS=(
    "src/feature/destiny_branch/destiny_branch_judge.gd"
    "src/feature/destiny_branch/default_destiny_branch_judge.gd"
    "tests/helpers/destiny_branch_judge_stub.gd"
)

# Forward-compat: discover any future `extends DestinyBranchJudge` files.
while IFS= read -r f; do
    if [ -n "$f" ]; then TARGETS+=("$f"); fi
done < <(grep -rl "extends DestinyBranchJudge" src/ tests/ 2>/dev/null || true)

FAILED=0
PATTERN='GameBus\..*\.emit\('
for t in "${TARGETS[@]}"; do
    if [ ! -f "$t" ]; then continue; fi
    if matches=$(grep -En "$PATTERN" "$t" | grep -v '^\s*#' || true); then
        if [ -n "$matches" ]; then
            echo "FAIL: $t emits GameBus signal — CR-DB-4 emission ownership violated:"
            echo "$matches"
            FAILED=1
        fi
    fi
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "PASS: DestinyBranchJudge classes emit no GameBus signals (CR-DB-4 emission ownership preserved)"
exit 0
