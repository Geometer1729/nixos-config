{ config, pkgs, lib, ... }:

{
  # Enable Tailscale VPN
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    # Auth key file for automatic authentication on boot
    # Generate a reusable key at: https://login.tailscale.com/admin/settings/keys
    # Then save it to /persist/system/tailscale-auth-key
    authKeyFile = "/persist/system/tailscale-auth-key";
    # Flags to pass to tailscale up on boot (only used if authKeyFile is set)
    extraUpFlags = [
      "--ssh"
      "--accept-routes"
      "--operator=${config.mainUser}"
    ];
  };

  # Enable the required kernel module for NAT traversal
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Open firewall ports for Tailscale
  networking.firewall = {
    # Allow Tailscale traffic
    allowedUDPPorts = [ 41641 ];
    # Trust the Tailscale interface
    trustedInterfaces = [ "tailscale0" ];
  };

  # Ensure tailscale package is available in system
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  # Auto-start tailscale daemon on boot
  systemd.services.tailscaled = {
    wantedBy = [ "multi-user.target" ];
  };
}
