{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system config; };
  pkgs2storeContents = l : map (x: { object = x; symlink = "none"; }) l;
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
  linuxPackages = pkgs.linuxPackages_4_1;
  config = {
    nixpkgs.config = {
      packageOverrides = pkgs: {
        stdenv = pkgs.stdenv // {
          platform = pkgs.stdenv.platform // {
            inherit kernelExtraConfig;
            name = "tablet";
          };
        };
      };
    };
    boot.kernelPackages = pkgs.linuxPackages_4_1;
  };
  linux = linuxPackages.kernel.override { extraConfig = kernelExtraConfig; };
  tarball = import <nixpkgs/nixos/lib/make-system-tarball.nix> {
    inherit (pkgs) stdenv perl xz pathsFromGraph;
    contents = [];
    extraArgs = "--owner=0";
    storeContents = (pkgs2storeContents [ pkgs.config.boot.kernelPackages.kernel ]);
  };
  jobs = {
    inherit tarball;
  };
in jobs
