# Usage: opencode-start [--task UUID] [--route ticket|pr|notes] [--new]
#                       [--linear ID] [--repo DIR]
#                       [--dir DIR] [--title TITLE] [--agent AGENT] [--skill SKILL]...
#                       [--prompt TEXT | --command NAME [ARGS...]]
# The one way into an OpenCode session: every launcher calls this, so where a
# session lives (routes), how it is tied to its task (link) and how it gets on
# screen (jump) are each decided here, once.
#
# --dir creates a session there. Without it, --task or --linear picks a route:
#   ticket  a Linear issue: its worktree, In Progress, /start-ticket
#   pr      my PR or a review request: a worktree on the PR's branch
#   notes   anything else: a plan session in ~/conf that reads the task's notes
# A routed task resumes its live session instead, unless --new.
# --task links the session to the task: <host>:<session> in its opencode UDA.
# Prints the session ID after jumping to it.

fail() {
  notify-send -u critical OpenCode "$*"
  echo "$*" >&2
  exit 1
}

host=$(uname -n)
work=$HOME/Code/work

task_uuid='' route='' new='' linear='' repo='' dir='' title='' agent='' prompt='' command='' command_args=''
skills=()
while (($#)); do
  case $1 in
  --task) task_uuid=${2?}; shift 2 ;;
  --route) route=${2?}; shift 2 ;;
  --new) new=1; shift ;;
  --linear) linear=${2?}; shift 2 ;;
  --repo) repo=${2?}; shift 2 ;;
  --dir) dir=${2?}; shift 2 ;;
  --title) title=${2?}; shift 2 ;;
  --agent) agent=${2?}; shift 2 ;;
  --skill) skills+=("${2?}"); shift 2 ;;
  --prompt) prompt=${2?}; shift 2 ;;
  --command) command=${2?}; shift 2; command_args="$*"; break ;;
  *) fail "opencode-start: unknown argument $1" ;;
  esac
done

if [[ -n $task_uuid ]]; then
  [[ $task_uuid =~ ^[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}$ ]] ||
    fail "Select a task first (got '$task_uuid')."
fi

## Sessions

session_json() { opencode api get "/api/session/$1" 2>/dev/null | jq -e .data; }

live() { session_json "$1" | jq -e '.time.archived == null' >/dev/null; }

# The newest top-level live session in a directory, optionally by title.
newest_in() {
  local params=(--param directory="$1" --param parentID=null --param archived=false
    --param order=desc --param limit=1)
  [[ -z ${2-} ]] || params+=(--param search="$2")
  opencode api session.list "${params[@]}" | jq -r '.data[0].id // empty'
}

