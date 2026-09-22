# Test the distributed builders and binary caches shared by am, balrog, and torag.
# The test is orchestrated from am because it is the remote builder and one cache source.
# shellcheck shell=bash

set -euo pipefail

BUILDER="am"
CLIENTS=(balrog torag)
HOSTS=(am balrog torag)
FAILURES=0

if [ "$(hostname)" != "$BUILDER" ]; then
  echo "Not on $BUILDER, bouncing via ssh..."
  exec ssh "bbrian@$BUILDER" test-remote-builds
fi

pass() { echo "  PASS: $1"; }
fail() {
  echo "  FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

run_on() {
  local host=$1
  shift
  if [ "$host" = "$BUILDER" ]; then
    "$@"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "bbrian@$host" "$@"
  fi
}

test_remote_builder() {
  local client=$1 token output
  token="${client}-builder-test-$(date +%s)-$$"

  if output=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "bbrian@$client" "
    path=\$(nix build -L --no-link --print-out-paths --max-jobs 0 --impure --expr '
      derivation {
        name = \"$token\";
        builder = \"/bin/sh\";
        args = [\"-c\" \"echo $token > \\\$out\"];
        system = \"x86_64-linux\";
      }
    ')
    test \"\$(/run/current-system/sw/bin/cat \"\$path\")\" = \"$token\"
  " 2>&1); then
    if grep -q "on 'ssh://bbrian@$BUILDER'" <<<"$output"; then
      pass "$client built a fresh derivation on $BUILDER"
    else
      fail "$client completed the build without evidence it ran on $BUILDER"
      echo "$output"
    fi
  else
    fail "$client could not build on $BUILDER"
    echo "$output"
  fi
}

build_local_path() {
  local token=$1
  nix build --builders "" --no-link --print-out-paths --impure --expr "
    derivation {
      name = \"$token\";
      builder = \"/bin/sh\";
      args = [\"-c\" \"echo $token > \\\$out\"];
      system = \"x86_64-linux\";
    }
  "
}

build_remote_local_path() {
  local host=$1 token=$2
  ssh -o BatchMode=yes -o ConnectTimeout=10 "bbrian@$host" "
    nix build --builders '' --no-link --print-out-paths --impure --expr '
      derivation {
        name = \"$token\";
        builder = \"/bin/sh\";
        args = [\"-c\" \"echo $token > \\\$out\"];
        system = \"x86_64-linux\";
      }
    '
  "
}

test_cache_copy() {
  local source=$1 client=$2 store=$3 path=$4 token=$5 output

  if output=$(run_on "$client" sh -c "
    test ! -e '$path' &&
    nix copy --from '$store' '$path' &&
    nix store verify --sigs-needed 1 '$path' &&
    test \"\$(/run/current-system/sw/bin/cat '$path')\" = '$token'
  " 2>&1); then
    pass "$source cache supplied a signed path to $client via $store"
  else
    fail "$source cache could not supply a signed path to $client via $store"
    echo "$output"
  fi
}

echo "=== Build and Cache Infrastructure Test ==="
echo

echo "SSH connectivity"
for host in "${CLIENTS[@]}"; do
  if run_on "$host" true 2>/dev/null; then
    pass "can connect to $host"
  else
    fail "cannot connect to $host"
  fi
done
echo

echo "Remote building"
for client in "${CLIENTS[@]}"; do
  test_remote_builder "$client"
done
echo

echo "HTTP cache endpoints"
for client in "${HOSTS[@]}"; do
  for cache in am balrog; do
    if run_on "$client" curl -fsS --retry 2 --connect-timeout 5 "http://$cache:5000/nix-cache-info" >/dev/null 2>&1; then
      pass "$client can reach $cache cache"
    else
      fail "$client cannot reach $cache cache"
    fi
  done
done
echo

echo "Signed cache transfers"
am_token="am-cache-test-$(date +%s)-$$"
balrog_token="balrog-cache-test-$(date +%s)-$$"
am_path=""
balrog_path=""

if am_path=$(build_local_path "$am_token"); then
  pass "created a fresh signed path on am"
else
  fail "could not create a cache test path on am"
fi

if balrog_path=$(build_remote_local_path balrog "$balrog_token"); then
  pass "created a fresh signed path locally on balrog"
else
  fail "could not create a cache test path locally on balrog"
fi

if [ -n "$am_path" ]; then
  test_cache_copy am balrog "ssh-ng://bbrian@am" "$am_path" "$am_token"
  test_cache_copy am torag "ssh-ng://bbrian@am" "$am_path" "$am_token"
fi

if [ -n "$balrog_path" ]; then
  test_cache_copy balrog am "http://balrog:5000" "$balrog_path" "$balrog_token"
  test_cache_copy balrog torag "http://balrog:5000" "$balrog_path" "$balrog_token"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All build and cache tests passed!"
else
  echo "$FAILURES test(s) failed."
  exit 1
fi
