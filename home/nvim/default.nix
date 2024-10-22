{ pkgs, lib, ... }:
{
  programs.nixvim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
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
      trouble.enable=true;
      tmux-navigator.enable = true;
      lualine = {
        enable = true;
        settings = {
          sections = {
            lualine_c = [
              "filename"
              { path = 1; }
            ];
          };
        };
      };
      treesitter = {
        enable = true;
        nixvimInjections = true;
        folding = false;
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
            "c"
            "ocaml"
            ];
        };
      };
    };
      extraPlugins =  with pkgs.vimPlugins;
        [ hoogle
          vimwiki
          nerdtree
          purescript-vim
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
  };
}
