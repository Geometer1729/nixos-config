{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # System utilities
    home-manager
    openssh
    xclip
    du-dust # disk usage tool
    nix-du # makes a graph of the nix store dependencies
    graphviz # renders graphs (like the nix-du ones)
    cloudflared
    deploy-rs
    nh # nix helper
    sops # needed to edit sops-nix secrets

    # Monitoring and status tools
    htop
    radeontop
    neofetch

    # Custom utilities
    (pkgs.writeShellApplication {
      name = "flushSwap";
      text = ''
        sudo swapoff -a
        sudo swapon -a
        notify-send "swap flushed"
      '';
    })
  ];

  # System monitoring configuration
  programs.btop = {
    enable = true;
    settings = {
      proc_sorting = "memory";
      show_swap = true;
    };
  };
  # TODO hide repeated disks in btop

  # Session variables
  home.sessionVariables = {
    NH_FLAKE = "${config.home.homeDirectory}/conf";
  };
}
