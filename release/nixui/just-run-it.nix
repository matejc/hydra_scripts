{ nixpkgs, src }:
let
  pkgs = import nixpkgs { system = builtins.currentSystem; };
  inherit (pkgs) stdenv fetchgit nix makeDesktopItem writeScript;
  node_webkit = <src/node-webkit.nix>;
  nixui = (import <src/default.nix> { inherit pkgs; }).build;
  script = writeScript "nixui" ''
    #! ${stdenv.shell}
    export PATH="${nix}/bin:\$PATH"
    ${node_webkit}/bin/nw ${nixui}/lib/node_modules/nixui/
  '';

  jobs = {
    nixui = stdenv.mkDerivation rec {
      name = "nixui-dev";
      inherit src;
      buildInputs = with pkgs; [ gnumake nix ];
      buildPhase = ''
        make just-run-it
      '';
      checkPhase = ''
        make test
      '';
      installPhase = ''
        mkdir -p $out/bin
        ln -s ${script} $out/bin/nixui
      '';
    };
  };
in
  jobs
