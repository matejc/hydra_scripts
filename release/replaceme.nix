{ pkgs, prefix, url, resultPath, systemPath ? "/system/bin", shell ? "/system/bin/sh" }:
let
  replaceme = pkgs.writeScriptBin "replaceme" ''
  #!${shell}

  export PATH="${resultPath}"
  mkdir -p ${prefix}/tmp
  busybox wget ${url} -O ${prefix}/tmp/out.tar.xx

  #url="${url}"
  #domain=`echo $url | busybox sed 's-^[^/]*/*\([^/]*\)/\?.*$-\1-'`
  #ipaddr=`ping -c 1 $domain | busybox sed -n 's@^.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*$@\1@p' | busybox head -1`
  #req_url=`echo $url | busybox sed "s-/[^/]\+-/$ipaddr-"`
  #busybox wget $req_url -O ${prefix}/tmp/out.tar.xx

  export PATH="${systemPath}"
  rm -rf ${prefix}/store || true
  rm -rf ${prefix}/result || true
  busybox tar xvf ${prefix}/tmp/out.tar.xx -C /
  '';
in
  replaceme
