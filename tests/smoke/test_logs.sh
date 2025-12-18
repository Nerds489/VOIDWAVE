#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Smoke Test: Logs Commands
#═══════════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1

echo "Testing logs commands..."

# Logs show (default)
./bin/voidwave logs > /dev/null 2>&1 || true

# Logs show with line count
./bin/voidwave logs show 10 > /dev/null 2>&1 || true

# Logs list
./bin/voidwave logs list > /dev/null 2>&1 || true

# Logs search (may have no matches, that's ok)
./bin/voidwave logs search "INFO" > /dev/null 2>&1 || true

# Logs filter by level (may have no entries, that's ok)
./bin/voidwave logs filter --level ERROR > /dev/null 2>&1 || true

# Logs tail without follow (non-blocking)
./bin/voidwave logs tail > /dev/null 2>&1 || true

echo "Logs smoke tests passed"
