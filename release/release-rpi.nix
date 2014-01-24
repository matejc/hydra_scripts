{ nixpkgs
, system ? builtins.currentSystem
, attrs ? [ "pkgs.pythonPackages.virtualenv" "pkgs.bash.crossDrv" ]
, supportedSystems ? [ ]
, nixList ? [ "nix.crossDrv" "openssl.crossDrv" "perl" ]
}:

with import <nixpkgs/pkgs/top-level/release-lib.nix> { inherit supportedSystems; };

let
  rpiCrossSystem = {
    config = "armv6l-unknown-linux-gnueabi";
    bigEndian = false;
    arch = "arm";
    float = "hard";
    fpu = "vfp";
    withTLS = true;
    libc = "glibc";
    platform = pkgsNoParams.platforms.raspberrypi;
    openssl.system = "linux-generic32";
    gcc = {
      arch = "armv6";
      fpu = "vfp";
      float = "softfp";
      abi = "aapcs-linux";
    };
  };
  pkgsFun = import <nixpkgs>;
  pkgsNoParams = pkgsFun {};
  pkgs = pkgsFun {
    crossSystem = rpiCrossSystem;
    config = pkgs: {
      packageOverrides = pkgs : {
        distccMasquerade = pkgs.distccMasquerade.override {
          gccRaw = pkgs.gccCrossStageFinal.gcc;
          binutils = pkgs.binutilsCross;
        };
      };
    };
  };

  removeFirst = (str: pkgs.lib.drop 1 (pkgs.lib.splitString "." str));
  zipSets = (list: pkgs.lib.zipAttrsWith (n: v: if builtins.tail v != [] then zipSets v else builtins.head v ) list);
  listOfBuildSets = (map (n: pkgs.lib.listToAttrs [(pkgs.lib.nameValuePair (builtins.head (pkgs.lib.splitString "." n)) (pkgs.lib.setAttrByPath (removeFirst n) pkgs.lib.platforms.mesaPlatforms))]) attrs);
  attrsByNames = names: set: pkgs.lib.listToAttrs (map (n: if builtins.hasAttr n set then pkgs.lib.nameValuePair n (builtins.getAttr n set) else (abort ("No attribute `"+n+"' in set!"))) names);
  tarballAttrs = (attrsByNames [ "src" "name" "nativeBuildInputs" "postUnpack" "configureFlags" "doInstallCheck" "makeFlags" "installFlags" ] pkgs.nix.crossDrv // { doCheck = false; buildInputs = pkgs.lib.attrValues { inherit (pkgs) curl openssl boehmgc sqlite bzip2; }; releaseName = pkgs.nix.crossDrv.name; });

  perlAttrs = (
    attrsByNames [ "name" "src" "patches" "configureFlags" "configureScript" "dontAddPrefix" "enableParallelBuilding" "preConfigure" "preBuild" "setupHook"  ] pkgs.perl // {
      doCheck = false;
      releaseName = pkgs.perl.name;
      libc = if pkgs.stdenv.gcc.libc or null != null then pkgs.stdenv.gcc.libc else "/usr";
      dontAddPrefix = "true";
    }
  );


  listOfNixBuildSets = (map (n: pkgs.lib.listToAttrs [(pkgs.lib.nameValuePair (builtins.head (pkgs.lib.splitString "." n)) (pkgs.lib.setAttrByPath (removeFirst n) pkgs.lib.platforms.mesaPlatforms))]) nixPkgsList);
  listOfNixSets = (list: set: (map (n: pkgs.lib.listToAttrs [(pkgs.lib.nameValuePair (builtins.head (pkgs.lib.splitString "." n)) (pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." n) set) )]) list));
  nixPkgsList = pkgs.lib.imap (i: v: ("pkgs."+v)) nixList;

  mapValues = f: set: (map (attr: f attr (builtins.getAttr attr set)) (builtins.attrNames set));
  recursiveCond = cond: f: set:
    let
      recurse = path: set:
        let
          g =
            name: value:
            if builtins.isAttrs value && cond path value
              then recurse (path ++ [name]) value
              else f (path ++ [name]) value;
        in mapValues g set;
    in recurse [] set;
  valuesOnLevel = level: set: if level == 0 then [set] else pkgs.lib.flatten (recursiveCond (path: value: (pkgs.lib.length path) < level - 1) (path: value: value) set);

  removePostfix = postfix: s:
      let
        postfixLen = pkgs.lib.stringLength postfix;
        sLen = pkgs.lib.stringLength s;
        prefixLen = pkgs.lib.sub sLen postfixLen;
      in
        if prefixLen >= 0 && postfix == pkgs.lib.substring prefixLen sLen s then
          pkgs.lib.substring 0 prefixLen s
        else
          s;
  removePostfixs = (postfix: list: (map (n: removePostfix postfix n) list));

  jobs = rec {
    build = (mapTestOnCross rpiCrossSystem (
      zipSets listOfBuildSets
    ));

/*
    nix_binary_tarball = pkgs.releaseTools.binaryTarball tarballAttrs;
    nix_source_tarball = pkgs.releaseTools.sourceTarball tarballAttrs;
    perl = pkgs.perl;
    perl_binary_tarball = pkgs.releaseTools.binaryTarball { src = jobs.perl.out; name = pkgs.perl.name; stdenv = pkgs.stdenv; doCheck = false; releaseName = pkgs.perl.name; installPhase = "mkdir -p $TMPDIR/inst; cp -r $TMPDIR/$name/* $TMPDIR/inst"; fixupPhase = "echo 'no need for fixup!'"; };


    nix_aggregate = pkgs.releaseTools.aggregate
        { name = "nix-aggregate";
          meta.description = "Release-Nix";
          constituents =
            [ pkgs.nix.crossDrv
            ];
        };
    nix_aggregate_binary_tarball = pkgs.releaseTools.binaryTarball { src = jobs.nix_aggregate; name = jobs.nix_aggregate.name; stdenv = pkgs.stdenv; doCheck = false; releaseName = jobs.nix_aggregate.name; installPhase = "ls -Rlah $TMPDIR; ls -Rlah $out; mkdir -p $TMPDIR/inst; cp -r $TMPDIR/$name/* $TMPDIR/inst"; };

    nix_env_binary_tarball = pkgs.releaseTools.binaryTarball {
      src = jobs.nix_env; name = jobs.nix_env.name; stdenv = pkgs.stdenv;
      doCheck = false; releaseName = jobs.nix_env.name; installPhase = "mkdir -p $TMPDIR/inst; cp -rL $TMPDIR/$name/* $TMPDIR/inst";
    };

    nix_env = pkgs.buildEnv {
      name = "nix_env";
      paths = [ pkgs.nix.crossDrv pkgs.glibc.crossDrv pkgs.openssl.crossDrv ];
      pathsToLink = [ "/" ];
      ignoreCollisions = true;
    };

    nix_rpi = (mapTestOnCross rpiCrossSystem (
      zipSets listOfNixBuildSets
    ));
    nix_rpi = (zipSets (listOfNixSets nixList pkgs));
*/

    nix_rpi = mapTestOnCross rpiCrossSystem {
      coreutils.crossDrv = linux;
      nixUnstable.crossDrv = linux;
      patch.crossDrv = linux;
      patchelf.crossDrv = linux;
      nix.crossDrv = linux;
      binutils.crossDrv = linux;
    };

    tarballs = let
      parsed_buildins = (map (n: pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." n) pkgs) nixList);
      nix_env = pkgs.buildEnv {
        name = "nix_env";
        paths = parsed_buildins;
        pathsToLink = [ "/" ];
        ignoreCollisions = true;
      };
    in pkgs.releaseTools.nixBuild {
      src = nix_env; name = "nix_tarballs"; stdenv = pkgs.stdenv;
      buildInputs = [ nix_env ];
      doCheck = false; releaseName = "nix_tarballs"; setSourceRoot = "mkdir -p $TMPDIR/nix_tarballs; sourceRoot='nix_tarballs'";
      buildPhase = ''
        mkdir -p $TMPDIR/inst; cp -r $TMPDIR/nix_env/* $TMPDIR/inst
        mkdir -p $out/tarballs
        tar cfj $out/tarballs/nix-rpi-binary-tarball.tar.bz2 -C / ${pkgs.lib.concatStringsSep " " parsed_buildins}
      '';
      installPhase = ''
        mkdir -p $out/nix-support

        tar cvfj $out/tarballs/''${releaseName:-binary-dist}.tar.bz2 -C $TMPDIR/inst .

        for i in $out/tarballs/*; do
            echo "file binary-dist $i" >> $out/nix-support/hydra-build-products
        done
        
        # Propagate the release name of the source tarball.  This is
        # to get nice package names in channels.
        test -n "$releaseName" && (echo "$releaseName" >> $out/nix-support/hydra-release-name)
      '';
    };
  };
in jobs