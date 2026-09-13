#!/usr/bin/env bash

set -euo pipefail
shopt -s dotglob nullglob

usage() {
  cat <<'EOF'
Usage: persist-survey [--exclude PATH]...

List candidate files and subtrees under /persist, largest disk usage first.
Skip active mount sources, mountpoints inside /persist, and explicit exclusions.
Recurse only where needed to separate candidates from excluded descendants.

  --exclude PATH  Skip this absolute path and its subtree (repeatable).
  -h, --help      Show this help.

Paths used directly or through symlink aliases need explicit exclusions, e.g.:
  persist-survey --exclude /persist/system/home/"$USER"/.zsh_history

Sizes are allocated disk usage from du. Symlinks are not followed; output paths
are shell-escaped. Candidates are not proof that data is unused. Run with sudo
to read root-owned directories; errors produce a partial report and nonzero exit.
EOF
}

excludes=()
while (( $# )); do
  case "$1" in
    --exclude)
      if (( $# < 2 )) || [[ "$2" != /* ]]; then
        printf 'persist-survey: --exclude requires an absolute path\n' >&2
        exit 2
      fi
      # Normalize spelling without resolving symlink aliases. NUL preserves
      # unusual path names, including trailing newlines.
      IFS= read -r -d '' path < <(realpath --canonicalize-missing --no-symlinks --zero -- "$2")
      if [[ "$path" != /persist && "$path" != /persist/* ]]; then
        printf 'persist-survey: exclusion is outside /persist: %q\n' "$path" >&2
        exit 2
      fi
      excludes+=("$path")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'persist-survey: unknown argument: %q\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# FSROOT is relative to the filesystem, not the live namespace. Match the
# filesystem device and translate from /persist's own FSROOT to its live path.
mounts=$(findmnt --json --list --output TARGET,FSROOT,MAJ:MIN)
mount_excludes=$(jq -ce '
  .filesystems as $mounts
  | ([$mounts[] | select(.target == "/persist")] | last
      // error("/persist is not a mountpoint")) as $base
  | ($base.fsroot | rtrimstr("/")) as $prefix
  | [
      $mounts[]
      | (
          select(.target != "/persist" and .["maj:min"] == $base["maj:min"])
          | .fsroot
          | if . == $base.fsroot then "/persist"
            elif startswith($prefix + "/") then "/persist" + ltrimstr($prefix)
            else empty end
        ),
        (.target | select(startswith("/persist/")))
    ]
  | unique
' <<< "$mounts")
while IFS= read -r -d '' path; do
  excludes+=("$path")
done < <(jq -j '.[] | ., "\u0000"' <<< "$mount_excludes")

walk() {
  local path="$1" excluded child
  local descend=false status=0

  for excluded in "${excludes[@]}"; do
    if [[ "$path" == "$excluded" || "$path" == "$excluded/"* ]]; then
      return 0
    fi
    if [[ "$excluded" == "$path/"* ]]; then
      descend=true
    fi
  done

  if [[ "$path" == /persist || "$descend" == true ]]; then
    if [[ -L "$path" || ! -d "$path" || ! -r "$path" || ! -x "$path" ]]; then
      printf 'persist-survey: cannot traverse directory: %q\n' "$path" >&2
      return 1
    fi
    for child in "$path"/*; do
      walk "$child" || status=1
    done
    return "$status"
  fi

  printf '%s\0' "$path"
}

printf 'Measuring candidate subtrees under /persist...\n' >&2
if ! walk /persist |
  du --files0-from=- --null --summarize --block-size=1 |
  sort --zero-terminated --numeric-sort --reverse |
  numfmt --zero-terminated --delimiter=$'\t' --field=1 --to=iec-i --suffix=B |
  while IFS= read -r -d '' entry; do
    printf '%9s  %q\n' "${entry%%$'\t'*}" "${entry#*$'\t'}"
  done
then
  printf 'persist-survey: survey incomplete; see errors above\n' >&2
  exit 1
fi
