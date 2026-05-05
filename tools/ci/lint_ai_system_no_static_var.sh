#!/usr/bin/env bash
# tools/ci/lint_ai_system_no_static_var.sh
#
# ai_system_static_var forbidden_pattern enforcement
# (TR-ai-system-014 + ADR-0019 §Forbidden Patterns + 5-precedent battle-scoped
#  + RefCounted lint pattern mirror; CR-AI-5 determinism contract enforcement).
#
# Exit 0: PASS. Exit 1: FAIL.
set -euo pipefail
TARGET="src/feature/ai/ai_system.gd"
if [ ! -f "$TARGET" ]; then echo "FAIL: target file missing: $TARGET"; exit 1; fi
if matches=$(grep -En '^[[:space:]]*static[[:space:]]+var' "$TARGET" || true); then
    if [ -n "$matches" ]; then
        echo "FAIL: $TARGET declares static var — CR-AI-5 determinism violated:"
        echo "$matches"
        exit 1
    fi
fi
echo "PASS: $TARGET declares no static var (CR-AI-5 determinism preserved)"
exit 0
