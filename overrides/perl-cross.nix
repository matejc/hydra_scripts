{ stdenv, fetchgit, fetchurl, prefix ? "", gccCrossStageStatic, which, binutils }:
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

      substituteInPlace ./configure --replace "/bin/bash" "${stdenv.shell}"
      substituteInPlace ./cnf/configure --replace "/bin/bash" "${stdenv.shell}"
      
      echo "########################################################################"
      ls -lah ${toString binutils}/bin
      ls -lah ${toString stdenv.gcc}/bin
      ls -lah ${toString gccCrossStageStatic}/bin


      export LD=${binutils}/bin/ld
    '';

    buildInputs = [ gccCrossStageStatic binutils stdenv.gcc which ];

    configureFlags = [
      "--mode=cross"
      "--target=${stdenv.cross.config}"
      "--target-tools-prefix=${stdenv.cross.config}-"
      "--with-cc=${stdenv.cross.config}-gcc"
      "--host-cc=gcc"
    ];

    installPhase = ''
      make DESTDIR=$out install
    '';
  }
