{ pkgs, prefix, url, resultPath, shell ? "/system/bin/sh" }:
let
  replaceproot = pkgs.writeScriptBin "replaceproot" ''
  #!${shell}
  export PATH="${resultPath}"
  mkdir -p ${prefix}/proot
  busybox wget ${url} -O ${prefix}/tmp/proot-out.tar.xx && \
  { \
    export PATH="${systemPath}" && \
    rm -rf ${prefix}/proot || true && \
    busybox tar xvf ${prefix}/tmp/proot-out.tar.xx -C ${prefix}/proot; \
  }
  '';
in
  replaceproot
