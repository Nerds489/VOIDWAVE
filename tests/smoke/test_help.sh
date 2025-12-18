#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

echo "Testing --help..."
"$ROOT/voidwave" --help >/dev/null
echo "PASS: --help"

echo "Testing voidwave-install --help..."
"$ROOT/voidwave-install" --help >/dev/null
echo "PASS: voidwave-install --help"
