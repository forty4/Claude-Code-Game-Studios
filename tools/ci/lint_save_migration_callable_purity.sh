#!/usr/bin/env bash
# tools/ci/lint_save_migration_callable_purity.sh
#
# ADR-0003 §Schema Stability §Migration Callable Purity + CR-SL-13 + TR-save-load-017:
# Migration Callables in SaveMigrationRegistry._migrations MUST be pure functions —
# no captured node, singleton, or object references. Captured references outlive the
# migration scope and create dangling references into freed scenes.
#
# HEURISTIC lint — false-positive risk acknowledged:
#   GDScript closures/lambdas are textual; this lint cannot perform full scope analysis.
#   It checks for common anti-patterns (captured autoload identifiers, NodePath refs,
#   get_node() calls, $ shortcuts) within the _migrations dictionary block.
#   The lint is FORWARD-LOOKING protection for when _migrations is populated post-MVP.
#   On current MVP HEAD, _migrations is empty `{}` — lint passes with zero findings.
#
# Files scanned:
#   src/core/save_migration_registry.gd
#
# Exit code: 0 if clean, 1 if violations found, 2+ if lint-infra crash.
#
# Negative-test recipe (manual, for AC-LINT-MIGRATION_PURITY verification):
#   1. Add a non-pure lambda to _migrations in save_migration_registry.gd, e.g.:
#        static var _migrations: Dictionary = {
#          1: func(ctx: SaveContext) -> SaveContext:
#            var node = get_node("/root/SaveManager")  # captured ref - FORBIDDEN
#            return ctx,
#        }
#   2. Run: bash tools/ci/lint_save_migration_callable_purity.sh
#   3. Assert exit code is 1 and the violating line + identifier are reported.
#   4. Revert the edit and confirm exit code returns to 0.
#
# Pure patterns that are ALLOWED inside migration lambdas:
#   - ctx.<field> access and assignment
#   - var / const declarations bound to literals or ctx fields
#   - push_error() / push_warning() standard built-ins
#   - return ctx
#   - Standard GDScript keywords and builtins (if/for/while/match/etc.)
#   - Primitive arithmetic, string ops, type checks (typeof/is/as)
#
# Forbidden patterns (captured outer-scope references):
#   - get_node(...) / $NodePath shortcuts
#   - Any identifier that resolves to an autoload (GameBus, SaveManager, etc.)
#     detected by referencing known autoload names from project.godot
#   - self (outside a pure context — lambdas don't inherit self semantics but
#     the keyword should not appear in a migration callable)

# Follow lint_save_paths.sh pattern: no `set -e`; triage Ruby exit codes.
set -uo pipefail

