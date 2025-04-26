{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python3;
        # Attempt a more Nix-idiomatic NixOS check
        isNixOS = let
          # Check if nixpkgs has a NixOS-specific attribute (safe evaluation)
          hasNixOS = pkgs.lib.attrByPath ["nixos"] null pkgs != null;
        in
          pkgs.stdenv.isLinux && (hasNixOS || builtins.pathExists "/etc/NIXOS");

      in
      {
        devShells = {
          default = pkgs.mkShell {
            packages = [
              python
              pkgs.uv
            ];

            shellHook = ''
              if [ "${toString isNixOS}" = "1" ]; then
                echo "Detected NixOS (non-FHS system)" >&2
                export UV_PYTHON="${python}/bin/python3"
                export UV_PYTHON_PREFERENCE="only-system"
                export LD_LIBRARY_PATH=${pkgs.zlib}/lib:${pkgs.gcc}/lib64:${pkgs.stdenv.cc.cc.lib}/lib64:$LD_LIBRARY_PATH
                if [ -d ~/.local/share/uv/python ]; then
                  echo "Clearing uv's Python cache for NixOS..." >&2
                  rm -rf ~/.local/share/uv/python
                fi
              else
                echo "Detected FHS-compliant system (e.g., Arch)" >&2
                if [ -x "$(command -v python3)" ]; then
                  echo "Using system Python: $(which python3)" >&2
                else
                  echo "No system Python found, using flake-provided Python" >&2
                  export UV_PYTHON="${python}/bin/python3"
                  export UV_PYTHON_PREFERENCE="only-system"
                fi
              fi

              if [ -d ~/.local/share/uv/python ]; then
                echo "Clearing uv's Python cache..."
                rm -rf ~/.local/share/uv/python
              fi

              export PYTHONPATH=$PWD:$PYTHONPATH

              if [ -f uv.lock ]; then
                echo "Syncing dependencies with uv..."
                uv sync --python "${python}/bin/python3" || echo "Sync failed"
              elif [ -f requirements.txt ]; then
                echo "Installing dependencies from requirements.txt..."
                uv pip install -r requirements.txt --python "${python}/bin/python3" || echo "Install failed"
              else
                echo "No uv.lock or requirements.txt found. Add dependencies with 'uv add'."
              fi
            '';
          };
        };

packages = {
  "3ebts" = let
    baseImage = pkgs.dockerTools.pullImage {
      imageName = "python";
      imageDigest = "sha256:7abcb9d3f11d0c9f0aa3ab03f4265a9ab4db39f8acdbdab96e30fcdc18347e8d";
      finalImageTag = "3.12-slim";
      sha256 = "0qwiy2fbwfrp11zfv8b23lrawyb2paffrllhaqq2d3hkx7brhggq";
    };
  in pkgs.dockerTools.buildImage {
    name = "3ebts";
    tag = "latest";
    fromImage = baseImage;
    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      paths = [
        (let
          python = pkgs.python312;
          pythonDeps = pkgs.stdenv.mkDerivation {
            name = "python-deps";
            src = ./src;
            nativeBuildInputs = [ python pkgs.uv ];
            buildInputs = [ pkgs.libjpeg pkgs.libpng pkgs.freetype pkgs.zlib pkgs.xz pkgs.xorg.libXau ];
            buildPhase = ''
              export UV_PYTHON="${python}/bin/python3"
              export UV_PYTHON_PREFERENCE="only-system"
              export UV_CACHE_DIR="$TMPDIR/uv-cache"
              mkdir -p "$UV_CACHE_DIR"
              if [ -f uv.lock ]; then
                uv sync --python "${python}/bin/python3"
              elif [ -f requirements.txt ]; then
                uv pip install -r requirements.txt --python "${python}/bin/python3"
              else
                echo "No uv.lock or requirements.txt found" >&2
                exit 1
              fi
              # Debug .venv contents
              echo "Listing .venv contents:"
              find .venv -type f -ls
              # Verify .venv/bin/python3
              if [ ! -f .venv/bin/python3 ]; then
                echo "Error: .venv/bin/python3 not found" >&2
                exit 1
              fi
              if [ ! -x .venv/bin/python3 ]; then
                echo "Error: .venv/bin/python3 is not executable" >&2
                exit 1
              fi
            '';
            installPhase = ''
              mkdir -p $out/venv
              cp -r --preserve=mode,links .venv/* $out/venv/
              # Debug copied contents
              echo "Listing $out/venv contents:"
              find $out/venv -type f -ls
            '';
          };
        in pkgs.stdenv.mkDerivation {
          name = "src-deps";
          src = ./src;
          nativeBuildInputs = [ python pkgs.uv ];
          buildInputs = [ pkgs.libjpeg pkgs.libpng pkgs.freetype pkgs.zlib pkgs.xz pkgs.xorg.libXau ];
          buildPhase = ''
            echo "Using pre-fetched dependencies"
          '';
          installPhase = ''
            mkdir -p $out/app/src/.venv/lib
            # Copy libraries first
            echo "Copying shared libraries:"
            cp -v ${pkgs.libjpeg.out}/lib/libjpeg.so.62 $out/app/src/.venv/lib/
            cp -v ${pkgs.libpng}/lib/libpng16.so.16 $out/app/src/.venv/lib/
            cp -v ${pkgs.freetype}/lib/libfreetype.so.6 $out/app/src/.venv/lib/
            cp -v ${pkgs.zlib}/lib/libz.so.1 $out/app/src/.venv/lib/
            cp -v ${pkgs.xz.out}/lib/liblzma.so.5 $out/app/src/.venv/lib/
            cp -v ${pkgs.xorg.libXau}/lib/libXau.so.6 $out/app/src/.venv/lib/
            # Create symlinks for Pillow's expected versions
            ln -sf $out/app/src/.venv/lib/liblzma.so.5 $out/app/src/.venv/lib/liblzma-a5872208.so.5.6.3
            ln -sf $out/app/src/.venv/lib/libXau.so.6 $out/app/src/.venv/lib/libXau-154567c4.so.6.0.0
            echo "Listing library directory permissions:"
            ls -ld $out/app/src/.venv/lib
            ls -l $out/app/src/.venv/lib
            # Copy source, .env, and .venv
            cp -r $src/* $out/app/src/
            # Copy .env if it exists
            if [ -f $src/.env ]; then
              cp -v $src/.env $out/app/src/.env
              echo "Contents of copied .env:"
              cat $out/app/src/.env
            else
              echo "Warning: .env file not found in $src" >&2
            fi
            cp -r --preserve=mode,links ${pythonDeps}/venv/* $out/app/src/.venv/
            # Debug .venv contents
            echo "Listing $out/app/src contents:"
            find $out/app/src -type f -ls
            # Verify .venv/bin/python3
            if [ ! -f $out/app/src/.venv/bin/python3 ]; then
              echo "Error: .venv/bin/python3 not copied" >&2
              exit 1
            fi
            if [ ! -x $out/app/src/.venv/bin/python3 ]; then
              echo "Error: .venv/bin/python3 is not executable" >&2
              exit 1
            fi
          '';
        })
      ];
      pathsToLink = ["/"];
    };
    config = {
      Cmd = [ "/app/src/.venv/bin/python3" "/app/src/manage.py" "runserver" "0.0.0.0:8000" ];
      WorkingDir = "/app/";
      Env = [
        "PYTHONUNBUFFERED=1"
        "DJANGO_SETTINGS_MODULE=ebt.settings"
        "PYTHONPATH=/app/src:/app/src/.venv/lib/python3.12/site-packages:$PYTHONPATH"
        "LD_LIBRARY_PATH=/app/src/.venv/lib:$LD_LIBRARY_PATH"
        "DJANGO_HOST=http://localhost"
        "ALLOWED_HOSTS=localhost,127.0.0.1"
      ];
    };
  };
};


}
 );
}


