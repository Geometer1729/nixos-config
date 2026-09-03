require('render-markdown').setup({
  file_types = { 'markdown', 'vimwiki' },
  pipe_table = {
    preset = 'round',
    cell = 'padded',
  },
})
