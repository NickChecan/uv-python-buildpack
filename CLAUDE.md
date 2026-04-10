# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Cloud Foundry buildpack for deploying Python applications managed with the `uv` package manager. Buildpacks must implement three scripts: `bin/detect`, `bin/compile`, and `bin/release`.

## Commands

```bash
# Run unit tests
make unit-test

# Run smoke tests (requires Python 3.13 on PATH)
make smoke-test

# Run smoke tests for a specific app
make test-buildpack APP_DIR=test/smoke/my-app-1

# Package the buildpack into a zip
make build

# Clean up temp staging directories
make clean-test-buildpack

# Stage and run an app locally on 127.0.0.1:8000
make start-local APP_DIR=test/smoke/my-app-1
```

Unit tests are shell scripts in `test/unit/` — run a single file directly with `bash test/unit/detect_test.sh`.

## Architecture

### Buildpack Flow

**bin/detect**: Exits 0 ("python-uv") if both `pyproject.toml` and `uv.lock` exist; exits 1 otherwise.

**bin/compile**: The main build script. Receives `BUILD_DIR`, `CACHE_DIR`, `ENV_DIR`.
1. Installs `uv` (prefers system `uv`, falls back to standalone installer)
2. Reads `.python-version` to pick Python version
3. Installs managed Python into `$BUILD_DIR/.uv/python/` via `uv python install`
4. Creates Python shims at `.python/bin/python3` and `.python/bin/python` using *relative paths* — critical because CF relocates the droplet after staging
5. Exports deps to requirements.txt via `uv export`, installs to `.python_packages/`
6. Writes `.profile.d/python.sh` to set `PATH` and `PYTHONPATH` at runtime

**bin/release**: Determines the web startup command (output as YAML `default_process_types`).
Priority order:
1. If `Procfile` exists → exits 0 (CF uses it directly)
2. Console script in `[project.scripts]` matching `[project].name`
3. A `start` script in `[project.scripts]`
4. `python3 main.py` fallback
5. `python3 app.py` fallback

Console scripts like `server.main:start` are converted to `python3 -c "from server.main import start; start()"`.

### Test Structure

- `test/unit/` — shell script unit tests for each bin script (detect, compile, release). Use fake `uv`/Python binaries to avoid real installs.
- `test/smoke/` — four fixture apps covering different scenarios:
  - `my-app-1`: flat layout, `main.py` entry point
  - `my-app-2`: `src/` layout, `start` console script
  - `my-app-3`: `src/` layout, script name matches project name
  - `my-app-4`: uses `Procfile` (tests that release script is bypassed)

### Key Design Constraints

- **Relative path shims**: Python wrapper scripts must use paths relative to the app root, not absolute paths, because CF relocates the droplet between staging and runtime.
- **Dual layout support**: `.profile.d/python.sh` must handle both `src/` layout and flat layout for `PYTHONPATH`.
- **No external runtime deps**: The buildpack must work without `python` or `uv` pre-installed on the staging machine.
- **`bin/release` requires `BUILD_DIR` as `$1`**: All three bin scripts now `cd` into their first argument. The Makefile and unit tests pass the directory explicitly — do not call `bin/release` without arguments.
- **MTA deployments must exclude `.venv` via `build-parameters.ignore`**: `mbt build` does not respect `.cfignore` or `.gitignore`. A local `.venv` built on macOS will be packaged into the `.mtar` and cause an exec format error on the Linux CF stack. Always add `.venv/` to `build-parameters.ignore` in `mta.yaml`.

### Release Process

Releases are automated via `semantic-release` (`.releaserc.json`). On push to `main`, if commits follow conventional commit format, it bumps `VERSION`, runs `buildpack-packager build -cached -any-stack`, and creates a GitHub release with the packaged zip.
