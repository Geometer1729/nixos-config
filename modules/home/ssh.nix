{ ... }:
let
  me = {
    user = "bbrian";
    identityFile = "~/.ssh/id_ed25519";
  };
  cloudflare = {
      proxyCommand = "cloudflared access ssh --hostname %h";
  };
in
{
  programs.ssh = {
    enable = true;
    matchBlocks = {
      tub = me // {
        hostname = "jsh.gov";
      } ;
      torag = me // cloudflare // {
        hostname = "torag.bbrian.xyz";
      };
      am = me // cloudflare // {
        hostname = "am.bbrian.xyz";
      };
    };
  };
}
