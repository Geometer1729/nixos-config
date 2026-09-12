{ config, ... }:
let
  keys = import ../../ssh-authorized-keys.nix;
in
{
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
  users.users.${config.mainUser}.openssh.authorizedKeys.keys = keys;
  users.users.root.openssh.authorizedKeys.keys = keys;
}
