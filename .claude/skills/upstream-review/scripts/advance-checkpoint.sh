#!/usr/bin/env bash
# Moves the review checkpoint to what a finished review covered: the upstream head commit and the query time
# printed at the top of upstream-report.sh's worksheet, and the backlog doc that records the review.
#
# Usage: advance-checkpoint.sh <upstream commit> <queried-at ISO-8601 UTC> <doc id> [--push]
# --push also moves origin's upstream-checkpoint branch to that commit (a mirror of upstream's history that
# keeps the reviewed commits reachable in the fork's remote).
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
[ $# -ge 3 ] || { sed -n '2,7p' "$0"; exit 2; }
COMMIT="$(git -C "$REPO_ROOT" rev-parse --verify "$1^{commit}")"
SINCE="$2"
DOC="$3"
[[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || { echo "queried-at must look like 2026-10-09T15:45:13Z" >&2; exit 2; }

cat > "$SKILL_DIR/checkpoint" <<EOF
# Where the last upstream review stopped. Advance it with scripts/advance-checkpoint.sh.
commit=$COMMIT
since=$SINCE
doc=$DOC
EOF
echo "checkpoint: commit ${COMMIT:0:7}, since $SINCE, doc $DOC"

if [ "${4:-}" = "--push" ]; then
  git -C "$REPO_ROOT" push origin "$COMMIT:refs/heads/upstream-checkpoint"
fi
