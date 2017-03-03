{ pkgs }:

{
  libxcb_x2go = pkgs.xorg.libxcb.overrideDerivation (oldAttrs: {
    postFixup = ''
      chmod +w $out/lib
      find $out/lib -name "*.so" -exec sed -i --follow-symlinks 's/BIG-REQUESTS/_IG-REQUESTS/' {} \;
      chmod -w $out/lib
    '';
  });
}
