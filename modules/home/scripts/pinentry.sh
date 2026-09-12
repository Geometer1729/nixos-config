#!/usr/bin/env bash

if [[ "${PINENTRY_USER_DATA:-}" == gui ]] \
  && [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
  exec pinentry-qt "$@"
fi

exec pinentry-curses "$@"
