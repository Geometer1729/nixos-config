#!/usr/bin/env bash
# Keep the machine awake while important work runs. Holds are ordinary logind
# sleep inhibitors, so logind is the only state: `status` just lists them.
set -euo pipefail

# Print "Reason: name (PID n)" if the process with this argv is important work.
# Matching is deliberately loose: a false positive only delays sleep.
workload() {
  local pid=$1 name=${2##*/} reason=""
  shift 2
  # Scripts appear as `bash /nix/store/…/bin/nixos-rebuild test`. Code passed
  # with -c/-m/-e is never a workload, even if it mentions one.
  if [[ $name =~ ^((ba|da|z)?sh|python[0-9.]*|perl)$ ]]; then
    while [[ ${1-} == -[BEsSu] ]]; do shift; done
    [[ -n ${1-} && $1 != -* ]] || return 0
    name=${1##*/}
    shift
  fi
  name=${name#.}
  name=${name%-wrapped}
  local args=" $* "
  case $name in
    nixos-rebuild) reason="NixOS rebuild" ;;
    switch-to-configuration) reason="NixOS activation" ;;
    local-deploy) reason="NixOS deployment" ;;
    nix-build) reason="Nix build" ;;
    nix-copy-closure) reason="Nix closure transfer" ;;
    nh) has os && reason="NixOS operation" ;;
    just) has deploy || has deploy-devshell && reason="Deployment" ;;
    nix)
      has build && reason="Nix build"
      has copy && reason="Nix copy"
      has flake check && reason="Nix flake check"
      ;;
    nix-store) has -r || has --realise || has --serve || has --import && reason="Nix store operation" ;;
    nix-daemon) has --stdio && reason="Remote Nix operation" ;;
  esac
  [[ -z $reason ]] || echo "$reason: $name (PID $pid)"
}

# True if workload's arguments contain these words in a row, e.g. `has flake check`.
has() { [[ $args == *" $* "* ]]; }

scan() {
  local proc argv
  for proc in /proc/[0-9]*; do
    # Processes may exit mid-scan; kernel threads have no argv.
    mapfile -d '' -t argv 2>/dev/null <"$proc/cmdline" || continue
    ((${#argv[@]})) || continue
    workload "${proc#/proc/}" "${argv[@]}"
  done
  # Everything a build user runs is part of a Nix build.
  ps -o user= -G "$KEEP_AWAKE_BUILD_GROUP" | sort -u | sed 's/^/Nix build: /' || true
}

monitor() {
  local reasons held="" inhibitor="" old last_seen=0
  while sleep 2; do
    reasons=$(scan | cut -d: -f1 | sort -u | paste -sd,)
    reasons=${reasons//,/, }
    if [[ -n $reasons ]]; then
      last_seen=$SECONDS
    elif ((SECONDS - last_seen < 5)); then
      continue # Bridge short gaps between build phases.
    fi
    [[ $reasons == "$held" ]] && continue

    # Take the new hold before releasing the old one.
    old=$inhibitor inhibitor=""
    if [[ -n $reasons ]]; then
      systemd-inhibit --what=sleep --mode=block --who=workload-inhibit --why="$reasons" \
        sleep infinity &
      inhibitor=$!
      echo "Holding sleep: $reasons"
    else
      echo "Released sleep hold"
    fi
    # systemd-inhibit releases its lock when its command exits.
    [[ -z $old ]] || pkill -P "$old" sleep
    held=$reasons
  done
}

# Print the tooltip text, or Waybar's JSON when $1 is "waybar".
status() {
  local automatic=disabled
  if [[ $KEEP_AWAKE_AUTOMATIC == true ]]; then
    automatic=$(systemctl is-active workload-inhibit.service || true)
  fi
  busctl --json=short call org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager ListInhibitors |
    jq -r --arg format "$1" --arg automatic "$automatic" --argjson uid "$(id -u)" '
      # Rows are [what, who, why, mode, uid, pid]; only sleep blockers matter.
      [.data[0][] | select((.[0] | split(":") | index("sleep")) and (.[3] | startswith("block")))]
      | . as $holds
      | any(.[]; .[1] == "keep-awake-manual" and .[4] == $uid) as $manual
      | any(.[]; .[1] == "workload-inhibit") as $auto
      | (if $automatic != "active" and $automatic != "disabled" then "error"
         elif $manual and $auto then "both"
         elif $manual then "manual"
         elif $auto then "automatic"
         elif $holds != [] then "other"
         else "off" end) as $mode
      | ([if $holds == [] then "Normal idle sleep and locking."
          else "Suspend blocked; automatic locking remains enabled." end]
         + [$holds[] | "\(.[1]): \(.[2])"]
         + if $mode == "error" then ["Automatic workload detection unavailable (\($automatic))."] else [] end
         + [if $manual then "Click: disable manual hold"
            else "Click: keep awake until toggled off or logout" end]
         | join("\n")) as $tooltip
      | if $format != "waybar" then $tooltip
        else {text: {off: "☕", automatic: "☕ auto", manual: "☕ manual", both: "☕ auto+manual",
                     other: "☕ busy", error: "☕ !"}[$mode],
              class: $mode, tooltip: ($tooltip | @html)} | tojson end'
}

case "${1:-status}" in
  toggle)
    # Serialize clicks; the user service's state is the manual mode.
    exec 9>"${XDG_RUNTIME_DIR:?}/keep-awake-toggle.lock"
    flock 9
    if systemctl --user is-active --quiet keep-awake-manual.service; then
      exec systemctl --user stop keep-awake-manual.service
    else
      exec systemctl --user start keep-awake-manual.service
    fi
    ;;
  status) status text ;;
  waybar)
    status waybar ||
      echo '{"text": "☕ !", "class": "error", "tooltip": "Keep-awake state unavailable"}'
    ;;
  matches)
    matches=$(scan)
    echo "${matches:-No recognized workloads.}"
    ;;
  monitor) monitor ;;
  *)
    echo 'Usage: keep-awake [toggle | status | matches]' >&2
    exit 2
    ;;
esac
