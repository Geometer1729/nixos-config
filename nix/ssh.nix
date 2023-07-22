{ userName,... }:
let
  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIq6wxRwdpUdae2guAcJk/OqO8pI5jq4Q/bu96XVYwR4 bbrian@am"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpgCGhWC4LE+vpiA+QydG8sg6TTbpRlJDCmPX3JfO+Z bbrian@raptor"
  ];
in
{
  users.users.${userName}.openssh.authorizedKeys.keys = keys;
  users.users.root.openssh.authorizedKeys.keys = keys;
}
