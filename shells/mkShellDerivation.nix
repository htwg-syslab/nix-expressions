{ flavor
, prefix
, callPackage
, mkDerivation
, buildInputs
, shellHook ? ""
, labshellExpressionsLocal
, makeWrapper
, writeTextFile
, nixpkgs
, shellpkgs
}:
let
  customLabshellShell = shellpkgs.labshell.override {
      inherit flavor;
      makeWrapperArgs = ''\
        --set LABSHELL_UPDATE 0 \
        --set LABSHELL_FLAVOR ${flavor} \
      '';
  };

  customLabshellInteractive = shellpkgs.labshell.override {
      inherit flavor;
      makeWrapperArgs = ''\
        --set LABSHELL_FLAVOR ${flavor} \
      '';
  };

in mkDerivation {
  name = "${prefix}_${flavor}";
  buildInputs = with shellpkgs; [
    glibcLocales
    makeWrapper
    labshell
  ] ++ buildInputs;
  phases = "installPhase";
  installPhase = ''
    mkdir -p $out/bin
    ln -sf ${customLabshellInteractive.wrapperPath} $out/bin/
  '';
  shellHookFile = writeTextFile { name = "rcFile"; text = ''
    function exitstatus() {
      if [[ $? -eq 0 ]]; then
        printf '✓'
      else
        printf '✗'
      fi
    }
    function nixshellEval {
      if [[ "$1" != "" ]]; then
        printf "»$1@$SHLVL« "
      fi
    }
    function setPS1 {
      if test "$TERM" != "dumb"; then
        # Provide a nice prompt.
        BLUE="\[\033[0;34m\]"
        RED="\[\033[1;31m\]"
        GREEN="\[\033[1;32m\]"
        NO_COLOR="\[\033[0m\]"

        PROMPT_COLOR=$RED
        let $UID && PROMPT_COLOR=$GREEN
        PS1="$PROMPT_COLOR\u$NO_COLOR@\h \$(exitstatus) \$(nixshellEval $1)$BLUE\w$NO_COLOR\n$PROMPT_COLOR\\$ $NO_COLOR"
        if test "$TERM" = "xterm"; then
          PS1="\[\033]2;\h:\u:\w\007\]$PS1"
        fi
      fi
    }

    export NIX_PATH=shellpkgs=${shellpkgs.path}:nixpkgs=${nixpkgs.path}
    export NIX_REMOTE=daemon
    export SHELL=${customLabshellShell.wrapperPath}
    export LABSHELL_FLAVOR_INSTANTIATED=${flavor}

    setPS1 ${flavor}

    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
  '' + shellHook;
  };
  shellHook = ''
    source $shellHookFile
  '';
}
