{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  # Fetch Claude icon as a derivation
  claudeIcon = pkgs.fetchurl {
    url = "https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/claude-ai-icon.svg";
    sha256 = "sha256-86hX9EtbVC7nniAN1kpLjt485fm5lpOjm9ECTLK392o=";
  };

  linearis-lockfile = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/czottmann/linearis/v2026.4.2/package-lock.json";
    hash = "sha256-wOuf8nl9+ZecRVWkMcJ/T+sKFquTVJSb2hccs1nBc/s=";
  };

  linearis = pkgs.buildNpmPackage rec {
    pname = "linearis";
    version = "2026.4.2";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/linearis/-/linearis-${version}.tgz";
      hash = "sha256-HZdcuxMgtS9sJLM1hy4dw+NaGjuMxlE4kmIXJ5E97Jw=";
    };
    sourceRoot = "package";
    postPatch = ''
      cp ${linearis-lockfile} package-lock.json
      # Strip prepare/postinstall scripts (need network/git, dist/ is already pre-built)
      ${pkgs.jq}/bin/jq 'del(.scripts.prepare, .scripts.postinstall, .scripts.preinstall)' \
        package.json > package.json.new
      mv package.json.new package.json
    '';
    npmDepsHash = "sha256-GDqnA14iQ9EM895nDomRX1n++p6nJqsWTM+XKdDwx5Q=";
    dontNpmBuild = true; # npm tarball ships pre-built dist/
    npmFlags = [ "--ignore-scripts" ];
    npmInstallFlags = [ "--ignore-scripts" ];
    nodejs = pkgs.nodejs_22;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Auto-load LINEAR_API_TOKEN from sops secret if not already set,
    # so the binary works regardless of shell environment.
    postFixup = ''
      wrapProgram $out/bin/linearis \
        --run 'if [ -z "''${LINEAR_API_TOKEN:-}" ] && [ -r /run/secrets/linear_api_key ]; then export LINEAR_API_TOKEN="$(< /run/secrets/linear_api_key)"; fi'
    '';
  };
in
{
  # Use home-manager's official Claude Code module
  programs.claude-code = {
    enable = true;
    package = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default; # native binary

    # Settings for ~/.claude/settings.json
    settings = {
      model = "claude-opus-4-5";
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

    # Memory file (~/CLAUDE.md)
    memory.text = ''
      NixOS. Direnv loads devshells. nix-shell -p if needed.
      CLIs: gh, linearis, slack-search
      Test fixes. Be skeptical.
      TELL ME WHEN I'M WRONG.
      Ask clarifiying questions.
      Suggest possible oversights.
      If you need to fundementally change the plan from what I said tell me why.
      Be confrontational chalenge bad ideas!
      Questions are almost never rhetorical, but even if you think they are answer them.
    '';
  };

  # API keys for CLI tools (linearis, slack-search)
  programs.zsh.initContent = ''
    if [ -f /run/secrets/linear_api_key ]; then
      LINEAR_API_TOKEN="$(< /run/secrets/linear_api_key)"
      export LINEAR_API_TOKEN
    fi
    if [ -f /run/secrets/slack_token ]; then
      SLACK_TOKEN="$(< /run/secrets/slack_token)"
      export SLACK_TOKEN
    fi
  '';

  home.packages = with pkgs; [
    linearis
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
