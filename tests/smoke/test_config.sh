#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Smoke Test: Configuration
#═══════════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")/../.."
export VW_NON_INTERACTIVE=1 VW_SUPPRESS_OUTPUT=1

echo "Testing config commands..."

# Config show
./bin/voidwave config show > /dev/null

# Config get
./bin/voidwave config get log_level > /dev/null

# Config path
./bin/voidwave config path > /dev/null

echo "Config smoke tests passed"
