#!/usr/bin/env bash
# tools/ci/lint_save_context_export_discipline.sh
#
# ADR-0003 §Schema Stability + CR-SL-2 + TR-save-load-018:
# Every typed `var` declaration in SaveContext and EchoMark MUST be preceded
# by an `@export` annotation. Non-exported fields are SILENTLY DROPPED by
# ResourceSaver during serialization — a save that appears to succeed will
# lose undecorated fields on the next load, corrupting the save state.
#
# Files scanned:
#   src/core/payloads/save_context.gd
#   src/core/payloads/echo_mark.gd
#   (add future save-serialized Resource subclasses to FILES_TO_SCAN below)
#
# Rules:
#   - For each `var <name>: <type>` line (typed var, NOT static var):
#     walk backward through preceding lines, skipping blank lines and
#     doc-comment lines (## or #). The first non-empty non-comment line above
#     MUST be `@export` or an `@export_*` annotation variant.
#   - `static var` declarations are excluded — they are class-level state,
#     not instance fields, and are never serialized by ResourceSaver.
#   - Lines inside inner classes are also checked (future schema additions).
#
# Exit code: 0 if clean, 1 if violations found, 2+ if lint-infra crash.
#
# Negative-test recipe (manual, for AC-LINT-EXPORT_DISCIPLINE verification):
#   1. Remove `@export` from one var declaration in save_context.gd or echo_mark.gd,
#      e.g. change `@export var schema_version: int = 1` to `var schema_version: int = 1`.
#   2. Run: bash tools/ci/lint_save_context_export_discipline.sh
#   3. Assert exit code is 1 and the violating field name + line number are reported.
#   4. Revert the edit and confirm exit code returns to 0.

# Follow lint_save_paths.sh pattern: no `set -e`; triage Ruby exit codes.
set -uo pipefail

ruby_stdout=$(ruby -e '
  FILES_TO_SCAN = [
    "src/core/payloads/save_context.gd",
    "src/core/payloads/echo_mark.gd",
  ]

  violations = []

  FILES_TO_SCAN.each do |file|
    unless File.exist?(file)
      # Missing file is treated as an infra error rather than a pass — the files
      # MUST exist (they are part of the ratified schema per ADR-0003).
      $stderr.puts "LINT INFRA ERROR: Required schema file not found: #{file}"
      exit 2
    end

    lines = File.readlines(file)

    lines.each_with_index do |line, idx|
      line_clean = line.chomp

      # Match typed var declarations: `var <name>: <type>`
      # Exclude `static var` — not instance fields; ResourceSaver ignores them.
      next unless line_clean =~ /^\s*var\s+(\w+)\s*:/
      next if line_clean =~ /^\s*static\s+var\b/

      field_name = $1

      # Walk backward to find the nearest non-empty, non-comment line.
      found_export = false
      look = idx - 1
      while look >= 0
        prev = lines[look].chomp.strip
        look -= 1

        # Skip blank lines.
        next if prev.empty?

        # Skip doc comments (## or plain #).
        next if prev.start_with?("#")

        # The first non-blank non-comment line above must be @export or @export_*.
        if prev.start_with?("@export")
          found_export = true
        end
        # Either way, stop the backward walk — we found the first real line.
        break
      end

      unless found_export
        violations << "#{file}:#{idx+1}: #{line_clean.strip}\n" \
          "  reason: field `#{field_name}` has no @export annotation on the preceding line " \
          "(ADR-0003 §Schema Stability CR-SL-2: undecorated fields are SILENTLY DROPPED by ResourceSaver)"
      end
    end
  end

  puts violations.join("\n\n")
  exit(violations.any? ? 1 : 0)
' 2>&1)
ruby_exit=$?

# Distinguish lint-infra crash (2+) from normal exit (0 clean, 1 violations).
if [ "$ruby_exit" -gt 1 ]; then
  echo "Lint tool error: Ruby exited with code $ruby_exit" >&2
  echo "Ruby output:" >&2
  echo "$ruby_stdout" >&2
  echo "This is a lint-infrastructure failure, NOT a @export discipline violation." >&2
  exit 2
fi

violations="$ruby_stdout"

if [ -n "$violations" ]; then
  echo "ADR-0003 §Schema Stability + CR-SL-2 violation: var declaration without @export annotation."
  echo "Non-@export fields in SaveContext / EchoMark are SILENTLY DROPPED by ResourceSaver."
  echo "A save that appears to succeed will lose undecorated fields — corrupting save state."
  echo
  echo "$violations"
  echo
  echo "Fix: add @export on the line immediately above the flagged var declaration:"
  echo "  @export var <field_name>: <type> = <default>"
  exit 1
fi

echo "CR-SL-2 + ADR-0003 §Schema Stability @export discipline lint: OK — all SaveContext + EchoMark fields are @export-annotated."
exit 0
