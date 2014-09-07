{ stdenv, fetchurl, flex, cracklib, pkgs, etcDir ? null, findutils }:

stdenv.mkDerivation rec {
  name = "linux-pam-1.1.8";

  src = fetchurl {
    url = http://www.linux-pam.org/library/Linux-PAM-1.1.8.tar.bz2;
    sha256 = "0m8ygb40l1c13nsd4hkj1yh4p1ldawhhg8pyjqj9w5kd4cxg5cf4";
  };

  patches = [ "${pkgs.path}/pkgs/os-specific/linux/pam/CVE-2014-2583.patch" ];

  nativeBuildInputs = [ flex ];

  buildInputs = [ cracklib ];

  crossAttrs = {
    propagatedBuildInputs = [ flex.crossDrv cracklib.crossDrv ];
  };

  postInstall = ''
    mv -v $out/sbin/unix_chkpwd{,.orig}
    ln -sv /var/setuid-wrappers/unix_chkpwd $out/sbin/unix_chkpwd
  '';

  preConfigure = stdenv.lib.optionalString (etcDir != null) ''
    echo "Rewriting /etc to ${etcDir}"
    ${findutils}/bin/find . -type f -exec sed -i -e 's|/etc|${etcDir}|g' {} \;
  '' + ''
    configureFlags="$configureFlags --includedir=$out/include/security"
  '';

  meta = {
    homepage = http://ftp.kernel.org/pub/linux/libs/pam/;
    description = "Pluggable Authentication Modules, a flexible mechanism for authenticating user";
    platforms = stdenv.lib.platforms.linux;
  };
}
