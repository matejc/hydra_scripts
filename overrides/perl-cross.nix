{ pkgs, stdenv, fetchurl, prefix ? "", gccCrossStageStatic, which, binutils, glibcCross, file, makeWrapper }:
let
  perlCrossSrc = fetchurl {
    url = "https://github.com/arsv/perl-cross/blob/releases/perl-5.16.3-cross-0.7.4.tar.gz";
    sha256 = "050l7h63rk32j3qmgpsf8z9s0cskq4fp4n0gs9439rg0qw8cwkp0";
  };

in
  stdenv.mkDerivation rec {
    name = "perl-cross-${stdenv.cross.config}";

    src = fetchurl {
      url = "http://www.cpan.org/src/5.0/perl-5.16.3.tar.gz";
      sha256 = "68732b270864cb0fc04c5790a594fc3ca420459a0555084cdd65bec9d9674d4a";
    };

    patches = [
      "${pkgs.path}/pkgs/development/interpreters/perl/5.16/no-sys-dirs.patch"
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
      "--host-set-ccflags='-I${stdenv.glibc}/include'"
      "-Dccflags='-I${glibcCross}/include -B${glibcCross}/lib'"
      "-Dlddlflags='-shared -I${glibcCross}/include -B${glibcCross}/lib '"
    ];

    preBuild = ''
      substituteInPlace ./Makefile.config.SH --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./miniperl_top --replace "#!/bin/bash" "#!${stdenv.shell}"
      substituteInPlace ./Makefile --replace 'perl$x: LDFLAGS += -Wl,-E' 'perl$x: LDFLAGS += -Wl,-E -B${glibcCross}/lib'
      substituteInPlace ./miniperl_top --replace 'exec $top/miniperl' 'export CPATH="${glibcCross}/include"; exec $top/miniperl'
      substituteInPlace ./x2p/Makefile --replace '$(LDFLAGS)' '-B${glibcCross}/lib'

      export GCCBIN=`pwd`/bin
      export INTERPRETER=`realpath ${glibcCross}/lib/ld-*.so`
      mkdir -p $GCCBIN
      for i in ${stdenv.gcc}/bin/*; do
        ln -sv $i $GCCBIN
      done
      for i in ${gccCrossStageStatic}/bin/*; do
        ln -sv $i $GCCBIN
      done

      #rm $GCCBIN/gcc
      #echo -e "#!${stdenv.shell} -x\n\
      #${stdenv.gcc}/bin/gcc -Wl,-dynamic-linker,$INTERPRETER \$@" > $GCCBIN/gcc
      #chmod +x $GCCBIN/gcc
      
      rm $GCCBIN/${stdenv.cross.config}-gcc
      echo -e "#!${stdenv.shell} -x\n\
      ${gccCrossStageStatic}/bin/${stdenv.cross.config}-gcc -Wl,-dynamic-linker,$INTERPRETER \$@" > $GCCBIN/${stdenv.cross.config}-gcc
      chmod +x $GCCBIN/${stdenv.cross.config}-gcc
      
      export PATH=`echo $PATH | sed -e "s|${gccCrossStageStatic}/bin|$GCCBIN|g" -e "s|${gccCrossStageStatic.gcc}/bin||g" -e "s|${stdenv.gcc}/bin||g"`
    '';

    #postInstall = ''
    #  INTERPRETER=`realpath ${glibcCross}/lib/ld-*.so`
    #  find $out -type f -exec patchelf --set-interpreter $INTERPRETER {} \;
    #'';

  }
