#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

readonly USAGE="Prepare a release: draft the changelog and update the version in README usage examples.

The version defaults to the one proposed by next-version.sh. A Terraform module
has no version file: the git tag is the version, and the Terraform Registry
publishes it when the tag is pushed. See docs/release.md.

Usage:
  ${SCRIPT_NAME} [-t <version>] [-n] [-y] [-h]
  ${SCRIPT_NAME} [--tag <version>] [--dry-run] [--yes] [--help]

Options:
  -t, --tag TAG   New version tag (e.g. v0.3.0, default: next-version.sh HEAD)
  -n, --dry-run   Run preflight checks and preview the changelog (no writes)
  -y, --yes       Assume 'yes' for every confirmation prompt (for CI, no tty)
  -h, --help      Show this help message

Examples:
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --tag v0.3.0
  ${SCRIPT_NAME} -t v1.0.0-rc.1 -n"

# --- helpers ---

usage() { echo "$USAGE"; }

die() {
  echo "${SCRIPT_NAME}: error: $*" >&2
  exit 1
}

info() { echo "  $*"; }

section() {
  echo ""
  echo "==> $*"
}

warn() {
  echo "${SCRIPT_NAME}: warning: $*" >&2
}

# Set by --yes: skip every confirmation prompt (there is no tty in CI).
assume_yes=false

