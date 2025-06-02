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
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
    };
  };


  # Boot faster

  # keeps breaking cloudflare I give up
  #let
  #  wait = {
  #    after = [ "network-online.target" "dhcpcd.service" ];
  #    wants = [ "network-online.target" "dhcpcd.service" ];
  #  };
  #  waitAndRestart = wait // {
  #    serviceConfig = {
  #      # Force cloudflared to wait until DHCP and DNS are fully operational
  #      ExecStartPre = "/run/current-system/sw/bin/sleep 5"; # Optional buffer
  #      Restart = "on-failure";
  #      RestartSec = "5s";
  #    };
  #  };
  #  dontWaitFor = {
  #    wantedBy = lib.mkForce [ ];
  #  };
  #in
  #networking = {
  #  dhcpcd.enable = true;
  #  dhcpcd.wait = "background";
  #  dhcpcd.extraConfig = ''
  #    timeout 1
  #    noarp
  #    nodelay
  #  '';
  #};

  #systemd.network.networks = {
  # internet0 = {
  #   matchConfig = { Name = "enp4s0"; };
  #   networkConfig = { DHCP = "ipv4"; };
  #  };
  #};

  #systemd = {
  #  targets = {
  #    home-assistant = dontWaitFor;
  #  };
  #  services = {
  #    ntpd = waitAndRestart;
  #    sshd = wait;
  #    home-assistant = waitAndRestart;
  #    "cloudflared-tunnel-${config.cloudflare-id}" = waitAndRestart // dontWaitFor;
  #    cloudflare-warp = dontWaitFor;
  #  };
  #};

}
