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
      surround.enable = true;
      direnv.enable = true;
      undotree.enable = true;
      fugitive.enable = true;
      startify.enable = true;
      vimtex.enable = true;
      tmux-navigator.enable = true;
      lualine = {
        enable = true;
        sections.lualine_c = [{
          name = "filename";
          extraConfig = {
              path = 1;
          };
        }];
      };
      treesitter = {
        enable = true;
        nixvimInjections = true;
        indent = true;
        ensureInstalled = [
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
          "lean"
          ];
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