# Prompt user to confirm after a warning. Exits unless user answers 'y' (case-insensitive).
confirm_or_exit() {
  local prompt="${1:-Continue anyway?}"
  local answer

  if $assume_yes; then
    info "${prompt} [assuming yes]"
    return 0
  fi
  # Read directly from /dev/tty so it works even when stdin is piped
  read -r -p "${prompt} [y/N] " answer </dev/tty
  if [[ ! "$(echo "$answer" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
    echo "Aborting." >&2
    exit 1
  fi
}

# Strip leading 'v' from a tag (v0.9.0 -> 0.9.0)
strip_v() { echo "${1#v}"; }

# --- preflight checks ---

# The release preparation is merged through a pull request, so this runs on a
# release branch. It must start from the latest main, or the changelog misses
# commits.
check_up_to_date() {
  git -C "$REPO_ROOT" fetch --quiet --tags origin main
  if git -C "$REPO_ROOT" merge-base --is-ancestor origin/main HEAD; then
    info "HEAD contains origin/main"
  else
    warn "HEAD does not contain the latest origin/main."
    warn "create the release branch from an up-to-date main: git switch main && git pull && git switch -c chore/release"
    confirm_or_exit "Continue from an outdated HEAD?"
  fi
}

check_clean_working_tree() {
  local status
  status="$(git -C "$REPO_ROOT" status --porcelain)"
  if [[ -n "$status" ]]; then
    warn "there are uncommitted changes:"
    echo "$status" | sed 's/^/    /' >&2
    confirm_or_exit "Continue with uncommitted changes?"
  else
    info "working tree: clean"
  fi
}

check_tag() {
  local new_tag="$1"

  # Ensure the tag does not already exist locally
  if git -C "$REPO_ROOT" tag --list | grep -qx "$new_tag"; then
    die "tag '${new_tag}' already exists locally."
  fi
  info "tag '${new_tag}': not found locally"

  # Ensure the tag does not already exist on origin
  if git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/${new_tag}" | grep -q .; then
    die "tag '${new_tag}' already exists on origin. It cannot be pushed again."
  fi
  info "tag '${new_tag}': not found on origin"

  # Find the latest existing tag and ask user to confirm the range
  local latest_tag
  latest_tag="$(git -C "$REPO_ROOT" tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
  if [[ -z "$latest_tag" ]]; then
    info "previous tag: none (first release)"
    confirm_or_exit "No previous tag found. Release ${new_tag} as first release?"
  else
    info "previous tag: ${latest_tag}"
    # Without commits there is no changelog entry, and the Release workflow
    # fails on a tag without one. Stop before any file is changed.
    if [[ -z "$(git -C "$REPO_ROOT" log "${latest_tag}..HEAD" --no-merges --format=%h)" ]]; then
      die "no commits since ${latest_tag}: nothing to release."
    fi
    confirm_or_exit "Changelog will cover from '${latest_tag}'. Continue?"
  fi
}

# --- version update helpers ---

# README usage examples pin the module to an exact version. Pre-releases are not
# advertised there.
update_readme_version() {
  local file="$1"
  local version="$2"
  sed -i.bak -E "s/^([[:space:]]*version[[:space:]]*=[[:space:]]*)\"[0-9]+\.[0-9]+\.[0-9]+\"/\1\"${version}\"/" "$file"
  rm -f "${file}.bak"
  info "updated ${file} -> ${version}"
}

# --- main ---

main() {
  local tag="" dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--tag)      tag="$2"; shift 2 ;;
      -n|--dry-run)  dry_run=true; shift ;;
      -y|--yes)      assume_yes=true; shift ;;
      -h|--help)     usage; exit 0 ;;
      *)             die "unknown option: $1" ;;
    esac
  done

  if [[ -z "$tag" ]]; then
    tag="$(bash "${SCRIPT_DIR}/next-version.sh" HEAD)"
    [[ -n "$tag" ]] || die "nothing to release: no commits since the latest tag"
    info "proposed version: ${tag} (from next-version.sh, override with --tag)"
  fi

  # Validate tag format: vX.Y.Z with an optional pre-release suffix
  [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "tag must be in the format vX.Y.Z or vX.Y.Z-rc.N (got: ${tag})"

  local version is_prerelease=false
  version="$(strip_v "$tag")"
  [[ "$version" == *-* ]] && is_prerelease=true

  section "Preflight checks"
  check_up_to_date
  check_clean_working_tree
  check_tag "$tag"

  if $dry_run; then
    section "[dry-run] README usage versions (would be updated to ${version})"
    if $is_prerelease; then
      info "pre-release: README is left unchanged"
    else
      grep -nE '^[[:space:]]*version[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "${REPO_ROOT}/README.md" | sed 's/^/    /' || true
    fi
    section "[dry-run] Changelog preview for ${tag}"
    (cd "$REPO_ROOT" && bash "${SCRIPT_DIR}/write-changelog.sh" --tag "$tag" --ref HEAD --dry-run)
    echo ""
    info "dry-run complete — no files were modified."
    return
  fi

  if ! $is_prerelease; then
    section "Updating README usage versions to ${version}"
    update_readme_version "${REPO_ROOT}/README.md" "$version"
  fi

  section "Drafting changelog for ${tag}"

  (cd "$REPO_ROOT" && bash "${SCRIPT_DIR}/write-changelog.sh" --tag "$tag" --ref HEAD)

  # --- instructions ---

  echo ""
  echo "============================================================"
  echo " Release ${tag} is ready for review"
  echo "============================================================"
  echo ""
  echo "Files changed:"
  git -C "$REPO_ROOT" diff --name-only | sed 's/^/  /'
  echo ""
  echo "Next steps:"
  echo ""
  echo "  1. Review and edit the changelog entry in CHANGELOG.md if needed."
  echo "     It becomes the GitHub Release notes."
  echo ""
  echo "  2. Commit the release preparation and open a pull request:"
  echo "       git add CHANGELOG.md README.md"
  echo "       git commit -m \"chore: prepare release ${tag}\""
  echo "       git push -u origin HEAD"
  echo ""
  echo "  3. After the pull request is merged, tag the merge commit on main:"
  echo "       git switch main && git pull"
  echo "       git tag ${tag}"
  echo ""
  echo "  4. Push the tag to trigger the Release workflow:"
  echo "       git push origin ${tag}"
  echo ""
  echo "  The Terraform Registry publishes the tag on push. The Release workflow"
  echo "  creates the GitHub Release from the changelog entry and checks that"
  echo "  the Registry picked up the version."
  echo ""
}

main "$@"
