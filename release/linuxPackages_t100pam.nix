{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system config; };
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
  linuxPackages = pkgs.linuxPackages_4_1;
  stdenv = pkgs.stdenv // {
    platform = pkgs.stdenv.platform // {
      inherit kernelExtraConfig;
      name = "tablet";
    };
  };
  linux = linuxPackages.kernel.override { extraConfig = kernelExtraConfig; };
  tarball = import <nixpkgs/nixos/lib/make-system-tarball.nix> {
    inherit (pkgs) perl xz pathsFromGraph;
    inherit stdenv;
    contents = [];
    extraArgs = "--owner=0";
    storeContents = (pkgs2storeContents [ linux ]);
  };
  jobs = {
    inherit tarball;
  };
in jobs
