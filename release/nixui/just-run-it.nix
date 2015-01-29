{ nixpkgs, src, system ? builtins.currentSystem }:
let
  pkgs = import nixpkgs { inheritr system; };
  inherit (pkgs) stdenv fetchgit nix makeDesktopItem writeScript;
  nodewebkit = pkgs.callPackage <src/node-webkit.nix> { gconf = pkgs.gnome.GConf; };
  nixui = (import <src/default.nix> { inherit pkgs; }).build;

  nodePackages = import <nixpkgs/pkgs/top-level/node-packages.nix> {
    inherit pkgs;
    inherit (pkgs) stdenv nodejs fetchurl fetchgit;
    neededNatives = [ pkgs.python ] ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.utillinux;
    self = nodePackages;
    generated = <src/node.nix>;
  };
  
  testNodePackages = pkgs.buildEnv {
    name = "testNodePackages";
    paths = [ nodePackages.mocha nodePackages.sinon nodePackages.by-spec."expect.js"."~0.3.1" ];
  };

  jobs = {
    nixui = stdenv.mkDerivation {
      name = "nixui-dev";
      src = { outPath = src; name = "nixui-src"; };
      buildInputs = with pkgs; [ gnumake nix tightvnc ];
      configurePhase = ''
        export NIX_REMOTE=daemon
        export NIX_PATH="nixpkgs=${nixpkgs}"
        export NODE_PATH="${testNodePackages}/lib/node_modules:$NODE_PATH"
        #export DISPLAY=:99.0
        #export VNCFONTS="${pkgs.xorg.fontmiscmisc}/lib/X11/fonts/misc,${pkgs.xorg.fontcursormisc}/lib/X11/fonts/misc"
        #export USER="test"
        #export HOME="`pwd`/home"
        #mkdir -p $HOME
      '';
      buildPhase = ''
        echo "############################ test 'package' ############################"
        nix-build dispatcher.nix --argstr action package

        #{pkgs.tightvnc}/bin/Xvnc :99 -localhost -geometry 1024x768 -depth 16 -fp $VNCFONTS &
        #echo $! > $HOME/.Xvnc.pid
        #trap "{ echo 'killing '$(cat $HOME/.Xvnc.pid); kill -15 $(cat $HOME/.Xvnc.pid); }" EXIT
        #{pkgs.busybox}/bin/timeout -t 5 ./result/bin/nixui

        echo "############################ run tests ############################"
        cd ./src
        ${testNodePackages}/lib/node_modules/.bin/mocha --reporter list
        cd ..
        
        echo "############################ test nodewebkit ############################"
        ls -lah ${nodewebkit}/bin/nw
      '';
      installPhase = ''
        mkdir -p $out/lib
        cp -r . $out/lib/nixui
      '';
    };
  };
in
  jobs
