#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_SCRIPT="$ROOT_DIR/bin/release"
TMP_DIR="$(mktemp -d /tmp/release-test.XXXXXX)"
TEST_ROOT="$TMP_DIR/test-root"
FAKE_BIN_DIR="$TMP_DIR/fake-bin"
REAL_PYTHON3="$(command -v python3 || true)"

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

assert_contains() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != *"$expected"* ]]; then
    echo "FAIL: $message"
    echo "Expected to find: $expected"
    echo "Actual output: $actual"
    exit 1
  fi
}

assert_not_contains() {
  local actual="$1"
  local unexpected="$2"
  local message="$3"

  if [[ "$actual" == *"$unexpected"* ]]; then
    echo "FAIL: $message"
    echo "Did not expect to find: $unexpected"
    echo "Actual output: $actual"
    exit 1
  fi
}

setup_fake_python_commands() {
  if [ -z "$REAL_PYTHON3" ]; then
    echo "FAIL: python3 is required to run release unit tests"
    exit 1
  fi

  mkdir -p "$FAKE_BIN_DIR"

  cat > "$FAKE_BIN_DIR/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$REAL_PYTHON3" "$@"
EOF

  chmod +x "$FAKE_BIN_DIR/python3"
}

run_release() {
  local app_dir="$1"
  local output_file="$TEST_ROOT/output.txt"

  set +e
  (
    cd "$app_dir"
    PATH="$FAKE_BIN_DIR:/usr/bin:/bin" REAL_PYTHON3="$REAL_PYTHON3" "$RELEASE_SCRIPT"
  ) >"$output_file" 2>&1
  status=$?
  set -e

  output="$(cat "$output_file")"
}

test_release_exits_when_procfile_exists() {
  # Arrange
  local app_dir="$TEST_ROOT/procfile-app"
  mkdir -p "$app_dir"
  touch "$app_dir/Procfile"
  setup_fake_python_commands

  # Act
  run_release "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "release should exit successfully when a Procfile exists"
  assert_contains "$output" "" "release should not emit default process types when Procfile exists"
}

test_release_prefers_project_name_script_over_start() {
  # Arrange
  local app_dir="$TEST_ROOT/project-script-app"
  mkdir -p "$app_dir"
  setup_fake_python_commands
  cat > "$app_dir/pyproject.toml" <<'EOF'
[project]
name = "my-app"

[project.scripts]
my-app = "server.main:run"
start = "server.main:start"
EOF

  # Act
  run_release "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "release should succeed for pyproject-based apps"
  assert_contains "$output" 'web: python3 -c "from server.main import run; run()"' "release should prefer the script named after project.name"
  assert_not_contains "$output" 'start; start()' "release should not choose the start script when a project-name script exists"
}

test_release_falls_back_to_start_script() {
  # Arrange
  local app_dir="$TEST_ROOT/start-script-app"
  mkdir -p "$app_dir"
  setup_fake_python_commands
  cat > "$app_dir/pyproject.toml" <<'EOF'
[project]
name = "my-app"

[project.scripts]
start = "server.main:start"
EOF

  # Act
  run_release "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "release should succeed when only a start script is defined"
  assert_contains "$output" 'web: python3 -c "from server.main import start; start()"' "release should fall back to the start script"
}

test_release_falls_back_to_main_py() {
  # Arrange
  local app_dir="$TEST_ROOT/main-py-app"
  mkdir -p "$app_dir"
  touch "$app_dir/main.py"
  setup_fake_python_commands

  # Act
  run_release "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "release should succeed for apps with main.py"
  assert_contains "$output" 'web: python3 main.py' "release should use main.py when no scripts are configured"
}

test_release_falls_back_to_app_py() {
  # Arrange
  local app_dir="$TEST_ROOT/app-py-app"
  mkdir -p "$app_dir"
  touch "$app_dir/app.py"
  setup_fake_python_commands

  # Act
  run_release "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "release should succeed for apps with app.py"
  assert_contains "$output" 'web: python3 app.py' "release should use app.py when main.py is absent"
}

test_release_uses_uvicorn_fallback_when_no_entrypoint_exists() {
  # Arrange
  local app_dir="$TEST_ROOT/uvicorn-fallback-app"
  mkdir -p "$app_dir"
  setup_fake_python_commands

  # Act
  run_release "$app_dir"

  # Assert
  assert_exit_code "$status" 0 "release should still succeed when no explicit entrypoint exists"
  assert_contains "$output" 'web: python3 -m uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}' "release should emit the uvicorn fallback command"
}

test_release_exits_when_procfile_exists
test_release_prefers_project_name_script_over_start
test_release_falls_back_to_start_script
test_release_falls_back_to_main_py
test_release_falls_back_to_app_py
test_release_uses_uvicorn_fallback_when_no_entrypoint_exists

echo "PASS: release unit tests"
