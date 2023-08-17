{ pkgs, ...}:
{
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
        [ -z $TMUX ] && tmux
      ''; #If this gets any more substantial it may be time for a file
      localVariables =
        { EDITOR = "vim";
          BROWSER="firefox";
          READER="zathura";
          TERM="xterm-256color";
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

  programs.starship =
    { enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = false;
        format =
        "$status$username$hostname$directory$git_branch$git_status$memory_usage$time$nix_shell\n$character";
        character.format = "[❯](bold green)";
        status.disabled=false;
        nix_shell =
          { format= "[$symbol]($style) ";
            style="bold cyan";
          };
        directory =
          { truncation_length = 5;
            format = "[$path]($style)[$lock_symbol]($lock_style) ";
          };
        git_branch =
          { format = "[$symbol$branch(:$remote_branch)]($style) ";
            style = "bold yellow";
            symbol = "🏷 ";
          };
        git_status =
          { conflicted = "⚔️";
            ahead = "🏎️ 💨 \${count}";
            behind = "🐢 ×\${count}";
            diverged = "🔱 🏎️ 💨 \${ahead_count} 🐢 \${behind_count}";
            untracked = "🛤️  \${count}";
            stashed = "📦";
            modified = "📝 ×\${count}";
            staged = "🗃️  ×\${count}";
            renamed = "📛 ×\${count}";
            #renamed = "[➡](bold green) × \${count}";
            deleted = "🗑️ ×\${count}";
            style = "bright-white";
            format = "$all_status$ahead_behind ";
          };

        username =
          { style_root="bold red";
            style_user="bold green";
            format="[$user]($style)[@](bold white)";
            show_always=true;
            disabled=false;
          };

        hostname =
          { ssh_only = false;
            format = "[$hostname]($style)[:](bold white)";
            trim_at = "-";
            style = "bold yellow";
            disabled = false;
          };

        memory_usage =
          { threshold=50;
            format="[\${ram_pct}]($style)[$symbol]($style)";
            disabled=false;
          };

        time =
          { format="[\${time}]($style)";
            disabled=false;
          };
    };
  };
}
