{ ... }:
final: prev: {
  # PrismLauncher develop currently calls find_package(PkgConfig) without
  # adding pkg-config to nativeBuildInputs. Remove once upstream fixes this.
  prismlauncher-unwrapped = prev.prismlauncher-unwrapped.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.pkg-config ];
  });

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
