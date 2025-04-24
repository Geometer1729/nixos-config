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

-- Temporary function
local function gvsplit_develop()
  local pos = vim.fn.getpos('.')
  vim.cmd('Gvsplit develop:%')
  vim.fn.setpos('.', pos)
end

-- Bind the command to <leader>d
vim.keymap.set('n', '<leader>de', gvsplit_develop, { desc = 'Git Diff Split with develop branch' })

-- Define the function
local function source_file_if_exists(filepath)
    local status, _ = pcall(vim.cmd, "source " .. filepath)
end

-- Call the function
source_file_if_exists(".vim/vimrc.local")
