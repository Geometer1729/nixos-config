#!/usr/bin/env bash

# Keybind: pick a Linear issue and repo with rofi, then open a ghostty window
# attached to a tmux session in the issue's worktree with opencode planning.

trap 'notify-send -u critical start-ticket "failed: $BASH_COMMAND"' ERR

work=$HOME/Code/work

# Removes worktrees whose PR was merged or closed 12h ago, and worktrees idle
# for 48h with every commit pushed. Without --force, git still refuses any
# worktree with uncommitted or untracked files. Whatever is left after a week
# idle gets a notification whose click opens a review in OpenCode.
cleanup_finished_worktrees() {
  local candidate branch state closed_at closed_epoch last_active unpushed reason common_dir
  local now
  now=$(date +%s)

  for candidate in "$work/wts"/*; do
    [[ -d $candidate && $candidate != "$worktree" ]] || continue
    # The HEAD reflog is per worktree and moves on every commit, checkout and reset.
    last_active=$(stat -c %Y "$(git -C "$candidate" rev-parse --path-format=absolute --git-path logs/HEAD)") ||
      last_active=$now
    reason=

    if branch=$(git -C "$candidate" symbolic-ref --quiet --short HEAD 2>/dev/null) &&
      IFS=$'\t' read -r state closed_at < <(
        cd "$candidate" && gh pr view "$branch" --json state,closedAt \
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
IFS=$'\t' read -r identifier title _state branch <<<"$choice"

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
  # Ignored .env files, at the root or in packages, don't come with a worktree.
  # --directory lists ignored directories like node_modules without descending.
  (
    cd "$repo" || exit
    git ls-files -z --others --ignored --exclude-standard --directory |
      while IFS= read -r -d '' path; do
        case $path in
        .env | */.env) cp --parents "$path" "$worktree" ;;
        esac
      done
  )
fi

if [[ -f $worktree/.envrc ]]; then
  direnv allow "$worktree"
fi

if [[ -f $worktree/apps/panharmonicon/.envrc ]]; then
  direnv allow "$worktree/apps/panharmonicon"
fi

if [[ ${_state,,} != "in progress" ]]; then
  linearis issues update "$identifier" --status "In Progress" >/dev/null
fi

if ! tmux has-session -t "=$session" 2>/dev/null; then
  tmux new-session -d -s "$session" -c "$worktree"
fi

if ! tmux list-panes -t "=$session" -F '#{pane_dead}:#{pane_current_command}' |
  grep -Eq '^0:opencode2?$'; then
  # An explicit title stops the title agent from naming every session after the
  # /start-ticket template ("BRD-?? implementation status").
  body=$(jq -nc --arg title "$identifier: $title" --arg directory "$worktree" \
    '{title: $title, location: {directory: $directory}}')
  opencode_session=$(opencode api post /api/session --data "$body" | jq -er '.data.id')
  # Not `opencode --prompt`: the TUI saves that prompt as the home draft and
  # resubmits it in every new tab.
  body=$(jq -nc --arg text "$identifier" '{name: "start-ticket", text: $text}')
  opencode api post "/api/session/$opencode_session/command" --data "$body" >/dev/null
  tmux split-window -h -t "$session:0.0" -c "$worktree" \
    "exec opencode --session $opencode_session"
  tmux select-layout -t "$session:0" even-horizontal
fi

(trap - ERR; cleanup_finished_worktrees) >/dev/null 2>&1 &
exec ghostty -e tmux attach-session -t "$session"
