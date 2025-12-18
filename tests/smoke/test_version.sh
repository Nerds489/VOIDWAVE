#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

version_output=$("$ROOT/voidwave" --version 2>&1)
version_file="$(head -n1 "$ROOT/VERSION" | tr -d '[:space:]')"

echo "Got: $version_output"

if [[ "$version_output" == *"$version_file"* ]]; then
    echo "PASS: version matches VERSION file ($version_file)"
    exit 0
else
    echo "FAIL: expected to find $version_file in version output"
    exit 1
fi
