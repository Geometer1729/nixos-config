# Claude Code for OpenCode's Claude Agent provider. Session replays send earlier
# tool images as if the user pasted them (anomalyco/opencode#62085); the filter
# swaps them for a note. Only stream-json input carries replays, and Claude
# keeps its own PID so OpenCode can signal it.
if [[ " $* " == *" --input-format stream-json "* || " $* " == *" --input-format=stream-json "* ]]; then
  exec "$CLAUDE" "$@" < <(jq --raw-input --raw-output --unbuffered --from-file "$SCRIPTS_LIB/strip-replayed-tool-media.jq")
fi
exec "$CLAUDE" "$@"
