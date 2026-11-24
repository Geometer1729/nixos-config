_:
_final: prev: {
  # pass-wayland derives from pass, so patch the base package for all variants.
  # wl-clipboard 2.3 supports this hint, which clipboard history tools can honor.
  # Upstream master does since 2026-10-27, unreleased after 1.7.4; remove once
  # nixpkgs pass is newer than 1.7.4 (--replace-fail then fails the build).
  pass = prev.pass.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace src/password-store.sh \
        --replace-fail 'local copy_cmd=( wl-copy )' \
                       'local copy_cmd=( wl-copy --sensitive )'
    '';
  });
}
