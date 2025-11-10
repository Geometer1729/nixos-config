{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # System utilities
    home-manager
    openssh
    wl-clipboard
    dust # disk usage tool
    nix-du # makes a graph of the nix store dependencies
    graphviz # renders graphs (like the nix-du ones)
    deploy-rs
    nh # nix helper
    sops # needed to edit sops-nix secrets

    # Monitoring and status tools
    htop
    radeontop
    neofetch

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
