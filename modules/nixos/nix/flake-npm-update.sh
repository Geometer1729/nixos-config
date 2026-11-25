# Move npm-pinned flake inputs to the versions their dist-tags name now, as
# `npm update` does for a package.json. flake.nix pins each to an exact tarball,
# with the tag to follow in a trailing comment:
#   name.url = "tarball+https://registry.npmjs.org/<package>/-/<file>.tgz"; # npm: <tag>
# A tag URL can't be the input itself: Nix locks it by content hash, so once the
# tag moves the lock can't be fetched again.
usage() {
  echo "Usage: flake-npm-update [flake-path]"
  echo "Repins every '# npm: <tag>' input in flake.nix to its tag's current tarball, then locks them."
}
case "${1-}" in
  -h | --help) usage; exit 0 ;;
  -*) usage >&2; exit 2 ;;
esac
flake=${1:-.}
file="$flake/flake.nix"
[[ -f "$file" ]] || { echo "No flake.nix in $flake" >&2; exit 1; }

pattern='^[[:space:]]*([A-Za-z0-9_-]+)\.url[[:space:]]*=[[:space:]]*"tarball\+(https://registry\.npmjs\.org/(.+)/-/[^"]+\.tgz)";[[:space:]]*#[[:space:]]*npm:[[:space:]]*([^[:space:]]+)'
content=$(<"$file")
found=0 changed=0
while IFS= read -r line; do
  [[ "$line" =~ $pattern ]] || continue
  input=${BASH_REMATCH[1]} pinned=${BASH_REMATCH[2]} package=${BASH_REMATCH[3]} tag=${BASH_REMATCH[4]}
  found=$((found + 1))
  current=$(curl -fsS "https://registry.npmjs.org/$package/$tag" | jq -er .dist.tarball)
  if [[ "$current" == "$pinned" ]]; then
    echo "$input ($package@$tag): ${pinned##*/} is current"
  else
    echo "$input ($package@$tag): ${pinned##*/} -> ${current##*/}"
    content=${content//"\"tarball+$pinned\""/"\"tarball+$current\""}
    changed=$((changed + 1))
  fi
done <<<"$content"

if ((found == 0)); then
  echo "No '# npm: <tag>' inputs in $file" >&2
  exit 1
fi
if ((changed > 0)); then
  printf '%s\n' "$content" >"$file"
  # Locks the changed URLs and leaves every other input where it is.
  nix flake lock "$flake"
fi
