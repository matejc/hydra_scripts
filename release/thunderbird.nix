{ nixpkgs, system ? builtins.currentSystem }:
let
  pkgs = import <nixpkgs> { inherit system; };
  jobs = {
    thunderbird-gtk3 = pkgs.thunderbird.override { gtk = pkgs.gtk3; };
  };
in jobs
