# Nix-Python

Because Nix is all you need.

## Overview

`Nix-Python` is a setup that allows you to manage Python environments and dependencies using Nix. It ensures that you have a consistent development environment with a specific Python version.

## Usage

### Development Shell

Run the following command to launch a shell with a pinned Python version (currently set to 3.1, modify if needed):

```bash
nix develop
```

- If a virtual environment does not exist, it will be created.
- Dependencies specified in `requirements.txt` or `pyproject.toml` will be installed using the local UV cache if it exists.

### Build Docker Image

Run the following command to create a Docker image:

```bash
nix build
```

