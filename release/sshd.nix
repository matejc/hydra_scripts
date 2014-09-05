{ pkgs, openssh, bash, utillinux, prefix }:
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
  mkdir -p ${prefix}/etc/ssh
  test -f ${prefix}/etc/ssh/ssh_host_rsa_key || ssh-keygen -t rsa -f ${prefix}/etc/ssh/ssh_host_rsa_key -N ""
  test -f ${prefix}/etc/ssh/ssh_host_ecdsa_key || ssh-keygen -t ecdsa -f ${prefix}/etc/ssh/ssh_host_ecdsa_key -N ""
  test -f ${prefix}/etc/ssh/ssh_host_dsa_key || ssh-keygen -t dsa -f ${prefix}/etc/ssh/ssh_host_dsa_key -N ""
  test -f ${prefix}/etc/ssh/sshd_config || ln -sv ${sshd_config} ${prefix}/etc/ssh/sshd_config
  '';

  sshd_run = pkgs.writeScript "sshd_run.sh" ''
  #!${bash}/bin/bash
  test -d ${prefix}/etc/ssh || ${sshd_init}
  mkdir -p ${prefix}/run
  ${openssh}/sbin/sshd -f ${prefix}/etc/ssh/sshd_config
  '';

  sshd_kill = pkgs.writeScript "sshd_kill.sh" ''
  #!${bash}/bin/bash
  test -f ${prefix}/run/sshd.pid && ${utillinux}/bin/kill -9 `cat ${prefix}/run/sshd.pid`
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
