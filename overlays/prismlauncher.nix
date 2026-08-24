{ ... }:
final: prev: {
  # Keep extra runtime libs for PrismLauncher and launched instances. Remove
  # entries once upstream packages the required runtime libs by default.
  prismlauncher = prev.prismlauncher.override {
    additionalLibs = [
      final.libvlc # Required for watermedia mod
      final.nss # Required for some mods
      final.wayland # Required for Minecraft 26.1+ native Wayland
    ];
  };
}
