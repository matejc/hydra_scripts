{ pkgs, prefix }:
let
  hydraSrc = pkgs.fetchgit {
    url = https://github.com/NixOS/hydra;
    rev = "f5c04bfa497715e247707c4d1dcff42242565694";
    sha256 = "18x053x5im7dv86syw1v15729w5ywhrfw7v7psfwfn3fazzj2vcr"; # 8c748a6b5b24c118f24e6e13222ae28ab375bb1f225976f0f4b04f57c85b3bb2
  };

  crossDrvs = list: map (i: builtins.getAttr "crossDrv" i) list;

  genAttrs' = pkgs.lib.genAttrs [ "x86_64-linux" "armv7l-linux" ];

  tarball =
    with pkgs;

    releaseTools.makeSourceTarball rec {
      name = "hydra-tarball";
      src = hydraSrc;
      version = hydraSrc.rev;

      buildInputs =
        [ perl libxslt dblatex tetex nukeReferences pkgconfig boehmgc git openssl ];

      preHook = ''
        # TeX needs a writable font cache.
        export VARTEXFONTS=$TMPDIR/texfonts

        addToSearchPath PATH $(pwd)/src/script
        addToSearchPath PATH $(pwd)/src/c
        addToSearchPath PERL5LIB $(pwd)/src/lib
      '';

      configureFlags =
        [ "--with-nix=${nixUnstable}"
          "--with-docbook-xsl=${docbook_xsl}/xml/xsl/docbook"
        ];

      postDist = ''
        make -C doc/manual install prefix="$out"
        nuke-refs "$out/share/doc/hydra/manual.pdf"

        echo "doc manual $out/share/doc/hydra manual.html" >> \
          "$out/nix-support/hydra-build-products"
        echo "doc-pdf manual $out/share/doc/hydra/manual.pdf" >> \
          "$out/nix-support/hydra-build-products"
      '';
    };


  build = genAttrs' (system:

    with pkgs;

    let

      nix = nixUnstable;

      perlDeps = buildEnv {
        name = "hydra-perl-deps";
        paths = with perlPackages;
          crossDrvs [ ModulePluggable
            CatalystAuthenticationStoreDBIxClass
            CatalystDispatchTypeRegex
            CatalystPluginAccessLog
            CatalystPluginAuthorizationRoles
            CatalystPluginCaptcha
            CatalystPluginSessionStateCookie
            CatalystPluginSessionStoreFastMmap
            CatalystPluginStackTrace
            CatalystPluginUnicodeEncoding
            CatalystTraitForRequestProxyBase
            CatalystViewDownload
            CatalystViewJSON
            CatalystViewTT
            CatalystXScriptServerStarman
            CatalystActionREST
            CryptRandPasswd
            #DBDPg
            DBDSQLite
            DataDump
            DateTime
            DigestSHA1
            EmailSender
            FileSlurp
            LWP
            LWPProtocolHttps
            IOCompress
            IPCRun
            JSONXS
            PadWalker
            CatalystDevel
            Readonly
            SetScalar
            SQLSplitStatement
            Starman
            SysHostnameLong
            TestMore
            TextDiff
            TextTable
            XMLSimple
            NetAmazonS3
            nix git
          ];
      };

    in

    releaseTools.nixBuild {
      name = "hydra";
      src = tarball;
      configureFlags = "--with-nix=${nix}";

      buildInputs =
        [ makeWrapper libtool unzip nukeReferences pkgconfig boehmgc sqlite
          gitAndTools.topGit mercurial darcs subversion bazaar openssl bzip2
          #guile # optional, for Guile + Guix support
          perlDeps perl
        ];

      hydraPath = lib.makeSearchPath "bin" (
        crossDrvs [ libxslt sqlite subversion openssh nix coreutils findutils
          gzip bzip2 lzma gnutar unzip git gitAndTools.topGit mercurial darcs gnused graphviz bazaar
        ] /*++ lib.optionals stdenv.isLinux [ rpm dpkg cdrkit ]*/ );

      preCheck = ''
        patchShebangs .
        export LOGNAME=${LOGNAME:-foo}
      '';

      postInstall = ''
        mkdir -p $out/nix-support
        nuke-refs $out/share/doc/hydra/manual/manual.pdf

        for i in $out/bin/*; do
            wrapProgram $i \
                --prefix PERL5LIB ':' $out/libexec/hydra/lib:$PERL5LIB \
                --prefix PATH ':' $out/bin:$hydraPath \
                --set HYDRA_RELEASE ${tarball.version} \
                --set HYDRA_HOME $out/libexec/hydra \
                --set NIX_RELEASE ${nix.name}
        done
      ''; # */

      meta.description = "Build of Hydra on ${system}";
      passthru.perlDeps = perlDeps;
    });

in
  build
