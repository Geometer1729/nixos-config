local g = vim.g
local o = vim.o

g.vimwiki_list = {
  { path = '~/Documents/vw/',
    syntax = 'markdown',
    ext = '.md',
    links_space_char= '_',
    auto_diary_index = 1
  }}

-- Don't conceal markdown in any mode
o.concealcursor=""
-- Tells task wiki not to break this
g.taskwiki_disable_concealcursor=1

-- Default used by `task` command
g.taskwiki_data_location="~/.local/share/task"

-- No folds
g.taskwiki_dont_fold="yes"
g.vimwiki_folding=''
g.foldenable=false
g.foldmethod="syntax"

vim.api.nvim_create_autocmd({'BufNewFile'},
  { pattern = '*Documents/vw/diary/*',
    command = [[silent :0r !cat ~/Documents/vw/templates/diary.md | sed "s/DATE/$(date '+\%m\/\%d\/\%y\ \%A')/g"]]
  }
  )
