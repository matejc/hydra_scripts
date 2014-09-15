{ pkgs, stdenv, fetchgit, fetchurl, prefix ? "", gccCrossStageStatic, which, binutils, glibcCross, file }:
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
      substituteInPlace ./cnf/configure \
        --replace '. $base/configure_func.sh' '. $base/configure_func.sh; cat $cfglog'
      substituteInPlace ./cnf/configure --replace "#!/bin/bash" "#!${stdenv.shell}"

      #export CFLAGS="-I${glibcCross}/include"
      ${pkgs.busybox}/bin/find ${glibcCross}

      ./configure ${toString configureFlags}

    '';

    buildInputs = [ gccCrossStageStatic binutils stdenv.gcc which ];

    configureFlags = [
      "--prefix=$out"
      "--target=${stdenv.cross.config}"
      ''--host-set-ccflags="-I${stdenv.glibc}/include"''
      ''-Dccflags="-I${glibcCross}/include -B${glibcCross}/lib"''
    ];

    preBuild = ''
      substituteInPlace ./Makefile.config.SH --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./miniperl_top --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./Makefile --replace 'perl$x: LDFLAGS += -Wl,-E' 'perl$x: LDFLAGS += -Wl,-E,-L${glibcCross}/lib'
    '';

    installPhase = ''
      make DESTDIR=$out install
    '';
  }
