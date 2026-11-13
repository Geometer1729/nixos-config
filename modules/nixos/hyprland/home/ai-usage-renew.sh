#!/usr/bin/env bash

# Waybar click on the AI usage meter: renew sign-ins, then make the OpenCode
# usage plugin poll now and Waybar redraw.
#
# Claude Code renews an expired access token itself on `claude auth status`,
# so the browser is only needed when the refresh token is dead too. Renewal
# stays with Claude Code because refresh tokens rotate; refreshing them here
# would race it. OpenCode renews the ChatGPT token Codex uses, so Codex needs a
# sign-in only when the plugin's fresh snapshot asks for one.

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
cache="$runtime/opencode-ai-usage.json"

# Ask the plugin to poll now, wait for its snapshot, and redraw Waybar.
refresh() {
  local before status=1
  before=$(stat -c %.9Y "$cache" 2>/dev/null || echo none)
  touch "$runtime/opencode-ai-usage.refresh"
  for _ in $(seq 40); do
    sleep 0.5
    if [[ $(stat -c %.9Y "$cache" 2>/dev/null || echo none) != "$before" ]]; then
      status=0
      break
    fi
  done
  # Waybar's custom/ai-usage module refreshes on SIGRTMIN+9.
  pkill -RTMIN+9 waybar || true
  return "$status"
}

# Sign-in terminals opened below run this script again as `login <target>`.
if [[ ${1:-} == login ]]; then
  target=$2
  exec 8>"$runtime/ai-usage-login-$target.lock"
  flock -n 8 || exit 0
  case $target in
    codex) signed_in() { opencode auth login openai --method chatgpt-token-sharing; } ;;
    claude-*) signed_in() { CLAUDE_CONFIG_DIR="$HOME/.$target" claude auth login; } ;;
  esac
  if signed_in; then
    echo "Updating the usage bar..."
    refresh || echo "The usage monitor did not respond; the bar updates once OpenCode is open."
  fi
  read -rp "Press Enter to close. " || true
  exit 0
fi

exec 9>"$runtime/ai-usage-renew.lock"
flock -n 9 || exit 0

summary=()

# Opens a sign-in terminal for <target>, unless one is still waiting.
sign_in() {
  local target=$1 label=$2
  if ! flock -n "$runtime/ai-usage-login-$target.lock" true; then
    summary+=("$label: finish signing in in the open window")
    return
  fi
  summary+=("$label: sign in from the new window")
  # Not single-instance: a running Ghostty would open the window without this
  # environment. 9>&- keeps the window from holding this click's lock.
  setsid -f ghostty --gtk-single-instance=false --title="$label sign-in" -e "$0" login "$target" \
    >/dev/null 2>&1 9>&-
}

valid() {
  jq -e --argjson now "$(date +%s)" '.claudeAiOauth.expiresAt / 1000 > $now + 60' \
    "$1/.credentials.json" >/dev/null 2>&1
}

# The profile directories zsh/direnv.nix and claude-agent.sh switch between.
for dir in "$HOME"/.claude-*/; do
  dir=${dir%/}
  name=${dir##*/.claude-}
  if valid "$dir"; then
    summary+=("Claude $name: signed in")
    continue
  fi
  CLAUDE_CONFIG_DIR="$dir" timeout 60 claude auth status --json >/dev/null 2>&1 || true
  if valid "$dir"; then
    summary+=("Claude $name: renewed")
    continue
  fi
  sign_in "claude-$name" "Claude $name"
done

# Codex's state is only known from the plugin, so act on a fresh snapshot only.
if refresh; then
  if jq -e 'any(.signIn[]?; . == "Codex")' "$cache" >/dev/null 2>&1; then
    sign_in codex Codex
  else
    summary+=("Codex: no sign-in needed")
  fi
else
  summary+=("" "The usage monitor did not respond. It runs inside OpenCode; the bar updates once OpenCode is open.")
fi

notify-send --app-name="AI usage" "AI usage" "$(printf '%s\n' "${summary[@]}")"
