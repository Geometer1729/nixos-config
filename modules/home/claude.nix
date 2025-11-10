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
          "nix eval"
          "nix log"
          "nix show-derivation"
          "nix path-info"
          "nix why-depends"
          "nix show-config"
          "nix hash"
          "nix search"
          "nix flake show"
          "nix flake metadata"
          "nix flake check"
          "nix store ls"
          "nix store cat"
          "nix store diff-closures"
          "nix store ping"
          "nix store verify"
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
    # Claude notification scripts are now in modules/home/scripts/
  ];

  # Create Claude Code settings configuration
  home.file.".claude/settings.json".source = settingsJson;

  # Manage Claude.md instructions file
  home.file."CLAUDE.md".text = ''
    # Global Claude Instructions


    ## Testing and Verification Requirements

    **CRITICAL: Never claim a fix works without testing it first.**

    - ALWAYS run the failing command/test after making changes to verify the fix actually works
    - If you can't test immediately, say "This change should help" or "Let me test this" instead of "Fixed!"
    - Only claim something is "Fixed" after verifying the original problem no longer occurs
     - When debugging, test each hypothesis before moving to the next one
     - Show the test results that prove the fix works
    - When the test fails try something else don't give up

    ## Communication Style
    - Be honest about uncertainty
    - Distinguish between theory and verified results
    - Test before claiming success

    ## Nixos
    - This machine uses nixos and nix heavily
    - Expect projects to use nix
    - Expect commands to require `nix develop`
  '';
}
