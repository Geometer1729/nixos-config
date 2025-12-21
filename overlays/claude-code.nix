{ ... }:
final: prev:
{
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: rec {
    version = "2.0.74";

    src = final.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-J3m1KUO8Bkzwh3fLI96LoWw6VsSwoETcSq2IufeRW9E=";
    };

    npmDepsHash = ""; #claude thinks this will be fixed if they change the deps
  });
}
