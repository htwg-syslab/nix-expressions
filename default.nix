{ shDrv ? null }:
let
  # Untouched but specific nixpkgs
  shellpkgs = import <shellpkgs> {};

  overrides = callPackage ./pkgs/overrides { };
  shells = callPackage ./shells { };

  # config passed to import {}
  config = {
    allowUnfree = true;
    maxJobs = shellpkgs.lib.mkDefault 5;

    packageOverrides = pkgs: with pkgs; rec {
        vscode = pkgs.replaceDependency {
          drv = pkgs.vscode;
          oldDependency = pkgs.xorg.libxcb;
          newDependency = overrides.libxcb_x2go;
        };

        atom = pkgs.replaceDependency {
          drv = pkgs.atom;
          oldDependency = pkgs.xorg.libxcb;
          newDependency = overrides.libxcb_x2go;
        };

        nixshwrap = callPackage ./pkgs/nixshwrap { };

        configuredPkgs = {
          vim = callPackage ./pkgs/configured/vim-derivates/vim.nix { name = "vim"; };
        };
    };
  };
  pkgs = import <shellpkgs> { inherit config; };

  callPackage = pkgs.newScope { 
    # self import to override old callPackage
    inherit callPackage;

    inherit (pkgs.stdenv) mkDerivation;
    inherit shellpkgs;
    inherit shDrv;
  };

in rec {
  inherit pkgs;
  inherit ( callPackage ./shells { } )
    shell_base
    shell_bsys
  ;

}
