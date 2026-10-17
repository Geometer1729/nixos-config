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

  programs.ssh.knownHosts = {
    durin.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpLa0qnwzKS2Au6VkrfD8Yo7U9udsRJMhzDBxEv6fx0";
    narvi.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICtJxLeb6qRxO7NUBqrptGwY/UoHAUhqauY7IwhVzg+z";
    gimli.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVdkr6cMcuuKeM5jSC8uvkzehLpuSwb83FEKk0j/tu/";
  };
}
