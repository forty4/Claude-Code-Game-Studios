#!/usr/bin/env bash
# tools/ci/lint_hero_database_validation.sh
#
# TR-hero-database-011 — F-1..F-4 stat-balance + SPI + growth-ceiling +
# MVP-roster validation Polish-tier lint.
#
# POLISH-TIER DEFERRED per ADR-0007 §11 + N2 (5-precedent Polish-deferral pattern:
#   ADR-0008 + ADR-0006 + ADR-0009 + ADR-0012 + ADR-0007 = pattern is now
#   load-bearing project discipline).
#
# Reactivation triggers (BOTH must be true to enable full implementation):
#   1. BalanceConstants threshold append — balance_entities.json gains 6 keys:
#        STAT_TOTAL_MIN, STAT_TOTAL_MAX, SPI_WARNING_THRESHOLD, STAT_HARD_CAP,
#        MVP_FLOOR_OFFSET, MVP_CEILING_OFFSET (per ADR-0006 forward-compat)
#   2. ≥30 hero records authored (Alpha-tier roster milestone)
#
# Validation passes (when reactivated):
#   F-1: stat_total ∈ [STAT_TOTAL_MIN=180, STAT_TOTAL_MAX=280] (boundary inclusive)
#   F-2: SPI = (stat_max - stat_min) / stat_avg < SPI_WARNING_THRESHOLD=0.5
#   F-3: stat_projected(L) ≤ STAT_HARD_CAP=100 at L=L_cap (Character Growth ADR L_cap)
#   F-4: MVP roster: stat_total ∈ [190, 260] AND 4-distinct-dominant_stat coverage
#
# Cross-references:
#   docs/architecture/ADR-0007-hero-database.md §11 + N2 (Polish-deferral rationale)
#   docs/architecture/ADR-0006-balance-data.md (forward-compat threshold reads)
#   docs/tech-debt-register.md TD-044 (Polish-tier full implementation)

set -uo pipefail

echo "lint_hero_database_validation: Polish-deferred — F-1..F-4 stat-balance lint not yet active."
echo "  See ADR-0007 §11 + tech-debt-register.md TD-044 for reactivation triggers."
exit 0
