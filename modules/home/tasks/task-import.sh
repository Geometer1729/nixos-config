# Usage: task-import
# Imports Linear issues and GitHub PRs with bugwarrior, then makes each issue
# depend on its open PRs so the work shows once. Run it on one host only
# (tasks.import.enable): two replicas importing before they sync would
# duplicate tasks.
# Exits non-zero if any bugwarrior target failed, after finishing the rest.

linear() {
  curl -sSf https://api.linear.app/graphql \
    -H "Authorization: $(</run/secrets/linear_api_key)" \
    -H 'Content-Type: application/json' \
    --data "$(jq -n --arg query "$1" '{$query}')"
}

task sync || echo "Sync failed, continuing with local replica" >&2

# The config is in a public repo, so look the assignee's email up instead.
email=$(linear '{ viewer { email } }' | jq -er .data.viewer.email)
config=$(mktemp --suffix=.toml)
trap 'rm -f "$config"' EXIT
template=$(<"$BUGWARRIOR_CONFIG")
printf '%s\n' "${template//@LINEAR_EMAIL@/"$email"}" >"$config"

status=0
output=$(BUGWARRIORRC="$config" bugwarrior pull 2>&1) || status=$?
printf '%s\n' "$output" >&2
# A failed target only logs "Aborted [target]"; bugwarrior still exits 0.
if grep -q '^ERROR:.*Aborted \[' <<<"$output"; then
  status=1
fi

# Linear attaches a PR to its issue from the branch name or magic words.
issues=$(linear '{ viewer { assignedIssues(filter: {state: {type: {in: ["unstarted", "started"]}}}) { nodes { identifier attachments { nodes { url } } } } } }')
task status:pending '( linearidentifier.any: or githuburl.any: )' export |
  jq -r --argjson issues "$issues" '
    (map(select(.githuburl) | {key: .githuburl, value: .uuid}) | from_entries) as $prs
    | ($issues.data.viewer.assignedIssues.nodes
       | map({key: .identifier, value: [.attachments.nodes[].url]}) | from_entries) as $links
    | .[] | select(.linearidentifier) as $issue
    | ($links[$issue.linearidentifier] // [])[] | $prs[.] // empty
    | select(IN($issue.depends // [] | .[]) | not)
    | "\($issue.uuid) \(.)"' |
  while read -r issue pr; do
    task rc.confirmation=off "$issue" modify depends:"$pr"
  done

task sync || echo "Sync failed" >&2
exit "$status"
