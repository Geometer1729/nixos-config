{ ... }:
{
  # unclear if this did anything tbh
  services.dnscache.enable = true;
  #networking.networkmanager.dns = "systemd-resolve";
  networking.nameservers = [ "8.8.8.8" ];
}
