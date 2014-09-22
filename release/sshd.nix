{ pkgs, openssh, bash, openssl, busybox, forceCommand ? "", shell ? "", prefix, strace ? null }:
let

  resolv_conf = pkgs.writeText "resolv.conf" ''
  nameserver 8.8.8.8
  nameserver 8.8.4.4
  nameserver 4.4.4.4
  '';

  config_nix = pkgs.writeText "config.nix" ''
  pkgs: {
    packageOverrides = self: {
      nix = self.nix.override {
        storeDir = "/data/nix/store";
        stateDir = "/data/nix/var";
      };
    };
  }
  '';

  sshd_config = pkgs.writeText "sshd_config" ''
    PidFile ${prefix}/run/sshd.pid
    Port 9022
    HostKey ${prefix}/etc/ssh/ssh_host_rsa_key
    HostKey ${prefix}/etc/ssh/ssh_host_dsa_key
    UsePrivilegeSeparation no
    
    PasswordAuthentication no
    PermitRootLogin no
    PermitEmptyPasswords no
    StrictModes no
    PermitTTY yes

    PubkeyAuthentication yes
    AuthorizedKeysFile ${prefix}/home/builder/.ssh/authorized_keys

    ${pkgs.lib.optionalString (forceCommand != "") "ForceCommand ${forceCommand}"}
  '';

  passwd = pkgs.writeText "passwd" ''
    builder:x:@uid@:@gid@::${prefix}/home/builder:${if shell == "" then "${bash}/bin/bash" else shell}
  '';
  group = pkgs.writeText "group" ''
    users:x:@uid@:
  '';
  shadow = pkgs.writeText "shadow" ''
    builder:x:16117::::::
  '';
  pam_sshd = pkgs.writeText "sshd" ''
    #%PAM-1.0
    auth       required     pam_unix.so
    auth       required     pam_nologin.so
  '';

  sshd_init = pkgs.writeScript "sshd_init.sh" ''
  #!${bash}/bin/bash
  source ${env}
  mkdir -p ${prefix}/etc/ssh
  test -f ${prefix}/etc/ssh/ssh_host_rsa_key || { \
    openssl genrsa -out ${prefix}/etc/ssh/ssh_host_rsa_key 2048 && \
    openssl rsa -pubout -in ${prefix}/etc/ssh/ssh_host_rsa_key -out ${prefix}/etc/ssh/ssh_host_rsa_key.pub; }
  test -f ${prefix}/etc/ssh/ssh_host_dsa_key || { \
    openssl dsaparam -out ${prefix}/etc/ssh/dsaparam.pem 2048 && \
    openssl gendsa -out ${prefix}/etc/ssh/ssh_host_dsa_key ${prefix}/etc/ssh/dsaparam.pem && \
    openssl dsa -pubout -in ${prefix}/etc/ssh/ssh_host_dsa_key -out ${prefix}/etc/ssh/ssh_host_dsa_key.pub; }
  cp -v ${sshd_config} ${prefix}/etc/ssh/sshd_config
  mkdir -p ${prefix}/home/builder/.ssh
  sed -e "s|@uid@|`id -u`|g" -e "s|@gid@|`id -g`|g" ${passwd} > ${prefix}/etc/passwd
  sed -e "s|@uid@|`id -u`|g" ${group} > ${prefix}/etc/group
  cp -v ${shadow} ${prefix}/etc/shadow
  cp -v ${resolv_conf} ${prefix}/etc/resolv.conf
  test -f ${prefix}/home/builder/.nixpkgs/config.nix || { mkdir -p ${prefix}/home/builder/.nixpkgs && cp -v ${config_nix} ${prefix}/home/builder/.nixpkgs/config.nix; }
  '';

  sshd_run = pkgs.writeScript "sshd_run.sh" ''
  #!${bash}/bin/bash
  source ${env}
  test -d ${prefix}/etc/ssh || ${sshd_init}
  mkdir -p ${prefix}/run
  chown -R `id -u`:`id -g` ${prefix}/home/builder || true
  ${openssh}/sbin/sshd -f ${prefix}/etc/ssh/sshd_config
  '';

  sshd_debug = pkgs.writeScript "sshd_debug.sh" ''
  #!${bash}/bin/bash
  ${env} chown -R `id -u`:`id -g` ${prefix}/home/builder || true
  ${pkgs.lib.optionalString (strace != null) "${strace}/bin/strace"} ${openssh}/sbin/sshd -d -f ${prefix}/etc/ssh/sshd_config
  '';

  sshd_kill = pkgs.writeScript "sshd_kill.sh" ''
  #!${bash}/bin/bash
  source ${env}
  test -f ${prefix}/run/sshd.pid && { kill -9 `cat ${prefix}/run/sshd.pid` && rm ${prefix}/run/sshd.pid; }
  '';
  
  env = pkgs.writeScript "env.sh" ''
  #!${bash}/bin/bash
  export PATH="${bash}/bin:${openssh}/bin:${openssh}/sbin:${openssl}/bin:${busybox}/bin"

  "$@"
  '';
  
  sshd = pkgs.stdenv.mkDerivation rec {
    name = "sshd";
    unpackPhase = "true";
    dontBuild = true;
    installPhase = ''
    mkdir -p $out/bin
    ln -svf ${sshd_init} $out/bin/sshd_init
    ln -svf ${sshd_debug} $out/bin/sshd_debug
    ln -svf ${sshd_run} $out/bin/sshd_run
    ln -svf ${sshd_kill} $out/bin/sshd_kill
    '';
    };


in
  sshd
