perl: perlCross: glibc: glibcCross: pkgs: busybox:

{ buildInputs ? [], ... } @ attrs:
let
  crossDrvs = list: map (i: if (i ? "crossDrv") then builtins.getAttr "crossDrv" i else i) list;
in
perlCross.stdenv.mkDerivation (
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
      rm $GCCBIN/gcc
      echo -e "#!${pkgs.stdenv.shell} -x\n\
      ${pkgs.gccCrossStageStatic}/bin/gcc -Wl,-dynamic-linker,$INTERPRETER `echo '$@' | sed -e 's|${pkgs.stdenv.gcc.libc}|${glibcCross}|g'`" > $GCCBIN/gcc
      chmod +x $GCCBIN/gcc
    '';
  }
)
