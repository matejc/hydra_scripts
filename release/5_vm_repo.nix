{ nixpkgs
, hydra_scripts
, system ? builtins.currentSystem
, prefixDir ? "/var/matej"
, minimal ? false
, vm_timeout ? "180"

, package_name
, package_repo
, build_command ? "make all"
, dist_command ? "bin/pocompile ./src; bin/easy_install distribute; bin/python setup.py sdist --formats=bztar"
, check_command ? ""
, dist_path ? "./dist"
, docs_path ? "./docs/html"
, build_inputs ? [ "pkgs.python27" "pkgs.python27Packages.virtualenv" "pkgs.libxml2" "pkgs.libxslt" ]
, CFLAGS_COMPILE_SETS ? []
, LDFLAGS_SETS ? []
, do_lcov ? false
, cov_command ? ""
, source_files ? "*.tar.gz *.tgz *.tar.bz2 *.tbz2 *.tar.xz *.tar.lzma *.zip"
, binary_files ? "*.egg"
, buildinout ? true
, install_command ? ""
, with_vnc_command ? ""
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

  build_inputs_str = toString build_inputs;

  esc = string: pkgs.lib.escapeShellArg string;

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

    nix-build ${<hydra_scripts/release/vm_build_repo.nix>} -A ${esc package_name} --argstr nixpkgs ${<nixpkgs>} --argstr hydra_scripts ${<hydra_scripts>} --argstr prefix ${prefixDir} --argstr build_inputs_str "${build_inputs_str}" --argstr system ${system} --argstr package_name "${esc package_name}" --argstr package_repo "${<package_repo>}" --argstr build_command "${esc build_command}" --argstr dist_command "${esc dist_command}" --argstr check_command "${check_command}" --argstr dist_path "${esc dist_path}" --argstr docs_path "${esc docs_path}" --argstr cov_command "${esc cov_command}" --argstr source_files "${esc source_files}" --argstr binary_files "${esc binary_files}" --argstr install_command "${esc install_command}" --argstr with_vnc_command "${esc with_vnc_command}" -vvv --show-trace

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

    while `test -f /var/images/$HASH.lock`; do sleep 1; echo "Waiting: $HASH.lock"; done
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
