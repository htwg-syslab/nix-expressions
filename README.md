# Syslab Nix Expressions
This project contains nix expressions for the syslab courses at HTWG Konstanz.

## Requirements

* Installed [nix](https://nixos.org/nix) which provides the [nix-shell](http://nixos.org/nix/manual/#sec-nix-shell)

## Design

* TODO: describe the following
    * [ ] everything is based on nixshwrap
    * [ ] every course has its own shell derivation
    * [ ] every language has it's own package collection

## Workflow

### Example: run the base from the alpha branch

```
(
    NIX_PATH=shellpkgs=https://github.com/NixOS/nixpkgs-channels/archive/6d6cf3f24acce7ef4dc541c797ad23e70889883b.tar.gz:$NIX_PATH
    NIX_SHELL_DRV=https://github.com/htwg-syslab/nix-expressions/archive/alpha.tar.gz
    NIX_SHELL_DRVATTR=shell_bsys
nix-shell \
    --argstr shDrv ${NIX_SHELL_DRV} \
    -A ${NIX_SHELL_DRVATTR} \
    ${NIX_SHELL_DRV}
)
```
