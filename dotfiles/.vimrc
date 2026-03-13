" ----------------------------
" General
" ----------------------------

set nocompatible
syntax on
set number
set relativenumber
set ruler
set showcmd
set showmode

set encoding=utf-8
set fileencoding=utf-8

set hidden
set nowrap

" ----------------------------
" Indentation
" ----------------------------

set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set autoindent

" YAML (Ansible)
autocmd FileType yaml setlocal tabstop=2 shiftwidth=2 expandtab

" ----------------------------
" Search
" ----------------------------

set ignorecase
set smartcase
set incsearch
set hlsearch

" clear search highlight
nnoremap <leader><space> :nohlsearch<CR>

" ----------------------------
" Clipboard macOS
" ----------------------------

set clipboard=unnamed

" copy to system clipboard
vnoremap <leader>y "+y
nnoremap <leader>y "+yy

" paste from clipboard
nnoremap <leader>p "+p

" ----------------------------
" UI
" ----------------------------

set cursorline
set wildmenu
set background=dark
set termguicolors

" ----------------------------
" File handling
" ----------------------------

set autoread
set nobackup
set nowritebackup
set noswapfile

" ----------------------------
" Navigation
" ----------------------------

set scrolloff=5

" easier window switching
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

