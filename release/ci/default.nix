{ nixpkgs, system ? builtins.currentSystem, timeout ? "36000", extraPRootArgs ? "", pr ? "6118", nix,
tarball ? "http://hydra.nixos.org/job/nixos/trunk-combined/nixos.containerTarball.x86_64-linux/latest/download-by-type/file/system-tarball" }:
let
  pkgs = import <nixpkgs> { inherit system; };

  passwd = pkgs.writeText "passwd" ''
    root:x:0:0::/root:/bin/sh
  '';
  group = pkgs.writeText "group" ''
    root:x:0:
    nixbld:x:100:
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

    export HOME=/root
    mkdir -p $HOME

    `readlink -f /nix/store/*-nix-*/etc/profile.d/nix.sh | awk 'NR==1'`
    

    if [ -f /nix-path-registration ]; then
      `readlink -f /nix/store/*-nix-*/bin/nix-store | awk 'NR==1'` --load-db < /nix-path-registration && rm /nix-path-registration
    fi
    # nixos-rebuild also requires a "system" profile
    `readlink -f /nix/store/*-nix-*/bin/nix-env | awk 'NR==1'` -p /nix/var/nix/profiles/system --set /run/current-system

    `readlink -f /nix/store/*-nix-*/bin/nix-env | awk 'NR==1'` -qa '*' | wc -l

    `readlink -f /nix/store/*-nix-*/bin/nix-env | awk 'NR==1'` -iA pkgs.nox

    { nox-review pr ${pr}; }

    EXITSTATUSCODE=$?

    echo $EXITSTATUSCODE > /exitstatuscode

    if [[ "0" -eq "$EXITSTATUSCODE" ]]; then
      echo "BUILD SUCCESS!"
    else
      echo "BUILD FAILED!"
    fi
    echo "############################### BUILD END ###############################"
  '';

  runCommand = pkgs.writeText "runCommand" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.wget}/bin:${pkgs.gnutar}/bin:${pkgs.xz}/bin:$PATH
    export CURL_CA_BUNDLE=${pkgs.cacert}/etc/ca-bundle.crt
    export HASH=`echo "${nixpkgs}${pr}" | sha1sum - | awk '{print $1}'`

    while `test -f /var/proots/$HASH.lock`; do sleep 10; echo "Waiting: $HASH.lock"; done
    touch /var/proots/$HASH.lock
    export PROOT_DIR=/var/proots/$HASH
    export PROOT_ROOT=/var/proots/$HASH/root
    postCommands() {
      rm /var/proots/$HASH.lock
    }
    trap "postCommands" EXIT

    mkdir -p $PROOT_DIR/xchg

    cp -f ${buildScript}/bin/build.sh $PROOT_DIR/xchg
    test -f $PROOT_DIR/xchg/tarball.tar.xz || wget ${tarball} -O $PROOT_DIR/xchg/tarball.tar.xz
    test -f $PROOT_DIR/xchg/tarball.tar || xz -dk $PROOT_DIR/xchg/tarball.tar.xz
    mkdir -p $PROOT_ROOT/bin
    test -d $PROOT_ROOT/nix/store || tar xf $PROOT_DIR/xchg/tarball.tar -C $PROOT_ROOT
    chmod -R g+w $PROOT_DIR/xchg || true

    BASHFULL=`readlink -f $PROOT_ROOT/nix/store/*-bash-*/bin/bash | awk 'NR==1'`
    ln -sf ''${BASHFULL#$PROOT_ROOT} $PROOT_ROOT/bin/sh

    cp ${passwd} $PROOT_ROOT/passwd && chmod +w $PROOT_ROOT/passwd
    cp ${group} $PROOT_ROOT/group && chmod +w $PROOT_ROOT/group
    cp ${shadow} $PROOT_ROOT/shadow && chmod +w $PROOT_ROOT/shadow

    { timeout ${timeout} ${pkgs.proot}/bin/proot -S "$PROOT_ROOT" \
      -b $PROOT_DIR/xchg/build.sh:/bin/build.sh \
      ${extraPRootArgs} "/bin/build.sh"; } || true

    test -w $PROOT_DIR || echo "WARNING: `id` has no write permission for $PROOT_DIR"
    # chmod g+w $PROOT_DIR || true

    EXITSTATUSCODE=`cat $PROOT_ROOT/exitstatuscode`
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
