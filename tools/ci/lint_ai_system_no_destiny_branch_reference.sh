#!/usr/bin/env bash
# tools/ci/lint_ai_system_no_destiny_branch_reference.sh
#
# ai_system_reads_destiny_branch_state forbidden_pattern enforcement
# (TR-ai-system-014 + ADR-0019 §Forbidden Patterns
#  — PILLAR 2 ARCHITECTURAL LOCK 4TH PROJECT PRECEDENT
#  after battle_hud_subscribes_to_hidden_fate_signal (1st)
#  + scenario_runner_deferred_seal_in_beat_7_entry (2nd)
#  + destiny_branch_judge_reads_scenario_runner_state (3rd)).
#
# AI MUST NOT introspect Pillar 2 hidden-fate state. The forbidden tokens
# `hidden_fate_condition_progressed`, `DestinyBranchChoice`, and
# `destiny_branch_chosen` MUST NOT appear anywhere in ai_system.gd.
#
# Pattern firmly stable at 4 invocations after this delta (per gate-check
# 2026-05-04 path-to-PASS item #4 close).
#
# Exit 0: PASS. Exit 1: FAIL (Pillar 2 lock violated).
set -euo pipefail
TARGET="src/feature/ai/ai_system.gd"
if [ ! -f "$TARGET" ]; then echo "FAIL: target file missing: $TARGET"; exit 1; fi
PATTERN='hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen'
if matches=$(grep -En "$PATTERN" "$TARGET" | grep -vE '^[0-9]+:[[:space:]]*#' || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $TARGET contains forbidden Pillar 2 token — architectural lock 4TH PRECEDENT violated:"
        echo "$matches"
        echo "  (AI MUST NOT introspect hidden-fate state per CR-AI-8)"
        exit 1
    fi
fi
echo "PASS: $TARGET contains no Pillar 2 hidden-fate tokens (lock 4th precedent preserved)"
exit 0
