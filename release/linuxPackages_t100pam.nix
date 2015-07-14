{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system config; };
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
    boot.kernelPackages = linuxPackages;
  };
  jobs = {
    #kernelPackages = config.boot.kernelPackages;
    linux = linuxPackages.kernel.override { extraConfig = kernelExtraConfig; };
  };
in jobs
