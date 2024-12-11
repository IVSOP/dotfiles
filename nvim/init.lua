require("config.lazy")

--require('nvim-juliana').colors()
vim.cmd.colorscheme("juliana")

local o = vim.opt
o.expandtab = true -- expand tab input with spaces characters
o.smartindent = true -- syntax aware indentations for newline inserts
o.tabstop = 4 -- num of space characters per tab
o.shiftwidth = 4 -- spaces per indentation level
o.number = true
o.relativenumber = true
o.signcolumn = "yes" -- space created by gitsigns is always there
o.termguicolors = true
o.pumblend = 0 -- transparency of popup

-- take warnins out of the left
vim.diagnostic.config({
    signs = false
})

