#!/usr/bin/env bash
# tools/ci/lint_enum_append_only.sh
#
# ADR-0003 §Schema Stability §BattleOutcome Enum Stability + TR-save-load-005:
# BattleOutcome.Result enum is append-only. Reordering or removing values breaks
# forward-compat of saved BattleOutcome payloads. Append is allowed only when
# the snapshot file is updated in the same PR (forces migration + schema_version
# bump discipline).
#
# Lint compares the live enum in src/core/payloads/battle_outcome.gd against
# a committed snapshot at tools/ci/snapshots/battle_outcome_enum.txt.
#
# Comparison rules:
#  - length(source) < length(snapshot) → FAIL (value removed)
#  - any source[i] != snapshot[i] for i < length(snapshot) → FAIL (reorder/rename)
#  - extra entries at source[length(snapshot)..] → PASS (append)
#
# Exit code: 0 clean, 1 violation, 2+ lint-infra crash.

set -uo pipefail

SOURCE_FILE="src/core/payloads/battle_outcome.gd"
SNAPSHOT_FILE="tools/ci/snapshots/battle_outcome_enum.txt"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "Lint tool error: source file not found: $SOURCE_FILE" >&2
  echo "Enum source path may have drifted. Update SOURCE_FILE in this script." >&2
  exit 2
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "Lint tool error: snapshot file not found: $SNAPSHOT_FILE" >&2
  echo "Expected committed snapshot at $SNAPSHOT_FILE (one enum value per line)." >&2
  exit 2
fi

ruby_stdout=$(ruby -e '
  source_file = ARGV[0]
  snapshot_file = ARGV[1]

  # Parse snapshot: one value per line, blank lines ignored, comments stripped.
  snapshot = File.readlines(snapshot_file).map(&:strip).reject { |l| l.empty? || l.start_with?("#") }

  # Extract "enum Result { ... }" block from source. Handles both single-line
  # and multi-line forms. Strips integer assignments (e.g. "WIN = 0" → "WIN").
  source_content = File.read(source_file)
  match = source_content.match(/enum\s+Result\s*\{([^}]*)\}/m)
  unless match
    puts "ERROR: could not locate `enum Result { ... }` in #{source_file}"
    exit 2
  end

  body = match[1]
  source_values = body.split(",").map { |raw|
    # Strip comments, whitespace, and "= N" assignments.
    raw.sub(/#.*/, "").strip.sub(/\s*=.*$/, "")
  }.reject(&:empty?)

  # Compare.
  errors = []

  if source_values.length < snapshot.length
    errors << "REMOVAL: source enum has #{source_values.length} values; snapshot has #{snapshot.length}."
    errors << "  snapshot: #{snapshot.inspect}"
    errors << "  source:   #{source_values.inspect}"
  end

  snapshot.each_with_index do |expected, i|
    actual = source_values[i]
    if actual != expected
      errors << "POSITION[#{i}]: expected #{expected.inspect} (from snapshot); found #{actual.inspect} (in source)."
    end
  end

  if errors.empty?
    appended = source_values[snapshot.length..] || []
    if appended.any?
      puts "APPEND OK: new values appended (snapshot must be updated in same PR): #{appended.inspect}"
    else
      puts "OK: enum matches snapshot exactly."
    end
    exit 0
  else
    puts errors.join("\n")
    exit 1
  end
' "$SOURCE_FILE" "$SNAPSHOT_FILE" 2>&1)
ruby_exit=$?

if [ "$ruby_exit" -gt 1 ]; then
  echo "Lint tool error: Ruby exited with code $ruby_exit" >&2
  echo "Ruby output:" >&2
  echo "$ruby_stdout" >&2
  echo "This is a lint-infrastructure failure, NOT an enum violation." >&2
  exit 2
fi

if [ "$ruby_exit" -eq 1 ]; then
  echo "ADR-0003 §Schema Stability §BattleOutcome Enum Stability + TR-save-load-005 violation:"
  echo "BattleOutcome.Result enum diverges from committed snapshot (append-only contract broken)."
  echo
  echo "$ruby_stdout"
  echo
  echo "Fix: (a) do NOT reorder or remove enum values — saved payloads carry integer indices;"
  echo "     (b) if adding a new value, APPEND it AND update tools/ci/snapshots/battle_outcome_enum.txt"
  echo "         AND author a migration Callable in SaveMigrationRegistry AND bump CURRENT_SCHEMA_VERSION."
  exit 1
fi

echo "ADR-0003 §Schema Stability + TR-save-load-005 lint: $ruby_stdout"
exit 0
