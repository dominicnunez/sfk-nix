# sfk-nix

Nix flake for [Springfield Kit](https://github.com/dominicnunez/springfield) - autonomous AI development kit.

**Features:**
- Direct binary packaging from GitHub releases
- Smart Home Manager detection with automatic symlink management
- Pre-built binaries via Garnix for instant installation
- Daily automated updates for new SFK versions
- Linux and macOS support (x86_64 and aarch64)

## Quick Start

**Try without installing:**
```bash
nix run github:dominicnunez/sfk-nix
```

**Install to your profile:**
```bash
nix profile add github:dominicnunez/sfk-nix
```

## Flake Usage

### As a Flake Input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sfk-nix.url = "github:dominicnunez/sfk-nix";
  };

  outputs = { self, nixpkgs, sfk-nix, ... }: {
    # Your configuration here
  };
}
```

### NixOS Configuration

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.sfk-nix.packages.${pkgs.system}.default
  ];
}
```

### Home Manager Configuration

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.sfk-nix.packages.${pkgs.system}.default
  ];
}
```

### Using the Overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sfk-nix.url = "github:dominicnunez/sfk-nix";
  };

  outputs = { self, nixpkgs, sfk-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ sfk-nix.overlays.default ];
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pkgs.sfk ];
      };
    };
}
```

## Home Manager Integration

This package includes smart Home Manager detection. When Home Manager is detected, the package skips creating symlinks to respect your declarative configuration.

**Detection methods:**
- `HM_SESSION_VARS` environment variable is set
- `~/.config/home-manager` directory exists
- `/etc/profiles/per-user/$USER` directory exists

**Behavior:**
- **Home Manager detected:** Skips symlink creation and cleans up any orphaned symlinks
- **Home Manager absent:** Creates `~/.local/bin/sfk` symlink for convenience

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SFK_NIX_VERBOSE` | Set to `1` to enable Home Manager detection and symlink management messages |

## Updating

**If using `nix profile add`:**
```bash
nix profile upgrade '.*sfk.*'
```

**If using as a flake input:**
```bash
nix flake update sfk-nix
nixos-rebuild switch  # or home-manager switch
```

## Contributing

### Development Setup

```bash
git clone https://github.com/dominicnunez/sfk-nix
cd sfk-nix
nix develop
nix build
./result/bin/sfk --version
```

### Update Workflow

```bash
nix develop
./update.sh
./update.sh --update
```

### Repository Structure

```
.
├── flake.nix           # Flake definition with outputs
├── flake.lock          # Locked dependencies
├── package.nix         # SFK package derivation
├── version.json        # Current version and hashes
├── update.sh           # Update detection and hash fetching script
├── README.md           # This file
└── .github/workflows/
    ├── update.yml      # Daily update check workflow
    └── ci.yml          # PR build validation workflow
```

## License

This packaging is MIT-licensed.

Springfield Kit is developed by [dominicnunez](https://github.com/dominicnunez).
