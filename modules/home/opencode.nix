{ flake, pkgs, config, ... }:
let
  inherit (flake) inputs;
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
  };
  opencode = pkgs.writeShellApplication {
    name = "opencode";
    runtimeEnv = {
      # opencode-vim's broad peer ranges otherwise resolve to a conflicting OpenTUI tree.
      NPM_CONFIG_FORCE = "true";
      PINENTRY_USER_DATA = "gui";
    };
    text = ''
      exec ${unstable.opencode}/bin/opencode "$@"
    '';
  };
  opencodeVimVersion =
    (builtins.fromJSON (builtins.readFile "${inputs.opencode-vim}/package.json")).version;

  developmentBashCommands = [
    "cargo build*"
    "cargo fmt*"
    "cargo clippy*"
    "cargo check*"
    "cargo test*"
    "cargo nextest run*"
    "rustfmt*"
    "cabal build*"
    "cabal check*"
    "cabal test*"
    "cabal v2-test*"
    "stack test*"
    "hlint*"
    "ormolu*"
    "fourmolu*"
    "stylish-haskell*"
    "cabal-fmt*"
    "nix fmt*"
    "nixpkgs-fmt*"
    "alejandra*"
    "treefmt*"
    "statix check*"
    "deadnix*"
    "shellcheck*"
    "shfmt*"
    "nixfmt*"
    "ruff format --check*"
    "command -v *"
  ];

  wrappedDevelopmentBashCommands = builtins.concatMap
    (command: [
      "nix develop --command ${command}"
      "nix develop .#* --command ${command}"
      "nix develop -c ${command}"
      "nix develop .#* -c ${command}"
      "direnv exec . ${command}"
    ])
    developmentBashCommands;

  trustedNixRunApps = [
    "codex-unresolved-comments"
    "codex-unresolved-threads"
    "panharmonicon-cabal2nix-check"
    "panharmonicon-cabal2nix-generate"
    "pr-ci-failed-logs"
    "pr-ready-wait"
    "precommit-check"
    "prod-monolith-log"
    "src-fix"
  ];

  trustedNixRunBashCommands = builtins.concatMap
    (app: [
      "nix run .#${app}"
      "nix run .#${app} *"
    ])
    trustedNixRunApps;

  linearisReadOnlyBashCommands = [
    "linearis -V"
    "linearis --version"
    "linearis --help*"
    "linearis usage*"
    "linearis version"
    "linearis version check*"
    "linearis version usage*"
    "linearis auth --help*"
    "linearis auth status*"
    "linearis auth usage*"
    "linearis issues --help*"
    "linearis issues list*"
    "linearis issues search*"
    "linearis issues read*"
    "linearis issues activity*"
    "linearis issues discussions*"
    "linearis issues replies*"
    "linearis issues relations --help*"
    "linearis issues relations list*"
    "linearis issues usage*"
    "linearis comments --help*"
    "linearis comments list*"
    "linearis comments usage*"
    "linearis labels --help*"
    "linearis labels list*"
    "linearis labels read*"
    "linearis labels usage*"
    "linearis projects --help*"
    "linearis projects list*"
    "linearis projects read*"
    "linearis projects discussions*"
    "linearis projects replies*"
    "linearis projects usage*"
    "linearis cycles --help*"
    "linearis cycles list*"
    "linearis cycles read*"
    "linearis cycles usage*"
    "linearis milestones --help*"
    "linearis milestones list*"
    "linearis milestones read*"
    "linearis milestones usage*"
    "linearis files --help*"
    "linearis files usage*"
    "linearis attachments --help*"
    "linearis attachments list*"
    "linearis attachments usage*"
    "linearis teams --help*"
    "linearis teams list*"
    "linearis teams read*"
    "linearis teams members*"
    "linearis teams usage*"
    "linearis users --help*"
    "linearis users list*"
    "linearis users usage*"
    "linearis initiatives --help*"
    "linearis initiatives list*"
    "linearis initiatives read*"
    "linearis initiatives discussions*"
    "linearis initiatives replies*"
    "linearis initiatives updates --help*"
    "linearis initiatives updates list*"
    "linearis initiatives updates read*"
    "linearis initiatives usage*"
    "linearis documents --help*"
    "linearis documents list*"
    "linearis documents read*"
    "linearis documents usage*"
  ];

  gcloudReadOnlyBashCommands = [
    "gcloud -h*"
    "gcloud --help*"
    "gcloud --version*"
    "gcloud help*"
    "gcloud info*"
    "gcloud topic*"
    "gcloud version*"
    "gcloud * --help*"
    "gcloud * help*"
    "gcloud * list"
    "gcloud * list *"
    "gcloud * describe"
    "gcloud * describe *"
    "gcloud * get-iam-policy"
    "gcloud * get-iam-policy *"
    "gcloud asset search-all-iam-policies*"
    "gcloud asset search-all-resources*"
    "gcloud auth list*"
    "gcloud config get-value*"
    "gcloud storage du*"
    "gcloud storage cat*"
    "gcloud storage ls*"
  ];

  ghReadOnlyBashCommands = [
    "gh --help*"
    "gh --version*"
    "gh auth status*"
    "gh status*"
    "gh pr checks*"
    "gh pr diff*"
    "gh pr list*"
    "gh pr status*"
    "gh pr view*"
    "gh issue list*"
    "gh issue status*"
    "gh issue view*"
    "gh repo list*"
    "gh repo view*"
    "gh run list*"
    "gh run view*"
    "gh run watch*"
    "gh workflow list*"
    "gh workflow view*"
    "gh release list*"
    "gh release view*"
    "gh search code*"
    "gh search commits*"
    "gh search issues*"
    "gh search prs*"
    "gh search repos*"
  ];

  allowedBashCommands = [
    "ls*"
    "rg*"
    "find*"
    "grep*"
    "cat*"
    "head*"
    "tail*"
    "wc*"
    "sort*"
    "uniq*"
    "cut*"
    "base64*"
    "tree*"
    "file*"
    "cmp*"
    "diff*"
    "stat*"
    "du*"
    "df*"
    "ps*"
    "which*"
    "type*"
    "whereis*"
    "locate*"
    "basename*"
    "dirname*"
    "realpath*"
    "readlink*"
    "pwd"
    "pwd -*"
    "id"
    "id *"
    "uname"
    "uname *"
    "hostname"
    "hostname -f"
    "hostname -s"
    "hostnamectl hostname"
    "lspci*"
    "pgrep*"
    "getent *"
    "sha256sum *"
    "comm *"
    "date*"
    "sleep *"
    "echo*"
    "printf*"
    "test*"
    "expr*"
    "jq*"
    "git status*"
    "git log*"
    "git diff*"
    "git show*"
    "git branch*"
    "git remote*"
    "git rev-parse*"
    "git ls-files*"
    "git ls-remote*"
    "git ls-tree*"
    "git grep*"
    "git check-ignore*"
    "git rev-list*"
    "git for-each-ref*"
    "git reflog"
    "git reflog show*"
    "git cat-file*"
    "git diff-tree*"
    "git hash-object*"
    "git range-diff*"
    "git patch-id*"
    "git worktree list*"
    "git worktree add --no-track -b update-* ${config.home.homeDirectory}/Code/conf-update-* HEAD"
    "git worktree add ${config.home.homeDirectory}/Code/conf-update-* update-*"
    "git config --get*"
    "git config --list*"
    "git blame*"
    "git merge-base*"
    "git describe*"
    "git tag"
    "git tag --list*"
    "git clone --filter=blob:none --no-checkout * /tmp/flake-update/*"
    "git -C /tmp/flake-update/* fetch*"
    "git -C /tmp/flake-update/* checkout --detach*"
    "git -C /tmp/flake-update/* worktree add --detach /tmp/flake-update/*"
    "gh api*"
    "gh repo clone * /tmp/flake-update/* -- --no-checkout"
    "bash -n *"
    "direnv reload"
    "direnv status*"
    "opencode --help*"
    "opencode --version*"
    "nix eval*"
    "nix build*"
    "nix log*"
    "nix derivation show*"
    "nix show-derivation*"
    "nix path-info*"
    "nix why-depends*"
    "nix show-config*"
    "nix hash*"
    "nix search*"
    "nix flake show*"
    "nix flake metadata*"
    "nix flake check*"
    "nix flake update*"
    "nix store ls*"
    "nix store cat*"
    "nix store diff-closures*"
    "nix store ping*"
    "nix store verify*"
    "nix-store -q*"
    "nix-store --query*"
    "flake-update*"
    "flake-changelog*"
    "nixpkgs-changelog*"
    "nh os build*"
    "nh os test*"
    "nh --version*"
    "nh * --help*"
    "just build*"
    "just fmt*"
    "just test*"
    "just health*"
    "just vim-health*"
    "just gnome-check*"
    "just test-remote-builds*"
    "nvd diff*"
    "got-gnomed*"
    "systemctl --failed*"
    "systemctl status*"
    "systemctl show*"
    "systemctl cat*"
    "systemctl list-units*"
    "systemctl list-unit-files*"
    "systemctl list-timers*"
    "systemctl is-active*"
    "systemctl is-enabled*"
    "systemctl --user status*"
    "systemctl --user show*"
    "systemctl --user cat*"
    "systemctl --user list-units*"
    "systemctl --user list-unit-files*"
    "systemctl --user list-timers*"
    "systemctl --user is-active*"
    "systemctl --user is-enabled*"
    "journalctl -p*"
    "journalctl --user -u meridian --no-pager*"
    "curl -sS http://127.0.0.1:3456/health"
    "meridian --version*"
    "check-syncthing*"
    "ssh -o ConnectTimeout=5 torag echo*"
    "ssh torag just health*"
    "ssh torag just vim-health*"
    "ssh torag just gnome-check*"
    "ssh torag just test-remote-builds*"
  ]
  ++ developmentBashCommands
  ++ wrappedDevelopmentBashCommands
  ++ trustedNixRunBashCommands
  ++ linearisReadOnlyBashCommands
  ++ ghReadOnlyBashCommands
  ++ gcloudReadOnlyBashCommands;

  lspServers = {
    nixd = {
      command = [ "nixd" ];
      extensions = [ ".nix" ];
    };
    "lua-ls" = {
      command = [ "lua-language-server" ];
      extensions = [ ".lua" ];
    };
    bash = {
      command = [ "bash-language-server" "start" ];
      extensions = [ ".sh" ".bash" ".zsh" ".ksh" ];
    };
    rust = {
      command = [ "rust-analyzer" ];
      extensions = [ ".rs" ];
    };
    hls = {
      command = [ "haskell-language-server" "--lsp" ];
      extensions = [ ".hs" ".lhs" ];
    };
    "yaml-ls" = {
      command = [ "yaml-language-server" "--stdio" ];
      extensions = [ ".yaml" ".yml" ];
    };
  };
