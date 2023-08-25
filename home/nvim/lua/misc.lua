vim.api.nvim_create_autocmd({'BufNewFile','BufRead'},
  { pattern = 'flake.lock',
    callback = function ()
      vim.o.filetype='json'
    end
  })
