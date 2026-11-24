#!/usr/bin/env bash

# Mako click action: hand currently failed units to an OpenCode session in ~/conf.

# A custom click action replaces mako's default dismissal.
if [[ -n "${1-}" ]]; then
  makoctl dismiss -n "$1" || true
fi

# Re-query rather than trusting the popup: units may have recovered since.
user=$(systemctl --user list-units --state=failed --no-legend --plain | awk 'NF {print $1}' | paste -sd ' ')
system=$(systemctl list-units --state=failed --no-legend --plain | awk 'NF {print $1}' | paste -sd ' ')
if [[ -z "$user" && -z "$system" ]]; then
  notify-send "OpenCode failure" "No failed units remain."
  exit 0
fi

text="Investigate these failed systemd units.
User units: ${user:-none}
System units: ${system:-none}
Check \`systemctl [--user] status\` and \`journalctl [--user] -b -u\` for each, compare against failures.md, and report the cause and a proposed fix."
opencode-start --dir "$HOME/conf" --agent plan --prompt "$text" >/dev/null
