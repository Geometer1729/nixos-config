# Prepare old and new revisions of an upstream GitHub repository for flake analysis.
# Usage: flake-repo-checkout [--no-worktrees] owner/repo old-rev new-rev destination

set -euo pipefail

CREATE_WORKTREES=true
if [[ ${1:-} == "--no-worktrees" ]]; then
  CREATE_WORKTREES=false
  shift
fi

if [[ $# -ne 4 ]]; then
  echo "Usage: flake-repo-checkout [--no-worktrees] owner/repo old-rev new-rev destination" >&2
  exit 2
fi

REPOSITORY=$1
OLD_REV=$2
NEW_REV=$3
DESTINATION=$(realpath -m "$4")

if [[ ! $REPOSITORY =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Repository must be a GitHub owner/repo name" >&2
  exit 2
fi
if [[ ! $OLD_REV =~ ^[0-9a-fA-F]{40}$ || ! $NEW_REV =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "Revisions must be full 40-character Git commit IDs" >&2
  exit 2
fi
if [[ $DESTINATION != /tmp/flake-update/*/repos/* ]]; then
  echo "Destination must be under /tmp/flake-update/<run>/repos" >&2
  exit 2
fi
if [[ -e $DESTINATION ]]; then
  echo "Destination already exists: $DESTINATION" >&2
  exit 1
fi

mkdir -p "$(dirname "$DESTINATION")"
cleanup() {
  rm -rf "$DESTINATION"
}
trap cleanup EXIT

GIT_DIR="$DESTINATION/repository.git"
git init --bare --initial-branch=flake-update "$GIT_DIR" >/dev/null
git -C "$GIT_DIR" remote add origin "https://github.com/$REPOSITORY.git"
git -C "$GIT_DIR" fetch --filter=blob:none --no-tags --depth=1024 origin "$NEW_REV:refs/heads/new"

DEPTH=1024
EXPECTED_COUNT=$(gh api "repos/$REPOSITORY/compare/$OLD_REV...$NEW_REV" --jq '.total_commits' 2>/dev/null || true)
while true; do
  OLD_PRESENT=false
  if git -C "$GIT_DIR" cat-file -e "$OLD_REV^{commit}" 2>/dev/null; then
    OLD_PRESENT=true
  fi

  if $OLD_PRESENT && [[ $EXPECTED_COUNT =~ ^[0-9]+$ ]]; then
    ACTUAL_COUNT=$(git -C "$GIT_DIR" rev-list --count "$OLD_REV..$NEW_REV")
    if (( ACTUAL_COUNT == EXPECTED_COUNT )); then
      break
    fi
  elif $OLD_PRESENT; then
    if [[ $(git -C "$GIT_DIR" rev-parse --is-shallow-repository) == true ]]; then
      git -C "$GIT_DIR" fetch --filter=blob:none --no-tags --unshallow origin "$NEW_REV:refs/heads/new"
    fi
    break
  fi

  if (( DEPTH >= 65536 )); then
    echo "Could not verify the complete range within 65536 commits" >&2
    exit 1
  fi
  git -C "$GIT_DIR" fetch --filter=blob:none --no-tags --deepen="$DEPTH" origin "$NEW_REV:refs/heads/new"
  DEPTH=$((DEPTH * 2))
done

if $CREATE_WORKTREES; then
  git -C "$GIT_DIR" worktree add --detach "$DESTINATION/old" "$OLD_REV" >/dev/null
  git -C "$GIT_DIR" worktree add --detach "$DESTINATION/new" "$NEW_REV" >/dev/null
fi

trap - EXIT
printf '%s\n' "$GIT_DIR"
