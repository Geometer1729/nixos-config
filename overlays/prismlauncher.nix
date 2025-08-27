{ ... }:
final: prev: {
  # Some mods require nss this overlay fixes it
  prismlauncher = prev.prismlauncher.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ [ final.nss ];
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/prismlauncher \
        --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath [ final.nss ]}"
    '';
  });
}
