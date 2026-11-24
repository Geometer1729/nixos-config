#!/usr/bin/env bash

# Keybind: pick a Linear issue and repo with rofi, then open the issue's
# session through opencode-start, which owns the worktree and the window.

trap 'notify-send -u critical start-ticket "failed: $BASH_COMMAND"' ERR

work=$HOME/Code/work

# Removes worktrees whose PR was merged or closed 12h ago, and worktrees idle
# for 48h with every commit pushed. Without --force, git still refuses any
# worktree with uncommitted or untracked files. Whatever is left after a week
# idle gets a notification whose click opens a review in OpenCode.
cleanup_finished_worktrees() {
  local candidate candidate_branch state closed_at closed_epoch last_active unpushed reason common_dir
  local now
  now=$(date +%s)

  for candidate in "$work/wts"/*; do
    [[ -d $candidate ]] || continue
    # The worktree being opened may not exist yet, so skip it by branch.
    [[ $(git -C "$candidate" symbolic-ref --quiet --short HEAD 2>/dev/null) != "$branch" ]] || continue
    # The HEAD reflog is per worktree and moves on every commit, checkout and reset.
    last_active=$(stat -c %Y "$(git -C "$candidate" rev-parse --path-format=absolute --git-path logs/HEAD)") ||
      last_active=$now
    reason=

    if candidate_branch=$(git -C "$candidate" symbolic-ref --quiet --short HEAD 2>/dev/null) &&
      IFS=$'\t' read -r state closed_at < <(
        cd "$candidate" && gh pr view "$candidate_branch" --json state,closedAt \
          --jq '[.state, .closedAt] | @tsv' 2>/dev/null
      ) &&
      [[ $state == MERGED || $state == CLOSED ]] &&
      closed_epoch=$(date --date="$closed_at" +%s) &&
      (( closed_epoch <= now - 12 * 60 * 60 )); then
      reason=${state,,}
    elif (( last_active <= now - 48 * 60 * 60 )) &&
      unpushed=$(git -C "$candidate" rev-list HEAD --not --remotes) &&
      [[ -z $unpushed ]]; then
      reason=idle
    fi

    if [[ -n $reason ]] &&
      common_dir=$(git -C "$candidate" rev-parse --path-format=absolute --git-common-dir) &&
      git --git-dir="$common_dir" worktree remove "$candidate"; then
      notify-send start-ticket "Removed $reason worktree ${candidate##*/}"
    elif (( last_active <= now - 7 * 24 * 60 * 60 )); then
      # review-worktree reads the path back from the body.
      notify-send --app-name=stale-worktree \
        "Consider pruning ${candidate##*/}" "$candidate"
    fi
  done
}

issues=$(
  linearis issues list --assignee brian@geosurge.ai | jq -r '
    .nodes[]
    | select(.state.name | ascii_downcase
        | IN("done", "completed", "canceled", "cancelled", "duplicate", "closed")
        | not)
    | [.identifier, .title, .state.name, .branchName] | @tsv'
)
choice=$(rofi -dmenu -i -no-custom -p 'Linear issue' \
  -display-columns 1,2,3 -display-column-separator $'\t' <<<"$issues") || exit 0
IFS=$'\t' read -r identifier _title _state branch <<<"$choice"

repo=$(find "$work" -mindepth 1 -maxdepth 1 -type d ! -name wts -printf '%f\n' |
  sort | rofi -dmenu -i -no-custom -p 'Repository') || exit 0
repo=$work/$repo

(trap - ERR; cleanup_finished_worktrees) >/dev/null 2>&1 &
opencode-start --linear "$identifier" --repo "$repo" >/dev/null
