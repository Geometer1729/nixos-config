{ config, lib, ... }:
let
  owned = { owner = config.mainUser; };
in
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";
    # User SSH keys are persisted and available before activation restores /etc.
    age.sshKeyPaths = [ "/persist/system/home/${config.mainUser}/.ssh/id_ed25519" ];
    gnupg.sshKeyPaths = [ ];

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
