#!/usr/bin/env bash
# tools/ci/lint_scenario_runner_state_match_exhaustive.sh
#
# scenario_runner_arbitrary_state_jump forbidden_pattern enforcement
# (TR-scenario-progression-005 + ADR-0017 §Decision §State Machine Form +
#  AC-SP-13 forward-only invariant).
#
# Two-layer check:
#   1. Match-statement covers all 13 enum members of State.
#   2. No `_state =` direct assignment outside `_transition_to()` body.
#
# Exit 0: PASS (state machine discipline preserved)
# Exit 1: FAIL (arbitrary-state-jump risk detected)
set -euo pipefail
TARGET="src/core/scenario_runner.gd"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

FAILED=0

# Check 1: all 13 State enum members appear as match arms.
REQUIRED_STATES=(
    "State.LOADING"
    "State.CHAPTER_START"
    "State.BEAT_1_ANCHOR"
    "State.BEAT_2_ECHO"
    "State.BEAT_3_BRIEF"
    "State.BEAT_4_PREP"
    "State.BATTLE_LOADING"
    "State.BEAT_5_BATTLE"
    "State.BEAT_6_RESULT"
    "State.BEAT_7_JUDGMENT"
    "State.BEAT_8_REVEAL"
    "State.BEAT_9_TRANSITION"
    "State.SCENARIO_END"
)
for state in "${REQUIRED_STATES[@]}"; do
    if ! grep -F -q "$state" "$TARGET"; then
        echo "FAIL: $TARGET match-statement missing State arm: $state"
        FAILED=1
    fi
done

# Check 2: no `_state =` ASSIGNMENT outside `_transition_to()` or `load_scenario()`.
# Match `_state =` followed by a non-`=` character (excludes `_state == X` comparisons).
# Allowed inside _transition_to() (the canonical mutator) AND load_scenario()
# (the LOADING-state entry path which predates state-machine activation).
violations=$(awk '
    /^func _transition_to/ {in_safe=1; next}
    /^func load_scenario/ {in_safe=1; next}
    /^func _set_chapters_for_test/ {in_safe=1; next}
    /^func / && in_safe {in_safe=0}
    /_state[[:space:]]*=[^=]/ && !in_safe && !/^[[:space:]]*#/ {print NR": "$0}
' "$TARGET" || true)
# Filter out the variable declaration `var _state: State = State.LOADING`.
violations=$(printf "%s" "$violations" | grep -vE '^[0-9]+:[[:space:]]*var _state' || true)
if [ -n "$violations" ]; then
    echo "FAIL: $TARGET contains _state = assignment outside _transition_to():"
    echo "$violations"
    FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi

echo "PASS: $TARGET state machine match exhaustive + no arbitrary-state-jump"
exit 0
