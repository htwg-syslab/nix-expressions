{}:
''
set nocompatible
set mouse=

" leader
let mapleader = ','

set hidden
syntax on
set hlsearch
set number

" mappings to stop insert mode
imap jjj <ESC>
imap kkk <ESC>
imap lll <ESC>
imap hhh <ESC>
set scroll=11

noremap <C-n> :tabn<CR>
noremap <C-p> :tabp<CR>
let g:ctrlp_map = '<tab>'
set wildignore+=*/site/*,*.so,*.swp,*.zip
let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/]\.(git|hg|svn|)$$',
  \ 'file': '\v\.(exe|so|dll)$$',
  \ }

"let g:ctrlp_match_func = { 'match': 'pymatcher#PyMatch' }
"let g:pydiction_location = '~/.vim/bundle/pydiction/complete-dict'

" allways show status line
set ls=2
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
"set textwidth=80

set backspace=indent,eol,start

set wildignore+=*/site/*,*.so,*.swp,*.zip
let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/]\.(git|hg|svn|)$$',
  \ 'file': '\v\.(exe|so|dll)$$',
  \ }
" }

" spelling {{{
au BufRead,BufNewFile *.txt,*.tex,*.md,*.markdown setlocal spell spelllang=en_us,de_de
" }}}

" sync default register to clipboard {
if has('unnamedplus')
  set clipboard=unnamedplus
else
  set clipboard=unnamed
endif
" }

" colored brackets {
let g:rbpt_colorpairs = [
    \ ['brown',       'RoyalBlue3'],
    \ ['Darkblue',    'SeaGreen3'],
    \ ['darkgray',    'DarkOrchid3'],
    \ ['darkgreen',   'firebrick3'],
    \ ['darkcyan',    'RoyalBlue3'],
    \ ['darkred',     'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['brown',       'firebrick3'],
    \ ['gray',        'RoyalBlue3'],
    \ ['black',       'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['Darkblue',    'firebrick3'],
    \ ['darkgreen',   'RoyalBlue3'],
    \ ['darkcyan',    'SeaGreen3'],
    \ ['darkred',     'DarkOrchid3'],
    \ ['red',         'firebrick3'],
    \ ]
let g:rbpt_max = 16
let g:rbpt_loadcmd_toggle = 0

au VimEnter * RainbowParenthesesToggle
au Syntax * RainbowParenthesesLoadRound
au Syntax * RainbowParenthesesLoadSquare
au Syntax * RainbowParenthesesLoadBraces
" }

set t_ut=
colorscheme PaperColor

" Python {{{
augroup ft_python
    au!
    au FileType python setlocal omnifunc=pythoncomplete#Complete
    au FileType python setlocal define=^\s*\\(def\\\\|class\\)
augroup END
" }}}

" YAML {{{
augroup ft_yaml
    au!
    setlocal autoindent sw=2 et tabstop=2 shiftwidth=2 softtabstop=2
augroup END
" }}}

''

