# Shared routing for task notes.
# A task's note is either its own file or a placeholder redirect to where the
# task lives in the wiki. Once written, a task's routing is never changed.

WIKI_DIR="$HOME/Documents/vw"
TASK_NOTES_DIR="$WIKI_DIR/tasks"

# Matches a taskwiki checklist line ending in the task's short uuid
task_line_regex() {
  printf '^\\s*\\* \\[.\\] .*#%s\\s*$' "${1:0:8}"
}

# Prints the first wiki file containing the task's taskwiki line
find_task_file() {
  { rg --files-with-matches --sort path --regexp "$(task_line_regex "$1")" "$WIKI_DIR" || true; } | head -n1
}

# Prints the absolute file a redirect note points at, failing if it is not one
redirect_target() {
  local link
  link=$(sed -n 's/^\[Redirect\](\([^)#]*\).*/\1/p' "$1" | head -n1)
  [ -n "$link" ] || return 1
  link=$(realpath -m "$TASK_NOTES_DIR/$link")
  if ! [ -e "$link" ] && [ -e "$link.md" ]; then
    link="$link.md"
  fi
  printf '%s\n' "$link"
}

# Creates the task's note if missing, redirecting to its taskwiki line when one exists
ensure_task_note() {
  local uuid="$1" description="$2" note="$TASK_NOTES_DIR/$1.md" found
  [ -e "$note" ] && return
  found=$(find_task_file "$uuid")
  if [ -n "$found" ]; then
    printf '[Redirect](%s)\nCHECKLIST:#%s\n' \
      "$(realpath --relative-to="$TASK_NOTES_DIR" "$found")" "${uuid:0:8}" > "$note"
  else
    printf '# %s\n' "$description" > "$note"
  fi
}
