#!/usr/bin/env bash
# tools/ci/lint_save_paths.sh
#
# ADR-0003 §Atomicity Guarantees + §Validation Criteria V-10 + TR-save-load-006:
# Save root MUST be user:// only. External storage (/sdcard), SAF URIs
# (content://), OS.get_user_data_dir() bypass, password-protected file access,
# and any absolute-filesystem-path string literal are forbidden in save code.
#
# Exit code: 0 if clean, 1 if violations found, 2+ if lint-infra crash.
# Scans: src/core/save_manager.gd, src/core/save_context.gd,
#        src/core/save_migration_registry.gd.

# Follow gamebus story-008 pattern: no `set -e` because we explicitly triage
# Ruby's exit codes (1 = violations, 2+ = crash) below.
set -uo pipefail

ruby_stdout=$(ruby -e '
  FILES_TO_SCAN = [
    "src/core/save_manager.gd",
    "src/core/save_context.gd",
    "src/core/save_migration_registry.gd",
  ]

  violations = []

  FILES_TO_SCAN.each do |file|
    next unless File.exist?(file)
    File.readlines(file).each_with_index do |line, idx|
      line_clean = line.chomp
      # Strip GDScript line comments: "#" following whitespace or start-of-line.
      # Keeps "#" inside string literals (e.g. "#foo") untouched.
      line_no_comment = line_clean.sub(/(^|\s)#.*$/, "\\1")

      reasons = []

      # Extract all string literals (double or single quoted) and check prefixes.
      line_no_comment.scan(/"([^"]*)"|'\''([^'\'']*)'\''/) do |dq, sq|
        literal = dq || sq
        next if literal.nil? || literal.empty?

        if literal.start_with?("/sdcard")
          reasons << "SAF external storage path \"#{literal[0, 40]}\" (Android /sdcard root)"
        elsif literal.start_with?("/") && literal.length > 1 && literal[1] =~ /[a-zA-Z0-9_]/
          # Require the second char to be a path-component character to exclude
          # single-char separators like "/" used in rstrip("/") and regex atoms.
          reasons << "absolute filesystem path \"#{literal[0, 40]}\" (must use user:// prefix)"
        elsif literal.start_with?("content://")
          reasons << "SAF URI \"#{literal[0, 40]}\" (Storage Access Framework)"
        end
      end

      # FileAccess.open_with_password — password-protected saves out of scope.
      if line_no_comment =~ /FileAccess\.open_with_password\b/
        reasons << "FileAccess.open_with_password (password-protected saves out of scope)"
      end

      # OS.get_user_data_dir() — bypasses user:// prefix; use user://saves directly.
      if line_no_comment =~ /OS\.get_user_data_dir\s*\(\s*\)/
        reasons << "OS.get_user_data_dir() bypass (use user:// prefix directly)"
      end

      reasons.each do |reason|
        violations << "#{file}:#{idx+1}: #{line_clean.strip}\n  reason: #{reason}"
      end
    end
  end

  puts violations.join("\n\n")
  exit(violations.any? ? 1 : 0)
' 2>&1)
ruby_exit=$?

# Distinguish crash (2+) from normal exit (0 clean, 1 violations).
if [ "$ruby_exit" -gt 1 ]; then
  echo "Lint tool error: Ruby exited with code $ruby_exit" >&2
  echo "Ruby output:" >&2
  echo "$ruby_stdout" >&2
  echo "This is a lint-infrastructure failure, NOT a save-path violation." >&2
  exit 2
fi

violations="$ruby_stdout"

if [ -n "$violations" ]; then
  echo "ADR-0003 §Atomicity Guarantees + TR-save-load-006 violation: forbidden save path pattern."
  echo "Save root MUST be user:// only. External storage does NOT guarantee atomic rename."
  echo
  echo "$violations"
  echo
  echo "Fix: use a user://saves/... path, or parameterize through _path_for()."
  exit 1
fi

echo "ADR-0003 §Atomicity + TR-save-load-006 lint: OK — save paths clean."
exit 0
