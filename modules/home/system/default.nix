{ config, machine, pkgs, lib, ... }:
{
  scripts.system = {
    directory = ./.;
    extras = with pkgs; [
      expect
      zsh
      nh
      tailscale
      iproute2
      nixos-rebuild
    ] ++ lib.optional (config.scripts ? hyprland) config.scripts.hyprland.packages.scratchPad;
  };

  home.packages = with pkgs; [
    # System utilities
    home-manager
    openssh
    dust # disk usage tool
    nix-du # makes a graph of the nix store dependencies
    graphviz # renders graphs (like the nix-du ones)
    nh # nix helper
    sops # needed to edit sops-nix secrets

    # Monitoring and status tools
    htop
    fastfetch
    lsof # list open files

    # Interactive tools, independent of individual scripts' runtime dependencies.
    coreutils
    curl
    fzf
    gh
    git
    jq
    libnotify
    pipewire
    pulseaudioFull
    python3
    systemd
  ] ++ lib.optionals machine.hasGui (with pkgs; [
    wl-clipboard
    radeontop
  ]);

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
