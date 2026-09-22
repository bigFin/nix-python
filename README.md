# Nix + Python

A minimal Python environment managed by [devenv](https://devenv.sh/) and [uv](https://docs.astral.sh/uv/).

```console
nix develop --no-pure-eval
uv sync
uv run python hello.py
```

`flake.nix` enables Python and uv:

```nix
languages.python.enable = true;
languages.python.uv.enable = true;
```

Add devenv features in the same module. Add Python dependencies with `uv add <package>`.

## Containers

This repo is a dev shell only. For images, use [devenv containers](https://devenv.sh/containers/):

```console
devenv container build shell --system x86_64-linux
devenv container build shell --system aarch64-linux
devenv container run shell
```

Build each target on that platform or with a remote builder, then publish a multi-platform manifest.
