#!/bin/bash
# extract_commits.sh - Extract commits in a parseable format, with built-in
# multi-repo discovery and optional author filtering.
#
# Behavior:
#   - If --path is itself a git repository: scan only that repo.
#   - Otherwise: discover child git repositories under --path up to --max-depth.
#   - If --author is omitted: include commits from all authors in the time range.
#
# Per-commit output carries a REPO field so a multi-repo run can be grouped
# downstream without losing repo provenance.
#
# Usage: bash extract_commits.sh [--author "name|email"] [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--path <dir>] [--max-depth N]

set -euo pipefail

AUTHOR=""
SINCE=""
UNTIL=""
SCAN_PATH="."
MAX_DEPTH=4
# Directory names to skip during multi-repo discovery (perf + avoid junk repos)
PRUNE_NAMES=(node_modules vendor .next dist build target .Pods Pods .venv venv __pycache__ .gradle)

usage() {
  cat <<EOF
Usage: $0 [--author "<name|email>"] [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--path <dir>] [--max-depth N]

Options:
  --author      Git author name or email (optional; if omitted, include all authors)
  --since       Start date (inclusive, default: this Monday)
  --until       End date (inclusive, default: today)
  --path        Single repo OR workspace dir containing multiple repos (default: cwd)
  --max-depth   Max search depth for multi-repo discovery (default: 4). Skips
                node_modules / vendor / dist / build / target / .next / .venv /
                Pods / __pycache__ / .gradle while scanning.

Output format:
  === META === block with author/date range/scan root and a list of discovered repos.
  === COMMITS === block with one record per commit. Each record:
      ===WEEKLY_COMMIT===
      REPO:    <repo name>
      HASH:    <sha>
      DATE:    <iso date>
      SUBJECT: <commit subject>
      ---BODY---
      <body, possibly empty or multi-line>
      ---END_BODY---
      ---FILES---
      <status>\t<path>      # one line per changed file (status: A/M/D/R...)
      ---END_FILES---
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --author) AUTHOR="$2"; shift 2;;
    --since) SINCE="$2"; shift 2;;
    --until) UNTIL="$2"; shift 2;;
    --path) SCAN_PATH="$2"; shift 2;;
    --max-depth) MAX_DEPTH="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1;;
  esac
done

# Portable Monday-of-this-week computation (macOS BSD date and GNU date)
get_monday() {
  if date -v-1d >/dev/null 2>&1; then
    local dow
    dow=$(date +%u)
    date -v-$((dow - 1))d +%Y-%m-%d
  else
    local dow
    dow=$(date +%u)
    date -d "$(date +%Y-%m-%d) -$((dow - 1)) days" +%Y-%m-%d
  fi
}

[[ -z "$SINCE" ]] && SINCE=$(get_monday)
[[ -z "$UNTIL" ]] && UNTIL=$(date +%Y-%m-%d)

if [[ ! -d "$SCAN_PATH" ]]; then
  echo "Error: path does not exist or is not a directory: $SCAN_PATH" >&2
  exit 1
fi

SCAN_ROOT=$(cd "$SCAN_PATH" && pwd)

# Discover repos: a single repo if SCAN_ROOT is itself a git repo, otherwise
# every git repo reachable up to MAX_DEPTH levels.
REPOS=()
MODE=""
if git -C "$SCAN_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  TOPLEVEL=$(git -C "$SCAN_ROOT" rev-parse --show-toplevel)
  REPOS+=("$TOPLEVEL")
  MODE="single-repo"
else
  MODE="multi-repo"
  # Build a find prune expression for known-heavy / nested dirs
  prune_expr=()
  for name in "${PRUNE_NAMES[@]}"; do
    prune_expr+=(-name "$name" -o)
  done
  # Drop the trailing -o
  unset 'prune_expr[${#prune_expr[@]}-1]'

  # Find .git entries (either dir or worktree file), pruning the heavy dirs above.
  # We don't descend into .git itself either.
  while IFS= read -r gitpath; do
    [[ -z "$gitpath" ]] && continue
    repo_root=$(dirname "$gitpath")
    if git -C "$repo_root" rev-parse --show-toplevel >/dev/null 2>&1; then
      abs=$(git -C "$repo_root" rev-parse --show-toplevel)
      REPOS+=("$abs")
    fi
  done < <(find "$SCAN_ROOT" -maxdepth "$MAX_DEPTH" \
              \( "${prune_expr[@]}" \) -prune \
              -o -name .git -print \
              2>/dev/null | sort -u)
fi

# Deduplicate REPOS while preserving order. Guarded for empty-array case.
DEDUP=()
if [[ ${#REPOS[@]} -gt 0 ]]; then
  seen_file=$(mktemp)
  trap 'rm -f "$seen_file"' EXIT
  for r in "${REPOS[@]}"; do
    if ! grep -Fxq "$r" "$seen_file"; then
      echo "$r" >> "$seen_file"
      DEDUP+=("$r")
    fi
  done
fi
if [[ ${#DEDUP[@]} -gt 0 ]]; then
  REPOS=("${DEDUP[@]}")
else
  REPOS=()
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "Error: no git repositories found under $SCAN_ROOT (max-depth=$MAX_DEPTH)" >&2
  exit 1
fi

# --- META block ---
echo "=== META ==="
echo "AUTHOR: ${AUTHOR:-(all authors)}"
echo "SINCE: $SINCE"
echo "UNTIL: $UNTIL"
echo "SCAN_ROOT: $SCAN_ROOT"
echo "MODE: $MODE"
echo "REPOS_FOUND: ${#REPOS[@]}"
for repo in "${REPOS[@]}"; do
  echo "REPO: $(basename "$repo")|$repo"
done
echo "=== COMMITS ==="

# Build per-repo git-log options
GIT_OPTS=(--since="$SINCE 00:00:00" --until="$UNTIL 23:59:59")
if [[ -n "$AUTHOR" ]]; then
  GIT_OPTS+=(--author="$AUTHOR")
fi

# Emit per-repo commits. REPO field is baked into the --pretty format string
# so each commit record self-identifies. awk closes ---END_FILES--- at the
# end of each repo's stream.
for repo in "${REPOS[@]}"; do
  repo_name=$(basename "$repo")
  # Escape literal % in repo name (git treats % as format placeholder)
  repo_name_fmt=${repo_name//%/%%}

  git -C "$repo" log \
    "${GIT_OPTS[@]}" \
    --pretty=format:"===WEEKLY_COMMIT===%nREPO: ${repo_name_fmt}%nHASH: %H%nDATE: %ai%nSUBJECT: %s%n---BODY---%n%b---END_BODY---%n---FILES---" \
    --name-status \
    2>/dev/null \
    | awk '
        BEGIN { in_files = 0 }
        /^===WEEKLY_COMMIT===$/ {
          if (in_files) { print "---END_FILES---"; in_files = 0 }
          print; next
        }
        /^---FILES---$/ { print; in_files = 1; next }
        { print }
        END {
          if (in_files) { print "---END_FILES---" }
        }
      '
done

# Trailing newline for clean output
echo ""
