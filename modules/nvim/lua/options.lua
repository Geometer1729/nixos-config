local o = vim.o
local g = vim.g

-- block global message
o.shortmess = "I"

vim.cmd.colorscheme('joker')
vim.api.nvim_set_hl(0,"NormalFloat",{ctermbg = "black"})

-- enable mouse
o.mouse ="a"
o.clipboard="unnamedplus" -- share system clipboard
o.number=true
-- scroll when 8 lines from the bottom
o.so=8

--search
o.hlsearch=true
o.ignorecase=true
o.smartcase=true
o.expandtab=true

-- sane splits
o.splitbelow=true
o.splitright=true

-- tab stuff
o.tabstop=2
o.softtabstop=0
o.shiftwidth=2
o.smarttab=true

o.undofile=true

-- indent settings
o.ai=true
o.si=true

-- airline
g['airline#extensions#tabline#enabled'] = 1
g['airline#extensions#tabline#left_sep'] = ' '

-- macros
g['@p']="O<Enter>"
g['@c']=[["zdt"P]]
