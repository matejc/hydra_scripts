{ nixpkgs, src
, profilePaths ? (config.nixui.profilePaths or ["/nix/var/nix/profiles"])
, dataDir ? (config.nixui.dataDir or "/tmp")
, configurations ? (config.nixui.configurations or ["/etc/nixos/configuration.nix"])
, NIX_PATH ? (config.nixui.NIX_PATH or "/nix/var/nix/profiles/per-user/root/channels/nixos:nixpkgs=/etc/nixos/nixpkgs:nixos-config=/etc/nixos/configuration.nix") }:
let
  inherit (import nixpkgs { system = builtins.currentSystem; }) stdenv pkgs fetchgit nix makeDesktopItem writeScript;
  node_webkit = <src/node-webkit.nix>;
  nixui = (import <src/node-default.nix> { nixui = src; inherit pkgs; }).build;
  script = writeScript "nixui" ''
    #! ${stdenv.shell}
    export PATH="${nix}/bin:\$PATH"
    export NIXUI_CONFIG="${config}"
    ${node_webkit}/bin/nw ${nixui}/lib/node_modules/nixui/
  '';
  config = builtins.toFile "config.json" ''
  {
      "profilePaths": ${builtins.toJSON profilePaths},
      "dataDir": "${dataDir}",
      "configurations": ${builtins.toJSON configurations},
      "NIX_PATH": "${NIX_PATH}"
  }
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
