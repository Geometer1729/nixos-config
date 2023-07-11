local telescope = require('telescope.builtin')

local g = vim.g

local function map(m, k, v)
    vim.keymap.set(m, k, v, { silent = true })
end

g.mapleader=' '

map('n','<Leader>o','<CMD>Spell<CR>')

local dirKeys = "hjkl"
for i = 1,#dirKeys do
  local c = dirKeys:sub(i,i)
  local key = '<C-'..c..'>'
  local action = '<C-w>'..c
  map('n',key,action)
  map('t',key,'<C-\\><C-n>'..action)
end
map('t','<C-n>','<C-\\><C-n>')

--map('n','S','<CMD>%s//g<Left><Left>')
--cmd without cr is not allowed
vim.cmd('nnoremap S :%s//g<Left><Left>')
vim.cmd([[cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit!]])

map('n','<Leader>pv',vim.cmd.Ex)

map('n','<Return>','<cmd>noh<cr>')
-- TODO close floating windows too

map('n','<C-s>','<cmd>mksession! .session.vim<cr><cmd>qa!<cr>')

-- Telescope
map('n','<Leader>ff',telescope.live_grep)
map('n','<Leader>fg',telescope.git_files)
map('n','<Leader>fa',telescope.find_files)

-- UndoTree
map('n','<Leader>u',vim.cmd.UndotreeToggle)

--Fugitiv
map('n','<Leader>gs',vim.cmd.Git)

--primagen tweaks
map('n','J','mzJ`z') -- hold cursor on J
map('n','n','nzzzv')
map('n','N','Nzzzv')
map('n','<leader>d','\"_d')
