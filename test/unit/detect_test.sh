#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DETECT_SCRIPT="$ROOT_DIR/bin/detect"
TMP_DIR="$(mktemp -d /tmp/detect-test.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL: $message"
    echo "Expected exit code: $expected"
    echo "Actual exit code: $actual"
    exit 1
  fi
}

assert_output() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $message"
    echo "Expected output: $expected"
    echo "Actual output: $actual"
    exit 1
  fi
}

run_detect() {
  local app_dir="$1"
  local output_file="$TMP_DIR/output.txt"

  set +e
  (
    cd "$app_dir"
    "$DETECT_SCRIPT"
  ) >"$output_file" 2>&1
  status=$?
  set -e

  output="$(cat "$output_file")"
}

test_detect_succeeds_when_pyproject_and_lockfile_exist() {
  # Arrange
  local app_dir="$TMP_DIR/success-case"
  mkdir -p "$app_dir"
  touch "$app_dir/pyproject.toml" "$app_dir/uv.lock"

  # Act
  run_detect "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "detect should succeed when both uv files exist"
  assert_output "$output" "python-uv" "detect should print the buildpack id when it succeeds"
}

test_detect_fails_when_lockfile_is_missing() {
  # Arrange
  local app_dir="$TMP_DIR/missing-lock"
  mkdir -p "$app_dir"
  touch "$app_dir/pyproject.toml"

  # Act
  run_detect "$app_dir"

  # Assert
  assert_exit_code "$status" 1 "detect should fail when uv.lock is missing"
  assert_output "$output" "" "detect should not print anything when detection fails"
}

test_detect_fails_when_pyproject_is_missing() {
  # Arrange
  local app_dir="$TMP_DIR/missing-pyproject"
  mkdir -p "$app_dir"
  touch "$app_dir/uv.lock"

  # Act
  run_detect "$app_dir"

  # Assert
  assert_exit_code "$status" 1 "detect should fail when pyproject.toml is missing"
  assert_output "$output" "" "detect should not print anything when detection fails"
}

test_detect_succeeds_when_extra_files_are_present() {
  # Arrange
  local app_dir="$TMP_DIR/extra-files"
  mkdir -p "$app_dir"
  touch "$app_dir/pyproject.toml" "$app_dir/uv.lock" "$app_dir/README.md"

  # Act
  run_detect "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "detect should ignore unrelated files"
  assert_output "$output" "python-uv" "detect should still identify a supported uv app"
}

test_detect_succeeds_when_pyproject_and_lockfile_exist
test_detect_fails_when_lockfile_is_missing
test_detect_fails_when_pyproject_is_missing
test_detect_succeeds_when_extra_files_are_present

echo "PASS: detect unit tests"
