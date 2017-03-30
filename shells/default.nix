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
        git
        tree
      ];

    code =
      with pkgs; [
        pkgconfig
        ncurses
        bats
        shellcheck
        python27Full
        clang
        lldb
        sublime3
        vscode
        atom
        geany-with-vte
        gdb
        valgrind
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

  shell_sysoHW0 = let
    in mkShellDerivation rec {
    name = "shell_sysoHW1";
    buildInputs = dependencies.base;
  };

  shell_sysoHW1 = let
    bbStatic = pkgs.busybox.override {
      enableStatic=true;
    };
    in mkShellDerivation rec {
    name = "shell_sysoHW1";
    buildInputs =
      (with dependencies;
        base)
        ++
      (with pkgs; [
        pkgconfig
        linuxPackages.kernel.nativeBuildInputs
        bbStatic.nativeBuildInputs
        ncurses ncurses.dev
        qemu
        cpio
      ])
    ;
    shellHook = with shellHooks;
    ''
        export hardeningDisable=all
    ''
    ;
  };

  shell_sysoHW2 = mkShellDerivation rec {
    name = "shell_sysoHW2";
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
