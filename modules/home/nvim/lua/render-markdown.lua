require('render-markdown').setup({
  file_types = { 'markdown', 'vimwiki' },
  heading = { enabled = false },
  code = { enabled = false },
  dash = { enabled = false },
  bullet = { enabled = false },
  checkbox = { enabled = false },
  quote = { enabled = false },
  link = { enabled = false },
  sign = { enabled = false },
  latex = { enabled = false },
  inline_highlight = { enabled = false },
  html = { enabled = false },
  yaml = { enabled = false },
  pipe_table = {
    preset = 'round',
    cell = 'padded',
  },
})
