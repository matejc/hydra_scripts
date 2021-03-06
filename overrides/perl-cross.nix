{ pkgs, stdenv, fetchurl, fetchgit, prefix ? "", gccCrossStageStatic, which, binutils, glibcCross, file, makeWrapper
, bashCross, busybox }:
let
  perlCrossSrc = fetchgit {
    url = "git://github.com/arsv/perl-cross";
    rev = "refs/tags/0.9.1";
    sha256 = "1icw7rkp0n12dzk8cjjcca824acjkxjw4bvd93fbkhjb0qgpnzdx";
  };

in
  stdenv.mkDerivation rec {
    name = "perl-cross-${stdenv.cross.config}";

    src = fetchgit {
      url = "git://github.com/Perl/perl5";
      rev = "refs/tags/v5.20.0";
      sha256 = "1s39f14mkrdq53q440fyn3jhwcrmsazn19n05gkhkaidx9w4zmid";
    };

    patches = [
      "${pkgs.path}/pkgs/development/interpreters/perl/5.20/no-sys-dirs.patch"
    ];

    configurePhase = ''
      cp -rv ${perlCrossSrc}/* .

      substituteInPlace ./configure --replace "#!/bin/bash" "#!${stdenv.shell}"
      sed -i -e 's|#!/bin/bash|#!${stdenv.shell}|g' ./cnf/configure
      substituteInPlace ./Makefile.config.SH --replace "#!/bin/bash" "#!${stdenv.shell}"

      #${busybox}/bin/find . -type f -exec sed -i -e 's|"/bin/sh"|"${bashCross}/bin/bash"|g' {} \;
      #${busybox}/bin/find . -type f -exec sed -i -e "s|'/bin/sh'|'${bashCross}/bin/bash'|g" {} \;
      #${busybox}/bin/find . -type f -exec sed -i -e 's|#define SH_PATH .*$|#define SH_PATH "${bashCross}/bin/bash"|g' {} \;

      ./configure ${toString configureFlags}
    '';

    buildInputs = [ which makeWrapper binutils stdenv.gcc gccCrossStageStatic ];

    configureFlags = [
      "--prefix=$out"
      "--target=${stdenv.cross.config}"
      "--host-set-ccflags='-I${stdenv.glibc}/include'"
      "-Dccflags='-I${glibcCross}/include -B${glibcCross}/lib'"
      "-Dlddlflags='-shared -I${glibcCross}/include -B${glibcCross}/lib '"
      "-Dusethreads"
      "-Dsh=${bashCross}/bin/bash"
    ];

    preBuild = ''
      substituteInPlace ./miniperl_top --replace "#!/bin/bash" "#!${stdenv.shell}"
      #substituteInPlace ./Makefile --replace 'perl$x: LDFLAGS += -Wl,-E' 'perl$x: LDFLAGS += -Wl,-E -B${glibcCross}/lib'
      substituteInPlace ./Makefile --replace 'cd $(dir $@) && $(top)miniperl_top -I$(top)lib Makefile.PL' 'echo "$@ > > > $(dir $@)" && cd $(dir $@) && $(top)miniperl_top -I$(top)lib Makefile.PL'
      substituteInPlace ./miniperl_top --replace 'exec $top/miniperl' 'export CPATH="${glibcCross}/include"; exec $top/miniperl'
      #substituteInPlace ./x2p/Makefile --replace '$(LDFLAGS)' '-B${glibcCross}/lib'

      #sed -i -e "s|cwd()|\`pwd\`|g" ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm
      #sed -i -e "s|chdir \$dir|\`cd \$dir\`|g" ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm
      #substituteInPlace ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm --replace " || die \"Can't figure out your cwd\!\"" ""
      #sed -i -e "s/ || die \"Can't figure out your cwd\!\"//g" ./cpan/ExtUtils-MakeMaker/lib/ExtUtils/MakeMaker.pm

      export GCCBIN=`pwd`/bin
      export INTERPRETER=`realpath ${glibcCross}/lib/ld-*.so`
      mkdir -p $GCCBIN
      for i in ${stdenv.gcc}/bin/*; do
        ln -sv $i $GCCBIN
      done
      for i in ${gccCrossStageStatic}/bin/*; do
        ln -sv $i $GCCBIN
      done

      rm $GCCBIN/${stdenv.cross.config}-gcc
      echo -e "#!${stdenv.shell} -x\n\
      ${gccCrossStageStatic}/bin/${stdenv.cross.config}-gcc -Wl,-dynamic-linker,$INTERPRETER -B${glibcCross}/lib \$(cat <<< \$@ | sed -e 's|-fstack-protector||g')" > $GCCBIN/${stdenv.cross.config}-gcc
      chmod +x $GCCBIN/${stdenv.cross.config}-gcc

      rm $GCCBIN/${stdenv.cross.config}-ld
      echo -e "#!${stdenv.shell} -x\n\
      ${gccCrossStageStatic}/bin/${stdenv.cross.config}-ld \$(cat <<< \$@ | sed -e 's|-fstack-protector||g')" > $GCCBIN/${stdenv.cross.config}-ld
      chmod +x $GCCBIN/${stdenv.cross.config}-ld

      export PATH=`echo $PATH | sed -e "s|${gccCrossStageStatic}/bin|$GCCBIN|g" -e "s|${stdenv.gcc}/bin||g"`
    '';

    #postInstall = ''
    #  INTERPRETER=`realpath ${glibcCross}/lib/ld-*.so`
    #  find $out -type f -exec patchelf --set-interpreter $INTERPRETER {} \;
    #'';

    passthru.libPrefix = "lib/perl5/site_perl";
  }
