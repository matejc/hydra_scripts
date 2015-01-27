{ nixpkgs, src }:
let
  pkgs = import nixpkgs { system = builtins.currentSystem; };
  inherit (pkgs) stdenv fetchgit nix makeDesktopItem writeScript;
  node_webkit = <src/node-webkit.nix>;
  nixui = (import <src/default.nix> { inherit pkgs; }).build;
  script = writeScript "nixui" ''
    #! ${stdenv.shell}
    export PATH="${nix}/bin:\$PATH"
    export NIXUI_CONFIG="${nixui}/lib/node_modules/nixui/src/config.json"
    ${node_webkit}/bin/nw ${nixui}/lib/node_modules/nixui/
  '';
  desktop = makeDesktopItem {
    name = "nixui";
    exec = script;
    icon = "${nixui}/lib/node_modules/nixui/img/128.png";
    desktopName = "NixUI";
    genericName = "NixUI";
  };

  jobs = {
    nixui = stdenv.mkDerivation rec {
      name = "nixui-dev";
      inherit src;
      installPhase = ''
        mkdir -p $out/bin
        ln -s ${script} $out/bin/nixui
      
        mkdir -p $out/share/applications
        ln -s ${desktop}/share/applications/* $out/share/applications/
      '';
    };
  };
in
  jobs
