local telescope = require('telescope.builtin')
local t = require('telescope')

local g = vim.g
local o = vim.o
local fn = vim.fn

local function map(m, k, v)
    vim.keymap.set(m, k, v, { silent = true })
end

g.mapleader=' '

map('n','<Leader>o',
  function ()
    o.spell=true
    o.spelllang="en_us"
    vim.cmd.highlight({"SpellBad","cterm=undercurl"})
  end
  )

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
vim.api.nvim_create_user_command('W'
  ,[[
  silent! write !sudo tee % >/dev/null
  edit!
  ]],{})


map('n','<Leader>pv',vim.cmd.Ex)

map('n','<Return>', function()
  vim.cmd('noh')
  -- Close floating windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= '' then
      vim.api.nvim_win_close(win, false)
    end
  end
end)

map('n','<C-s>','<cmd>mksession! .session.vim<cr><cmd>qa!<cr>')

-- Telescope
map('n','<Leader>ff',telescope.live_grep)
map('n','<Leader>fw',t.extensions.vw.live_grep)
map('n','<Leader>fg',telescope.git_files)
map('n','<Leader>fa',telescope.find_files)
map('n','<Leader>fh',telescope.help_tags)

-- UndoTree
map('n','<Leader>u',vim.cmd.UndotreeToggle)

--Fugitiv
map('n','<Leader>gs',vim.cmd.Git)

--primagen tweaks
map('n','J','mzJ`z') -- hold cursor on J
map('n','n','nzzzv')
map('n','N','Nzzzv')
map('n','<leader>d','\"_d')

map('n','<Leader>jq','<cmd>.!jq<cr>')

--vimtex
map('n','<Leader>ll',vim.cmd.VimtexCompile)

-- task link
map('v','<Leader>t',
  function ()
  vim.cmd([[:'<,'>w !gen-task-link]]);
  vim.cmd([[:r /tmp/task-link]]);
  end
  )

local function toggle_nerdtree_with_buffers()
      local buffers = vim.tbl_filter(function(b)
          return vim.api.nvim_get_option_value('buflisted',{buf=b})
      end, vim.api.nvim_list_bufs())

      for _, buf in ipairs(buffers) do
          local bufname = fn.fnamemodify(fn.bufname(buf), ':p')
          vim.cmd('NERDTreeFind ' .. bufname)
      end
      vim.cmd('NERDTreeToggle')
end


map('n','<Leader>tt',toggle_nerdtree_with_buffers)

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if vim.fn.bufname('#') ~= "" and
       vim.fn.bufname('#'):match('NERD_tree_%d+') and
       vim.fn.bufname('%'):match('NERD_tree_%d+') == nil and
       vim.fn.winnr('$') > 1
    then
      local buf = vim.fn.bufnr()
      vim.cmd('buffer#')
      vim.cmd('execute "normal! \\<C-W>w"')
      vim.cmd('execute "buffer' .. buf .. '"')
    end
  end
})


-- Prevents fork bomb when editing this file
vim.api.nvim_clear_autocmds({
  event = "BufWritePost",
  pattern = "*.lua",
})
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.lua",
  callback = function()
    vim.cmd("luafile " .. vim.fn.expand("%"))
    print("Reloaded config")
  end,
})
