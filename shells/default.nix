{ pkgs
, callPackage
}: 

let 
  mkShellDerivation = callPackage ./mkShellDerivation.nix;

  dependencies = {
    base = 
      with pkgs; [
        bashInteractive
        man
        less
        stdmanpages
        which
        bashInteractive 
        nix
      ];

    code = 
      with pkgs; [
        git
        bats
        sublime3
        vscode
        atom
      ];

    rust = 
      (with pkgs;[
        rustfmt
        rustracer 
      ]) ++ 
      (with pkgs.rustStable;[
        rustc cargo
      ]);
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
  };
}
