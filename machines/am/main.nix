{userName,...}:
let
  # TODO avoid repeating the keys
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIq6wxRwdpUdae2guAcJk/OqO8pI5jq4Q/bu96XVYwR4 bbrian@am"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpgCGhWC4LE+vpiA+QydG8sg6TTbpRlJDCmPX3JfO+Z bbrian@raptor"
  ];
in
{
  nix = {
    settings = {
      allowed-users = [ "nix-serve" ];
      trusted-users = [ "nix-serve" ];
    };
    sshServe.enable = true;
    sshServe.keys = keys;
    settings.max-jobs = 40;
  };
  services.nix-serve = {
    port = 5000; # the defualt but just want to see it
    enable = true;
    secretKeyFile = "/home/${userName}/secrets/secret-key-file";
  };
  users.extraUsers.nixBuild = {
    isSystemUser = true;
    openssh.authorizedKeys.keys = keys;
    group = "nixBuild";
  };
  users.extraUsers.nix-serve = {
    isSystemUser = true;
    openssh.authorizedKeys.keys = keys;
    group = "nixBuild";
  };
}
