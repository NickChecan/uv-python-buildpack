#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_TEST_DIR="${UNIT_TEST_DIR:-$ROOT_DIR/test/unit}"

if [ ! -d "$UNIT_TEST_DIR" ]; then
  echo "Unit test directory not found: $UNIT_TEST_DIR"
  exit 1
fi

found_test=0

# Run every shell test in test/unit and stop immediately if one fails.
for test_file in "$UNIT_TEST_DIR"/*.sh; do
  [ -f "$test_file" ] || continue
  found_test=1
  echo "==> Running $(basename "$test_file")"
  bash "$test_file"
done

if [ "$found_test" -eq 0 ]; then
  echo "No unit test scripts found in $UNIT_TEST_DIR"
  exit 1
fi
