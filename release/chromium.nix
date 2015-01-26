{ nixpkgs, system ? builtins.currentSystem }:
let
  pkgs = import <nixpkgs> { inherit system; };
  jobs = {
    chromium = pkgs.chromium;
  };
in jobs
