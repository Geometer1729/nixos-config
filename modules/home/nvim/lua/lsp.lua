local lsp = require('lspconfig')

local signs = { Error = "E", Warn = "W", Hint = "H", Info = "I" }

vim.api.nvim_set_hl(0,"NormalFloat",{ctermbg = "black"})

lsp.hls.setup { cmd = { "haskell-language-server", "--lsp" } }
lsp.leanls.setup{}
lsp.purescriptls.setup {}
lsp.rust_analyzer.setup {}
lsp.ts_ls.setup {} -- typescript
lsp.ocamllsp.setup{}
lsp.nixd.setup({
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
})

lsp.lua_ls.setup {
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

vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    print("LSP Ready")
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

-- TODO use autocmd syntax

-- show diagnostics for current line
vim.cmd([[autocmd CursorMoved * lua vim.diagnostic.open_float(nil, {focus=false})]])

-- remove trailing white spece
vim.cmd([[autocmd BufWritePre * %s/\s\+$//e]])


