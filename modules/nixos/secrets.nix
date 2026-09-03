{ config, lib, ... }:
let
  owned = { owner = config.mainUser or "bbrian"; };
in
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    age = {
      keyFile = "/persist/system/home/${config.mainUser or "bbrian"}/.config/sops/age/keys.txt";
      sshKeyPaths = [
        "/persist/system/home/${config.mainUser or "bbrian"}/.ssh/id_ed25519"
        "/etc/ssh/ssh_host_ed25519_key"
      ];
      generateKey = true;
    };

    secrets = {
      wifi = lib.mkIf (config.wifi.enable or false) { owner = "wpa_supplicant"; };
      hashedPassword = owned // { neededForUsers = true; };
      yixinHashedPassword = owned // { neededForUsers = true; };
      hosts = owned;
      gcloud_client_id = owned;
      gcloud_secret = owned;
      linear_api_key = owned;
      slack_token = owned;
      slack_mcp_client_id = owned;
      slack_mcp_client_secret = owned;
      taskwarrior-sync-secret = owned;
      foundryvtt-env = { };
    };
  };
  # secret hosts
  environment.etc.hosts.mode = "0644";
  system.activationScripts.hosts = {
    deps = [ "setupSecrets" "etc" ];
    text = ''
      cat /run/secrets/hosts >> /etc/hosts
    '';
  };
}
