{ pkgs, ... }:
let
  me = {
    user = "bbrian";
    identityFile = "/home/bbrian/.ssh/id_ed25519";
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      tub = me // {
        hostname = "jsh.gov";
      };
      capitol = me // {
        hostname = "192.168.1.227";
        proxyJump = "tub";
      };
      # I guess with tailscale I don't really need this
      #torag = me // {
      #  hostname = "10.0.0.7";
      #};
      #am = me // {
      #  hostname = "10.0.0.248";
      #};
    };
  };
}
