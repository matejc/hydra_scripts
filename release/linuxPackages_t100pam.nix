{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system config; };
  pkgs2storeContents = l : map (x: { object = x; symlink = "none"; }) l;
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
  linuxPackages = pkgs.linuxPackages_4_1;
  config = {
    nixpkgs.config = {
      packageOverrides = pkgs: {
        linux_4_1 = pkgs.linux_4_1.override { extraConfig = kernelExtraConfig; };
        stdenv = pkgs.stdenv // {
          platform = pkgs.stdenv.platform // {
            name = "tablet";
          };
        };
      };
    };
    boot.kernelPackages = pkgs.linuxPackages_4_1;
  };
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
