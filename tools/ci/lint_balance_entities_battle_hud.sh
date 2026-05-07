#!/usr/bin/env bash
# tools/ci/lint_balance_entities_battle_hud.sh
#
# BalanceConstants key-presence enforcement for battle-hud (TR-battle-hud-009;
# ADR-0015 §Decision §Depends On + design/ux/battle-hud.md §10 Tuning Knobs).
#
# Mandatory keys for the battle-hud system:
#   - FORECAST_RENDER_BUDGET_MS = 120 (UI-GB-04 forecast burst budget; integer;
#     safe range 50-300 per design/ux/battle-hud.md §10 Tuning Knobs)
#
# Pattern shape mirrors `lint_balance_entities_grid_battle_controller.sh`
# (sprint-5 S5-11 precedent) + `lint_balance_entities_input_handling.sh`
# (sprint-9 S9-05 precedent).
#
# Exit 0: key present + integer + within safe range
# Exit 1: key missing / wrong type / out of safe range
set -euo pipefail
TARGET="assets/data/balance/balance_entities.json"
if [ ! -f "$TARGET" ]; then
    echo "FAIL: target file missing: $TARGET"
    exit 1
fi

# Use python for robust JSON parsing (project is allowed python per
# tools/ci/lint_balance_entities_grid_battle_controller.sh precedent).
python3 - "$TARGET" <<'PYEOF'
import json
import sys

target = sys.argv[1]

with open(target, "r") as f:
    data = json.load(f)

REQUIRED = {
    "FORECAST_RENDER_BUDGET_MS": {"type": int, "min": 50, "max": 300},
}

failures = []
for key, spec in REQUIRED.items():
    if key not in data:
        failures.append(f"missing key: {key}")
        continue
    val = data[key]
    if not isinstance(val, spec["type"]):
        failures.append(f"{key} type mismatch: expected {spec['type'].__name__}, got {type(val).__name__}")
        continue
    if val < spec["min"] or val > spec["max"]:
        failures.append(f"{key} = {val} out of safe range [{spec['min']}, {spec['max']}]")

if failures:
    print("FAIL: balance_entities.json battle-hud key validation:")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print(f"PASS: balance_entities.json battle-hud keys present + valid:")
for key, spec in REQUIRED.items():
    print(f"  - {key} = {data[key]} (range {spec['min']}-{spec['max']})")
PYEOF
