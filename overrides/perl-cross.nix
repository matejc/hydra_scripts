{ stdenv, fetchgit, fetchurl, perl520, lib, prefix ? "" }:
let
  perlCrossSrc = fetchgit {
    url = https://github.com/arsv/perl-cross;
    rev = "refs/tags/0.9.1";
    sha256 = "68732b270864cb0fc04c5790a594fc3ca420459a0555084cdd65bec9d9674d4a";
  };

in
  stdenv.mkDrivation  {
    name = "perl-5.20.0";

    src = fetchurl {
      url = "mirror://cpan/src/${name}.tar.gz";
      sha256 = "00ndpgw4bjing9gy2y6jvs3q46mv2ll6zrxjkhpr12fcdsnji32f";
    };

    preConfigure = ''
      cp -rv ${perlCrossSrc}/* .
    '';

    configureFlags = [
      "--target=${stdenv.cross.config}"
      "-Uinstallusrbinperl"
      "-Dinstallstyle=lib/perl5"
      "-Duseshrplib"
      "-Dlocincpth=${prefix}/usr/include"
      "-Dloclibpth=${prefix}/usr/lib"
      "-Dman1dir=$out/share/man/man1"
      "-Dman3dir=$out/share/man/man3"
    ];

    installPhase = ''
      make DESTDIR=$out install
    '';
  }
