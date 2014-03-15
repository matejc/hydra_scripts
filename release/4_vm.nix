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
    virtualisation.diskSize = 20000;
  };

  machine =
    { config, pkgs, ... }: configVM;

  attrs_str = toString attrs;  # legacy

  vmBuildCommands = ''
    echo "############################### BUILD START ###############################"
    export PATH=${nix}/bin:$PATH

    mkdir -p ${prefixDir}/store
    chgrp -R 30000 ${prefixDir}
    chmod -R 1775 ${prefixDir}
    export NIX_STORE_DIR=${prefixDir}/store
    mkdir -p ${prefixDir}/var/nix
    export NIX_STATE_DIR=${prefixDir}/var/nix
    mkdir -p ${prefixDir}/var/nix/db
    export NIX_DB_DIR=${prefixDir}/var/nix/db

    nix-build ${<hydra_scripts/release/vm_build.nix>} -A vmEnvironment --argstr nixpkgs ${<nixpkgs>} --argstr prefix ${prefixDir} --argstr attrs_str "${attrs_str}" --argstr system ${system} -vvv --show-trace

    EXITSTATUSCODE=$?

    echo $EXITSTATUSCODE > /tmp/xchg/exitstatuscode

    if [[ "0" -eq "$EXITSTATUSCODE" ]]; then
      test -L ./result && cp -Pv ./result ${prefixDir}
      ${gnutar}/bin/tar cvf /tmp/xchg/out.tar "${prefixDir}/result" `nix-store -qR ./result`
      ${xz}/bin/xz /tmp/xchg/out.tar
    else
      echo "BUILD FAILED!"
    fi
    echo "############################### BUILD END ###############################"
  '';

  vm = buildVM { } [
    machine {
      key = "run-in-machine";
      networking.enableIPv6 = false;
      nix.readOnlyStore = true;
      systemd.services.backdoor.enable = false;

      systemd.services.build = {
        description = "Build";
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
    export PATH=${coreutils}/bin:${gawk}/bin:$PATH

    mkdir -p vm-state-client/xchg
    export > vm-state-client/xchg/saved-env
    
    HASH=`echo "${prefixDir}" | sha1sum - | awk '{print $1}'`

    while `test -f /var/images/$HASH.lock`; do sleep 10; echo "Waiting: $HASH.lock"; done
    touch /var/images/$HASH.lock
    export NIX_DISK_IMAGE=/var/images/$HASH.img
    timeout ${vm_timeout} ${vm.config.system.build.vm}/bin/run-*-vm
    rm /var/images/$HASH.lock

    { chmod g+w $NIX_DISK_IMAGE; } || echo "WARNING: Could not set write permission to $NIX_DISK_IMAGE"

    EXITSTATUSCODE=`cat ./nix-vm.*/xchg/exitstatuscode`
    test 0 -ne $EXITSTATUSCODE && exit $EXITSTATUSCODE

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

  jobs = {
    build = vmRunner;
  };
in jobs
