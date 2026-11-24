# Changelog

## v0.2.1 (2026-11-24)

**Full diff:** [`v0.2.0...v0.2.1`](../../compare/v0.2.0...v0.2.1)

### Bug Fixes

- fix: aws readonly billing access intead of read-write (`d706849`)

### Chores

- chore(ci): improve ci add timeouts and better structure (`49491e3`)
- chore: support breaking changes and revert commits (`11f07ae`)
- chore: add pre-commit hooks pinned to commit hashes (`d1983bc`)
- chore: add release scripts, workflow and changelog (`3feeaa1`)
- chore: move policy parity check under scripts/tests (`4d81263`)

### Other Changes

- docs: document registry usage, development, releasing and agent guidance (`aecdb6c`)
- ci: add tflint, terraform-docs, examples and minimum terraform version checks (`ae4fdc6`)
- ci: check commit messages follow conventional commits (`3aa8822`)

## v0.2.0 (2026-11-17)

**Full diff:** [`v0.1.0...v0.2.0`](../../compare/v0.1.0...v0.2.0)

### Features

- feat: add missing attribute perms allow override expert advice vars (`8a35abd`)
- feat: allow restricting and/or extending the role trust policy (`3179811`)
- feat(reflex): attach a metadata-only policy instead of ReadOnlyAccess (`eb7ab36`)
- feat(module): add opt-in Reflex read-only feature (`827fc3b`)

### Bug Fixes

- fix(reflex): rebuild the policy on AWS-managed policies (`146ba0c`)
- fix(reflex): re-run the IAM propagation delay when the policy changes (`a996e98`)

### Chores

- chore: improve policy-check script with auto managing venv (`f6bf26e`)
- chore: add CI job for test and lock script dependencies (`29b3468`)
- chore: split attribute perms and add docs (`a68194e`)

### Other Changes

- docs: explain unscoped Spot Scaling PassRole and RunInstances (`b2570f1`)

## v0.1.0 (2026-06-15)

Initial release.

### Features

- feat(terraform): added role definition and policies (`1c2fa3e`)
- feat: register cloudconnect aws account (`1f3a6eb`)

### Bug Fixes

- fix(module): Updated the README with the correct aws version (`23d3982`)

### Other Changes

- refactor(module): added usage of doit api key (`4ba3893`)
