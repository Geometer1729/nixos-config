{ pkgs, ... }:
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
  #home.file.".taskopenrc".text =
  #  ''
  #  TASK_ATTRIBUTES = priority,project,tags,description
  #  NOTES_FOLDER=$HOME/Documents/vw/tasks/
  #  NOTES_EXT=.md
  #  NOTES_CMD = "${edit-note}/bin/edit-note $HOME/Documents/vw/tasks/$UUID.md $TASK_DESCRIPTION"
  #  '';
  home.file.".vit/config.ini".text =
    ''
      [keybinding]
      o = :!wr taskopen {TASK_UUID}<Enter>
      [vit]
      #theme = classic
    '';
  programs.zsh.shellAliases =
    {
      ta = "task add";
      to = "taskopen";
      t = "task";
      note = "task +LATEST annotate Notes;taskopen $(task +LATEST ids)";
    };
}
