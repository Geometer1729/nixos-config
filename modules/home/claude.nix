{ pkgs, config, ... }:
let
  claudeSettings = {
    permissions = {
      Bash = {
        allowed = [
          "ls"
          "rg"
          "find"
          "grep"
          "cat"
          "head"
          "tail"
          "wc"
          "sort"
          "uniq"
          "cut"
          "tree"
          "file"
          "stat"
          "du"
          "df"
          "ps"
          "which"
          "type"
          "whereis"
          "locate"
          "basename"
          "dirname"
          "realpath"
          "readlink"
          "date"
          "echo"
          "printf"
          "test"
          "expr"
          "git status"
          "git log"
          "git diff"
          "git show"
          "git branch"
          "git remote"
        ];
        denied = [
          "git add"
          "git commit"
          "git push"
          "git pull"
          "git merge"
          "git rebase"
          "git reset"
          "git revert"
          "git checkout"
          "git switch"
          "git stash"
          "git cherry-pick"
          "git apply"
          "git am"
          "git clean"
          "git rm"
          "git mv"
          "git tag"
          "git fetch"
          "git clone"
          "git submodule"
          "git worktree"
          "git reflog"
          "git gc"
          "git fsck"
          "git filter-branch"
          "git replace"
          "git notes"
        ];
      };
    };
    hooks = {
      Notification = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "claude-user-input";
            }
          ];
        }
      ];
      Stop = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "claude-completed";
            }
          ];
        }
      ];
      SubagentStop = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "claude-completed";
            }
          ];
        }
      ];
    };
  };

  settingsJson = pkgs.writeText "claude-settings.json" (builtins.toJSON claudeSettings);
in
{
  home.packages = with pkgs; [
    # Ensure libnotify is available for notify-send
    libnotify

    # Create a wrapper script for Claude Code notifications
    # TODO remove?
    (pkgs.writeShellApplication {
      name = "claude-notify";
      text = ''
        # Claude Code notification helper
        # Usage: claude-notify <title> <message> [urgency]

        TITLE="''${1:-Claude Code}"
        MESSAGE="''${2:-Needs user input}"
        URGENCY="''${3:-normal}"

        # Send notification with Claude Code branding
        notify-send \
          --urgency="$URGENCY" \
          --icon=dialog-information \
          --app-name="Claude Code" \
          --expire-time=10000 \
          "$TITLE" \
          "$MESSAGE"
      '';
    })

    # Create specific notification for user input requests
    (pkgs.writeShellApplication {
      name = "claude-user-input";
      text = ''
        # Notify user that Claude Code needs input
        PWD_INFO=$(pwd | sed "s|^$HOME|~|")
        
        notify-send \
          --urgency=normal \
          --icon=dialog-question \
          --app-name="Claude" \
          --expire-time=0 \
          "Input needed" \
          "in $PWD_INFO"
      '';
    })

    # Create notification for Claude Code completion
    (pkgs.writeShellApplication {
      name = "claude-completed";
      text = ''
        # Notify user that Claude Code has completed a task
        PWD_INFO=$(pwd | sed "s|^$HOME|~|")
        
        # Get the last command from history for context
        LAST_CMD=$(history | tail -1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' | cut -c1-50)
        
        notify-send \
          --urgency=low \
          --icon=dialog-information \
          --app-name="Claude" \
          --expire-time=3000 \
          "Completed in $PWD_INFO" \
          "$LAST_CMD"
      '';
    })
  ];

  # Create Claude Code settings configuration
  home.file.".claude/settings.json".source = settingsJson;
}
