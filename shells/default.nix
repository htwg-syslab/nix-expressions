{ pkgs
, callPackage
}:

let
  mkShellDerivation = callPackage ./mkShellDerivation.nix;

  dependencies = {
    base =
      with pkgs; [
        openssh
        strace
        bashInteractive
        man
        less
        curl
        stdmanpages
        pstree
        psmisc
        procps
        htop
        vim
        ncurses
        tmux
        which
        bashInteractive
        zsh
        zsh-autosuggestions
        zsh-completions
        zsh-syntax-highlighting
        nix
      ];

    code =
      with pkgs; [
        git
        bats
        shellcheck
        python27Full
        clang
        sublime3
        vscode
        atom
        geany-with-vte
      ];

    rust =
      (with pkgs;[
        rustfmt
        rustracer
      ]) ++
      (with pkgs.rustStable;[
        rustc cargo
      ]);
  };

  shellHooks = {
    base = ''
        export PAGER=${pkgs.less}/bin/less
    '';
    rust = ''
      export RUST_SRC_PATH="${pkgs.rustStable.rustc.src}/src"
    '';
  };

in {

  shell_base = mkShellDerivation rec {
    name = "shell_base";
    buildInputs = with dependencies;
      base
    ;
    shellHook = with shellHooks;
      base
    ;
  };

  shell_bsys = mkShellDerivation rec {
    name = "shell_bsys";
    buildInputs = with dependencies;
      base
      ++ code
      ++ rust
    ;
    shellHook = with shellHooks;
      base
      + rust
    ;
  };
}
