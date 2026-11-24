#!/usr/bin/env bash

# Every 5 minutes on every host: file a Taskwarrior task for each failed unit,
# then, on desktops, notify. One task per failure instance (InvocationID); a
# repeat failure of a unit that already has a pending task annotates it. Each
# host files only its own failures, so sync lag can't duplicate them.
# The popup lists each unit with its task's short UUID; clicking it runs
# opencode-failure on those tasks.

host=$(uname -n)

# Prints "<unit> (task <short uuid>)".
file_task() {
  local scope=$1 unit=$2 flag=() invocation key uuid keys
  [[ $scope == system ]] || flag=(--user)
  invocation=$(systemctl "${flag[@]}" show -p InvocationID --value "$unit")
  [[ -n $invocation ]] ||
    invocation=$(systemctl "${flag[@]}" show -p StateChangeTimestampMonotonic --value "$unit")
  key=$host/$scope/$unit/$invocation

  # Any status: a completed or deleted task means this failure was handled.
  uuid=$(task rc.verbose=nothing rc.context= "failure.has:$key" _uuids | head -n1)
  if [[ -z $uuid ]]; then
    uuid=$(task rc.verbose=nothing rc.context= status:pending failurehost:"$host" \
      failurescope:"$scope" failureunit:"$unit" _uuids | head -n1)
    if [[ -n $uuid ]]; then
      keys=$(task _get "$uuid.failure")
      task rc.verbose=nothing rc.confirmation=off "$uuid" modify "failure:$keys $key" >/dev/null
      task rc.verbose=nothing "$uuid" annotate \
        "Failed again at $(systemctl "${flag[@]}" show -p StateChangeTimestamp --value "$unit")" >/dev/null
    else
      uuid=$(task rc.verbose=new-uuid add "Investigate failed $unit on $host" \
        project:conf +agent +next +@computer +@home \
        failure:"$key" failurehost:"$host" failurescope:"$scope" failureunit:"$unit" |
        grep -oE '[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}')
    fi
  fi
  printf '%s (task %s)\n' "$unit" "${uuid:0:8}"
}

check() {
  local scope=$1 summary=$2 flag=() units lines=()
  [[ $scope == system ]] || flag=(--user)
  units=$(systemctl "${flag[@]}" list-units --state=failed --no-legend --plain 2>/dev/null |
    awk 'NF {print $1}')
  [[ -n $units ]] || return 0
  while IFS= read -r unit; do
    lines+=("$(file_task "$scope" "$unit")")
  done <<<"$units"
  if [[ -n ${FAILURE_NOTIFY-} ]]; then
    notify-send --app-name=systemd-failures -u critical "$summary" "$(printf '%s\n' "${lines[@]}")"
  fi
}

check user "Failed User Services"
check system "Failed System Services"
