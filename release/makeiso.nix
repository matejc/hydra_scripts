{ nixpkgs, system, hydra_scripts }:
with import <nixpkgs/lib>;
let
  pkgs = import <nixpkgs> { inherit system; };
  kernelExtraConfig = builtins.readFile "${hydra_scripts}/config/t100pam_extra.config";
  stableBranch = false;
  makeTest = (import <nixpkgs/nixos/lib/testing.nix> { inherit system; }).makeTest;

  version = builtins.readFile <nixpkgs/.version>;
  versionSuffix =
    (if stableBranch then "." else "pre") + "${toString nixpkgs.revCount}.${nixpkgs.shortRev}";
  versionModule =
    { system.nixosVersionSuffix = versionSuffix;
      system.nixosRevision = nixpkgs.rev or nixpkgs.shortRev;
    };

  evalConfig = 
    { module, type, versionModule, system }:
    (import <nixpkgs/nixos/lib/eval-config.nix> {
      inherit system;
      modules = [ module versionModule { isoImage.isoBaseName = "nixos-${type}"; } ];
    });

  makeIso =
    { module, type, description ? type, maintainers ? ["matejc"], system }:
    with import nixpkgs { inherit system; };
    let
      config = (evalConfig {inherit module type versionModule system;}).config;
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

  linux_testing = pkgs.linux_testing.override {
    extraConfig = kernelExtraConfig;
    stdenv = pkgs.stdenv // {
      platform = pkgs.stdenv.platform // {
        name = "tablet";
      };
    };
  };
  linuxPackages_testing = pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_testing linuxPackages_testing);
  
  configuration =
    { config, lib, pkgs, ... }:
    {
      imports = [
        <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix>
        <nixpkgs/nixos/modules/profiles/minimal.nix>
      ];
      # boot.loader.gummiboot.enable = true;
      # boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = linuxPackages_testing;
      boot.zfs.useGit = true;
      # nixpkgs.config = {
      #   packageOverrides = pkgs: {
      #     stdenv = pkgs.stdenv // {
      #       platform = pkgs.stdenv.platform // {
      #         #kernelExtraConfig = kernelExtraConfig;
      #         name = "tablet";
      #       };
      #     };
      #   };
      # };
    };
  
  iso = makeIso {
    module = configuration;
    type = "minimal";
    inherit system;
  };

  makeBootTest = name: machineConfig:
    makeTest {
      inherit iso;
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
    
  isoImage = (evalConfig { module = configuration; type = "minimal"; inherit versionModule system; }).config.system.build.isoImage;

  makeBootTestJob = name: machineConfig: hydraJob (makeBootTest name machineConfig);
  tests = {
    bootBiosCdrom = makeBootTestJob "bios-cdrom" ''
        cdrom => glob("${isoImage}/iso/*.iso")
      '';
    bootBiosUsb = makeBootTestJob "bios-usb" ''
        usb => glob("${isoImage}/iso/*.iso")
      '';
    bootUefiCdrom = makeBootTestJob "uefi-cdrom" ''
        cdrom => glob("${isoImage}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
    bootUefiUsb = makeBootTestJob "uefi-usb" ''
        usb => glob("${isoImage}/iso/*.iso"),
        bios => '${pkgs.OVMF}/FV/OVMF.fd'
      '';
  };

  jobs = {
    inherit iso;
  };
in jobs
