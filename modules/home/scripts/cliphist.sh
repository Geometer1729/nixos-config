#!/usr/bin/env bash

# The script package puts upstream cliphist ahead of this wrapper in PATH.
# Keep the services, picker, and interactive CLI on one runtime-only database.
umask 077
export CLIPHIST_DB_PATH="${XDG_RUNTIME_DIR:?}/cliphist/db"
exec cliphist "$@"
