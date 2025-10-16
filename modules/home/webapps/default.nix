{ config, lib, pkgs, ... }:

{
  imports = [ ./lib.nix ];

  programs.webapps = {
    enable = true;

    apps = {
      perplexity = {
        name = "Perplexity AI";
        url = "https://perplexity.ai";
        description = "AI-powered search and research assistant";
        icon = "https://www.perplexity.ai/favicon.ico";
      };
    };
  };
}
