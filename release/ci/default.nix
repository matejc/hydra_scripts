{ nixpkgs, system ? builtins.currentSystem, timeout ? "36000", extraPRootArgs ? "", pr ? "6118", nix,
tarball ? "http://hydra.nixos.org/job/nixos/trunk-combined/nixos.containerTarball.x86_64-linux/latest/download-by-type/file/system-tarball" }:
let
  pkgs = import <nixpkgs> { inherit system; };

  passwd = pkgs.writeText "passwd" ''
    root:x:0:0::/root:/bin/sh
    nixbld1:x:30001:30000::/home/builder:/bin/sh
  '';
  group = pkgs.writeText "group" ''
    root:x:0:
    nixbld:x:30000:nixbld1
  '';
  shadow = pkgs.writeText "shadow" ''
    root:x:16117::::::
    nixbld1:!:15925::::::
  '';
  resolv_conf = pkgs.writeText "resolv.conf" ''
    nameserver 8.8.8.8
    nameserver 8.8.4.4
    nameserver 4.4.4.4
  '';

  buildScript = pkgs.writeScriptBin "build.sh" ''
    #!/bin/sh
    echo "############################### BUILD START ###############################"
    export PATH="/bin:`readlink -f /nix/store/*-system-path/bin/ | awk 'NR==1'`:$PATH"

    # chown -R 0:0 /etc
    
    # echo "login   auth    required        pam_nologin.so  no_warn" > /etc/pam.conf
    
    # ls -lah /etc

    export HOME=/root
    mkdir -p $HOME

    # strace groupadd -f -g 100 nixbld

    mkdir -p /home/builder
    # useradd -d /home/builder -s /bin/sh nixbld1 -g nixbld || true

    echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > $HOME/.nix-channels
    
    strace nix-channel --update

    # if [ -f /nix-path-registration ]; then
      # nix-store --load-db < /nix-path-registration && rm /nix-path-registration
    # fi
    # nixos-rebuild also requires a "system" profile
    #nix-env -p /nix/var/nix/profiles/system --set /run/current-system

    echo "list packages:"
    nix-env -qa '*' | wc -l

    echo "install nox:"
    nix-env -iA pkgs.nox

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
    
    FULLPATH=`readlink -f $PROOT_ROOT/nix/store/*-bash-*/bin/bash | awk 'NR==1'`
    ln -sf ''${FULLPATH#$PROOT_ROOT} $PROOT_ROOT/bin/sh

    mkdir -p $PROOT_ROOT/etc/
    cp ${passwd} $PROOT_ROOT/etc/passwd && chmod 600 $PROOT_ROOT/etc/passwd
    cp ${group} $PROOT_ROOT/etc/group && chmod 600 $PROOT_ROOT/etc/group
    cp ${shadow} $PROOT_ROOT/etc/shadow && chmod 600 $PROOT_ROOT/etc/shadow

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
