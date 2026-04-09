# Cloud Foundry UV Python Buildpack

The current cloud foundry [python-buildpack](https://github.com/cloudfoundry/python-buildpack) doesn't support modern python tools, such as [uv](https://docs.astral.sh/uv/), so I created this custom buildpack to bridge the gap.

## Installation

## Testing Locally

Run the buildpack test flow from the repository root:

```sh
make test-buildpack
```

This command:

- stages `test/my-app` into a temporary build directory
- runs `bin/detect`
- runs `bin/compile`
- verifies the staged dependencies can be imported
- prints the `bin/release` output

If you want to remove the temporary staging directories before or after a run:

```sh
make clean-test-buildpack
```

If you want to start the staged sample app locally after `make test-buildpack` succeeds:

```sh
make start-local
```

Then open `http://127.0.0.1:8000/`.
