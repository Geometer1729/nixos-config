_:
_final: prev: {
  # pass-wayland derives from pass, so patch the base package for all variants.
  # wl-clipboard 2.3 supports this hint, which clipboard history tools can honor.
  # Remove once upstream pass marks its Wayland clipboard copies as sensitive.
  pass = prev.pass.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace src/password-store.sh \
        --replace-fail 'local copy_cmd=( wl-copy )' \
                       'local copy_cmd=( wl-copy --sensitive )'
    '';
  });
}
