{ pkgs, ... }:
let
  me = {
    user = "bbrian";
    identityFile = "/home/bbrian/.ssh/id_ed25519";
  };
  cloudflare = {
    proxyCommand = "cloudflared access ssh --hostname %h";
  };
in
{
  home.packages = [ pkgs.cloudflared ];
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      tub = me // {
        hostname = "jsh.gov";
      };
      torag = me // cloudflare // {
        hostname = "torag.bbrian.xyz";
      };
      am = me // cloudflare // {
        hostname = "am.bbrian.xyz";
      };
    };
  };
}
