{ config, pkgs, lib, ...}:
{
  programs.neovim =
    { enable = true;
      vimAlias = true;
      extraLuaConfig = builtins.readFile ./init.lua;

      coc= {
        enable = true;
        settings.languageserver= {
            purescript= {
              command= "purescript-language-server";
              args= ["--stdio"];
              filetypes= ["purescript"];
              rootPatterns= ["output"];
              trace.server= "off";
              settings= {
                purescript= {
                  addSpagoSources= true;
                  addNpmPath= true;
                };
              };
            };
            haskell= {
              command= "haskell-language-server";
              args= ["--lsp"];
              filetypes= ["hs" "lhs" "haskell" "lhaskell"];
              rootPatterns= ["*.cabal" "stack.yaml" "cabal.project" "package.yaml"  "hie.yaml"];
              initializationOptions.languageServerHaskell.hlintOn=true;
            };
            rust= {
              command = "rust-analyzer";
              filetypes = ["rust"];
              rootPatterns = ["Cargo.toml"];
            };
            #nix = { # TODO this doesn't work can I get something good for nix?
            #  command = "rnix-lsp";
            #  filetypes = [ "nix" ];
            #};
          };
        };
        # TODO look into telescope

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
              };
          in
          [ syntastic
            airline
            commentary
            haskell-vim
            purescript-vim
            surround
            nerdtree
            vimwiki
            hoogle
            vim-nix
            vim-j
            telescope-nvim
            nvim-treesitter
          ];
     };
}
