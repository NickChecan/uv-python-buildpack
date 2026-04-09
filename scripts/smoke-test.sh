#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Allow CI or local runs to point at a different smoke-fixture directory.
SMOKE_DIR="${SMOKE_DIR:-$ROOT_DIR/test/smoke}"

if [ ! -d "$SMOKE_DIR" ]; then
  echo "Smoke test directory not found: $SMOKE_DIR"
  exit 1
fi

found_app=0

# Run the single-app make target for every fixture app under test/smoke.
for app_dir in "$SMOKE_DIR"/*; do
  [ -d "$app_dir" ] || continue
  found_app=1
  echo "==> Smoke testing $(basename "$app_dir")"
  if ! make -C "$ROOT_DIR" test-buildpack APP_DIR="${app_dir#$ROOT_DIR/}"; then
    # Clean staged files before failing so the next run starts fresh.
    make -C "$ROOT_DIR" clean-test-buildpack
    exit 1
  fi
  # Clean after every app to keep smoke-test runs isolated from each other.
  make -C "$ROOT_DIR" clean-test-buildpack
done

if [ "$found_app" -eq 0 ]; then
  echo "No smoke test apps found in $SMOKE_DIR"
  exit 1
fi
