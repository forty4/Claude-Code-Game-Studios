#!/usr/bin/env bash
# tools/ci/lint_turn_order_no_ai_symbol_reference.sh
#
# TR-turn-order-009 forbidden_pattern + S2-06 same-patch amendment.
# TurnOrderRunner MUST NOT reference AI system symbols or classes directly.
# This enforces domain boundary: TurnOrderRunner is pure turn-order scheduling;
# AI decision-making belongs in separate subsystem (ScoutAI, NormalAI, etc.).
#
# Forbidden patterns:
#   - class_name references: ScoutAI, CavalryAI, InfantryAI, NormalAI, SpecialAI
#   - load() calls to AI .gd files: res://src/ai/...
#   - AI-specific method calls: invoke_ai(), get_ai_decision(), etc.
#
# Exit code: 0 if no AI symbol references, 1 if violation detected.

set -uo pipefail

TARGET="src/core/turn_order_runner.gd"

if [ ! -f "$TARGET" ]; then
  echo "lint_turn_order_no_ai_symbol_reference: ERROR — $TARGET not found" >&2
  exit 1
fi

# Scan for direct AI class_name references
ai_symbols="ScoutAI|CavalryAI|InfantryAI|NormalAI|SpecialAI"
ai_class_refs=$(grep -n "$ai_symbols" "$TARGET" || true)

if [ -n "$ai_class_refs" ]; then
  echo "TR-turn-order-009 VIOLATION: TurnOrderRunner references AI class names directly."
  echo "Matching lines:"
  echo "$ai_class_refs"
  echo
  echo "Fix: TurnOrderRunner must remain agnostic to AI subsystem (S2-06 domain boundary)."
  echo "Use generic unit_turn_started signal / event; AI subscribers decide their own actions."
  exit 1
fi

# Scan for load() calls to AI system files
ai_load=$(grep -n 'load.*res://src/ai/' "$TARGET" || true)

if [ -n "$ai_load" ]; then
  echo "TR-turn-order-009 VIOLATION: TurnOrderRunner loads AI system files directly."
  echo "Matching lines:"
  echo "$ai_load"
  echo
  echo "Fix: AI instantiation belongs in AI subsystem setup, not TurnOrderRunner."
  exit 1
fi

echo "PASS: TurnOrderRunner AI-symbol-reference protection intact (TR-009 + S2-06)."
exit 0
