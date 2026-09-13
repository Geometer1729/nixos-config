_:
final: prev: {
  # PrismLauncher PR #6045 left the combined Client/Server Modrinth filter
  # with an unqualified facet, causing HTTP 400. Remove once upstream adds
  # the missing environment: prefix to UniversalSide in ModrinthAPI.h.
  prismlauncher-unwrapped = prev.prismlauncher-unwrapped.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace launcher/modplatform/modrinth/ModrinthAPI.h \
        --replace-fail '"environment:client_and_server","client_or_server_prefers_both"' \
                       '"environment:client_and_server","environment:client_or_server_prefers_both"'
    '';
  });

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
