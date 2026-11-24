{ pkgs, ... }:
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    config = {
      urgency."inherit" = "on";
      "news.version" = "3.4.1"; # I don't love this but it beats everything else I've tried
      search.case.sensitive = "no";
      uda.page = {
        type = "string";
        label = "Page";
      };
      # Linked sessions, as space-separated <host>:<session ID>; see opencode-start.
      uda.opencode = {
        type = "string";
        label = "OpenCode";
      };
    };
  };

  programs.zsh.shellAliases =
    {
      ta = "task add";
      to = "taskopen";
      t = "task";
      note = "task +LATEST annotate Notes;taskopen $(task +LATEST ids)";
      qn = "quick-note";
      quicknote = "quick-note";
    };

  imports = [
    ./scripts.nix
    ./vit.nix
    ./taskchampion-client.nix
    ./gtd.nix
    ./dailies.nix
    ./import.nix
  ];
}
