{ nixpkgs, hydra_scripts, prefix, system, attrs_str ? "pkgs.nix.crossDrv pkgs.bash.crossDrv", build_sshd ? "", replaceme_url ? "" }:
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

  pkgsNoOverrides = import nixpkgs {
    crossSystem = crosssystem;
    config = { nix = config_nix; };
  };

  etcDir = "${prefix}/etc";

  config = {
    nix = config_nix;
    packageOverrides = pkgs : rec {
      python27 = pkgs.callPackage ../overrides/python-xcompile.nix { inherit hydra_scripts; };
      bison3 = pkgs.callPackage ../overrides/bison3-xcompile.nix { };
      pam = pkgs.callPackage ../overrides/pam-xcompile.nix { inherit etcDir; findutils = pkgsNoOverrides.findutils; };
      #nodejs = pkgs.callPackage ../overrides/nodejs-xcompile.nix { };
      openssh = pkgs.lib.overrideDerivation (pkgs.openssh.override { inherit pam; }) (oldAttrs: {
        preConfigure = ''
          ${pkgsNoOverrides.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/pam|${etcDir}/pam|g' {} \;
          ${pkgsNoOverrides.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/passwd|${etcDir}/passwd|g' {} \;
          ${pkgsNoOverrides.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/group|${etcDir}/group|g' {} \;
          ${pkgsNoOverrides.findutils}/bin/find . -type f -exec sed -i -e 's|/etc/shadow|${etcDir}/shadow|g' {} \;
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
      busybox = pkgs.callPackage ../overrides/busybox-xcompile.nix { inherit etcDir; findutils = pkgsNoOverrides.findutils; };
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
    };

  essentials = [pkgs.bash.crossDrv pkgs.busybox.crossDrv];
  paths = parsed_attrs ++ essentials;

  mybash = pkgs.writeScriptBin "mybash" ''
  #!${pkgs.bash.crossDrv}/bin/bash
  ${pkgs.bash.crossDrv}/bin/bash --rcfile ${bashrc} $@
  '';
  inputrc = pkgs.writeText "inputrc" ''
  # /etc/inputrc - global inputrc for libreadline
  # See readline(3readline) and `info rluserman' for more information.

  # Be 8 bit clean.
  set input-meta on
  set output-meta on

  # To allow the use of 8bit-characters like the german umlauts, comment out
  # the line below. However this makes the meta key not work as a meta key,
  # which is annoying to those which don't need to type in 8-bit characters.

  # set convert-meta off

  # try to enable the application keypad when it is called.  Some systems
  # need this to enable the arrow keys.
  # set enable-keypad on

  # see /usr/share/doc/bash/inputrc.arrows for other codes of arrow keys

  # do not bell on tab-completion
  # set bell-style none
  # set bell-style visible

  # some defaults / modifications for the emacs mode
  $if mode=emacs

  # allow the use of the Home/End keys
  "\e[1~": beginning-of-line
  "\e[4~": end-of-line

  # allow the use of the Delete/Insert keys
  "\e[3~": delete-char
  "\e[2~": quoted-insert

  # mappings for "page up" and "page down" to step to the beginning/end
  # of the history
  # "\e[5~": beginning-of-history
  # "\e[6~": end-of-history

  # alternate mappings for "page up" and "page down" to search the history
  # "\e[5~": history-search-backward
  # "\e[6~": history-search-forward

  # mappings for Ctrl-left-arrow and Ctrl-right-arrow for word moving
  "\e[1;5C": forward-word
  "\e[1;5D": backward-word
  "\e[5C": forward-word
  "\e[5D": backward-word
  "\e\e[C": forward-word
  "\e\e[D": backward-word

  $if term=rxvt
  "\e[8~": end-of-line
  "\eOc": forward-word
  "\eOd": backward-word
  $endif

  # for non RH/Debian xterm, can't hurt for RH/Debian xterm
  # "\eOH": beginning-of-line
  # "\eOF": end-of-line

  # for freebsd console
  # "\e[H": beginning-of-line
  # "\e[F": end-of-line

  $endif
  '';
  bashrc = pkgs.writeText "bashrc" ''
  if [[ ! $- =~ "i" ]]; then return; fi
  export INPUTRC=${inputrc}
  PATH="${pkgs.lib.makeSearchPath "bin" (map (a: a.outPath) paths)}"
  export PATH="$PATH:${pkgs.lib.makeSearchPath "sbin" (map (a: a.outPath) paths)}"
  export PS1="\$ "
  '';

  build = {
    vmEnvironment = pkgs.buildEnv {
      name = "vm-environment";
      paths = paths ++ [mybash] ++ (pkgs.lib.optionals (build_sshd == "1") [sshd]) ++ (pkgs.lib.optionals (replaceme_url != "") [replaceme]);
      pathsToLink = [ "/" ];
      ignoreCollisions = true;
    };
  };
in
  build
