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

      set -e
      function readlog {
        echo "######################### LOG START"
        cat ./config.log*
        echo "######################### LOG END"
      }
      trap readlog EXIT


      export GCCBIN=`pwd`/bin
      mkdir -p $GCCBIN
      for i in ${gccCrossStageStatic}/bin/*; do
          makeWrapper $i $GCCBIN/`basename $i` \
            --prefix CPATH ":" "${glibcCross}/include" \
            --prefix LIBRARY_PATH ":" "${glibcCross}/lib" \
            --prefix LD_LIBRARY_PATH ":" "${glibcCross}/lib" \
            --set CCFLAGS " -I${glibcCross}/include -B${glibcCross}/lib $CCFLAGS " \
            --set LDFLAGS " -L${glibcCross}/lib $LDFLAGS "
      done
      for i in ${stdenv.gcc}/bin/*; do
          makeWrapper $i $GCCBIN/`basename $i` \
            --prefix CPATH ":" "${stdenv.glibc}/include" \
            --prefix LIBRARY_PATH ":" "${stdenv.glibc}/lib" \
            --prefix LD_LIBRARY_PATH ":" "${stdenv.glibc}/lib" \
            --set LDFLAGS " -L${stdenv.glibc}/lib $LDFLAGS "
      done
      export PATH="$GCCBIN:$PATH"

      ./configure ${toString configureFlags}
    '';

    buildInputs = [ which makeWrapper ];

    configureFlags = [
      "--prefix=$out"
      "--target=${stdenv.cross.config}"
      ''--host-set-ccflags="-I${stdenv.glibc}/include"''
      ''-Dccflags="-I${glibcCross}/include -B${glibcCross}/lib"''
      "--with-objdump=${binutils}/bin/objdump"
    ];

    preBuild = ''
      substituteInPlace ./Makefile.config.SH --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./miniperl_top --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./Makefile --replace 'perl$x: LDFLAGS += -Wl,-E' 'perl$x: LDFLAGS += -Wl,-E -B${glibcCross}/lib'
      substituteInPlace ./miniperl_top --replace 'exec $top/miniperl' 'export CPATH="${glibcCross}/include"; exec $top/miniperl'

      echo "#####################################"
      ${pkgs.busybox}/bin/find $GCCBIN
      echo "#####################################"
      ${pkgs.busybox}/bin/find ${stdenv.gcc}/bin
      echo "#####################################"
      ${pkgs.busybox}/bin/find ${gccCrossStageStatic}/bin
      echo "#####################################"
    '';

    installPhase = ''
      make DESTDIR=$out install
    '';
  }
