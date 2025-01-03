{ config, ... }:
let
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG3LUPVpP5l+5xgT0zru9+fJtk/Kds/+F2UL/epe2D4K bbrian@am"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ/cWZ3qZqwLWRrp07Sl2NIGEse4JkgnZxgZ+bubAl/k bbrian@raptor"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFMycTM2SljOHjVFbnonUwdZu1LDEghhUwep7jxTa25s bbrian@torag"
  ];
in
{
  users.users.${config.mainUser}.openssh.authorizedKeys.keys = keys;
  users.users.root.openssh.authorizedKeys.keys = keys;
  nix.sshServe.keys = keys;
}
