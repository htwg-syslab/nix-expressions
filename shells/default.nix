{ pkgs
, nixpkgsChannelsFetched
, callPackage
, prefix
, mkDerivation
}:

let
  mkShellDerivation = callPackage ./mkShellDerivation.nix;

  rustExtended = rec {
    channels = {
      stable = pkgs.rustChannels.stable;
      nightly = with pkgs.lib.rustLib;
        fromManifest (manifest_v2_url { channel = "nightly"; date = "2017-10-13"; }) {
          inherit (pkgs) stdenv fetchurl patchelf;
        };
    };

    stable = (channels.stable.rust.override { extensions = [ "rust-src" "rls-preview" ]; });
    nightly = (channels.nightly.rust.override { extensions = [ "rust-src" "rls-preview" ]; });
  };

  crossPkgsAarch64LinuxGnu = ({ pkgsPath }:
    let
			platform = (import "${builtins.toString pkgsPath}/lib/systems/platforms.nix").aarch64-multiplatform;
      pkgs = import pkgsPath {
        crossSystem = (import "${builtins.toString pkgsPath}/lib").systems.examples.aarch64-multiplatform;
      };
    in pkgs) { pkgsPath = nixpkgsChannelsFetched; };

  dependencies = ({ dpkgs ? pkgs }: {
    base =
      with dpkgs; [
        dpkg customLesspipe
        openssh_with_kerberos
        strace
        file
        man
        manpages
        stdmanpages
        less
        curl
        netcat
        pstree
        fasd
        psmisc
        procps
        htop
        configuredPkgs.vim
        nano
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
        nettools
      ];

    admin =
      with dpkgs; [
        gist
        rsync
        ansible
        nix-repl
        nox
      ];

    code =
      with dpkgs; [
        ccache
        pkgconfig
        ncurses ncurses.dev
        posix_man_pages
        bats
        shellcheck
        python27Full
        clang
        cmake
        lldb
        sublime3
        xsel
        vscode
        vscodePkill
        atom
        geany-with-vte
        gdb
        ddd
        valgrind
        meld
      ];

    rust = {
        stable = [
          rustExtended.stable
#          rustExtended.nightly # this will put "rls" in the PATH, everything else will be shadowd
        ];
        nightly = [ rustExtended.nightly ];
    };


    osDevelopment =
      with dpkgs; [
        qemu
        grub2
        nasm
        xorriso
        llvm
      ];

    webDevelopment =
      with dpkgs; [
        sqlite
        postgresql
    ];

    linuxDevelopment =
      with dpkgs; [
        linuxPackages.kernel.buildInputs
        busybox.buildInputs
        dropbear.buildInputs

        zlib zlib.dev
        ncurses ncurses.dev
      ];

    linuxDevelopmentTools =
      with dpkgs; [
        qemu
        cpio
        pax-utils

        linuxPackages.kernel.nativeBuildInputs
        busybox.nativeBuildInputs
        dropbear.nativeBuildInputs

        kmod
        eject # util-linux
      ];

    linuxDevelopmentStatic = let
      bbStatic = dpkgs.busybox.override {
        enableStatic=true;
      };

      dbStatic = dpkgs.dropbear.override {
        enableStatic=true;
      };
     in
      with dpkgs; [
        glibc # FIXME: why is this needed for busybox to build?
        glibc.static
        zlib.static
        bbStatic.nativeBuildInputs
        bbStatic.buildInputs
        dbStatic.nativeBuildInputs
        dbStatic.buildInputs
      ];

    rustCrates = {
      base = {
        racer = {
          version = "2.0.10";
          binary  = "racer";
        };
        rustfmt = {
          version = "0.9.0";
          binary = "rustfmt";
        };
        rustsym = {
          version = "0.3.2";
          binary = "rustsym";
        };
      };

      cross = {
        xargo = {
          version = "0.3.9";
          binary = "xargo";
        };
      };

      nightly = {
        clippy = {
          version = "0.0.165";
          binary = "cargo-clippy";
        };
      };
    };
  });

  genRustCratesCode = ({cratesSet}:
    builtins.foldl' (a: b:
      a + ''(
        set -e
        CRATE=${b}
        CRATE_BINARY=${(builtins.getAttr b (dependencies{}).rustCrates."${cratesSet}").binary}
        CRATE_VERSION=${(builtins.getAttr b (dependencies{}).rustCrates."${cratesSet}").version}
        cargo install --list | grep "$CRATE v$CRATE_VERSION" &>> /dev/null
        rc1=$?
        ldd $(which $CRATE_BINARY 2>/dev/null) &>> /dev/null
        rc2=$?
        if [[ ! $rc1 -eq 0 || ! $rc2 -eq 0 ]]; then
          echo Rebuilding $CRATE $CRATE_VERSION
          cargo install --force --vers $CRATE_VERSION $CRATE
        fi
      ) || exit $?
      ''
    ) "" (builtins.attrNames (dependencies{}).rustCrates."${cratesSet}")
  );

  genManPath = ({deps}:
    mkDerivation rec {
      name = "manpath";

      manpaths = builtins.foldl' (a: b:
          a + " ${b}/share/man"
      ) "" (deps);

      phases = "installPhase";
      installPhase = ''
        set -e
        mkdir -p $out
        for m in $manpaths; do
          for mdirabs in $m/*; do
            mdir=$(basename $mdirabs)
            mkdir -p $out/$mdir
            ln -sf $mdirabs/* $out/$mdir/
          done
        done
      '';
    }
  );

  shellHooks = {
    base = ''
      export EDITOR=vim
      export PAGER=${pkgs.less}/bin/less
      source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
      export GIT_SSH=${pkgs.openssh_with_kerberos}/bin/ssh
      git config --global merge.tool 1>/dev/null || git config --global merge.tool vimdiff
      export MANPATH=${genManPath {deps=(dependencies{}).base;}}
      '' +
      # FIXME: whys is this needed?
      ''
      source ${pkgs.gitFull}/etc/bash_completion.d/git-completion.bash
    '';
    code = ''
      export MANPATH=$MANPATH:${genManPath {deps=(dependencies{}).code;}}
      export hardeningDisable=all
    '';
    rust = ({rustVariant ? "stable", rustDeps ? [ "base" ]}: ''
      export MANPATH=$MANPATH:${genManPath {deps=(dependencies{}).rust."${rustVariant}";}}
      export RUST_SRC_PATH=${rustExtended."${rustVariant}"}/lib/rustlib/src/rust/src/

      export CARGO_INSTALL_ROOT=/var/tmp/cargo
      if [[ ! -d $CARGO_INSTALL_ROOT ]]; then
        mkdir -p $CARGO_INSTALL_ROOT -m 2770
      fi
      export PATH=$CARGO_INSTALL_ROOT/bin:$PATH

      '' +
        builtins.foldl' (a: b:
          a + (genRustCratesCode{cratesSet=b;})
        ) "" rustDeps
      + ''
      find $CARGO_INSTALL_ROOT \
        -uid $(id -u) -type d -exec chmod g+sw {} \+ -o \
        -uid $(id -u) -type f -exec chmod g+w {} \+
    '');

    cross = ''
      PATH_CROSS=$(echo $PATH | tr ':' '\n' | grep $(echo $crossConfig | cut -d'-' -f1 )| tr '\n' ':')
      PATH_NATIVE=$(echo $PATH | tr ':' '\n' | grep -v $(echo $crossConfig | cut -d'-' -f1 )| tr '\n' ':')
      export PATH=$PATH_NATIVE:$PATH_CROSS
      unset PATH_CROSS PATH_NATIVE
    '';
  };

  shellDerivations = {

  base = mkShellDerivation rec {
    inherit prefix;
    flavor = "base";
    buildInputs = with (dependencies{});
      base
    ;
    shellHook = with shellHooks;
      base
    ;
  };

  code = mkShellDerivation rec {
    inherit prefix;
    flavor = "code";
    buildInputs = with (dependencies{});
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
    buildInputs = with (dependencies{});
      base
      ++ admin
    ;
    shellHook = with shellHooks;
      base
    ;
  };

  bsys = mkShellDerivation rec {
    inherit prefix;
    flavor = "bsys";
    buildInputs = with (dependencies{});
      base
      ++ code
      ++ rust.stable
    ;
    shellHook = with shellHooks;
      base
      + code
      + rust {rustVariant="stable";}
    ;
  };

  bsysNightly = { unstable = true; } // mkShellDerivation rec {
    inherit prefix;
    flavor = "bsysNightly";
    buildInputs = with (dependencies{});
      base
      ++ code
      ++ rust.nightly
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="nightly"; rustDeps=[ "base" "nightly" ];})
    ;
  };

  rtos =  { unstable = true; } // mkShellDerivation rec {
    inherit prefix;
    flavor = "rtos";
    buildInputs = with (dependencies{});
      base
      ++ osDevelopment
      ++ code
      ++ rust.stable
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="stable"; rustDeps=[ "base" "cross" ];})
    ;
  };

  rtosNightly = { unstable = true; } // mkShellDerivation rec {
    inherit prefix;
    flavor = "rtosNightly";
    buildInputs = with (dependencies{});
      base
      ++ osDevelopment
      ++ code
      ++ rust.nightly
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="nightly"; rustDeps=[ "base" "cross" ];})
    ;
  };

  osdev = { unstable = true; } // mkShellDerivation rec {
    inherit prefix;
    flavor = "osdev";
    buildInputs = with (dependencies{});
      base
      ++ osDevelopment
      ++ code
      ++ linuxDevelopment
      ++ linuxDevelopmentTools
      ++ rust.nightly
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="nightly"; rustDeps=[ "base" "cross" ];})
    ;
  };

  rustWebDev = { unstable = true; } // mkShellDerivation rec {
    inherit prefix;
    flavor = "rustWebDev";
    buildInputs = with (dependencies{});
      base
      ++ code
      ++ rust.nightly
      ++ webDevelopment
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="nightly"; rustDeps=[ "base" "nightly" ];})
    ;
  };

  sysoHW0 = let
    in mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW0";
    buildInputs = with (dependencies{});
      base
      ++ code
    ;
    shellHook = with shellHooks;
      base
      + code
    ;
  };

  sysoHW1 = let
    in mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW1";
    buildInputs = with (dependencies{});
      base
      ++ linuxDevelopment
      ++ linuxDevelopmentStatic
      ++ linuxDevelopmentTools
      ++ code
      ++ rust.stable
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="stable";})
    ;
  };

  sysoHW2 = mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW2";
    buildInputs = with (dependencies{});
      base
      ++ linuxDevelopment
      ++ linuxDevelopmentStatic
      ++ linuxDevelopmentTools
      ++ code
      ++ rust.stable
    ;
    shellHook = with shellHooks;
      base
      + code
      + (rust {rustVariant="stable";})
    ;
  };



  sysoHW3 = { unstable = true; } // mkShellDerivation rec {
    inherit prefix;
    flavor = "sysoHW3";

    buildInputs = with (dependencies{});
      base
      ++ linuxDevelopment
      ++ linuxDevelopmentTools
      ++ code
      ++ rust.stable
    ;

    crosspkgs = crossPkgsAarch64LinuxGnu;
    crossBuildInputs = with (dependencies{ dpkgs = crossPkgsAarch64LinuxGnu; }); [
        linuxDevelopment
    ];

    shellHook = with shellHooks;
        base
        + code
        + (rust {rustVariant="stable";})
        + cross
    ;
  };

  sysoFHS = { unstable = true; } // (pkgs.buildFHSUserEnv rec {
    flavor = "sysoFHS";
    name = "${prefix}_${flavor}";
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

  }; # shellDerivations }

in shellDerivations // {
  sysoHW4 = { unstable = true; } // shellDerivations.sysoHW3.override {
    flavor = "sysoHW4";
  };
  sysoHW5 = { unstable = true; } // shellDerivations.sysoHW3.override {
    flavor = "sysoHW5";
  };
}
