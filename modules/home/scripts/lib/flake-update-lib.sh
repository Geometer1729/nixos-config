#!/usr/bin/env bash
# Shared functions for flake update scripts

# Output directory for update artifacts
FLAKE_UPDATE_DIR="/tmp/flake-update"

# Ensure output directory exists
ensure_output_dir() {
  mkdir -p "$FLAKE_UPDATE_DIR"
}

# Get list of direct (root-level) inputs from flake.lock
# Args: $1 - path to flake.lock
get_direct_inputs() {
  local lock_file="$1"
  jq -r '.nodes.root.inputs | keys[]' "$lock_file" 2>/dev/null
}

# Get locked info for a specific input
# Args: $1 - path to flake.lock, $2 - input name
# Returns JSON object with type, owner, repo, rev, lastModified
get_input_info() {
  local lock_file="$1"
  local input_name="$2"

  # Handle follows - resolve to actual node
  local node_name
  node_name=$(jq -r ".nodes.root.inputs[\"$input_name\"]" "$lock_file" 2>/dev/null)

  # If it's an array (follows), get the first element
  if [[ "$node_name" == "["* ]]; then
    node_name=$(jq -r ".nodes.root.inputs[\"$input_name\"][0]" "$lock_file" 2>/dev/null)
  fi

  jq -c ".nodes[\"$node_name\"].locked // empty" "$lock_file" 2>/dev/null
}

# Extract GitHub owner/repo from locked info
# Args: $1 - locked info JSON
get_github_repo() {
  local locked="$1"
  local owner repo
  owner=$(echo "$locked" | jq -r '.owner // empty')
  repo=$(echo "$locked" | jq -r '.repo // empty')

  if [[ -n "$owner" && -n "$repo" ]]; then
    echo "$owner/$repo"
  fi
}

# Extract GitLab project path from locked info
# Args: $1 - locked info JSON
get_gitlab_repo() {
  local locked="$1"
  local owner repo
  owner=$(echo "$locked" | jq -r '.owner // empty')
  repo=$(echo "$locked" | jq -r '.repo // empty')

  if [[ -n "$owner" && -n "$repo" ]]; then
    echo "$owner/$repo"
  fi
}

# Get the type of source (github, gitlab, sourcehut, etc.)
# Args: $1 - locked info JSON
get_source_type() {
  local locked="$1"
  echo "$locked" | jq -r '.type // "unknown"'
}

# Format Unix timestamp to human-readable date
# Args: $1 - Unix timestamp
format_timestamp() {
  local ts="$1"
  if [[ -n "$ts" && "$ts" != "null" ]]; then
    date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# Get revision from locked info
# Args: $1 - locked info JSON
get_rev() {
  local locked="$1"
  echo "$locked" | jq -r '.rev // empty'
}

# Get lastModified from locked info
# Args: $1 - locked info JSON
get_last_modified() {
  local locked="$1"
  echo "$locked" | jq -r '.lastModified // empty'
}

# Check if two revisions are different
# Args: $1 - old rev, $2 - new rev
revs_differ() {
  local old_rev="$1"
  local new_rev="$2"
  [[ "$old_rev" != "$new_rev" ]]
}

# URL-encode a string (for GitLab API)
# Args: $1 - string to encode
urlencode() {
  local string="$1"
  python3 -c "import urllib.parse; print(urllib.parse.quote('$string', safe=''))"
}

# Log message with timestamp (to stderr so it doesn't corrupt JSON output)
log_info() {
  echo "[$(date '+%H:%M:%S')] $*" >&2
}

log_error() {
  echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2
}

log_warn() {
  echo "[$(date '+%H:%M:%S')] WARN: $*" >&2
}
