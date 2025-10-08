{ pkgs, config, ... }:
let
  gen-task-link =
    pkgs.writeShellApplication
      {
        name = "gen-task-link";
        text =
          ''
            # description target_file
            read -r description
            task add "$description" >> /dev/null
            task +LATEST annotate Redirect >> /dev/null
            UUID="$(task +LATEST uuids)"
            echo "[Redirect]($1#$UUID)" > ~/Documents/vw/tasks/"$UUID".md
            echo "[[**$UUID**|$1]]" > /tmp/task-link
          '';
      };
  edit-note = bin
    (pkgs.writeShellApplication
      {
        name = "edit-note";
        text =
          ''
            if ! [ -e "$1" ]
            then
              echo \# "$2" >> "$1"
            fi
            vim "$1"
          '';
      });
  bin = pkg: "${pkg}/bin/${pkg.name}";
in
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    config = {
      urgency."inherit" = "on";
    };
  };

  home.packages = with pkgs;
    [
      vit
      taskopen
      gen-task-link
    ];
  home.file.".taskopenrc".text =
    ''
      [General]
      no_annotation_hook="${edit-note} ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""

      [Actions]
      notes.regex = "^Notes"
      notes.command = "${edit-note} ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""

      redirect.regex = "^Redirect"
      redirect.command = "vim ~/Documents/vw/tasks/$UUID.md --command VimwikiFollowLink"
    '';
  home.file.".vit/config.ini".text =
    ''
      [keybinding]
      o = :!wr taskopen {TASK_UUID}<Enter>
      [vit]
      theme = stylix
    '';

  # Generate vit theme from Stylix colors following base16 guidelines
  home.file.".vit/theme/stylix.py".text = ''
    # Auto-generated vit theme from Stylix configuration
    # Following base16 guidelines: base00=bg, base01=lighter_bg, base02=selection, base03=comments, base05=fg, base08=errors, base0D=functions/focus
    theme = [
        ('list-header', "", "", "", "", ""),
        ('list-header-column', 'black', 'light gray', "", 'black', 'light gray'),  # base05 on base01
        ('list-header-column-separator', 'black', 'light gray', "", 'black', 'light gray'),  # base03 on base01
        ('striped-table-row', 'white', 'dark gray', "", 'white', 'dark gray'),  # base05 on base02
        ('reveal focus', 'black', 'dark cyan', 'standout', 'black', 'dark cyan'),  # base00 on base0D (focus)
        ('message status', 'white', 'dark blue', 'standout', 'white', 'dark blue'),  # base05 on base0D (status)
        ('message error', 'white', 'dark red', 'standout', 'white', 'dark red'),  # base05 on base08 (error)
        ('status', 'dark magenta', 'black', "", 'dark magenta', 'black'),  # base0E on base00
        ('flash off', 'black', 'black', 'standout', 'black', 'black'),
        ('flash on', 'white', 'black', 'standout', 'white', 'black'),  # base05 on base00
        ('pop_up', 'white', 'black', "", 'white', 'black'),  # base05 on base00
        ('button action', 'white', 'dark red', "", 'white', 'dark red'),  # base05 on base08 (action)
        ('button cancel', 'black', 'light gray', "", 'black', 'light gray'),  # base03 on base01 (cancel)
    ]
  '';
  programs.zsh.shellAliases =
    {
      ta = "task add";
      to = "taskopen";
      t = "task";
      note = "task +LATEST annotate Notes;taskopen $(task +LATEST ids)";
    };
}
