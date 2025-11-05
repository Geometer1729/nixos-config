#!/usr/bin/env bash
scratchPad vit show
tmux new-window -t vit -n process process \
  || (sleep 0.5 && tmux new-window -t vit -n process process) \
  || (sleep 1.0 && tmux new-window -t vit -n process process)
