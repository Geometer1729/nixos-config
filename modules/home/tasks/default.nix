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
  create-task-from-heading =
    pkgs.writeShellApplication
      {
        name = "create-task-from-heading";
        runtimeInputs = [ pkgs.taskwarrior3 ];
        text =
          ''
            # Usage: create-task-from-heading "Heading Text" "file/path.md" "heading-anchor"
            HEADING="$1"
            FILE_PATH="$2"
            ANCHOR="$3"

            # Create task with heading as description
            task add "$HEADING" >> /dev/null
            task +LATEST annotate Redirect >> /dev/null
            UUID="$(task +LATEST uuids)"

            # Create markdown file with link to heading
            echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md

            echo "Created task $UUID: $HEADING -> $FILE_PATH#$ANCHOR"
          '';
      };
  update-task-link =
    pkgs.writeShellApplication
      {
        name = "update-task-link";
        runtimeInputs = [ pkgs.taskwarrior3 pkgs.fzf ];
        text =
          ''
            # Usage: update-task-link "file/path.md" "heading-anchor"
            FILE_PATH="$1"
            ANCHOR="$2"

            # Select task using fzf
            SELECTED=$(task status:pending export | ${pkgs.jq}/bin/jq -r '.[] | "\(.uuid) \(.description)"' | fzf --prompt="Select task to update: ")

            if [ -z "$SELECTED" ]; then
              echo "No task selected"
              exit 1
            fi

            UUID=$(echo "$SELECTED" | awk '{print $1}')

            # Update the redirect link
            echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md

            # Add Redirect annotation if not present
            if ! task "$UUID" | grep -q "Redirect"; then
              task "$UUID" annotate Redirect >> /dev/null
            fi

            echo "Updated task $UUID to point to $FILE_PATH#$ANCHOR"
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
      create-task-from-heading
      update-task-link
    ];
  home.file.".taskopenrc".text =
    ''
      [General]
      no_annotation_hook="${edit-note} ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""

      [Actions]
      notes.regex = "^Notes"
      notes.command = "${edit-note} ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""

      redirect.regex = "^Redirect"
      redirect.command = "vim ~/Documents/vw/tasks/$UUID.md -c VimwikiFollowLink"
    '';
  home.file.".vit/config.ini".text =
    ''
      [keybinding]
      o = :!wr taskopen {TASK_UUID}<Enter>
      [vit]
      theme = stylix
    '';

  # Generate vit theme from Stylix colors following base16 guidelines
  home.file.".vit/theme/stylix.py".text = with config.lib.stylix.colors.withHashtag; ''
    # Auto-generated vit theme from Stylix configuration
    # Following base16 guidelines: base00=bg, base01=lighter_bg, base02=selection, base03=comments, base05=fg, base08=errors, base0D=functions/focus
    # urwid palette format: (name, fg_16color, bg_16color, mono, fg_256color, bg_256color)
    theme = [
        ('list-header', "", "", "", "", ""),
        ('list-header-column', 'white', 'black', "", '${base05}', '${base01}'),  # Default foreground on lighter background
        ('list-header-column-separator', 'dark magenta', 'black', "", '${base03}', '${base01}'),  # Comments color on lighter background
        ('striped-table-row', 'white', 'dark gray', "", '${base05}', '${base02}'),  # Default foreground on selection background
        ('reveal focus', 'black', 'dark magenta', 'standout', '${base00}', '${base0D}'),  # Primary background on focus color (inverted for visibility)
        ('message status', 'white', 'dark magenta', 'standout', '${base05}', '${base0D}'),  # Default foreground on focus/info color
        ('message error', 'white', 'dark red', 'standout', '${base05}', '${base08}'),  # Default foreground on error color
        ('status', 'dark magenta', 'black', "", '${base0E}', '${base00}'),  # Purple on primary background
        ('flash off', 'black', 'black', 'standout', '${base00}', '${base00}'),  # Background on background (invisible)
        ('flash on', 'white', 'black', 'standout', '${base05}', '${base00}'),  # Default foreground on primary background
        ('pop_up', 'white', 'black', "", '${base05}', '${base00}'),  # Default foreground on primary background
        ('button action', 'white', 'dark red', "", '${base05}', '${base08}'),  # Default foreground on error color (for action emphasis)
        ('button cancel', 'dark magenta', 'black', "", '${base03}', '${base01}'),  # Comments color on lighter background
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
