{ pkgs
, name
, additionalRC ? ""
, additionalPlugins ? []
, ... } @ args :

pkgs.vim_configurable.customize {
  inherit name;
  # add custom .vimrc lines like this:
  vimrcConfig.customRC = (import ./commonrc.nix { inherit pkgs; }) + ''
  '' + additionalRC;

  vimrcConfig.vam.knownPlugins = pkgs.vimPlugins; # optional
  vimrcConfig.vam.pluginDictionaries = [{
    # full ducomentation at github.com/MarcWeber/vim-addon-manager
    names = [
      "vim-addon-vim2nix"
      "vim-airline"
      "vim-addon-nix"
      "ctrlp"
      "syntastic"
      "vim-css-color"
      "rainbow_parentheses"
      "vim-colorschemes"
      "vim-colorstepper"
      "vim-signify"
      "youcompleteme"
    ] ++ additionalPlugins;
  }];
}
