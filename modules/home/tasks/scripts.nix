{ config, lib, pkgs, ... }:
{
  scripts.tasks = {
    directory = ./.;
    extras = with pkgs; [
      config.programs.taskwarrior.package
      config.programs.nixvim.build.package
      taskopen
      fzf
      libnotify
    ] ++ lib.optional (config.scripts ? hyprland) config.scripts.hyprland.packages.scratchPad;
  };

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