in
{
  imports = [ inputs.meridian.homeModules.default ];

  home.packages = with pkgs; [
    config.services.meridian.package
    libnotify
    opencode
  ];
  home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  services.meridian = {
    enable = true;
    environment = {
      CLAUDE_CONFIG_DIR = "${config.home.homeDirectory}/.claude-work";
    };
  };

  xdg.configFile."meridian/sdk-features.json" = {
    force = true;
    text = builtins.toJSON {
      opencode = {
        clientSystemPrompt = false;
        codeSystemPrompt = true;
      };
    };
  };

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    lsp = lspServers;
    model = "openai/gpt-5.6-sol";
    plugin = [ config.services.meridian.opencode.pluginPath ];
    provider.anthropic.options = {
      apiKey = "x";
      baseURL = "http://127.0.0.1:3456";
    };
    permission = {
      external_directory = {
        "/nix/store/**" = "allow";
        "/tmp/**" = "allow";
        "${config.home.homeDirectory}/Code/conf-update-*/**" = "allow";
      };
      lsp = "allow";
      read = {
        "/nix/store/**" = "allow";
        "/tmp/**" = "allow";
      };
      bash = builtins.listToAttrs (
        [
          {
            name = "*";
            value = "ask";
          }
        ]
        ++ map
          (command: {
            name = command;
            value = "allow";
          })
          allowedBashCommands
      );
      edit = {
        "*" = "ask";
        "/nix/store/**" = "deny";
        "/tmp/**" = "allow";
      };
    };
  };

  xdg.configFile."opencode/plugins/notifications.js".text = ''
    export const NotificationPlugin = async ({ directory }) => {
      const notify = (eventType) => {
        Bun.spawn({
          cmd: ["opencode-notify", eventType, directory],
          stdout: "ignore",
          stderr: "ignore",
        })
      }

      return {
        event: async ({ event }) => {
          if (event.type === "session.idle") notify("ready")
          if (event.type === "permission.asked") notify("permission")
        },
      }
    }
  '';

  xdg.configFile."opencode/tui.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    attention = {
      enabled = true;
      notifications = true;
      sound = false;
    };
    plugin = [
      [
        "opencode-vim@${opencodeVimVersion}"
        {
          autoUpdate = false;
          vim = {
            defaultMode = "insert";
          };
        }
      ]
    ];
    keybinds = {
      editor_open = "ctrl+o";
    };
  };
}
