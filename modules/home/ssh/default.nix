{ config, pkgs, ... }:
let
  me = {
    User = "bbrian";
    IdentityFile = "/home/bbrian/.ssh/id_ed25519";
  };
  sshOpen = config.scripts.ssh.packages.ssh-open;
  # Kept out of home.packages so it only shadows xdg-open in SSH sessions.
  xdgOpenShim = pkgs.runCommand "ssh-open-xdg-open" { } ''
    mkdir -p $out/bin
    ln -s ${sshOpen}/bin/ssh-open $out/bin/xdg-open
  '';
in
{
  scripts.ssh = {
    directory = ./.;
    extras = with pkgs; [ getent iproute2 tmux ];
  };

  # Send browser launches from SSH sessions back to the connecting machine.
  programs.zsh.envExtra = ''
    if [[ -n $SSH_CONNECTION ]]; then
      export BROWSER=${sshOpen}/bin/ssh-open
      path=(${xdgOpenShim}/bin ''${path:#${xdgOpenShim}/bin})
    fi
  '';

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
