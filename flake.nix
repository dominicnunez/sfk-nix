{
  description = "Nix flake for Springfield Kit (SFK) - autonomous AI development kit";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      overlay = final: prev: {
        sfk = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.sfk;
          sfk = pkgs.sfk;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.sfk}/bin/sfk";
            meta.description = "Springfield Kit - autonomous AI development kit";
          };
          sfk = {
            type = "app";
            program = "${pkgs.sfk}/bin/sfk";
            meta.description = "Springfield Kit - autonomous AI development kit";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch
            gh
            jq
          ];
        };

        formatter = pkgs.nixpkgs-fmt;

        checks = {
          build = pkgs.sfk;

          version = pkgs.runCommand "sfk-version-check" { } ''
            ${pkgs.sfk}/bin/sfk --version
            touch $out
          '';
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
