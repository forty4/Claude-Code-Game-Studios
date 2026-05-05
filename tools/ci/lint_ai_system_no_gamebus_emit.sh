#!/usr/bin/env bash
# tools/ci/lint_ai_system_no_gamebus_emit.sh
#
# ai_system_signal_emission_outside_action_ready forbidden_pattern enforcement
# (TR-ai-system-014 + ADR-0019 §Forbidden Patterns + 9-precedent stateless-emit
#  / non-emitter discipline mirror).
#
# AISystem MUST emit ONLY its own LOCAL signal `ai_action_ready` declared on
# the AISystem class. NO GameBus.* emission anywhere in the file.
#
# Exit 0: PASS. Exit 1: FAIL (GameBus emission detected).
set -euo pipefail
TARGET="src/feature/ai/ai_system.gd"
if [ ! -f "$TARGET" ]; then echo "FAIL: target file missing: $TARGET"; exit 1; fi
if matches=$(grep -En 'GameBus\..*\.emit\(' "$TARGET" | grep -v '^\s*#' || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $TARGET emits GameBus signal — only LOCAL ai_action_ready allowed:"
        echo "$matches"
        exit 1
    fi
fi
echo "PASS: $TARGET emits no GameBus signals (LOCAL ai_action_ready only)"
exit 0
