{ pkgs, lib, ...}:
{
  programs.neovim =
    { enable = true;
      vimAlias = true;
      # builtins.readFile ./lua/init.lua;
      extraConfig =
        lib.strings.concatStrings
          ( builtins.map
            (name: "luafile ${./lua}/${name}\n")
            (builtins.attrNames (builtins.readDir ./lua))
          );

        plugins = with pkgs.vimPlugins;
          let
            vim-j = pkgs.vimUtils.buildVimPlugin
              { name = "vim-j";
                src = pkgs.fetchFromGitHub {
                  owner = "Geometer1729";
                  repo = "vim-j";
                  rev = "dcf2357339fbe1b7ac4125a323dbe0f8ff4937cc";
                  sha256 = "sha256-QSM8tR2RtL34lBqzn3pifO73qsLroZyPEiFsW/Hn/KI=";
                };
              }; # TODO just use default vim-j and set background
          in
          [ airline # status line
            purescript-vim # there is currently no treesitter purescript
            telescope-nvim # finder
            (nvim-treesitter.withPlugins
              (p: with p; [ lua vim vimdoc rust haskell nix typescript markdown ])
            )
            surround # I should use this more
            direnv-vim # should make lsp restarts include direnv reloads?
            nerdtree # file browser
            hoogle
            vim-j # my color scheme
            vimwiki
            undotree
            fugitive # :Git thing

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
