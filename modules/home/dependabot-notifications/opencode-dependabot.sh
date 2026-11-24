#!/usr/bin/env bash

# Mako click action: hand open Dependabot alerts to an OpenCode session in ~/conf.

# A custom click action replaces mako's default dismissal.
if [[ -n "${1-}" ]]; then
  makoctl dismiss -n "$1" || true
fi

text="Investigate the open Dependabot alerts for: $DEPENDABOT_REPOS
List them with \`gh api 'repos/<repo>/dependabot/alerts?state=open'\`, trace how each vulnerable package is pulled in, assess whether the vulnerable code is actually reachable here, and propose a fix (upgrade, override, or dismissal with reason)."
opencode-start --dir "$HOME/conf" --agent plan --prompt "$text" >/dev/null
