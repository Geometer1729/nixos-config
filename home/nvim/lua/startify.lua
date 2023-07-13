local g = vim.g

g.startify_custom_header = {}

g.startify_lists = {
  { type= 'bookmarks', header = {'[Bookmarks]'} },
  { type= 'files', header = {'[MRU]'} }
  -- { type= 'dir', header = {'[Dir MRU]'} }
  -- probably not worth the delay on 1
  }
g.startify_bookmarks =
  { {c='~/conf/flake.nix'},
    {w='~/Documents/vw/index.md'}
  }
