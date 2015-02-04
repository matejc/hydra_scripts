{ nixpkgs, system ? builtins.currentSystem, timeout ? "36000", extraPRootArgs ? "", pr ? "6118", nix }:
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

    # to associate uid with username and
    # gid with groupname for programs like `id`
    mkdir -p /etc
    cp ${passwd} /etc/passwd
    cp ${group} /etc/group
    cp ${shadow} /etc/shadow

    ls -lah /xchg/nix
    
    cd /xchg/nix && ./install
    
    . ~/.nix-profile/etc/profile.d/nix.sh
    nix-env -qa '*' | wc -l

    nix-env -iA pkgs.nox

    { nox-review pr ${pr}; }

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
    export PATH=${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.curl}/bin:${pkgs.gnutar}/bin:${pkgs.bzip2}/bin:$PATH
    export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ca-bundle.crt
    export HASH=`echo "${nixpkgs}${pr}" | sha1sum - | awk '{print $1}'`

    while `test -f /var/proots/$HASH.lock`; do sleep 10; echo "Waiting: $HASH.lock"; done
    touch /var/proots/$HASH.lock
    export PROOT_DIR=/var/proots/$HASH
    postCommands() {
      rm /var/proots/$HASH.lock
    }
    trap "postCommands" EXIT

    mkdir -p $PROOT_DIR/xchg

    cp -f ${buildScript}/bin/build.sh $PROOT_DIR/xchg
    test -f $PROOT_DIR/xchg/nix.tar.xx || curl ${nix} -o $PROOT_DIR/xchg/nix.tar.xx
    test -d $PROOT_DIR/xchg/nix && rm -rf $PROOT_DIR/xchg/nix
    mkdir -p $PROOT_DIR/xchg/nix
    tar xvf $PROOT_DIR/xchg/nix.tar.xx -C $PROOT_DIR/xchg/nix
    chmod -R g+w $PROOT_DIR/xchg || true

    { timeout ${timeout} ${pkgs.proot}/bin/proot -S "$PROOT_DIR" \
      -b ${pkgs.bash}/bin/bash:/bin/sh
      ${extraPRootArgs} "/xchg/build.sh"; } || true

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
