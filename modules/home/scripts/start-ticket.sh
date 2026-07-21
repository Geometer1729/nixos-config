#!/usr/bin/env bash

# Keybind: pick a Linear issue and repo with rofi, then open a ghostty window
# attached to a tmux session in the issue's worktree with opencode planning.

trap 'notify-send -u critical start-ticket "failed: $BASH_COMMAND"' ERR

work=$HOME/Code/work

cleanup_merged_worktrees() {
  local candidate branch state common_dir

  for candidate in "$work/grim-wts"/*; do
    [[ -d $candidate && $candidate != "$worktree" ]] || continue
    branch=$(git -C "$candidate" symbolic-ref --quiet --short HEAD 2>/dev/null) || continue
    state=$(cd "$candidate" && gh pr view "$branch" --json state --jq .state 2>/dev/null) || continue
    [[ $state == MERGED ]] || continue
    common_dir=$(git -C "$candidate" rev-parse --path-format=absolute --git-common-dir) || continue

    if git --git-dir="$common_dir" worktree remove "$candidate"; then
      notify-send start-ticket "Removed merged worktree ${candidate##*/}"
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
IFS=$'\t' read -r identifier title _ branch <<<"$choice"

repo=$(find "$work" -mindepth 1 -maxdepth 1 -type d ! -name grim-wts -printf '%f\n' |
  sort | rofi -dmenu -i -no-custom -p 'Repository') || exit 0
repo=$work/$repo

session=${identifier,,}
worktree=$work/grim-wts/$session

if [[ ! -d $worktree ]]; then
  git -C "$repo" fetch --quiet origin
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$repo" worktree add "$worktree" "$branch"
  elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git -C "$repo" worktree add --track -b "$branch" "$worktree" "origin/$branch"
  else
    git -C "$repo" worktree add --no-track -b "$branch" "$worktree" origin/HEAD
  fi
  if [[ -f $repo/.env ]]; then
    cp "$repo/.env" "$worktree/.env"
  fi
fi

if [[ -f $worktree/.envrc ]]; then
  direnv allow "$worktree"
fi

if [[ -f $worktree/apps/panharmonicon/.envrc ]]; then
  direnv allow "$worktree/apps/panharmonicon"
fi

if ! tmux has-session -t "=$session" 2>/dev/null; then
  prompt="Start by reading Linear issue $identifier ($title) and its comments with 'linearis issues read $identifier --with-comments'. Read its relations with 'linearis issues relations list $identifier'. Determine where implementation currently stands; it is usually brand new, but check for existing commits, whether the branch is pushed, any associated PR, and its review and check status. Inspect the repository for the relevant implementation context, then propose the appropriate next steps. Ask questions where requirements are unclear. Stay in plan mode and do not edit files yet."
  tmux new-session -d -s "$session" -c "$worktree"
  tmux split-window -h -t "$session:0.0" -c "$worktree" \
    "exec opencode --agent plan --prompt $(printf %q "$prompt")"
  tmux select-layout -t "$session:0" even-horizontal
fi

(trap - ERR; cleanup_merged_worktrees) >/dev/null 2>&1 &
exec ghostty --title="$session" -e tmux attach-session -t "$session"
