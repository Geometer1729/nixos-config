# Analyze nixpkgs changes filtered by packages used in config
# Usage: nixpkgs-changelog <old-rev> <new-rev> [--json]
#
# This script:
# 1. Extracts package names from your NixOS config
# 2. Fetches commits from nixpkgs between revisions
# 3. Filters to only show commits affecting your packages
# 4. Fetches PR details for richer context

source "$SCRIPTS_LIB/flake-update-lib.sh"

# Number of commit pages to fetch (100 per page)
# 14k commits = 140 pages, but let's cap at 200 to be safe
MAX_PAGES=200

# Parse arguments
OLD_REV=""
NEW_REV=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    -h|--help)
      echo "Usage: nixpkgs-changelog <old-rev> <new-rev> [--json]"
      echo ""
      echo "Analyze nixpkgs changes filtered by packages in your config."
      echo ""
      echo "Options:"
      echo "  --json    Output as JSON instead of human-readable"
      exit 0
      ;;
    *)
      if [[ -z "$OLD_REV" ]]; then
        OLD_REV="$1"
      else
        NEW_REV="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$OLD_REV" || -z "$NEW_REV" ]]; then
  echo "Usage: nixpkgs-changelog <old-rev> <new-rev> [--json]" >&2
  exit 1
fi

ensure_output_dir

# Step 1: Extract package names from config
log_info "Extracting package names from config..."

PACKAGES_FILE="$FLAKE_UPDATE_DIR/config-packages.txt"
: > "$PACKAGES_FILE"  # Truncate file

# Get system packages
nix eval .#nixosConfigurations.am.config.environment.systemPackages --json 2>/dev/null | \
   jq -r '.[]' 2>/dev/null | sed 's|/nix/store/[a-z0-9]*-||' | sed 's|-[0-9].*||' >> "$PACKAGES_FILE" || true

# Get home-manager packages
nix eval .#nixosConfigurations.am.config.home-manager.users.bbrian.home.packages --json 2>/dev/null | \
   jq -r '.[]' 2>/dev/null | sed 's|/nix/store/[a-z0-9]*-||' | sed 's|-[0-9].*||' >> "$PACKAGES_FILE" || true

# Also try torag configuration if am doesn't exist
nix eval .#nixosConfigurations.torag.config.environment.systemPackages --json 2>/dev/null | \
   jq -r '.[]' 2>/dev/null | sed 's|/nix/store/[a-z0-9]*-||' | sed 's|-[0-9].*||' >> "$PACKAGES_FILE" || true

# Deduplicate and clean
sort -u "$PACKAGES_FILE" -o "$PACKAGES_FILE" 2>/dev/null || true

PACKAGE_COUNT=$(wc -l < "$PACKAGES_FILE" 2>/dev/null || echo "0")
log_info "Found $PACKAGE_COUNT unique packages in config"

# Step 2: Fetch commits from nixpkgs
log_info "Fetching nixpkgs commits from $OLD_REV to $NEW_REV..."

COMMITS_FILE="$FLAKE_UPDATE_DIR/nixpkgs-commits.json"
PAGE_FILE="$FLAKE_UPDATE_DIR/page.json"
echo "[]" > "$COMMITS_FILE"

for page in $(seq 1 $MAX_PAGES); do
  log_info "  Fetching page $page..."

  if ! gh api "repos/NixOS/nixpkgs/commits?sha=$NEW_REV&per_page=100&page=$page" > "$PAGE_FILE" 2>/dev/null; then
    log_warn "Failed to fetch page $page"
    break
  fi

  # Check if empty
  if [[ ! -s "$PAGE_FILE" ]] || jq -e '. == []' "$PAGE_FILE" >/dev/null 2>&1; then
    break
  fi

  # Check if we've gone past the old revision
  if jq -e ".[] | select(.sha == \"$OLD_REV\")" "$PAGE_FILE" >/dev/null 2>&1; then
    # Filter commits up to old revision and merge
    jq "[.[] | select(.sha != \"$OLD_REV\")]" "$PAGE_FILE" > "$PAGE_FILE.filtered"
    jq -s '.[0] + .[1]' "$COMMITS_FILE" "$PAGE_FILE.filtered" > "$COMMITS_FILE.tmp"
    mv -f "$COMMITS_FILE.tmp" "$COMMITS_FILE"
    rm -f "$PAGE_FILE.filtered"
    break
  fi

  # Merge this page using file-based slurp
  jq -s '.[0] + .[1]' "$COMMITS_FILE" "$PAGE_FILE" > "$COMMITS_FILE.tmp"
  mv "$COMMITS_FILE.tmp" "$COMMITS_FILE"

  # Rate limit protection
  sleep 0.5
done

rm -f "$PAGE_FILE"
COMMIT_COUNT=$(jq 'length' "$COMMITS_FILE")
log_info "Fetched $COMMIT_COUNT commits"

# Step 3: Filter commits by package names
log_info "Filtering commits by config packages..."

MATCHES_FILE="$FLAKE_UPDATE_DIR/nixpkgs-matches.json"

# Extract commit messages and match against packages
jq -r '.[] | "\(.sha)\t\(.commit.message | split("\n")[0])"' "$COMMITS_FILE" | \
while IFS=$'\t' read -r sha message; do
  # Extract package name (first token before colon)
  raw_pkg=$(echo "$message" | cut -d':' -f1 | tr '[:upper:]' '[:lower:]' | sed 's/^ *//' | sed 's/ *$//')

  # Strip common prefixes to get the actual package name
  # nixos/hyprland -> hyprland, python3Packages.foo -> foo, haskellPackages.bar -> bar
  pkg_name=$(echo "$raw_pkg" | sed -E 's|^nixos/||; s|^[a-z0-9]+packages\.||i; s|plugins\..*||')

  # Check if package is in our config
  if grep -iqw "$pkg_name" "$PACKAGES_FILE" 2>/dev/null; then
    # Extract PR number if present (grep returns 1 if no match, so use || true)
    pr_num=$(echo "$message" | grep -oE '#[0-9]+' | tail -1 | tr -d '#' || true)
    echo "$sha|$pkg_name|$message|$pr_num"
  fi
