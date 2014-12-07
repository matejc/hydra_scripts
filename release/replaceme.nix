{ pkgs, prefix, url, resultPath, systemPath ? "/system/bin", shell ? "/system/bin/sh" }:
let
  replaceme = pkgs.writeScriptBin "replaceme" ''
  #!${shell}
  export PATH="${resultPath}"
  mkdir -p ${prefix}/tmp
  busybox wget ${url} -O ${prefix}/tmp/out.tar.xx && \
  { \
    export PATH="${systemPath}" && \
    rm -rf ${prefix}/store || true && \
    rm -rf ${prefix}/var/nix || true && \
    rm -rf ${prefix}/result || true && \
    busybox tar xvf ${prefix}/tmp/out.tar.xx -C / &&
    ${resultPath}/sshd_kill || true &&
    ${resultPath}/sshd_init || true &&
    ${resultPath}/sshd_run; \
  }
  '';
in
  replaceme
