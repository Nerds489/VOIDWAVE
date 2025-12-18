#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Smoke Test: Status Command
#═══════════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1

# Status command
./bin/voidwave status > /dev/null

echo "Status smoke test passed"
