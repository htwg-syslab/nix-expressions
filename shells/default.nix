{ pkgs
, callPackage
, prefix
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
        schedtool
      ];

    admin =
      with pkgs; [
        ansible
        nix-repl
        nox
      ];

    code =
      with pkgs; [
        pkgconfig
        ncurses ncurses.dev
        posix_man_pages
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
      a + ''(
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

  genManPath = ({deps}:
    builtins.foldl' (a: b:
        a + ":${b}/share/man"
    ) "" (deps)
  );

  shellHooks = {
    base = ''
      export EDITOR=vim
      export PAGER=${pkgs.less}/bin/less
      source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
      export GIT_SSH=${pkgs.openssh_with_kerberos}/bin/ssh
      git config --global merge.tool 1>/dev/null || git config --global merge.tool vimdiff
      export MANPATH=${genManPath {deps=dependencies.base;}}
      '' +
      # FIXME: whys is this needed?
      ''
      source ${pkgs.gitFull}/etc/bash_completion.d/git-completion.bash
    '';
    code = ''
      export MANPATH=$MANPATH:${genManPath {deps=dependencies.code;}}
      export hardeningDisable=all
    '';
    rust = ''
      export MANPATH=$MANPATH:${genManPath {deps=dependencies.rust;}}
      export RUST_SRC_PATH="${rustExtended}/lib/rustlib/src/rust/src/"

      export CARGO_INSTALL_ROOT=/var/tmp/cargo
      if [[ ! -d $CARGO_INSTALL_ROOT ]]; then
        mkdir -p $CARGO_INSTALL_ROOT -m 2770
      fi
      export PATH=$CARGO_INSTALL_ROOT/bin:$PATH

      ${genRustCratesCode{}}

      find $CARGO_INSTALL_ROOT \
        -uid $(id -u) -type d -exec chmod g+sw {} \+ -o \
        -uid $(id -u) -type f -exec chmod g+w {} \+
    '';
  };

in {

  base = mkShellDerivation rec {
    inherit prefix;
    flavor = "base";
    buildInputs = with dependencies;
      base
    ;
    shellHook = with shellHooks;
      base
    ;
  };

  code = mkShellDerivation rec {
    inherit prefix;
    flavor = "code";
    buildInputs = with dependencies;
      base
      ++ code
    ;
    shellHook = with shellHooks;
      base
      + code
    ;
  };

  admin = mkShellDerivation rec {
    inherit prefix;
    flavor = "admin";
    buildInputs = with dependencies;
      base
      ++ admin
      ++ code
    ;
    shellHook = with shellHooks;
      base
      + code
    ;
  };

  bsys = mkShellDerivation rec {
    inherit prefix;
    flavor = "bsys";
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

  rtos = mkShellDerivation rec {
    inherit prefix;
    flavor = "rtos";
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

  sysoHW0 = let
    in mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW0";
    buildInputs = with dependencies;
      base
      ++ code
    ;
    shellHook = with shellHooks;
      base
      + code
    ;
  };

  sysoHW1 = let
    bbStatic = pkgs.busybox.override {
      enableStatic=true;
    };
    in mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW1";
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
        + rust
    ;
  };

  sysoHW2 = let
    bbStatic = pkgs.busybox.override {
      enableStatic=true;
    };
    dbStatic = pkgs.dropbear.override {
      enableStatic=true;
    };
    in mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW2";
    buildInputs =
      (with dependencies;
        base
        ++ code
        ++ rust)
        ++
      (with pkgs; [
        linuxPackages.kernel.nativeBuildInputs
        bbStatic.nativeBuildInputs
        dbStatic.nativeBuildInputs
        zlib zlib.static glibc glibc.static
        qemu
        cpio
        pax-utils
      ])
    ;
    shellHook = with shellHooks;
        base
        + code
        + rust
    ;
  };

  sysoHW3 = mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW3";
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
        gccCrossArmNoneEabi
      ])
    ;
    shellHook = with shellHooks;
        base
        + code
        + rust
    ;
  };

  sysoFHS = (pkgs.buildFHSUserEnv rec {
    flavor = "sysoFHS";
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