ruby_stdout=$(ruby -e '
  TARGET_FILE = "src/core/save_migration_registry.gd"

  unless File.exist?(TARGET_FILE)
    puts "INFO: #{TARGET_FILE} not found — skipping (no save-load source to check)."
    exit 0
  end

  lines = File.readlines(TARGET_FILE)

  # ── Step 1: locate _migrations static var declaration block ──────────────────
  # Use flag/next pattern (TG-3: avoid /start/,/end/ awk range self-close issue).
  # We look for the line containing `static var _migrations` and parse from there.

  migration_start_line = nil
  lines.each_with_index do |line, idx|
    if line =~ /static\s+var\s+_migrations\s*[=:]/
      migration_start_line = idx
      break
    end
  end

  if migration_start_line.nil?
    puts "INFO: No _migrations declaration found in #{TARGET_FILE} — nothing to validate."
    exit 0
  end

  # ── Step 2: extract the _migrations block (from `{` to matching `}`) ─────────
  # Walk from the declaration line forward until brace depth returns to 0.
  block_lines = []
  brace_depth = 0
  in_block = false

  lines[migration_start_line..].each_with_index do |line, rel_idx|
    abs_line_no = migration_start_line + rel_idx + 1  # 1-indexed
    line_no_comment = line.chomp.sub(/(^|\s)#.*$/, "\\1")

    brace_depth += line_no_comment.count("{")
    brace_depth -= line_no_comment.count("}")

    in_block = true if brace_depth >= 1
    block_lines << { line: line.chomp, no: abs_line_no } if in_block

    break if in_block && brace_depth <= 0
  end

  # ── Step 3: check for empty dict (MVP state — pass immediately) ───────────────
  combined_block = block_lines.map { |b| b[:line] }.join(" ")
  # Strip all whitespace and comments; if only {} remain, block is empty.
  stripped = combined_block.gsub(/(^|\s)#.*?($)/, "").gsub(/\s+/, "")
  if stripped =~ /^\{?\s*\}\s*$/ || stripped == "{}"
    puts "CR-SL-13 + ADR-0003 §Migration Callable Purity lint: OK — _migrations is empty (MVP state); 0 migrations to validate."
    exit 0
  end

  # ── Step 4: scan callable bodies for forbidden patterns ───────────────────────
  # Known autoload names (from project.godot [autoload] section — manual sync required).
  KNOWN_AUTOLOADS = %w[GameBus SceneManager SaveManager ScenarioRunner DestinyState StoryEvent].freeze

  # Built-in pure identifiers ALLOWED inside a migration lambda body.
  ALLOWED_BUILTINS = %w[
    ctx var const if elif else for while match break continue return
    func pass true false null and or not in as is typeof
    push_error push_warning print printerr str int float bool
    SaveContext EchoMark PackedStringArray Array Dictionary Vector2 Vector3
    Color Rect2 Transform2D Transform3D Quaternion StringName String
  ].freeze

  # Forbidden API patterns (regex matched against the no-comment line).
  FORBIDDEN_PATTERNS = [
    { pattern: /get_node\s*\(/, label: "get_node() — forbidden node reference in migration" },
    { pattern: /\x24[A-Za-z_]/, label: "$ NodePath shortcut — forbidden in migration" },
    { pattern: /\bself\b/, label: "self — forbidden in migration (no object context)" },
    { pattern: /\bOS\b\./, label: "OS singleton reference — forbidden in migration" },
    { pattern: /\bEngine\b\./, label: "Engine singleton reference — forbidden in migration" },
    { pattern: /\bClassDB\b\./, label: "ClassDB singleton reference — forbidden in migration" },
  ]

  # Also flag known autoload references.
  KNOWN_AUTOLOADS.each do |name|
    FORBIDDEN_PATTERNS << {
      pattern: /\b#{Regexp.escape(name)}\b/,
      label: "#{name} autoload reference — forbidden in migration (captured singleton)"
    }
  end

  violations = []

  # Only scan lines that are INSIDE a lambda body (between `func(` and matching `:`-block).
  # Heuristic: look for lines inside the block that are NOT the dict-key/Callable declaration lines.
  in_lambda = false
  block_lines.each do |entry|
    line_clean = entry[:line].chomp
    line_no_comment = line_clean.sub(/(^|\s)#.*$/, "\\1")
    line_no = entry[:no]

    # Detect start of a lambda (func( pattern or Callable( wrapping).
    in_lambda = true if line_no_comment =~ /\bfunc\s*\(/

    next unless in_lambda

    FORBIDDEN_PATTERNS.each do |fp|
      if line_no_comment =~ fp[:pattern]
        violations << "#{TARGET_FILE}:#{line_no}: #{line_clean.strip}\n  reason: #{fp[:label]}"
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
  echo "This is a lint-infrastructure failure, NOT a migration purity violation." >&2
  exit 2
fi

violations="$ruby_stdout"

# Check for INFO prefix (no error — just informational pass).
if echo "$violations" | grep -q "^INFO:\|^CR-SL-13"; then
  echo "$violations"
  exit 0
fi

if [ -n "$violations" ]; then
  echo "ADR-0003 §Migration Callable Purity + CR-SL-13 violation: captured reference in migration Callable."
  echo "Migration Callables in _migrations MUST be pure: operate only on the ctx SaveContext argument."
  echo "Captured node/singleton/object references create dangling refs into freed scenes."
  echo
  echo "$violations"
  echo
  echo "Fix: replace the captured reference with a pure equivalent operating only on ctx fields."
  echo "  FORBIDDEN:  var node = get_node(\"/root/SaveManager\"); node.do_thing()"
  echo "  ALLOWED:    ctx.some_field = ctx.other_field.to_lower(); return ctx"
  exit 1
fi

echo "CR-SL-13 + ADR-0003 §Migration Callable Purity lint: OK — all migration Callables are clean."
exit 0
