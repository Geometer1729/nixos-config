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
    "nix eval*"
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
    "nix store ls*"
    "nix store cat*"
    "nix store diff-closures*"
    "nix store ping*"
    "nix store verify*"
  ];
in
{
  home.packages = [ pkgs.opencode ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    model = "openai/gpt-5.5";
    permission = {
      external_directory = {
        "/nix/store/**" = "allow";
      };
      read = {
        "/nix/store/**" = "allow";
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
}
