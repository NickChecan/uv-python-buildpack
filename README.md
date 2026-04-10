# Cloud Foundry UV Python Buildpack

[![GitHub Release](https://img.shields.io/github/v/release/NickChecan/uv-python-buildpack)](https://github.com/NickChecan/uv-python-buildpack/releases/latest)
[![Pipeline](https://github.com/NickChecan/uv-python-buildpack/actions/workflows/pipeline.yaml/badge.svg)](https://github.com/NickChecan/uv-python-buildpack/actions/workflows/pipeline.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![semantic-release: angular](https://img.shields.io/badge/semantic--release-angular-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)

The standard Cloud Foundry [python-buildpack](https://github.com/cloudfoundry/python-buildpack) does not focus on modern Python workflows built around [uv](https://docs.astral.sh/uv/). This custom buildpack fills that gap by detecting uv-managed applications, installing a managed Python runtime, and staging locked dependencies for Cloud Foundry.

## What this buildpack expects

For an app to be detected by this buildpack, it must include:

- `pyproject.toml`
- `uv.lock`

If the app includes a `.python-version` file, the buildpack uses that version when installing Python.

## How startup is chosen

At release time, the buildpack chooses the web command in this order:

1. If the app has a `Procfile`, Cloud Foundry uses it directly.
2. Otherwise, if `pyproject.toml` defines a console script whose name matches `[project].name`, that script is used.
3. Otherwise, if `[project.scripts]` defines `start`, that script is used.
4. Otherwise, if `main.py` exists, the buildpack uses `python3 main.py`.
5. Otherwise, if `app.py` exists, the buildpack uses `python3 app.py`.

For example, this `pyproject.toml`:

```toml
[project]
name = "my-app"

[project.scripts]
my-app = "server.main:run"
start = "server.main:start"
```

becomes:

```sh
python3 -c "from server.main import run; run()"
```

> **Note:** `uv` is only available during staging, not at runtime. All dependencies are already baked into the droplet by `bin/compile`, so `uv run` is unnecessary and would repeat that work on every start. When specifying commands through the `manifest` or the `Procfile`, use a direct Python invocation instead.

## How to use

You can reference the github repository URI or a specific GitHub release.

| Project Example | Description | Deployment Script | Buildpack Reference |
|---|---|---|---|
| [my-app-script](./examples/my-app-script/) | `src/` layout app with a console script entry point defined in `[project.scripts]` | [`pyproject.toml`](./examples/my-app-script/pyproject.toml) | [`manifest.yml`](./examples/my-app-script/manifest.yml) |
| [my-app-manifest](./examples/my-app-manifest/) | App with a custom start command specified directly in the CF manifest | [`manifest.yml`](./examples/my-app-manifest/manifest.yml) | [`manifest.yml`](./examples/my-app-manifest/manifest.yml) |
| [my-app-procfile](./examples/my-app-procfile/) | App using a `Procfile` to define the web process | [`Procfile`](./examples/my-app-procfile/Procfile) | [`manifest.yml`](./examples/my-app-procfile/manifest.yml) |
| [my-app-mta](./examples/my-app-mta/) | MTA deployment for SAP BTP Cloud Foundry | [`pyproject.toml`](./examples/my-app-mta/pyproject.toml) | [`mta.yaml`](./examples/my-app-mta/mta.yaml) |

Check the entire projects inside the [examples](./examples/) directory for more details on how to make use of this buildpack.

## Installing the buildpack

Download the latest packaged zip from the [GitHub Releases](https://github.com/NickChecan/uv-python-buildpack/releases) page, then upload it to your CF environment.

To upload the buildpack:

```sh
cf create-buildpack python-uv-buildpack python-uv_buildpack-cached-vX.Y.Z.zip 1 --enable
```

The position (`1`) controls priority when CF auto-detects buildpacks. Adjust as needed relative to your other buildpacks.

... then reference it in your app's `manifest.yaml` or `mta.yaml`:**

```yaml
buildpacks:
  - python-uv-buildpack
```

To update an existing buildpack after a new release:

```sh
cf update-buildpack python-uv-buildpack -p python-uv_buildpack-cached-vX.Y.Z.zip --enable
```

## Testing locally

Run the buildpack test flow from the repository root:

```sh
make test-buildpack
```

This command:

- stages the sample app into a temporary build directory
- runs `bin/detect`
- runs `bin/compile`
- verifies the staged dependencies are importable
- prints the `bin/release` output

You can run a different smoke fixture by passing its directory:

```sh
make test-buildpack APP_DIR=test/smoke/my-app-2
```

To clean the temporary staging directories:

```sh
make clean-test-buildpack
```

To start the staged sample app locally after a successful test build:

```sh
make start-local
```

Then open `http://127.0.0.1:8000/`.

To run the full unit test suite:

```sh
make unit-test
```

To run all smoke fixtures:

```sh
make smoke-test
```

See the project [Makefile](./Makefile) for the supported local commands.

## Contributing

Contributions are welcome.

1. Report bugs or request features by opening an [issue](https://github.com/NickChecan/uv-python-buildpack/issues).
2. Fork the repository, create a branch, make your changes, and open a pull request.
3. Improve the documentation or examples to make the buildpack easier to adopt.
4. Run the local tests before submitting changes when possible.

## License

Copyright (c) 2026 Nicholas Coutinho Checan.
Licensed under the MIT License. See [LICENSE](./LICENSE).
