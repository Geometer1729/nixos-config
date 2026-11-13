#!/usr/bin/env bash

# Mako click action: hand a stale worktree from start-ticket's cleanup to an
# OpenCode session that reviews whether it can be pruned.
fail() {
  notify-send -u critical "Review worktree" "$*"
  echo "$*" >&2
  exit 1
}

id=${1:?usage: review-worktree <mako notification id>}

# The body holds the worktree's path; expired notifications are only in history.
worktree=$(jq -sr --argjson id "$id" 'add | map(select(.id == $id))[0].body // empty' \
  <(makoctl list -j) <(makoctl history -j)) ||
  fail "Could not read notification $id."
# A custom click action replaces mako's default dismissal.
makoctl dismiss -n "$id" || true

[[ -d $worktree ]] || fail "Worktree ${worktree:-of notification $id} no longer exists."
common_dir=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir) ||
  fail "$worktree is not a git worktree."

# Run from the main checkout so pruning does not delete the session's directory.
body=$(jq -nc --arg title "Review worktree ${worktree##*/} for pruning" --arg directory "${common_dir%/.git}" \
  '{title: $title, location: {directory: $directory}}')
session=$(opencode api post /api/session --data "$body" | jq -er '.data.id') ||
  fail "Could not create the OpenCode session."

text="Review whether the worktree $worktree can be pruned. Nothing has been committed or checked out in it for over a week, and start-ticket's cleanup kept it.
Report what removing it would lose: uncommitted and untracked files, commits on no remote (a detached HEAD's commits would be orphaned), its branch's PR state, and whether its work reached the default branch another way. Recommend prune or keep.
Change nothing until I approve. Then save what is worth keeping, such as a branch for detached commits or copies of loose files, and run \`git worktree remove\`."
body=$(jq -nc --arg text "$text" '{text: $text}')
opencode api post "/api/session/$session/prompt" --data "$body" >/dev/null ||
  fail "Session $session was created, but its prompt could not be sent."
