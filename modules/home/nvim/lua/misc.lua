vim.api.nvim_create_autocmd({'BufNewFile','BufRead'},
  { pattern = 'flake.lock',
    callback = function ()
      vim.o.filetype='json'
    end
  })

require('lualine').setup {
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c =  { { "filename", path = 1 , } },
    lualine_x = {'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c =  { { "filename", path = 1 , } },
    lualine_x = {'location'},
    lualine_z = {}
  },
};
