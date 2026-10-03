# Programs register how to reach their key help; the Hyprland key-help picker
# shows the entries matching the focused window and tmux pane.
{ lib, ... }:
let
  inherit (lib) mkOption types;
  pattern = description: mkOption {
    type = types.nullOr types.str;
    default = null;
    inherit description;
  };
  bind = types.submodule {
    options = {
      key = mkOption {
        type = types.str;
        description = "Shortcut as shown to the user.";
      };
      description = mkOption { type = types.str; };
      keys = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "tmux key names sent to the matched pane when selected.";
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell command run when selected, with KEY_HELP_WINDOW (Hyprland
          address), KEY_HELP_PANE, and KEY_HELP_CLIENT (tmux) set.
        '';
      };
    };
  };
in
{
  options.keyHelp = mkOption {
    default = { };
    description = "Key help entries by program, shown when all given patterns match.";
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        label = mkOption {
          type = types.str;
          default = name;
        };
        order = mkOption {
          type = types.int;
          default = 50;
          description = "Sort position; outer layers such as the window manager come first.";
        };
        match = {
          class = pattern "Regex for the focused window's class.";
          title = pattern "Regex for the focused window's title.";
          process = pattern ''
            Regex for the command line of the foreground process in the focused
            tmux pane. Entries with a pattern only show inside tmux.
          '';
        };
        binds = mkOption { type = types.listOf bind; };
      };
    }));
  };
}
