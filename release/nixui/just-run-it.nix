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
        #export DISPLAY=:99.0
        #export VNCFONTS="${pkgs.xorg.fontmiscmisc}/lib/X11/fonts/misc,${pkgs.xorg.fontcursormisc}/lib/X11/fonts/misc"
        #export USER="test"
        #export HOME="`pwd`/home"
        #mkdir -p $HOME
      '';
      buildPhase = ''
        nix-build dispatcher.nix --argstr action package

        #{pkgs.tightvnc}/bin/Xvnc :99 -localhost -geometry 1024x768 -depth 16 -fp $VNCFONTS &
        #echo $! > $HOME/.Xvnc.pid
        #trap "{ echo 'killing '$(cat $HOME/.Xvnc.pid); kill -15 $(cat $HOME/.Xvnc.pid); }" EXIT
        #{pkgs.busybox}/bin/timeout -t 5 ./result/bin/nixui

        nix-shell dispatcher.nix --argstr action env --command "npm install"
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