{ stdenv, fetchgit, fetchurl, prefix ? "", gccCrossStageStatic, which, binutils, glibcCross }:
let
  perlCrossSrc = fetchgit {
    url = https://github.com/arsv/perl-cross;
    rev = "refs/tags/0.9.1";
    sha256 = "1icw7rkp0n12dzk8cjjcca824acjkxjw4bvd93fbkhjb0qgpnzdx";
  };

in
  stdenv.mkDerivation rec {
    name = "perl-cross";

    src = fetchurl {
      url = "mirror://cpan/src/perl-5.20.0.tar.gz";
      sha256 = "00ndpgw4bjing9gy2y6jvs3q46mv2ll6zrxjkhpr12fcdsnji32f";
    };

    configurePhase = ''
      cp -rv ${perlCrossSrc}/* .

      substituteInPlace ./configure --replace "/bin/bash" "${stdenv.shell}"
      substituteInPlace ./cnf/configure --replace "/bin/bash" "${stdenv.shell}"

      export CFLAGS=" $CFLAGS -I${glibcCross}/include "
      export LDFLAGS=" $LDFLAGS -L${glibcCross}/lib "

      ./configure ${toString configureFlags}
    '';

    buildInputs = [ gccCrossStageStatic binutils stdenv.gcc which ];

    configureFlags = [
      "--prefix=$out"
      "--target=${stdenv.cross.config}"
      "--with-libs=memchr"
    ];

    preBuild = ''
      substituteInPlace ./Makefile.config.SH --replace "/bin/bash" "${stdenv.shell}"
      substituteInPlace ./miniperl_top --replace "/bin/bash" "${stdenv.shell}"
    '';

    installPhase = ''
      make DESTDIR=$out install
    '';
  }
