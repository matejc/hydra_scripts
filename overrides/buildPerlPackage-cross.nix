stdenvCross: perl: perlCross: glibcCross: pkgs: busybox:

{ buildInputs ? [], ... } @ attrs:
let
  crossDrvs = list: map (i: if (i ? "crossDrv") then builtins.getAttr "crossDrv" i else i) list;
in
stdenvCross.mkDerivation (
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
    builder = "${pkgs.path}/pkgs/development/perl-modules/generic/builder.sh";
    buildInputs = (crossDrvs buildInputs) ++ [ perl ];
    makeMakerFlags = " LD=${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-ld ";
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
      ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-gcc -Wl,-dynamic-linker,$INTERPRETER \$(echo \$@ | sed -e 's|${perlCross.stdenv.gcc.libc}|${glibcCross}|g' -e 's|$PERLLIBDIR|$PERLCROSSLIBDIR|g')" > $GCCBIN/gcc
      chmod +x $GCCBIN/gcc
    '';
    
    postInstall = ''
      ${busybox}/bin/find $out -type f -exec sed -i -e 's|${perl}|${perlCross}|g' {} \;
    '';
  }
)
