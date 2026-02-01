{ flake, pkgs, config, ... }:
let
  inherit (flake) inputs;
  # Fetch Claude icon as a derivation
  claudeIcon = pkgs.fetchurl {
    url = "https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/claude-ai-icon.svg";
    sha256 = "sha256-86hX9EtbVC7nniAN1kpLjt485fm5lpOjm9ECTLK392o=";
  };
in
{
  # Use home-manager's official Claude Code module
  programs.claude-code = {
    enable = true;
    package = inputs.claude-code.packages.${pkgs.system}.default; # native binary

    # Settings for ~/.claude/settings.json
    settings = {
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

    # Memory file (~/CLAUDE.md)
    memory.text = ''
      # Global Claude Instructions


      ## Testing and Verification Requirements

      **CRITICAL: ALWAYS test a fix before claiming it works or suggest a test **

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
      - Most projects use direnv to automatically load nix environments
      - Expect your Bash tool already use the local devshell
      - Expect each call to use the current version changes will be reflected immediately
      - If you want to use a tool that's not in path feel free to use nix-shell -p or add it to the devshell if it feels apropriate
    '';
  };

  home.packages = with pkgs; [
    # Ensure libnotify is available for notify-send
    libnotify
    # Claude notification scripts are now in modules/home/scripts/
  ];

  # Install Claude icon for notifications
  home.file.".local/share/icons/claude-icon.svg".source = claudeIcon;

  # Claude account isolation: separate config directories for work/personal
  # Direnv sets CLAUDE_CONFIG_DIR based on current directory (see zsh/direnv.nix)
  # These symlink the managed settings/memory into both config directories
  home.file = {
    ".claude-work/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/settings.json";
    ".claude-work/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/CLAUDE.md";
    ".claude-personal/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/settings.json";
    ".claude-personal/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/CLAUDE.md";
  };
}
