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

  vscodePkill = mkDerivation rec {
    name = "vscodePkill";

    src = writeScript "code_pkill" ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.procps}/bin/pkill -9 -u $(id -u) -f vscode/code
      ${pkgs.vscode}/bin/code
    '';

    phases = "installPhase";
    installPhase = ''
      set -xe
      mkdir -p $out/bin
      cp -a ${src} $out/bin/code_pkill
    '';
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
