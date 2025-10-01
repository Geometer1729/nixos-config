{ pkgs, ... }:
{
  imports = [ ./starship.nix ./direnv.nix ];
  programs.zsh =
    {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      plugins = [
        {
          # gets nix-shell to use zsh
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
      history = {
        append = true;
        # TODO it would be cool if this was set by impermenance?
        # Or maybe just a global option for that
        path = "/persist/system/home/bbrian/.zsh_history";
        # I can't figure out why, but something about the wya it's mounted
        # causes constant failure with
        # zsh: can't rename /home/bbrian/.zsh_history.new to $HISTFILE
        # AFAICT append should mean it never tries to do this anyway
        # but that must not be true
      };
      historySubstringSearch =
        {
          enable = true;
          #searchUpKey="^K";
        };
      autocd = true;
      defaultKeymap = "viins";
      profileExtra =
        ''
          # Currently just using a display manager
          #if [ "$(tty)" = "/dev/tty1" ] && ! pgrep -x Xorg >/dev/null
          #then
          #  startx
          #fi
          if [[ $- =~ i ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
            exec tmux new-session -A -s ssh
          fi
        '';
      initContent = ''
        source ${./helpers.sh}
        source ${./viCursor.sh}
        source ${./notify.sh}
        bindkey  clear-screen
      ''; #If this gets any more substantial it may be time for a file
      localVariables =
        {
          EDITOR = "vim";
          BROWSER = "firefox";
          READER = "zathura";
          REPORTTIME = 1;
        };
      shellAliases =
        {
          rs = "exec zsh";
          ls = "ls -hN --color=auto --group-directories-first";
          grep = "grep -E --color=auto";
          sed = "sed -E";
          la = "ls -A";
          ll = "ls -Al";
          mv = "mv -i";
          gs = "git status";
          dr = "direnv reload";
          da = "direnv allow";
          rgi = "rg -i";
          ":q" = "exit";
          du = "dust";
          v = "vim";
          g = "git";
          lg = "lazygit";
          fgv = ''
            vim -S .session.vim -c 'silent exec "!rm .session.vim"'
          '';
          # helpers
          zathura = "zathura_";
          rm = "rm_";
          cd = "cd_";
          nix-du = "\\nix-du  -s=500mb | dot -Tpng > /tmp/store.png && sxiv /tmp/store.png";
          xclip = "xclip -selection clipboard";
        } //
        (# always sudo
          builtins.listToAttrs
            (builtins.map
              (name: { inherit name; value = "sudo ${name}"; })
              [
                "dd"
                "systemctl"
                "mount"
                "umount"
                "shutdown"
                "nixos-rebuild"
                "eject"
                "arp-scan"
              ]
            )
        );
      shellGlobalAliases =
        builtins.listToAttrs (
          builtins.map
            (n: {
              name = builtins.concatStringsSep "" (builtins.genList (_: ".") (n + 1));
              value = builtins.concatStringsSep "/" (builtins.genList (_: "..") n);
            })
            (builtins.tail (builtins.genList (n: n + 1) 10))
        );
    };
  home.sessionVariables = {
    EDITOR = "vim";
    NIX_AUTO_RUN = 1;
  };
  programs.nix-index = {
    enable = true;
    # AFAICT The zsh integration is less usefull
    # than the default command-not-found
    enableZshIntegration = true;
  };
}
