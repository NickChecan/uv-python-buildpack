#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPILE_SCRIPT="$ROOT_DIR/bin/compile"
TMP_DIR="$(mktemp -d /tmp/compile-test.XXXXXX)"
TEST_ROOT="$TMP_DIR/test-root"
FAKE_BIN_DIR="$TMP_DIR/fake-bin"

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

assert_file_contains() {
  local file_path="$1"
  local expected="$2"
  local message="$3"

  if ! grep -Fq -- "$expected" "$file_path"; then
    echo "FAIL: $message"
    echo "Expected to find: $expected"
    echo "In file: $file_path"
    echo "Actual file contents:"
    cat "$file_path"
    exit 1
  fi
}

assert_path_exists() {
  local file_path="$1"
  local message="$2"

  if [ ! -e "$file_path" ]; then
    echo "FAIL: $message"
    echo "Missing path: $file_path"
    exit 1
  fi
}

setup_fake_commands() {
  local pip_available="${1:-1}"
  mkdir -p "$FAKE_BIN_DIR"

  cat > "$FAKE_BIN_DIR/python3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ge 2 ] && [ "$1" = "-c" ] && [ "$2" = "import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")" ]; then
  printf '3.13\n'
  exit 0
fi

if [ "$#" -ge 3 ] && [ "$1" = "-m" ] && [ "$2" = "pip" ] && [ "$3" = "--version" ]; then
  if [ "${FAKE_PIP_AVAILABLE:-1}" = "1" ]; then
    printf 'pip 24.0 from /fake/site-packages/pip (python 3.13)\n'
    exit 0
  fi

  echo "No module named pip" >&2
  exit 1
fi

if [ "$#" -ge 3 ] && [ "$1" = "-m" ] && [ "$2" = "ensurepip" ] && [ "$3" = "--upgrade" ]; then
  log_file="${TEST_ROOT}/ensurepip.log"
  mkdir -p "$(dirname "$log_file")"
  printf '%s\n' "$*" >> "$log_file"
  exit 0
fi

if [ "$#" -ge 3 ] && [ "$1" = "-m" ] && [ "$2" = "pip" ]; then
  log_file="${TEST_ROOT}/pip.log"
  mkdir -p "$(dirname "$log_file")"
  printf '%s\n' "$*" >> "$log_file"

  target_dir=""
  requirements_file=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target)
        shift
        target_dir="$1"
        ;;
      -r)
        shift
        requirements_file="$1"
        ;;
    esac
    shift || true
  done

  if [ -n "$target_dir" ]; then
    mkdir -p "$target_dir"
    touch "$target_dir/fake-installed-package.txt"
  fi

  if [ -n "$requirements_file" ]; then
    printf '%s\n' "$requirements_file" > "${TEST_ROOT}/last-requirements-file.txt"
  fi

  exit 0
fi

echo "Unexpected python3 invocation: $*" >&2
exit 1
EOF

  cat > "$FAKE_BIN_DIR/uv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TEST_ROOT}/uv.log"
mkdir -p "$(dirname "$log_file")"
printf '%s\n' "$*" >> "$log_file"

if [ "$1" = "export" ]; then
  output_file=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -o)
        shift
        output_file="$1"
        ;;
    esac
    shift || true
  done

  cat > "$output_file" <<'REQ'
fastapi==0.135.3
uvicorn==0.44.0
REQ
  exit 0
fi

echo "Unexpected uv invocation: $*" >&2
exit 1
EOF

  chmod +x "$FAKE_BIN_DIR/python3" "$FAKE_BIN_DIR/uv"
  FAKE_PIP_AVAILABLE="$pip_available"
}

run_compile() {
  local build_dir="$1"
  local cache_dir="$2"
  local env_dir="$3"
  local output_file="$TEST_ROOT/output.txt"

  set +e
  PATH="$FAKE_BIN_DIR:/usr/bin:/bin" TEST_ROOT="$TEST_ROOT" FAKE_PIP_AVAILABLE="${FAKE_PIP_AVAILABLE:-1}" "$COMPILE_SCRIPT" "$build_dir" "$cache_dir" "$env_dir" >"$output_file" 2>&1
  status=$?
  set -e

  output="$(cat "$output_file")"
}

