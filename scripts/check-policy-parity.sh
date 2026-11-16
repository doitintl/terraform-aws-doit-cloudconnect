#!/usr/bin/env bash
# Runs check_policy_parity.py in a temporary virtual environment with hash-checked dependencies.
# Uses uv when available, otherwise python3 -m venv and pip. Arguments are passed to the script.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
requirements="$script_dir/requirements.txt"
venv="$(mktemp -d)"
trap 'rm -rf "$venv"' EXIT

if command -v uv >/dev/null 2>&1; then
  uv venv --quiet "$venv"
  uv pip install --quiet --require-hashes --python "$venv/bin/python" -r "$requirements"
else
  python3 -m venv "$venv"
  "$venv/bin/pip" install --quiet --disable-pip-version-check --require-hashes -r "$requirements"
fi

"$venv/bin/python" "$script_dir/check_policy_parity.py" "$@"
