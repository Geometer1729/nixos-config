{ flake, config, lib, ... }:
{
  imports = [ ./steam.nix ];

  # Apply the nightly package before our local runtime-library overlay.
  nixpkgs.overlays = lib.mkBefore [ flake.inputs.prismlauncher.overlays.default ];

  home-manager.users = {
    ${config.mainUser}.imports = [ ./home.nix ];
    yixin.imports = [ ./home.nix ];
  };

  environment.persistence."/persist/system".users.${config.mainUser}.directories = [
    ".local/share/PrismLauncher"
    ".local/share/Steam"
  ];
}
