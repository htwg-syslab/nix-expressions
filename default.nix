{ nixpkgs ? import <nixpkgs>{}
, labshellExpressionsLocal ? builtins.toString ./.
, labshellExpressionsUpdateFromLocal ? false
, labshellExpressionsRemoteRepo ? "htwg-syslab/nix-expressions"
, labshellExpressionsRemoteRev ? "master"
, labshellExpressionsRemoteURL ? if labshellExpressionsUpdateFromLocal then labshellExpressionsLocal else "https://github.com/${labshellExpressionsRemoteRepo}/archive/${labshellExpressionsRemoteRev}.tar.gz"
, nixpkgsChannelsRev ? "f8d1205d4b98771ad12d4868b04717451b27b88b"
, nixpkgsChannelsSha256 ? "19655w66w2j4cm0y06vzz7wc2f9qynjvcgcwl2yc2cjl8zjdm8gq"
, nixpkgsChannelsFetched ? nixpkgs.fetchFromGitHub {
    owner = "htwg-syslab";
    repo = "nixpkgs";
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

        gccCrossArmNoneEabi = (pkgsFun {
          crossSystem = {
            config = "arm-none-eabi";
            libc = null;
          };
        }).gccCrossStageStatic;

        # gdb = pkgs.gdb.overrideDerivation (oldAttrs: {
        #   patches = [ ./patches/gdb-allow-change-g-packet.patch ];
        # });

        inherit (callPackage ./pkgs { })
          configuredPkgs
          mkShellDerivation
          labshell

          customLesspipe
        ;
    };

    system = "x86_64-linux";
    platform = { kernelArch = "x86_64"; kernelAutoModules = true; kernelBaseConfig = "defconfig"; kernelHeadersBaseConfig = "defconfig"; kernelTarget = "bzImage"; name = "pc"; uboot = null; };
  };

  rustOverlaySrc = nixpkgs.fetchFromGitHub {
    owner = "mozilla";
    repo = "nixpkgs-mozilla";
    rev = "6179dd876578ca2931f864627598ede16ba6cdef";
    sha256 = "1lim10a674621zayz90nhwiynlakxry8fyz1x209g9bdm38zy3av";
  };

  overlays = [
    (import "${rustOverlaySrc}/rust-overlay.nix")
  ];

  pkgsFun = import nixpkgsChannelsFetched;
  shellpkgsFunArgs = { inherit config overlays; };
  shellpkgs = pkgsFun shellpkgsFunArgs;

  callPackage = shellpkgs.newScope {
    inherit callPackage # self import to override old callPackage
      shellpkgs
      nixpkgs
      nixpkgsChannelsFetched
      labshellExpressionsLocal
      labshellExpressionsRemoteURL
      ;
    inherit (nixpkgs.stdenv) mkDerivation;
  };

  labshellsUnstable = shellpkgs.lib.filterAttrs (k: v:
      (builtins.isAttrs v)
    ) (callPackage ./shells { prefix = "labshell"; });

  labshellsStable = shellpkgs.lib.filterAttrs (k: v:
      (builtins.isAttrs v) && !( (builtins.hasAttr "unstable" v) && v.unstable == true)
    ) (callPackage ./shells { prefix = "labshell"; });

in rec {
  inherit (shellpkgs)
    labshell
  ;

  inherit
    labshellsStable
    labshellsUnstable
  ;

  labshells = labshellsStable;
}
