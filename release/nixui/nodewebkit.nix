{ nixpkgs, src, systems ? [ "i686-linux" "x86_64-linux" ] }:
let


  checkForSystem = system:
    let
      pkgs = import nixpkgs { inherit system; };
      nodewebkit = pkgs.callPackage <src/node-webkit.nix> { gconf = pkgs.gnome.GConf; };
    in nodewebkit

  checkForSystems = map (s: nameValuePair s (checkForSystem s)) systems;

  jobs = {
    builtins.listToAttrs checkForSystems;
  };
in
  jobs
