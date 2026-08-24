{ config, pkgs, ... }:
let
  nhWithSleepInhibit = pkgs.writeShellScriptBin "nh" ''
    if [[ "''${1-}" == os ]]; then
      exec ${pkgs.systemd}/bin/systemd-inhibit \
        --what=sleep \
        --who=nh \
        --why="NixOS operation in progress" \
        ${pkgs.nh}/bin/nh "$@"
    fi

    exec ${pkgs.nh}/bin/nh "$@"
  '';
in
{
  home.packages = with pkgs; [
    # System utilities
    home-manager
    openssh
    wl-clipboard
    dust # disk usage tool
    nix-du # makes a graph of the nix store dependencies
    graphviz # renders graphs (like the nix-du ones)
    nhWithSleepInhibit # nix helper
    sops # needed to edit sops-nix secrets

    # Monitoring and status tools
    htop
    radeontop
    fastfetch
    lsof # list open files

    # Custom utilities moved to modules/home/scripts/
  ];

  # System monitoring configuration
  programs.btop = {
    enable = true;
    settings = {
      proc_sorting = "memory";
      show_swap = true;
      disks_filter = "/persist";
    };
  };

  # Session variables
  home.sessionVariables = {
    NH_FLAKE = "${config.home.homeDirectory}/conf";
  };
}
