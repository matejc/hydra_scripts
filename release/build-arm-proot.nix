{ nixpkgs, hydra_scripts, prefix, system, attrs_str ? "pkgs.nix pkgs.bash", build_sshd ? "", replaceme_url ? "", build_hydra ? "" }:
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
    #crossSystem = crosssystem;
    inherit config;
  };

  config_nix = {
    storeDir = prefix+"/store";
    stateDir = prefix+"/var/nix";
  };

  pkgsNoOverrides = import nixpkgs {
    #crossSystem = crosssystem;
    config = { nix = config_nix; };
  };

  etcDir = "${prefix}/etc";

  config = {
    nix = config_nix;
    packageOverrides = pkgs : rec {
    };
  };

  parsed_attrs = (map (n: pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." n) pkgs) (pkgs.lib.splitString " " attrs_str));

  sshd = import "${hydra_scripts}/release/sshd.nix" {
    inherit pkgs prefix;
    bash = pkgs.bash;
    openssh = pkgs.openssh;
    busybox = pkgs.busybox;
    openssl = pkgs.openssl;
    shell = "${mybash}/bin/mybash";
    strace = pkgs.strace;
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

  essentials = [pkgs.bashInteractive pkgs.busybox];
  paths = parsed_attrs ++ essentials;

  mybash = pkgs.writeScriptBin "mybash" ''
  #!${pkgs.bashInteractive}/bin/bash
  cd /
  ${pkgs.bashInteractive}/bin/bash --rcfile ${bashrc} "$@"
  '';
  bashrc = pkgs.writeText "bashrc" ''
  ${pkgs.busybox}/bin/busybox tty -s
  if [ $? -ne 0 ]; then return; fi

  PATH="${pkgs.lib.makeSearchPath "bin" (map (a: a.outPath) paths)}"
  export PATH="$PATH:${pkgs.lib.makeSearchPath "sbin" (map (a: a.outPath) paths)}"
  export PS1="\$(pwd) $ "
  export TMPDIR="${prefix}/tmp"
  export NIX_CURL_FLAGS="--dns-servers 8.8.4.4,4.4.4.4"
  '';

  build = {
    vmEnvironment = pkgs.buildEnv {
      name = "outenv-arm";
      paths = paths ++ [mybash] ++ (pkgs.lib.optionals (build_hydra == "1") [hydra]) ++ (pkgs.lib.optionals (build_sshd == "1") [sshd]) ++ (pkgs.lib.optionals (replaceme_url != "") [replaceme]);
      pathsToLink = [ "/" ];
      ignoreCollisions = true;
    };
  };
in
  build
