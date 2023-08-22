{ pkgs, ...}:
{
  imports = [ ./starship.nix ./direnv.nix ];
  programs.zsh =
    { enable = true;
      enableAutosuggestions = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      plugins = [
        { # gets nix-shell to use zsh
          name = "zsh-nix-shell";
          file = "nix-shell.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "chisui";
            repo = "zsh-nix-shell";
            rev = "v0.5.0";
            sha256 = "0za4aiwwrlawnia4f29msk822rj9bgcygw6a8a6iikiwzjjz0g91";
          };
        }
      ];
      historySubstringSearch =
        { enable = true;
          #searchUpKey="^K";
        };
      autocd = true;
      defaultKeymap = "viins";
      profileExtra =
        ''
        EDITOR=vim
        # Local variable doesn't work for vim scratchpad
        if [ "$(tty)" = "/dev/tty1" ] && ! pgrep -x Xorg >/dev/null
        then
          startx
        fi
        '';
      initExtra = ''
        source ${./helpers.sh}
        source ${./viCursor.sh}
        eval "$(direnv hook zsh)"
        bindkey  clear-screen
        [ -z $TMUX ] && exec tmux
      ''; #If this gets any more substantial it may be time for a file
      localVariables =
        { EDITOR = "vim";
          BROWSER="firefox";
          READER="zathura";
          REPORTTIME=1;
        };
      shellAliases =
        { rs="exec zsh";
          ls="ls -hN --color=auto --group-directories-first";
          grep="grep -E --color=auto";
          sed="sed -E";
          la="ls -A";
          ll="ls -Al";
          mv="mv -i";
          gs="git status";
          dr="direnv reload";
          da="direnv allow";
          rgi="rg -i";
          ":q"="exit";
          du="dust";
          v = "vim";
          g = "git";
          lg = "lazygit";
          fgv = ''
            vim -S .session.vim -c 'silent exec "!rm .session.vim"'
          '';
          # helpers
          zathura="zathura_";
          rm="rm_";
          cd="cd_";
          nix-du="\\nix-du  -s=500mb | dot -Tpng > /tmp/store.png && sxiv /tmp/store.png";
        } //
        ( # always sudo
          builtins.listToAttrs
          ( builtins.map
            (name: {inherit name; value = "sudo ${name}";})
            [ "dd" "systemctl" "mount" "umount" "shutdown" "nixos-rebuild" "eject" ]
          )
        );
        shellGlobalAliases = {
          "..."="../..";
          "...."="../../..";
          "....."="../../../..";
          "......"="../../../../..";
          "......."="../../../../../..";
          "........"="../../../../../../..";
          "........."="../../../../../../../..";
          ".........."="../../../../../../../../..";
          "..........."="../../../../../../../../../..";
          "............"="../../../../../../../../../../..";
          # TODO auto generate this with nix
        };
    };
}
