#!/usr/bin/env bash
# Writes a Markdown worksheet of what changed upstream (robbietilton/Compositor) since the last review:
# commits with their files mapped to Lamina's paths, and issues and PRs updated since the checkpoint date,
# each cross-referenced with the backlog records that already mention it.
#
# Usage: upstream-report.sh [--from <commit>] [--since <ISO-8601 UTC>] [--out <file>]
# Defaults come from ../checkpoint. Needs git and an authenticated gh. Read-only apart from fetching
# upstream main into refs/upstream/main.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
UPSTREAM_REPO="robbietilton/Compositor"
UPSTREAM_REF="refs/upstream/main"
CHECKPOINT="$SKILL_DIR/checkpoint"
PATH_MAP="$SKILL_DIR/path-map.tsv"

checkpoint_value() { sed -n "s/^$1=//p" "$CHECKPOINT" | head -1; }

FROM="$(checkpoint_value commit)"
SINCE="$(checkpoint_value since)"
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$FROM" ] && [ -n "$SINCE" ] || { echo "checkpoint needs commit= and since= (or pass --from and --since)" >&2; exit 2; }

cd "$REPO_ROOT"
git fetch --quiet --no-tags "https://github.com/$UPSTREAM_REPO.git" "+main:$UPSTREAM_REF"
HEAD_SHA="$(git rev-parse "$UPSTREAM_REF")"
QUERIED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
git cat-file -e "$FROM^{commit}" 2>/dev/null || { echo "checkpoint commit $FROM is not in this clone" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git ls-files Sources Tests > "$WORK/files"
# "<n>\t<record id>" for every #n mentioned by an upstream-related backlog record.
grep -rli upstream backlog 2>/dev/null | while read -r file; do
  id="$(basename "$file" | sed 's/ - .*//')"
  { grep -oE '#[0-9]+' "$file" || true; } | tr -d '#' | sort -u | while read -r n; do printf '%s\t%s\n' "$n" "$id"; done
done > "$WORK/backlog-index"
# "<sha>\t<merge subject>" for commits that arrived through a pull request's merge ("Merge #199: …").
git log --merges --format='%H %s' "$FROM..$UPSTREAM_REF" | { grep '#[0-9]' || true; } | while read -r merge subject; do
  git rev-list "$merge^1..$merge^2" | while read -r sha; do printf '%s\t%s\n' "$sha" "$subject"; done
done > "$WORK/merged-via"

# Upstream path -> Lamina path: explicit renames first, then the layout's prefix rules,
# then any tracked file with the same name (with "Compositor" read as "Lamina").
lamina_path() {
  local f="$1" mapped base found
  mapped="$( [ -f "$PATH_MAP" ] && awk -F'\t' -v p="$f" '$1 == p { print $2; exit }' "$PATH_MAP" || true)"
  if [ -z "$mapped" ]; then
    case "$f" in
      appcast.xml|Compositor.xcodeproj/*) echo "(release plumbing, not ported)"; return ;;
      README.md) echo "README.md (Lamina's own; see brand/README.md)"; return ;;
      Compositor/Rendering/*.h) mapped="Sources/CPixels/include/${f##*/}" ;;
      Compositor/Rendering/*.c) mapped="Sources/CPixels/${f##*/}" ;;
      Compositor/*) mapped="Sources/LaminaApp/${f#Compositor/}" ;;
      CompositorTests/*) mapped="Tests/LaminaAppTests/${f#CompositorTests/}" ;;
      *) mapped="$f" ;;
    esac
  fi
  if [ -e "$mapped" ]; then echo "$mapped"; return; fi
  base="$(basename "$f" | sed 's/Compositor/Lamina/g')"
  found="$(grep "/$base\$" "$WORK/files" | head -2 | tr '\n' ' ' | sed 's/ $//')"
  if [ -n "$found" ]; then echo "$found (moved)"; else echo "none (new upstream file)"; fi
}

# Backlog records (task-n, doc-n, decision-n, draft-n) that mention #n, limited to upstream-related ones.
backlog_refs() {
  awk -F'\t' -v n="$1" '$1 == n { print $2 }' "$WORK/backlog-index" | sort -u | tr '\n' ' ' | sed 's/ $//'
}

release_only() {
  local files
  files="$(git show --format= --name-only "$1")"
  ! printf '%s\n' "$files" | grep -qvE '^(appcast\.xml|Compositor\.xcodeproj/.*)$'
}

report() {
  echo "# Upstream changes since ${FROM:0:7} / $SINCE"
  echo
  echo "- Upstream: https://github.com/$UPSTREAM_REPO, main at \`$HEAD_SHA\`"
  echo "- Queried at: $QUERIED_AT (use this and the head commit to advance the checkpoint)"
  echo "- Inspect a commit with \`git show <sha>\`; a merged PR with \`gh pr view <n> -R $UPSTREAM_REPO\`"
  echo

  echo "## Commits (oldest first, merges and release-only commits listed apart)"
  echo
  local sha date author subject n
  git log --reverse --no-merges --format='%H%x09%ad%x09%an%x09%s' --date=short "$FROM..$UPSTREAM_REF" |
    while IFS=$'\t' read -r sha date author subject; do
      if release_only "$sha"; then continue; fi
      echo "### ${sha:0:7} $subject"
      echo
      via="$(awk -F'\t' -v s="$sha" '$1 == s { print " · via \"" $2 "\""; exit }' "$WORK/merged-via")"
      echo "$date · $author · $(git show --format= --shortstat "$sha" | sed 's/^ *//')$via"
      echo
      git show --format= --numstat "$sha" | while IFS=$'\t' read -r add del file; do
        case "$file" in *"=>"*) file="$(printf '%s' "$file" | sed -E 's/\{[^}]*=> ([^}]*)\}/\1/; s/.* => //')" ;; esac
        echo "- \`$file\` (+$add −$del) → $(lamina_path "$file")"
      done
      echo
    done

  echo "### Release-only commits"
  echo
  git log --reverse --no-merges --format='%H %s' "$FROM..$UPSTREAM_REF" | while read -r sha subject; do
    release_only "$sha" && echo "- ${sha:0:7} $subject"
  done
  echo
  echo "### Merges"
  echo
  git log --reverse --merges --format='%h %s' "$FROM..$UPSTREAM_REF" | sed 's/^/- /'
  echo

  echo "## Issues and pull requests updated since $SINCE"
  echo
  echo "\"new\" means opened after the checkpoint; the others were open at the last review and changed since."
  echo "Backlog lists upstream-related records that already mention the number."
  echo
  echo "| # | Kind | State | New | Updated | Author | Title | Backlog |"
  echo "| --- | --- | --- | --- | --- | --- | --- | --- |"
  gh api --paginate "repos/$UPSTREAM_REPO/issues?state=all&since=$SINCE&per_page=100" \
    --jq '.[] | [.number,
                 (if .pull_request then "PR" else "issue" end),
                 (if .pull_request.merged_at then "merged" else .state end),
                 .created_at, .updated_at[0:10], .user.login,
                 (.title | gsub("\\|"; "/"))] | @tsv' |
    sort -n |
    while IFS=$'\t' read -r n kind state created updated author title; do
      local new=""
      [[ "$created" > "$SINCE" ]] && new="new"
      echo "| [$n](https://github.com/$UPSTREAM_REPO/issues/$n) | $kind | $state | $new | $updated | $author | $title | $(backlog_refs "$n") |"
    done
  echo
  echo "## Open PRs not updated since the checkpoint"
  echo
  echo "Triaged in an earlier review unless the backlog column is empty."
  echo
  gh pr list -R "$UPSTREAM_REPO" --state open --limit 200 --json number,title,updatedAt \
    --jq ".[] | select(.updatedAt < \"$SINCE\") | [.number, .title] | @tsv" |
    sort -n |
    while IFS=$'\t' read -r n title; do
      echo "- [#$n](https://github.com/$UPSTREAM_REPO/pull/$n) $title — backlog: $(backlog_refs "$n")"
    done
}

if [ -n "$OUT" ]; then report > "$OUT"; echo "wrote $OUT (upstream main $HEAD_SHA, queried $QUERIED_AT)"; else report; fi
