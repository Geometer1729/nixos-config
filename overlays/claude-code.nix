{ ... }:
final: prev:
let
  version = "2.0.73";

  # Wrapper script that checks for updates on launch
  updateChecker = final.writeShellScript "claude-update-checker" ''
    CURRENT_VERSION="${version}"
    LATEST_VERSION=$(${final.curl}/bin/curl -s https://registry.npmjs.org/@anthropic-ai/claude-code/latest | ${final.jq}/bin/jq -r '.version' 2>/dev/null || echo "$CURRENT_VERSION")

    if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ] && [ -n "$LATEST_VERSION" ]; then
      echo "⚠️  Claude Code update available: $LATEST_VERSION (you have $CURRENT_VERSION)" >&2
      echo "   Run 'just update-claude' to update" >&2
      echo "" >&2
    fi
  '';

  claude-unwrapped = prev.claude-code.overrideAttrs (oldAttrs: rec {
    inherit version;

    src = final.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-kQRj8Vd735KyPzPZnoieE4TxUKHoCpnC62Blsh5dbWw=";
    };

    npmDepsHash = ""; #claude thinks this will be fixed if they change the deps
  });

in
{
  claude-code = final.symlinkJoin {
    name = "claude-code-wrapped-${version}";
    paths = [ claude-unwrapped ];
    buildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --run '${updateChecker}'
    '';
  };
}
