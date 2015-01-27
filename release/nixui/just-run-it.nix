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
        export DISPLAY=:99.0
        export VNCFONTS="${pkgs.xorg.fontmiscmisc}/lib/X11/fonts/misc,${pkgs.xorg.fontcursormisc}/lib/X11/fonts/misc"
        export USER="test"
        export HOME="`pwd`/home"
        mkdir -p $HOME
      '';
      buildPhase = ''
        nix-build dispatcher.nix --argstr action package

        ${pkgs.tightvnc}/bin/Xvnc :99 -localhost -fp $VNCFONTS &
        echo $! > $HOME/.Xvnc.pid

        ${pkgs.busybox}/bin/timeout -t 5 ./result/bin/nixui

        # and then kill the VNC server
        kill -15 `cat \$HOME/.Xvnc.pid`

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
