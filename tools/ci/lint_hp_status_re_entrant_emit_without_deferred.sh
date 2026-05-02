#!/usr/bin/env bash
# tools/ci/lint_hp_status_re_entrant_emit_without_deferred.sh
#
# TR-hp-status-015 — enforces ADR-0010 R-1 (forbidden_pattern: hp_status_re_entrant_emit_without_deferred).
#
# IMPORTANT — this is a SOFT-WARNING + HARD-FAIL hybrid lint:
#
# SOFT WARNING (no exit 1): R-1 is enforced subscriber-side via CONNECT_DEFERRED per ADR-0001 §5.
#   The emitter (HPStatusController) cannot prevent re-entrant callers — subscribers must connect
#   with CONNECT_DEFERRED to avoid re-entry. This lint validates that the CONNECT_DEFERRED reference
#   is documented in the source as a comment (R-1 mitigation documentation).
#   Missing CONNECT_DEFERRED reference is a warning, not a hard failure.
#
# HARD FAIL (exit 1): Production code MUST NOT call apply_damage from within the unit_died.emit()
#   call frame (synchronous re-entry). This is an AST heuristic: if `apply_damage(` appears within
#   5 lines AFTER `GameBus.unit_died.emit(` in the same function body, it is flagged as a potential
#   synchronous re-entry pattern. Hard fail prevents accidental re-entry introduction.
#
# Heuristic-only nature: the awk scan is a proximity heuristic, not a full AST parse.
#   A false positive is possible if apply_damage is called in a different function that happens
#   to follow unit_died.emit in the file. Review any flagged lines before concluding violation.
#   The production code is structured so that unit_died.emit() is always in a return-or-branch
#   position; apply_damage follows only in a subsequent function body.
#
# Fix if hard fail triggers:
#   - Do NOT call apply_damage (or any mutator) within the unit_died.emit() call frame.
#   - If re-entry is needed (e.g., damage chain), use CONNECT_DEFERRED subscriber-side.
#   - ADR-0010 R-1 + ADR-0001 §5 mandate: subscribers MUST use CONNECT_DEFERRED.
#
# Exit code: 0 if no synchronous re-entry pattern detected, 1 if violation detected.

set -uo pipefail

TARGET="src/core/hp_status_controller.gd"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: lint_hp_status_re_entrant_emit_without_deferred — $TARGET not found" >&2
  exit 1
fi

# ── Soft warning: CONNECT_DEFERRED reference ─────────────────────────────────
# R-1 is enforced subscriber-side; emitter should document the mandate.
if ! grep -q "CONNECT_DEFERRED" "$TARGET"; then
  echo "WARNING: $TARGET missing CONNECT_DEFERRED reference (R-1 mitigation documentation)."
  echo "ADR-0001 §5 mandates subscribers use CONNECT_DEFERRED for cross-scene re-entrancy."
  echo "Consider adding a comment near unit_died.emit() noting the subscriber-side requirement."
  echo "(Soft warning only — R-1 is enforced by subscriber-side CONNECT_DEFERRED, not emitter-side.)"
  # No exit 1 — this is a soft warning per story §5 rationale
fi

# ── Hard fail: synchronous apply_damage re-entry within unit_died.emit() frame ─
# Heuristic: scan for apply_damage call within 5 lines after unit_died.emit (synchronous re-entry).
AWK_RESULT=$(awk '
  /GameBus\.unit_died\.emit\(/ {
    flag=1
    line_count=0
    next
  }
  flag && /apply_damage\(/ {
    print NR ": potential synchronous apply_damage re-entry within unit_died.emit call frame"
    flag=0
  }
  flag {
    line_count++
    if (line_count >= 5) flag=0
  }
' "$TARGET")

if [ -n "$AWK_RESULT" ]; then
  echo "ADR-0010 R-1 VIOLATION (hp_status_re_entrant_emit_without_deferred): synchronous apply_damage re-entry detected."
  echo ""
  echo "Offending lines in $TARGET:"
  echo "$AWK_RESULT"
  echo ""
  echo "Fix: do NOT call apply_damage (or any mutator) synchronously within the unit_died.emit() call frame."
  echo "If damage chaining is needed, subscribers MUST use CONNECT_DEFERRED per ADR-0001 §5."
  echo ""
  echo "Note: this is an AST proximity heuristic (5-line window). Review the flagged lines to confirm"
  echo "      whether the apply_damage call is actually within the unit_died.emit() call frame."
  exit 1
fi

echo "PASS: no synchronous apply_damage re-entry within unit_died.emit() call frame (ADR-0010 R-1 intact)."
exit 0
