{ pkgs
, mkDerivation
, callPackage
, writeScript
 }:

let

in {
   configuredPkgs = {
     vim = callPackage ./configured/vim-derivates/vim.nix { name = "vim"; };
   };

  customLesspipe = mkDerivation {
    name = "lesspipe";

    phases = "installPhase";
    installPhase = ''
      set -xe
      mkdir -p $out
      cp -r ${pkgs.lesspipe}/* $out/
      chmod +w $out/bin
      ln -s lesspipe.sh $out/bin/lesspipe
      chmod -w $out/bin
    '';
  };

  labshell = callPackage ./labshell { };
}
