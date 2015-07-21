{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system; };
  hydraJob = pkgs.lib.hydraJob;
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";

  makeIso =
    { module, type, description ? type, maintainers ? ["matejc"], system }:
    with import nixpkgs { inherit system; };
    let
      config = (import <nixpkgs/lib/eval-config.nix> {
        inherit system;
        modules = [ module versionModule { isoImage.isoBaseName = "nixos-${type}"; } ];
      }).config;
      iso = config.system.build.isoImage;
    in
      # Declare the ISO as a build product so that it shows up in Hydra.
      hydraJob (runCommand "nixos-iso-${config.system.nixosVersion}"
        { meta = {
            description = "NixOS installation CD (${description}) - ISO image for ${system}";
            maintainers = map (x: lib.maintainers.${x}) maintainers;
          };
          inherit iso;
          passthru = { inherit config; };
        }
        ''
          mkdir -p $out/nix-support
          echo "file iso" $iso/iso/*.iso* >> $out/nix-support/hydra-build-products
        ''); # */
  
  iso_minimal = makeIso {
    module =
      { config, lib, pkgs, ... }:
      {
        imports = [
          <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix>
          <nixpkgs/nixos/modules/profiles/minimal.nix>
        ];
        boot.kernelPackages = pkgs.linuxPackages_4_1;
        nixpkgs.config = {
          packageOverrides = pkgs: {
            stdenv = pkgs.stdenv // {
              platform = pkgs.stdenv.platform // {
                kernelExtraConfig = kernelExtraConfig;
                name = "tablet";
              };
            };
          };
        };
      };
    type = "minimal";
    inherit system;
  };

  jobs = {
    inherit iso_minimal;
  };
in jobs
