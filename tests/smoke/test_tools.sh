#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# VOIDWAVE Smoke Test: Tool Availability
#═══════════════════════════════════════════════════════════════════════════════

set -e
cd "$(dirname "$0")/../.."

echo "Testing tool availability..."

# Verify main binaries exist and are executable
[[ -x "bin/voidwave" ]] || { echo "FAIL: bin/voidwave not executable"; exit 1; }
[[ -x "bin/voidwave-install" ]] || { echo "FAIL: bin/voidwave-install not executable"; exit 1; }

# Verify core libs exist
[[ -f "lib/core.sh" ]] || { echo "FAIL: lib/core.sh missing"; exit 1; }
[[ -f "lib/ui.sh" ]] || { echo "FAIL: lib/ui.sh missing"; exit 1; }
[[ -f "lib/utils.sh" ]] || { echo "FAIL: lib/utils.sh missing"; exit 1; }

echo "Tool smoke tests passed"
