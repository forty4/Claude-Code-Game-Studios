#!/usr/bin/env bash
# tools/ci/lint_ai_system_no_direct_state_read.sh
#
# ai_system_direct_battle_state_read forbidden_pattern enforcement
# (TR-ai-system-014 + ADR-0019 §Forbidden Patterns + CR-AI-6 enforcement
#  — 2nd invocation of pure-function-takes-snapshot pattern after
#  destiny_branch_judge_reads_scenario_runner_state).
#
# AISystem reads battle state ONLY through BattleStateSnapshot parameter
# (CR-AI-6 pure-function-takes-snapshot). NO direct MapGrid./HPStatusController./
# TurnOrderRunner. references in scoring code. The DI'd `_grid_battle_controller`
# field is exempt — it's the signal subscription target, not a state read.
#
# Exit 0: PASS. Exit 1: FAIL (direct state read detected).
set -euo pipefail
TARGET="src/feature/ai/ai_system.gd"
if [ ! -f "$TARGET" ]; then echo "FAIL: target file missing: $TARGET"; exit 1; fi
# Forbidden: any reference to autoload-style state classes.
PATTERN='MapGrid\.|HPStatusController\.|TurnOrderRunner\.|GameBus\.[a-zA-Z_]+\.emit'
# Allow lines that are GameBus connect/disconnect (subscription). Allow comments.
if matches=$(grep -En "$PATTERN" "$TARGET" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v 'connect(' | grep -v 'disconnect(' | grep -v 'is_connected(' || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $TARGET reads direct state — CR-AI-6 pure-function-takes-snapshot violated:"
        echo "$matches"
        echo "  (AI must read state ONLY via BattleStateSnapshot parameter)"
        exit 1
    fi
fi
echo "PASS: $TARGET reads no direct state (CR-AI-6 pure-function-takes-snapshot preserved)"
exit 0
