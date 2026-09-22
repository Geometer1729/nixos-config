# Fetch changelog between two flake.lock versions
# Usage: flake-changelog <old-flake.lock> <new-flake.lock>
# Output: JSON changelog to stdout

source "$SCRIPTS_LIB/flake-update-lib.sh"

# Maximum commits to fetch per input (to avoid rate limits and huge outputs)
MAX_COMMITS=50

# Fetch commits from GitHub between two revisions
# Args: $1 - owner/repo, $2 - old rev, $3 - new rev
fetch_github_commits() {
  local repo="$1"
  local old_rev="$2"
  local new_rev="$3"

  # Use gh api with error handling for rate limits
  local response
  if ! response=$(gh api "repos/$repo/compare/${old_rev}...${new_rev}" \
    --jq "{
      commits: [.commits[:$MAX_COMMITS][] | {
        sha: .sha,
        message: (.commit.message | split(\"\n\")[0]),
        author: .commit.author.name,
        date: .commit.author.date
      }],
      total_commits: .total_commits,
      truncated: (.total_commits > $MAX_COMMITS)
    }" 2>&1); then
    # Check for rate limiting
    if echo "$response" | grep -q "rate limit"; then
      log_warn "GitHub rate limit hit for $repo"
      echo '{"commits":[],"error":"rate_limited"}'
    else
      log_warn "Failed to fetch commits for $repo: $response"
      echo '{"commits":[],"error":"fetch_failed"}'
    fi
    return
  fi

  echo "$response"
}

# Fetch releases from GitHub between two dates
# Args: $1 - owner/repo, $2 - old timestamp, $3 - new timestamp
fetch_github_releases() {
  local repo="$1"
  local old_ts="$2"
  local new_ts="$3"

  # Convert timestamps to ISO format
  local old_date new_date
  old_date=$(date -d "@$old_ts" -Iseconds 2>/dev/null || echo "")
  new_date=$(date -d "@$new_ts" -Iseconds 2>/dev/null || echo "")

  if [[ -z "$old_date" || -z "$new_date" ]]; then
    echo '[]'
    return
  fi

  # Fetch releases and filter by date
  # --paginate returns one JSON array per page, so merge them with jq -s 'add // []'
  gh api "repos/$repo/releases" --paginate --jq "[.[] | select(.published_at > \"$old_date\" and .published_at <= \"$new_date\") | {
    tag: .tag_name,
    name: .name,
    url: .html_url,
    published: .published_at,
    prerelease: .prerelease
  }]" 2>/dev/null | jq -s 'add // []' || echo '[]'
}

# Fetch commits from GitLab between two revisions
# Args: $1 - project path (owner/repo), $2 - old rev, $3 - new rev
fetch_gitlab_commits() {
  local project="$1"
  local old_rev="$2"
  local new_rev="$3"

  # URL-encode the project path
  local encoded_project
  encoded_project=$(urlencode "$project")

  # GitLab compare API
  local response
  if ! response=$(curl -sf "https://gitlab.com/api/v4/projects/$encoded_project/repository/compare?from=$old_rev&to=$new_rev" 2>&1); then
    log_warn "Failed to fetch GitLab commits for $project"
    echo '{"commits":[],"error":"fetch_failed"}'
    return
  fi

  # Transform to our format
  echo "$response" | jq "{
    commits: [.commits[:$MAX_COMMITS][] | {
      sha: .id,
      message: (.title // .message | split(\"\n\")[0]),
      author: .author_name,
      date: .authored_date
    }],
    total_commits: (.commits | length),
    truncated: ((.commits | length) > $MAX_COMMITS)
  }" 2>/dev/null || echo '{"commits":[],"error":"parse_failed"}'
}

# Special handling for nixpkgs - don't fetch all commits
# Instead, just note the update and suggest using nvd
handle_nixpkgs() {
  local old_rev="$1"
  local new_rev="$2"

  echo '{
    "note": "nixpkgs has thousands of commits per update. Use nvd diff to see package changes.",
    "suggestion": "Run: nvd diff /run/current-system result",
    "commits": [],
    "truncated": true
  }'
}

