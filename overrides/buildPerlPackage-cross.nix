stdenvCross: perl: perlCross: glibcCross: pkgs: busybox: bashCross: hydra_scripts:

{ buildInputs ? [], ... } @ attrs:
let
  crossDrvs = list: map (i: if (i ? "crossDrv") then builtins.getAttr "crossDrv" i else i) list;
  sedCrossDrvs = list: pkgs.lib.concatStringsSep " " (map (i: if (i ? "crossDrv") then (" -e 's|${i}|${builtins.getAttr "crossDrv" i}|g' ") else "") list);
  buildInputsOrg = buildInputs;
in
perl.stdenv.mkDerivation (
  {
    doCheck = false;

    # Prevent CPAN downloads.
    PERL_AUTOINSTALL = "--skipdeps";

    # From http://wiki.cpantesters.org/wiki/CPANAuthorNotes: "allows
    # authors to skip certain tests (or include certain tests) when
    # the results are not being monitored by a human being."
    AUTOMATED_TESTING = true;
  }
  //
  attrs
  //
  {
    name = "perl-cross-" + attrs.name;
    builder = "${hydra_scripts}/overrides/buildPerlPackage-builder.sh";
    buildInputs = buildInputs ++ [ perl ];
    makeMakerFlags = " LD=`pwd`/bin/ld ";
    preBuild = ''
      export GCCBIN=`pwd`/bin
      mkdir -p $GCCBIN
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-ar $GCCBIN/ar
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-as $GCCBIN/as
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-c++ $GCCBIN/c++
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-cpp $GCCBIN/cpp
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-f77 $GCCBIN/f77
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-gcc $GCCBIN/gcc
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-ld $GCCBIN/ld
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-nm $GCCBIN/nm
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-strip $GCCBIN/strip
      export PATH="$GCCBIN:$PATH"
      export INTERPRETER=`realpath ${glibcCross}/lib/ld-*.so`
      export PERLLIBDIR=`realpath ${perl}/lib/perl5/*/${pkgs.stdenv.system}-*/`
      export PERLCROSSLIBDIR=`realpath ${perlCross}/lib/perl5/*/*-*/`

      rm $GCCBIN/gcc
      echo -e "#!${pkgs.stdenv.shell} -x\n\
      ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-gcc -Wl,-dynamic-linker,$INTERPRETER \$(cat <<< \$@ | sed -e 's|-fstack-protector||g' -e 's|${perlCross.stdenv.gcc.libc}|${glibcCross}|g' ${sedCrossDrvs buildInputsOrg} -e 's|$PERLLIBDIR|$PERLCROSSLIBDIR|g') -lc $GCC_EXTRA_OPTIONS" > $GCCBIN/gcc
      chmod +x $GCCBIN/gcc

      rm $GCCBIN/ld
      echo -e "#!${pkgs.stdenv.shell} -x\n\
      ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-ld \$(cat <<< \$@ | sed -e 's|-fstack-protector||g' -e 's|-Wl,-Bsymbolic|-Bsymbolic|g' -e 's|${perlCross.stdenv.gcc.libc}|${glibcCross}|g' ${sedCrossDrvs buildInputsOrg} -e 's|$PERLLIBDIR|$PERLCROSSLIBDIR|g') -lc $LD_EXTRA_OPTIONS" > $GCCBIN/ld
      chmod +x $GCCBIN/ld

      #sed -i -e 's|-D_FILE_OFFSET_BITS=64||g' -e 's|-D_LARGEFILE64_SOURCE||g' -e 's|-D_LARGEFILE_SOURCE||g' ./Makefile
    '';
    
    postInstall = ''
      ${busybox}/bin/find $out -type f -exec sed -i -e 's|${perl}|${perlCross}|g' {} \;
      ${busybox}/bin/find $out -type f -exec sed -i -e 's|/bin/sh|${bashCross}/bin/bash|g' {} \;
    '';
  }
)
