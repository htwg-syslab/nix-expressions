{ pkgs
, nixpkgsChannelsFetched
, callPackage
, prefix
, mkDerivation
, makeWrapper
}:

let
  mkShellDerivation = callPackage ./mkShellDerivation.nix;

  rustExtended = (pkgs.rustChannels.stable.rust.override { extensions = [ "rust-src" ]; });
  rustExtendedNightly = (pkgs.rustChannels.stable.rust.override { extensions = [ "rust-src" ]; });

  customLesspipe = mkDerivation {
    name = "lesspipe";

    phases = "installPhase";
    installPhase = ''
      set -xe
      mkdir -p $out
      cp -r ${pkgs.lesspipe}/* $out/
      chmod +w $out/bin
      ln -s lesspipe.sh $out/bin/lesspipe
      chmod -w $out/bin
    '';
  };

  bbStatic = pkgs.busybox.override {
    enableStatic=true;
  };

  crossPkgsArmv7aLinuxGnueabihf = ({ pkgsPath }:
    let
      kernelConfig = "defconfig";
      pkgs = import pkgsPath {
        crossSystem = {
          config = "armv7a-linux-gnueabihf";
          bigEndian = false;
          arch = "arm";
          float = "hard";
          withTLS = true;
          libc = "glibc";
          platform = {
            name = "arm";
            kernelMajor = "2.6";
            kernelBaseConfig = kernelConfig;
            kernelHeadersBaseConfig = kernelConfig;
            uboot = null;
            kernelArch = "arm";
            kernelAutoModules = false;
            kernelTarget = "vmlinux.bin";
          };
          openssl.system = "linux-generic32";
          gcc.arch = "armv7-a";
        };
      };
    in pkgs) { pkgsPath = nixpkgsChannelsFetched; };

  crossPkgsArmv5LinuxGnueabi = ({ pkgsPath }:
    let
      kernelConfig = "defconfig";
      pkgs = import nixpkgsChannelsFetched {
        crossSystem = {
          config = "armv5-linux-gnueabi";
          bigEndian = false;
          arch = "armv5";
          float = "soft";
          withTLS = true;
          libc = "glibc";
          platform = {
            name = "arm";
            kernelMajor = "2.6";
            kernelBaseConfig = kernelConfig;
            kernelHeadersBaseConfig = kernelConfig;
            uboot = null;
            kernelArch = "arm";
            kernelAutoModules = false;
            kernelTarget = "vmlinux.bin";
          };
          openssl.system = "linux-generic32";
          gcc.arch = "armv5";
        };
      };
    in pkgs) { pkgsPath = nixpkgsChannelsFetched; };

  crossPkgsAarch64LinuxGnu = ({ pkgsPath }:
    let
			platform = (import "${builtins.toString pkgsPath}/lib/systems/platforms.nix").aarch64-multiplatform;
      pkgs = import pkgsPath {
        crossSystem = {
          config = "aarch64-linux-gnu";
          bigEndian = false;
          arch = "aarch64";
          float = "hard";
          withTLS = true;
          libc = "glibc";
					inherit platform;
          inherit (platform) gcc;
          openssl.system = "linux-generic64";
        };
      };
    in pkgs) { pkgsPath = nixpkgsChannelsFetched; };

  dependencies = {
    base =
      with pkgs; [
        dpkg customLesspipe
        openssh_with_kerberos
        strace
        file
        man
        less
        curl
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
      ];

    admin =
      with pkgs; [
        rsync
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
        cmake
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
        cargo install --list | grep "$CRATE v$CRATE_VERSION" &>> /dev/null
        rc1=$?
        ldd $(which $CRATE 2>/dev/null) &>> /dev/null
        rc2=$?
        if [[ ! $rc1 -eq 0 || ! $rc2 -eq 0 ]]; then
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
    ;
    shellHook = with shellHooks;
      base
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



  sysoHW3 = { unstable = true; } // mkShellDerivation rec {
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
        linuxPackages.kernel.buildInputs
        qemu
        cpio
        zlib
      ]) ++
      []
    ;
    crosspkgs = crossPkgsAarch64LinuxGnu;
    crossBuildInputs = with crossPkgsAarch64LinuxGnu; [
        linuxPackages.kernel.nativeBuildInputs
        linuxPackages.kernel.buildInputs
        busybox.buildInputs
        busybox.nativeBuildInputs
        dropbear.buildInputs
        dropbear.nativeBuildInputs
        zlib zlib.dev
        ncurses ncurses.dev
    ];

    shellHook = with shellHooks;
        base
        + code
        + rust
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
}
