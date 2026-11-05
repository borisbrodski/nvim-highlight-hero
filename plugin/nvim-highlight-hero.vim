" Title:        Neovim Highlight Hero
" Description:   Highlight multiple words, selections and whole lines; with a
"               merge-friendly mode that matches lines ignoring indentation.
" Maintainer:   Boris Brodski <brodsky_boris@yahoo.com>
" Repository:   https://github.com/borisbrodski/nvim-highlight-hero

" Load guard. Commands, keymaps and highlight groups are created by
" require('nvim-highlight-hero').setup(), so call that from your config.
if exists("g:loaded_nvim_highlight_hero")
    finish
endif
let g:loaded_nvim_highlight_hero = 1
