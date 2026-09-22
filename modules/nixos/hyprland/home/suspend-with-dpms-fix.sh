#!/usr/bin/env bash
# Suspend system and re-enable monitors on wake

# Suspend the system
sudo systemctl suspend

# When we wake up (suspend returns), re-enable all monitors
hyprctl dispatch dpms on
