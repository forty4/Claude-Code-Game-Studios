#!/usr/bin/env bash
# tools/ci/lint_save_resource_loader_cache_mode_ignore.sh
#
# ADR-0003 §Decision §Atomic Write step 3 + CR-SL-11 + TR-save-load-016:
# Every ResourceLoader.load(...) call site in save-load source files MUST
# pass ResourceLoader.CACHE_MODE_IGNORE (or the equivalent integer 3) as the
# cache_mode argument. Omitting this flag causes ResourceLoader to return a
# cached instance on repeat loads — violating the CACHE_MODE_IGNORE invariant
# required for idempotent save-slot enumeration and safe reload after migration.
#
# Files scanned:
#   src/core/save_manager.gd
#   src/core/save_migration_registry.gd
#   (add future save-load source files to FILES_TO_SCAN below)
#
# Exit code: 0 if clean, 1 if violations found, 2+ if lint-infra crash.
#
# Negative-test recipe (manual, for AC-LINT-CACHE_MODE_IGNORE verification):
#   1. Edit one ResourceLoader.load(...) call in src/core/save_manager.gd to
#      remove CACHE_MODE_IGNORE from its args (e.g. change to
#      ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)).
#   2. Run: bash tools/ci/lint_save_resource_loader_cache_mode_ignore.sh
#   3. Assert exit code is 1 and the violation line number is reported.
#   4. Revert the edit and confirm exit code returns to 0.

# Follow lint_save_paths.sh pattern: no `set -e`; triage Ruby exit codes explicitly.
set -uo pipefail

ruby_stdout=$(ruby -e '
  FILES_TO_SCAN = [
    "src/core/save_manager.gd",
    "src/core/save_migration_registry.gd",
  ]

  violations = []

  FILES_TO_SCAN.each do |file|
    next unless File.exist?(file)

    lines = File.readlines(file)
    lines.each_with_index do |line, idx|
      line_clean = line.chomp

      # Strip GDScript line comments (# after whitespace or start-of-line)
      # to avoid false positives from commented-out code.
      line_no_comment = line_clean.sub(/(^|\s)#.*$/, "\\1")

      # Check if this line contains a ResourceLoader.load( call.
      next unless line_no_comment =~ /ResourceLoader\.load\s*\(/

      # Check whether CACHE_MODE_IGNORE is present on THIS line.
      # Multi-line calls: if the call opens on this line, also check up to
      # 4 subsequent lines for the CACHE_MODE_IGNORE argument.
      window = [line_no_comment]
      (1..4).each do |lookahead|
        break if idx + lookahead >= lines.size
        next_line = lines[idx + lookahead].chomp.sub(/(^|\s)#.*$/, "\\1")
        window << next_line
        # Stop lookahead at the closing paren of the call.
        break if next_line.include?(")")
      end

      combined = window.join(" ")
      unless combined.include?("CACHE_MODE_IGNORE")
        violations << "#{file}:#{idx+1}: #{line_clean.strip}\n" \
          "  reason: ResourceLoader.load() call missing CACHE_MODE_IGNORE arg (CR-SL-11)"
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
  echo "This is a lint-infrastructure failure, NOT a CACHE_MODE_IGNORE violation." >&2
  exit 2
fi

violations="$ruby_stdout"

if [ -n "$violations" ]; then
  echo "ADR-0003 §Atomic Write step 3 + CR-SL-11 violation: ResourceLoader.load() missing CACHE_MODE_IGNORE."
  echo "Every ResourceLoader.load() in save-load code MUST pass ResourceLoader.CACHE_MODE_IGNORE."
  echo "Omitting it allows stale cached Resources to be returned on repeat loads,"
  echo "defeating the atomic-write invariant and save-slot idempotency contract."
  echo
  echo "$violations"
  echo
  echo "Fix: update the call to:"
  echo "  ResourceLoader.load(path, \"\", ResourceLoader.CACHE_MODE_IGNORE)"
  exit 1
fi

echo "CR-SL-11 + ADR-0003 §Atomic Write CACHE_MODE_IGNORE lint: OK — all ResourceLoader.load() calls are clean."
exit 0
