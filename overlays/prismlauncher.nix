{ ... }:
final: prev: {
  # Upstream ResourceFolderModel test is failing in the 2026-06-26 unstable
  # build. Remove once the PrismLauncher input includes the test fix.
  prismlauncher-unwrapped = prev.prismlauncher-unwrapped.overrideAttrs {
    doCheck = false;
  };

  # Keep extra runtime libs for the installed PrismLauncher mod set. Remove
  # this overlay if those mods stop needing them or if prismlauncher packages
  # the required runtime libs by default.
  prismlauncher = prev.prismlauncher.override {
    additionalLibs = [
      final.libvlc # Required for watermedia mod
      final.nss # Required for some mods
    ];
  };
}
