{ nixpkgs, src, systems ? [ "i686-linux" "x86_64-linux" ] }:
let
  pkgs = import nixpkgs { system = builtins.currentSystem; };

  checkForSystem = s:
    let
      p = import nixpkgs { system = s; };
      nodewebkit = p.callPackage <src/node-webkit.nix> { gconf = p.gnome.GConf; };
    in
      nodewebkit;

  checkForSystems = map (s: pkgs.lib.nameValuePair s (checkForSystem s)) systems;

  jobs = builtins.listToAttrs checkForSystems;
in
  jobs
