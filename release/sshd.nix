{ pkgs, openssh, bash, utillinux, coreutils, openssl, environment, prefix }:
let

  sshd_config = pkgs.writeText "sshd_config" ''
    PidFile ${prefix}/run/sshd.pid
    Port 9022
    HostKey ${prefix}/etc/ssh/ssh_host_rsa_key
    HostKey ${prefix}/etc/ssh/ssh_host_dsa_key
    UsePrivilegeSeparation no
    
    UsePAM no
    PasswordAuthentication no
    PermitRootLogin no
    PermitEmptyPasswords no
    StrictModes no
    PermitTTY no

    PubkeyAuthentication yes
    AuthorizedKeysFile ${prefix}/etc/ssh/authorized_keys

    ForceCommand ${environment} bash
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
  test -f ${prefix}/etc/ssh/sshd_config || ln -sv ${sshd_config} ${prefix}/etc/ssh/sshd_config
  '';

  sshd_run = pkgs.writeScript "sshd_run.sh" ''
  #!${bash}/bin/bash
  source ${env}
  test -d ${prefix}/etc/ssh || ${sshd_init}
  mkdir -p ${prefix}/run
  ${openssh}/sbin/sshd -f ${prefix}/etc/ssh/sshd_config
  '';

  sshd_kill = pkgs.writeScript "sshd_kill.sh" ''
  #!${bash}/bin/bash
  source ${env}
  test -f ${prefix}/run/sshd.pid && kill -9 `cat ${prefix}/run/sshd.pid`
  '';
  
  env = pkgs.writeScript "env.sh" ''
  #!${bash}/bin/bash
  export PATH="${utillinux}/bin:${bash}/bin:${openssh}/bin:${openssh}/sbin:${coreutils}/bin:${openssl}/bin"

  "$@"
  '';
  
  sshd = pkgs.stdenv.mkDerivation rec {
    name = "sshd";
    unpackPhase = "true";
    dontBuild = true;
    installPhase = ''
    mkdir -p $out/bin
    ln -svf ${sshd_init} $out/bin/sshd_init
    ln -svf ${sshd_run} $out/bin/sshd_run
    ln -svf ${sshd_kill} $out/bin/sshd_kill
    '';
    };


in
  sshd
