{ ... }:
{
  boot = {
    #kernel.sysctl = {
    #  "vm.overcommit_memory" = 2;
    #  "vm.overcommit_ratio" = 100;
    #};
    tmp.cleanOnBoot = true;
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 1;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        configurationLimit = 20;
      };
    };
  };


  # Boot faster - optimized dhcpcd configuration
  networking = {
    dhcpcd.enable = true;
    dhcpcd.wait = "background"; # Don't block boot waiting for DHCP
    dhcpcd.extraConfig = ''
      # Fast boot optimizations
      timeout 1         # Only wait 1 second for DHCP
      noarp            # Skip ARP probes (saves ~2 seconds)
      nodelay          # Don't add random delay
      noipv4ll         # Skip IPv4 link-local address assignment

      # Only request what we need
      option domain_name_servers, domain_name, domain_search
      option classless_static_routes
      option interface_mtu

      # Background IPv6 to speed up IPv4
      ipv6rs

      # Reduce discover attempts
      reboot 0
    '';
  };

  # Prevent services from waiting for network
  systemd.services = {
    NetworkManager-wait-online.enable = false;
    systemd-networkd-wait-online.enable = false;
  };

}
