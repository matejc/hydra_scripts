{ nixpkgs, src }:
let
  pkgs = import nixpkgs { system = builtins.currentSystem; };
  inherit (pkgs) stdenv fetchgit nix makeDesktopItem writeScript;
  node_webkit = <src/node-webkit.nix>;
  nixui = (import <src/default.nix> { inherit pkgs; }).build;

  jobs = {
    nixui = stdenv.mkDerivation {
      name = "nixui-dev";
      src = { outPath = src; name = "nixui-src"; };
      buildInputs = with pkgs; [ gnumake nix tightvnc ];
      configurePhase = ''
        export NIX_REMOTE=daemon
        export NIX_PATH="nixpkgs=${nixpkgs}"
      '';
      buildPhase = ''
        nix-build dispatcher.nix --argstr action package

        # this command runs the VNC server on screen :99
        vncserver :99

        # start your tests by setting DISPLAY env variable
        export DISPLAY=:99.0
        
        # check if it starts
        ${pkgs.busybox}/bin/timeout 5 ./result/bin/nixui

        # and then kill the VNC server
        vncserver -kill :99

        nix-shell dispatcher.nix --argstr action env --command "cd ./src && ../node_modules/.bin/mocha --reporter list"
      '';
      installPhase = ''
        mkdir -p $out/lib
        cp -r . $out/lib/nixui
      '';
    };
  };
in
  jobs
