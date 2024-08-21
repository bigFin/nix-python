{ pkgs ? import <nixpkgs> {} }:
# I pin to 310 because thats what my k8s dask pods have
let
  python = pkgs.python310;
in
pkgs.mkShell {
  buildInputs = [
    python
    python.pkgs.virtualenv
    pkgs.zlib  # Ensure zlib is available
    pkgs.glibc  # Ensure glibc is available for standard libraries
    pkgs.gcc  # Ensure gcc is available for libstdc++.so.6
  ];
  shellHook = ''
    export VENV_DIR=".venv"
    export LD_LIBRARY_PATH=${pkgs.zlib.out}/lib:${pkgs.gcc.out}/lib64:${pkgs.stdenv.cc.cc.lib}/lib64:$LD_LIBRARY_PATH
    if [ ! -d "$VENV_DIR" ]; then
      python -m venv $VENV_DIR
      source $VENV_DIR/bin/activate
      pip install --upgrade pip
      pip install uv
    else
      source $VENV_DIR/bin/activate
    fi

    # Use uv to install packages from requirements.txt
    uv pip install -r requirements.txt

    # Debugging: Print Python version and executable path
    echo "Python version: $(python --version)"
    echo "Python executable: $(which python)"
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
  '';
}


