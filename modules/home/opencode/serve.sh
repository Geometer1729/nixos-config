# Paired apps reach the server over Tailscale; the firewall keeps other interfaces closed.
if [ "$(opencode2 service get | jq -r '.hostname // ""')" != 0.0.0.0 ]; then
  opencode2 service set hostname 0.0.0.0
fi

# A login shell gives agent tools the same environment as a terminal-started server,
# and a separate scope keeps the server alive when this unit is stopped or restarted.
# shellcheck disable=SC2016
exec systemd-run --user --scope --collect --quiet --description="OpenCode server" \
  zsh -lc 'exec "$0" service start' "$(command -v opencode2)"
