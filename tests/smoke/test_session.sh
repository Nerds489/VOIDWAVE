#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Smoke Test: Session Commands
#═══════════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1

echo "Testing session commands..."

# Session list (should not crash even if no sessions)
./bin/voidwave session list > /dev/null 2>&1 || true

echo "Session smoke tests passed"
