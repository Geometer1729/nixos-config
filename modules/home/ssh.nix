{ pkgs, ... }:
let
  me = {
    user = "bbrian";
    identityFile = "/home/bbrian/.ssh/id_ed25519";
  };
in
{
  # Enable ssh-agent for regular SSH key management
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      # Set TERM for hosts that don't have ghostty terminfo
      "*" = {
        setEnv = { TERM = "xterm-256color"; };
      };
      # Use Tailscale SSH for all .tail-scale.ts.net hosts
      "*.tail-scale.ts.net" = {
        proxyCommand = "${pkgs.tailscale}/bin/tailscale nc %h %p";
        user = me.user;
      };
      tub = me // {
        hostname = "jsh.gov";
      };
      capitol = me // {
        hostname = "192.168.1.227";
        proxyJump = "tub";
      };
    };
  };
}
