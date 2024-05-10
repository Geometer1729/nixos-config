{ ... }:
{
  nix = {
    settings = {
      allowed-users = [ "nix-serve" ];
      trusted-users = [ "nix-serve" ];
    };
    sshServe.enable = true;
    settings.max-jobs = 40;
  };
}
