tmux kill-window -t rebuild || true
# kill any previous failed rebuilds
# this errors if there are no previous
# failed rebuilds so continue on error
CMD="
  tmux new-window \
    -e HIDE_SP_AFTER_REBUILD=${HIDE_SP_AFTER_REBUILD:-false} \
    -k -t sp -n rebuild rebuild
  "

$CMD \
  || (sleep 0.5s ; $CMD) \
  || (sleep 1.0s; $CMD)
# Failure is usually caused by waiting for the
# tmux sesion to spawn so just wait and retry
