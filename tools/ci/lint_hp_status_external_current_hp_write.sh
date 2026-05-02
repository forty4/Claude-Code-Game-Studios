#!/usr/bin/env bash
# tools/ci/lint_hp_status_external_current_hp_write.sh
#
# TR-hp-status-015 — enforces ADR-0010 CR-2 + R-5 extension
# (forbidden_pattern: hp_status_external_current_hp_write).
#
# External systems MUST NOT directly access HPStatusController._state_by_unit OR
# write `unit_hp_state.current_hp = N` from outside hp_status_controller.gd.
#
# All HP changes MUST flow through the 4 sanctioned mutator paths:
#   - HPStatusController.apply_damage     (CR-3 intake pipeline)
#   - HPStatusController.apply_heal       (CR-4 healing pipeline)
#   - HPStatusController.apply_status     (CR-5 status effect application)
#   - HPStatusController.initialize_unit  (CR-1a battle-init only)
#
# The CR-2 invariant `0 ≤ current_hp ≤ max_hp` is enforced ONLY at these mutator boundaries.
# Bypassing them creates state corruption:
#   - `current_hp = -5` → ghost-alive unit
#   - `current_hp = max_hp + 50` → overheal violating CR-4a
#   - `current_hp = 999` → bypasses MIN_DAMAGE, DEFEND_STANCE, Shield Wall, unit_died emit, DEMORALIZED propagation
#
# Scans:
#   (1) Non-test src/ files for direct `_state_by_unit` field access
#   (2) All src/ files (excluding hp_status_controller.gd itself) for `current_hp =` write patterns
#
# Exit code: 0 if no external access found, 1 if violation detected.

set -uo pipefail

CONTROLLER="src/core/hp_status_controller.gd"

if [ ! -f "$CONTROLLER" ]; then
  echo "ERROR: lint_hp_status_external_current_hp_write — $CONTROLLER not found" >&2
  exit 1
fi

VIOLATIONS=""

# ── Check 1: _state_by_unit access outside HPStatusController ─────────────────
# Any .gd file in src/ that references _state_by_unit (except the controller itself)
STATE_BY_UNIT_VIOLATIONS=$(grep -rEn '_state_by_unit\b' src/ --include='*.gd' \
  | grep -v "src/core/hp_status_controller.gd" || true)

if [ -n "$STATE_BY_UNIT_VIOLATIONS" ]; then
  VIOLATIONS="${VIOLATIONS}
_state_by_unit access violations:
${STATE_BY_UNIT_VIOLATIONS}"
fi

# ── Check 2: current_hp direct write outside HPStatusController ───────────────
# Pattern: `current_hp = ` assignment (write) in any src/ .gd file except the controller.
# Matches: `state.current_hp = `, `unit_hp_state.current_hp = `, `.current_hp = N`, etc.
CURRENT_HP_WRITE_VIOLATIONS=$(grep -rEn '\.current_hp\s*=' src/ --include='*.gd' \
  | grep -v "src/core/hp_status_controller.gd" || true)

if [ -n "$CURRENT_HP_WRITE_VIOLATIONS" ]; then
  VIOLATIONS="${VIOLATIONS}
current_hp direct write violations:
${CURRENT_HP_WRITE_VIOLATIONS}"
fi

if [ -n "$VIOLATIONS" ]; then
  echo "ADR-0010 CR-2 + R-5 VIOLATION (hp_status_external_current_hp_write):"
  echo "External code accesses HPStatusController state directly."
  echo ""
  echo "$VIOLATIONS"
  echo ""
  echo "Fix: remove all direct _state_by_unit access and current_hp writes from external files."
  echo "External code MUST use the 4 sanctioned mutator paths only:"
  echo "  - apply_damage(unit_id, resolved_damage, attack_type, source_flags)"
  echo "  - apply_heal(unit_id, raw_heal, source_unit_id)"
  echo "  - apply_status(unit_id, effect_template_id, duration_override, source_unit_id)"
  echo "  - initialize_unit(unit_id, hero, unit_class)  [battle-init only]"
  exit 1
fi

echo "PASS: no external _state_by_unit access or current_hp writes outside $CONTROLLER (ADR-0010 CR-2 + R-5 intact)."
exit 0
