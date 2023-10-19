{ userName, opts, ... }:
let
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3LUPVpP5l+5xgT0zru9+fJtk/Kds/+F2UL/epe2D4K bbrian@am"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpgCGhWC4LE+vpiA+QydG8sg6TTbpRlJDCmPX3JfO+Z bbrian@raptor"
  ];
in
{
  users.users.${userName}.openssh.authorizedKeys.keys = keys;
  users.users.root.openssh.authorizedKeys.keys = keys;
  nix.sshServe.keys = if opts.builder then keys else [];
}
