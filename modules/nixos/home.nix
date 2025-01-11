{ pkgs, ... }:
let
  homeassistant-smartrent = pkgs.fetchFromGitHub {
    owner = "ZacheryThomas";
    repo = "homeassistant-smartrent";
    rev = "main";
    sha256 = "sha256-FIfTrbIGP7FztvifI9wVLtepQZKwd70xImncmoYGu6k=";
  };
  smartrent-py =
    let
      pname = "smartrent-py";
      version = "0.4.5";
    in
    pkgs.buildPythonPackage {
      inherit pname version;
      src = pkgs.fetchPypi {
        inherit pname version;
        sha256 = "sha256-128T4CtMVTUoQK0V71xk888CP3foBjfYDGeGFWbivdM=";
      };
    };
in
{
  networking.firewall.allowedTCPPorts = [ 8123 ];
  # TODO try the customComponents field instead
  systemd.tmpfiles.rules = [
    "C /var/lib/hass/custom_components/smartrent - - - - ${homeassistant-smartrent}/custom_components/smartrent"
    "Z /var/lib/hass/custom_components 770 hass hass - -"
  ];
  services.home-assistant = {
    enable = true;
    extraPackages = python3Packages: with python3Packages; [
      ibeacon-ble
      govee-ble
      websockets
      #pyicloud
      smartrent-py
    ];
    configWritable = true;
    lovelaceConfigWritable = true;
    #customComponents = with pkgs.home-assistant-custom-components; [
    #  #smartrent
    #];

    extraComponents = [
      # Required components for onboarding
      "esphome"
      "met"
      "radio_browser"
    ];


    config = {
      # Basic setup configuration
      default_config = { };
      automation = "!include automations.yaml";
      script = "!include scripts.yaml";
      http = {
        server_host = "::1";
        trusted_proxies = [ "::1" ];
        use_x_forwarded_for = true;
      };
    };
  };
}
