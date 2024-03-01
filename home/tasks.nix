{pkgs,...}:
{
  programs.taskwarrior = {
    enable = true;
    config = {
      urgency."inherit" = "on";
    };
  };

  home.packages = with pkgs;
    [ taskwarrior-tui
      taskopen
    ];
}
