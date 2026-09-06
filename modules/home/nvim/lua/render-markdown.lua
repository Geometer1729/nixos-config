require('render-markdown').setup({
  file_types = { 'markdown', 'vimwiki' },
  heading = {
    sign = false,
    icons = {},
  },
  bullet = {
    enabled = false,
  },
  pipe_table = {
    preset = 'round',
    cell = 'padded',
  },
})
