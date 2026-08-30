{ config, ... }:
let
  keys = import ../../ssh-authorized-keys.nix;
in
{
  users.users.${config.mainUser}.openssh.authorizedKeys.keys = keys;
  users.users.yixin.openssh.authorizedKeys.keys = keys;
  users.users.root.openssh.authorizedKeys.keys = keys;
  nix.sshServe.keys = keys;
}
