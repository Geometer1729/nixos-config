# Claude Code for OpenCode's Claude Agent provider. The provider starts Claude in
# the session's folder, but the shared OpenCode server never loads direnv, so
# apply the same account split as zsh/direnv.nix here.
if [[ "$PWD" == "$HOME/Code/work"* ]]; then
  export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
else
  export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
fi

exec "$CLAUDE" "$@"
