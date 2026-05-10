{ ... }:
final: prev: {
  # Keep opencode ahead of nixpkgs because 1.14.31 had cursor flicker issues for us
  # and nixpkgs was lagging behind upstream fixes. Remove this overlay once nixpkgs
  # packages a version new enough to avoid the flicker regression.
  opencode = prev.opencode.overrideAttrs (old: rec {
    version = "1.14.46";

    src = prev.fetchFromGitHub {
      owner = "anomalyco";
      repo = "opencode";
      tag = "v${version}";
      hash = "sha256-4qyCmYDTNnWuSgDYQuvawhRj2Nh06sAAjSVp78aTKlI=";
    };

    node_modules = old.node_modules.overrideAttrs (_: {
      inherit version src;
      outputHash = "sha256-R6jVIeuv2IikSAuTMOjzn8N8+GS6USSG9+cTBUseBNg=";
    });
  });
}
