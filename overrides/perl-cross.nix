{ stdenv, fetchgit, fetchurl, prefix ? "" }:
let
  perlCrossSrc = fetchgit {
    url = https://github.com/arsv/perl-cross;
    rev = "refs/tags/0.9.1";
    sha256 = "1icw7rkp0n12dzk8cjjcca824acjkxjw4bvd93fbkhjb0qgpnzdx";
  };

in
  stdenv.mkDerivation rec {
    name = "perl-5.20.0";

    src = fetchurl {
      url = "mirror://cpan/src/${name}.tar.gz";
      sha256 = "00ndpgw4bjing9gy2y6jvs3q46mv2ll6zrxjkhpr12fcdsnji32f";
    };

    preConfigure = ''
      cp -rv ${perlCrossSrc}/* .

      export CC=${stdenv.gcc}/bin/cc

      substituteInPlace ./configure --replace "/bin/bash" "${stdenv.shell}"
      substituteInPlace ./cnf/configure --replace "/bin/bash" "${stdenv.shell}"
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
