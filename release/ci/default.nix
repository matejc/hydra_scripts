{ nixpkgs, system ? builtins.currentSystem, timeout ? "36000", extraPRootArgs ? "", pr ? "6118" }:
let
  pkgs = import <nixpkgs> { inherit system; };

  passwd = pkgs.writeText "passwd" ''
    root:x:0:0::/root:/bin/sh
  '';
  group = pkgs.writeText "group" ''
    root:x:0:
  '';
  shadow = pkgs.writeText "shadow" ''
    root:x:16117::::::
  '';
  resolv_conf = pkgs.writeText "resolv.conf" ''
    nameserver 8.8.8.8
    nameserver 8.8.4.4
    nameserver 4.4.4.4
  '';

  buildScript = pkgs.writeScriptBin "build.sh" ''
    #!/bin/sh
    echo "############################### BUILD START ###############################"
    export PATH=${pkgs.busybox}/bin:${pkgs.nix}/bin:$PATH

    # to associate uid with username and
    # gid with groupname for programs like `id`
    mkdir -p /etc
    cp ${passwd} /etc/passwd
    cp ${group} /etc/group
    cp ${shadow} /etc/shadow
    cp ${resolv_conf} /etc/resolv.conf

    mkdir -p /home/builder
    busybox adduser -h /home/builder -s /bin/sh -D  builder || true

    chown -R builder /nix/store
    #chmod -R 1775 /nix/store

    busybox su builder -c '/bin/sh /xchg/travis-nox-review-pr.sh nix'

    EXITSTATUSCODE=$?

    echo $EXITSTATUSCODE > /xchg/exitstatuscode

    if [[ "0" -eq "$EXITSTATUSCODE" ]]; then
      echo "BUILD SUCCESS!"
    else
      echo "BUILD FAILED!"
    fi
    echo "############################### BUILD END ###############################"
  '';

  runCommand = pkgs.writeText "runCommand" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.gawk}/bin:$PATH

    export HASH=`echo "${nixpkgs}${pr}" | sha1sum - | awk '{print $1}'`

    while `test -f /var/proots/$HASH.lock`; do sleep 10; echo "Waiting: $HASH.lock"; done
    touch /var/proots/$HASH.lock
    postCommands() {
      rm /var/proots/$HASH.lock
    }
    trap "postCommands" EXIT

    export PROOT_DIR=/var/proots/$HASH
    mkdir -p $PROOT_DIR/xchg
    test -w $PROOT_DIR/xchg || chmod -R g+w $PROOT_DIR/xchg

    cp <nixpkgs/maintainers/scripts/travis-nox-review-pr.sh> $PROOT_DIR/xchg

    { timeout ${timeout} ${pkgs.proot}/bin/proot -S "$PROOT_DIR" \
      -b /bin/sh \
      ${extraPRootArgs} ${buildScript}/bin/build.sh; } || true

    test -w $PROOT_DIR || echo "WARNING: `id` has no write permission for $PROOT_DIR"
    chmod g+w $PROOT_DIR || true

    EXITSTATUSCODE=`cat $PROOT_DIR/xchg/exitstatuscode`
    echo $EXITSTATUSCODE > $out
    test 0 -ne $EXITSTATUSCODE && exit $EXITSTATUSCODE
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
