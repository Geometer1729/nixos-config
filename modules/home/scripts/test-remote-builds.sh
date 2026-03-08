# Test that remote build infrastructure between am and torag is working.
# Designed to run on am. If run on torag, re-executes itself on am via ssh.

set -euo pipefail

REMOTE="torag"
BUILDER="am"

# Trickshot: if we're not on am, bounce there
if [ "$(hostname)" != "$BUILDER" ]; then
  echo "Not on $BUILDER, bouncing via ssh..."
  exec ssh "bbrian@$BUILDER" test-remote-builds
fi

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
FAILURES=0

echo "=== Remote Build Infrastructure Test ==="
echo ""

# 1. SSH connectivity
echo "[1/6] SSH connectivity to $REMOTE"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "bbrian@$REMOTE" true 2>/dev/null; then
  pass "can ssh to $REMOTE"
else
  fail "cannot ssh to $REMOTE"
fi

# 2. nix-serve running locally on am
echo "[2/6] nix-serve running on $BUILDER"
if curl -sf --connect-timeout 5 http://localhost:5000/nix-cache-info >/dev/null 2>&1; then
  pass "nix-serve is running on port 5000"
else
  fail "nix-serve not reachable on localhost:5000"
fi

# 3. nix-serve reachable from torag
echo "[3/6] nix-serve reachable from $REMOTE"
if ssh -o ConnectTimeout=5 "bbrian@$REMOTE" "curl -sf --connect-timeout 5 http://$BUILDER:5000/nix-cache-info" >/dev/null 2>&1; then
  pass "$REMOTE can reach nix-serve on $BUILDER:5000"
else
  fail "$REMOTE cannot reach nix-serve on $BUILDER:5000"
fi

# 4. Store signing - check that am signs new paths
echo "[4/6] Store path signing on $BUILDER"
SIGNING_KEYS=$(nix show-config 2>/dev/null | grep "secret-key-files" || true)
if echo "$SIGNING_KEYS" | grep -q "cache-priv-key"; then
  pass "secret-key-files configured for signing"
else
  fail "secret-key-files not configured (paths won't be signed for substitution)"
fi

# 5. ssh-ng substituter - torag can query AND fetch a signed path from am
echo "[5/6] ssh-ng substituter from $REMOTE"
# Build a unique derivation on am so it can't be cached anywhere else
UNIQUE_TOKEN="test-remote-builds-$(date +%s)-$$"
TEST_PATH=$(nix build --no-link --print-out-paths --impure --expr "
  derivation {
    name = \"$UNIQUE_TOKEN\";
    builder = \"/bin/sh\";
    args = [\"-c\" \"echo $UNIQUE_TOKEN > \\\$out\"];
    system = \"x86_64-linux\";
  }
" 2>/dev/null)
if [ -z "$TEST_PATH" ]; then
  fail "couldn't build test path on $BUILDER"
else
  # Delete it from torag first if it somehow exists, then try to fetch via ssh-ng
  RESULT=$(ssh -o ConnectTimeout=5 "bbrian@$REMOTE" \
    "sudo nix store delete '$TEST_PATH' 2>/dev/null; \
     nix copy --from ssh-ng://bbrian@$BUILDER '$TEST_PATH' 2>&1 && echo OK" 2>&1)
  if echo "$RESULT" | grep -q "OK"; then
    pass "$REMOTE can fetch paths from $BUILDER via ssh-ng"
  else
    fail "$REMOTE cannot fetch from $BUILDER via ssh-ng: $RESULT"
  fi
fi

# 6. Remote building - torag can offload a build to am
echo "[6/6] Remote build from $REMOTE"
# Build a unique derivation that can't exist in any cache, forcing an actual remote build
# Use --max-jobs 0 on torag to force offloading (no local builds allowed)
UNIQUE_TOKEN2="test-remote-build-$(date +%s)-$$"
REMOTE_BUILD=$(ssh -o ConnectTimeout=10 "bbrian@$REMOTE" "
  nix build --no-link --print-out-paths --max-jobs 0 --impure --expr '
    derivation {
      name = \"$UNIQUE_TOKEN2\";
      builder = \"/bin/sh\";
      args = [\"-c\" \"echo $UNIQUE_TOKEN2 > \\\$out\"];
      system = \"x86_64-linux\";
    }
  ' 2>&1 && echo OK" 2>&1)
if echo "$REMOTE_BUILD" | grep -q "OK"; then
  pass "$REMOTE can offload builds to $BUILDER"
else
  fail "$REMOTE cannot offload builds to $BUILDER: $REMOTE_BUILD"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "All tests passed!"
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
