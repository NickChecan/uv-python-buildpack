# Cloud Foundry UV Python Buildpack

The current cloud foundry [python-buildpack](https://github.com/cloudfoundry/python-buildpack) doesn't support modern python tools, such as [uv](https://docs.astral.sh/uv/), so I created this custom buildpack to bridge the gap.

## Installation

## How to use

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