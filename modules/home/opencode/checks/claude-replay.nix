{ pkgs, opencode, filter }:
# The claude-agent wrapper filters Claude's stdin to keep OpenCode from replaying
# earlier tool images as user attachments (anomalyco/opencode#62085). Test the
# filter, and fail once this OpenCode stops writing the replay text it matches,
# so a change upstream can't silently turn the workaround off.
pkgs.runCommand "claude-replay-filter"
{
  nativeBuildInputs = [ pkgs.jq ];
  preferLocalBuild = true;
}
  ''
    for marker in 'Attached media from tool result:' '<conversation-checkpoint>'; do
      if ! grep -rqF -- "$marker" ${opencode}/bin; then
        echo "OpenCode no longer contains '$marker'; update or drop ${filter}" >&2
        exit 1
      fi
    done

    run() { jq --raw-input --raw-output --unbuffered --from-file ${filter} < "$1"; }
    run ${./claude-replay/passthrough.txt} > passthrough.out
    if ! cmp passthrough.out ${./claude-replay/passthrough.txt}; then
      diff ${./claude-replay/passthrough.txt} passthrough.out >&2 || true
      exit 1
    fi
    run ${./claude-replay/rewrite.jsonl} | jq -c . > rewrite.out
    if ! diff <(jq -c . ${./claude-replay/rewrite.expected.jsonl}) rewrite.out >&2; then
      exit 1
    fi
    touch "$out"
  ''
