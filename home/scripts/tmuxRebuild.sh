tmux kill-window -t rebuild || true
# kill any previous failed rebuilds
# this errors if there are no previous
# failed rebuilds so continue on error
tmux new-window \
  -e HIDE_SP_AFTER_REBUILD="$HIDE_SP_AFTER_REBUILD" \
  -k -t sp -n rebuild rebuild
