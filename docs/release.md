# Release Procedure

This module is published to the Terraform Registry as [`doitintl/doit-cloudconnect/aws`](https://registry.terraform.io/modules/doitintl/doit-cloudconnect/aws/latest) and used by customers. The project uses semantic versioning, and `CHANGELOG.md` is the source of truth for release notes.

## How publishing works

A Terraform module has no version file: **the git tag is the version**. The Registry watches the repository through a GitHub webhook and publishes every tag that is a valid semver (`vX.Y.Z`) as soon as it is pushed. There is no publish step and no credentials involved.

Pushing the tag also runs the [Release workflow](../.github/workflows/release.yml), which:

1. checks the tag format and that the tagged commit is on `main`. This only detects a bad tag after the fact, because the Registry has already published it. See [Repository setup](#repository-setup).
2. extracts the tag's entry from `CHANGELOG.md` with [`extract-changelog.sh`](../scripts/release/extract-changelog.sh), and fails if there is none
3. creates the GitHub Release with those notes
4. waits up to 10 minutes for the version to appear on the Registry, and warns if it does not

## Versioning

The next version is derived from the [Conventional Commit](https://www.conventionalcommits.org/) subjects since the latest tag by [`next-version.sh`](../scripts/release/next-version.sh):

| Commits since the latest tag | Bump |
| --- | --- |
| a breaking change (`feat!:`, `BREAKING CHANGE:`) | minor while the version is `0.x`, major from `1.0.0` |
| a `feat` | minor |
| anything else | patch |

For this module, a breaking change is anything that forces customers to change their configuration, or that makes Terraform destroy or replace existing resources, for example:

- removing or renaming an input or output, or changing its type
- renaming a resource without a `moved` block
- raising the minimum Terraform or provider version

Prefer a `moved` block over a breaking rename.

Check what would be proposed:

```bash
./scripts/release/next-version.sh HEAD
```

## Releasing

1. Create a release branch from an up-to-date `main`:

   ```bash
   git switch main && git pull
   git switch -c chore/release
   ```

2. Preview, then prepare the release. The version defaults to the one proposed by `next-version.sh`; pass `--tag` to override it.

   ```bash
   ./scripts/release/prepare-release.sh --dry-run
   ./scripts/release/prepare-release.sh            # or --tag v0.3.0
   ```

   The script prepends an entry to `CHANGELOG.md` with [`write-changelog.sh`](../scripts/release/write-changelog.sh) and updates the pinned `version = "X.Y.Z"` in the README usage examples.

3. **Review the changelog entry.** It is drafted from commit subjects and becomes the GitHub Release notes, so edit it for clarity and call out anything customers must act on. Commits marked as breaking are listed first, under **Breaking Changes**. If a commit and its revert are both in the range, remove both from the entry.

4. Commit `chore: prepare release vX.Y.Z`, push, open a pull request and merge it once CI passes.

5. Tag the merge commit on `main` and push the tag:

   ```bash
   git switch main && git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

6. Check the [Release workflow](../.github/workflows/release.yml) run, and that the [Registry](https://registry.terraform.io/modules/doitintl/doit-cloudconnect/aws/latest) shows the new version as latest.

## Pre-releases

Tags such as `v1.0.0-rc.1` are published to the Registry but never become `latest`, so consumers only get them by pinning the exact version. The Release workflow marks their GitHub Release as a pre-release. `prepare-release.sh --tag v1.0.0-rc.1` drafts a changelog entry but leaves the README versions unchanged.

## Rules

- **Never move or delete a published tag.** The Registry and consumers' caches keep the first version they saw. To fix a bad release, ship a new patch release.
- **Never tag without a `CHANGELOG.md` entry.** The Release workflow fails, and the GitHub Release is missing until the tag's entry exists on `main` and the workflow is re-run.
- Tag only commits on `main`. The Release workflow flags a tag that isn't on `main`, but only after the Registry has published it.

## Troubleshooting

- **Version missing on the Registry.** The webhook may have been missed. A Registry owner of the `doitintl` namespace can sign in to the Registry, open the module page and use **Manage Module → Resync Module**.
- **Release workflow failed.** Fix the cause on `main` (for example, add the missing changelog entry in a PR), then re-run the workflow from the tag's run. The Registry does not depend on the workflow, so the version is already published either way.

## Repository setup

Required once, by a repository admin, before relying on this procedure.

Pushing a `v*` tag publishes it to the Registry immediately, and nothing in CI can stop it, so only release maintainers should be able to push release tags. Under **Settings → Rules → Rulesets**, add a tag ruleset:

- targeting `v*`
- with **Restrict creations**, **Restrict updates** and **Restrict deletions** enabled
- with only the release maintainers in the bypass list

Release maintainers can still tag any commit, so tagging only merged commits on `main` stays their responsibility.
