{ nixpkgs, prefix, system, attrs_str ? "pkgs.nix pkgs.bash" }:
let

  config = {
    nix = {
      storeDir = prefix+"/store";
      stateDir = prefix+"/state";
    };
  };
  pkgs = import nixpkgs { inherit system config; };

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
