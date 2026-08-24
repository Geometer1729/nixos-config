#!/usr/bin/env bash
# Human-in-the-loop reproduction loop. Copy and edit only with user approval.

set -euo pipefail

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer
  printf -v "$var" '%s' "$answer"
}

# Replace these example steps with the minimal reproduction.
step "Open the affected application and prepare the failing state."
capture REPRODUCED "Did the exact reported symptom occur? (y/n)"
capture OBSERVATION "Describe the observable symptom without secrets:"

printf '\n--- Captured ---\n'
printf 'REPRODUCED=%s\n' "$REPRODUCED"
printf 'OBSERVATION=%s\n' "$OBSERVATION"
