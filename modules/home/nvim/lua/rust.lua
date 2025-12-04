-- Rust development keybindings and utilities

local function map(m, k, v)
    vim.keymap.set(m, k, v, { silent = true })
end

-- Set up cargo compiler for Rust files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    -- Set makeprg to use cargo
    vim.opt_local.makeprg = "cargo"

    -- Set errorformat for cargo output
    vim.opt_local.errorformat = {
      "%Eerror: %m",
      "%Eerror[E%n]: %m",
      "%Wwarning: %m",
      "%Inote: %m",
      "%C %#--> %f:%l:%c",
      "%-G%.%#"
    }
  end
})

-- Rust-specific keybindings (only active in Rust files)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = false }

    -- <leader>cb - Cargo Build
    vim.keymap.set('n', '<leader>cb', function()
      vim.cmd('make build')
      vim.cmd('copen')
    end, opts)

    -- <leader>cc - Cargo Check (faster than build)
    vim.keymap.set('n', '<leader>cc', function()
      vim.cmd('make check')
      vim.cmd('copen')
    end, opts)

    -- <leader>ct - Cargo Test
    vim.keymap.set('n', '<leader>ct', function()
      vim.cmd('make test')
      vim.cmd('copen')
    end, opts)

    -- <leader>cr - Cargo Run
    vim.keymap.set('n', '<leader>cr', function()
      vim.cmd('make run')
      vim.cmd('copen')
    end, opts)

    -- <leader>cw - Cargo Clippy (linter)
    vim.keymap.set('n', '<leader>cw', function()
      vim.cmd('make clippy')
      vim.cmd('copen')
    end, opts)

    print("Rust keybindings loaded: <leader>c[b|c|t|r|w]")
  end
})

-- Quickfix navigation keybindings (global, work in any file type)
-- [q and ]q to jump between quickfix errors
map('n', '[q', '<cmd>cprev<cr>zz')
map('n', ']q', '<cmd>cnext<cr>zz')

-- [Q and ]Q to jump to first/last error
map('n', '[Q', '<cmd>cfirst<cr>zz')
map('n', ']Q', '<cmd>clast<cr>zz')

-- <leader>q to toggle quickfix window
map('n', '<leader>q', function()
  local qf_exists = false
  for _, win in pairs(vim.fn.getwininfo()) do
    if win["quickfix"] == 1 then
      qf_exists = true
      break
    end
  end
  if qf_exists then
    vim.cmd('cclose')
  else
    vim.cmd('copen')
  end
end)

-- Automatically open quickfix window after :make, but keep focus on current window
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  pattern = "[^l]*",
  callback = function()
    vim.cmd('cwindow')
  end
})
