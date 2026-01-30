{ pkgs, lib }:
{
  viAlias = true;
  vimAlias = true;
  extraPackages = with pkgs; [
    tree-sitter # Required by nvim-treesitter for grammar compilation
    fd # Required by telescope for faster file finding
    curl # Required by nvim-treesitter for downloading parsers
    ripgrep # Required by telescope for live-grep
  ];
  extraConfigLua =
    lib.strings.concatStrings
      (builtins.map
        (name: builtins.readFile "${./lua}/${name}")
        (builtins.attrNames (builtins.readDir ./lua))
      );
  plugins = {
    telescope.enable = true;
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
      hoogle
      vimwiki
      nerdtree
      purescript-vim
      (pkgs.vimUtils.buildVimPlugin
        {
          name = "telescope-vimwiki";
          src = pkgs.fetchFromGitHub {
            owner = "ElPiloto";
            repo = "telescope-vimwiki.nvim";
            rev = "13a83b6107da17af9eb8a1d8e0fe49e1004dfeb4";
            sha256 = "sha256-46N1vMSu1UuzPFFe6Yt39s3xlKPOTErhPJbfaBQgq7g=";
          };
        })
      (pkgs.vimUtils.buildVimPlugin
        {
          name = "nvim-luaref";
          src = pkgs.fetchFromGitHub {
            owner = "milisims";
            repo = "nvim-luaref";
            rev = "dc40d606549db7df1a6e23efa743c90c178333d4";
            sha256 = "sha256-GscwQpo0stDLkcfeeLhjciT/y7k2u0CO9vaGswazISo=";
          };
        })
      (pkgs.vimUtils.buildVimPlugin
        {
          name = "ocaml.nvim";
          src = pkgs.fetchFromGitHub {
            owner = "andreypopp";
            repo = "ocaml.nvim";
            rev = "c192e71dddb5b4f506873b4a6eb3a900e1d89d3f";
            sha256 = "sha256-xThnPcDYaCTxlY92PKOmoZEtxTg3cAWj1yRa5ud+2ps=";
          };
        })

      (pkgs.vimUtils.buildVimPlugin
        {
          name = "Recover.vim";
          src = pkgs.fetchFromGitHub {
            owner = "chrisbra";
            repo = "Recover.vim";
            rev = "e61319bce3cd1004e5b695933296d8f267dd65a3";
            sha256 = "sha256-BPvxcvC4Il9NkyY3qmAKAraORNYQNiyOvM+5DRTh3EI=";
          };
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
    ];
}
