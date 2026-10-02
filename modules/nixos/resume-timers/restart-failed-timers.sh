# Timers that elapsed during sleep fire on resume while the sleep job is still
# queued. If the triggered unit conflicts with sleep.target, systemd rejects the
# transaction, and the timer fails with Result=resources and stays dead.
systemctl list-units --type=timer --state=failed --plain --no-legend |
  awk '{ print $1 }' |
  while read -r timer; do
    if [[ $(systemctl show --property=Result --value "$timer") == resources ]]; then
      echo "Restarting $timer after it failed to queue its unit"
      systemctl restart "$timer"
    fi
  done
