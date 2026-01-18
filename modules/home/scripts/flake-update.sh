# Main flake update orchestrator
# Usage: flake-update [--dry-run] [--no-fetch] [flake-path]
#
# Options:
#   --dry-run   Don't actually run nix flake update, just analyze current lock
#   --no-fetch  Skip fetching commits from GitHub/GitLab (faster, less detail)
#
# Output:
#   - Backs up old flake.lock to /tmp/flake-update/old-flake.lock
#   - Generates changelog to /tmp/flake-update/changelog.json
#   - Prints summary to stdout

source "$SCRIPTS_LIB/flake-update-lib.sh"

# Parse arguments
DRY_RUN=false
NO_FETCH=false
FLAKE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-fetch)
      NO_FETCH=true
      shift
      ;;
    -h|--help)
      echo "Usage: flake-update [--dry-run] [--no-fetch] [flake-path]"
      echo ""
      echo "Options:"
      echo "  --dry-run   Don't run nix flake update, analyze current lock vs git HEAD~1"
      echo "  --no-fetch  Skip fetching commits from GitHub/GitLab"
      echo ""
      echo "Output files written to: $FLAKE_UPDATE_DIR/"
      exit 0
      ;;
    *)
      FLAKE_PATH="$1"
      shift
      ;;
  esac
done

# Default to current directory
if [[ -z "$FLAKE_PATH" ]]; then
  FLAKE_PATH="."
fi

# Resolve to absolute path
FLAKE_PATH=$(cd "$FLAKE_PATH" && pwd)

# Check for flake.nix
if [[ ! -f "$FLAKE_PATH/flake.nix" ]]; then
  log_error "No flake.nix found in $FLAKE_PATH"
  exit 1
fi

# Check for flake.lock
if [[ ! -f "$FLAKE_PATH/flake.lock" ]]; then
  log_error "No flake.lock found in $FLAKE_PATH"
  exit 1
fi

# Setup output directory
ensure_output_dir

log_info "Flake update for: $FLAKE_PATH"

# Backup current lock file
OLD_LOCK="$FLAKE_UPDATE_DIR/old-flake.lock"
cp "$FLAKE_PATH/flake.lock" "$OLD_LOCK"
log_info "Backed up current flake.lock to $OLD_LOCK"

if $DRY_RUN; then
  log_info "Dry run mode - not running nix flake update"

  # In dry run, try to get old lock from git if available
  if git -C "$FLAKE_PATH" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$FLAKE_PATH" show HEAD~1:flake.lock >"$OLD_LOCK" 2>/dev/null; then
      log_info "Using flake.lock from previous git commit for comparison"
    else
      log_warn "Could not get previous flake.lock from git, comparing against self"
    fi
  fi
else
  # Run nix flake update
  log_info "Running nix flake update..."
  if ! nix flake update --flake "$FLAKE_PATH" 2>&1; then
    log_error "nix flake update failed"
    exit 1
  fi
  log_info "Flake update completed"
fi

NEW_LOCK="$FLAKE_PATH/flake.lock"
CHANGELOG="$FLAKE_UPDATE_DIR/changelog.json"

if $NO_FETCH; then
  log_info "Skipping commit fetch (--no-fetch)"

  # Generate minimal changelog without fetching commits
  # Just show what changed
  jq -n \
    --arg timestamp "$(date -Iseconds)" \
    --arg note "Commit details not fetched (--no-fetch mode)" \
    --argjson old "$(cat "$OLD_LOCK")" \
    --argjson new "$(cat "$NEW_LOCK")" \
    '{
      timestamp: $timestamp,
      note: $note,
      updated: [],
      added: [],
      removed: []
    }' > "$CHANGELOG"
else
  # Generate full changelog with commit details
  log_info "Fetching changelog details..."
  flake-changelog "$OLD_LOCK" "$NEW_LOCK" > "$CHANGELOG"
fi

log_info "Changelog written to: $CHANGELOG"

# Print summary
echo ""
echo "=== Flake Update Summary ==="
echo ""

