-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- plugins
require("lazy").setup({
  { "morhetz/gruvbox" },
  { "nvim-lualine/lualine.nvim" },
})

-- colorscheme
vim.o.background = "dark"
vim.cmd("colorscheme gruvbox")

-- line numbers
vim.o.number = true
vim.o.relativenumber = true

vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    vim.o.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.o.relativenumber = true
  end,
})

-- lualine
require("lualine").setup()
