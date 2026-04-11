#!/usr/bin/env bash
# Search Slack messages and format results for LLM consumption
# Usage: slack-search [-n COUNT] <query>

count=10

while getopts "n:" opt; do
  case $opt in
    n) count="$OPTARG" ;;
    *) echo "Usage: slack-search [-n COUNT] <query>" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
  echo "Usage: slack-search [-n COUNT] <query>" >&2
  exit 1
fi

if [ -z "${SLACK_TOKEN:-}" ]; then
  echo "Error: SLACK_TOKEN not set. Add token to /run/secrets/slack_token" >&2
  exit 1
fi

query="$*"

response=$(curl -s -G "https://slack.com/api/search.messages" \
  -H "Authorization: Bearer ${SLACK_TOKEN}" \
  --data-urlencode "query=${query}" \
  --data-urlencode "count=${count}" \
  --data-urlencode "sort=timestamp" \
  --data-urlencode "sort_dir=desc")

ok=$(echo "$response" | jq -r '.ok')
if [ "$ok" != "true" ]; then
  error=$(echo "$response" | jq -r '.error // "unknown error"')
  echo "Slack API error: ${error}" >&2
  exit 1
fi

total=$(echo "$response" | jq -r '.messages.total')
echo "Found ${total} results (showing up to ${count}):"
echo ""

echo "$response" | jq -r '.messages.matches[] | "[\(.channel.name)] \(.username) (\(.ts | tonumber | strftime("%Y-%m-%d %H:%M")))\n\(.text)\n---"'
