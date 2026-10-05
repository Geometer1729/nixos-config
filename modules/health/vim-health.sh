# Fail on Neovim checkhealth errors; list warnings for comparison with failures.md.
if [[ ${OPENCODE_TERMINAL:-} == 1 && -n ${TMUX:-} ]]; then
  TERM=$(tmux show-options -gv default-terminal)
elif [[ -z ${TERM:-} ]]; then
  # Non-interactive SSH has no terminal, which checkhealth reports as an error.
  TERM=xterm-256color
fi
export TERM

report=$(mktemp --suffix=.txt)
trap 'rm -f "$report"' EXIT
nvim --headless -c checkhealth -c "w! $report" -c qa 2>/dev/null || true
if [[ ! -s $report ]]; then
  echo "vim-health: checkhealth wrote no report" >&2
  exit 1
fi

findings=$(grep -E '^- (❌|⚠)' "$report" | grep -v 'is not executable. Configuration will not be used' || true)
if [[ -z $findings ]]; then
  echo "No errors or warnings found"
  exit 0
fi
echo "$findings"
if grep -q '^- ❌' <<<"$findings"; then
  exit 1
fi
