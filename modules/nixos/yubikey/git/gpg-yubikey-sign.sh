#!/usr/bin/env bash
# git's gpg.program: sign with whichever YubiKey is plugged in.
# git calls `gpg --status-fd=2 -bsau <user.signingkey>`; when a card is present,
# swap in the card's own signature key so the primary and backup both work.

args=("$@")

for i in "${!args[@]}"; do
  if [[ ${args[i]} == -bsau ]]; then
    card_key=$(gpg --card-status --with-colons 2>/dev/null | awk -F: '$1 == "fpr" { print $2 }') || true
    if [[ -n ${card_key:-} ]]; then
      args[i + 1]="$card_key!"
    fi
  fi
done

exec gpg "${args[@]}"
