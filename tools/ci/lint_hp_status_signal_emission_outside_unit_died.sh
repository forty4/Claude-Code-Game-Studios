#!/usr/bin/env bash
# tools/ci/lint_hp_status_signal_emission_outside_unit_died.sh
#
# TR-hp-status-015 — enforces ADR-0010 Validation §3 + §4
# (forbidden_pattern: hp_status_signal_emission_outside_unit_died).
#
# HPStatusController (src/core/hp_status_controller.gd) MUST emit ONLY the
# unit_died(unit_id: int) signal on GameBus per ADR-0001 line 155.
#
# HP/Status is non-emitter by behavior for all OTHER 21 GameBus signals across 8 domains:
#   Input (input_action_fired), Combat (damage_calculated), Scenario (chapter_started),
#   Persistence (save_persisted), Environment (tile_destroyed), Grid Battle (battle_outcome_resolved),
#   Turn Order (round_started; HP/Status CONSUMES unit_turn_started but does NOT emit it),
#   UI-Flow (ui_input_block_requested).
#
# ADR-0010 Validation §3 requires ≥2 unit_died emit sites:
#   1. apply_damage Step 4 (HP reduction branch when current_hp reaches 0)
#   2. _apply_turn_start_tick DoT-kill branch (POISON-killed unit per EC-06)
#
# Exit code: 0 if only unit_died emits exist AND ≥2 emit sites found, 1 if violation detected.

set -uo pipefail

TARGET="src/core/hp_status_controller.gd"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: lint_hp_status_signal_emission_outside_unit_died — $TARGET not found" >&2
  exit 1
fi

# ── Find all GameBus.*.emit( call sites ──────────────────────────────────────
EMIT_SITES=$(grep -nE 'GameBus\.[a-z_]+\.emit\(' "$TARGET" || true)

if [ -z "$EMIT_SITES" ]; then
  echo "ADR-0010 Validation §3 VIOLATION (hp_status_signal_emission_outside_unit_died):"
  echo "  $TARGET has 0 GameBus emit call sites."
  echo "  ADR-0010 Validation §3 requires ≥2 unit_died emit sites:"
  echo "    1. apply_damage Step 4 (HP reduction death path)"
  echo "    2. _apply_turn_start_tick DoT-kill branch (EC-06 POISON-killed unit)"
  exit 1
fi

# ── Verify all emit sites are unit_died ──────────────────────────────────────
NON_UNIT_DIED=$(echo "$EMIT_SITES" | grep -vE 'GameBus\.unit_died\.emit\(' || true)

if [ -n "$NON_UNIT_DIED" ]; then
  echo "ADR-0010 Validation §4 VIOLATION (hp_status_signal_emission_outside_unit_died):"
  echo "  $TARGET emits signals OTHER than unit_died (ADR-0001 line 155: sole HP/Status emitter signal)."
  echo ""
  echo "  Forbidden emit sites:"
  echo "$NON_UNIT_DIED" | sed 's/^/    /'
  echo ""
  echo "  Fix: HPStatusController must ONLY emit GameBus.unit_died."
  echo "  Other domain signals are owned by their respective domains — do not emit them here."
  exit 1
fi

# ── Verify ≥2 unit_died emit sites (ADR-0010 Validation §3) ──────────────────
COUNT=$(echo "$EMIT_SITES" | wc -l | tr -d ' ')

if [ "$COUNT" -lt 2 ]; then
  echo "ADR-0010 Validation §3 VIOLATION (hp_status_signal_emission_outside_unit_died):"
  echo "  $TARGET has only $COUNT unit_died emit site(s); ≥2 required."
  echo "  Required emit sites:"
  echo "    1. apply_damage Step 4 — emits when current_hp reaches 0 after PHYSICAL/MAGICAL damage"
  echo "    2. _apply_turn_start_tick DoT-kill branch — emits when POISON tick kills a unit (EC-06)"
  echo ""
  echo "  Fix: ensure both emit sites are present in the production code."
  exit 1
fi

echo "PASS: $COUNT unit_died emit site(s) found; no foreign-domain emits (ADR-0010 Validation §3+§4 intact)."
exit 0
