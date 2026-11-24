#!/usr/bin/env bash
# Runs every local check that CI runs: formatting, validation of the module and
# examples, terraform test, TFLint, the README docs check and the policy parity
# check. Run from anywhere; stops at the first failing check.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

section() {
  echo ""
  echo "==> $*"
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' is not installed. See \"Development\" in README.md." >&2
    exit 1
  }
}

for tool in terraform tflint terraform-docs; do
  require "$tool"
done

cd "$REPO_ROOT"

section "terraform fmt"
terraform fmt -check -recursive

section "terraform validate"
for dir in . modules/*/ examples/*/; do
  echo "  ${dir}"
  terraform -chdir="$dir" init -backend=false -input=false >/dev/null
  terraform -chdir="$dir" validate -no-color >/dev/null
done

section "terraform test"
for dir in . modules/*/; do
  if compgen -G "${dir}/tests/*.tftest.hcl" >/dev/null; then
    echo "  ${dir}"
    terraform -chdir="$dir" test
  fi
done

section "tflint"
tflint --init >/dev/null
tflint --recursive --format compact

section "terraform-docs"
for dir in . modules/*/; do
  echo "  ${dir}"
  terraform-docs -c "${REPO_ROOT}/.terraform-docs.yml" "$dir" --output-check
done

section "policy parity"
"${SCRIPT_DIR}/check-policy-parity.sh"

echo ""
echo "All checks passed."
