_:
final: prev: {
  # nixpkgs lags far behind upstream gh-stack releases. Remove once nixpkgs
  # reaches this version.
  gh-stack =
    final.lib.warnIf (final.lib.versionAtLeast prev.gh-stack.version "0.2.0")
      "nixpkgs gh-stack is ${prev.gh-stack.version}; drop overlays/gh-stack.nix"
      (prev.gh-stack.overrideAttrs (oldAttrs: {
        version = "0.2.0";
        src = oldAttrs.src.override {
          tag = "v0.2.0";
          hash = "sha256-70H1kOdvklTeB8OVFg7g6xQ4rn0gqv+zU7yjDYPd3vo=";
        };
        vendorHash = "sha256-Otstml5TSTJeYsP9o94aUperP1MgT2axa/wqALEnXYk=";
        nativeCheckInputs = (oldAttrs.nativeCheckInputs or [ ]) ++ [ final.git ];
        # modifyview tests expect to run inside a git checkout.
        preCheck = (oldAttrs.preCheck or "") + ''
          git init -q
        '';
      }));
}
