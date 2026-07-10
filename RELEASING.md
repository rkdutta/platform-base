# Releasing

This repository is versioned with [Semantic Versioning](https://semver.org/) and
Git tags of the form `vX.Y.Z`.

## Version scheme

- **MAJOR** — breaking changes: removing/renaming variables or outputs, or changes
  to the cluster / Argo CD topology that require a destroy-and-recreate.
- **MINOR** — backwards-compatible features: new variables, resources, or opt-in
  behaviour.
- **PATCH** — fixes and version bumps of pinned charts/providers with no interface
  change.

## Cutting a release

1. Make sure `main` is green (the CI workflow passes).
2. In `CHANGELOG.md`, move the items under `## [Unreleased]` into a new
   `## [X.Y.Z] - YYYY-MM-DD` section and update the compare/tag links at the
   bottom.
3. Commit the changelog: `git commit -am "Release vX.Y.Z"`.
4. Tag and push:

   ```sh
   git tag vX.Y.Z
   git push origin main --tags
   ```

5. The **Release** workflow (`.github/workflows/release.yml`) re-validates the
   Terraform, extracts the matching `CHANGELOG.md` section, and publishes a
   GitHub Release. It fails if there is no changelog entry for the tag.

## Pinned versions

Reproducibility depends on keeping these pinned:

- **Terraform** — `required_version` in `versions.tf`.
- **Providers** — constraints in `versions.tf`, exact versions locked in
  `.terraform.lock.hcl` (this file is committed on purpose).
- **Argo CD chart** — `argocd_chart_version` in `variables.tf`.
