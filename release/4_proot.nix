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
, extraPRootArgs ? "-q qemu-arm"
}:
let
  pkgs = import <nixpkgs> { inherit system; };

  attrs_str = toString attrs;  # legacy

  passwd = pkgs.writeText "passwd" ''
    root:x:0:0::/root:/bin/sh
  '';
  group = pkgs.writeText "group" ''
    root:x:0:
  '';
  shadow = pkgs.writeText "shadow" ''
    root:x:16117::::::
  '';

  buildScript = pkgs.writeScriptBin "build.sh" ''
    #! /bin/sh -e
    echo "############################### BUILD START ###############################"
    export PATH=${pkgs.busybox}/bin:${pkgs.nix}/bin:$PATH

    # to associate uid with username and
    # gid with groupname for programs like `id`
    mkdir -p /etc
    cp ${passwd} /etc/passwd
    cp ${group} /etc/group
    cp ${shadow} /etc/shadow

    mkdir -p /home/builder
    busybox adduser -h /home/builder -s /bin/sh -D  builder || true

    mkdir -p ${prefixDir}/store
    export NIX_STORE_DIR=${prefixDir}/store
    mkdir -p ${prefixDir}/var/nix
    export NIX_STATE_DIR=${prefixDir}/var/nix
    mkdir -p ${prefixDir}/var/nix/db
    export NIX_DB_DIR=${prefixDir}/var/nix/db

    chown -R builder ${prefixDir}
    #chmod -R 1775 ${prefixDir}

    busybox su builder -c 'nix-build ${<hydra_scripts>}"/"${build_script} -A vmEnvironment --argstr nixpkgs ${<nixpkgs>} --argstr hydra_scripts ${<hydra_scripts>} --argstr prefix ${prefixDir} --argstr attrs_str "${attrs_str}" --argstr system ${system} ${toString passthru} -vv --show-trace'

    EXITSTATUSCODE=$?

    echo $EXITSTATUSCODE > /tmp/xchg/exitstatuscode

    if [[ "0" -eq "$EXITSTATUSCODE" ]]; then
      test -L ./result && cp -Pv ./result ${prefixDir}
      STORE_PATHS=`nix-store -qR ./result ${pkgs.lib.optionalString (tarGrep != "") "| grep ${tarGrep}"}`
      RESULT_PATHS="`find ${prefixDir}/result/* -type l | xargs realpath`\n${prefixDir}/result"

      echo -e "$STORE_PATHS\n$RESULT_PATHS" | sort | uniq > ./merged_paths

      echo -e "$STORE_PATHS\n$RESULT_PATHS" | wc -l
      cat ./merged_paths | wc -l

      ${pkgs.gnutar}/bin/tar cvf /xchg/out.tar --files-from ./merged_paths --mode=u+rw
      ${pkgs.bzip2}/bin/bzip2 /xchg/out.tar
    else
      echo "BUILD FAILED!"
    fi
    echo "############################### BUILD END ###############################"
  '';

  runCommand = pkgs.writeText "runCommand" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.qemu}/bin:${pkgs.gawk}/bin:$PATH

    export HASH=`echo "${prefixDir}" | sha1sum - | awk '{print $1}'`

    while `test -f /var/proots/$HASH.lock`; do sleep 10; echo "Waiting: $HASH.lock"; done
    touch /var/proots/$HASH.lock
    postCommands() {
      rm /var/proots/$HASH.lock
    }
    trap "postCommands" EXIT

    export PROOT_DIR=/var/proots/$HASH
    mkdir -p $PROOT_DIR && chmod -R g+w $PROOT_DIR

    timeout ${timeout} ${pkgs.proot}/bin/proot -S "$PROOT_DIR" \
      -b /bin/sh -b ${pkgs.busybox} -b ${pkgs.nix} -b ${pkgs.gnutar} \
      -b ${pkgs.bzip2} -b ${<hydra_scripts>} -b ${<nixpkgs>} -b ${buildScript} \
      -b ${passwd} -b ${group} -b ${shadow} -b ${pkgs.perl} -b ${pkgs.stdenv} \
      ${extraPRootArgs} ${buildScript}/bin/build.sh

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

  runner = pkgs.stdenv.mkDerivation {
    name = "proot-runner";
    builder = "${pkgs.bash}/bin/sh";
    args = ["-e" runCommand];
  };

  jobs = {
    build = runner;
  };
in jobs
