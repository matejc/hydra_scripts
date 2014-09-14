{ stdenv, fetchgit, perl520, lib, prefix ? "" }:
let
  perlCrossSrc = fetchgit {
    url = https://github.com/arsv/perl-cross;
    rev = "refs/tags/0.9.1";
    sha256 = "68732b270864cb0fc04c5790a594fc3ca420459a0555084cdd65bec9d9674d4a";
  };

in
  lib.overrideDerivation perl520 (oldAttrs: {
    preConfigure = ''
      cp -rv ${perlCrossSrc}/* .
    '' + oldAttrs.preConfigure;
    configureFlags = [
      "--target=${stdenv.cross.config}"
      "-Uinstallusrbinperl"
      "-Dinstallstyle=lib/perl5"
      "-Duseshrplib"
      "-Dlocincpth=${prefix}/usr/include"
      "-Dloclibpth=${prefix}/usr/lib"
    ];
  })
