{ pkgs, stdenv, fetchgit, fetchurl, prefix ? "", gccCrossStageStatic, which, binutils, glibcCross, file,  makeWrapper }:
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

    patches = [
      "${pkgs.path}/pkgs/development/interpreters/perl/5.20/no-sys-dirs.patch"
    ];

    configurePhase = ''
      cp -rv ${perlCrossSrc}/* .

      substituteInPlace ./configure --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./cnf/configure --replace "#!/bin/bash" "#!${stdenv.shell}"

      ./configure ${toString configureFlags}
    '';

    buildInputs = [ which makeWrapper binutils stdenv.gcc gccCrossStageStatic ];

    configureFlags = [
      "--prefix=$out"
      "--target=${stdenv.cross.config}"
      ''--host-set-ccflags="-I${stdenv.glibc}/include"''
      ''-Dccflags="-I${glibcCross}/include -B${glibcCross}/lib"''
      ''-Dlddlflags="-shared -I${glibcCross}/include -B${glibcCross}/lib "''
    ];

    preBuild = ''
      substituteInPlace ./Makefile.config.SH --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./miniperl_top --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./Makefile --replace 'perl$x: LDFLAGS += -Wl,-E' 'perl$x: LDFLAGS += -Wl,-E -B${glibcCross}/lib'
      substituteInPlace ./miniperl_top --replace 'exec $top/miniperl' 'export CPATH="${glibcCross}/include"; exec $top/miniperl'
      substituteInPlace ./x2p/Makefile --replace '$(LDFLAGS)' '-B${glibcCross}/lib'

      set -e
      function readlog {
        echo "######################### LOG START"
        tail ./config.log*
        echo "######################### TAILEND"
        cat ./config.log*
        echo "######################### LOG END"
      }
      trap readlog EXIT
    '';

    doCheck = true;

    installPhase = ''
      make DESTDIR=$out install
    '';
  }
