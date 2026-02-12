local signs = { Error = "E", Warn = "W", Hint = "H", Info = "I" }

vim.api.nvim_set_hl(0,"NormalFloat",{ctermbg = "black"})

vim.lsp.config.hls = { cmd = { "haskell-language-server", "--lsp" } }
vim.lsp.config.leanls = {}
vim.lsp.config.purescriptls = {}
vim.lsp.config.rust_analyzer = {
  cmd = { "rust-analyzer" },
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures = true,
      },
      checkOnSave = {
        command = "clippy",
      },
      procMacro = {
        enable = true,
      },
    },
  },
}
vim.lsp.config.ts_ls = {} -- typescript
vim.lsp.config.nixd = {
  cmd = { "nixd" },
  settings = {
    nixd = {
      nixpkgs = {
        expr = "import <nixpkgs> { }",
      },
      formatting = {
        command = { "alejandra" }, -- or nixfmt or nixpkgs-fmt
      },
      options = {
        nixos = {
            expr = '(builtins.getFlake "/home/bbrian/conf").nixosConfigurations.am.options',
        },
        home_manager = {
            expr = '(builtins.getFlake "/home/bbrian/conf").legacyPackages.x86_64-linux.homeConfigurations.bbrian.options',
        },
      },
    },
  }
}

vim.lsp.config.lua_ls = {
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

vim.lsp.config.sqls = {
  cmd = { "sqls" },
}

-- Enable LSP servers for their respective filetypes
vim.lsp.enable('hls')
vim.lsp.enable('leanls')
vim.lsp.enable('purescriptls')
vim.lsp.enable('rust_analyzer')
vim.lsp.enable('ts_ls')
vim.lsp.enable('nixd')
vim.lsp.enable('lua_ls')
vim.lsp.enable('sqls')

vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1 }) end)
vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count = 1 }) end)

local lsp_progress = {}

vim.api.nvim_create_autocmd('LspProgress', {
  callback = function(ev)
    local client_id = ev.data.client_id
    local value = ev.data.params.value
    local token = ev.data.params.token

    if not lsp_progress[client_id] then
      lsp_progress[client_id] = {}
    end

    if value.kind == 'begin' then
      lsp_progress[client_id][token] = value.title or true
    elseif value.kind == 'end' then
      lsp_progress[client_id][token] = nil
      if next(lsp_progress[client_id]) == nil then
        local client = vim.lsp.get_client_by_id(client_id)
        local name = client and client.name or "LSP"
        print(name .. " Ready")
      end
    end
  end,
})

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', '<leader>r',
      function ()
        print("Restarting")
        vim.lsp.stop_client(vim.lsp.get_clients())
        vim.cmd('e')
      end
      , opts)
    vim.keymap.set('n', '<leader>gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', '<leader>gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', '<leader>h', function() vim.lsp.buf.hover({border="single"}) end, opts)
    vim.keymap.set('n', '<leader>gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>a', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<leader>f', function()
      vim.diagnostic.goto_next()
      vim.lsp.buf.code_action()
    end, opts)
  end,
})

vim.diagnostic.config({
    virtual_text = true,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = signs.Error,
            [vim.diagnostic.severity.WARN] = signs.Warn,
            [vim.diagnostic.severity.HINT] = signs.Hint,
            [vim.diagnostic.severity.INFO] = signs.Info,
        }
    },
    underline = true,
    severity_sort = true,
    float = {
      wrap = true,
      border = "rounded"
    }
})

-- show diagnostics for current line after cursor is idle
vim.api.nvim_create_autocmd('CursorHold', {
  callback = function()
    vim.diagnostic.open_float(nil, {focus=false, scope='line'})
  end,
})

-- remove trailing white space
vim.api.nvim_create_autocmd('BufWritePre', {
  callback = function()
    vim.cmd('%s/\\s\\+$//e')
  end,
})


