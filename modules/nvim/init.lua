local o = vim.o
local g = vim.g

local function map(m, k, v)
    vim.keymap.set(m, k, v, { silent = true })
end

-- block global message
o.shortmess = "I"

vim.cmd.colorscheme('joker')

-- enable mouse
o.mouse ="a"
o.clipboard="unnamedplus" -- share system clipboard
o.number=true
-- o.encoding="utf-8"
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
g['@c']='\"zdt\"P'

map('n','<leader>cr','<CMD>CocRestart<CR><CR>')
map('n','<leader>o','<CMD>Spell<CR>')

local dirKeys = "hjkl"
for i = 1,#dirKeys do
  local c = dirKeys:sub(i,i)
  local key = '<C-'..c..'>'
  local action = '<C-w>'..c
  map('n',key,action)
  map('t',key,'<C-\\><C-n>'..action)
end

--map('n','S','<CMD>%s//g<Left><Left>')
--cmd without cr is not allowed
vim.cmd('nnoremap S :%s//g<Left><Left>')
vim.cmd([[cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit!]])


-- Telescope
map('n','<leader>ff','<cmd>Telescope git_files<cr>')
map('n','<leader>fg','<cmd>Telescope live_grep<cr>')
map('n','<leader>fa','<cmd>Telescope find_files<cr>')


-- Coc
map('n','<Leader>gd','<Plug>(coc-definition)')
map('n','<Leader>gh',[[<cmd>:call CocActionAsync('doHover')<cr>]])
map('n','<Leader>gn','<Plug>(coc-diagnostic-next)')
map('n','<Leader>gp','<Plug>(coc-diagnostic-prev)')
map('n','<Leader>al',[[<Plug>(coc-codeaction-line)<cmd>:w<cr>]])
map('n','<Leader>ac','<Plug>(coc-codeaction-cursor)')
