{ pkgs, ... }:
{
  # Task management helper scripts moved to modules/home/scripts/

  home.packages = with pkgs;
    [
      taskopen
    ];

  home.file.".taskopenrc".text =
    ''
      [General]
      no_annotation_hook="taskopen-smart ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""

      [Actions]
      notes.regex = "^Notes"
      notes.command = "edit-note ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""
    '';
}
