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

        gccCrossArmNoneEabi = (pkgsFun {
          crossSystem = {
            config = "arm-none-eabi";
            libc = null;
          };
        }).gccCrossStageStatic;
    };

    system = "x86_64-linux";
    platform = { kernelArch = "x86_64"; kernelAutoModules = true; kernelBaseConfig = "defconfig"; kernelHeadersBaseConfig = "defconfig"; kernelTarget = "bzImage"; name = "pc"; uboot = null; };
  };

  rustOverlaySrc = shellpkgs.fetchFromGitHub {
    owner = "htwg-syslab";
    repo = "nixpkgs-mozilla";
    rev = "1eb61fb93ea32d7343efc5f9a53b5e4ab9846390";
    sha256 = "0dplynkwp39npgfs8qcr9731x6rvj4jfn25as209f6g04jq5j1bc";
  };

  overlays = [
    (import "${rustOverlaySrc}/rust-overlay.nix")
  ];

  pkgsFun = import <shellpkgs>;
  pkgsFunArgs = { inherit config overlays; };
  pkgs = pkgsFun pkgsFunArgs;

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
    shell_admin
    shell_code
    shell_bsys
    shell_rtos
    shell_sysoHW0
    shell_sysoHW1
    shell_sysoHW2
    shell_sysoFHS
  ;
}
