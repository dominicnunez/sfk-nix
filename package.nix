{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  versionInfo = lib.importJSON ./version.json;
  version = versionInfo.version;
  hashes = versionInfo.hashes;

  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "darwin-x64";
    "aarch64-darwin" = "darwin-arm64";
  };

  isDarwin = stdenv.hostPlatform.isDarwin;

  system = stdenv.hostPlatform.system;
  platform = platformMap.${system} or (throw "Unsupported system: ${system}");
  hash = hashes.${system} or (throw "No hash for system: ${system}");

  src = fetchurl {
    url = "https://github.com/dominicnunez/springfield/releases/download/v${version}/sfk-${platform}";
    inherit hash;
  };

  wrapperScript = ''
    #!/usr/bin/env bash

    verbose=''${SFK_NIX_VERBOSE:-0}

    is_home_manager_active() {
      [[ -n "''${HM_SESSION_VARS:-}" ]] ||
      [[ -d "$HOME/.config/home-manager" ]] ||
      [[ -d "/etc/profiles/per-user/$USER" ]]
    }

    manage_symlink() {
      local target_dir="$HOME/.local/bin"
      local symlink_path="$target_dir/sfk"
      local binary_path="@out@/bin/.sfk-unwrapped"

      if is_home_manager_active; then
        if [[ -L "$symlink_path" ]]; then
          local link_target
          link_target="$(readlink "$symlink_path" 2>/dev/null || echo "")"
          if [[ "$link_target" == "$binary_path" ]] || \
             [[ "$link_target" == /nix/store/*-sfk-* ]]; then
            rm -f "$symlink_path"
            [[ "$verbose" == "1" ]] && echo "[sfk-nix] Removed symlink (Home Manager now manages sfk)" >&2
          fi
        fi
        return 0
      fi

      local current_target
      current_target="$(readlink -f "$symlink_path" 2>/dev/null || echo "")"

      if [[ "$current_target" == "$binary_path" ]]; then
        return 0
      fi

      mkdir -p "$target_dir"
      ln -sf "$binary_path" "$symlink_path"
      [[ "$verbose" == "1" ]] && echo "[sfk-nix] Created symlink: $symlink_path -> $binary_path" >&2
    }

    manage_symlink

    exec "@out@/bin/.sfk-unwrapped" "$@"
  '';
in
stdenv.mkDerivation {
  pname = "sfk";
  inherit version src;

  dontUnpack = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
    ];

  buildInputs = [ ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    ${
      if isDarwin then
        ''
                cp $src $out/bin/.sfk-unwrapped
                chmod +x $out/bin/.sfk-unwrapped

                cat > $out/bin/sfk << 'WRAPPER_EOF'
          ${wrapperScript}
          WRAPPER_EOF
                chmod +x $out/bin/sfk

                substituteInPlace $out/bin/sfk --replace-quiet "@out@" "$out"
        ''
      else
        ''
          cp $src $out/bin/sfk
          chmod +x $out/bin/sfk
        ''
    }

    runHook postInstall
  '';

  meta = with lib; {
    description = "Springfield Kit (SFK) - autonomous AI development kit";
    homepage = "https://github.com/dominicnunez/springfield";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "sfk";
  };
}
