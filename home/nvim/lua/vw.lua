local g = vim.g

g.vimwiki_list = {
  { path = '~/Documents/vw/',
    syntax = 'markdown',
    ext = '.md',
    links_space_char= '_',
    auto_diary_index = 1
  }}

vim.cmd.highlight({"link","VimWikiHeader1","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader2","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader3","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader4","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader5","Identifier"})

-- Default used by `task` command
g.taskwiki_data_location="~/.local/share/task"

-- No folds
g.taskwiki_dont_fold="yes"
g.vimwiki_folding=''

vim.api.nvim_create_autocmd({'BufNewFile'},
  { pattern = '*Documents/vw/diary/*',
    command = [[silent :0r !cat ~/Documents/vw/templates/diary.md | sed "s/DATE/$(date '+\%m\/\%d\/\%y\ \%A')/g"]]
  }
  )


