# Open a URL in the browser of the machine this SSH session came from.
# Inside SSH sessions zshenv installs this as BROWSER and as xdg-open.
url=${1:?usage: ssh-open URL}

connection=${SSH_CONNECTION:-}
# tmux refreshes its session environment on every attach, so it knows the
# current client even when this pane was started from an older connection.
if [[ -n ${TMUX:-} ]] && tmux_env=$(tmux show-environment SSH_CONNECTION 2>/dev/null); then
  case $tmux_env in
    SSH_CONNECTION=*) connection=${tmux_env#SSH_CONNECTION=} ;;
    -SSH_CONNECTION) connection= ;;
  esac
fi

if [[ -z $connection ]]; then
  exec /run/current-system/sw/bin/xdg-open "$url"
fi

client_ip=${connection%% *}
client=$(getent hosts "$client_ip" | awk '{ print $2; exit }') || client=
client=${client%%.*}

# Tailscale SSH leaves XDG_RUNTIME_DIR unset. The real xdg-open is called by
# path because the client's own shell also sees an SSH session.
remote="export XDG_RUNTIME_DIR=/run/user/\$(id -u)
systemctl --user show-environment | grep -qE '^(WAYLAND_)?DISPLAY=' &&
  systemd-run --user --collect --quiet /run/current-system/sw/bin/xdg-open $(printf '%q' "$url")"

if [[ -n $client ]] && ssh -o BatchMode=yes -o ConnectTimeout=5 "$client" "$remote"; then
  exit 0
fi

echo "ssh-open: no browser reachable on ${client:-$client_ip}; open this URL yourself:" >&2
echo "$url" >&2
exit 1
