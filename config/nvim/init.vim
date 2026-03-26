call plug#begin('~/.local/share/nvim/plugged')

Plug 'morhetz/gruvbox'

call plug#end()

" === Theme ===
set termguicolors
set background=dark
colorscheme gruvbox
let g:gruvbox_contrast_dark = 'medium'

call plug#begin('~/.local/share/nvim/plugged')

Plug 'morhetz/gruvbox'
Plug 'nvim-lualine/lualine.nvim'

call plug#end()

lua << END
require('lualine').setup {
  options = {
    theme = 'gruvbox',
    section_separators = '',
    component_separators = ''
  }
}
END

" === Basics (Mini-Upgrade) ===
syntax on
set number
set relativenumber
set cursorline
set mouse=a
