# Cloud Foundry UV Python Buildpack

The current cloud foundry [python-buildpack](https://github.com/cloudfoundry/python-buildpack) doesn't support modern python tools, such as [uv](https://docs.astral.sh/uv/), so I created this custom buildpack to bridge the gap.

## Installation

## How to use


### Defining the initialization script

This buildpack detects uv-managed apps when both `pyproject.toml` and `uv.lock` are present.

At staging time, `bin/compile` exports the locked dependencies from `uv.lock`, installs them into `.python_packages`, and writes a `.profile.d/python.sh` file so the app can import those staged packages at runtime. If the app uses a `src/` layout, that `src/` directory is also added to `PYTHONPATH`.

At release time, `bin/release` chooses the web command in this order:

1. If the app has a `Procfile`, the buildpack does not generate a default process type and Cloud Foundry uses the `Procfile`.
2. If `pyproject.toml` exists and `[project.scripts]` contains a script named exactly the same as `[project].name`, that script is used.
3. Otherwise, if `[project.scripts]` contains a `start` script, that script is used.
4. Otherwise, if `main.py` exists, the buildpack uses `python3 main.py`.
5. Otherwise, if `app.py` exists, the buildpack uses `python3 app.py`.
6. If none of the above are present, the buildpack emits an empty `web` process and you must provide your own entrypoint.

For `pyproject.toml` scripts, the buildpack converts a console-script target such as:

```toml
[project]
name = "my-app"

[project.scripts]
my-app = "server.main:run"
start = "server.main:start"
```

into a process command like:

```sh
python3 -c "from server.main import run; run()"
```

In the example above, `my-app` wins over `start` because it matches `[project].name`.

## Testing Locally

Run the buildpack test flow from the repository root:

```sh
make test-buildpack
```

This command:

- stages `test/my-app-*` into a temporary build directory
- runs `bin/detect`
- runs `bin/compile`
- verifies the staged dependencies can be imported
- prints the `bin/release` output

You can also run other smoke test projects by specifying its directory. For example:

```sh
make test-buildpack APP_DIR=test/smoke/my-app-2
```

If you want to remove the temporary staging directories before or after a run:

```sh
make clean-test-buildpack
```

If you want to start the staged sample app locally after `make test-buildpack` succeeds:

```sh
make start-local
```

Then open `http://127.0.0.1:8000/`.

## How to Contribute

Contributions are welcome! Here's how you can get involved:

1. **Report Issues:** Found a bug or have a feature request? [Open an issue](https://github.com/NickChecan/uv-python-buildpack/issues). <br />
2. **Submit Pull Requests:** Fork the repository, create a new branch, make your changes, and submit a PR. <br />
3. **Improve Documentation:** Help improve the README or add examples to make setup easier. <br />
4. **Test & Feedback:** Try Model Mux and provide feedback.

## License

Copyright (c) 2026 Nicholas Coutinho Checan.
Licensed under the MIT License. See [LICENSE](./LICENSE).