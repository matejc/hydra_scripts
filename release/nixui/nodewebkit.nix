{ nixpkgs, src }:
let
  pkgs32 = import nixpkgs { system = "i686-linux"; };
  pkgs64 = import nixpkgs { system = "x86_64-linux"; };

  jobs = {
    nodewebkit32 = pkgs32.callPackage <src/node-webkit.nix> { gconf = pkgs32.gnome.GConf; };
    nodewebkit64 = pkgs64.callPackage <src/node-webkit.nix> { gconf = pkgs64.gnome.GConf; };
  };
in
  jobs
