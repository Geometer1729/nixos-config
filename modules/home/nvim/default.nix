{ pkgs, lib, ... }:
{
  stylix.targets.nixvim = {
    enable = true;
    #plugin = "base16-nvim";
    transparentBackground = {
      main = true;
      signColumn = true;
    };
  };
  programs.nixvim =
    (import ./nixvim.nix { inherit pkgs lib; })
    // { enable = true; };

  # Hourly systemd timer to check for vim swap files
  systemd.user.timers.checkSwaps = {
    Unit.Description = "Check for vim swap files hourly";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.checkSwaps = {
    Unit.Description = "Check for vim swap files and notify";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "check-swaps-wrapper" ''
        ${builtins.readFile ../scripts/check-swaps.sh}
      ''}";
    };
  };
}
