{ pkgs, stdenv, fetchurl, fetchgit, prefix ? "", gccCrossStageStatic, which, binutils, glibcCross, file, makeWrapper }:
let
  perlCrossSrc = fetchgit {
    url = "git://github.com/arsv/perl-cross";
    rev = "refs/tags/0.7.4";
    sha256 = "1h37knc2fhgvkj8y7xafg396d145dgcbvg7y51mvai9f4fiic951";
  };

in
  stdenv.mkDerivation rec {
    name = "perl-cross-${stdenv.cross.config}";

    src = fetchgit {
      url = "git://github.com/Perl/perl5";
      rev = "refs/tags/v5.16.3";
      sha256 = "1xhszndh6l9siqp6wmm6nj1bwhyixif8lphfk8psnp622sp1zzy6";
    };

    patches = [
      "${pkgs.path}/pkgs/development/interpreters/perl/5.16/no-sys-dirs.patch"
    ];

    configurePhase = ''
      cp -rv ${perlCrossSrc}/* .

      substituteInPlace ./configure --replace "#!/bin/bash" "#!${stdenv.shell}"
      sed -i -e 's|#!/bin/bash|#!${stdenv.shell}|g' ./cnf/configure
      substituteInPlace ./Makefile.config.SH --replace "#!/bin/bash" "#!${stdenv.shell}"

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
      substituteInPlace ./miniperl_top --replace "#!/bin/bash" "#!${stdenv.shell}"
      #substituteInPlace ./Makefile --replace 'perl$x: LDFLAGS += -Wl,-E' 'perl$x: LDFLAGS += -Wl,-E -B${glibcCross}/lib'
      substituteInPlace ./Makefile --replace 'cd $(dir $@) && $(top)miniperl_top -I$(top)lib Makefile.PL' 'echo "$@ > > > $(dir $@)" && cd $(dir $@) && $(top)miniperl_top -I$(top)lib Makefile.PL'
      substituteInPlace ./miniperl_top --replace 'exec $top/miniperl' 'export CPATH="${glibcCross}/include"; exec $top/miniperl'
      #substituteInPlace ./x2p/Makefile --replace '$(LDFLAGS)' '-B${glibcCross}/lib'

      #sed -i -e "s|cwd()|\`pwd\`|g" ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm
      #sed -i -e "s|chdir \$dir|\`cd \$dir\`|g" ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm
      substituteInPlace ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm --replace " || die \"Can't figure out your cwd\!\"" ""

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
      ${gccCrossStageStatic}/bin/${stdenv.cross.config}-gcc -Wl,-dynamic-linker,$INTERPRETER -B${glibcCross}/lib \$@" > $GCCBIN/${stdenv.cross.config}-gcc
      chmod +x $GCCBIN/${stdenv.cross.config}-gcc
      
      export PATH=`echo $PATH | sed -e "s|${gccCrossStageStatic}/bin|$GCCBIN|g" -e "s|${gccCrossStageStatic.gcc}/bin||g" -e "s|${stdenv.gcc}/bin||g"`
    '';

    #postInstall = ''
    #  INTERPRETER=`realpath ${glibcCross}/lib/ld-*.so`
    #  find $out -type f -exec patchelf --set-interpreter $INTERPRETER {} \;
    #'';

  }
