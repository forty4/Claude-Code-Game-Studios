#!/usr/bin/env bash
# tools/ci/lint_per_frame_emit.sh
#
# ADR-0001 §Implementation Guidelines §7 + §Validation Criteria V-7:
# Per-frame GameBus emits are forbidden. This script detects any
# GameBus.<signal>.emit(...) calls inside func _process(...) or
# func _physics_process(...) bodies in src/**/*.gd files.
#
# Exit code: 1 if violations found, 0 if clean.
# Excludes: tests/, prototypes/, tools/ (only scans src/).

# Note: we do NOT use `set -e` because we explicitly handle Ruby's non-zero
# exit codes below. Ruby exits 1 on violations (normal failure), 2+ on crash
# (syntax error, missing binary, corrupted file). Using `set -e` + `|| true`
# cannot distinguish these cases — a crash would silently pass.
set -uo pipefail

ruby_stdout=""
ruby_exit=0
if ! ruby_stdout=$(ruby -e '
  violations = []
  Dir.glob("src/**/*.gd").each do |file|
    current_func = nil
    indent_base = nil
    File.readlines(file).each_with_index do |line, idx|
      line_without_newline = line.chomp

      # Detect function entry: func _process(...) or func _physics_process(...)
      if line =~ /^(\s*)func\s+(_process|_physics_process)\b/
        indent_base = $1.length
        current_func = $2
      # Detect body-scope emit: GameBus.<signal>.emit(...) inside the function.
      # Note: this regex intentionally matches GameBus.sig.emit.call_deferred(...)
      # too — deferred emission from _process still couples signal cadence to
      # frame timing, so flagging it is correct per ADR-0001 §7.
      elsif current_func && line =~ /^(\s+)GameBus\.\w+\.emit\b/
        curr_indent = $1.length
        if curr_indent > indent_base
          violations << "#{file}:#{idx+1}: #{line_without_newline.strip}"
        end
      # Detect function exit: dedent to same-or-less indent than func declaration.
      # Note: assumes consistent tab-based indentation (project convention).
      # Mixed tab/space would break the .length comparison.
      elsif current_func && line =~ /\S/ && line !~ /^\s*#/
        curr_indent = line[/^\s*/].length
        if curr_indent <= indent_base
          current_func = nil
          indent_base = nil
        end
      end
    end
  end
  puts violations
  exit(violations.any? ? 1 : 0)
' 2>&1); then
  ruby_exit=$?
fi

# Distinguish crash from normal exit codes.
# Ruby exit 0 = clean; exit 1 = violations found; exit 2+ = Ruby itself errored.
if [ "$ruby_exit" -gt 1 ]; then
  echo "Lint tool error: Ruby exited with code $ruby_exit" >&2
  echo "Ruby output:" >&2
  echo "$ruby_stdout" >&2
  echo "This is a lint-infrastructure failure, NOT a per-frame emit violation." >&2
  exit 2
fi

violations="$ruby_stdout"

if [ -n "$violations" ]; then
  echo "ADR-0001 §Implementation Guidelines §7 violation: per-frame GameBus emit forbidden."
  echo "The following lines emit GameBus signals inside _process or _physics_process:"
  echo "$violations"
  echo
  echo "Fix: move the emit to an event-driven handler (signal, input, timer)."
  echo "Or if the emit must fire periodically, use a Timer node with timeout signal."
  exit 1
fi

echo "ADR-0001 §Implementation Guidelines §7 lint: OK — no per-frame GameBus emits in src/."
exit 0
