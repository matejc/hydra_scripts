{ nixpkgs, system, hydra_scripts }:
let
  pkgs = import <nixpkgs> { inherit system; };
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
  hydraJob = pkgs.lib.hydraJob;
  stableBranch = false;
  makeTest = (import <nixpkgs/nixos/lib/testing.nix> { inherit system; }).makeTest;

  version = builtins.readFile <nixpkgs/.version>;
  versionSuffix =
    (if stableBranch then "." else "pre") + "${toString nixpkgs.revCount}.${nixpkgs.shortRev}";
  versionModule =
    { system.nixosVersionSuffix = versionSuffix;
      system.nixosRevision = nixpkgs.rev or nixpkgs.shortRev;
    };

  makeIso =
    { module, type, description ? type, maintainers ? ["matejc"], system }:
    with import nixpkgs { inherit system; };
    let
      config = (import <nixpkgs/nixos/lib/eval-config.nix> {
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
  
  
  makeBootTest = name: machineConfig:
    makeTest {
      iso = iso_minimal.config.system.build.isoImage;
      name = "boot-" + name;
      nodes = { };
      testScript =
        ''
          my $machine = createMachine({ ${machineConfig}, qemuFlags => '-m 768' });
          $machine->start;
          $machine->waitForUnit("multi-user.target");
          $machine->shutdown;
        '';
    };
  makeBootTestJob = hydraJob makeBootTest;
  tests = {
    bootBiosCdrom = makeBootTestJob "bios-cdrom" ''
        cdrom => glob("${iso}/iso/*.iso")
      '';
    bootBiosUsb = makeBootTestJob "bios-usb" ''
        usb => glob("${iso}/iso/*.iso")
      '';
    bootUefiCdrom = makeBootTestJob "uefi-cdrom" ''
        cdrom => glob("${iso}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
    bootUefiUsb = makeBootTestJob "uefi-usb" ''
        usb => glob("${iso}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
  };

  jobs = {
    inherit iso_minimal tests;
  };
in jobs
