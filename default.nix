{ nixpkgs ? import <nixpkgs>{}
, labshellExpressionsLocal ? builtins.toString ./.
, labshellExpressionsUpdateFromLocal ? false
, labshellExpressionsRemoteRepo ? "htwg-syslab/nix-expressions"
, labshellExpressionsRemoteRev ? "master"
, labshellExpressionsRemoteURL ? if labshellExpressionsUpdateFromLocal then labshellExpressionsLocal else "https://github.com/${labshellExpressionsRemoteRepo}/archive/${labshellExpressionsRemoteRev}.tar.gz"
, nixpkgsChannelsRev ? "e019978d027b60440119a5906041991866325621"
, nixpkgsChannelsSha256 ? "184lp8zknxm2m0p0zxxkmxfr6xqxsp1lxp5rb3zgc4daqdyza84a"
, nixpkgsChannels ? nixpkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs-channels";
    rev = nixpkgsChannelsRev;
    sha256 = nixpkgsChannelsSha256;
  }
}:

let
  overrides = callPackage ./pkgs/overrides { };
  shells = callPackage ./shells { };

  # config passed to import {}
  config = {
    allowUnfree = true;
    maxJobs = nixpkgs.lib.mkDefault 5;

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

        labshell = callPackage ./pkgs/labshell { };

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

  rustOverlaySrc = nixpkgs.fetchFromGitHub {
    owner = "htwg-syslab";
    repo = "nixpkgs-mozilla";
    rev = "1eb61fb93ea32d7343efc5f9a53b5e4ab9846390";
    sha256 = "0dplynkwp39npgfs8qcr9731x6rvj4jfn25as209f6g04jq5j1bc";
  };

  overlays = [
    (import "${rustOverlaySrc}/rust-overlay.nix")
  ];

  pkgsFun = import nixpkgsChannels;
  shellpkgsFunArgs = { inherit config overlays; };
  shellpkgs = pkgsFun shellpkgsFunArgs;

  callPackage = shellpkgs.newScope {
    inherit callPackage # self import to override old callPackage
      shellpkgs
      nixpkgs
      labshellExpressionsLocal
      labshellExpressionsRemoteURL
      ;
    inherit (nixpkgs.stdenv) mkDerivation;
  };

in rec {
  inherit (shellpkgs)
    labshell
  ;

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
