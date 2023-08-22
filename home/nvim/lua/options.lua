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
-- This fixes an issue with comment indetations in nix
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

-- airline
g['airline#extensions#tabline#enabled'] = 1
g['airline#extensions#tabline#left_sep'] = ' '
o.laststatus=3

-- macros
g['@p']="O<Enter>"
g['@c']=[["zdt"P]]
