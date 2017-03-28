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
        file
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
        pkgconfig
        ncurses
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
    cpp =
      (with pkgs;[
        busybox.nativeBuildInputs
      ]);
    cpp-embedded =
      (with pkgs;[
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

  shell_sysoHW0 = mkShellDerivation rec {
    name = "shell_sysoHW0";
    buildInputs = 
      (with dependencies;
        base
        ++ code)
        ++
      (with pkgs; [
        linuxPackages.kernel.nativeBuildInputs
        busybox.nativeBuildInputs
        gcc
        glibc.static
        cpio
        qemu
      ])
    ;
    shellHook = with shellHooks;
    ''
        export hardeningDisable=all
    ''
    ;
  };

  shell_sysoHW1 = mkShellDerivation rec {
    name = "shell_sysoHW1";
    buildInputs = 
      (with dependencies;
        base
        ++ code)
        ++
      (with pkgs; [
        qemu
        busybox.nativeBuildInputs
        cpio
        gccCrossArmNoneEabi
      ])
    ;
    shellHook = with shellHooks;
    ''
        export hardeningDisable=all
    ''
    ;
  };

  shell_sysoFHS = (pkgs.buildFHSUserEnv rec {
    name = "syso-buildenv";
    targetPkgs = pkgs: with pkgs;[
        which
        bashInteractive
        git
    ];
    multiPkgs = pkgs: with pkgs;[
        gnumake
        gcc-unwrapped
        glibc.static
        binutils
        busybox.nativeBuildInputs
        ncurses
        ncurses.dev
    ];
    profile = ''
        export LIBRARY_PATH=$LD_LIBRARY_PATH
    '';
   });

}
