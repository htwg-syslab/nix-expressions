{ pkgs
, callPackage
}:

let
  mkShellDerivation = callPackage ./mkShellDerivation.nix;

  dependencies = {
    base =
      with pkgs; [
        openssh_with_kerberos
        strace
        file
        man
        less
        curl
        stdmanpages
        pstree
        psmisc
        procps
        htop
        configuredPkgs.vim
        tmux
        which
        bashInteractive
        zsh
        zsh-autosuggestions
        zsh-completions
        zsh-syntax-highlighting
        nix
        gitFull
        tree
        indent
      ];

    code =
      with pkgs; [
        pkgconfig
        ncurses ncurses.dev
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
        ddd
        valgrind
      ];

    rust =
      (with pkgs;[
      ]) ++
      (with pkgs.rustChannels.stable;[
        rust
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
        export EDITOR=vim
        export PAGER=${pkgs.less}/bin/less
        source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
        export GIT_SSH=${pkgs.openssh_with_kerberos}/bin/ssh
        git config --global merge.tool 1>/dev/null || git config --global merge.tool vimdiff
        '' +
        # FIXME: whys is this needed?
        ''
        source ${pkgs.gitFull}/etc/bash_completion.d/git-completion.bash
    '';
    code = ''
        export hardeningDisable=all
    '';
    rust = ''
      export RUST_SRC_PATH="${pkgs.rustChannels.stable.rust-src}/lib/rustlib/src/rust/src/"

      export CARGO_INSTALL_ROOT=/var/tmp/cargo
      mkdir -p $CARGO_INSTALL_ROOT
      export PATH=$CARGO_INSTALL_ROOT/bin:$PATH

      for crate in racer rustfmt rustsym; do
        cargo install $crate
      done

      chmod g+w -R $CARGO_INSTALL_ROOT
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
      + code
      + rust
    ;
  };

  shell_rtos = mkShellDerivation rec {
    name = "shell_rtos";
    buildInputs =
      (with dependencies;
        base
        ++ code
        ++ rust)
        ++
      (with pkgs; [
        qemu
        grub
        nasm
      ])
    ;
    shellHook = with shellHooks;
      base
      + code
      + rust
    ;
  };

  shell_sysoHW0 = let
    in mkShellDerivation rec {
    name = "shell_sysoHW1";
    buildInputs = with dependencies; 
        base
        ++ code
    ;
    shellHook = with shellHooks;
      base
      + code
    ;
  };

  shell_sysoHW1 = let
    bbStatic = pkgs.busybox.override {
      enableStatic=true;
    };
    in mkShellDerivation rec {
    name = "shell_sysoHW1";
    buildInputs =
      (with dependencies;
        base
        ++ code
        ++ rust)
        ++
      (with pkgs; [
        linuxPackages.kernel.nativeBuildInputs
        bbStatic.nativeBuildInputs
        qemu
        cpio
      ])
    ;
    shellHook = with shellHooks;
        base
        + code
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
        base
        + code
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
