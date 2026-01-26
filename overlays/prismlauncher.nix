{ ... }:
final: prev: {
  # Some mods require nss and vlc (for watermedia)
  prismlauncher = prev.prismlauncher.override {
    additionalLibs = [
      final.libvlc # Required for watermedia mod
      final.nss # Required for some mods
    ];
  };
}
