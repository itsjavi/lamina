#!/usr/bin/env bash
# Bumps VERSION, commits it and tags the commit vX.Y.Z (the tag release.yml builds).
#
#   scripts/bump-version.sh <major|minor|patch|X.Y.Z> [--push]
#
#   --push   pushes main and the tag together, which starts the Release workflow (it builds,
#            signs and publishes; nothing is built locally)
#
# Needs a clean working tree on main, so the tagged commit is exactly what gets released.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { sed -n '4,7s/^# \{0,1\}//p' "$0" >&2; exit 64; }
fail() { echo "✗ $*" >&2; exit 1; }

target="" push=0
for arg in "$@"; do
  case "$arg" in
    --push) push=1 ;;
    -h|--help) usage ;;
    -*) echo "Unknown option $arg" >&2; usage ;;
    *) [ -z "$target" ] || usage; target="$arg" ;;
  esac
done
[ -n "$target" ] || usage

semver='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
current="$(tr -d '[:space:]' < VERSION)"
[[ "$current" =~ $semver ]] || fail "VERSION holds “${current}”, not X.Y.Z"
major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"

case "$target" in
  major) next="$((major + 1)).0.0" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  patch) next="$major.$minor.$((patch + 1))" ;;
  *)
    next="${target#v}"
    [[ "$next" =~ $semver ]] || fail "“${target}” isn't major, minor, patch or X.Y.Z"
    ;;
esac

# The new version must be higher: Sparkle and the website pick the newest by version.
[ "$(printf '%s\n%s\n' "$current" "$next" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" = "$next" ] &&
  [ "$next" != "$current" ] || fail "$next isn't higher than the current $current"

tag="v$next"
[ "$(git branch --show-current)" = main ] || fail "check out main first (releases are tagged on main)"
[ -z "$(git status --porcelain)" ] || fail "commit or stash your changes first; the tag must match what gets built"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "tag $tag already exists"

if [ "$push" = 1 ]; then
  git fetch -q origin main --tags
  git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null && fail "tag $tag already exists on origin"
  [ -z "$(git rev-list HEAD..origin/main)" ] || fail "main is behind origin/main; pull first"
fi

echo "$next" > VERSION
git add VERSION
git commit -q -m "chore(release): $tag"
git tag -a "$tag" -m "Lamina $next"
echo "✓ $current → $next, committed and tagged $tag"

if [ "$push" = 1 ]; then
  # Both or neither: a pushed tag without its commit on main (or the reverse) confuses releases.
  git push -q --atomic origin HEAD:main "refs/tags/$tag"
  echo "✓ Pushed main and $tag: the Release workflow is building it"
else
  echo "  Push when ready: git push --atomic origin main $tag"
fi
