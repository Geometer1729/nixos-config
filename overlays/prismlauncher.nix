{ ... }:
final: prev: {
  # temporary fix for
  #https://github.com/NixOS/nixpkgs/issues/425323
  jdk8 = prev.jdk8.overrideAttrs {
    separateDebugInfo = false;
    __structuredAttrs = false;
  };
  # Some mods require nss this overlay fixes it
  prismlauncher = prev.prismlauncher.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ [ final.nss ];
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/prismlauncher \
        --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath [ final.nss ]}"
    '';
  });
}
