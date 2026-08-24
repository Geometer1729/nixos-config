#!/usr/bin/env bash

# Keybind: pick a Linear issue and repo with rofi, then open a ghostty window
# attached to a tmux session in the issue's worktree with opencode planning.

trap 'notify-send -u critical start-ticket "failed: $BASH_COMMAND"' ERR

work=$HOME/Code/work

cleanup_merged_worktrees() {
  local candidate branch state merged_at merged_epoch common_dir
  local cutoff=$(( $(date +%s) - 48 * 60 * 60 ))

  for candidate in "$work/wts"/*; do
    [[ -d $candidate && $candidate != "$worktree" ]] || continue
    branch=$(git -C "$candidate" symbolic-ref --quiet --short HEAD 2>/dev/null) || continue
    IFS=$'\t' read -r state merged_at < <(
      cd "$candidate" && gh pr view "$branch" --json state,mergedAt \
        --jq '[.state, .mergedAt] | @tsv' 2>/dev/null
    ) || continue
    [[ $state == MERGED && -n $merged_at ]] || continue
    merged_epoch=$(date --date="$merged_at" +%s) || continue
    (( merged_epoch <= cutoff )) || continue
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
IFS=$'\t' read -r identifier _title _state branch <<<"$choice"

repo=$(find "$work" -mindepth 1 -maxdepth 1 -type d ! -name wts -printf '%f\n' |
  sort | rofi -dmenu -i -no-custom -p 'Repository') || exit 0
repo=$work/$repo

worktree=
while IFS= read -r line; do
  case $line in
  worktree\ *) current_worktree=${line#worktree } ;;
  branch\ refs/heads/"$branch") worktree=$current_worktree; break ;;
  esac
done < <(git -C "$repo" worktree list --porcelain)

if [[ -z $worktree ]]; then
  worktree_name=${branch:0:30}
  worktree=$work/wts/${worktree_name//\//-}

  if [[ -d $worktree ]]; then
    repo_common_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
    worktree_common_dir=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir)
    if [[ $repo_common_dir != "$worktree_common_dir" ]]; then
      worktree=$worktree-${repo##*/}
    fi
  fi
fi
session=${worktree##*/}

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
  tmux new-session -d -s "$session" -c "$worktree"
fi

if ! tmux list-panes -t "=$session" -F '#{pane_dead}:#{pane_current_command}' |
  grep -Eq '^0:opencode2?$'; then
  prompt="/start-ticket $identifier"
  tmux split-window -h -t "$session:0.0" -c "$worktree" \
    "exec opencode --prompt $(printf %q "$prompt")"
  tmux select-layout -t "$session:0" even-horizontal
fi

(trap - ERR; cleanup_merged_worktrees) >/dev/null 2>&1 &
exec ghostty --title="$session" -e tmux attach-session -t "$session"
