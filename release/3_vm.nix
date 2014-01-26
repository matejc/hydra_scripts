{ nixpkgs
, hydra_scripts
, system ? builtins.currentSystem
, attrs ? [ "pkgs.nix" "pkgs.bash" ]
, prefixDir ? "/var/matej"
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
    echo "############################### BUILD START ###############################"
    export PATH=${nix}/bin:$PATH

    mkdir -p ${prefixDir}/store
    chgrp -R 30000 ${prefixDir}
    chmod -R 1775 ${prefixDir}
    export NIX_STORE_DIR=${prefixDir}/store
    mkdir ${prefixDir}/share
    export NIX_DATA_DIR=${prefixDir}/share
    mkdir -p ${prefixDir}/log/nix
    export NIX_LOG_DIR=${prefixDir}/log/nix
    mkdir -p ${prefixDir}/var/nix
    export NIX_STATE_DIR=${prefixDir}/var/nix
    mkdir ${prefixDir}/var/nix/db
    export NIX_DB_DIR=${prefixDir}/var/nix/db
    mkdir -p ${prefixDir}/etc/nix
    export NIX_CONF_DIR=${prefixDir}/etc/nix

    nix-build ${vmBuildNixFile} -A vmEnvironment --argstr nixpkgs ${vmNixpkgs.outPath} --argstr prefix ${prefixDir} --argstr attrs_str "${attrs_str}" --argstr system ${system} --show-trace

    test -L ./result && cp -Pv ./result ${prefixDir}

    ${gnutar}/bin/tar cfv /tmp/xchg/out.tar ${prefixDir}
    ${xz}/bin/xz /tmp/xchg/out.tar
    echo "############################### BUILD END ###############################"
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
