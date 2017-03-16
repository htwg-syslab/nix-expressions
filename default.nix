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

        gccCrossArmV7LinuxHardfp = (pkgsFun {
          crossSystem = {
            config = "arm-none-eabi";
            arch = "armv7";
            float = "hard";
            fpu = "vfp";
            libc = null;
            withTLS = true;
            openssl.system = "linux-generic32";
            gcc = {
              arch = "armv7";
              fpu = "vfp";
              float = "hard";
            };
          };
        }).gccCrossStageStatic;
    };

    system = "x86_64-linux";
    platform = { kernelArch = "x86_64"; kernelAutoModules = true; kernelBaseConfig = "defconfig"; kernelHeadersBaseConfig = "defconfig"; kernelTarget = "bzImage"; name = "pc"; uboot = null; };
  };

  pkgsFun = import <shellpkgs>;
  pkgsFunArgs = { inherit config; };
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
    shell_bsys
    shell_syso
    shell_sysoFHS
  ;

}
