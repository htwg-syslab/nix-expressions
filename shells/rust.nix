{ nixpkgs ? <nixpkgs>
, fixpkgs ? (fetchTarball "https://github.com/NixOS/nixpkgs-channels/archive/6d6cf3f24acce7ef4dc541c797ad23e70889883b.tar.gz")
, _pkgs ? fixpkgs
, pkgs ? import fixpkgs {}
, name ? "generic"
, version ? "Stable"
, extraBuildInputs ? []
, x2go ? true
}: 
let 
  rustPackages = builtins.getAttr "rust${version}" pkgs;
  rustc = rustPackages.rustc;
  rustShellHook = { rustc, name }: ''
    rustname=rust_${rustc.version}_${name}
    setPS1 $rustname
    unset name
  '';
  commonVimRC = ''
  '';

  libxcb_x2go = pkgs.xorg.libxcb.overrideDerivation (oldAttrs: {
    postFixup = ''
      chmod +w $out/lib
      find $out/lib -name "*.so" -exec sed -i --follow-symlinks 's/BIG-REQUESTS/_IG-REQUESTS/' {} \;
      chmod -w $out/lib
    '';
  });

  config = {
    allowUnfree = true;
    maxJobs = pkgs.lib.mkDefault 5;

    packageOverrides = pkgs: rec {
        # FIXME: find out why this doesn't work for atom and vscode (atomEnv)
#        xorg =
#        if x2go then
#          pkgs.xorg // {
#            libxcb = libxcb_x2go;
#          }
#        else pkgs.xorg;

        vscode = pkgs.replaceDependency {
          drv = pkgs.vscode;
          oldDependency = pkgs.xorg.libxcb;
          newDependency = libxcb_x2go;
        };
    };
  };

  configuredPkgs = import _pkgs { inherit config; };

in configuredPkgs.stdenv.mkDerivation {
  inherit name;
  buildInputs = with rustPackages;[
#   TODO: add configured vim
#   ( import ./vim-rust.nix { pkgs=gitpkgs; commonRC=commonVimRC;
#       inherit rustc;
#       racerd=pkgs.rustracerd;
#   })
    rustc cargo
  ] ++ [
    configuredPkgs.rustfmt
    configuredPkgs.git
    configuredPkgs.bats
    configuredPkgs.sublime

    configuredPkgs.vscode
  ] ++ extraBuildInputs;
  shellHook = (rustShellHook){
    inherit name;
    inherit rustc;
  } + ''
    alias code-x2go="LD_LIBRARY_PATH=${libxcb_x2go}/lib ${pkgs.vscode.out}/bin/code"
  '';
}
