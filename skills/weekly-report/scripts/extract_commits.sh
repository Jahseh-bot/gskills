#!/bin/bash
# extract_commits.sh - Extract commits for a specific author in a parseable format
# Usage: bash extract_commits.sh --author "name|email" [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--path <repo>]

set -euo pipefail

AUTHOR=""
SINCE=""
UNTIL=""
REPO_PATH="."

usage() {
  cat <<EOF
Usage: $0 --author "<name|email>" [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--path <repo>]

Options:
  --author   Git author name or email (required, supports regex partial match)
  --since    Start date (inclusive, default: this Monday)
  --until    End date (inclusive, default: today)
  --path     Repository path (default: current directory)

Output format:
  === META === block with author/date range
  === COMMITS === block with one line per commit: HASH|DATE|SUBJECT
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --author) AUTHOR="$2"; shift 2;;
    --since) SINCE="$2"; shift 2;;
    --until) UNTIL="$2"; shift 2;;
    --path) REPO_PATH="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Error: unknown argument: $1" >&2; usage; exit 1;;
  esac
done

if [[ -z "$AUTHOR" ]]; then
  echo "Error: --author is required" >&2
  usage
  exit 1
fi

# Get Monday of this week (portable across macOS BSD date and GNU date)
get_monday() {
  if date -v-1d >/dev/null 2>&1; then
    # macOS / BSD
    local dow
    dow=$(date +%u)
    date -v-$((dow - 1))d +%Y-%m-%d
  else
    # GNU date (Linux)
    local dow
    dow=$(date +%u)
    date -d "$(date +%Y-%m-%d) -$((dow - 1)) days" +%Y-%m-%d
  fi
}

if [[ -z "$SINCE" ]]; then
  SINCE=$(get_monday)
fi

if [[ -z "$UNTIL" ]]; then
  UNTIL=$(date +%Y-%m-%d)
fi

if [[ ! -d "$REPO_PATH" ]]; then
  echo "Error: repo path does not exist: $REPO_PATH" >&2
  exit 1
fi

cd "$REPO_PATH"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not a git repository: $REPO_PATH" >&2
  exit 1
fi

echo "=== META ==="
echo "AUTHOR: $AUTHOR"
echo "SINCE: $SINCE"
echo "UNTIL: $UNTIL"
echo "REPO: $(pwd)"
echo "=== COMMITS ==="

# Use --author with regex; git log treats --author as substring/regex on the author field
git log \
  --author="$AUTHOR" \
  --since="$SINCE 00:00:00" \
  --until="$UNTIL 23:59:59" \
  --pretty=format:"%H|%ai|%s" \
  || true

# Trailing newline for clean output
echo ""
