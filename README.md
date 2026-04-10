# Cloud Foundry UV Python Buildpack

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

## Installing the buildpack

### Option 1: Use a packaged buildpack zip directly

Package the buildpack from the repository root:

```sh
make build
```

Then deploy an app with the generated zip:

```sh
cf push my-app -p path/to/app -b /full/path/to/python-uv_buildpack-cached-vX.Y.Z.zip
```

If you use a manifest, you can also pass the buildpack zip on the command line:

```sh
cf push -f manifest.yml -b /full/path/to/python-uv_buildpack-cached-vX.Y.Z.zip
```

### Option 2: Upload the buildpack to Cloud Foundry once

Create a reusable named buildpack in your foundation:

```sh
cf create-buildpack python-uv-buildpack python-uv_buildpack-cached-v1.0.10.zip 1 --enable
```

Then deploy apps with:

```sh
cf push my-app -b python-uv-buildpack
```

Or in `manifest.yml`:

```yaml
---
applications:
  - name: my-app
    path: .
    buildpacks:
      - python-uv-buildpack
```

### Option 3: Use a published GitHub Release artifact

If you publish packaged buildpack zips in GitHub Releases, you can deploy with a release URL:

```sh
cf push my-app -b https://github.com/NickChecan/uv-python-buildpack/releases/download/vX.Y.Z/python-uv_buildpack-cached-vX.Y.Z.zip
```

## Example app manifests

If you pass the buildpack with `cf push -b ...`, you do not need a `buildpacks:` entry in the app manifest.

Example:

```yaml
---
applications:
  - name: my-app
    path: .
    memory: 256M
    disk_quota: 512M
    instances: 1
```

Then:

```sh
cf push -f manifest.yml -b ../../python-uv_buildpack-cached-vX.Y.Z.zip
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
