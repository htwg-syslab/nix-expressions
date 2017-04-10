{ pkgs
, callPackage
}:

let
  mkShellDerivation = callPackage ./mkShellDerivation.nix;

  rustExtended = (pkgs.rustChannels.stable.rust.override { extensions = [ "rust-src" ]; });

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

    rust = [ rustExtended ];

    cpp =
      (with pkgs;[
        busybox.nativeBuildInputs
      ]);
    cpp-embedded =
      (with pkgs;[
      ]);

    rustCrates = {
      racer = "2.0.6";
      rustfmt = "0.8.3";
      rustsym = "0.3.1";
    };
  };

  genRustCratesCode = ({}:
    builtins.foldl' (a: b:
        a + ''
	(
	  set -e
	  CRATE=${b}
	  CRATE_VERSION=${builtins.getAttr b dependencies.rustCrates}
	  cargo install --list | grep "$CRATE v$CRATE_VERSION" 2>&1 1>/dev/null
	  if [ ! $? -eq 0 ]; then
	    cargo install --force --vers $CRATE_VERSION $CRATE
	  fi
	) || exit $?
        ''
    ) "" (builtins.attrNames dependencies.rustCrates)
  );

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
      export RUST_SRC_PATH="${rustExtended}/lib/rustlib/src/rust/src/"

      export CARGO_INSTALL_ROOT=/var/tmp/cargo
      mkdir -p $CARGO_INSTALL_ROOT
      export PATH=$CARGO_INSTALL_ROOT/bin:$PATH

      ${genRustCratesCode{}}

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

  shell_code= mkShellDerivation rec {
    name = "shell_code";
    buildInputs = with dependencies;
      base
      ++ code
    ;
    shellHook = with shellHooks;
      base
      + code
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