# Process a single input and generate changelog entry
# Args: $1 - input name, $2 - old locked JSON, $3 - new locked JSON
process_input() {
  local name="$1"
  local old_locked="$2"
  local new_locked="$3"

  local source_type
  source_type=$(get_source_type "$new_locked")

  local old_rev new_rev
  old_rev=$(get_rev "$old_locked")
  new_rev=$(get_rev "$new_locked")

  local old_ts new_ts
  old_ts=$(get_last_modified "$old_locked")
  new_ts=$(get_last_modified "$new_locked")

  local repo="" commits_data releases_data

  case "$source_type" in
    github)
      repo=$(get_github_repo "$new_locked")

      # Special handling for nixpkgs
      if [[ "$repo" == "NixOS/nixpkgs" ]]; then
        commits_data=$(handle_nixpkgs "$old_rev" "$new_rev")
        releases_data='[]'
      else
        commits_data=$(fetch_github_commits "$repo" "$old_rev" "$new_rev")
        releases_data=$(fetch_github_releases "$repo" "$old_ts" "$new_ts")
      fi
      ;;
    gitlab)
      repo=$(get_gitlab_repo "$new_locked")
      commits_data=$(fetch_gitlab_commits "$repo" "$old_rev" "$new_rev")
      releases_data='[]'  # GitLab releases API is different, skip for now
      ;;
    *)
      log_warn "Unknown source type '$source_type' for $name"
      commits_data='{"commits":[]}'
      releases_data='[]'
      ;;
  esac

  # Build the changelog entry
  jq -n \
    --arg name "$name" \
    --arg repo "$repo" \
    --arg source_type "$source_type" \
    --arg old_rev "$old_rev" \
    --arg new_rev "$new_rev" \
    --arg old_ts "$old_ts" \
    --arg new_ts "$new_ts" \
    --argjson commits "$commits_data" \
    --argjson releases "$releases_data" \
    '{
      name: $name,
      source_type: $source_type,
      repo: $repo,
      old_rev: $old_rev,
      new_rev: $new_rev,
      old_timestamp: ($old_ts | tonumber? // null),
      new_timestamp: ($new_ts | tonumber? // null),
      commits: $commits.commits,
      total_commits: ($commits.total_commits // ($commits.commits | length)),
      truncated: ($commits.truncated // false),
      note: ($commits.note // null),
      suggestion: ($commits.suggestion // null),
      releases: $releases,
      error: ($commits.error // null)
    }'
}

# Main function
main() {
  local old_lock="$1"
  local new_lock="$2"

  if [[ -z "$old_lock" || -z "$new_lock" ]]; then
    echo "Usage: flake-changelog <old-flake.lock> <new-flake.lock>" >&2
    exit 1
  fi

  if [[ ! -f "$old_lock" ]]; then
    log_error "Old lock file not found: $old_lock"
    exit 1
  fi

  if [[ ! -f "$new_lock" ]]; then
    log_error "New lock file not found: $new_lock"
    exit 1
  fi

  local timestamp
  timestamp=$(date -Iseconds)

  # Get inputs from both locks
  local old_inputs new_inputs
  old_inputs=$(get_direct_inputs "$old_lock")
  new_inputs=$(get_direct_inputs "$new_lock")

  # Find updated, added, and removed inputs
  local updated=()
  local added=()
  local removed=()

  # Check for updated and removed inputs
  for input in $old_inputs; do
    if echo "$new_inputs" | grep -qx "$input"; then
      # Input exists in both - check if updated
      local old_locked new_locked
      old_locked=$(get_input_info "$old_lock" "$input")
      new_locked=$(get_input_info "$new_lock" "$input")

      local old_rev new_rev
      old_rev=$(get_rev "$old_locked")
      new_rev=$(get_rev "$new_locked")

      if revs_differ "$old_rev" "$new_rev"; then
        updated+=("$input")
      fi
    else
      removed+=("$input")
    fi
  done

  # Check for added inputs
  for input in $new_inputs; do
    if ! echo "$old_inputs" | grep -qx "$input"; then
      added+=("$input")
    fi
  done

  # Process updated inputs and collect changelog entries
  local updated_entries=()
  for input in "${updated[@]}"; do
    log_info "Processing $input..."
    local old_locked new_locked
    old_locked=$(get_input_info "$old_lock" "$input")
    new_locked=$(get_input_info "$new_lock" "$input")

    local entry
    entry=$(process_input "$input" "$old_locked" "$new_locked")
    updated_entries+=("$entry")
  done

  # Process added inputs (no old info)
  local added_entries=()
  for input in "${added[@]}"; do
    local new_locked
    new_locked=$(get_input_info "$new_lock" "$input")

    added_entries+=("$(jq -n \
      --arg name "$input" \
      --arg repo "$(get_github_repo "$new_locked")$(get_gitlab_repo "$new_locked")" \
      --arg rev "$(get_rev "$new_locked")" \
      '{name: $name, repo: $repo, rev: $rev}')")
  done

  # Process removed inputs
  local removed_entries=()
  for input in "${removed[@]}"; do
    removed_entries+=("$(jq -n --arg name "$input" '{name: $name}')")
  done

  # Build final JSON output
  local updated_json added_json removed_json

  if [[ ${#updated_entries[@]} -eq 0 ]]; then
    updated_json='[]'
  else
    updated_json=$(printf '%s\n' "${updated_entries[@]}" | jq -s '.')
  fi

  if [[ ${#added_entries[@]} -eq 0 ]]; then
    added_json='[]'
  else
    added_json=$(printf '%s\n' "${added_entries[@]}" | jq -s '.')
  fi

  if [[ ${#removed_entries[@]} -eq 0 ]]; then
    removed_json='[]'
  else
    removed_json=$(printf '%s\n' "${removed_entries[@]}" | jq -s '.')
  fi

  jq -n \
    --arg timestamp "$timestamp" \
    --argjson updated "$updated_json" \
    --argjson added "$added_json" \
    --argjson removed "$removed_json" \
    '{
      timestamp: $timestamp,
      updated: $updated,
      added: $added,
      removed: $removed
    }'
}

main "$@"
