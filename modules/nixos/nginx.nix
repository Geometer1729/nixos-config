{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts.default.default = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
