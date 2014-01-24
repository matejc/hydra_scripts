{ nixpkgs
, hydra_scripts
, supportedSystems ? [ "x86_64-linux" ]
, system ? builtins.currentSystem
, attrs ? [ "pkgs.pythonPackages.virtualenv" "pkgs.bash" ]
, storeDir ? "/var/matej"
, minimal ? false
, vm_timeout ? "180"
}:

with import <nixpkgs/nixos/lib/build-vms.nix> { inherit system minimal; };
with pkgs;

let
  pkgs = import <nixpkgs> { inherit system; };
  configVM = {
    virtualisation.memorySize = 1024;
    virtualisation.graphics = false;
    virtualisation.diskSize = 5000;
  };

  machine =
    { config, pkgs, ... }: configVM;

  vmBuildNixText = builtins.readFile <hydra_scripts/release/vm_build.nix>;
  vmBuildNixFile = writeText "vm-build.nix" vmBuildNixText;

  attrs_str = toString attrs;  # legacy

  vmBuildCommands = ''
    echo "############################### DO SOMETHING, WILL YOU? ###############################"
    export PATH=${nix}/bin:$PATH

    mkdir -p ${storeDir}
    chgrp 30000 ${storeDir}
    chmod 1775 ${storeDir}
    export NIX_STORE_DIR=${storeDir}

    nix-build ${vmBuildNixFile} -A vmEnvironment --argstr nixpkgs ${vmNixpkgs.outPath} --argstr prefix ${storeDir} --argstr attrs_str ${attrs_str} --show-trace

    ${gnutar}/bin/tar cfv /tmp/xchg/out.tar ${storeDir}
    ${xz}/bin/xz /tmp/xchg/out.tar
    echo "############################### YOU DID SOMETHING, DID YOU? ###############################"
  '';

  vm = buildVM { } [
    machine {
      key = "run-in-machine";
      networking.enableIPv6 = false;
      nix.readOnlyStore = true;
      systemd.services.backdoor.enable = false;

      systemd.services.build-commands = {
        description = "Build Commands";
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        script = ''
          {
            ${vmBuildCommands}
          } || {
            echo "BUILD SCRIPT EXITED WITH ERROR"
          }
          sleep 5; poweroff
        '';
        serviceConfig = {
          Type = "oneshot";
        };
      };
    }
  ];

  vmRunCommand = writeText "vm-run" ''
    export PATH=${coreutils}/bin:$PATH

    mkdir -p vm-state-client/xchg
    export > vm-state-client/xchg/saved-env

    timeout ${vm_timeout} ${vm.config.system.build.vm}/bin/run-*-vm

    mkdir -p $out/tarballs
    cp ./nix-vm.*/xchg/out.tar.xz $out/tarballs

    mkdir -p $out/nix-support
    for i in $out/tarballs/*; do
        echo "file binary-dist $i" >> $out/nix-support/hydra-build-products
    done
  '';

  vmRunner = stdenv.mkDerivation {
    name = "vm-runner";
    requiredSystemFeatures = [ "kvm" ];
    builder = "${bash}/bin/sh";
    args = ["-e" vmRunCommand];
  };

  vmNixpkgs = stdenv.mkDerivation {
    name = "vm-nixpkgs";
    src = fetchgit { url = https://github.com/matejc/nixpkgs; rev = "refs/heads/master"; };
    phases = [ "unpackPhase" "installPhase" ];
    installPhase = ''
      mkdir -p $out
      cp -rv $curSrc/* $out
    '';
  };

  jobs = {
    build = vmRunner;
  };
in jobs
