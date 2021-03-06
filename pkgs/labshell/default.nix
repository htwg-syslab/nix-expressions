{ mkDerivation
, labshellExpressionsRemoteURL
, labshellExpressionsLocal
, makeWrapper
, flavor ? ""
, makeWrapperArgs ? ""
}:

let
  binarySuffix = if flavor == "" then "" else "_${flavor}";
  relativeWrapperPath = "bin/labshell${binarySuffix}";
  drv = mkDerivation rec {
    passthru.wrapperPath = drv+"/"+relativeWrapperPath;

    name = "labshell${binarySuffix}";
    version = "0.2.0";
    src = labshellExpressionsLocal;
    unpackPhase = ":";
    buildInputs = [
      makeWrapper
    ];

    installPhase  = ''
      mkdir -p $out/bin
      echo Wrapping ${src}/pkgs/labshell/src/labshell.sh
      if [[ "${src}" == "/nix/store"* ]]; then
        cp ${src}/pkgs/labshell/src/labshell.sh $out/labshell.sh
      else 
        ln -s ${src}/pkgs/labshell/src/labshell.sh $out/labshell.sh
      fi
      makeWrapper $out/labshell.sh $out/${relativeWrapperPath} \
        --no-assert \
        --set LABSHELL_EXPRESSIONS_LOCAL $\{LABSHELL_EXPRESSION_LOCAL:-${labshellExpressionsLocal}\} \
        --set LABSHELL_EXPRESSIONS_REMOTE_URL $\{LABSHELL_EXPRESSIONS_REMOTE_URL:-${labshellExpressionsRemoteURL}\} ${makeWrapperArgs}
    '';
  };
in drv
