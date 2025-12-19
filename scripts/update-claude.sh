#!/usr/bin/env bash
set -euo pipefail

# Get latest version from npm
echo "Fetching latest Claude Code version..."
LATEST_VERSION=$(curl -s https://registry.npmjs.org/@anthropic-ai/claude-code/latest | jq -r '.version')
echo "Latest version: $LATEST_VERSION"

# Get current version from overlay
CURRENT_VERSION=$(grep 'version = ' overlays/claude-code.nix | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo "Current version: $CURRENT_VERSION"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date!"
  exit 0
fi

echo "Updating to $LATEST_VERSION..."

# Update version in overlay
sed -i "s/version = \"$CURRENT_VERSION\"/version = \"$LATEST_VERSION\"/" overlays/claude-code.nix

# Prefetch the source to get the hash
echo "Prefetching source..."
SRC_HASH=$(nix-prefetch-url --unpack "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$LATEST_VERSION.tgz" 2>&1 | tail -1)
SRI_HASH=$(nix hash to-sri --type sha256 "$SRC_HASH")

# Update the source hash in overlay
sed -i "0,/hash = \"sha256-.*\"/s//hash = \"$SRI_HASH\"/" overlays/claude-code.nix

echo "Source hash updated to: $SRI_HASH"

# Now build to get the npmDepsHash error
echo "Building to determine npmDepsHash..."
echo "This will fail - we'll extract the correct hash from the error..."

if BUILD_OUTPUT=$(nix build .#nixosConfigurations.am.config.system.build.toplevel --no-link 2>&1); then
  echo "Build succeeded (unexpected!)"
else
  # Extract the "got:" hash from the error
  NPM_HASH=$(echo "$BUILD_OUTPUT" | grep -A1 "got:" | tail -1 | awk '{print $1}' | tr -d ' ')

  if [ -n "$NPM_HASH" ]; then
    echo "Updating npmDepsHash to: $NPM_HASH"
    sed -i "0,/npmDepsHash = \"sha256-.*\"/s//npmDepsHash = \"$NPM_HASH\"/" overlays/claude-code.nix
    echo "✓ Overlay updated successfully!"
    echo ""
    echo "Run 'nh os test' to build and test the new version"
  else
    echo "❌ Could not extract npmDepsHash from build output"
    echo "You may need to manually update it"
    exit 1
  fi
fi
