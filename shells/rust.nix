{ nixpkgs ? import "/nix/var/nix/profiles/per-user/root/channels/nixpkgs/"{}
, fixpkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs-channels/archive/6d6cf3f24acce7ef4dc541c797ad23e70889883b.tar.gz") {}
, pkgs ? fixpkgs
, name ? "generic"
, version ? "Stable"
, extraBuildInputs ? []
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
in pkgs.stdenv.mkDerivation {
  inherit name;
  buildInputs = with rustPackages;[
#   TODO: add configured vim
#   ( import ./vim-rust.nix { pkgs=gitpkgs; commonRC=commonVimRC;
#       inherit rustc;
#       racerd=pkgs.rustracerd;
#   })
    rustc cargo
  ] ++ [
    pkgs.rustfmt
    pkgs.git
    pkgs.bats
    pkgs.strace
    pkgs.gdb
    pkgs.sublime3
    pkgs.vscode
  ] ++ extraBuildInputs;
  shellHook = (rustShellHook){
    inherit name;
    inherit rustc;
  };
}
