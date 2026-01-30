#!/usr/bin/env bash
# Sourced by Claude Code before each Bash command (via CLAUDE_ENV_FILE)
# Ensures direnv environment is loaded for the current directory

if command -v direnv &> /dev/null; then
    eval "$(direnv export bash 2>/dev/null)"
fi
