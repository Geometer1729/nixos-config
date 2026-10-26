# Official ChatGPT desktop app (Chat, Work, and Codex with its built-in browser).
{ flake, config, pkgs, ... }:
let
  unstable = import flake.inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  home-manager.users.${config.mainUser}.home.packages = [ unstable.chatgpt ];

  environment.persistence."/persist/system".users.${config.mainUser}.directories = [
    ".codex"
    ".config/Codex"
    # ~1.7G of sandbox runtimes fetched on first launch.
    ".cache/codex-runtimes"
  ];
}
