#!/usr/bin/env bash

# Wait for Hyprland to be ready
while ! hyprctl activeworkspace -j >/dev/null 2>&1; do
  sleep 0.2
done
# Optional: tiny extra settle time
sleep 0.5
