{ ... }:
final: prev: {
  # Keep extra runtime libs for PrismLauncher and launched instances. Remove
  # entries once upstream packages the required runtime libs by default.
  prismlauncher = prev.prismlauncher.override {
    # Remove once the ResourceFolderModel timer tests stop timing out in the
    # Nix sandbox. Keep the rest of the upstream test suite enabled.
    prismlauncher-unwrapped = prev.prismlauncher-unwrapped.overrideAttrs {
      checkPhase = "ctest --output-on-failure --exclude-regex '^ResourceFolderModel$'";
    };

    additionalLibs = [
      final.libvlc # Required for watermedia mod
      final.nss # Required for some mods
      final.wayland # Required for Minecraft 26.1+ native Wayland
    ];
  };
}
