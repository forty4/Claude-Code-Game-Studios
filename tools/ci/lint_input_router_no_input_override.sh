#!/usr/bin/env bash
# tools/ci/lint_input_router_no_input_override.sh
#
# Verifies that InputRouter does NOT override `_input(event)` — only
# `_unhandled_input(event)` per ADR-0005 §1 + Advisory C dual-focus 4.6
# architecture. Overriding `_input` would intercept events BEFORE Control
# focus dispatch, breaking the dual-focus split per godot-specialist Item 1.
#
# Exit 0: no `_input` override found
# Exit 1: `_input` override declared (Advisory C violation)
#
# Usage:   bash tools/ci/lint_input_router_no_input_override.sh
# CI:      wired in story-010 (.github/workflows/tests.yml)
# ADR ref: docs/architecture/ADR-0005-input-handling.md §1 + Advisory C

set -euo pipefail

FILE="src/foundation/input_router.gd"

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE not found. Run from the project root."
    exit 1
fi

# Match `func _input(event...)` — but NOT `func _unhandled_input(...)`
if grep -nE '^func _input\(' "$FILE" > /dev/null; then
    echo "::error::InputRouter declares func _input(event) override — Advisory C forbids; use _unhandled_input only"
    grep -nE '^func _input\(' "$FILE"
    exit 1
fi

echo "lint_input_router_no_input_override PASS"
