{ nixpkgs, system ? builtins.currentSystem }:
let
  config = {
    chromium.enablePepperFlash = true;
  };
  pkgs = import <nixpkgs> { inherit system config; };
  jobs = {
    chromium = pkgs.chromium;
  };
in jobs
