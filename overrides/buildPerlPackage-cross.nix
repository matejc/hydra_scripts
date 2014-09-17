perl, perlCross, pkgs:

{ buildInputs ? [], ... } @ attrs:

perlCross.stdenv.mkDerivation (
  {
    doCheck = true;
    
    checkTarget = "test";
    
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
    name = "perl-" + attrs.name;
    builder = "${pkgs.path}/pkgs/development/perl-modules/generic/builder.sh";
    buildInputs = buildInputs ++ [ perl ];
  }
)
