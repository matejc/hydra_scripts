{ nixpkgs
, supportedSystems ? [ "x86_64-linux" "i686-linux" ]
, package_name
, package_repo
, build_command ? "make all"
, dist_command ? "bin/pocompile ./src; bin/easy_install distribute; bin/python setup.py sdist --formats=bztar"
, check_command ? ""
, dist_path ? "./dist"
, docs_path ? "./docs/html"
, build_inputs ? [ "pkgs.python27" "pkgs.python27Packages.virtualenv" "pkgs.libxml2" "pkgs.libxslt" ]
, CFLAGS_COMPILE_SETS ? []
, LDFLAGS_SETS ? []
, do_lcov ? false
, cov_command ? ""
, source_files ? "*.tar.gz *.tgz *.tar.bz2 *.tbz2 *.tar.xz *.tar.lzma *.zip"
, binary_files ? "*.egg"
, name_command ? "bin/python setup.py --fullname"
}:

with import <nixpkgs/pkgs/top-level/release-lib.nix> { inherit supportedSystems; };

let
  removeFirst = (str: pkgs.lib.drop 1 (pkgs.lib.splitString "." str));
  nullPkgs = import <nixpkgs> { };
  nativePkgs = import <nixpkgs> { system = builtins.currentSystem; };
  genAttrs' = pkgs.lib.genAttrs supportedSystems;
  getSetFromStr = str: set: (pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." str) set);
  getImports = prefix: paths: set: map (item: prefix + (toString (getSetFromStr item.package set)) + item.path) paths;
  getSet = (n: value: pkgs.lib.listToAttrs [(pkgs.lib.nameValuePair (builtins.head (pkgs.lib.splitString "." n)) (pkgs.lib.setAttrByPath (removeFirst n) value))]);

  functions_sh = ''
    copy_and_reg() {
        mkdir -vp "$3"/nix-support/
        mkdir -vp "$3"/"$4"/
        while IFS=" " read -ra ADDR; do
            for ext in "''${ADDR[@]}"; do
                find "$2" -type f -maxdepth 1 -iname "$ext" -exec cp -v "{}" "$3"/"$4"/ \;
                find "$3"/"$4"/ -type f -maxdepth 1 -iname "$ext" -exec echo "file $5 {}" >> "$3"/nix-support/hydra-build-products \;
            done
        done <<< "$1"
    }
  '';

  jobs = {

    build = builtins.listToAttrs [(pkgs.lib.nameValuePair package_name (genAttrs' (system:
    let
      pkgs = import <nixpkgs> { inherit system; };
      ADD_CFLAGS_COMPILE = pkgs.lib.concatStringsSep " " (getImports "-I" CFLAGS_COMPILE_SETS pkgs);
      ADD_LDFLAGS = pkgs.lib.concatStringsSep " " (getImports "-L" LDFLAGS_SETS pkgs);
      parsed_buildins = (map (n: pkgs.lib.getAttrFromPath (pkgs.lib.splitString "." n) pkgs) build_inputs);
      build_env = pkgs.buildEnv {
        name = "build_env."+system;
        paths = parsed_buildins ++ [ pkgs.tree pkgs.gnused pkgs.gnumake pkgs.stdenv pkgs.binutils pkgs.findutils pkgs.coreutils pkgs.git pkgs.perl ];
        pathsToLink = [ "/" ];
        ignoreCollisions = true;
      };
    in pkgs.releaseTools.nixBuild ({
      name = package_name;
      src = <package_repo>;
      doCoverageAnalysis = do_lcov;
      dontBuild = false;
      buildInputs = [ build_env pkgs.cacert ];
      buildPhase = ''
        nixprofile=${build_env}
 
        export PATH="$nixprofile/bin"
        export LD_LIBRARY_PATH="$nixprofile/lib"
        export NIX_LDFLAGS="-L$nixprofile/lib ${ADD_LDFLAGS}"
        export NIX_CFLAGS_COMPILE="-I$nixprofile/include ${ADD_CFLAGS_COMPILE}"
        export PKG_CONFIG_PATH="$nixprofile/lib/pkgconfig"
        export PYTHONPATH="$nixprofile/lib/python2.7/site-packages"
 
        mkdir -p "./home-build"
        export HOME="./home-build"
 
        unset http_proxy
        unset ftp_proxy
        export OPENSSL_X509_CERT_FILE=${pkgs.cacert}/etc/ca-bundle.crt
        export GIT_SSL_CAINFO=${pkgs.cacert}/etc/ca-bundle.crt
 
        export C_INCLUDE_PATH="${build_env}/include:$C_INCLUDE_PATH"
        export INCLUDE="${build_env}/include:$INCLUDE"
        export LD_RUN_PATH="${build_env}/lib:$LD_RUN_PATH"
        export LIBRARY_PATH="${build_env}/lib:$LIBRARY_PATH"
        export LIB="${build_env}/lib:$LIB"
        export LDFLAGS=$NIX_LDFLAGS
        export CFLAGS=$NIX_CFLAGS_COMPILE
 
        ${build_command}
      '';
 
      doCheck = check_command != ""; 
      checkPhase = ''
        ${check_command}
      '';
 
      installPhase = ''
        mkdir -p $out
        #cp -vr ./ $out
      '';

      doDist = dist_command != "";
      distPhase = ''
        mkdir -p $out/tarballs/
        ${dist_command}

        ${functions_sh}
        copy_and_reg "${source_files}" "${dist_path}" "$out" "tarballs" "source-dist"
        copy_and_reg "${binary_files}" "${dist_path}" "$out" "tarballs" "binary-dist"

        # Try to figure out the release name.
        if [[ -n "${name_command}" ]]; then
          releaseName=$(${name_command})
        else
          releaseName=$( (cd $out/tarballs && ls) | head -n 1 | sed -e 's^\.[a-z].*^^')
        fi
        test -n "$releaseName" && (echo "$releaseName" >> $out/nix-support/hydra-release-name)

        if [[ -n "${docs_path}" ]]; then
          mkdir -p $out/manual/
          cp -rv ${docs_path}/* $out/manual/
          echo "doc manual $out/manual index.html" >> $out/nix-support/hydra-build-products
        fi
      '';

      postPhases = (if cov_command == "" then [] else ["customCoverageReportPhase"]);

      # In the report phase, create a coverage analysis report.
      customCoverageReportPhase = ''
        ${cov_command}
        mkdir $out/coverage
        cp -vr ./coverage/* $out/coverage
        # Grab the overall coverage percentage for use in release overviews.
        grep "<span class='pc_cov'>.*</span>" ./coverage/index.html | perl -pe 's|.*>(.*)%<.*|\1|' > $out/nix-support/coverage-rate
        echo "report coverage $out/coverage" >> $out/nix-support/hydra-build-products
      '';
    } // (if do_lcov then { lcov = pkgs.lcov; } else {})
    ))))];
  };
 
in jobs