#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

readonly USAGE="Print the next release tag, derived from Conventional Commit subjects.

Commits are read up to the given ref, starting from the highest v* tag in the
repository. The bump level is:

  breaking (\`!:\` or \`BREAKING CHANGE\`)  major (minor while the version is 0.x)
  feat                                   minor
  anything else                          patch

Prints nothing and exits 0 when there is nothing to release.

Usage:
  ${SCRIPT_NAME} [ref]

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} HEAD"

case "${1:-}" in
  -h|--help) echo "$USAGE"; exit 0 ;;
esac

ref="${1:-HEAD}"

latest_tag="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
[[ -n "$latest_tag" ]] || { echo "${SCRIPT_NAME}: error: no v* tag found" >&2; exit 1; }

# Merge commits repeat their branch's subjects, so they are excluded. The type
# is read from subjects only — a "feat:" quoted in a commit body is not a
# feature — while BREAKING CHANGE is a body trailer by definition.
subjects="$(git log "${latest_tag}..${ref}" --no-merges --format=%s)"
bodies="$(git log "${latest_tag}..${ref}" --no-merges --format=%b)"
[[ -n "${subjects//[[:space:]]/}" ]] || exit 0

IFS='.' read -r major minor patch <<< "${latest_tag#v}"

if grep -qE '^[a-z]+(\([^)]*\))?!:' <<< "$subjects" || grep -qE '^BREAKING[ -]CHANGE' <<< "$bodies"; then
  # A 0.x line is not stable yet, so a breaking change bumps the minor instead
  # of declaring 1.0.0 — that call stays with a human.
  if [[ "$major" == "0" ]]; then
    minor=$((minor + 1)); patch=0
  else
    major=$((major + 1)); minor=0; patch=0
  fi
elif grep -qE '^feat(\([^)]*\))?:' <<< "$subjects"; then
  minor=$((minor + 1)); patch=0
else
  patch=$((patch + 1))
fi

echo "v${major}.${minor}.${patch}"
