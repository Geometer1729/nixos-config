#!/usr/bin/env bash

# Start work on a Linear issue in an isolated worktree and tmux session.

usage() {
  cat <<'EOF'
Usage: start-ticket [--desktop] [--repo PATH] [--worktree-root PATH] [ISSUE]

Without ISSUE, choose an open Linear issue with rofi. Without --repo, choose a
source repository from ~/Code/work with rofi. Worktrees default to the sibling
grim-wts/<issue-id> directory.

Environment:
  START_TICKET_ASSIGNEE       Linear assignee (default: brian@geosurge.ai).
  START_TICKET_BASE_REF       Ref for a new branch (default: origin/HEAD).
  START_TICKET_REPO_ROOT      Directory containing source repositories.
  START_TICKET_WORKTREE_ROOT  Override the default worktree directory.
EOF
}

die() {
  local message=$*

  printf 'start-ticket: %s\n' "$message" >&2
  if [[ ${desktop:-false} == true ]] && command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency=critical "start-ticket" "$message"
  fi
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

select_issue() {
  local assignee issues selection

  assignee="${START_TICKET_ASSIGNEE:-brian@geosurge.ai}"
  issues=$(linearis issues list --assignee "$assignee" --limit 50) ||
    die "failed to list Linear issues assigned to $assignee"
  selection=$(
    jq -r '
      def is_terminal:
        (.state.name | ascii_downcase) as $state
        | ["done", "completed", "canceled", "cancelled", "duplicate", "closed"]
        | index($state) != null;

      .nodes
      | map(select(is_terminal | not))
      | sort_by(
          if .priority == 0 then 5 else .priority end,
          .identifier
        )
      | .[]
      | [
          .identifier,
          .title,
          .state.name,
          (.assignee.name // "Unassigned")
        ]
      | @tsv
    ' <<<"$issues" |
      rofi -dmenu -i -no-custom -sync \
        -display-columns 1,2,3,4 \
        -display-column-separator $'\t' \
        -p 'Linear issue'
  ) || exit 0

  printf '%s\n' "${selection%%$'\t'*}"
}

select_repo() {
  local candidate repo_parent selection
  local -a repos=()

  repo_parent=${START_TICKET_REPO_ROOT:-"$HOME/Code/work"}
  [[ -d "$repo_parent" ]] || die "repository directory does not exist: $repo_parent"

  for candidate in "$repo_parent"/*; do
    [[ -d "$candidate/.git" ]] || continue
    repos+=("$(basename "$candidate")"$'\t'"$candidate")
  done
  ((${#repos[@]} > 0)) || die "no Git repositories found in $repo_parent"

  selection=$(
    printf '%s\n' "${repos[@]}" |
      sort |
      rofi -dmenu -i -no-custom -sync \
        -display-columns 1 \
        -display-column-separator $'\t' \
        -p 'Source repository'
  ) || exit 0

  printf '%s\n' "${selection#*$'\t'}"
}

find_branch_worktree() {
  local branch_name=$1 repo_root=$2 line path=""

  while IFS= read -r line; do
    case "$line" in
      "worktree "*) path=${line#worktree } ;;
      "branch refs/heads/$branch_name")
        printf '%s\n' "$path"
        return 0
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain)

  return 1
}

attach_session() {
  local session_name=$1

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
  fi
}

worktree_root="${START_TICKET_WORKTREE_ROOT:-}"
issue_id=""
repo=""
desktop=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --desktop)
      desktop=true
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || die "--repo requires a path"
      repo=$2
      shift 2
      ;;
    --worktree-root)
      [[ $# -ge 2 ]] || die "--worktree-root requires a path"
      worktree_root=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$issue_id" ]] || die "only one issue may be specified"
      issue_id=$1
      shift
      ;;
  esac
done

for command in direnv git jq linearis opencode tmux; do
  require_command "$command"
done

if [[ -z "$issue_id" ]]; then
  require_command rofi
  issue_id=$(select_issue)
  [[ -n "$issue_id" ]] || exit 0
fi

if [[ -z "$repo" ]]; then
  require_command rofi
  repo=$(select_repo)
  [[ -n "$repo" ]] || exit 0
fi

repo_root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) ||
  die "not a Git repository: $repo"

issue=$(linearis issues read "$issue_id") || die "failed to read Linear issue: $issue_id"
identifier=$(jq -er '.identifier' <<<"$issue") || die "issue has no identifier"
branch_name=$(jq -er '.branchName | select(length > 0)' <<<"$issue") ||
  die "issue has no Linear branch name"
title=$(jq -er '.title' <<<"$issue") || die "issue has no title"

issue_slug=${identifier,,}
session_name=$issue_slug

if $desktop; then
  require_command ghostty
  exec ghostty --title="$session_name" -e \
    start-ticket --repo "$repo_root" "$identifier"
fi

if [[ -z "$worktree_root" ]]; then
  worktree_root="$(dirname "$repo_root")/grim-wts"
fi
worktree_root=$(realpath -m "$worktree_root")
worktree="$worktree_root/$issue_slug"

existing_worktree=$(find_branch_worktree "$branch_name" "$repo_root" || true)
if [[ -n "$existing_worktree" ]]; then
  worktree=$existing_worktree
elif [[ -e "$worktree" || -L "$worktree" ]]; then
  die "$worktree already exists but is not the worktree for $branch_name"
else
  mkdir -p "$worktree_root"

  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch_name"; then
    git -C "$repo_root" worktree add "$worktree" "$branch_name"
  elif git -C "$repo_root" show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
    git -C "$repo_root" worktree add --track -b "$branch_name" "$worktree" "origin/$branch_name"
  else
    base_ref=${START_TICKET_BASE_REF:-}
    if [[ -z "$base_ref" ]]; then
      base_ref=$(git -C "$repo_root" symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)
      base_ref=${base_ref:-HEAD}
    fi
    git -C "$repo_root" rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1 ||
      die "base ref does not resolve to a commit: $base_ref"
    git -C "$repo_root" worktree add -b "$branch_name" "$worktree" "$base_ref"
  fi
fi

if [[ -f "$worktree/.envrc" ]]; then
  printf 'Building direnv environment in %s\n' "$worktree"
  direnv allow "$worktree"
  direnv exec "$worktree" true
fi

if ! tmux has-session -t "=$session_name" 2>/dev/null; then
  prompt="Start by reading Linear issue $identifier ($title) and its comments with 'linearis issues read $identifier --with-comments'. Read its relations with 'linearis issues relations list $identifier'. Inspect this repository for the relevant implementation context, then produce a concrete implementation plan. Ask questions where requirements are unclear. Stay in plan mode and do not edit files yet."
  printf -v quoted_prompt '%q' "$prompt"

  tmux new-session -d -s "$session_name" -c "$worktree"
  tmux split-window -h -t "$session_name:0.0" -c "$worktree" \
    "exec opencode --agent plan --prompt $quoted_prompt"
  tmux select-layout -t "$session_name:0" even-horizontal >/dev/null
fi

printf 'Worktree: %s\nBranch: %s\nSession: %s\n' \
  "$worktree" "$branch_name" "$session_name"
attach_session "$session_name"
