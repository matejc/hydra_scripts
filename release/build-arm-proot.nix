{ nixpkgs, hydra_scripts, prefix, system, attrs_str ? "pkgs.nix.crossDrv pkgs.bash.crossDrv", build_sshd ? "", replaceme_url ? "", build_hydra ? "" }:
let

  platform = {
    name = "arm";
    kernelMajor = "2.6";
    kernelHeadersBaseConfig = "kirkwood_defconfig";
    kernelBaseConfig = "bcmrpi_defconfig";
    kernelArch = "arm";
    kernelAutoModules = false;
    kernelExtraConfig =
      ''
        BLK_DEV_RAM y
        BLK_DEV_INITRD y
        BLK_DEV_CRYPTOLOOP m
        BLK_DEV_DM m
        DM_CRYPT m
        MD y
        REISERFS_FS m
        BTRFS_FS y
        XFS_FS m
        JFS_FS y
        EXT4_FS y

        IP_PNP y
        IP_PNP_DHCP y
        NFS_FS y
        ROOT_NFS y
        TUN m
        NFS_V4 y
        NFS_V4_1 y
        NFS_FSCACHE y
        NFSD m
        NFSD_V2_ACL y
        NFSD_V3 y
        NFSD_V3_ACL y
        NFSD_V4 y
        NETFILTER y
        IP_NF_IPTABLES y
        IP_NF_FILTER y
        IP_NF_MATCH_ADDRTYPE y
        IP_NF_TARGET_LOG y
        IP_NF_MANGLE y
        IPV6 m
        VLAN_8021Q m

        CIFS y
        CIFS_XATTR y
        CIFS_POSIX y
        CIFS_FSCACHE y
        CIFS_ACL y

        ZRAM m

        # Fail to build
        DRM n
        SCSI_ADVANSYS n
        USB_ISP1362_HCD n
        SND_SOC n
        SND_ALI5451 n
        FB_SAVAGE n
        SCSI_NSP32 n
        ATA_SFF n
        SUNGEM n
        IRDA n
        ATM_HE n
        SCSI_ACARD n
        BLK_DEV_CMD640_ENHANCED n

        FUSE_FS m

        # nixos mounts some cgroup
        CGROUPS y

        # Latencytop 
        LATENCYTOP y
      '';
    kernelTarget = "zImage";
    uboot = null;
    gcc = {
      arch = "armv6";
      fpu = "vfp";
      float = "hard";
    };
  };

  crosssystem = {
    config = "armv6l-unknown-linux-gnueabi";
    bigEndian = false;
    arch = "arm";
    float = "hard";
    fpu = "vfp";
    withTLS = true;
    libc = "glibc";
    platform = platform;
    openssl.system = "linux-generic32";
    gcc = {
      arch = "armv6";
      fpu = "vfp";
      float = "softfp";
      abi = "aapcs-linux";
    };
  };

  pkgs = import nixpkgs {
    crossSystem = crosssystem;
    inherit config;
  };

  config_nix = {
    storeDir = prefix+"/store";
    stateDir = prefix+"/var/nix";
  };

  pkgsHost = import nixpkgs {};

  etcDir = "${prefix}/etc";

  config = {
    nix = config_nix;
    packageOverrides = pkgs : rec {
      binutils_xcompile = pkgs.callPackage ../overrides/binutils-xcompile.nix { gold = false; };
      #binutils = pkgs.binutils_nogold;
      #binutilsCross = pkgs.lib.overrideDerivation pkgs.binutilsCross (oldAttrs: { gold = false; });
      binutilsCross = (pkgs.forceNativeDrv (import "${pkgs.path}/pkgs/development/tools/misc/binutils" {
        inherit (pkgs) stdenv fetchurl zlib;
        noSysDirs = true;
        gold = false;
        cross = crosssystem;
      }));
      #perl_xcompile = pkgs.callPackage ../overrides/perl-cross.nix { inherit prefix glibcCross; binutils = binutils_xcompile; };
      perlCross = pkgs.forceNativeDrv (pkgs.callPackage ../overrides/perl-cross.nix { inherit prefix glibcCross busybox; bashCross = pkgs.bash.crossDrv; });
      buildPerlCrossPackage = import ../overrides/buildPerlPackage-cross.nix (pkgs.makeStdenvCross pkgs.stdenv crosssystem binutilsCross pkgs.gccCrossStageStatic) pkgs.perl520 perlCross glibcCross pkgs busybox pkgs.bash.crossDrv hydra_scripts;
      perlCrossPackages = import "${pkgs.path}/pkgs/top-level/perl-packages.nix" {
        pkgs = pkgs // {
          perl = pkgs.perl520;
          buildPerlPackage = buildPerlCrossPackage;
        };
        overrides = (p: rec {
          DBDSQLite = pkgs.lib.overrideDerivation (import "${pkgs.path}/pkgs/development/perl-modules/DBD-SQLite" {
            inherit (p) stdenv fetchurl;
            buildPerlPackage = buildPerlCrossPackage;
            DBI = DBI1631;
            inherit (p) sqlite;
          }) (oldAttrs: {
            preConfigure = ''
              sed -i -e "s|^.*DBI 1.57.*$|print \$@;|g" ./Makefile.PL
              export PERL5LIB_ORIG=$PERL5LIB
              export PERL5LIB="$(dirname `realpath ${perl520Packages.DBI}/lib/perl5/site_perl/*/*/DBI.pm`)";
            '';
            #GCC_EXTRA_OPTIONS = "-DSQLITE_DISABLE_LFS";
            postConfigure = ''
              export PERL5LIB=$PERL5LIB_ORIG
            '';
          });
          DBI157 = buildPerlCrossPackage {
            name = "DBI-1.57";
            src = p.fetchurl {
              url = mirror://cpan/authors/id/T/TI/TIMB/DBI-1.57.tar.gz;
              sha256 = "1bi78b7zcrfckmk9x396mhwqw2a10xqcznslqw1np7nh5zn9ll7c";
            };
            preConfigure = ''
              sed -i -e 's|$(PERL) dbixs_rev.pl|echo|g' ./Makefile.PL
            '';
          };
          DBI1631 = buildPerlCrossPackage {
            name = "DBI-1.631";
            src = pkgs.fetchurl {
              url = mirror://cpan/authors/id/T/TI/TIMB/DBI-1.631.tar.gz;
              sha256 = "04fmrnchhwi7jx4niaiv93vmi343hdm3xj04w9zr2m9hhqh782np";
            };
          };
          /*
          WWWCurlCross = buildPerlCrossPackage rec {
            name = "WWW-Curl-4.17";
            src = pkgs.fetchurl {
              url = "mirror://cpan/authors/id/S/SZ/SZBALINT/${name}.tar.gz";
              sha256 = "1fmp9aib1kaps9vhs4dwxn7b15kgnlz9f714bxvqsd1j1q8spzsj";
            };
            buildInputs = [ curlCross ];
            preConfigure =
              ''
                substituteInPlace Makefile.PL --replace '"cpp"' '"gcc -E"'
              '';
            doCheck = false; # performs network access
          };
          */
        }) pkgs;
      };
      curlCross = pkgs.forceNativeDrv (pkgs.lib.overrideDerivation (pkgs.curl.override {
        zlibSupport = true;
        sslSupport = true;
        scpSupport = true;
        c-aresSupport = true;
      }).crossDrv (oldAttrs: {
        configureFlags = [ "--with-libssh2=${pkgs.libssh2.crossDrv}" "--with-ssl=${pkgs.openssl.crossDrv}" "--enable-ares=${pkgs.c-ares.crossDrv}" ];
        #postInstall = ''
        #  source "${pkgs.makeWrapper}/nix-support/setup-hook"
        #  wrapProgram $out/bin/curl --add-flags "--dns-servers 8.8.4.4,4.4.4.4"
        #'';
      }));
      perl520Packages = import "${pkgs.path}/pkgs/top-level/perl-packages.nix" {
        pkgs = pkgs // {
          perl = pkgs.perl520;
          buildPerlPackage = import "${pkgs.path}/pkgs/development/perl-modules/generic" pkgs.perl520;
        };
        overrides = (p: {}) pkgs;
      };
      #sqlite.crossDrv = pkgs.lib.overrideDerivation pkgs.sqlite.crossDrv (oldAttrs: {
      #  CFLAGS = oldAttrs.CFLAGS + " -DSQLITE_DISABLE_LFS ";
      #});
      #perlDBICross = (pkgs.makeOverridable (pkgs.makeStdenvCross pkgs.stdenv crosssystem binutilsCross pkgs.gccCrossStageFinal).mkDerivation (pkgs.perlPackages.DBI));
      #perlDBDSQLiteCross = (pkgs.makeOverridable (pkgs.makeStdenvCross pkgs.stdenv crosssystem binutilsCross pkgs.gccCrossStageFinal).mkDerivation (pkgs.perlPackages.DBDSQLite));
      #perlWWWCurlCross = (pkgs.makeOverridable (pkgs.makeStdenvCross pkgs.stdenv crosssystem binutilsCross pkgs.gccCrossStageFinal).mkDerivation (pkgs.perlPackages.WWWCurl));
      nix.crossDrv = pkgs.lib.overrideDerivation (pkgs.nix.override { perl = pkgs.perl520; perlPackages = perl520Packages; }).crossDrv (oldAttrs: {
        buildInputs = [ curlCross pkgs.openssl.crossDrv pkgs.boehmgc.crossDrv pkgs.sqlite.crossDrv ];
        preConfigure = ''
          ${pkgsHost.findutils}/bin/find . -type f \( -iname "*.cc" -or -iname "*.in" -or -iname "*.nix" \) -exec sed -i -e '/^\s*#/! s|"/bin/sh"|"${pkgs.bash.crossDrv}/bin/bash"|g' {} \;
        '';
        postInstall = ''
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|shell =.*;|shell = "${pkgs.bash.crossDrv}/bin/bash";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|tr =.*;|tr = "${coreutils.crossDrv}/bin/tr";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|coreutils =.*;|coreutils = "${coreutils.crossDrv}/bin";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|bzip2 =.*;|bzip2 = "${pkgs.bzip2.crossDrv}/bin/bzip2";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|gzip =.*;|gzip = "${pkgs.gzip.crossDrv}/bin/gzip";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|xz =.*;|xz = "${pkgs.xz.crossDrv}/bin/xz";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|tar =.*;|tar = "${pkgs.gnutar.crossDrv}/bin/tar";|' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -iname "config.nix" -exec sed -i -e 's|curl =.*;|curl = "${curlCross}/bin/curl";|' {} \;

          ${pkgsHost.findutils}/bin/find $out -type f -exec sed -i -e '/^\s*#/ s|/bin/sh|${pkgs.bash.crossDrv}/bin/bash|g' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -exec sed -i -e 's|${pkgs.perl520}|${perlCross}|g' {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -exec sed -i -e "s|${perl520Packages.DBI}/${pkgs.perl520.libPrefix}|`realpath ${perlCrossPackages.DBI}/${perlCross.libPrefix}/*/*/`|g" {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -exec sed -i -e "s|${perl520Packages.DBDSQLite}/${pkgs.perl520.libPrefix}|`realpath ${perlCrossPackages.DBDSQLite}/${perlCross.libPrefix}/*/*/`|g" {} \;
          ${pkgsHost.findutils}/bin/find $out -type f -exec sed -i -e "s|${perl520Packages.WWWCurl}/${pkgs.perl520.libPrefix}|`realpath ${perlCrossPackages.WWWCurl}/${perlCross.libPrefix}/*/*/`|g" {} \;
          
          #${pkgsHost.findutils}/bin/find $out -type f -not -name "nix-prefetch-url" -exec sed -i -e 's|$Nix::Config::curl|$Nix::Config::curl --dns-servers 8.8.4.4,4.4.4.4|g' {} \;

          source "${pkgs.makeWrapper}/nix-support/setup-hook"
          wrapProgram $out/bin/nix-prefetch-url --set NIX_CURL_FLAGS "\"--dns-servers 8.8.4.4,4.4.4.4\""

          ${pkgsHost.findutils}/bin/find $out -type f -name "fetchurl.nix" -exec sed -i -e 's|[\$]{curl}|${curlCross}/bin/curl --dns-servers 8.8.4.4,4.4.4.4|g' {} \;
        '';
      });
      bashInteractive = pkgs.bashInteractive.override { interactive = true; readline = pkgs.readline; };
      python27 = pkgs.callPackage ../overrides/python-xcompile.nix { inherit hydra_scripts; };
      bison3 = pkgs.callPackage ../overrides/bison3-xcompile.nix { };
      pam = pkgs.callPackage ../overrides/pam-xcompile.nix { inherit etcDir; findutils = pkgsHost.findutils; };
      #nodejs = pkgs.callPackage ../overrides/nodejs-xcompile.nix { };
      openssh = pkgs.lib.overrideDerivation (pkgs.openssh.override { pam = null; }) (oldAttrs: {
        preConfigure = ''
          #${pkgsHost.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/pam|${etcDir}/pam|g' {} \;
          ${pkgsHost.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/passwd|${etcDir}/passwd|g' {} \;
          ${pkgsHost.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/group|${etcDir}/group|g' {} \;
          ${pkgsHost.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/shadow|${etcDir}/shadow|g' {} \;
        '' + oldAttrs.preConfigure;
      });
      glibcCross = pkgs.forceNativeDrv (pkgs.makeOverridable (import ../overrides/glibc-xcompile.nix)
        (let crossGNU = crosssystem != null && crosssystem.config == "i586-pc-gnu";
         in {
           inherit (pkgs) stdenv fetchurl;
           gccCross = pkgs.gccCrossStageStatic;
           kernelHeaders = if crossGNU then pkgs.gnu.hurdHeaders else pkgs.linuxHeadersCross;
           installLocales = pkgs.config.glibc.locales or false;
         }
         // pkgs.lib.optionalAttrs crossGNU {
            inherit (pkgs.gnu) machHeaders hurdHeaders libpthreadHeaders mig;
            inherit (pkgs) fetchgit;
          } // {inherit pkgs etcDir;}));
      glibc = pkgs.callPackage ../overrides/glibc-xcompile.nix {
        kernelHeaders = pkgs.linuxHeaders;
        installLocales = pkgs.config.glibc.locales or false;
        machHeaders = null;
        hurdHeaders = null;
        gccCross = null;
        inherit pkgs etcDir;
      };
      #shadow =  pkgs.callPackage ../overrides/shadow-xcompile.nix { inherit pam; glibcCross = pkgs.glibcCross; inherit etcDir; };
      coreutils = pkgs.callPackage ../overrides/coreutils-xcompile.nix { inherit etcDir; };
      busybox = pkgs.callPackage ../overrides/busybox-xcompile.nix { inherit etcDir; findutils = pkgsHost.findutils; };
      apr = pkgs.lib.overrideDerivation (pkgs.apr) (oldAttrs: {
        configureFlags = [ "ac_cv_file__dev_zero=yes" "ac_cv_func_setpgrp_void=yes" ] ++ oldAttrs.configureFlags;
      });
      #libxslt.crossDrv = pkgs.lib.overrideDerivation pkgs.libxslt.crossDrv {
      #  configureFlags = "--with-libxml-prefix=${pkgs.libxml2.crossDrv} --without-python --without-crypto --without-debug --without-mem-debug --without-debugger";
      #};
      tmux = pkgs.lib.overrideDerivation pkgs.tmux (oldAttrs: {
        postInstall = oldAttrs.postInstall + ''
          source "${pkgs.makeWrapper}/nix-support/setup-hook"
          wrapProgram $out/bin/tmux --set TMUX_TMPDIR "${prefix}/tmp"
        '';
      });
      /*gitCross = pkgs.lib.overrideDerivation ((pkgs.lib.makeOverridable (import "${pkgs.path}/pkgs/applications/version-management/git-and-tools/git") {
        inherit (pkgs) fetchurl stdenv curl openssl zlib expat gettext gnugrep
          asciidoc xmlto docbook2x docbook_xsl docbook_xml_dtd_45 libxslt cpio tcl
          tk makeWrapper gzip subversionClient;
        python = python27;
        perl = pkgs.perl520;
        texinfo = pkgs.texinfo5;
        withManual = true;
        svnSupport = false;		# for git-svn support
        guiSupport = false;		# requires tcl/tk
        sendEmailSupport = false;	# requires plenty of perl libraries
        pythonSupport = false;
        perlLibs = with perlCrossPackages; [perlPackages.LWP perlPackages.URI perlPackages.TermReadKey];
        smtpPerlLibs = [ ];
      }).crossDrv) (oldAttrs: {
        #nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.asciidoc pkgs.xmlto ];
        postInstall = oldAttrs.postInstall + ''
          ${pkgsHost.findutils}/bin/find $out -type f -exec sed -i -e 's|${pkgs.perl520}|${perlCross}|g' {} \;
        '';
      });*/
      gnugrep = pkgs.gnugrep.override { doCheck = false; };
    };
  };

  parsed_attrs = (map (n: pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." n) pkgs) (pkgs.lib.splitString " " attrs_str));

  sshd = import "${hydra_scripts}/release/sshd.nix" {
    inherit pkgs prefix;
    bash = pkgs.bash.crossDrv;
    openssh = pkgs.openssh.crossDrv;
    busybox = pkgs.busybox.crossDrv;
    openssl = pkgs.openssl.crossDrv;
    shell = "${mybash}/bin/mybash";
    strace = pkgs.strace.crossDrv;
    };

  replaceme = import "${hydra_scripts}/release/replaceme.nix" {
    inherit pkgs prefix;
    url = replaceme_url;
    resultPath = "${prefix}/result/bin";
    systemPath = "/system/bin";
    shell = "/system/bin/sh";
    };

  hydra = (import "${hydra_scripts}/release/hydra.nix" {
    inherit pkgs prefix;
    }).armv7l-linux;

  essentials = [pkgs.bashInteractive.crossDrv pkgs.busybox.crossDrv];
  paths = parsed_attrs ++ essentials;

  mybash = pkgs.writeScriptBin "mybash" ''
  #!${pkgs.bashInteractive.crossDrv}/bin/bash
  cd /
  ${pkgs.bashInteractive.crossDrv}/bin/bash --rcfile ${bashrc} "$@"
  '';
  bashrc = pkgs.writeText "bashrc" ''
  ${pkgs.busybox.crossDrv}/bin/busybox tty -s
  if [ $? -ne 0 ]; then return; fi

  PATH="${pkgs.lib.makeSearchPath "bin" (map (a: a.outPath) paths)}"
  export PATH="$PATH:${pkgs.lib.makeSearchPath "sbin" (map (a: a.outPath) paths)}"
  export PS1="\$(pwd) $ "
  export TMPDIR="${prefix}/tmp"
  export NIX_CURL_FLAGS="--dns-servers 8.8.4.4,4.4.4.4"
  '';

  build = {
    vmEnvironment = pkgs.buildEnv {
      name = "outenv-${pkgs.stdenv.cross.config}";
      paths = paths ++ [mybash] ++ (pkgs.lib.optionals (build_hydra == "1") [hydra]) ++ (pkgs.lib.optionals (build_sshd == "1") [sshd]) ++ (pkgs.lib.optionals (replaceme_url != "") [replaceme]);
      pathsToLink = [ "/" ];
      ignoreCollisions = true;
    };
  };
in
  build
