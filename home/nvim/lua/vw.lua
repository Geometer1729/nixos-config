local g = vim.g

g.vimwiki_list = {
  { path = '~/Documents/vw/',
    syntax = 'markdown',
    ext = '.md'
  }
  }

vim.cmd.highlight({"link","VimWikiHeader1","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader2","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader3","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader4","Identifier"})
vim.cmd.highlight({"link","VimWikiHeader5","Identifier"})
