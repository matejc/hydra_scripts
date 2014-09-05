{ pkgs, openssh, bash, utillinux, coreutils, prefix }:
let

  sshd_config = pkgs.writeText "sshd_config" ''
    PidFile ${prefix}/run/sshd.pid
    Port 9022
    AuthorizedKeysFile ${prefix}/etc/ssh/authorized_keys
    HostKey ${prefix}/etc/ssh/ssh_host_rsa_key
    HostKey ${prefix}/etc/ssh/ssh_host_ecdsa_key
    HostKey ${prefix}/etc/ssh/ssh_host_dsa_key
    UsePrivilegeSeparation no
  '';

  sshd_init = pkgs.writeScript "sshd_init.sh" ''
  #!${bash}/bin/bash
  source ${env}
  mkdir -p ${prefix}/etc/ssh
  test -f ${prefix}/etc/ssh/ssh_host_rsa_key || ssh-keygen -t rsa -f ${prefix}/etc/ssh/ssh_host_rsa_key -N ""
  test -f ${prefix}/etc/ssh/ssh_host_ecdsa_key || ssh-keygen -t ecdsa -f ${prefix}/etc/ssh/ssh_host_ecdsa_key -N ""
  test -f ${prefix}/etc/ssh/ssh_host_dsa_key || ssh-keygen -t dsa -f ${prefix}/etc/ssh/ssh_host_dsa_key -N ""
  test -f ${prefix}/etc/ssh/sshd_config || ln -sv ${sshd_config} ${prefix}/etc/ssh/sshd_config
  '';

  sshd_run = pkgs.writeScript "sshd_run.sh" ''
  #!${bash}/bin/bash
  source ${env}
  test -d ${prefix}/etc/ssh || ${sshd_init}
  mkdir -p ${prefix}/run
  sshd -f ${prefix}/etc/ssh/sshd_config
  '';

  sshd_kill = pkgs.writeScript "sshd_kill.sh" ''
  #!${bash}/bin/bash
  source ${env}
  test -f ${prefix}/run/sshd.pid && kill -9 `cat ${prefix}/run/sshd.pid`
  '';
  
  env = pkgs.writeScript "env.sh" ''
  #!${bash}/bin/bash
  export PATH="${utillinux}/bin:${bash}/bin:${openssh}/bin:${openssh}/sbin:${coreutils}/bin"

  "$@"
  '';
  
  sshd = pkgs.stdenv.mkDerivation rec {
    name = "sshd";
    unpackPhase = "true";
    dontBuild = true;
    installPhase = ''
    mkdir -p $out/bin
    ln -svf ${openssh}/bin/* $out/bin
    ln -svf ${sshd_init} $out/bin/sshd_init
    ln -svf ${sshd_run} $out/bin/sshd_run
    ln -svf ${sshd_kill} $out/bin/sshd_kill
    '';
    };


in
  sshd
