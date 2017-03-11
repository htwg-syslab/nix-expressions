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

### Example: run the base from a commit known to work

```bash
(
    NIX_PATH=shellpkgs=https://github.com/NixOS/nixpkgs-channels/archive/6d6cf3f24acce7ef4dc541c797ad23e70889883b.tar.gz:$NIX_PATH
    NIX_SHELL_DRV=https://github.com/htwg-syslab/nix-expressions/archive/b9472c0fbac63e86e147db547b5242b10c26b3ed.tar.gz
    NIX_SHELL_DRVATTR=shell_bsys
nix-shell \
    --pure \
    --argstr shDrv ${NIX_SHELL_DRV} \
    -A ${NIX_SHELL_DRVATTR} \
    ${NIX_SHELL_DRV}
)
```

### Example Development Workflow

For development it best to clone the repository locally.

#### Clone Repository
```bash
git clone git@github.com:htwg-syslab/nix-expressions.git
pushd nix-expressions
```

#### Test changes to shell_bsys
The following example assumes `$PWD` is the path of the git repository.

1. Prepare the environment variables
    ```bash
    NIX_PATH=shellpkgs=https://github.com/NixOS/nixpkgs-channels/archive/6d6cf3f24acce7ef4dc541c797ad23e70889883b.tar.gz:$NIX_PATH
    NIX_SHELL_DRV=$PWD
    NIX_SHELL_DRVATTR=shell_bsys
    ```
2. Make your desired changes
    ```bash
    $EDITOR shells/default.nix
    ```
3. Try out your changes
    ```
    nix-shell \
        --pure \
        --argstr shDrv ${NIX_SHELL_DRV} \
        -A ${NIX_SHELL_DRVATTR} \
        ${NIX_SHELL_DRV}
    ```