#!/usr/bin/env bash

# Check user services
FAILED_USER=$(systemctl --user list-units --state=failed --no-legend --plain | awk 'NF {print $1}')
if [[ -n "$FAILED_USER" ]]; then
  notify-send --app-name=systemd-failures -u critical "Failed User Services" "$FAILED_USER"
fi

# Check system services
FAILED_SYSTEM=$(systemctl list-units --state=failed --no-legend --plain 2>/dev/null | awk 'NF {print $1}')
if [[ -n "$FAILED_SYSTEM" ]]; then
  notify-send --app-name=systemd-failures -u critical "Failed System Services" "$FAILED_SYSTEM"
fi
