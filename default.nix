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

  rustOverlaySrc = nixpkgs.fetchFromGitHub {
    owner = "mozilla";
    repo = "nixpkgs-mozilla";
    rev = "6179dd876578ca2931f864627598ede16ba6cdef";
    sha256 = "1lim10a674621zayz90nhwiynlakxry8fyz1x209g9bdm38zy3av";
  };

  pkgsImportFunc = ({ nixpkgs
      , pkgsPath
      , additionalOverrides ? ({...}: {})
    }:
    let
      # config passed to import {}
      config = {
        allowUnfree = true;
        maxJobs = nixpkgs.lib.mkDefault 5;

        packageOverrides = pkgs: with pkgs; rec {
          inherit (callPackage ./pkgs { })
            configuredPkgs
            labshell

            vscodePkill
            customLesspipe
          ;

          mkShellDerivation = callPackage ./shells/mkShellDerivation.nix;

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

        } // additionalOverrides { inherit pkgs; };

        system = "x86_64-linux";
        platform = { kernelArch = "x86_64"; kernelAutoModules = true; kernelBaseConfig = "defconfig"; kernelHeadersBaseConfig = "defconfig"; kernelTarget = "bzImage"; name = "pc"; uboot = null; };
      };
      overlays = [
        (import "${rustOverlaySrc}/rust-overlay.nix")
      ];
    in
      import pkgsPath { inherit config overlays; }
  );

  shellpkgs = pkgsImportFunc {
    inherit nixpkgs;
    pkgsPath = nixpkgsChannelsFetched;
  };

  shellpkgsCrossFixedFetched =
    nixpkgs.fetchFromGitHub {
      owner = "htwg-syslab";
      repo = "nixpkgs";
      rev = "ba44a07c63cef713c8c2670e5e124aae0411b206";
      sha256 = "0ngfdh4jx19w60rfhrj9dm3fwcqk4m303sn8sm82kdjn3igbyqyl";
    }
  ;

  shellpkgsCrossFixed = pkgsImportFunc {
    inherit nixpkgs;
    pkgsPath = shellpkgsCrossFixedFetched;
    additionalOverrides = (pkgs: with pkgs; rec {
      # guile 2.2 doesn't cross compile. See https://debbugs.gnu.org/cgi/bugreport.cgi?bug=28920
      guile = pkgs.guile_2_0;

      # We really don't need libapparmor and it is a pain to cross compile due to
      # its perl bindings
      systemd = pkgs.systemd.override { libapparmor = null; };
    });
  };

  shellpkgsCrossAarch64LinuxGnu = ({ pkgsPath }:
    let
			platform = (import "${builtins.toString pkgsPath}/lib/systems/platforms.nix").aarch64-multiplatform;
      pkgs = import pkgsPath {
        crossSystem = (import "${builtins.toString pkgsPath}/lib").systems.examples.aarch64-multiplatform;
      };
    in pkgs) { pkgsPath = shellpkgsCrossFixedFetched; };


  callPackage = shellpkgs.newScope {
    inherit callPackage # self import to override old callPackage
      nixpkgs
      shellpkgs
      shellpkgsCrossFixed
      shellpkgsCrossAarch64LinuxGnu

      labshellExpressionsLocal
      labshellExpressionsRemoteURL
      ;
    inherit (nixpkgs.stdenv) mkDerivation;
    inherit (shellpkgs) mkShellDerivation;
  };

  labshellsUnstable = nixpkgs.lib.filterAttrs (k: v:
      (builtins.isAttrs v)
    ) (callPackage ./shells { prefix = "labshell"; });

  labshellsStable = nixpkgs.lib.filterAttrs (k: v:
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
