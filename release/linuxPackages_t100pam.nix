{ nixpkgs, system, hydra_scripts }:
let
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
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
  pkgs = import <nixpkgs> { inherit system config; };
  jobs = {
    kernelPackages = config.boot.kernelPackages;
  };
in jobs
