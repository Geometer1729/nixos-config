# Paired apps reach the server over Tailscale; the firewall keeps other interfaces closed.
if [ "$(opencode2 service get | jq -r '.hostname // ""')" != 0.0.0.0 ]; then
  opencode2 service set hostname 0.0.0.0
fi

# A switch that updates OpenCode would leave the running server on the old build,
# with plugins built for the new one, so stop it and start this build below. That
# interrupts running agents. TUIs belong to their terminals: only report those.
current="$(dirname "$(command -v opencode2)")/.opencode2-wrapped"
installed=${current#*-opencode2-}
installed=${installed%%/*}
tuis=0
for proc in /proc/[0-9]*; do
  exe=$(readlink "$proc/exe" 2>/dev/null) || continue
  [[ "$exe" == /nix/store/*-opencode2-*/bin/.opencode2-wrapped && "$exe" != "$current" ]] || continue
  if tr '\0' ' ' <"$proc/cmdline" 2>/dev/null | grep -q ' serve --service'; then
    pid=${proc#/proc/}
    old=${exe#*-opencode2-}
    echo "Restarting the OpenCode server: ${old%%/*} -> $installed (PID $pid)" >&2
    kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..100}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid"; fi
  else
    tuis=$((tuis + 1))
  fi
done
if ((tuis > 0)); then
  echo "$tuis OpenCode TUI(s) still run a build older than $installed" >&2
  timeout 5 notify-send --app-name=OpenCode --expire-time=0 "OpenCode $installed installed" \
    "$tuis TUI(s) still run an older build; restart them." || true
fi

# A login shell gives agent tools the same environment as a terminal-started server,
# and a separate scope keeps the server alive when this unit is stopped or restarted.
# shellcheck disable=SC2016
exec systemd-run --user --scope --collect --quiet --description="OpenCode server" \
  zsh -lc 'exec "$0" service start' "$(command -v opencode2)"
