{ nixpkgs, hydra_scripts, prefix, system, attrs_str ? "pkgs.nix.crossDrv pkgs.bash.crossDrv" }:
let

  platform = {
    name = "mk902";
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

  config = {
    nix = {
      storeDir = prefix+"/store";
      stateDir = prefix+"/var/nix";
    };
    packageOverrides = pkgs : {
      python27 = pkgs.stdenv.lib.overrideDerivation pkgs.python27 (oldAttrs : rec{
        configureFlags = oldAttrs.configureFlags + " --disable-ipv6 ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no ac_cv_have_long_long_format=yes";
        version = "2.7.5";
        src = pkgs.fetchurl {
          url = "http://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
          sha256 = "1c8xan2dlsqfq8q82r3mhl72v3knq3qyn71fjq89xikx2smlqg7k";
        };
        preConfigure = ''
          ./configure
          make --jobs=1 python Parser/pgen
          mv python python_for_build
          mv Parser/pgen Parser/pgen_for_build
          patch -p3 < "${hydra_scripts}/patches/Python-2.7.5-xcompile.patch"
        '';
      });
    };
  };

  parsed_attrs = (map (n: pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." n) pkgs) (pkgs.lib.splitString " " attrs_str));

  build = {
    vmEnvironment = pkgs.buildEnv {
      name = "vm-environment";
      paths = parsed_attrs;
      pathsToLink = [ "/" ];
      ignoreCollisions = true;
    };
  };
in
  build
