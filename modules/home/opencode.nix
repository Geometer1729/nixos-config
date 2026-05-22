{ pkgs, ... }:
let
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
    "tree*"
    "file*"
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
    "date*"
    "echo*"
    "printf*"
    "test*"
    "expr*"
    "git status*"
    "git log*"
    "git diff*"
    "git show*"
    "git branch*"
    "git remote*"
    "gh api*"
    "nix eval*"
    "nix build*"
    "nix log*"
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
    "flake-update*"
    "flake-changelog*"
    "nixpkgs-changelog*"
    "nh os build*"
    "just build*"
    "just health*"
    "just vim-health*"
    "just gnome-check*"
    "just test-remote-builds*"
    "nvd diff*"
    "got-gnomed*"
    "systemctl --failed*"
    "journalctl -p*"
    "check-syncthing*"
    "ssh -o ConnectTimeout=5 torag echo*"
    "ssh torag just health*"
    "ssh torag just vim-health*"
    "ssh torag just gnome-check*"
    "ssh torag just test-remote-builds*"
  ];

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
  home.packages = [ pkgs.opencode ];
  home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    lsp = lspServers;
    model = "openai/gpt-5.5";
    permission = {
      external_directory = {
        "/nix/store/**" = "allow";
        "/tmp/flake-update/**" = "allow";
        "/tmp/nvim-health.txt" = "allow";
      };
      lsp = "allow";
      read = {
        "/nix/store/**" = "allow";
        "/tmp/flake-update/**" = "allow";
        "/tmp/nvim-health.txt" = "allow";
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
      };
    };
  };

  xdg.configFile."opencode/tui.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    plugin = [
      [
        "opencode-vim@0.0.13"
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
