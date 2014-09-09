{ pkgs, bash, busybox, environment, prefix, url, ping ? "/system/bin/ping" }:
let
  resolv_conf = pkgs.writeText "resolv.conf" ''
  nameserver 8.8.8.8
  nameserver 8.8.4.4
  nameserver 4.4.4.4
  '';

  replaceme = pkgs.writeScriptBin "replaceme" ''
  #!${bash}/bin/bash
  source ${environment}
  test -f ${prefix}/etc/resolv.conf || cp -v ${resolv_conf} ${prefix}/etc/resolv.conf
  test -d ${prefix}/tmp || mkdir -p ${prefix}/tmp
  url="${url}"
  domain=`echo $url | sed 's-^[^/]*/*\([^/]*\)/\?.*$-\1-'`
  ipaddr=`${ping} -c 1 $domain | sed -n 's@^.*(\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*$@\1@p' | head -1`
  req_url=`echo $url | sed "s-/[^/]\+-/$ipaddr-"`
  wget $req_url -O ${prefix}/tmp/out.tar.xx
  tar xvf ${prefix}/tmp/out.tar.xx -C /
  '';

in
  replaceme
