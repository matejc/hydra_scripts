{ nixpkgs, hydra_scripts, prefix, system, attrs_str ? "pkgs.nix.crossDrv pkgs.bash.crossDrv", build_sshd ? "" }:
let

  platform = {
    name = "arm";
    kernelMajor = "3.7";
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
    withTLS = false;  # true;
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
      glibc = pkgs.lib.overrideDerivation (pkgs.glibc) (oldAttrs: {
        preConfigure = ''
          ${pkgsNoOverrides.findutils}/bin/find . -type f -iname "*.c" -exec sed -i -e 's|/etc/passwd|${etcDir}/passwd|g' {} \;
          ${pkgsNoOverrides.findutils}/bin/find . -type f -iname "*.c" -exec sed -i -e 's|/etc/group|${etcDir}/group|g' {} \;
          ${pkgsNoOverrides.findutils}/bin/find . -type f -iname "*.c" -exec sed -i -e 's|/etc/shadow|${etcDir}/shadow|g' {} \;
        '' + oldAttrs.preConfigure;
      });
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
    utillinux = pkgs.utillinux.crossDrv;
    coreutils = pkgs.coreutils.crossDrv;
    openssl = pkgs.openssl.crossDrv;
    environment = env;
    strace = pkgs.strace.crossDrv;
    };

  essentials = [pkgs.bash.crossDrv pkgs.coreutils.crossDrv];
  paths = parsed_attrs ++ essentials;

  env = pkgs.writeScriptBin "environment" ''
  #!${pkgs.bash.crossDrv}/bin/bash
  PATH="$out/bin:${pkgs.lib.makeSearchPath "bin" (map (a: a.outPath) paths)}"
  export PATH="$PATH:${pkgs.lib.makeSearchPath "sbin" (map (a: a.outPath) paths)}"
  export PS1=\$

  "$@"
  '';

  build = {
    vmEnvironment = pkgs.buildEnv {
      name = "vm-environment";
      paths = paths ++ [env] ++ (pkgs.lib.optionals (build_sshd == "1") [sshd]);
      pathsToLink = [ "/" ];
      ignoreCollisions = true;
    };
  };
in
  build