create() {
  local body
  body=$(jq -nc --arg directory "$dir" --arg title "$title" --arg agent "$agent" '
    {location: {$directory}}
    + (if $title == "" then {} else {$title} end)
    + (if $agent == "" then {} else {$agent} end)')
  session=$(opencode api post /api/session --data "$body" | jq -er .data.id) ||
    fail "Could not create an OpenCode session in $dir."
  # Through the API, not `opencode --prompt`: the TUI saves that prompt as the
  # home draft and resubmits it in every new tab.
  if [[ -n $command ]]; then
    body=$(jq -nc --arg name "$command" --arg text "$command_args" '{$name, $text}')
    opencode api post "/api/session/$session/command" --data "$body" >/dev/null ||
      fail "Session $session was created, but /$command could not be sent."
  elif [[ -n $prompt ]]; then
    # Attach skills explicitly: API text does not pass through TUI @ completion.
    body=$(jq -nc --arg text "$prompt" '{$text}
      + if $ARGS.positional == [] then {} else {skills: ($ARGS.positional | map({id: .}))} end' \
      --args "${skills[@]}")
    opencode api post "/api/session/$session/prompt" --data "$body" >/dev/null ||
      fail "Session $session was created, but its prompt could not be sent."
  fi
}

## Task links

task_json() { task rc.verbose=nothing "$task_uuid" export | jq -e '.[0]'; }

link() {
  [[ -n $task_uuid ]] || return 0
  local links
  links=$(task _get "$task_uuid.opencode")
  [[ " $links " != *" $host:$1 "* ]] || return 0
  task rc.verbose=nothing rc.confirmation=off "$task_uuid" modify "opencode:${links:+$links }$host:$1"
}

# Jumps to the task's newest live session on this host, after dropping dead
# links. Other hosts' links are left alone: only their own server can tell.
resume_linked() {
  [[ -n $task_uuid && -z $new ]] || return 0
  local links entry kept=() newest=
  links=$(task _get "$task_uuid.opencode")
  for entry in $links; do
    if [[ $entry != "$host":* ]]; then
      kept+=("$entry")
    elif live "${entry#*:}"; then
      kept+=("$entry")
      newest=${entry#*:}
    fi
  done
  if [[ "${kept[*]}" != "$links" ]]; then
    task rc.verbose=nothing rc.confirmation=off "$task_uuid" modify "opencode:${kept[*]}"
  fi
  [[ -z $newest ]] || resume "$newest"
}

resume() {
  [[ -n $1 && -z $new ]] || return 0
  link "$1"
  jump "$1"
  printf '%s\n' "$1"
  exit 0
}

## Worktrees

# Finds the worktree checked out on a branch, or adds one under ~/Code/work/wts
# with the main checkout's ignored .env files.
worktree() {
  local repo=$1 branch=$2 line current='' path='' name
  while IFS= read -r line; do
    case $line in
    worktree\ *) current=${line#worktree } ;;
    branch\ refs/heads/"$branch") path=$current; break ;;
    esac
  done < <(git -C "$repo" worktree list --porcelain)

  if [[ -z $path ]]; then
    name=${branch:0:30}
    path=$work/wts/${name//\//-}
    if [[ -d $path ]] && [[ $(git -C "$repo" rev-parse --path-format=absolute --git-common-dir) != \
      "$(git -C "$path" rev-parse --path-format=absolute --git-common-dir)" ]]; then
      path=$path-${repo##*/}
    fi
  fi

  if [[ ! -d $path ]]; then
    git -C "$repo" fetch --quiet origin
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$repo" worktree add --quiet "$path" "$branch" >&2
    elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git -C "$repo" worktree add --quiet --track -b "$branch" "$path" "origin/$branch" >&2
    else
      git -C "$repo" worktree add --quiet --no-track -b "$branch" "$path" origin/HEAD >&2
    fi
    # Ignored .env files, at the root or in packages, don't come with a worktree.
    # --directory lists ignored directories like node_modules without descending.
    (
      cd "$repo" || exit
      git ls-files -z --others --ignored --exclude-standard --directory |
        while IFS= read -r -d '' file; do
          case $file in
          .env | */.env) cp --parents "$file" "$path" ;;
          esac
        done
    )
  fi

  local envrc
  for envrc in "$path/.envrc" "$path/apps/panharmonicon/.envrc"; do
    if [[ -f $envrc ]]; then direnv allow "${envrc%/.envrc}"; fi
  done
  printf '%s\n' "$path"
}

## Routes: where a task's session lives

route_ticket() {
  local issue branch
  [[ -n $linear ]] || linear=$(task_json | jq -er .linearidentifier)
  if [[ -z $task_uuid ]]; then
    task_uuid=$(task rc.verbose=nothing status:pending linearidentifier:"$linear" _uuids | head -n1)
    resume_linked
  fi
  issue=$(linearis issues read "$linear") || fail "Could not read Linear issue $linear."
  branch=$(jq -er .branchName <<<"$issue")
  dir=$(worktree "${repo:-$work/grim-monolith}" "$branch")
  if [[ $(jq -r '.state.name | ascii_downcase' <<<"$issue") != "in progress" ]]; then
    linearis issues update "$linear" --status "In Progress" >/dev/null
  fi
  # Sessions start-ticket made before the task was imported, or linked.
  resume "$(newest_in "$dir" "$linear")"
  # An explicit title stops the title agent naming every session after the
  # /start-ticket template ("BRD-?? implementation status").
  title=$(jq -r '"\(.identifier): \(.title)"' <<<"$issue")
  command=start-ticket command_args=$linear
}

route_pr() {
  local pr slug branch me
  pr=$(task_json)
  slug=$(jq -er .githubrepo <<<"$pr")
  repo=$work/${slug#*/}
  [[ -d $repo ]] || fail "No clone of $slug at $repo."
  # gh's stderr carries usage hints; failures are reported here instead.
  branch=$(gh pr view "$(jq -er .githuburl <<<"$pr")" --json headRefName --jq .headRefName 2>/dev/null) ||
    fail "Could not read the branch of $(jq -r .githuburl <<<"$pr")."
  git -C "$repo" fetch --quiet origin "$branch" ||
    fail "Branch $branch of $slug isn't on origin (a fork's PR?)."
  dir=$(worktree "$repo" "$branch")
  resume "$(newest_in "$dir")"
  agent=plan
  # task-import already formats it: "<repo>#<n>: <title>", or "Review ..." for reviews.
  title=$(jq -r .description <<<"$pr")
  me=$(gh api user --jq .login 2>/dev/null) || fail "Could not read the GitHub login."
  if [[ $(jq -r .githubuser <<<"$pr") == "$me" ]]; then
    prompt="This worktree is on the branch of my PR $(jq -r .githuburl <<<"$pr"). Check where it stands with gh: review comments, CI checks and mergeability. Summarize what is left before it can merge."
  else
    prompt="Review PR $(jq -r .githuburl <<<"$pr"), checked out here. Read its description and diff (gh pr view, gh pr diff), then summarize it and list your concerns, most important first. Post nothing to GitHub."
  fi
}

route_notes() {
  dir=$(realpath "$HOME/conf")
  agent=plan
  skills+=(taskwarrior)
  prompt="@taskwarrior $task_uuid: $(task_json | jq -er .description)"
}

## Jump: get the session on screen

jump() {
  local directory socket reply name pane
  directory=$(session_json "$1" | jq -er .location.directory) || fail "No OpenCode session $1."
  # The notifications plugin's presence server hands it to the TUI with that
  # tab, else to one started in its directory, which opens it as a tab.
  for socket in "$XDG_RUNTIME_DIR"/opencode-notify-*.sock; do
    [[ -S $socket ]] || continue
    reply=$(jq -nc --arg session "$1" --arg directory "$directory" '{$session, $directory}' |
      socat -T 2 - "UNIX-CONNECT:$socket" 2>/dev/null) || continue
    [[ $reply != true ]] || return 0
  done
  # No TUI there: start one beside a shell in the directory's tmux session,
  # and show that session in its window, or a new one.
  name=${directory##*/}
  name=${name//[.:]/-}
  tmux has-session -t "=$name" 2>/dev/null || tmux new-session -d -s "$name" -c "$directory"
  pane=$(tmux split-window -h -P -F '#{pane_id}' -t "=$name:" -c "$directory" \
    "exec opencode --session $1")
  tmux select-layout -t "=$name:" even-horizontal
  opencode-focus "" "$pane" 2>/dev/null ||
    setsid -f ghostty -e tmux attach-session -t "=$name" >/dev/null 2>&1
}

## Main

if [[ -z $dir ]]; then
  if [[ -n $linear ]]; then
    route=ticket
  elif [[ -n $task_uuid ]]; then
    task_json >/dev/null || fail "No task $task_uuid."
    resume_linked
    if [[ -z $route ]]; then
      if task_json | jq -e .linearidentifier >/dev/null; then route='ticket'
      elif task_json | jq -e .githuburl >/dev/null; then route='pr'
      else route='notes'
      fi
    fi
  else
    fail "opencode-start needs --dir, --task or --linear."
  fi
  case $route in
  ticket | pr | notes) "route_$route" ;;
  *) fail "opencode-start: unknown route $route" ;;
  esac
fi

create
link "$session"
jump "$session"
printf '%s\n' "$session"
