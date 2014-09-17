perl: perlCross: pkgs:

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
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-ar $GCCBIN/bin/ar
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-as $GCCBIN/bin/as
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-c++ $GCCBIN/bin/c++
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-cpp $GCCBIN/bin/cpp
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-f77 $GCCBIN/bin/f77
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-gcc $GCCBIN/bin/gcc
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-ld $GCCBIN/bin/ld
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-nm $GCCBIN/bin/nm
      ln -sv ${pkgs.gccCrossStageStatic}/bin/${pkgs.stdenv.cross.config}-strip $GCCBIN/bin/strip
      export PATH="$GCCBIN:$PATH"
    '';
  }
)