# Count updates
UPDATED_COUNT=$(jq '.updated | length' "$CHANGELOG")
ADDED_COUNT=$(jq '.added | length' "$CHANGELOG")
REMOVED_COUNT=$(jq '.removed | length' "$CHANGELOG")

echo "Updated: $UPDATED_COUNT inputs"
echo "Added: $ADDED_COUNT inputs"
echo "Removed: $REMOVED_COUNT inputs"
echo ""

if [[ "$UPDATED_COUNT" -gt 0 ]]; then
  echo "Updated inputs:"
  jq -r '.updated[] | "  - \(.name): \(.old_rev[:8])...\(.new_rev[:8]) (\(.total_commits // 0) commits)"' "$CHANGELOG"
  echo ""
fi

if [[ "$ADDED_COUNT" -gt 0 ]]; then
  echo "Added inputs:"
  jq -r '.added[] | "  + \(.name)"' "$CHANGELOG"
  echo ""
fi

if [[ "$REMOVED_COUNT" -gt 0 ]]; then
  echo "Removed inputs:"
  jq -r '.removed[] | "  - \(.name)"' "$CHANGELOG"
  echo ""
fi

# Check for potential breaking changes
BREAKING_KEYWORDS="breaking|deprecat|remov|migrat|renam|BREAKING"
BREAKING_COMMITS=$(jq -r ".updated[].commits[]?.message // empty" "$CHANGELOG" | grep -iE "$BREAKING_KEYWORDS" || true)

if [[ -n "$BREAKING_COMMITS" ]]; then
  echo "=== Potential Breaking Changes ==="
  echo "$BREAKING_COMMITS" | head -20
  echo ""
fi

echo "Full changelog: $CHANGELOG"
echo ""

# Check if nixpkgs was updated and run specialized analysis
NIXPKGS_OLD_REV=$(jq -r '.nodes.nixpkgs_3.locked.rev // .nodes.nixpkgs_2.locked.rev // .nodes.nixpkgs.locked.rev // empty' "$OLD_LOCK" 2>/dev/null)
NIXPKGS_NEW_REV=$(jq -r '.nodes.nixpkgs_3.locked.rev // .nodes.nixpkgs_2.locked.rev // .nodes.nixpkgs.locked.rev // empty' "$NEW_LOCK" 2>/dev/null)

if [[ -n "$NIXPKGS_OLD_REV" && -n "$NIXPKGS_NEW_REV" && "$NIXPKGS_OLD_REV" != "$NIXPKGS_NEW_REV" ]]; then
  if ! $NO_FETCH; then
    log_info "nixpkgs was updated, running specialized analysis..."
    if nixpkgs-changelog "$NIXPKGS_OLD_REV" "$NIXPKGS_NEW_REV" --json > "$FLAKE_UPDATE_DIR/nixpkgs-changelog.json" 2>/dev/null; then
      NIXPKGS_MATCHES=$(jq '.relevant_changes | length' "$FLAKE_UPDATE_DIR/nixpkgs-changelog.json")
      echo ""
      echo "=== nixpkgs Changes (filtered by your config) ==="
      echo "Found $NIXPKGS_MATCHES changes affecting your packages"
      if [[ "$NIXPKGS_MATCHES" -gt 0 ]]; then
        jq -r '.relevant_changes[] | "  [\(.package)] \(.message)"' "$FLAKE_UPDATE_DIR/nixpkgs-changelog.json"
      fi
      echo ""
      echo "Full nixpkgs analysis: $FLAKE_UPDATE_DIR/nixpkgs-changelog.json"
    fi
  fi
fi

# Output paths for Claude to use
echo ""
echo "=== Output Files ==="
echo "Old lock: $OLD_LOCK"
echo "New lock: $NEW_LOCK"
echo "Changelog: $CHANGELOG"
if [[ -f "$FLAKE_UPDATE_DIR/nixpkgs-changelog.json" ]]; then
  echo "nixpkgs analysis: $FLAKE_UPDATE_DIR/nixpkgs-changelog.json"
fi
