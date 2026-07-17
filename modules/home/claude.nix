{ flake, pkgs, lib, config, ... }:
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
    package = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default; # native binary

    # Settings for ~/.claude/settings.json
    settings = {
      showThinkingSummaries = true;
      voiceEnabled = true;
      autoMemoryEnabled = false;
      # Disable claude.ai MCP integrations (Gmail, Calendar, Drive, Slack, Linear)
      mcpServers = { };
      disabledMcpServers = [ "claude_ai_Gmail" "claude_ai_Google_Calendar" "claude_ai_Google_Drive" "claude_ai_Slack" "claude_ai_Linear" ];
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

    # Global context file (~/CLAUDE.md)
    context = ''
      NixOS. Direnv loads devshells. nix-shell -p if needed.
      CLIs: gh, linearis
      Test fixes. Be skeptical.
      Do not be afraid to raise limitations or possible mistakes I missed.
      Ask clarifying questions.
      Suggest possible oversights.
      If you need to fundamentally change the plan from what I said tell me why.
      Questions are almost never rhetorical, but even if you think they are answer them.
      If I ask a question, answer it directly before taking action.
      Treat questions as genuine requests for information,
      not implicit permission to edit, run commands, or proceed.
      If you think action is needed, first answer the question, then ask whether I want you to act.
      I ask a question that's a request to plan (even in build mode).
      If I ask you to diagnose a problem that's a request to plan.
    '';
  };

  home.packages = with pkgs; [
    libnotify
    sox # Required for Claude Code /voice command (audio recording)
    # Claude notification scripts are now in modules/home/scripts/
  ];

  # Install Claude icon for notifications
  home.file.".local/share/icons/claude-icon.svg".source = claudeIcon;

  # Claude account isolation: separate config directories for work/personal
  # Direnv sets CLAUDE_CONFIG_DIR based on current directory (see zsh/direnv.nix)
  # These symlink the managed settings/memory into both config directories
  # force=true: these live in persisted directories, so stale files survive reboot
  # and would block HM activation (which is all-or-nothing)
  home.file = {
    ".claude-work/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/settings.json";
      force = true;
    };
    ".claude-personal/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/settings.json";
      force = true;
    };
  };
}