test_compile_succeeds_for_locked_uv_project() {
  # Arrange
  local build_dir="$TEST_ROOT/success/build"
  local cache_dir="$TEST_ROOT/success/cache"
  local env_dir="$TEST_ROOT/success/env"
  local site_packages_dir="$build_dir/.python_packages/lib/python3.13/site-packages"
  local profile_file="$build_dir/.profile.d/python.sh"
  local export_file="$build_dir/.uv-export-requirements.txt"

  mkdir -p "$build_dir" "$cache_dir" "$env_dir"
  touch "$build_dir/pyproject.toml" "$build_dir/uv.lock"
  setup_fake_commands

  # Act
  run_compile "$build_dir" "$cache_dir" "$env_dir"

  # Assert
  assert_exit_code "$status" 0 "compile should succeed for a locked uv project"
  assert_contains "$output" "Detected uv project with lockfile. Installing dependencies with uv." "compile should announce supported uv projects"
  assert_path_exists "$site_packages_dir" "compile should create the staged site-packages directory"
  assert_path_exists "$profile_file" "compile should write a profile script for runtime imports"
  assert_path_exists "$export_file" "compile should write the exported requirements file"
  assert_file_contains "$profile_file" "$site_packages_dir" "profile script should add staged dependencies to PYTHONPATH"
  assert_file_contains "$TEST_ROOT/uv.log" "export --locked --format requirements-txt --no-emit-local -o $export_file" "compile should export locked third-party dependencies"
  assert_file_contains "$TEST_ROOT/pip.log" "-m pip install uv" "compile should install uv with pip"
  assert_file_contains "$TEST_ROOT/pip.log" "--no-deps --target $site_packages_dir -r $export_file" "compile should install exported dependencies into the staged site-packages directory"
}

test_compile_bootstraps_pip_when_missing() {
  # Arrange
  local build_dir="$TEST_ROOT/missing-pip/build"
  local cache_dir="$TEST_ROOT/missing-pip/cache"
  local env_dir="$TEST_ROOT/missing-pip/env"

  mkdir -p "$build_dir" "$cache_dir" "$env_dir"
  touch "$build_dir/pyproject.toml" "$build_dir/uv.lock"
  setup_fake_commands 0

  # Act
  run_compile "$build_dir" "$cache_dir" "$env_dir"

  # Assert
  assert_exit_code "$status" 0 "compile should bootstrap pip when the interpreter does not ship it"
  assert_contains "$output" "pip not found for python3. Bootstrapping with ensurepip." "compile should explain when it needs to bootstrap pip"
  assert_file_contains "$TEST_ROOT/ensurepip.log" "-m ensurepip --upgrade" "compile should bootstrap pip before using it"
  assert_file_contains "$TEST_ROOT/pip.log" "-m pip install uv" "compile should continue with pip installs after bootstrapping"
}

test_compile_adds_src_directory_to_pythonpath_when_present() {
  # Arrange
  local build_dir="$TEST_ROOT/src-layout/build"
  local cache_dir="$TEST_ROOT/src-layout/cache"
  local env_dir="$TEST_ROOT/src-layout/env"
  local profile_file="$build_dir/.profile.d/python.sh"

  mkdir -p "$build_dir/src" "$cache_dir" "$env_dir"
  touch "$build_dir/pyproject.toml" "$build_dir/uv.lock"
  setup_fake_commands

  # Act
  run_compile "$build_dir" "$cache_dir" "$env_dir"

  # Assert
  assert_exit_code "$status" 0 "compile should succeed for src-layout projects"
  assert_file_contains "$profile_file" "$build_dir/src" "profile script should add src layout projects to PYTHONPATH"
}

test_compile_fails_when_lockfile_is_missing() {
  # Arrange
  local build_dir="$TEST_ROOT/missing-lock/build"
  local cache_dir="$TEST_ROOT/missing-lock/cache"
  local env_dir="$TEST_ROOT/missing-lock/env"

  mkdir -p "$build_dir" "$cache_dir" "$env_dir"
  touch "$build_dir/pyproject.toml"
  setup_fake_commands

  # Act
  run_compile "$build_dir" "$cache_dir" "$env_dir"

  # Assert
  assert_exit_code "$status" 1 "compile should fail when uv.lock is missing"
  assert_contains "$output" "No supported uv project found. Expected both pyproject.toml and uv.lock." "compile should explain why unsupported projects fail"
}

test_compile_succeeds_for_locked_uv_project
test_compile_bootstraps_pip_when_missing
test_compile_adds_src_directory_to_pythonpath_when_present
test_compile_fails_when_lockfile_is_missing

echo "PASS: compile unit tests"
