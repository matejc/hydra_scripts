{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system; };
  pkgs2storeContents = l : map (x: { object = x; symlink = "none"; }) l;
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
  stdenv = pkgs.stdenv // {
    platform = pkgs.stdenv.platform // {
      name = "tablet";
    };
  };
  linux = pkgs.linux_4_1.override { extraConfig = kernelExtraConfig; inherit stdenv; };
  tarball = import <nixpkgs/nixos/lib/make-system-tarball.nix> {
    inherit (pkgs) stdenv perl xz pathsFromGraph;
    contents = [];
    extraArgs = "--owner=0";
    storeContents = (pkgs2storeContents [ linux ]);
  };
  jobs = {
    inherit tarball;
  };
in jobs
