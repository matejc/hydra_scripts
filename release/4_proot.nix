{ nixpkgs
, hydra_scripts
, build_script ? "release/vm_build.nix"
, system ? builtins.currentSystem
, attrs ? [ "pkgs.nix" "pkgs.bash" ]
, prefixDir ? "/var/matej"
, minimal ? false
, timeout ? "36000"
, passthru ? ""
, tarGrep ? ""
}:

with pkgs;

let
  pkgs = import <nixpkgs> { inherit system; };

  attrs_str = toString attrs;  # legacy

  buildScript = pkgs.writeScriptBin "build.sh" ''
    #! ${pkgs.stdenv.shell} -e
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

    nix-build ${<hydra_scripts>}"/"${build_script} -A vmEnvironment --argstr nixpkgs ${<nixpkgs>} --argstr hydra_scripts ${<hydra_scripts>} --argstr prefix ${prefixDir} --argstr attrs_str "${attrs_str}" --argstr system ${system} ${toString passthru} -vv --show-trace

    EXITSTATUSCODE=$?

    echo $EXITSTATUSCODE > /tmp/xchg/exitstatuscode

    if [[ "0" -eq "$EXITSTATUSCODE" ]]; then
      test -L ./result && cp -Pv ./result ${prefixDir}
      STORE_PATHS=`nix-store -qR ./result ${pkgs.lib.optionalString (tarGrep != "") "| grep ${tarGrep}"}`
      RESULT_PATHS="`find ${prefixDir}/result/* -type l | xargs realpath`\n${prefixDir}/result"

      echo -e "$STORE_PATHS\n$RESULT_PATHS" | sort | uniq > ./merged_paths

      echo -e "$STORE_PATHS\n$RESULT_PATHS" | wc -l
      cat ./merged_paths | wc -l

      ${gnutar}/bin/tar cvf /xchg/out.tar --files-from ./merged_paths --mode=u+rw
      ${bzip2}/bin/bzip2 /xchg/out.tar
    else
      echo "BUILD FAILED!"
    fi
    echo "############################### BUILD END ###############################"
  '';

  runCommand = writeText "runCommand" ''
    export PATH=${coreutils}/bin:${gawk}/bin:$PATH

    HASH=`echo "${prefixDir}" | sha1sum - | awk '{print $1}'`

    while `test -f /var/proots/$HASH.lock`; do sleep 10; echo "Waiting: $HASH.lock"; done
    mkdir -p /var/proots
    touch /var/proots/$HASH.lock
    export PROOT_DIR=/var/proots/$HASH
    mkdir $PROOT_DIR/xchg

    cp ${buildScript}/bin/* ${buildScript}/bin/

    timeout ${timeout} ${proot}/bin/proot -S "$PROOT_DIR" -b /nix/store /bin/build.sh

    rm /var/proots/$HASH.lock

    test -w $PROOT_DIR || echo "WARNING: `id` has no write permission for $PROOT_DIR"
    chmod g+w $PROOT_DIR || true

    EXITSTATUSCODE=`cat $PROOT_DIR/xchg/exitstatuscode`
    test 0 -ne $EXITSTATUSCODE && exit $EXITSTATUSCODE

    mkdir -p $out/tarballs
    cp $PROOT_DIR/xchg/out.tar.bz2 $out/tarballs

    mkdir -p $out/nix-support
    for i in $out/tarballs/*; do
        echo "file binary-dist $i" >> $out/nix-support/hydra-build-products
    done
  '';

  runner = stdenv.mkDerivation {
    name = "proot-runner";
    builder = "${bash}/bin/sh";
    args = ["-e" runCommand];
  };

  jobs = {
    build = runner;
  };
in jobs
