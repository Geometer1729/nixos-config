local o = vim.o
local g = vim.g

-- I blocks global message
-- W shortens write messages
o.shortmess = "IW"
vim.api.nvim_set_hl(0,"Normal", { bg = "none" })
vim.api.nvim_set_hl(0,"NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0,"NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0,"Pmenu", { bg = "none" })
vim.api.nvim_set_hl(0,"LineNR", { bg = "none" })


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
-- This somewhat fixes an issue with comment indetations in nix
-- Without this comments are always the start of the line
-- With this they seem to be indented just one less?
-- it seems to be related to #define in C
-- I'm not sure what prevents this from being an issue in python or bash
-- It may be possible to fix this by finding a better nix plugin
vim.api.nvim_create_autocmd({'FileType'},
  { pattern = 'nix',
    callback = function ()
      o.si=false
      o.cinkeys="0{,0},!^F,o,O,e"
      o.cindent=true
    end
  })

-- only one status bar
o.laststatus=3

-- macros
g['@p']="O<Enter>"
g['@c']=[["zdt"P]]
