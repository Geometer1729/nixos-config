{ flake, config, osConfig, lib, pkgs, ... }:
let
  persistedHome =
    if config.home.username == "root"
    then "/persist/system/root"
    else "/persist/system/home/${config.home.username}";
  zshFiles = lib.mapAttrs (_: file: file // { target = lib.removePrefix "./" file.target; })
    (lib.filterAttrs (_: file: builtins.match "(\\./)?\\.z.*" file.target != null) config.home.file);
  profiles = [ config.home.path osConfig.system.path ];
in
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
          src = flake.inputs.zsh-nix-shell;
        }
      ];
      history = {
        append = true;
        # TODO it would be cool if this was set by impermenance?
        # Or maybe just a global option for that
        path = "${persistedHome}/.zsh_history";
        # I can't figure out why, but something about the wya it's mounted
        # causes constant failure with
        # zsh: can't rename ~/.zsh_history.new to $HISTFILE
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
        source ${./helpers.zsh}
        source ${./viCursor.zsh}
        source ${./notify.zsh}
        bindkey  clear-screen
      ''; #If this gets any more substantial it may be time for a file
      localVariables =
        {
          EDITOR = "vim";
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
          g = "git_";
          git = "git_";
          lg = "lazygit";
          fgv = ''
            vim -S .session.vim -c 'silent exec "!rm .session.vim"'
          '';
          # helpers
          zathura = "zathura_";
          rm = "rm_";
          cd = "cd_";
          nix-du = "\\nix-du  -s=500mb | dot -Tpng > /tmp/store.png && sxiv /tmp/store.png";
        } //
        (# always sudo
          builtins.listToAttrs
            (map
              (name: { inherit name; value = "sudo ${name}"; })
              [
                "dd"
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
          map
            (n: {
              name = builtins.concatStringsSep "" (builtins.genList (_: ".") (n + 1));
              value = builtins.concatStringsSep "/" (builtins.genList (_: "..") n);
            })
            (builtins.tail (builtins.genList (n: n + 1) 10))
        );
    };
  # Start an interactive login shell on the generated dotfiles, with the real
  # profiles for PATH/completions; any startup output fails the build.
  # Home and history paths are redirected into the sandbox.
  home.checks = [
    (pkgs.runCommand "zsh-config-check" { nativeBuildInputs = [ config.programs.zsh.package ]; } ''
      export HOME=$TMPDIR/home
      export NIX_PROFILES=${lib.escapeShellArg (toString profiles)}
      export PATH=${lib.makeBinPath profiles}:$PATH
      ${lib.concatStrings (lib.mapAttrsToList (_: file: ''
        mkdir -p "$(dirname "$HOME/${file.target}")"
        if [[ -d ${file.source} ]]; then
          ln -s ${file.source} "$HOME/${file.target}"
        else
          sed -e 's|${dirOf config.programs.zsh.history.path}|'"$TMPDIR/history"'|g' \
            -e 's|${config.home.homeDirectory}|'"$HOME"'|g' \
            ${file.source} > "$HOME/${file.target}"
        fi
      '') zshFiles)}
      if ! output=$(zsh -i -l -c exit 2>&1 >/dev/null) || [[ -n $output ]]; then
        echo "$output" >&2
        exit 1
      fi
      touch $out
    '')
  ];

  home.sessionVariables = {
    EDITOR = "vim";
    NIX_AUTO_RUN = 1;
    #CLAUDE_CODE_EFFORT_LEVEL = "high";
  };
  programs.nix-index = {
    enable = true;
    # AFAICT The zsh integration is less usefull
    # than the default command-not-found
    enableZshIntegration = true;
  };
}
