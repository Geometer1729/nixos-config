{ flake, ... }:
let
  inherit (flake) inputs;
in
{
  services.xserver.enable = true;

  imports = [
    inputs.xlibre-overlay.nixosModules.overlay-xlibre-xserver
    inputs.xlibre-overlay.nixosModules.overlay-all-xlibre-drivers
  ];

  # Fix xvfb: nixpkgs' xvfb uses autoconf but xlibre-xserver uses meson,
  # so xvfb fails to build from xlibre source. Reuse the Xvfb binary
  # that xlibre-xserver already builds via -Dxvfb=true.
  nixpkgs.overlays = [
    (_final: prev: {
      xvfb = prev.runCommand "xvfb-${prev.xorg-server.version}"
        {
          meta = prev.xvfb.meta // { mainProgram = "Xvfb"; };
        } ''
        mkdir -p $out/bin
        ln -s ${prev.xorg-server}/bin/Xvfb $out/bin/Xvfb
      '';
    })
  ];
}
