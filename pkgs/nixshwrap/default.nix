{ pkgs
, mkDerivation
, writeScript
, shDrvAttr 
, shDrv
}: 

mkDerivation rec {
  name = "nixshwrap";
  version = "0.1.0";
  src = writeScript "nixSHwrap" ''
    #! ${pkgs.nix}/bin/nix-shell
    #! nix-shell --argstr shDrv ${shDrv}
    #! nix-shell -A ${shDrvAttr} 
    #! nix-shell ${shDrv}
  '';
  unpackCmd = ''
    mkdir src
    cp $src src/${name}
  '';

  installPhase  = ''
    pwd
    ls -lha
    mkdir -p $out/bin
    cp ${name} $out/bin/${name}
    chmod +x $out/bin/${name}
  '';
}
