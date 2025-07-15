{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Games
    #prismlauncher  # Temporarily disabled - OpenJDK circular dependency
  ];

  # Some mods require nss this overlay fixes it
  nixpkgs.overlays = [
    (final: prev: {
      prismlauncher = prev.prismlauncher.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs ++ [ prev.nss ];
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/prismlauncher \
            --prefix LD_LIBRARY_PATH : "${prev.lib.makeLibraryPath [ prev.nss ]}"
        '';
      });
    })
  ];
}
