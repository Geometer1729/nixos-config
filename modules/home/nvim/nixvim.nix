{ pkgs, lib, nixpkgsSource ? null, pluginSources }:
{
  version.enableNixpkgsReleaseCheck = false;
  nixpkgs = lib.optionalAttrs (nixpkgsSource != null) {
    source = nixpkgsSource;
  };
  viAlias = true;
  vimAlias = true;
  extraPackages = with pkgs; [
    tree-sitter # Required by nvim-treesitter for grammar compilation
    fd # Required by telescope for faster file finding
    curl # Required by nvim-treesitter for downloading parsers
    ripgrep # Required by telescope for live-grep
  ];
  # neovim (nixpkgs>=2026-03-24) now uses luajit-env for require() resolution
  # instead of runtimepath. Plugins that use require() across plugins need to
  # be declared here so their Lua modules are findable.
  extraLuaPackages = ps: with ps; [ plenary-nvim ];
  extraConfigLua =
    lib.strings.concatStrings
      (builtins.map
        (name: builtins.readFile "${./lua}/${name}")
        (builtins.attrNames (builtins.readDir ./lua))
      );
  plugins = {
    telescope.enable = true;
    which-key.enable = true;
    web-devicons.enable = true;
    vim-surround.enable = true;
    direnv.enable = true;
    undotree.enable = true;
    fugitive.enable = true;
    startify.enable = true;
    vimtex.enable = true;
    trouble.enable = true;
    tmux-navigator.enable = true;
    lazygit.enable = true;
    lualine.enable = true;
    treesitter = {
      enable = true;
      nixvimInjections = true;
      folding.enable = false;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        ensureInstalled = [
          "lean"
          "lua"
          "vim"
          "vimdoc"
          "rust"
          "haskell"
          "nix"
          "typescript"
          "markdown"
          "markdown_inline"
          "c"
          "ocaml"
          "dhall"
        ];
      };
    };
  };
  extraPlugins = with pkgs.vimPlugins;
    [
      vim-hoogle
      vimwiki
      nerdtree
      purescript-vim
      (pkgs.vimUtils.buildVimPlugin
        {
          name = "telescope-vimwiki";
          src = pluginSources.telescope-vimwiki-nvim;
        })
      (pkgs.vimUtils.buildVimPlugin
        {
          name = "nvim-luaref";
          src = pluginSources.nvim-luaref;
        })
      (pkgs.vimUtils.buildVimPlugin
        {
          name = "ocaml.nvim";
          src = pluginSources.ocaml-nvim;
        })

      (pkgs.vimUtils.buildVimPlugin
        {
          name = "Recover.vim";
          src = pluginSources.recover-vim;
        })

      # LSP
      nvim-lspconfig
      # cmp
      nvim-cmp
      cmp-vsnip
      vim-vsnip
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      cmp-omni
    ];
}
