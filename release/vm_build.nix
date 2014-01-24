{ nixpkgs, prefix, attrs_str ? "pkgs.nix pkgs.unzip" }:
let

  config = {
    nix = {
      storeDir = prefix+"/store";
      stateDir = prefix+"/state";
    };
  };
  pkgs = import nixpkgs { system = builtins.currentSystem; inherit config; };

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