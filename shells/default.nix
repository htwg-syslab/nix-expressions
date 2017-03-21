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
  };

  shell_bsys = mkShellDerivation rec {
    name = "shell_bsys";
    buildInputs = with dependencies;
      base
      ++ code
      ++ rust
    ;
    shellHook = with shellHooks;
      rust
    ;
  };

  shell_sysoV1 = mkShellDerivation rec {
    name = "shell_sysoV1";
    buildInputs = 
      (with dependencies;
        base
        ++ code)
        ++
      (with pkgs; [
        busybox.nativeBuildInputs
        gcc
        cpio
      ])
    ;
    shellHook = with shellHooks;
    ''
        export hardeningDisable=all
    ''
    ;
  };

  shell_sysoV2 = mkShellDerivation rec {
    name = "shell_sysoV2";
    buildInputs = 
      (with dependencies;
        base
        ++ code)
        ++
      (with pkgs; [
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
