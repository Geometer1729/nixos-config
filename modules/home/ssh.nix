{ pkgs, ... }:
let
  me = {
    User = "bbrian";
    IdentityFile = "/home/bbrian/.ssh/id_ed25519";
  };
in
{
  # Enable ssh-agent for regular SSH key management
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      # Set TERM for hosts that don't have ghostty terminfo
      "*" = {
        SetEnv = { TERM = "xterm-256color"; };
      };
      # Use Tailscale SSH for all .tail-scale.ts.net hosts
      "*.tail-scale.ts.net" = {
        ProxyCommand = "${pkgs.tailscale}/bin/tailscale nc %h %p";
        inherit (me) User;
      };
      tub = me // {
        HostName = "jsh.gov";
      };
      capitol = me // {
        HostName = "192.168.1.227";
        ProxyJump = "tub";
      };
    };
  };
}
