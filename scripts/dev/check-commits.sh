#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--safe] <base-ref> <head-ref>"
  echo "       $0 --file <commit-message-file>"
  echo "Example: $0 origin/main HEAD"
  echo "  --safe  Only print commit hashes in output, not messages (avoids shell injection from untrusted commit messages)"
  echo "  --file  Check a single commit message file, as the pre-commit commit-msg hook does"
}

SAFE=0
MESSAGE_FILE=""
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --safe) SAFE=1; shift ;;
    --file)
      [ $# -ge 2 ] || { usage; exit 1; }
      MESSAGE_FILE="$2"; shift 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

# Conventional commit pattern: type(optional-scope): description
PATTERN='^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)(\(.+\))?!?: .{1,120}$'

print_help() {
  echo "Expected: type(optional-scope): description"
  echo "Allowed types: feat, fix, chore, docs, style, refactor, perf, test, build, ci, revert"
}

if [ -n "$MESSAGE_FILE" ]; then
  # The subject is the first line that is neither empty nor a git comment.
  SUBJECT="$(grep -vE '^[[:space:]]*(#|$)' "$MESSAGE_FILE" | head -n 1 || true)"

  # Merge commits and fixups for a later autosquash keep git's own subjects.
  if echo "$SUBJECT" | grep -qE '^(Merge |(fixup|squash|amend)! )'; then
    exit 0
  fi
  if ! echo "$SUBJECT" | grep -qE "$PATTERN"; then
    echo "Commit message does not follow the Conventional Commits format: ${SUBJECT}"
    print_help
    exit 1
  fi
  exit 0
fi

if [ "${#POSITIONAL[@]}" -lt 2 ]; then
  usage
  exit 1
fi

BASE_REF="${POSITIONAL[0]}"
HEAD_REF="${POSITIONAL[1]}"

echo "Checking commits from ${BASE_REF} to ${HEAD_REF}..."

FAILED=0
while IFS= read -r LINE; do
  HASH="${LINE%% *}"
  MESSAGE="${LINE#* }"

  if ! echo "$MESSAGE" | grep -qE "$PATTERN"; then
    if [ "$SAFE" -eq 1 ]; then
      echo "FAIL: $HASH"
    else
      echo "FAIL: $HASH $MESSAGE"
    fi
    FAILED=$((FAILED + 1))
  fi
done < <(git log --no-merges --format="%h %s" "${BASE_REF}..${HEAD_REF}")

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "${FAILED} commit(s) do not follow the Conventional Commits format."
  print_help
  echo ""
  echo "Commit messages are used in changelogs and release notes. Some tools depend on properly formatted commit messages."
  echo "Please consider updating your commit messages, or squash them into a single commit with a proper message before merging."
  echo "Please consider using pre-commit hooks to enforce commit message formatting in the future."
  exit 1
fi

echo "All commits follow the Conventional Commits format."