done > "$FLAKE_UPDATE_DIR/matches.txt"

# Also find breaking change commits
log_info "Checking for potential breaking changes..."
jq -r '.[] | "\(.sha)\t\(.commit.message | split("\n")[0])"' "$COMMITS_FILE" | \
  grep -iE 'breaking|deprecat|BREAKING' | \
  while IFS=$'\t' read -r sha message; do
    pr_num=$(echo "$message" | grep -oE '#[0-9]+' | tail -1 | tr -d '#' || true)
    echo "$sha|BREAKING|$message|$pr_num"
  done >> "$FLAKE_UPDATE_DIR/matches.txt" || true  # grep returns 1 if no matches

# Step 4: Fetch PR details for matches
log_info "Fetching PR details for matches..."

# Build JSON array of matches with PR details
PR_TEMP="$FLAKE_UPDATE_DIR/pr_temp.json"
echo "[]" > "$MATCHES_FILE"

while IFS='|' read -r sha pkg message pr_num; do
  [[ -z "$sha" ]] && continue

  if [[ -n "$pr_num" ]]; then
    # Fetch PR details to temp file to avoid shell escaping issues
    if gh api "repos/NixOS/nixpkgs/pulls/$pr_num" > "$PR_TEMP" 2>/dev/null; then
      # Extract fields using jq with proper escaping, writing to a temp JSON
      jq -n \
        --arg sha "$sha" \
        --arg package "$pkg" \
        --arg message "$message" \
        --argjson pr_num "$pr_num" \
        --slurpfile pr "$PR_TEMP" \
        '{
          sha: $sha,
          package: $package,
          message: $message,
          pr_number: $pr_num,
          pr_body: ($pr[0].body // "" | gsub("[\\x00-\\x1f]"; " ") | split("\n")[0:5] | join(" ") | .[0:500]),
          pr_labels: [($pr[0].labels // [])[].name],
          pr_merged: $pr[0].merged_at
        }' > "$PR_TEMP.entry"

      # Merge into matches file
      jq -s '.[0] + [.[1]]' "$MATCHES_FILE" "$PR_TEMP.entry" > "$MATCHES_FILE.tmp"
      mv -f "$MATCHES_FILE.tmp" "$MATCHES_FILE"
      rm -f "$PR_TEMP.entry"
    fi
    sleep 0.3  # Rate limit protection
  else
    # No PR number - create entry without PR details
    jq -n \
      --arg sha "$sha" \
      --arg package "$pkg" \
      --arg message "$message" \
      '{sha: $sha, package: $package, message: $message, pr_number: null, pr_body: null, pr_labels: [], pr_merged: null}' > "$PR_TEMP.entry"
    jq -s '.[0] + [.[1]]' "$MATCHES_FILE" "$PR_TEMP.entry" > "$MATCHES_FILE.tmp"
    mv -f "$MATCHES_FILE.tmp" "$MATCHES_FILE"
    rm -f "$PR_TEMP.entry"
  fi

done < "$FLAKE_UPDATE_DIR/matches.txt"

rm -f "$PR_TEMP"

# Clean up temp files
rm -f "$FLAKE_UPDATE_DIR/matches.txt"

MATCH_COUNT=$(jq 'length' "$MATCHES_FILE")
log_info "Found $MATCH_COUNT relevant changes"

# Step 5: Output results
if $JSON_OUTPUT; then
  jq -n \
    --arg old_rev "$OLD_REV" \
    --arg new_rev "$NEW_REV" \
    --argjson matches "$(cat "$MATCHES_FILE")" \
    --arg packages_file "$PACKAGES_FILE" \
    --arg total_commits "$COMMIT_COUNT" \
    '{
      old_rev: $old_rev,
      new_rev: $new_rev,
      total_commits_scanned: ($total_commits | tonumber),
      relevant_changes: $matches,
      packages_file: $packages_file
    }'
else
  echo ""
  echo "=== nixpkgs Changelog (filtered by config) ==="
  echo "Revisions: ${OLD_REV:0:8}...${NEW_REV:0:8}"
  echo "Total commits scanned: $COMMIT_COUNT"
  echo "Relevant changes: $MATCH_COUNT"
  echo ""

  if [[ "$MATCH_COUNT" -gt 0 ]]; then
    echo "=== Changes affecting your packages ==="
    jq -r '.[] | select(.package != "BREAKING") | "  [\(.package)] \(.message)"' "$MATCHES_FILE"
    echo ""

    BREAKING_COUNT=$(jq '[.[] | select(.package == "BREAKING")] | length' "$MATCHES_FILE")
    if [[ "$BREAKING_COUNT" -gt 0 ]]; then
      echo "=== Potential breaking changes ==="
      jq -r '.[] | select(.package == "BREAKING") | "  \(.message)"' "$MATCHES_FILE"
      echo ""
    fi

    echo "=== PR Details ==="
    jq -r '.[] | select(.pr_number != null) | "PR #\(.pr_number): \(.message)\n  \(.pr_body // "No description")\n"' "$MATCHES_FILE" | head -50
  else
    echo "No changes found affecting packages in your config."
  fi

  echo ""
  echo "Full results: $MATCHES_FILE"
  echo "Package list: $PACKAGES_FILE"
fi
