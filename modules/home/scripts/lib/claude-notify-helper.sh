#!/usr/bin/env bash
# Shared helper functions for Claude notifications

# Icon path (will be set by nix)
CLAUDE_ICON="${CLAUDE_ICON:-$HOME/.local/share/icons/claude-icon.svg}"

# Lock directory for preventing notification spam
LOCK_DIR="/tmp/claude-notify-locks"
mkdir -p "$LOCK_DIR"

# Check if the terminal window is currently focused
# Returns 0 (true) if focused, 1 (false) if not focused
is_window_focused() {
  if [[ -n "$WAYLAND_DISPLAY" ]]; then
    # On Wayland with Hyprland, use tmux to get terminal PID and check if it's focused
    if [[ -n "$TMUX" ]]; then
      local terminal_pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null)
      local focused_pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid' 2>/dev/null)

      # Check if terminal_pid is in the process tree of focused window
      if [[ -n "$terminal_pid" && -n "$focused_pid" ]]; then
        pgrep -P "$focused_pid" 2>/dev/null | grep -q "$terminal_pid"
        return $?
      fi

      # If we can't determine, assume not focused (show notification)
      return 1
    else
      # Not in tmux, don't notify
      return 0
    fi
  elif [[ -n "$DISPLAY" && -n "$WINDOWID" ]]; then
    # On X11, use xdotool to check if current window is active
    [[ "$WINDOWID" == "$(xdotool getactivewindow 2>/dev/null)" ]]
    return $?
  else
    # Fallback: assume not focused (show notification)
    return 1
  fi
}

# Check if we should send a notification
# Args: $1 - notification type (user-input, completed, etc.)
# Returns 0 if we should notify, 1 if we should skip
should_notify() {
  local notify_type="$1"
  local lock_file="$LOCK_DIR/$notify_type"
  local lock_timeout=2  # seconds - prevents notification spam

  # Skip notification if window is focused
  if is_window_focused; then
    return 1
  fi

  # Skip notification if we recently sent one of this type (debouncing)
  if [[ -f "$lock_file" ]]; then
    local lock_age=$(($(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0)))
    if [[ $lock_age -lt $lock_timeout ]]; then
      return 1
    fi
  fi

  # Create lock file
  touch "$lock_file"

  # Clean up old lock files (older than 10 seconds)
  find "$LOCK_DIR" -name "claude-*" -type f -mtime +10s -delete 2>/dev/null

  return 0
}

# Get contextual information about current project
get_project_info() {
  local pwd_info=$(pwd | sed "s|^$HOME|~|")

  # Try to get git repo name
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
    if [[ -n "$repo_name" ]]; then
      echo "$repo_name ($pwd_info)"
      return
    fi
  fi

  # Fallback to just directory
  echo "$pwd_info"
}
